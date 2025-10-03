<#
.SYNOPSIS
    Export vault and entry permission assignments from Devolutions Hub.
.DESCRIPTION
    Connects to a Hub instance, retrieves vault, entry, user, group, and role data,
    and writes a readable overview of permissions for vaults and entries to the console.
    Update the connection variables in the configuration section before running the script.
#>

function Display-VaultPermissions {
    <#
    .SYNOPSIS
        Display all permission assignments for a specific set of vault permissions.
    .PARAMETER VaultPermissions
        Permission data structure that contains user and group assignments for a vault.
    .PARAMETER Users
        Collection of Hub users used to resolve user names from identifiers.
    .PARAMETER Groups
        Collection of Hub groups used to resolve group names from identifiers.
    .PARAMETER VaultRoles
        Collection of Hub vault roles used to resolve role-based permissions.
    #>
    param (
        $VaultPermissions,
        $Users,
        $Groups,
        $VaultRoles
    )

    foreach ($id in $VaultPermissions.Users.Keys) {
        # Match the permission entry back to the user and optional role.
        $permissions = $VaultPermissions.Users[$id];
        $user = $Users | Where-Object -Property Id -eq $id;
        $role = $VaultRoles | Where-Object -Property Id -eq $permissions.roleId;
        
        if ($user) {
            Write-Host $user.name;
            if ($permissions.roleId) {
                Write-Host ($role.VaultPermission | Format-List | Out-String);
            }
            else {
                Write-Host ($permissions | Format-List | Out-String);
            }
        }
    }
    
    foreach ($id in $VaultPermissions.Groups.Keys) {
        # Repeat the same logic for groups associated to the vault.
        $permissions = $VaultPermissions.Groups[$id];
        $group = $Groups | Where-Object { $_.Id -eq $id };
        $role = $VaultRoles | Where-Object { $_.id -eq $permissions.roleId };
        
        if ($group) {
            Write-Host $group.name;
            if ($permissions.roleId) {
                Write-Host ($role.VaultPermission | Format-List | Out-String);
            }
            else {
                Write-Host ($permissions | Format-List | Out-String);
            }
        }
    }
}

function Display-EntryPermissions {
    <#
    .SYNOPSIS
        Display each permission assignment defined for a specific entry.
    .PARAMETER EntryPermissions
        Permission data structure that contains user and group assignments for an entry.
    .PARAMETER Users
        Collection of Hub users used to resolve user names from identifiers.
    .PARAMETER Groups
        Collection of Hub groups used to resolve group names from identifiers.
    .PARAMETER EntryRoles
        Collection of Hub entry roles used to resolve role-based permissions.
    #>
    param (
        $EntryPermissions,
        $Users,
        $Groups,
        $EntryRoles
    )

    foreach ($id in $EntryPermissions.Users.Keys) {
        # Match the permission entry back to the user and optional role.
        $permissions = $EntryPermissions.Users[$id];
        $user = $Users | Where-Object -Property Id -eq $id;
        $role = $EntryRoles | Where-Object -Property Id -eq $permissions.roleId;
        
        if ($user) {
            Write-Host $user.name;
            if ($permissions.roleId) {
                Write-Host ($role.EntryPermission | Format-List | Out-String);
            }
            else {
                Write-Host ($permissions | Format-List | Out-String);
            }
        }
    }
    
    foreach ($id in $EntryPermissions.Groups.Keys) {
        # Repeat the same logic for groups associated to the entry.
        $permissions = $EntryPermissions.Groups[$id];
        $group = $Groups | Where-Object { $_.Id -eq $id };
        $role = $vaultRoles | Where-Object { $_.id -eq $permissions.roleId };
        
        if ($group) {
            Write-Host $group.name;
            if ($permissions.roleId) {
                Write-Host ($role.EntryPermission | Format-List | Out-String);
            }
            else {
                Write-Host ($permissions | Format-List | Out-String);
            }
        }
    }
}

<#
    Update the following variables with your Hub environment and application credentials
    before executing the script.
#>
$url = '<your url>'
$appSecret = '<your app secret>';
$appKey = '<your app key>';

<# Connect to the Hub tenant using the provided service principal credentials. #>
Connect-HubAccount -Url $url -ApplicationKey $appKey -ApplicationSecret $appSecret;

# Gather the data required to resolve permissions into readable output.
$vaultRoles = Get-HubVaultRole;
$entryRoles = Get-HubEntryRole;
$users = Get-HubUser;
$groups = Get-HubGroup;
$vaults = Get-HubVault;
$systemSettings = Get-HubSystemSettings;

Write-Host "# All vaults #";
Display-VaultPermissions -VaultPermission $systemSettings.SystemVaultPermissions -Users $users -Groups $groups -VaultRoles $vaultRoles;

foreach ($vault in $vaults) {
    # Only display vault-specific permissions when assignments exist.
    if ($vault.VaultPermissions.Users.Keys -gt 0 -or $vault.VaultPermissions.Groups.Keys -gt 0) {
        Write-Host "## Vault : $($vault.name) ##";
        Display-VaultPermissions -VaultPermission $vault.VaultPermissions -Users $users -Groups $groups -VaultRoles $vaultRoles;
    }
    
    # Walk through each entry to dump entry-level permission overrides when present.
    $vaultEntries = Get-HubEntry -VaultId $vault.Id;
    foreach ($entry in $vaultEntries) {
        if ($entry.PsMetadata.Permissions.Users.Keys -gt 0 -or $entry.PsMetadata.Permissions.Groups.Keys -gt 0) {
            Write-Host "### Entry : $($entry.PsMetadata.name) ###";
            Display-EntryPermissions -EntryPermission $entry.PsMetadata.Permissions -Users $users -Groups $groups -EntryRoles $entryRoles;
        }
    }
}

Write-Host "Done"
pause
