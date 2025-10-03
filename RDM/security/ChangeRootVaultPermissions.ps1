<#
.SYNOPSIS
  Applies a predefined permission set to the root of each Remote Desktop Manager (RDM) vault.

.DESCRIPTION
  This script ensures the Devolutions.PowerShell module is available, switches to the desired data source, and updates
  the root entry permissions using a customizable hash table. By default it sets add/edit/delete/execute/security
  operations to `Default` and view/password/history permissions to `Everyone`, but you can adjust the mappings before running it.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if missing.
  - Customize `NameOfYourDataSourceHere` and tweak the `$setPermissions` hash to reflect your security policy.

.EXAMPLE
  PS> .\ChangeRootVaultPermissions.ps1
  Updates the current data source so each vault root inherits the specified permission set.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the data source whose root permissions need to be refreshed.
$ds = Get-RDMDataSource -Name 'NameOfYourDataSourceHere'
Set-RDMCurrentDataSource $ds

# Retrieve the root entry that controls permissions for the active data source.
$rdmRoot = Get-RDMRootSession

# Define the overrides you want to apply; adjust the map as required.
$setPermissions = @{
    'Add'              = 'Default'
    'Edit'             = 'Default'
    'Delete'           = 'Default'
    'Execute'          = 'Default'
    'EditSecurity'     = 'Default'
    'ViewPassword'     = 'Everyone'
    'PasswordHistory'  = 'Everyone'
    'ConnectionHistory'= 'Everyone'
}

# Translate the permission hash into the strongly typed structure expected by RDM.
$properties = @()
foreach ($perm in $setPermissions.GetEnumerator()) {
    $properties += New-Object PSObject -Property @{
        Override   = $perm.Value
        Right      = $perm.Name
        Roles      = @('')
        RoleValues = ''
    }
}

# Apply the custom permission set to the root and persist the change.
$rdmRoot.Security.RoleOverride = 'Custom'
$rdmRoot.Security.Permissions = $properties
$rdmRoot | Set-RDMRootSession

# Refresh so the UI reflects the updated security settings.
Update-RDMUI
