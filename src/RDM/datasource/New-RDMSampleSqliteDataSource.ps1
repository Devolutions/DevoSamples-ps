<#FRONTMATTER
id: New-RDMSampleSqliteDataSource
title: New-RDMSampleSqliteDataSource
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
  - New-RDMSqliteDataSource
  - Get-RDMDataSource
  - Set-RDMCurrentDataSource
params:
  - name: Name
    type: string
    mandatory: true
  - name: DatabasePath
    type: string
    mandatory: true
tags:
  - datasource
  - sqlite
author: ''
last_updated: 2026-05-18
FRONTMATTER#>

<#
.SYNOPSIS
Create a SQLite data source (no master password) and make it the active one.

.DESCRIPTION
Provides New-RDMSampleSqliteDataSource, which registers a new RDM data source
backed by a SQLite database file. The data source is created without a master
password (sessions stored unencrypted at rest) and is set as the current data
source on success.

.PARAMETER Name
Display name for the new data source. Must be unique within RDM.

.PARAMETER DatabasePath
Full path to the SQLite .db file. The file is created if it does not exist.

.EXAMPLE
New-RDMSampleSqliteDataSource -Name "Local Sandbox" -DatabasePath "C:\rdm\sandbox.db"

.NOTES
SQLite data sources without a master password are intended for personal /
sandbox use. Do not store production credentials in an unencrypted store.
#>

function New-RDMSampleSqliteDataSource
{
    param (
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$DatabasePath
    )

    Import-Module Devolutions.PowerShell -ErrorAction Stop

    if (Get-RDMDataSource -Name $Name -ErrorAction SilentlyContinue) {
        throw "A data source named '$Name' already exists."
    }

    $dataSource = New-RDMSqliteDataSource -Name $Name -Database $DatabasePath
    Set-RDMCurrentDataSource -DataSource $dataSource
}
