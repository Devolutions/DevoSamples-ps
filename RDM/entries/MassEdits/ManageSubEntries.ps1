#requires -version 4
<#
.SYNOPSIS
  Mass edit Entries in RDM version 2022.3.x or higher.
  The samples sections may be used separately. 

.DESCRIPTION
  Mass edit Entries in RDM version 2022.3.x or higher.

.PARAMETER <Parameter_Name>

.INPUTS

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Erica Poirier
  Creation Date:  31/07/2023
  Purpose/Change: Initial script development
.EXAMPLE

#>

#-------------------------------[Initialisations]------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
  Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Sample 1
# Getting a list of Entries that are sub entries
$subConnections = Get-RDMSession | Where-Object {![string]::IsNullOrWhiteSpace($_.ParentID)}

# Sample 2
# Getting a list of an entry sub entries
$parent = Get-RDMSession -Name '<Parent entry name>'
$subConnections = Get-RDMSession | Where-Object { $_.ParentID -eq $parent.ID}

# Sample 3
# Remove sub entries from parent
foreach ($connection in $subConnections)
{
  $connection.ParentID = ""
  Set-RDMSession $connection
}

# Sample 4
# Add sub entries to parent
foreach ($connection in $subConnections)
{
  $connection.ParentID = $parent.ID
  Set-RDMSession $connection -Refresh
}
