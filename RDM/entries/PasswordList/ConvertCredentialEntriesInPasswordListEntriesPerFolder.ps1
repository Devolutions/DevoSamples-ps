<#
.SYNOPSIS
  Converts all credential entries within each folder into a consolidated password list entry.

.DESCRIPTION
  This script leverages the Devolutions.PowerShell module to:
  - Ensure Remote Desktop Manager (RDM) cmdlets are available by installing the module when needed.
  - Target a specific data source so every operation runs against the intended repository.
  - Enumerate all folders (group entries) and gather their credential entries.
  - Create a password list entry per folder, populated with the credentials it previously contained.
  - Optionally delete each original credential entry after migrating it to the password list.

  Update the data source name before running the script and execute it with an account that has permission to create and delete entries.

.NOTES
  - Requires the Devolutions.PowerShell module; the script installs it for the current user if it is missing.
  - Running the script may remove the original credential entries unless you disable the deletion line.

.EXAMPLE
  PS> .\ConvertCredentialEntriesInPasswordListEntriesPerFolder.ps1
  Migrates every credential entry in the target data source into password list entries, one per folder.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Select the data source that contains the credential entries you want to migrate.
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds
$groups = Get-RDMSession | where {$_.ConnectionType -eq "Group"}

foreach ($group in $groups) {
	# Gather every credential entry whose group name matches the current folder.
	$credentials = Get-RDMSession | where {$_.Group -match $group.Name -and $_.ConnectionType -eq "Credential"}
	
	if ($credentials.count -gt 1) {
		Write-Host "Processing folder" $group.Name
		
		# Compose the password list entry name. Adjust the prefix to match your naming standards.
		$entryName = "PwdList_" + $group.Name
		
		# Create the password list entry in the same folder and switch its credential type accordingly.
		$ps = New-RDMSession -Name $entryName -Type Credential -Group $group.Group
		$ps.Credentials.CredentialType = "PasswordList"

		$psArray = @()

		# Convert each credential entry into a password list item and stage it for the new entry.
		foreach ($cred in $credentials) {
			$psEntry = New-Object "Devolutions.RemoteDesktopManager.Business.PasswordListItem"
			$psEntry.User = $cred.HostUserName
			$psEntry.Password = Get-RDMSessionPassword $cred -AsPlainText
			$psEntry.Domain = $cred.HostDomain
			$psEntry.Description = $cred.Description
			$psArray += $psEntry
			
			# Remove the original credential entry once it has been migrated; comment out to retain the source.
			Remove-RDMSession -ID $cred.ID -Force
		}

		$ps.Credentials.PasswordList = $psArray
		Set-RDMSession $ps -Refresh
		Write-Host "Password list $entryName created!"
		Write-Host
	}
}

Update-RDMUI
