<#FRONTMATTER
id: Import-RDMSessionsFromXml
title: Import-RDMSessionsFromXml
product: RDM
category: import
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
  - Import-RDMSession
params:
  - name: Path
    type: string
    mandatory: true
tags:
  - import
  - xml
author: ''
last_updated: 2026-05-18
FRONTMATTER#>

<#
.SYNOPSIS
Import RDM sessions from an XML export file into the currently active data source.

.DESCRIPTION
Provides Import-RDMSessionsFromXml, which loads the sessions defined in an
RDM XML export file (produced by File > Export, or by Export-RDMSession) and
imports them into the data source currently selected in Remote Desktop Manager.

.PARAMETER Path
Path to the RDM XML file to import. Must exist.

.EXAMPLE
Import-RDMSessionsFromXml -Path "C:\exports\sessions.xml"

.NOTES
The currently active RDM data source is the import target. Switch data sources
(File > Data Sources) before running if you need to import elsewhere.
#>

function Import-RDMSessionsFromXml
{
    param (
        [Parameter(Mandatory)][string]$Path
    )

    Import-Module Devolutions.PowerShell -ErrorAction Stop

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "RDM XML file '$Path' not found."
    }

    Import-RDMSession -Path $Path
}
