<#
.SYNOPSIS
  Renames an RDM security role and updates every reference to that role inside session permissions.

.DESCRIPTION
  Exposes the `Rename-Role` function, which:
  - Ensures the Devolutions.PowerShell module is present before running.
  - Switches to the requested data source.
  - Optionally renames the role object itself.
  - Walks through each vault and session to replace the old role name in view permissions and granular security rights.

  Call `Rename-Role` with the old role name, new role name, data source, and a boolean indicating whether the role
  object should be renamed in addition to updating permissions.

.NOTES
  - Requires the Devolutions.PowerShell module; installs it for the current user if missing.
  - Set the `$chgRole` parameter to `$false` if the role already exists under the new name and only permissions should be updated.

.EXAMPLE
  PS> Rename-Role -oldRoleName 'Operations' -newRoleName 'Ops Team' -dsName 'MainDataSource' -chgRole $true
  Renames the role from `Operations` to `Ops Team` and rewrites every session permission that referenced the old name.

.LINK
  https://powershell.devolutions.net/
#>

# Ensure the Devolutions.PowerShell module is available before invoking any RDM cmdlets.
if (-not (Get-Module Devolutions.PowerShell -ListAvailable)) {
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

    # Switch to the data source that hosts the target role and associated sessions.
    $ds = Get-RDMDataSource -Name $dsName
    Set-RDMCurrentDataSource $ds

    # Optionally rename the role entity before updating downstream permissions.
    if ($chgRole)
    {
        try
        {
            $role = Get-RDMRole -Name $oldRoleName -ErrorAction Stop
            Set-RDMRoleProperty -Role $role -Property Name -Value $newRoleName
            Set-RDMRole $role
        }
        catch
        {
            throw "Unable to find or rename role '$oldRoleName'."
        }
    }

    # Retrieve every repository and refresh the UI so session updates occur against current data.
    $repositories = Get-RDMRepository

    foreach ($repository in $repositories)
    {
        Set-RDMCurrentRepository $repository
        Update-RDMUI

        $sessions = Get-RDMSession

        foreach ($session in $sessions)
        {
            $updateView = $false
            $updatePerms = $false

            # Replace the role name in any view override entries.
            $roles = $session.Security.ViewRoles
            if ($roles -contains $oldRoleName)
            {
                $session.Security.ViewRoles = $roles -replace [Regex]::Escape($oldRoleName), $newRoleName
                $updateView = $true
            }

            # Replace the role in granular permission assignments and track whether updates occurred.
            $perms = $session.Security.Permissions
            foreach ($perm in $perms)
            {
                $permRoles = $perm.Roles
                if ($permRoles -contains $oldRoleName)
                {
                    $perm.Roles = $permRoles -replace [Regex]::Escape($oldRoleName), $newRoleName
                    $updatePerms = $true
                }
            }

            # Persist updates only when a change was detected.
            if ($updateView -or $updatePerms)
            {
                Set-RDMSession $session -Refresh
            }
        }
    }

    Update-RDMUI
    Write-Output "Done!!!"
}
