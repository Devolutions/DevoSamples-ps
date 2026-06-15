<#
.SYNOPSIS
    Migrate legacy "Web" and "Credential" entries to the modern "WebBrowser"
    connection type across all (or selected) RDM repositories/vaults.

.DESCRIPTION
    Hardened rewrite of LegacyToWeb.ps1. Key improvements over the original:

      * SupportsShouldProcess  -> run with -WhatIf to preview, no changes made.
      * -Discover mode         -> dumps the REAL property names/values for matching
                                  entries so you can confirm the data model first.
      * Create-then-delete      -> builds a NEW WebBrowser entry from the legacy data
                                  (same name + folder) and removes the legacy entry.
                                  Flipping ConnectionType on the existing entry does
                                  NOT persist, which is why nothing changed before.
      * -KeepLegacy             -> keep the original entry instead of deleting it.
      * Update-RDMEntries        called AFTER switching vault (refresh cache) so the
                                  enumeration reflects the selected repository.
      * Robust legacy filter     that tolerates ConnectionTypeInfos being a collection.
      * Credentials persisted via the dedicated Set-RDMSession* cmdlets with -SetSession
        and -ID, so they land in the WebBrowser 'Web' block.
      * Run summary             with replaced / copied / skipped / failed counts.

.PARAMETER VaultName
    Optional. One or more repository names (wildcards allowed). Default: all vaults.

.PARAMETER KeepLegacy
    Keep the original legacy entry instead of deleting it after the WebBrowser
    entry is created (results in a duplicate; useful for side-by-side testing).

.PARAMETER Discover
    Inspect matching entries and print their actual ConnectionType and any
    url/web/site/user/domain properties, then exit WITHOUT changing anything.
    Run this first to confirm the property model in your environment.

.EXAMPLE
    .\LegacyToWeb.Improved.ps1 -Discover
    # See what would be matched and which properties hold the URL/user/domain.

.EXAMPLE
    .\LegacyToWeb.Improved.ps1 -WhatIf
    # Preview the migration without writing anything.

.EXAMPLE
    .\LegacyToWeb.Improved.ps1 -VaultName 'Production*'
    # Migrate only vaults whose name starts with "Production".
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]] $VaultName,

    [switch]   $Discover,

    # By default the legacy entry is DELETED after the new WebBrowser entry is
    # created. Use -KeepLegacy to leave the original in place (creates a duplicate).
    [switch]   $KeepLegacy,

    [string]   $DataSourceName = '<Data Source Name>'
)

$ErrorActionPreference = 'Stop'

#-----------------------------------------------------------------------------
# Authenticate: select the data source to operate against
#-----------------------------------------------------------------------------

$ds = Get-RDMDataSource | Where-Object {$_.Name -eq $DataSourceName}

Set-RDMCurrentDataSource $ds

# Legacy data-entry kinds to migrate. NOTE: such entries report a top-level
# ConnectionType of "DataEntry"; the real kind is in
# DataEntry.ConnectionTypeInfos[].DataEntryConnectionType (e.g. "Web").
$script:LegacyKindsToMigrate        = @('Web', 'Credential')

#-----------------------------------------------------------------------------
# Helpers
#-----------------------------------------------------------------------------

function Get-LegacyKind {
    # Returns 'Web' or 'Credential' if this entry is a legacy data entry of that
    # kind, otherwise $null. ConnectionTypeInfos may be a scalar OR a collection,
    # so normalize with @(...) before reading DataEntryConnectionType.
    param($Entry)

    $data = Get-EntryValue -Object $Entry -Name 'DataEntry'
    if (-not $data) { return $null }

    $infos = @(Get-EntryValue -Object $data -Name 'ConnectionTypeInfos')
    foreach ($info in $infos) {
        if (-not $info) { continue }
        $kind = "$($info.DataEntryConnectionType)"
        if ($kind -in $script:LegacyKindsToMigrate) { return $kind }
    }
    return $null
}

