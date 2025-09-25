#source: https://forum.devolutions.net/topics/35657/bulk-import-speed-problem
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Declarations
$SourceFolder = 'D:\Scripts\ToImport'
$CredentialRootFolder = "1. Credentials"


# Define Customers Array
$Customers = @("A Test Customer1","A Test Customer2")

foreach($Customer in $Customers)
{
    $CustSrcFile = $SourceFolder + "\" + $Customer + ".csv"

    $RootName = ''

    if (!(Test-Path $CustSrcFile))
    {
	    Write-Host "Error: No CSV for Customer $Customer found"
    }
    else
    {
        $Vault = Get-RDMVault -Name $Customer
        # Fix for the Set-RDMCurrentRepository Bug
        # Loop until the Repo is fully loaded
        do
        {
	        try
	        {
		        Set-RDMCurrentRepository -Repository $Vault
	        }
	        catch {}
	        Start-Sleep -Seconds 1
        }
        until ((Get-RDMCurrentRepository).Name -eq $Customer)

        $AllFolders = Get-RDMSession -ErrorAction SilentlyContinue | where { $_.ConnectionType -eq "Group" }

        # Original Header directly from Password Safe:
        # "Ordner (Kategorie)";"Name";"UserName";"Password";"URL"

        #-Header "Folder","Name","Username","Password","Url"
        $Credentials = Import-csv -Path $CustSrcFile -Delimiter ";" 

        foreach($Credential in $Credentials)
        {
            $CredFolder = $($Credential.("Ordner (Kategorie)")).replace(' >> ','\')
            $CredName = $Credential.Name
            $CredUser = $Credential.UserName
            $CredPass = $Credential.Password
            $CredURL = $Credential.URL
            $CredDomain = ""

            # Since Password Safe exports the Folder Name as "Root" we
            # need to find out which Name it is and Replace it with
            # the new Root Folder Name
            if([string]::IsNullOrEmpty($RootName))
            {
                if(([Regex]::Matches($CredFolder, "\\")).Count -eq 0)
                {
                    $RootName = $CredFolder
                }
            }
            $CredFolder = $CredFolder.replace($RootName, $CredentialRootFolder)

            # Check & Create Folder Structure if Folder not existent
            if(([Regex]::Matches($CredFolder, "\\")).Count -gt 0)
            {
                $ThisFolderPath = ""
                $CredFolder -split "\\" | Foreach-Object {
                    $ThisFolderName = $_
                    if($ThisFolderPath -ne "")
                    {
                        $SearchCredFolder = $AllFolders | where { $_.Group -eq "$ThisFolderPath\$ThisFolderName" }
                        if ($SearchCredFolder.Count -eq 0)
                        {
                            Write-Host "Creating '$ThisFolderName' in '$ThisFolderPath'"
                            $NewFolder = New-RDMSession -Name $ThisFolderName -Group $ThisFolderPath -Type "Group" -SetSession
                            Set-RDMSession -Session $NewFolder -Refresh

                            # Update $AllFolders with the new Folder - safe one Get-RDMSession call
                            $AllFolders += $NewFolder
                        }
                        $ThisFolderPath += "\$ThisFolderName"
                    }
                    else
                    {
                        $ThisFolderPath += $ThisFolderName
                    }
                }
            }

            # Specify Credential Type
            if (-not ([string]::IsNullOrEmpty($CredURL)))
            {
                $CredType = "WebBrowser"
            }
            else
            {
                $CredType = "Credential"
            }

            # Check if Username has Domain and set Domain Variable
            if(([Regex]::Matches($CredUser, "\\")).Count -gt 0)
            {
                $CredUserSplit = $CredUser -split "\\"
                $CredUser = $CredUserSplit[1]
                $CredDomain = $CredUserSplit[0]
            }

            $NewCred = New-RDMSession -Name $CredName -Type $CredType -Group $CredFolder -Host $CredURL
            #$NewCred.Description = "test description"
            $NewCred.Credentials.UserName = $CredUser
            $NewCred.Credentials.Domain = $CredDomain

            Set-RDMSession $NewCred -refresh
            Set-RDMSessionPassword -ID $($NewCred.ID).Guid -Password (ConvertTo-SecureString $CredPass -AsPlainText -Force) -refresh
        }
    }
}