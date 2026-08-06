<#
.SYNOPSIS
This script override the permissions of a given folder.

.DESCRIPTION
This script override the permissions of a given folder.

.PARAMETER FolderID
N/A

.EXAMPLE
Set-DSFolderPermissions -CSVFilePath "c:\temp\permissions.csv"

.NOTES
N/A
#>

<#
Function: Get-DSInheritedPermissions

Description: Get the permissions from a parent folder if the permissions are set to Inherited, Allowed or Disallowed.

Parameter: 
    FolderID: ID of the folder.
    isPAM: True for a PAM account, False or empty for non-PAM account
#>
function Get-DSInheritedPermissions ()
{
    param (
        [string]$FolderID,
        [switch]$isPAM=$false
    )

    if ($isPAM){
        $resultEntry = Get-DSPAMFolder -FolderID $FolderID
    }
    else
    {
        $resultEntry = Get-DSFolder -FolderID $FolderID
    }

    if ($resultEntry.Security -and $resultEntry.security.roleOverride -ne 3 -and $resultEntry.security.roleOverride -ne 4 -and $resultEntry.security.roleOverride -ne $null)
    {
        $result = $resultEntry
    } else {
        If (-NOT $resultEntry.group) {
            if ($isPAM){
                $vaultID = (Get-DSFolders -vaultID $resultEntry.RepositoryID -IncludeSubFolders | Where-Object {($_.connectionType -eq 124) -and ($_.connectionType.data.PAMConnectionType -eq 14)}).ID
            }
            else {
                $vaultID = (Get-DSFolders -vaultID $resultEntry.RepositoryID -IncludeSubFolders | Where-Object { $_.connectionType -eq 92 }).ID
            }           
            $result = Get-DSFolder -FolderID $vaultId
        } Else {
            $group = $resultEntry.group
            $folderName = $group.Replace($resultEntry.Name, "")
            if ($folderName -match '\\$') {
                $folderName = $folderName.Substring(0, $folderName.Length - 1)
            }

            if ([string]::IsNullOrEmpty($resultEntry.RepositoryID)) {
                $vaultID = "00000000-0000-0000-0000-000000000000"
            }
            else {
                $vaultID = $resultEntry.RepositoryID
            }
        
            if ([string]::IsNullOrEmpty($folderName)) {
                if ($isPAM)
                {
                    $folderID = (Get-DSPAMFolders -vaultID $vaultID | Where-Object { $_.group -eq "" }).ID
                    $result = Get-DSPAMFolder -FolderID $folderID
                }
                else
                {
                    $folderID = (Get-DSFolders -vaultID $vaultID -IncludeSubFolders | Where-Object { $_.group -eq "" }).ID
                    $result = Get-DSFolder -FolderID $folderID
                }
            } else {
                if ($isPAM)
                {
                    $folderID = (Get-DSPAMFolders -vaultID $vaultID | Where-Object { $_.group -eq $folderName }).ID  
                }
                else {
                    $folderID = (Get-DSFolders -vaultID $vaultID -IncludeSubFolders | Where-Object { $_.group -eq $folderName }).ID
                }                
                $result = Get-DSInheritedPermissions $folderID $isPAM
            }
        }
        
                
    }

    return $result
}

<#
Function: Add-DSSecurityProperty

Description: Add the security property to a folder object with permissions set to Inherited.

Parameter: 
    FolderID: ID of the folder.
