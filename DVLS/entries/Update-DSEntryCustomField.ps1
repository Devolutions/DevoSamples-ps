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
    $entry = Get-DSEntry -VaultID $vault.ID -FilterMatch ExactExpression -FilterValue $EntryName
	$entryObject = $entry.data | Convert-XMLToPSCustomObject;
	
	$metaInformation = $entryObject.Connection.MetaInformation
	
	$index = ($null)
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
        $plainProp = 'CustomField{0}Value' -f $index
        $hiddenProp = 'CustomField{0}Hidden' -f $index
        $sensitiveProp = 'SafeCustomField{0}ValueSensitive' -f $index

        if ($Sensitive) {
            Remove-Property $metaInformation $plainProp
            Ensure-NoteProperty $metaInformation $hiddenProp "true"
            $filtered = [Devolutions.RemoteDesktopManager.Business.ConnectionMetaInformation]::FilterCustomFieldValueSensitive($NewValue)
            Ensure-NoteProperty $metaInformation $sensitiveProp $filtered
        }
        else {
            Remove-Property $metaInformation $sensitiveProp
            Remove-Property $metaInformation $hiddenProp
            Ensure-NoteProperty $metaInformation $plainProp $NewValue
        }
    }
    else {
        $e = $entityMatch

        if ($Sensitive) {
            Remove-Property $e 'CustomFieldValue'
            Ensure-NoteProperty $e 'CustomFieldHidden' "true"
            Ensure-NoteProperty $e 'CustomFieldType' 'Hidden'
            $filtered = [Devolutions.RemoteDesktopManager.Business.ConnectionMetaInformation]::FilterCustomFieldValueSensitive($NewValue)
            Ensure-NoteProperty $e 'SafeCustomFieldValueSensitive' $filtered
        }
        else {
            Remove-Property $e 'SafeCustomFieldValueSensitive'
            Remove-Property $e 'CustomFieldHidden'
            Remove-Property $e 'CustomFieldType'
            Ensure-NoteProperty $e 'CustomFieldValue' $NewValue
        }
    }
	
	$entryObject.Connection.MetaInformation = $metaInformation
	$newEntryXml = $entryObject | Convert-PSCustomObjectToXML
	$entry.Data = $newEntryXml.OuterXml
	Update-DSEntryBase -FromRDMConnection $entry
}