function Get-EntryValue {
    # Safely read a possibly-missing nested property; returns $null if absent.
    param($Object, [string] $Name)
    if (-not $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $null
}

function Get-LegacySourceFields {
    # Pulls URL / domain / user from the correct legacy location for the kind.
    param($Entry, [string] $Kind)

    $data = (Get-EntryValue -Object $Entry -Name 'DataEntry')

    if ($Kind -eq 'Web') {
        return [pscustomobject]@{
            Url    = Get-EntryValue -Object $data -Name 'URL'
            Domain = Get-EntryValue -Object $data -Name 'WebDomain'
            User   = Get-EntryValue -Object $data -Name 'WebUserName'
        }
    }
    else { # Credential
        return [pscustomobject]@{
            Url    = Get-EntryValue -Object $data -Name 'URL'
            Domain = Get-EntryValue -Object $data -Name 'Domain'
            User   = Get-EntryValue -Object $data -Name 'UserName'
        }
    }
}

function Get-MatchingEntries {
    # All legacy Web/Credential entries in the current vault, tagged with kind.
    Get-RDMSession | ForEach-Object {
        $kind = Get-LegacyKind -Entry $_
        if ($kind) {
            [pscustomobject]@{ Entry = $_; Kind = $kind }
        }
    }
}

#-----------------------------------------------------------------------------
# Vault selection
#-----------------------------------------------------------------------------

$allVaults = @(Get-RDMRepository)
if ($allVaults.Count -eq 0) {
    throw 'No repositories/vaults were found in the current data source.'
}

if ($VaultName) {
    $vaults = @(
        $allVaults | Where-Object {
            $name = $_.Name
            $VaultName | Where-Object { $name -like $_ }
        }
    )
    if ($vaults.Count -eq 0) {
        throw "No repositories matched -VaultName: $($VaultName -join ', ')"
    }
}
else {
    $vaults = $allVaults
}

Write-Host ("Processing {0} of {1} vault(s)." -f $vaults.Count, $allVaults.Count) -ForegroundColor Cyan

#-----------------------------------------------------------------------------
# Discover mode: report only, change nothing
#-----------------------------------------------------------------------------

if ($Discover) {
    foreach ($vault in $vaults) {
        Set-RDMCurrentRepository -Repository $vault
        Update-RDMEntries

        $legacyEntries = @(Get-MatchingEntries)
        Write-Host ("`n=== Vault '{0}': {1} legacy entr(y/ies) ===" -f $vault.Name, $legacyEntries.Count) -ForegroundColor Yellow

        foreach ($m in $legacyEntries | Select-Object -First 10) {
            $e = $m.Entry
            Write-Host ("`n[{0}] '{1}'  (legacy kind: {2}, ConnectionType: {3})" -f `
                $e.ID, $e.Name, $m.Kind, $e.ConnectionType)

            $interesting = $e.PSObject.Properties |
                Where-Object { $_.Name -match 'url|web|site|user|domain' } |
                Sort-Object Name
            foreach ($p in $interesting) {
                # Never print anything password-like.
                if ($p.Name -match 'pass|secret|pwd') { continue }
                Write-Host ("    {0,-22} = {1}" -f $p.Name, $p.Value)
            }
        }
        if ($legacyEntries.Count -gt 10) {
            Write-Host ("    ... and {0} more (showing first 10)." -f ($legacyEntries.Count - 10))
        }
    }
    Write-Host "`nDiscover complete. No changes were made." -ForegroundColor Cyan
    return
}

#-----------------------------------------------------------------------------
# Migration
#-----------------------------------------------------------------------------

$summary = [System.Collections.Generic.List[object]]::new()

foreach ($vault in $vaults) {
    Set-RDMCurrentRepository -Repository $vault
    Update-RDMEntries   # refresh the cache for the newly selected vault BEFORE reading

    $legacyEntries = @(Get-MatchingEntries)
    if ($legacyEntries.Count -eq 0) {
        Write-Host ("Vault '{0}': no legacy Web/Credential entries." -f $vault.Name)
        continue
    }

    Write-Host ("`nVault '{0}': {1} legacy entr(y/ies) to migrate." -f $vault.Name, $legacyEntries.Count) -ForegroundColor Cyan

    foreach ($m in $legacyEntries) {
        $entry = $m.Entry
        $kind  = $m.Kind
        $id    = $entry.ID
        $name  = $entry.Name
        $group = Get-EntryValue -Object $entry -Name 'Group'   # folder path, preserved on the new entry

        try {
            $src = Get-LegacySourceFields -Entry $entry -Kind $kind

            if ([string]::IsNullOrWhiteSpace($src.Url)) {
                Write-Warning "Skipping '$name' [$id]: no URL found."
                $summary.Add([pscustomobject]@{ Vault = $vault.Name; Entry = $name; ID = $id; Result = 'Skipped (no URL)' })
                continue
            }

            # Resolve the password as a SecureString (never plain text). A failure
            # here is non-fatal: migrate the entry without carrying the password.
            $securePwd = $null
            try {
                $resolved = Get-RDMSessionPassword -ID $id
                if ($resolved -is [string]) {
                    if (-not [string]::IsNullOrEmpty($resolved)) {
                        $securePwd = ConvertTo-SecureString -String $resolved -AsPlainText -Force
                    }
                }
                elseif ($resolved -is [System.Security.SecureString]) {
                    $securePwd = $resolved
                }
            }
            catch {
                Write-Warning "Could not resolve password for '$name' [$id]; migrating without it. $($_.Exception.Message)"
            }

            $action = if ($KeepLegacy) { "Create WebBrowser copy of $kind" } else { "Replace $kind with WebBrowser" }
            if (-not $PSCmdlet.ShouldProcess("$name [$id]", $action)) {
                $summary.Add([pscustomobject]@{ Vault = $vault.Name; Entry = $name; ID = $id; Result = 'WhatIf' })
                continue
            }

            # 1) Create a NEW WebBrowser entry in the same folder. Flipping
            #    ConnectionType on the existing DataEntry object does NOT persist,
            #    so we build a fresh entry of the correct type instead.
            $new = New-RDMSession -Type WebBrowser -Name $name -Group $group
            $new.WebBrowserUrl = $src.Url
            Set-RDMSession -Session $new
            $newId = $new.ID

            # 2) Set username / domain / password on the new entry by ID with
            #    -SetSession so the module writes them into the WebBrowser 'Web' block.
            if (-not [string]::IsNullOrWhiteSpace($src.User)) {
                Set-RDMSessionUsername -ID $newId -UserName $src.User -SetSession | Out-Null
            }
            if (-not [string]::IsNullOrWhiteSpace($src.Domain)) {
                Set-RDMSessionDomain -ID $newId -Domain $src.Domain -SetSession | Out-Null
            }
            if ($securePwd) {
                Set-RDMSessionPassword -ID $newId -Password $securePwd -SetSession | Out-Null
            }

            # 3) Remove the legacy entry unless the caller asked to keep it.
            if (-not $KeepLegacy) {
                Remove-RDMSession -ID $id -Force
            }

            $verb = if ($KeepLegacy) { 'Created WebBrowser copy of' } else { 'Replaced' }
            Write-Host ("  {0} '{1}' [{2}] ({3}) -> new WebBrowser [{4}]." -f $verb, $name, $id, $kind, $newId) -ForegroundColor Green
            $summary.Add([pscustomobject]@{
                Vault  = $vault.Name; Entry = $name; ID = $id; NewID = $newId
                Result = if ($KeepLegacy) { 'Copied' } else { 'Replaced' }
            })
        }
        catch {
            Write-Error "Failed to migrate '$name' [$id]: $($_.Exception.Message)"
            $summary.Add([pscustomobject]@{ Vault = $vault.Name; Entry = $name; ID = $id; Result = "Failed: $($_.Exception.Message)" })
        }
    }

    Update-RDMEntries   # let the RDM UI reflect the changes
}

#-----------------------------------------------------------------------------
# Summary
#-----------------------------------------------------------------------------

Write-Host "`n================ Run summary ================" -ForegroundColor Cyan
$summary | Group-Object Result | Sort-Object Name | ForEach-Object {
    Write-Host ("  {0,-28} {1}" -f $_.Name, $_.Count)
}
Write-Host ("  {0,-28} {1}" -f 'TOTAL', $summary.Count)

# Emit the detail objects so callers can pipe / export them.
$summary
