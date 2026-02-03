<#
.SYNOPSIS
Update a username-password credential entry's password.

.DESCRIPTION
Provides Update-DSCredentialPassword, which:
- Locates a vault by name and a username-password credential entry by name match.
- Sets the password on the credential entry using Set-DSEntryProperty.
- Saves the updated entry.

.PARAMETER VaultName
Name of the vault that contains the credential entry.

.PARAMETER CredentialName
Name of the credential entry to update.

.PARAMETER Password
The new password to set for the credential.

.EXAMPLE
Update-DSCredentialPassword -VaultName "MyVaultName" -CredentialName "MyCredName" -Password "NewPassword"

.NOTES
This function requires a credential entry of type "username and password."
#>

function Update-DSCredentialPassword ()
{
    param (
        [Parameter(Mandatory)][string]$VaultName,
        [Parameter(Mandatory)][string]$CredentialName,
        [Parameter(Mandatory)][string]$Password
    )

    $vault = Get-DSVault -All | where name -EQ $VaultName
    if (-not $vault) {
        throw "Vault '$VaultName' not found."
    }

    $entries = @(Get-DSEntry -VaultID $vault.ID -FilterMatch ExactExpression -FilterValue $CredentialName)
    
    if (-not $entries) {
        throw "Entry '$CredentialName' not found in vault '$VaultName'."
    }

    if ($entries.Count -gt 1) {
        throw "Multiple entries matching '$CredentialName' found in vault '$VaultName'. Expected exactly one entry."
    }

    $entry = $entries | Select-Object -First 1

	$entry | Set-DSEntryProperty -Path "Credentials" -PropertyName "Password" -PropertyValue $Password | Update-DSEntryBase
}
