#source: https://forum.devolutions.net/topics/35657/bulk-import-speed-problem
###########################################################################
#
# Import credential entries from CSV exports (e.g., Password Safe) into RDM.
#
###########################################################################

<#
.SYNOPSIS
    Import credential and web entries from CSV files into Remote Desktop Manager vaults.
.DESCRIPTION
    Ensures the Devolutions.PowerShell module is present, sets the current data source, and loops through a
    configured list of customers. For each customer, the script loads their CSV export, creates any missing
    folder structure under a designated root folder, and imports each credential as either a standard
    credential or a web entry. Passwords are applied via secure string conversion.
.NOTES
    Update the data source name, customer list, source folder, and credential root folder before running.
    The CSV is expected to use semicolons and the Password Safe headers shown below.
#>

# Check whether the RDM PowerShell module is installed; install it for the current user if absent.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (replace with your RDM data source name).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Configure the folders that contain the customer CSVs and the destination root folder in RDM.
$SourceFolder = 'D:\Scripts\ToImport'
$CredentialRootFolder = "1. Credentials"

# Define the customers whose CSV files will be imported.
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
        # Work around Set-RDMCurrentRepository timing issues by retrying until the vault is active.
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

        # Original Password Safe header: "Ordner (Kategorie)";"Name";"UserName";"Password";"URL"
        $Credentials = Import-csv -Path $CustSrcFile -Delimiter ";" 

        foreach($Credential in $Credentials)
        {
            $CredFolder = $($Credential.("Ordner (Kategorie)")).replace(' >> ','\')
            $CredName = $Credential.Name
            $CredUser = $Credential.UserName
            $CredPass = $Credential.Password
            $CredURL = $Credential.URL
            $CredDomain = ""

            # Infer the root name the first time we encounter a top-level folder.
            if([string]::IsNullOrEmpty($RootName))
            {
                if(([Regex]::Matches($CredFolder, "\\")).Count -eq 0)
                {
                    $RootName = $CredFolder
                }
            }
            $CredFolder = $CredFolder.replace($RootName, $CredentialRootFolder)

            # Ensure the folder hierarchy exists prior to creating the session.
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

                            # Track the new folder locally to avoid redundant Get-RDMSession calls.
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

            # Choose the entry type based on whether a URL is present.
            if (-not ([string]::IsNullOrEmpty($CredURL)))
            {
                $CredType = "WebBrowser"
            }
            else
            {
                $CredType = "Credential"
            }

            # Split domain-qualified usernames into domain + username values.
            if(([Regex]::Matches($CredUser, "\\")).Count -gt 0)
            {
                $CredUserSplit = $CredUser -split "\\"
                $CredUser = $CredUserSplit[1]
                $CredDomain = $CredUserSplit[0]
            }

            $NewCred = New-RDMSession -Name $CredName -Type $CredType -Group $CredFolder -Host $CredURL
            #$NewCred.Description = "Optional description"
            $NewCred.Credentials.UserName = $CredUser
            $NewCred.Credentials.Domain = $CredDomain

            Set-RDMSession $NewCred -refresh
            Set-RDMSessionPassword -ID $($NewCred.ID).Guid -Password (ConvertTo-SecureString $CredPass -AsPlainText -Force) -refresh
        }
    }
}
