<#
.SYNOPSIS
  Updates root and top-level folder permissions (view rights) within a Remote Desktop Manager (RDM) vault.

.DESCRIPTION
  This script ensures the Devolutions.PowerShell module is available, targets a data source, and adjusts security
  for the vault root entry plus every top-level folder. It switches their security configuration to `Custom` and
  applies the specified security group to the `View` role override.

  Customize the data source, vault name, and group identifier before running the script.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if missing.
  - Replace placeholder values such as `NameOfYourDataSourceHere`, `vault_name`, and `group_name` with real values.

.EXAMPLE
  PS> .\ChangeRootAndFolderPermissions.ps1
  Applies the configured group to view permissions on the target vault root and its top-level folders.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the data source that hosts the vault whose permissions you want to modify.
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Synchronize the UI/cache so subsequent queries run against the chosen data source.
Update-RDMUI

# Retrieve the vault to confirm it exists; replace the placeholder with the desired vault name.
$vault = Get-RDMVault "vault_name"

# Name of the security group that should receive view rights.
$group = "group_name"

# Apply custom view permissions to the vault root entry.
$rdmRoot = Get-RDMRootSession
$rdmRoot.Security.RoleOverride = "Custom"
$rdmRoot.Security.ViewOverride = "Custom"
$rdmRoot.Security.ViewRoles = $group
$rdmRoot | Set-RDMRootSession

# Collect only top-level folders (their group path matches their name) for consistent permission updates.
$entries = Get-RDMSession | Where-Object { $_.Group -eq $_.Name }

foreach ($entry in $entries) {
    # Assign the same custom view permissions to each top-level folder.
    $entry.Security.RoleOverride = "Custom"
    $entry.Security.ViewOverride = "Custom"
    $entry.Security.ViewRoles = $group
    Set-RDMSession -Refresh -Session $entry
}

# Final refresh so the RDM UI reflects the updated permissions immediately.
Update-RDMUI
