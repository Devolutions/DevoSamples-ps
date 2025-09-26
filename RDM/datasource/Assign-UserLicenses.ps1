<#
.SYNOPSIS
  Assigns a Remote Desktop Manager (RDM) license to a user by serial number.

.DESCRIPTION
  This script leverages the Devolutions.PowerShell module to:
  - Select the RDM data source that holds your users and licenses via `Get-RDMDataSource`.
  - Resolve the target user with `Get-RDMUser`.
  - Retrieve the license identified by its serial using `Get-RDMLicense`.
  - Enable the user's membership on that license and persist the change with `Set-RDMLicense`.

.NOTES
  - Requires the Devolutions.PowerShell module. The script installs it for the current user if missing.
  - Ensure you replace the placeholder data source name with one that exists in your environment.

.EXAMPLE
  PS> .\Assign-UserLicenses.ps1
  Loads the helper function so you can run `Set-LicenseSerialToUser -Serial "XXXX" -UserName "jdoe"`.
#>

# Ensure the Devolutions.PowerShell module is available so Get-RDM* cmdlets can be used.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the Remote Desktop Manager data source that contains the target users and licenses.
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

function Set-LicenseSerialToUser(
    [String]
    $Serial,
    [String]
    $UserName    
)
{
    # Resolve the Remote Desktop Manager user object from the current data source.
    $User = Get-RDMUser -Name $UserName

    # Retrieve the license object that matches the provided serial number.
    $License = Get-RDMLicense -Serial $Serial

    # Enable the user's membership for the retrieved license.
    $userlicense = $License.Users | Where-Object{$_.UserID -eq $User.ID}
    $userlicense.IsMember = $True

    # Persist the updated license assignment back to the data source.
    Set-RDMLicense -License $License
}
