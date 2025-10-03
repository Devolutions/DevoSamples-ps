<#
.SYNOPSIS
  Creates a credential entry and an accompanying RDP session that references the newly created credentials.

.DESCRIPTION
  This script uses the Devolutions.PowerShell module to:
  - Ensure Remote Desktop Manager (RDM) cmdlets are available by installing the module if required.
  - Target a specific data source so all operations occur in the intended repository.
  - Create a credential entry, set its username, and store a password.
  - Provision a preconfigured RDP session that reuses the generated credential entry.

  Adjust the placeholder values (data source name, credential details, host information, etc.) before running the script.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if it is missing.
  - Set `$computername` to the desired session name prior to execution.

.EXAMPLE
  PS> $computername = "SRV01"
  PS> .\NewCredentialsandEntry.ps1
  Creates a credential entry named `creds` and an RDP session named `SRV01` that uses those credentials.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the data source that will hold the new credential and RDP entries.
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Create the credential entry inside the target folder and populate its username.
$creds = New-RDMSession -Name "creds" -Type Credential -Group "Credentials"
$creds.Credentials.UserName = "administrator"
Set-RDMSession $creds -Refresh
Set-RDMSessionPassword -ID $creds.ID -Password (ConvertTo-SecureString "test123$" -AsPlainText -Force)

# Create a preconfigured RDP session that points to the intended host and reuses the credential entry above.
$rdp = New-RDMSession -Name "$computername" -Type RDPConfigured -Group "Machines"
$rdp.Host = "192.168.1.1" # Replace with the IP or hostname of the target machine.
$rdp.CredentialConnectionID = $creds.ID

# Persist the new RDP session so it becomes available in the data source.
Set-RDMSession $rdp -Refresh