#>
function Add-DSSecurityProperty ()
{
    param (
        [string]$FolderID
    )

    $folder = Get-DSFolder -FolderId $FolderID

    $security = (Get-DSInheritedPermissions -FolderID $folder.ID).security

    $folder | Add-Member -Name security -Value $security -MemberType NoteProperty

    # Fix the folder path to avoid virtual folders
    $group = $folder.group.Replace($folder.name, "")
    if ($group[$group.Length - 1] -eq "\")
    {
        $group = $group.SubString(0, $group.Length - 1)
    }
    $folder.group = $group

    Update-DSEntryBase -JsonBody (ConvertTo-Json -InputObject $folder -Depth 10)
}

<#
Function: Edit-DSSecurityProperty

Description: When a folder permissions are set to Allowed or Disallowed, replace the security property with its parent permissions folder.

Parameter: 
    FolderID: ID of the folder.
#>
function Edit-DSSecurityProperty ()
{
    param (
        [string]$FolderID
    )

    $folder = Get-DSFolder -FolderId $FolderID

    $security = (Get-DSInheritedPermissions -FolderID $folder.ID).security
    $folder.security = $security

    # Fix the folder path to avoid virtual folders
    $group = $folder.group.Replace($folder.name, "")
    if ($group[$group.Length - 1] -eq "\")
    {
        $group = $group.SubString(0, $group.Length - 1)
    }
    $folder.group = $group

    Update-DSEntryBase -JsonBody (ConvertTo-Json -InputObject $folder -Depth 10)
}

<#
Function: Get-DSPreservedViewPermission

Description: Build a View permission object reflecting the folder's current View state (viewOverride / viewRoles).
    Set-DSEntityPermission clears the View permission whenever it is called without a View permission in its set.
    Passing the result of this function back into Set-DSEntityPermission when updating a non-View right keeps the
    existing View permission intact. Returns $null when there is no custom View permission to preserve.

Parameter:
    Folder: the folder entry object (as returned by Get-DSEntry) whose View permission must be preserved.
#>
function Get-DSPreservedViewPermission ()
{
    param (
        $Folder
    )

    if (-not $Folder.security -or -not ($Folder.security.PSObject.Properties.Name -contains 'viewOverride'))
    {
        return $null
    }

    $viewOverride = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]$Folder.security.viewOverride

    $viewRoles = @()
    if (($Folder.security.PSObject.Properties.Name -contains 'viewRoles') -and $Folder.security.viewRoles)
    {
        $viewRoles = @($Folder.security.viewRoles | ForEach-Object { [string]$_ })
    }

    # Nothing custom to preserve: View is inheriting from the parent and has no explicit roles.
    if (($viewOverride -eq [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Inherited -or
         $viewOverride -eq [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Default) -and
        $viewRoles.Count -eq 0)
    {
        return $null
    }

    $viewPerm = New-Object RemoteDesktopManager.PowerShellModule.Private.models.ConnectionPermission
    $viewPerm.Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::View
    $viewPerm.Override = $viewOverride
    $viewPerm.Roles = $viewRoles

    return $viewPerm
}

<#
Function: Set-DSFolderPermissions

Description: Set the permissions on a folder with the given users and/or uer groups.

Parameter:
    CSVFilePath: path and filename of the CSV file that contains the permissions to update.
#>
function Set-DSFolderPermissions ()
{
    param (
        [Parameter(Mandatory)]
        [string]$CSVFilePath
    )

    $CSVpermissions = Import-Csv $CSVFilePath

    foreach ($CSVPerm in $CSVpermissions)
    {
        $folderID = $CSVPerm.FolderID
        $Permission = $CSVPerm.Permission
        $Role = $CSVPerm.Role 
        $Operation = $CSVPerm.Operation
        $Items = $CSVPerm.Items
        $Items = $Items.Split(';')

        $resultEntry = Get-DSEntry -EntryID $FolderID 
        if (![bool]($resultEntry.PSobject.Properties.name -match "Security"))
        {
            Add-DSSecurityProperty $resultEntry.ID
        }
        elseif ($resultEntry.security.roleOverride -eq 3 -or $resultEntry.security.roleOverride -eq 4 -or $resultEntry.security.roleOverride -eq $null -or $resultEntry.security.permissions -eq $null)
        {
            Edit-DSSecurityProperty $resultEntry.ID
        }

        $ItemsID = @()

        # Permissions to update
        switch ($Permission)
        {
            "View" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::View; Break}
            "Add" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Add; Break}
            "Edit" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Edit; Break}
            "Move" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Move; Break}
            "Delete" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Delete; Break}
            "ViewPassword" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::ViewPassword; Break}
            "ViewSensitive" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::ViewSensitiveInformation; Break}
            "EditSecurity" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::EditSecurity; Break}
            "ConnectionHistory" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::ConnectionHistory; Break}
            "PasswordHistory" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::PasswordHistory; Break}
            "Remotetools" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Remotetools; Break}
            "Inventory" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Inventory; Break}
            "Attachment" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Attachment; Break}
            "EditAttachment" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::EditAttachment; Break}
            "Handbook" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Handbook; Break}
            "EditHandbook" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::EditHandbook; Break}
            "EditInformation" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::EditInformation; Break}
            "Connect" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Execute; Break}
            "Execute" {$Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::Execute; Break}
        }

        # Retrieve back the entry properties if it has been update from above Add or Edit security properties functions
        $Folder = Get-DSEntry -EntryID $FolderID

        # Right to update
        # The View right is stored differently from every other right. It does NOT live in
        # security.permissions[]; it lives in security.viewOverride + security.viewRoles and is
        # only honored when the folder's roleOverride is Custom. Handle it explicitly here.
        if ($Right -eq [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::View)
        {
            # The View right lives in security.viewOverride + security.viewRoles (not in the permissions[]
            # array) and is only honored when roleOverride is Custom. Set-DSEntityPermission knows how to
            # route a View permission to those fields and rebuilds the security object itself, so drive the
            # update through it. This also avoids touching $Folder.security, which can be null on a folder
            # that inherits its permissions.
            $viewPerm = New-Object RemoteDesktopManager.PowerShellModule.Private.models.ConnectionPermission
            $viewPerm.Right = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleRight]::View

            switch ($Role)
            {
                "Custom"
                {
                    $ItemsID = @()

                    foreach ($Item in $Items)
                    {
                        $user = Get-DSUser -All | where {$_.Name -eq $Item}
                        if ($user)
                        {
                            $ItemsID += [string]$user.ID
                        }

                        $usergroup = Get-DSRole -All | where {$_.Name -eq $Item}
                        If ($usergroup)
                        {
                            $ItemsID += [string]$usergroup.ID
                        }
                    }

                    $existingViewRoles = @()
                    if ($Folder.security -and ($Folder.security.PSObject.Properties.Name -contains 'viewRoles') -and $Folder.security.viewRoles)
                    {
                        $existingViewRoles = @($Folder.security.viewRoles | ForEach-Object { [string]$_ })
                    }

                    if ($Operation -eq "Append")
                    {
                        $viewPerm.Roles = @($existingViewRoles + $ItemsID | Select-Object -Unique)
                    }
                    else
                    {
                        $viewPerm.Roles = @($ItemsID)
                    }

                    $viewPerm.Override = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Custom
                    Break
                }
                "Inherited"
                {
                    # viewOverride = Inherited means the View right is inherited from the parent folder.
                    $viewPerm.Override = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Inherited
                    $viewPerm.Roles = @()
                    Break
                }
                "Never"
                {
                    # viewOverride = Never (Disallowed) grants View to no one but the administrators.
                    $viewPerm.Override = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Never
                    $viewPerm.Roles = @()
                    Break
                }
            }

            Set-DSEntityPermission -EntityID $FolderID -Permissions $viewPerm
            $Folder = Get-DSEntry -EntryID $FolderID
        }
        else
        {
        switch ($Role)
        {
            "Custom"
            {
                if ($Folder.security.permissions -eq $null)
                {
                    $perms = New-Object RemoteDesktopManager.PowerShellModule.Private.models.ConnectionPermission
                    $perms.Right = $Right
                    $perms.Override = 'Custom'
                    
                    foreach($Item in $Items)
                    {
                        $user = Get-DSUser -All | where {$_.Name -eq $Item}
                        if ($user)
                        {
                            $ItemsID += $user.ID
                        }
                        
                        $usergroup = Get-DSRole -All | where {$_.Name -eq $Item}
                        If ($usergroup)
                        {
                            $ItemsID += $usergroup.ID
                        }
                    }

                    $perms.roles += $ItemsID

                    # Preserve the existing View permission, which Set-DSEntityPermission would otherwise clear.
                    $permsToSet = @($perms)
                    $viewPerm = Get-DSPreservedViewPermission -Folder $Folder
                    if ($viewPerm) { $permsToSet += $viewPerm }

                    Set-DSEntityPermission -EntityID $FolderID -Permissions $permsToSet
                    $Folder = Get-DSEntry -EntryID $FolderID
                }
                else 
                {
                    [bool]$updatePerm = $false
                    $perms = New-Object RemoteDesktopManager.PowerShellModule.Private.models.ConnectionPermission
                    $perms.Right = $Right
                    $perms.Override = 'Custom'

                    foreach($permissions in $Folder.security.permissions)
                    {
                        if ($permissions.Right -eq $Right)
                        {
                            switch ($Operation)
                            {
                                "Append" 
                                {
                                    foreach($Item in $Items)
                                    {
                                        $user = Get-DSUser -All | where {$_.Name -eq $Item}
                                        if ($user)
                                        {
                                            $ItemsID += $user.ID
                                        }
                                        
                                        $usergroup = Get-DSRole -All | where {$_.Name -eq $Item}
                                        If ($usergroup)
                                        {
                                            $ItemsID += $usergroup.ID
                                        }
                                    }

                                    $perms.Roles = $permissions.roles + $ItemsID

                                    # Preserve the existing View permission, which Set-DSEntityPermission would otherwise clear.
                                    $permsToSet = @($perms)
                                    $viewPerm = Get-DSPreservedViewPermission -Folder $Folder
                                    if ($viewPerm) { $permsToSet += $viewPerm }

                                    Set-DSEntityPermission -EntityID $FolderID -Permissions $permsToSet
                                    $Folder = Get-DSEntry -EntryID $FolderID
                                    $updatePerm = $true
                                    Break
                                }
                                "Replace" 
                                {
                                    foreach($Item in $Items)
                                    {
                                        $user = Get-DSUser -All | where {$_.Name -eq $Item}
                                        if ($user)
                                        {
                                            $ItemsID += $user.ID
                                        }
                                        
                                        $usergroup = Get-DSRole -All | where {$_.Name -eq $Item}
                                        If ($usergroup)
                                        {
                                            $ItemsID += $usergroup.ID
                                        }
                                    }
                                    $perms.roles = $ItemsID

                                    # Preserve the existing View permission, which Set-DSEntityPermission would otherwise clear.
                                    $permsToSet = @($perms)
                                    $viewPerm = Get-DSPreservedViewPermission -Folder $Folder
                                    if ($viewPerm) { $permsToSet += $viewPerm }

                                    Set-DSEntityPermission -EntityID $FolderID -Permissions $permsToSet
                                    $Folder = Get-DSEntry -EntryID $FolderID
                                    $updatePerm = $true
                                    Break
                                }        
                            }
                            Break
                        }
                    }

                    if (!$updatePerm)
                    {
                        foreach($Item in $Items)
                        {
                            $user = Get-DSUser -All | where {$_.Name -eq $Item}
                            if ($user)
                            {
                                $ItemsID += $user.ID
                            }
                            
                            $usergroup = Get-DSRole -All | where {$_.Name -eq $Item}
                            If ($usergroup)
                            {
                                $ItemsID += $usergroup.ID
                            }
                        }

                        if ($Right -eq 'View' -and $Operation -eq "Append")
                        {
                            $perms.Roles = $ItemsID + $Folder.security.ViewRoles
                        }
                        else 
                        {
                            $perms.roles = $ItemsID
                        }
                        
                        # Preserve the existing View permission, which Set-DSEntityPermission would otherwise clear.
                        $permsToSet = @($perms)
                        $viewPerm = Get-DSPreservedViewPermission -Folder $Folder
                        if ($viewPerm) { $permsToSet += $viewPerm }

                        Set-DSEntityPermission -EntityID $FolderID -Permissions $permsToSet
                        $Folder = Get-DSEntry -EntryID $FolderID
                        $updatePerm = $true
                    }
                }
            }
            "Inherited"
            {
                $Folder.security.roleOverride  = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Inherited
                Break
            }
            "Never" 
            {
                $Folder.security.roleOverride  = [RemoteDesktopManager.PowerShellModule.Private.enums.SecurityRoleOverride]::Never
                Break
            }
        }
        }

        $group = $Folder.group.Replace($Folder.name, "")
        if ($group[$group.Length - 1] -eq "\")
        {
            $group = $group.SubString(0, $group.Length - 1)
        }
        $Folder.group = $group

        Update-DSEntryBase -JsonBody (ConvertTo-Json -InputObject $Folder -Depth 10)
    }
}