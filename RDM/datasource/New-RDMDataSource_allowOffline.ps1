<#
.SYNOPSIS
  Creates a new SQL Server-based Remote Desktop Manager (RDM) data source and enables offline capabilities.

.DESCRIPTION
  This script uses the Devolutions.PowerShell module to:
  - Create a new RDM data source targeting a SQL Server database.
  - Enable offline features so users can work when disconnected:
      • AutoGoOffline: RDM automatically switches to offline mode when needed.
      • AllowOfflineMode: Allows the data source to be taken offline.
      • AllowOfflineEdit: Allows editing entries while offline.
  - Save the data source configuration.

  Replace the placeholder values for `-Server`, `-Database`, and `-Name` with your environment details before running.

.NOTES
  - Requires the Devolutions.PowerShell module. If not present, the script attempts to install it for the current user.
  - Installing modules may require an internet connection and a trusted PSGallery repository.
  - Run within a context that has permissions to create/configure RDM data sources.

.EXAMPLE
  PS> .\New-RDMDataSource_allowOffline.ps1
  Creates a data source (with your replaced values) and enables offline features.

.LINK
  https://forum.devolutions.net/topics/33589/how-to-set-properties-on-data-source-using-powershell
#>

# Ensure the Devolutions PowerShell module is available; install if missing.
# Note: Installation targets the current user scope to avoid requiring admin privileges.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Create a new SQL Server-backed RDM data source. Replace placeholders:
#   -Server  : SQL Server hostname or instance (e.g., "SQL01" or "SQL01\\INSTANCE").
#   -Database: RDM database name (must already exist unless you plan to initialize separately).
#   -Name    : Friendly display name for this data source in RDM.
#   -IntegratedSecurity: Uses Windows Integrated Authentication for the SQL connection.
$ds = New-RDMDataSource -SQLServer -Server YourSQLServer -Database YourSQLDatabase -Name YourDataSourceName -IntegratedSecurity

# Enable automatic offline switch when connectivity is lost.
Set-RDMDatasourceProperty -DataSource $ds -Property AutoGoOffline   -Value $true

# Allow users to take the data source offline.
Set-RDMDatasourceProperty -DataSource $ds -Property AllowOfflineMode -Value $true

# Allow editing entries while offline (changes will sync when reconnected).
Set-RDMDatasourceProperty -DataSource $ds -Property AllowOfflineEdit -Value $true

# Persist the changes to the data source configuration in RDM.
Set-RDMDataSource $ds
