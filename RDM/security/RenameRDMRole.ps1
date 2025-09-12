###########################################################################
#
#This PowerShell script will rename a role and edit all permissions.
#
#Rename-Role "OldRoleName" "NewRoleName" "MyDataSourceName" $true
#
#Parameter 1 : Old role name
#Parameter 2 : New role name
#Parameter 3 : Display name of the data source
#Parameter 4 : $True = rename the role and change the role name in the permissions
#                       $false = only change the role name in the permissions
#
#
#
###########################################################################

#check if RDM PS module is installed
if(-not (Get-Module Devolutions.PowerShell -ListAvailable)){
    Install-Module Devolutions.PowerShell -Scope CurrentUser
}

function Rename-Role
{
    param (
        [Parameter(Mandatory=$True,Position=1)]
        [string]$oldRoleName,
        [Parameter(Mandatory=$True,Position=2)]
        [string]$newRoleName,
        [Parameter(Mandatory=$True,Position=3)]
        [string]$dsName,
        [Parameter(Mandatory=$True,Position=4)]
        [bool]$chgRole		
    )

    # Set the data source
    $ds = Get-RDMDataSource -Name $dsName
    Set-RDMCurrentDataSource $ds


    # Renaming the role
    if ($chgRole)
    {
        Try
        {
            $role = Get-RDMRole -Name $oldRoleName -ErrorAction SilentlyContinue
            $errorOccured = $false
        }
        catch
        {
            $errorOccured = $True
        }
        if (!$errorOccured)
        {
            Set-RDMRoleProperty -Role $role -Property Name -Value $newRoleName
            Set-RDMRole $role
        }
    }

    $repositories = Get-RDMRepository

    foreach ($repository in $repositories)
    {
        Set-RDMCurrentRepository $repository
        Update-RDMUI

        $sessions = Get-RDMSession
      
        foreach ($session in $sessions)
        {
            [bool]$updateView = $false
            [bool]$updatePerms = $false

            # Replace role name in View permission
            $roles = $session.Security.ViewRoles
            if ($roles -contains $oldRoleName)
            {
                $roles = $roles -replace [Regex]::Escape($oldRoleName), $newRoleName
                $session.Security.ViewRoles = $roles
                $updateView = $True
            }

            # Replace role name in other permissions
            $perms = $session.Security.Permissions
            $newPerms = @()
            foreach ($perm in $perms)
            {
                $roles = $perm.Roles
                if ($roles -contains $oldRoleName)
                {
                    $roles = $roles -replace [Regex]::Escape($oldRoleName), $newRoleName
                    $perm.Roles = $roles
                    $newPerms += $perm
                    $updatePerms = $True
                }
            }
            if ($updatePerms)
            {
                $session.Security.Permissions = $newPerms
            }

            if ($updateView -or $updatePerms)
            {
                Set-RDMSession $session -Refresh
            }
        }
    }

    Update-RDMUI
    Write-Output "Done!!!"
}