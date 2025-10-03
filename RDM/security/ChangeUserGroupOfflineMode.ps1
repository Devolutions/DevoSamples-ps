<#
.SYNOPSIS
  Sets the offline mode for one or more Remote Desktop Manager (RDM) security roles.

.DESCRIPTION
  This script ensures the Devolutions.PowerShell module is available, selects a data source, and updates the
  `CustomSecurity` XML of a target user group (role) to match the requested offline mode:
  - `disabled` removes offline access entirely.
  - `readonly` leaves the XML empty, allowing cache-only viewing.
  - `readwrite` enables offline edits.

  Adjust the data source name, target role, and `$offlineMode` variable before running the script.

.NOTES
  - Requires the Devolutions.PowerShell module; installs it if missing.
  - Only modifies the `CustomSecurity` XML for the specified role; expand logic if you need to handle multiple roles.

.EXAMPLE
  PS> $offlineMode = 'readwrite'
  PS> .\ChangeUserGroupOfflineMode.ps1
  Enables offline edit mode for the role identified in the script.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the data source whose security role you intend to update.
$ds = Get-RDMDataSource -Name 'NameOfYourDataSourceHere'
Set-RDMCurrentDataSource $ds

# Choose the desired offline mode: 'disabled', 'readonly', or 'readwrite'.
$offlineMode = 'readonly'

# Retrieve the security role (user group) you want to modify.
$roleName = 'ChangedFromPowershell'
$role = Get-RDMRole -Name $roleName

# Parse the existing CustomSecurity XML so we can adjust its contents safely.
[xml]$customSecurityXml = $role.CustomSecurity

# Clear existing child nodes to ensure the new offline mode settings are applied cleanly.
if ($customSecurityXml.ChildNodes.Count -gt 0) {
    $customSecurityXml.CustomSecurity.RemoveAll()
}

# Populate the XML based on the requested offline mode.
switch ($offlineMode.ToLower()) {
    'disabled' {
        $allowOfflineCaching = $customSecurityXml.CreateElement('AllowOfflineCaching')
        $allowOfflineCaching.InnerText = 'false'
        $customSecurityXml.DocumentElement.AppendChild($allowOfflineCaching) | Out-Null

        $allowOfflineMode = $customSecurityXml.CreateElement('AllowOfflineMode')
        $allowOfflineMode.InnerText = 'false'
        $customSecurityXml.DocumentElement.AppendChild($allowOfflineMode) | Out-Null
    }
    'readwrite' {
        $allowOfflineEdit = $customSecurityXml.CreateElement('AllowOfflineEdit')
        $allowOfflineEdit.InnerText = 'true'
        $customSecurityXml.DocumentElement.AppendChild($allowOfflineEdit) | Out-Null
    }
    'readonly' {
        # No additional XML required; leaving the node empty enables read-only cache access.
    }
    default {
        throw "Unsupported offline mode: $offlineMode. Use 'disabled', 'readonly', or 'readwrite'."
    }
}

# Persist the updated CustomSecurity XML back to the role.
Set-RDMRoleProperty -Role $role -Property 'CustomSecurity' -Value $customSecurityXml.InnerXml
Set-RDMRole $role

Write-Host "Offline mode for role '$roleName' set to '$offlineMode'." -ForegroundColor Yellow
