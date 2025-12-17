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

# Set the current data source (replace with your configured data source name).
$ds = Get-RDMDataSource -Name "<data source name>"
Set-RDMCurrentDataSource $ds
$dsid = $ds.Id

# Collect every RDP session and project it into objects containing the display name and rdm:// launch URL.
$sessions = Get-RDMSession | Where-Object { $_.ConnectionType -eq "RDPConfigured" }
 ForEach-Object {
        New-Object Object |
            Add-Member NoteProperty Name $_.Name -PassThru |
            Add-Member NoteProperty URL "rdm://open?DataSource=$dsid&Session=$($_.ID)" -PassThru
    }

# Persist the session list to CSV so it can be published or shared.
$sessions | Export-Csv c:\temp\sessions.csv -NoTypeInformation
