function Display-VaultPermissions {
    param (
        $VaultPermissions,
        $Users,
        $Groups,
        $VaultRoles
    )

    foreach ($id in $VaultPermissions.Users.Keys) {
        $permissions = $VaultPermissions.Users[$id];
        $user = $Users | Where-Object -Property Id -eq $id;
        $role = $VaultRoles | Where-Object -Property Id -eq $permissions.roleId;
		
		if ($user) {
			Write-Host $user.name;
			if ($permissions.roleId) {
				Write-Host ($role.VaultPermission | Format-List | Out-String);
			} else {
				Write-Host ($permissions | Format-List | Out-String);
			}			
		}		

    }
	
    foreach ($id in $VaultPermissions.Groups.Keys) {
        $permissions = $VaultPermissions.Groups[$id];
        $group = $Groups | Where-Object { $_.Id -eq $id };
        $role = $VaultRoles | Where-Object { $_.id -eq $permissions.roleId };
        
		if ($group) {
			Write-Host $group.name;
			if ($permissions.roleId) {
				Write-Host ($role.VaultPermission | Format-List | Out-String);
			} else {
				Write-Host ($permissions | Format-List | Out-String);
			}
		}
    }
}

function Display-EntryPermissions {
    param (
        $EntryPermissions,
        $Users,
        $Groups,
        $EntryRoles
    )

    foreach ($id in $EntryPermissions.Users.Keys) {
        $permissions = $EntryPermissions.Users[$id];
        $user = $Users | Where-Object -Property Id -eq $id;
        $role = $EntryRoles | Where-Object -Property Id -eq $permissions.roleId;
		
		if ($user) {
			Write-Host $user.name;
			if ($permissions.roleId) {
				Write-Host ($role.EntryPermission | Format-List | Out-String);
			} else {
				Write-Host ($permissions | Format-List | Out-String);
			}			
		}		
    }
	
    foreach ($id in $EntryPermissions.Groups.Keys) {
        $permissions = $EntryPermissions.Groups[$id];
        $group = $Groups | Where-Object { $_.Id -eq $id };
        $role = $vaultRoles | Where-Object { $_.id -eq $permissions.roleId };
        
		if ($group) {
			Write-Host $group.name;
			if ($permissions.roleId) {
				Write-Host ($role.EntryPermission | Format-List | Out-String);
			} else {
				Write-Host ($permissions | Format-List | Out-String);
			}
		}
    }
}


<# Change variables below #>
$url = 'https://pathub.devolutions.app/'
$appSecret = 'klMZfZeAPBG8rcKBrKIW/odA+BOMT1Z7GqcaqaPFDgo=';
$appKey = '778bc075-bd48-45fe-b89a-fa5512cd0725;6cd64424-5061-42fb-b875-8ffe281780e8';

<# Connect #>
Connect-HubAccount -Url $url -ApplicationKey $appKey -ApplicationSecret $appSecret;

$vaultRoles = Get-HubVaultRole;
$entryRoles = Get-HubEntryRole;
$users = Get-HubUser;
$groups = Get-HubGroup;
$vaults = Get-HubVault;
$systemSettings = Get-HubSystemSettings;

Write-Host "# All vaults #";
Display-VaultPermissions -VaultPermission $systemSettings.SystemVaultPermissions -Users $users -Groups $groups -VaultRoles $vaultRoles;

foreach ($vault in $vaults)
{	
	if ($vault.VaultPermissions.Users.Keys -gt 0 -or $vault.VaultPermissions.Groups.Keys -gt 0) {
		Write-Host "## Vault : $($vault.name) ##";
		Display-VaultPermissions -VaultPermission $vault.VaultPermissions -Users $users -Groups $groups -VaultRoles $vaultRoles;
	}
	
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
