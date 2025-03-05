###########################################################################
#
# This script will Assign a given License (Through the serial) to a given user (Username) 
#
###########################################################################
#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
�� �Install-Module Devolutions.PowerShell -Scope CurrentUser
}

# Adapt the data source name
$ds = Get-RDMDataSource -Name "NameOfYourDataSourceHere"
Set-RDMCurrentDataSource $ds

function Set-LicenseSerialToUser(
    # Parameter help description
    [String]
    $Serial,
    [String]
    $UserName    
)
{
# Getuser
$User = Get-RDMUser -Name $UserName

# fetch license from serial
$License = Get-RDMLicense -Serial $Serial

# get the assignation
$userlicense = $License.Users | Where-Object{$_.UserID -eq $User.ID}
$userlicense.IsMember = $True

# save changes
Set-RDMLicense -License $License
}