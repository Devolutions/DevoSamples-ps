###########################################################################
#
# This script will change the offline mode of given User Group(s) to either disabled, read-only, or read-write
#
###########################################################################
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

<#
# Offline Disabled
CustomSecurity      : <?xml version="1.0"?>
                    <CustomSecurity>
                        <AllowOfflineCaching>false</AllowOfflineCaching>
                        <AllowOfflineMode>false</AllowOfflineMode>      
                    </CustomSecurity>

# Offline ReadOnly
CustomSecurity      : <?xml version="1.0"?>
                      <CustomSecurity />
# in other words, delete all nodes

# Offline ReadWrite
CustomSecurity      : <?xml version="1.0"?>
                      <CustomSecurity>
                        <AllowOfflineEdit>true</AllowOfflineEdit>
                      </CustomSecurity>
#>

# Set this variable to the desired offline mode {disabled, readonly, readwrite}

# $offlineMode = "readonly"
# $offlineMode = "disabled"
# $offlineMode = "readwrite"

$ug = Get-RDMRole -Name  "ChangedFromPowershell";

[xml]$cs = [xml]$ug.CustomSecurity;

# we need here clear the content of <CustomSecurity>...<\CustomSecurity>, in order to either leave empty (readonly), or add the element to disable, or enable read/write
if ($cs.ChildNodes.Count -gt 0){
  $cs.CustomSecurity.RemoveAll()
}

# these next lines will depend on your preference for offline mode : 
if ($offlineMode -eq "disabled"){
  $child = $cs.CreateElement("AllowOfflineCaching")
  $cs.DocumentElement.AppendChild($child);
  $cs.CustomSecurity.AllowOfflineCaching = "false"

  $child = $cs.CreateElement("AllowOfflineMode")
  $cs.DocumentElement.AppendChild($child)
  $cs.CustomSecurity.AllowOfflineMode = "false"
}
elseif ($offlineMode -eq "readwrite"){
    $child = $cs.CreateElement("AllowOfflineEdit")
    $cs.DocumentElement.AppendChild($child)
    $cs.CustomSecurity.AllowOfflineEdit = "true";

}
else{  # do nothing (I left it there because there is another setting in User (cache-only))
}



# Then you save.

Set-RDMRoleProperty -Role $ug -Property "CustomSecurity" -Value $cs.InnerXml
Set-RDMRole $ug

Write-Host "Done!!" -ForegroundColor "Yellow"