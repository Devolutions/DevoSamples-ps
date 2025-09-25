#The following script will export all entries from all vaults as one file per vault. Each file is password protected.

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

# Adapt the password
$passwd = ConvertTo-SecureString -AsPlainText -Force 'mypassword'

$repos = Get-RDMRepository

foreach ($repo in $repos)
{
    Set-RDMCurrentRepository $repo

    $sessions = Get-RDMSession
    $reponame = $repo.name
    if ($null -eq $sessions) {
        Write-Host -BackgroundColor Gray -ForegroundColor Red "Warning! Vault '$($repo.name)' is empty – no file will be created."
    }
    else {
        # Adapt the destination path for file(s)
        Export-RDMSession -Path "C:\temp\Sessions_$reponame.rdm" -Sessions $sessions -IncludeCredentials -XML -Password $passwd
    }
}
