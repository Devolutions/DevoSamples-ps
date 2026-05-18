<#FRONTMATTER
id: New-RDMSampleSQLServerDataSource
title: New-RDMSampleSQLServerDataSource
product: RDM
category: datasource
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
  - New-RDMDataSource
  - Set-RDMDatasourceProperty
  - Set-RDMDataSource
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
  - datasource
  - sqlserver
  - offline
author: ''
last_updated: 2026-05-18
FRONTMATTER#>

<#
.SYNOPSIS
Create a SQL Server-backed RDM data source with offline mode enabled.

.DESCRIPTION
Provides New-RDMSampleSQLServerDataSource, which:
- Creates a new RDM data source pointing at a SQL Server database, using
  Windows Integrated Authentication for the connection.
- Enables the three offline capabilities on the data source:
    AutoGoOffline    — automatically switch to offline mode when connectivity
                       to the SQL Server is lost.
    AllowOfflineMode — let users take the data source offline manually.
    AllowOfflineEdit — let users edit entries while offline; changes sync on
                       reconnect.
- Persists the configuration via Set-RDMDataSource.

.PARAMETER Name
Display name for the new data source as it appears in RDM.

.PARAMETER Server
SQL Server hostname or instance (e.g. "SQL01" or "SQL01\INSTANCE").

.PARAMETER Database
Name of the existing SQL Server database backing the RDM data source.

.EXAMPLE
New-RDMSampleSQLServerDataSource -Name "Production" -Server "SQL01" -Database "RDMDB"

.NOTES
Uses Windows Integrated Authentication. Run from a context that has SQL
permissions to read/write the target database.

.LINK
https://forum.devolutions.net/topics/33589/how-to-set-properties-on-data-source-using-powershell
#>

function New-RDMSampleSQLServerDataSource
{
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Server,
        [Parameter(Mandatory)][string]$Database
    )

    Import-Module Devolutions.PowerShell -ErrorAction Stop

    $dataSource = New-RDMDataSource -SQLServer -Server $Server -Database $Database -Name $Name -IntegratedSecurity

    Set-RDMDatasourceProperty -DataSource $dataSource -Property AutoGoOffline    -Value $true
    Set-RDMDatasourceProperty -DataSource $dataSource -Property AllowOfflineMode -Value $true
    Set-RDMDatasourceProperty -DataSource $dataSource -Property AllowOfflineEdit -Value $true

    Set-RDMDataSource $dataSource
}
