#####################################################################
#                                                                   #
# WARNING, THE RESULTING FILE WILL CONTAIN PASSWORDS IN CLEAR TEXT  #
#                                                                   #
#####################################################################

<#
.SYNOPSIS
    Export RDM sessions with usernames and passwords in clear text to a CSV file.
.DESCRIPTION
    Installs the Devolutions.PowerShell module if needed, switches to the specified data source, and iterates
    through every vault to collect all sessions that are not folder-only entries. The script adds username and
    password fields to each session and appends them to the target CSV file, producing plain text credentials.
.NOTES
    Update the data source name and export file path before running. The generated CSV is sensitive and should
    be protected appropriately.
.VERSION
    1.1
.LASTEDIT
    2025-09-25
#>

# Ensure the Devolutions PowerShell module is available for the current user.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Set the current data source (replace "NameOfYourDataSourceHere" with the required data source).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Destination CSV path where the exported sessions will be stored.
$exportFileName = "c:\Backup\RDMCredentialsData_$(get-date -f yyyy-MM-dd).csv"

# Refresh the RDM UI context to avoid stale data when querying sessions.
Update-RDMUI

# Retrieve all vaults (repositories) exposed by the current data source.
$vaults = Get-RDMVault

foreach ($vault in $vaults){
    # Switch to the current vault so the session queries target the correct repository.
    Set-RDMCurrentRepository $vault
    Update-RDMUI

    # Fetch every session except the Group placeholders; retain relevant properties.
    $RDMsessions = Get-RDMSession | Where-Object {$_.ConnectionType -ne "Group"}  | Select-Object -Property Name, ID, ConnectionType, Group, Host

    foreach ($session in $RDMsessions){
        # Attach the resolved username as an additional property on the session object.
        $session | Add-Member -MemberType NoteProperty "Username" -Value (Get-RDMSessionUserName -ID $session.id)
        # Attach the clear text password for export; highly sensitive information.
        $session | Add-Member -MemberType NoteProperty "Password" -Value (get-RDMSessionPassword -ID $session.id -AsPlainText)
        # Append the enriched session data to the result CSV.
        $session | Export-Csv -Path $exportFileName -Append -NoTypeInformation
    }
}
