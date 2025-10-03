<#
.SYNOPSIS
    Export every entry from every accessible Remote Desktop Manager vault to password-protected RDM files.
.DESCRIPTION
    Connects to the specified data source, iterates through each vault (repository), and exports the sessions
    it contains to individual `.rdm` files. Empty vaults are skipped with a warning message.
.NOTES
    Customize the data source name, temporary export path, and archive password before running the script.
    The script installs the Devolutions.PowerShell module for the current user if it is missing.
#>

# Ensure the Devolutions PowerShell module is available for the current user.
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Authenticate to the Remote Desktop Manager data source to export from (update the name).
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Convert the export password to a secure string (replace with your own secret).
$passwd = ConvertTo-SecureString -AsPlainText -Force 'mypassword'

# Retrieve every repository (vault) that the current data source exposes.
$repos = Get-RDMRepository

foreach ($repo in $repos)
{
    Set-RDMCurrentRepository $repo

    # Collect every session in the current vault. `$null` indicates the vault is empty.
    $sessions = Get-RDMSession
    $reponame = $repo.name
    if ($null -eq $sessions) {
        Write-Host -BackgroundColor Gray -ForegroundColor Red "Warning! Vault '$($repo.name)' is empty - no file will be created."
    }
    else {
        # Export the sessions for this vault to an encrypted RDM file (adjust the destination path as needed).
        Export-RDMSession -Path "C:\temp\Sessions_$reponame.rdm" -Sessions $sessions -IncludeCredentials -XML -Password $passwd
    }
}
