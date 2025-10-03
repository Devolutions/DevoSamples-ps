<#
.SYNOPSIS
  Exports folder permissions for every vault (or a specific vault) in Remote Desktop Manager (RDM) to a CSV file.

.DESCRIPTION
  Ensures the Devolutions.PowerShell module is available, switches to the requested data source, and iterates through
  vaults and folders (optionally filtered by depth). For each folder it captures role overrides and detailed permission
  assignments, emitting them to a CSV that conforms to the documented column layout.

  Provide the target data source, output file path, and optional log/vault/depth parameters when invoking the script.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if needed.
  - Use the `-Verbose` switch alongside `-logFileName` for a detailed transcript of the export process.

.EXAMPLE
  PS> .\Export-RDMPermissions.ps1 -dsName 'MyDataSource' -fileName 'C:\Temp\permissions.csv' -Verbose
  Captures permissions for every vault and writes them to the specified CSV while logging verbose output.

.LINK
  https://powershell.devolutions.net/
#>

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

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Seed the output file with the required CSV header row.
Set-Content -Path $filename -Value '"Vault","Folder","RoleOverride","ViewRoles","Add","Edit","Move","Delete","ViewPassword","Execute","EditSecurity","ConnectionHistory","PasswordHistory","Remotetools","Inventory","Attachment","EditAttachment","Handbook","EditHandbook","EditInformation"'
# $createCSV = {} | Select "Vault","Folder","RoleOverride","ViewRoles","Add","Edit","Delete","ViewPassword","Execute","EditSecurity","ConnectionHistory","PasswordHistory","Remotetools","Inventory","Attachment","EditAttachment","Handbook","EditHandbook","EditInformation" | Export-Csv $fileName
# $csvFile = Import-Csv $fileName

# Switch to the requested data source so repository calls execute in the correct context.
$ds = Get-RDMDataSource -Name $dsName
Set-RDMCurrentDataSource $ds

# Optionally capture a transcript when a log file path is provided.
if (-not [string]::IsNullOrEmpty($logFileName))
{
    Start-Transcript -Path $logFileName -Force
}

# Scope the export to a single vault when requested; otherwise enumerate all vaults.
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
        # Limit folder enumeration to the requested depth (0-based index, so subtract one from desired level).
        $folders = Get-RDMSession | where {$_.ConnectionType -eq "Group" -and (($_.Group).Split("\").GetUpperBound(0) -le ($folderLevel - 1))}
    }
    else
    {
        # No depth constraint; include every folder entry in the vault.
        $folders = Get-RDMSession | where {$_.ConnectionType -eq "Group"}
    }
    
    foreach ($folder in $folders)
    {
        # Pre-populate the CSV row with base metadata and blank permission slots.
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
            # Record the view override directly or expand explicit roles/users into a semicolon-separated string.
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
                # Write the resolved role/user list into the matching permission column.
                $csvFile."$permission" = $permroles
            }
        }
        
        # Append the row to the destination CSV file.
        $csvFile | Export-Csv $fileName -Append
        Write-Verbose "Permissions exported for folder $folder..."
    }

    Write-Verbose "Permissions exported for vault $vault..."
}

Write-Host "Done!!!"

# Stop the transcript if one was started earlier.
if (-not [string]::IsNullOrEmpty($logFileName))
{
    Stop-Transcript
}
