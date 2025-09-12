#source https://forum.devolutions.net/topics/34248/cant-get-powershell-module-to-work-stable

#dataource name
$rdm_datasource_name = My-datasorce


#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

if ($(Get-RDMCurrentDataSource).Name -ne $rdm_datasource_name)
{
    if ($rdm_datasource_name -in $((Get-RDMDataSource).name)) # datasource present but not currently selected
    {
        $ds = Get-RDMDataSource -Name $rdm_datasource_name
        Set-RDMCurrentDataSource $ds[0]
        Update-RDMUI
    }
    else # rdm datasource doesn't exist yet
    {
        # connect to correct datasource
        New-RDMDataSource -Database $rdm_db_name -Name $rdm_datasource_name -Server $rdm_db_server -IntegratedSecurity -SQLServer -SetDatasource
        
        # remove all the other datasources - uncomment if neccesary
        # Get-RDMDataSource | Where-Object -FilterScript {$_.Name -ne $rdm_datasource_name} | Remove-RDMDataSource

        # rebuild cache
        Update-RDMUI
    }
}
else
{
    # rebuild cache
    Update-RDMUI
}
