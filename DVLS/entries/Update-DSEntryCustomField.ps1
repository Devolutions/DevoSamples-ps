<#
.SYNOPSIS
Update an entry's custom field, with support for toggling between plain and sensitive storage.

.DESCRIPTION
Provides the function Update-DSEntryCustomField, which:
- Locates an entry by Vault and Entry name.
- Finds the target custom field by matching its Title (CustomField1..5Title) to -FieldName.
- Updates the value (when -Sensitive is supplied, the value is encrypted and stored in the appropriate field).

.EXAMPLE
# Set a non-sensitive field named "Environment" to "Prod"
Update-DSEntryCustomField -VaultName "MyVault" -EntryName "MyEntry" -FieldName "Environment" -NewValue "Prod"

.EXAMPLE
# Store a sensitive value for the "API Key" field
Update-DSEntryCustomField -VaultName "MyVault" -EntryName "MyEntry" -FieldName "API Key" -NewValue "abc123" -Sensitive

.NOTES
Custom field must have a set name.
Behavior is idempotent: re-running with the same switch state (-Sensitive present or absent) just updates the value.
#>

function Update-DSEntryCustomField ()
{
    param (
        [Parameter(Mandatory)][string]$VaultName,
        [Parameter(Mandatory)][string]$EntryName,
        [Parameter(Mandatory)][string]$FieldName,
        [Parameter(Mandatory)][string]$NewValue,
        [switch]$Sensitive
    )
	
    function Remove-Property([object]$object, [string]$name) {
        if ($object.PSObject.Properties.Name -contains $name) { [void]$object.PSObject.Properties.Remove($name) }
    }

    function Ensure-NoteProperty([object]$object, [string]$name, $value) {
        if ($object.PSObject.Properties.Name -contains $name) { $object.$name = $value }
        else { Add-Member -InputObject $object -MemberType NoteProperty -Name $name -Value $value }
    }
    
    $vault = Get-DSVault -All | where name -EQ $VaultName
    if (-not $vault) {
        throw "Vault '$VaultName' not found."
    }

    $entry = Get-DSEntry -VaultID $vault.ID -FilterMatch ExactExpression -FilterValue $EntryName
    if (-not $entry) {
        throw "Entry '$EntryName' not found in vault '$VaultName'."
    }

	$entryObject = $entry.data | Convert-XMLToPSCustomObject
	
	$metaInformation = $entryObject.Connection.MetaInformation
	
	$index = $null
	foreach ($i in 1..5) {
		$titleProp = 'CustomField{0}Title' -f $i
		if ($metaInformation.$titleProp -and $metaInformation.$titleProp -eq $FieldName) { $index = $i; break }
	}
	
	$entityMatch = $null
    if (-not $index) {
        $entities = @()
        if ($metaInformation.CustomFieldEntities -and $metaInformation.CustomFieldEntities.CustomFieldEntity) {
            $entities = @($metaInformation.CustomFieldEntities.CustomFieldEntity)
        }

        if ($entities.Count -gt 0) {
            $entityMatch = $entities | Where-Object { $_.CustomFieldTitle -eq $FieldName } | Select-Object -First 1
        }
    }

    if (-not $index -and -not $entityMatch) {
        throw "Field '$FieldName' not found among custom fields."
    }
	
	if ($index) {

        if ($Sensitive) {
			$entry |
				Set-DSEntryProperty -Path "MetaInformation" -PropertyName "CustomField${index}Hidden" -PropertyValue $true |
				Set-DSEntryProperty -Path "MetaInformation" -PropertyName "CustomField${index}ValueSensitive" -PropertyValue $NewValue |
				Update-DSEntryBase
		}
		else {
			$entry |
				Set-DSEntryProperty -Path "MetaInformation" -PropertyName "CustomField${index}Hidden" -PropertyValue $false |
				Set-DSEntryProperty -Path "MetaInformation" -PropertyName "CustomField${index}Value" -PropertyValue $NewValue |
				Update-DSEntryBase
		}

        return
    }

    if ($Sensitive) {
        Remove-Property $entityMatch 'CustomFieldValue'
        Ensure-NoteProperty $entityMatch 'CustomFieldHidden' "true"
        Ensure-NoteProperty $entityMatch 'CustomFieldType' 'Hidden'
        $filtered = [Devolutions.RemoteDesktopManager.Business.ConnectionMetaInformation]::FilterCustomFieldValueSensitive($NewValue)
        Ensure-NoteProperty $entityMatch 'SafeCustomFieldValueSensitive' $filtered
    }
    else {
        Remove-Property $entityMatch 'SafeCustomFieldValueSensitive'
        Remove-Property $entityMatch 'CustomFieldHidden'
        Remove-Property $entityMatch 'CustomFieldType'
        Ensure-NoteProperty $entityMatch 'CustomFieldValue' $NewValue
    }
	
	$entryObject.Connection.MetaInformation = $metaInformation
	$newEntryXml = $entryObject | Convert-PSCustomObjectToXML
	$entry.Data = $newEntryXml.OuterXml
	Update-DSEntryBase -FromRDMConnection $entry
}
