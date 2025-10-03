###########################################################################
#
# This script will export a CSV file containing the Name and the URL that
# can be used in a Wiki to launch the session using RDM
#
###########################################################################

<#
.SYNOPSIS
    Export a CSV that maps RDM session names to launch URLs for the web protocol handler.
.DESCRIPTION
    Ensures the Devolutions.PowerShell module is present, connects to the specified data source, and retrieves
    every RDP-configured session. For each entry, builds the `rdm://` URL that launches the session via the
    web protocol handler and writes the results to a CSV for documentation or wiki usage.
.NOTES
    Update the data source name and output path before running. The `rdm://` URLs work only for users who can
    reach the same data source and have the Remote Desktop Manager web protocol handler installed.
#>

# Check whether the RDM PowerShell module is available; install it for the current user if missing.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (replace with your configured data source name).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Retrieve the identifier of the active data source (matches the value used in generated web URLs).
$dsid = Get-RDM-DataSource | Where-Object {$_.IsCurrent -eq "X"} | Select-Object -ExpandProperty ID

# Collect every RDP session and project it into objects containing the display name and rdm:// launch URL.
$sessions = Get-RDM-Session |
    Where-Object {$_.Session.Kind -eq "RDPConfigured"} | ForEach-Object {
        New-Object Object |
            Add-Member NoteProperty Name $_.Name -PassThru |
            Add-Member NoteProperty URL "rdm://open?DataSource=$dsid&Session=$($_.ID)" -PassThru
    }

# Persist the session list to CSV so it can be published or shared.
$sessions | Export-Csv c:\temp\sessions.csv -NoTypeInformation
