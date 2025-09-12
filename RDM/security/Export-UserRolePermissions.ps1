##########
#
# Object : Export entries' permissions of all vaults for a given user or user group.
#
# Parameters   :
# $dsName      : Name of the RDM data source.
# $fileName    : Name and full path of the exported CSV file.
# $logFileName : Name and full path of the log file. To be used with the -Verbose switch for maximum log information.
# $vaultName   : Name of a vault we want to export the permissions.
# $folderLevel : Depth of the folder' level we want to get the permissions (None for all entries, 1 for root folder, 2 for root and first subfolder, etc).
# $objecttype  : Type of object (between Folders, Entries or All) this script pull out the permissions from.
#
# CSV file headers
# Vault             : Name of the Vault
# Folder            : Folder full path (no leading or trailing "\")
# Entry             : Name of the entry (a leading "\" specifies a folder entry type)
# Permission        : Default, Everyone, Never or Custom
# ViewRoles         : True, Inherited
# Add               : True, Inherited
# Edit              : True, Inherited
# Delete            : True, Inherited
# ViewPassword      : True, Inherited
# ViewSensitiveInformation : True, Inherited 
# Execute           : True, Inherited
# EditSecurity      : True, Inherited
# ConnectionHistory : True, Inherited
# PasswordHistory   : True, Inherited
# Remotetools       : True, Inherited
# Inventory         : True, Inherited
# Attachment        : True, Inherited
# EditAttachment    : True, Inherited
# Handbook          : True, Inherited
# EditHandbook      : True, Inherited
# DeleteHandbook    : True, Inherited
# EditInformation   : True, Inherited

param (
    [Parameter(Mandatory=$True,Position=1)]
    [string]$dsName,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$fileName,
    [Parameter(Mandatory=$true,Position=3)]
    [string]$UserRolename, 
    [Parameter(Mandatory=$false,Position=4)]
    [string]$logFileName,
    [Parameter(Mandatory=$false,Position=4)]
    [string]$vaultName,
    [Parameter(Mandatory=$false,Position=4)]
    [string]$folderLevel,
    [Parameter(Mandatory=$false,Position=4)]
    [ValidateSet("All","Entries","Folders")]
    [string]$objectType = "All"
    )

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# CSV file creation
Set-Content -Path $filename -Value '"Vault","Folder","Entry","Permission","View","Add","Edit","Move","Delete","ViewPassword","Execute","EditSecurity","ConnectionHistory","PasswordHistory","Remotetools","Inventory","Attachment","EditAttachment","Handbook","EditHandbook","DeleteHandbook","EditInformation"'


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

$UserorRole = Get-RDMUser -Name $UserRolename -ErrorAction SilentlyContinue -InformationAction SilentlyContinue -WarningAction SilentlyContinue
if ([string]::IsNullOrEmpty($UserorRole))
{
    $UserorRole = Get-RDMRole -Name $UserRolename
}

