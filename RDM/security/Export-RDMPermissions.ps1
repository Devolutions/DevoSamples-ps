##########
#
# Object : Export folders' permissions of all vaults
#
# Parameters   :
# $dsName      : Name of the RDM data source.
# $fileName    : Name and full path of the exported CSV file.
# $logFileName : Name and full path of the log file. To be used with the -Verbose switch for maximum log information.
# $vaultName   : Name of a vault we want to export the permissions.
# $folderLevel : Depth of the folders' level we want to get the permissions (None for all folders, 1 for root folders, 2 for root and first subfolders, etc).
#
# CSV file headers
# Vault             : Name of the Vault
# Folder            : Folder full path (no leading or trailing "\")
# RoleOverride      : Default, Everyone, Never or Custom
# ViewRoles         : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Add               : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Edit              : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Delete            : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# ViewPassword      : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# ViewSensitiveInformation : Default, Everyone, Never or list of Roles and/or Users separated with ";" 
# Execute           : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# EditSecurity      : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# ConnectionHistory : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# PasswordHistory   : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Remotetools       : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Inventory         : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Attachment        : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# EditAttachment    : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# Handbook          : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# EditHandbook      : Default, Everyone, Never or list of Roles and/or Users separated with ";"
# EditInformation   : Default, Everyone, Never or list of Roles and/or Users separated with ";"

param (
    [Parameter(Mandatory=$True,Position=1)]
    [string]$dsName,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$fileName,
    [Parameter(Mandatory=$false,Position=3)]
    [string]$logFileName,
    [Parameter(Mandatory=$false,Position=3)]
    [string]$vaultName,
    [Parameter(Mandatory=$false,Position=3)]
    [string]$folderLevel
    )

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# CSV file creation
Set-Content -Path $filename -Value '"Vault","Folder","RoleOverride","ViewRoles","Add","Edit","Move","Delete","ViewPassword","Execute","EditSecurity","ConnectionHistory","PasswordHistory","Remotetools","Inventory","Attachment","EditAttachment","Handbook","EditHandbook","EditInformation"'
# $createCSV = {} | Select "Vault","Folder","RoleOverride","ViewRoles","Add","Edit","Delete","ViewPassword","Execute","EditSecurity","ConnectionHistory","PasswordHistory","Remotetools","Inventory","Attachment","EditAttachment","Handbook","EditHandbook","EditInformation" | Export-Csv $fileName
# $csvFile = Import-Csv $fileName

# Set the data source
$ds = Get-RDMDataSource -Name $dsName
Set-RDMCurrentDataSource $ds

if (-not [string]::IsNullOrEmpty($logFileName))
{
    Start-Transcript -Path $logFileName -Force
}

if (-not [string]::IsNullOrEmpty($vaultName))
{
    $vaults = Get-RDMRepository -Name $vaultName
}
else
{
    $vaults = Get-RDMRepository
}

foreach ($vault in $vaults)
{
    # Set the default vault
    # $vault = Get-RDMRepository -Name $vault
    Set-RDMCurrentRepository $vault
    $vaultName = $vault.Name
    Write-Verbose "Vault $vaultName selected..."
    
    if (-not [string]::IsNullOrEmpty($folderLevel))
    {
        $folders = Get-RDMSession | where {$_.ConnectionType -eq "Group" -and (($_.Group).Split("\").GetUpperBound(0) -le ($folderLevel - 1))}
    }
    else
    {
        $folders = Get-RDMSession | where {$_.ConnectionType -eq "Group"}
    }
    
    foreach ($folder in $folders)
    {
        $csvFile = [PSCustomObject]@{
            Vault = $vaultName
            Folder = $folder.Group
            RoleOverride = $folder.Security.RoleOverride
            ViewRoles = ""
            Add = ""
            Edit = ""
            Move = ""
            Delete = ""
            ViewPassword = ""
            ViewSensitiveInformation = ""
            Execute = ""
            EditSecurity = ""
            ConnectionHistory = ""
            PasswordHistory = ""
            RemoteTools = ""
            Inventory = ""
            Attachment = ""
            EditAttachment = ""
            Handbook = ""
            EditHandbook = ""
            DeleteHandbook = ""
            EditInformation = ""
        }
        
        if ($csvFile.RoleOverride -eq "Custom")
        {
            if ($folder.Security.ViewOverride -in "Everyone", "Default", "Never")
            {
                $csvFile.ViewRoles = $folder.Security.ViewOverride
            }
            else 
            {
                $csvFile.ViewRoles = ($folder.Security.ViewRoles -join ";")
            }

            $folderPermissions = $folder.Security.Permissions
            foreach ($folderPermission in $folderPermissions)
            {
                $permission = $folderPermission.Right
                $permroles = $folderPermission.RoleValues
                $permroles = $permroles -replace [Regex]::Escape(","), "; "
                $csvFile."$permission" = $permroles
            }
        }
        
        $csvFile | Export-Csv $fileName -Append
        Write-Verbose "Permissions exported for folder $folder..."
    }

    Write-Verbose "Permissions exported for vault $vault..."
}

Write-Host "Done!!!"

if (-not [string]::IsNullOrEmpty($logFileName))
{
    Stop-Transcript
}
