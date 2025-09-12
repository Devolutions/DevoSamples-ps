#source: https://forum.devolutions.net/topics/33589/how-to-set-properties-on-data-source-using-powershell

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

$ds = New-RDMDataSource -SQLServer -Server YourSQLServer -Database YourSQLDatabase -Name YourDataSourceName -IntegratedSecurity
Set-RDMDatasourceProperty -DataSource $ds -Property AutoGoOffline -Value $true
Set-RDMDatasourceProperty -DataSource $ds -Property AllowOfflineMode -Value $true
Set-RDMDatasourceProperty -DataSource $ds -Property AllowOfflineEdit -Value $true
Set-RDMDataSource $ds