#Here is the PowerShell script to convert all Credential entries to a Password List entry. This will scan the whole repository and convert entries per folder.
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds
$groups = Get-RDMSession | where {$_.ConnectionType -eq "Group"}

foreach ($group in $groups) {
	# Get all Credential entries in the folder
	$credentials = Get-RDMSession | where {$_.Group -match $group.Name -and $_.ConnectionType -eq "Credential"}
	
	if ($credentials.count -gt 1) {
		Write-Host "Processing folder" $group.Name
		
		# This the name of the Password List entry. Please change it to fit your needs.
		# It will add PwdList as the prefix of the Folder name that contains the credential entries
		$entryName = "PwdList_" + $group.Name
		
		# Creation of the Password List entry
		$ps = New-RDMSession -Name $entryName -Type Credential -Group $group.Group
		$ps.Credentials.CredentialType = "PasswordList"

		$psArray = @()

		# Add the credentials in the Password List
		foreach ($cred in $credentials) {
			$psEntry = New-Object "Devolutions.RemoteDesktopManager.Business.PasswordListItem"
			$psEntry.User = $cred.HostUserName
			$psEntry.Password = Get-RDMSessionPassword $cred -AsPlainText
			$psEntry.Domain = $cred.HostDomain
			$psEntry.Description = $cred.Description
			$psArray += $psEntry
			
			# Comment the following line to not delete the original credential entry.
			Remove-RDMSession -ID $cred.ID -Force
		}

		$ps.Credentials.PasswordList = $psArray
		Set-RDMSession $ps -Refresh
		Write-Host "Password list $entryName created!"
		Write-Host
	}
}

Update-RDMUI