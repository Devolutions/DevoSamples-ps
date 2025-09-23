<#
.SYNOPSIS
  Extract the legacy embedded credentials and save it in the belonged entry as now supported.
  This script should be used only if recommended by the support team only.

.DESCRIPTION
  This script will extract the username and password from the legacy embedded credentials and will set it to 

.PARAMETER <Parameter_Name>
  None

.INPUTS
  All entries with Credentials parameter to Embedded.

.OUTPUTS
  None

.NOTES
  Version:        1.0
  Author:         Erica Poirier
  Creation Date:  17/07/2023
  Purpose/Change: Customer request
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

#---------------------------------[Functions]----------------------------------


#---------------------------------[Execution]----------------------------------

$vaults = Get-RDMVault

foreach ($vault in $vaults)
{
    Set-RDMCurrentRepository -Repository $vault
    $vaultname = $vault.Name
    Write-Host "Current vault is "$vaultname

    $sessions = Get-RDMSession | where {$_.CredentialConnectionID -eq '0C0C8D0A-CE6D-40E7-84D0-343D488E2DBA'}

    foreach ($session in $sessions)
    {
        $username = Get-RDMSessionUserName $session
        $password = Get-RDMSessionPassword $session
        $session.CredentialConnectionID = ''
        Set-RDMSessionUsername -Session $session -UserName $username
        Set-RDMSessionPassword -Session $session -Password $password
        Set-RDMSession -Session $session -Refresh
        Write-Host "Entry " + $session.Name + " updated!"
    }
}

Write-Host "Process completed!!!"