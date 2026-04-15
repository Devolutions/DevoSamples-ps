###########################################################################
#
# Import entries in a given Vault of a given data source from a CSV extracted
# from Delinea
#
###########################################################################

<#
.SYNOPSIS
    Import credential entries from a Delinea generated CSV file
.DESCRIPTION
    Ensures the Devolutions.PowerShell is available, connects to the specified
    RDM data source, and import credential entries following the Folder. This script should detect when a line is 
    a new entry or a continuation
.NOTES
    Replace the placeholders for the data source name, vault name, csv path. The
    script installs modules for the current user if they are missing and prompts an Out-GridView summary when
    finished.
    Require Remote Desktop Manager installed and configured to connect to DVLS.
    While calling the script, you will be prompted for a [string]$DataSourceName, [string]$VaultName, [string]$csvFilePath, and [string]$logFilePath = ""
    
#>

## read the csv file
## for each rows, verify if:
## - SecretName is not empty
## - Domain is not empty
## - Username is not empty
## - Password is not empty
## - Notes is not empty
## - what is the folder

## when Username is empty, makes sure the rest is empty
## if all empty, just skip
## else add to description

## before adding an 

# review the csv file
# identify crucial fields
# map fields properly
# find irregularities and interpret what should be done
# import account


param(
    [Parameter(Mandatory)]
    [string]$DataSourceName,
    [Parameter(Mandatory)]
    [string]$VaultName,
    [Parameter(Mandatory)]
    [string]$csvFilePath,
    [Parameter(Mandatory)]
    [string]$logFilePath = ""
)

if ($null -eq (Get-Module -Name Devolutions.PowerShell)){
    Install-Module -Name Devolutions.PowerShell
}

Set-RDMCurrentDataSource -DataSource (Get-RDMDataSource -Name $DataSourceName)
Set-RDMCurrentVault -Vault (Get-RDMVault -Name $VaultName)

function Import-EntriesFromDelineaCsv {
    param (
        [String]$csvPath
    )
    
    # read and Import the csv File
    $Records = Import-Csv -LiteralPath $csvPath
    # variable to ensure we have everything to save the entry
   
    # init migration
    $readyToSave = $false
    # counter to identify the end
    $i = 0
    # Browse the file
    foreach($r in $Records){
    # define what the row is
    # what makes an ignore > All empty
    $i++
        If (('' -eq [string]$r.'Secret Name') -and 
            ('' -eq [string]$r.Domain) -and
            ('' -eq [string]$r.Username) -and
            ('' -eq [string]$r.Password) -and
            ('' -eq [string]$r.Notes) -and
            ('' -eq [string]$r.Folder)){            
        # don't do anything else    
        LogLine -Message "------- Empty Line ---------" -FilePath $logFilePath
        }

    # what makes it a new row:
    # secretname, username and password are filled
        ElseIf (('' -ne [string]$r.'Secret Name') -and 
            ('' -ne [string]$r.Username) -and 
            ('' -ne [string]$r.Password)){
            # new rew

            # New credential entry found - save the previous if ready to be saved
            if($readyToSave){
                Set-NewEntry -secretName $entryName -domain $entryDomain -username $entryUsername -password $entryPassword -notes $entryNotes -folder $entryFolder
                $readyToSave = $false
            }
            # assign values to variables - prepare entry
            $entryName = [string]$r.'Secret Name'
            $entryDomain = [string]$r.Domain
            $entryUsername = [string]$r.Username
            $entryPassword = ConvertTo-SecureString ([string]$r.Password) -AsPlainText
            # completely new note
            $entryNotes = [string]$r.Notes
            $entryFolder = [string]$r.Folder
            # indicate that this is technically ready to be saved
            $readyToSave = $true            
        }
        
    # what makes a continuation
    # secretname is filled (with a new Line of notes in username)
        elseif ('' -ne [string]$r.'Secret Name'){

            # the secretName is always filled with a continued note
            $entryNotes = $entryNotes + "`r`n" + $r.'Secret Name'
            # Username may be filled with what seems to be th folder
            If ('' -ne [string]$r.Username){
            # there is something, does it start with '\'
                If ([string]$r.Username -like "\*"){
                    $entryFolder = [string]$r.Username
                }
                else {
                    # not a folder indication
                    # add a note
                    $entryNotes = $entryNotes + "`r`n" + $r.Notes
                }
            }  
        }  
        # we need to attempt saving when at the very last row
        if($i -eq $records.Count){
            Set-NewEntry -secretName $entryName -domain $entryDomain -username $entryUsername -password $entryPassword -notes $entryNotes -folder $entryFolder
        }
    }

}

function Set-NewEntry {
    param (
        [string]$secretName,
        [string]$domain,
        [string]$username,
        [SecureString]$password,
        [string]$notes,
        [string]$folder
    )

    $newE = New-RDMEntry -Type Credential -Name $secretName
    $newE.Credentials.UserName = $username
    $newE.Credentials.Domain = $domain
    $newE.Description = $notes
    $newE.Group = $folder.TrimStart('\')

    if($folder -eq ''){
        # if folder empty, save at the root
        LogLine -FilePath $logFilePath -Message "Adding $secretname to the root. Values:`r`nSecretName: $secretName`r`ndomain: $domain`r`nUsnerame: $username`r`npassword: *******`r`nNotes: $notes`r`nFolder:Root" 
        Set-RDMEntry $newE        
    }
    else {
        Verify-FolderStructure -folderPath $folder
        LogLine -FilePath $logFilePath -Message "Adding $secretname to the folder $folder. Values:`r`nSecretName: $secretName`r`ndomain: $domain`r`nUsnerame: $username`r`npassword: *******`r`nNotes: $notes`r`nFolder:$folder" 
    }
    Set-RDMEntryPassword -InputObject $newE -Password $password -Set
}

function Verify-FolderStructure {
    param (
        [string]$folderPath
    )
    $folderPath = $folderPath.TrimStart('\')
    $structure = $folderPath -split '\\'
    
    $current = ""
    foreach($f in $structure){
        if ($current -eq ""){
            $current = $f
        }
        else {
            $current = $current + '\' + $f
        }
        
        $exists = Get-RDMEntry -Name $f -GroupName $current
        if ($null -eq $exists)
        {
            #Folder does not exists, create
            New-Folder -folderName $f -folderPath $current

        }

    }   
}
function New-Folder {
    param (
        [string]$folderName,
        [string]$folderPath
    )
    # Create a folder in the given tree
    # if the path is the same as the name > Root
    
    if ($folderName -eq $folderPath) {
        LogLine -FilePath $logFilePath -Message "[Folder] Creating $FolderName at the [Root]"
        $nf = New-RDMEntry -Name $folderName -Type Group -Set
    }
    else {
        LogLine -FilePath $logFilePath -Message "[Folder] Creating $FolderName in [$FolderPath]"
        $nf = New-RDMEntry -Name $folderName -Type Group -Group $folderPath -Set
    }

}

function LogLine {    
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$FilePath = ""
    )
    Write-Host -ForegroundColor Yellow $Message
    if ($FilePath -ne ""){
        Add-Content -Path $FilePath -Value $Message
    }
}

Import-EntriesFromDelineaCsv -csvPath $csvFilePath