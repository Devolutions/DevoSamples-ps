<#
.SYNOPSIS
Update a username-password credential entry's password.

.DESCRIPTION
Provides Update-DSCredentialPassword, which:
- Locates a vault by name and a username-password credential entry by name match.
- Loads the entry XML into a PowerShell object.
- Sets the clear-text Password on a typed CredentialsConnection so that SafePassword is recalculated.
- Writes the recalculated SafePassword back to the entry and saves the entry.

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
    $entry = Get-DSEntry -VaultID $vault.ID -FilterMatch ExactExpression -FilterValue $CredentialName
    
	$credObject = $entry.data | Convert-XMLToPSCustomObject
	$credConnection = [Devolutions.RemoteDesktopManager.Business.CredentialsConnection]$credObject.Connection.Credentials
	$credConnection.Password = $Password
	$credObject.Connection.Credentials.SafePassword = $credConnection.SafePassword
	
	$newCredXml = $credObject | Convert-PSCustomObjectToXML
	$entry.Data = $newCredXml.OuterXml
	Update-DSEntryBase -FromRDMConnection $entry
}
