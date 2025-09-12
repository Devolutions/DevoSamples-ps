#requires -version 4
<#
.SYNOPSIS
  Creates RDM user accounts from AD accounts stored in a CSV file.
.DESCRIPTION
  Creates RDM user accounts from AD accounts stored in a CSV file.
.PARAMETER <Parameter_Name>
  None
.INPUTS
  CSV file that contains the list of AD user accounts.
.OUTPUTS
  None
.NOTES
  Version:        1.0
  Author:         Érice Poirier
  Creation Date:  2021-04-29
  Purpose/Change: Initial script development
.EXAMPLE
  
#>


#-------------------------------[Initialisations]------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = 'SilentlyContinue'

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}


#---------------------------------[Functions]----------------------------------

#---------------------------------[Execution]----------------------------------

### Connect to the SQL Data Source
$ds = Get-RDMDataSource -Name "YourSQLDataSourceNameHere"
Set-RDMCurrentDataSource $ds
Update-RDMUI

$path     = Split-Path -parent $MyInvocation.MyCommand.Definition  
$urspath  = $path + "\user_input.csv" 
$csv      = @() 
$csv      = Import-Csv -Path $urspath 

foreach ($user in $csv)            
{            
    $Displayname = $User.Firstname + " " + $User.Lastname            
    $UserFirstname = $User.Firstname            
    $UserLastname = $User.Lastname            
    $Email = $User.Firstname + "." + $User.Lastname + "@" + $User.Maildomain
    
    # Replace the domain name below.
    $NetBios = "YourDomain\" + $SAM
    try
    {
        # NetBios username format
        # $newUser = New-RDMUser -Login $NetBios -Email $Email -AuthentificationType SqlServer -IntegratedSecurity
        
        # UPN username format
        $newUser = New-RDMUser -Login $Email -Email $Email -AuthentificationType SqlServer -IntegratedSecurity 
        $newUser.UserType = "User"
        $newUser.FirstName = $UserFirstname
        $newUser.LastName = $UserLastname
        Set-RDMUser -User $newUser

        Write-Host "$Displayname created"
    }
    catch
    {
        Write-Host "Unable to create user $Displayname"
    }
} 

Write-Host "Done!!!"

#----------------------------------[Closure]-----------------------------------
# If running in the console only, ask to press a key
if ($Host.Name -eq "ConsoleHost")
{
    Write-Host "Press any key to continue..."
    $Host.UI.RawUI.FlushInputBuffer()  
    $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp") > $null
}
