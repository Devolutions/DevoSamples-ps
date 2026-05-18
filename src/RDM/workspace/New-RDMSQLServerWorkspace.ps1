<#FRONTMATTER
id: New-RDMSQLServerWorkspace
title: New-RDMSQLServerWorkspace
product: RDM
category: workspace
script_version: 0.1.0
status: active
targets:
  devolutions_powershell:
    min: 2024.3.0
    tested_up_to: 2026.1.0
  rdm:
    min: 2024.1
    tested_up_to: 2026.1
cmdlets:
  - New-RDMWorkspace
  - Set-RDMWorkspaceProperty
  - Set-RDMWorkspace
params:
  - name: Name
    type: string
    mandatory: true
  - name: Server
    type: string
    mandatory: true
  - name: Database
    type: string
    mandatory: true
tags:
  - workspace
  - sqlserver
  - offline
author: ''
last_updated: 2026-05-18
FRONTMATTER#>

<#
.SYNOPSIS
Create a SQL Server-backed RDM workspace with offline mode enabled.

.DESCRIPTION
Provides New-RDMSQLServerWorkspace, which:
- Creates a new RDM workspace (formerly "data source") pointing at a SQL
  Server database, using Windows Integrated Authentication for the
  connection.
- Enables the three offline capabilities on the workspace:
    AutoGoOffline    — automatically switch to offline mode when connectivity
                       to the SQL Server is lost.
    AllowOfflineMode — let users take the workspace offline manually.
    AllowOfflineEdit — let users edit entries while offline; changes sync on
                       reconnect.
- Persists the configuration via Set-RDMWorkspace.

.PARAMETER Name
Display name for the new workspace as it appears in RDM.

.PARAMETER Server
SQL Server hostname or instance (e.g. "SQL01" or "SQL01\INSTANCE").

.PARAMETER Database
Name of the existing SQL Server database backing the RDM workspace.

.EXAMPLE
New-RDMSQLServerWorkspace -Name "Production" -Server "SQL01" -Database "RDMDB"

.NOTES
Uses Windows Integrated Authentication. Run from a context that has SQL
permissions to read/write the target database.

`New-RDMWorkspace` is the canonical cmdlet; `New-RDMDataSource` is kept
as an alias for backward compatibility. The script avoids the one-liner
`-Set` switch on `New-RDMWorkspace` because the three offline properties
must be applied before the workspace is persisted.

.LINK
https://forum.devolutions.net/topics/33589/how-to-set-properties-on-data-source-using-powershell
#>

function New-RDMSQLServerWorkspace
{
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Database
    )

    Import-Module Devolutions.PowerShell -ErrorAction Stop

    $workspace = New-RDMWorkspace -SQLServer -Server $Server -Database $Database -Name $Name -IntegratedSecurity

    Set-RDMWorkspaceProperty -Workspace $workspace -Property AutoGoOffline    -Value $true
    Set-RDMWorkspaceProperty -Workspace $workspace -Property AllowOfflineMode -Value $true
    Set-RDMWorkspaceProperty -Workspace $workspace -Property AllowOfflineEdit -Value $true

    Set-RDMWorkspace $workspace
}
