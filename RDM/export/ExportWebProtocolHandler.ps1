###########################################################################
#
# This script will export a CSV file containing the Name and the URL that
# can be used in a Wiki to launch the session using RDM
#
###########################################################################
#-----------------------------------[Main]-------------------------------------
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

## get the data source ID, note that the "Create Web Url" button generates a different ID, but both are accepted
$dsid = Get-RDM-DataSource | where {$_.IsCurrent -eq "X"} | select -expand "ID"
## get the RDP sessions, create a new object with the desired fields.
## Simply append "add-member" commands to include a new field
$s = Get-RDM-Session | 
    where {$_.Session.Kind -eq "RDPConfigured"} | foreach {
        new-Object Object |
            Add-Member NoteProperty Name $_.Name –PassThru |
            Add-Member NoteProperty URL "rdm://open?DataSource=$dsid&Session=$($_.ID)" –PassThru 
    }; 

## save to csv, the field names are used as column headers.
$s | export-csv c:\temp\sessions.csv -notypeinformation;
