#requires -version 4

<#
.SYNOPSIS
  Bulk-creates Remote Desktop Manager (RDM) SQL users from a CSV list of Active Directory accounts.

.DESCRIPTION
  This script ensures the Devolutions.PowerShell module is available, connects to a specified SQL data source,
  and processes `user_input.csv` located alongside the script. For each record it:
  - Builds display name, UPN, and optional NetBIOS login formats.
  - Creates an RDM SQL user that leverages integrated security.
  - Assigns first name, last name, and email before persisting the account.

  Update the data source name, CSV path, and domain-specific placeholders before running the script.

.NOTES
  - The CSV must include at least `Firstname`, `Lastname`, and `Maildomain`; add `SamAccountName` if you intend to use NetBIOS logins.
  - Original reference: https://forum.devolutions.net/topics/34454/changing-different-properties-on-sessions

.EXAMPLE
  PS> .\BulkSQLUserCreation.ps1
  Adds SQL users to the configured data source using entries from `user_input.csv`.

.LINK
  https://powershell.devolutions.net/
#>

# ------------------------------[Initialisation]------------------------------

# Surface non-terminating errors in a more predictable manner during batch execution.
$ErrorActionPreference = 'SilentlyContinue'

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# -------------------------------[Execution]----------------------------------

# Connect to the SQL data source that hosts the users you want to manage.
$ds = Get-RDMDataSource -Name 'YourSQLDataSourceNameHere'
Set-RDMCurrentDataSource $ds
Update-RDMUI

# Load the CSV of user records that will be provisioned.
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$csvPath = Join-Path $scriptDirectory 'user_input.csv'
$csv = Import-Csv -Path $csvPath

foreach ($user in $csv) {
    $displayName = "$($user.Firstname) $($user.Lastname)"
    $email = "$($user.Firstname).$($user.Lastname)@$($user.Maildomain)"

    # Replace the domain below or derive it from $user.SamAccountName if present in the CSV.
    $netBios = "YourDomain\\$($user.SamAccountName)"

    try {
        # Example for NetBIOS login format; uncomment if your environment requires it.
        # $newUser = New-RDMUser -Login $netBios -Email $email -AuthentificationType SqlServer -IntegratedSecurity

        # Default to the UPN format when creating the SQL user entry.
        $newUser = New-RDMUser -Login $email -Email $email -AuthentificationType SqlServer -IntegratedSecurity
        $newUser.UserType = 'User'
        $newUser.FirstName = $user.Firstname
        $newUser.LastName = $user.Lastname
        Set-RDMUser -User $newUser

        Write-Host "$displayName created"
    }
    catch {
        Write-Host "Unable to create user $displayName"
    }
}

Write-Host 'Done!'

# ----------------------------------[Closure]---------------------------------
# Prompt for a key press when the script runs directly in the console host.
if ($Host.Name -eq 'ConsoleHost') {
    Write-Host 'Press any key to continue...'
    $Host.UI.RawUI.FlushInputBuffer()
    $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyUp') > $null
}