foreach ($vault in $vaults)
{
    # Set the default vault
    # $vault = Get-RDMRepository -Name $vault
    Set-RDMCurrentRepository $vault
    $vaultName = $vault.Name
    Write-Verbose "Vault $vaultName selected..."
    
    switch ($objectType) {
        "All" {
            if (-not [string]::IsNullOrEmpty($folderLevel))
            {
                $entries = Get-RDMSession | where {(($_.Group).Split("\").GetUpperBound(0) -le ($folderLevel - 1))}
            }
            else
            {
                $entries = Get-RDMSession
            }
            break   
        }
        "Entries"
        {
            if (-not [string]::IsNullOrEmpty($folderLevel))
            {
                $entries = Get-RDMSession | where {$_.ConnectionType -ne "Group" -and (($_.Group).Split("\").GetUpperBound(0) -le ($folderLevel - 1))}
            }
            else
            {
                $entries = Get-RDMSession | where {$_.ConnectionType -ne "Group"}
            }
            break
        }
        "Folders"
        {
            if (-not [string]::IsNullOrEmpty($folderLevel))
            {
                $entries = Get-RDMSession | where {$_.ConnectionType -eq "Group" -and (($_.Group).Split("\").GetUpperBound(0) -le ($folderLevel - 1))}
            }
            else
            {
                $entries = Get-RDMSession | where {$_.ConnectionType -eq "Group"}
            }
            break
        }  
        Default {}
    }
    
    foreach ($entry in $entries)
    {
        $csvFile = [PSCustomObject]@{
            Vault = $vaultName
            Folder = $entry.Group
            Entry = $entry.Name
            Permission = "False"
            View = ""
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

        If ($entry.ConnectionType -eq "Group")
        {
            $csvfile.Entry = "\" + $entry.Name
        }
        
        $csvFile.Permission = $entry.Security.RoleOverride
        if ($entry.Security.RoleOverride -eq "Custom")
        {
            if ($entry.Security.ViewOverride -in "Everyone", "Default")
            {
                $csvFile.View = $entry.Security.ViewOverride
            }
            elseif ($entry.Security.ViewOverride -eq "Custom")
            {
                if ($UserorRole.ID -in $entry.Security.ViewRoles)
                {
                    $csvFile.View = "True"
                }
                else 
                {
                    $csvFile.View = "False"
                }
            }

            $entryPermissions = $entry.Security.Permissions
            foreach ($entryPermission in $entryPermissions)
            {
                $permission = $entryPermission.Right
                $permroles = $entryPermission.RoleValues
                $permroles = $permroles -replace [Regex]::Escape(","), "; "
                if ($UserorRole.ID -in $permroles -or $entryPermissions.Override -eq "Everyone")
                {
                    $csvFile."$permission" = "True"
                }
            }
        }
        elseif ($entry.Security.RoleOverride -eq "Everyone")
        {
            $csvFile.View = "True"
            $csvFile.Add = "True"
            $csvFile.Edit = "True"
            $csvFile.Move = "True"
            $csvFile.Delete = "True"
            $csvFile.ViewPassword = "True"
            $csvFile.ViewSensitiveInformation = "True"
            $csvFile.Execute = "True"
            $csvFile.EditSecurity = "True"
            $csvFile.ConnectionHistory = "True"
            $csvFile.PasswordHistory = "True"
            $csvFile.RemoteTools = "True"
            $csvFile.Inventory = "True"
            $csvFile.Attachment = "True"
            $csvFile.EditAttachment = "True"
            $csvFile.Handbook = "True"
            $csvFile.EditHandbook = "True"
            $csvFile.DeleteHandbook = "True"
            $csvFile.EditInformation = "True"
        }
        elseif ($entry.Security.RoleOverride -eq "Default")
        {
            $csvFile.View = "Inherited"
            $csvFile.Add = "Inherited"
            $csvFile.Edit = "Inherited"
            $csvFile.Move = "Inherited"
            $csvFile.Delete = "Inherited"
            $csvFile.ViewPassword = "Inherited"
            $csvFile.ViewSensitiveInformation = "Inherited"
            $csvFile.Execute = "Inherited"
            $csvFile.EditSecurity = "Inherited"
            $csvFile.ConnectionHistory = "Inherited"
            $csvFile.PasswordHistory = "Inherited"
            $csvFile.RemoteTools = "Inherited"
            $csvFile.Inventory = "Inherited"
            $csvFile.Attachment = "Inherited"
            $csvFile.EditAttachment = "Inherited"
            $csvFile.Handbook = "Inherited"
            $csvFile.EditHandbook = "Inherited"
            $csvFile.DeleteHandbook = "Inherited"
            $csvFile.EditInformation = "Inherited"
        }
        
        # Filter to provide only entries with View Password or Execute direct or inherited permissions 
        if ($csvfile.Execute -eq "True" -or $csvfile.Execute -eq "Inherited" -or $csvfile.ViewPassword -eq "True" -or $csvfile.ViewPassword -eq "Inherited")
        {
            $csvFile | Export-Csv $fileName -Append
            Write-Verbose "Permissions exported for entry $entry..."
        }
    }

    Write-Verbose "Permissions exported for vault $vault..."
}

Write-Host "Done!!!"

if (-not [string]::IsNullOrEmpty($logFileName))
{
    Stop-Transcript
}
