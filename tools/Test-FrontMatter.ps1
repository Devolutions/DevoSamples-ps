#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Path
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

function ConvertFrom-MinimalYaml {
    param([string]$Yaml)

    $rawLines = $Yaml -split "`r?`n"
    $kept = @()
    foreach ($l in $rawLines) {
        if ($l -match '^\s*#') { continue }
        if ($l.Trim().Length -eq 0) { continue }
        $kept += $l
    }
    if ($kept.Count -eq 0) { return [ordered]@{} }

    $minIndent = ($kept | ForEach-Object {
        if ($_ -match '^(\s*)') { $Matches[1].Length } else { 0 }
    } | Measure-Object -Minimum).Minimum

    if ($minIndent -gt 0) {
        $kept = $kept | ForEach-Object { $_.Substring($minIndent) }
    }

    return Convert-YamlBlock -Lines @($kept) -BaseIndent 0
}

function Convert-YamlBlock {
    param([string[]]$Lines, [int]$BaseIndent)

    $result = [ordered]@{}
    $i = 0
    while ($i -lt $Lines.Count) {
        $line   = $Lines[$i]
        $indent = ($line -replace '^(\s*).*', '$1').Length
        if ($indent -lt $BaseIndent) { break }
        $trim = $line.Trim()

        if ($trim -match '^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            $key   = $Matches[1]
            $value = $Matches[2]
            if (-not $value) {
                $j = $i + 1
                $children = @()
                while ($j -lt $Lines.Count) {
                    $childIndent = ($Lines[$j] -replace '^(\s*).*', '$1').Length
                    if ($childIndent -le $indent) { break }
                    $children += $Lines[$j]
                    $j++
                }
                if ($children.Count -eq 0) {
                    $result[$key] = $null
                }
                elseif ($children[0].Trim().StartsWith('- ')) {
                    $result[$key] = Convert-YamlSequence -Lines $children
                }
                else {
                    $result[$key] = Convert-YamlBlock -Lines $children -BaseIndent ($indent + 2)
                }
                $i = $j
                continue
            }
            else {
                $result[$key] = Convert-YamlScalar $value
                $i++
                continue
            }
        }
        $i++
    }
    return $result
}

function Convert-YamlSequence {
    param([string[]]$Lines)

    $items = @()
    $i = 0
    while ($i -lt $Lines.Count) {
        $line = $Lines[$i]
        if ($line -notmatch '^(\s*)- (.*)$') { $i++; continue }
        $dashIndent = $Matches[1].Length
        $head       = $Matches[2]

        if ($head -match '^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
            $obj = [ordered]@{}
            $obj[$Matches[1]] = if ($Matches[2]) { Convert-YamlScalar $Matches[2] } else { $null }
            $j = $i + 1
            while ($j -lt $Lines.Count) {
                $next       = $Lines[$j]
                $nextIndent = ($next -replace '^(\s*).*', '$1').Length
                if ($next -match '^\s*-\s' -and $nextIndent -le $dashIndent) { break }
                if ($nextIndent -le $dashIndent) { break }
                if ($next -match '^\s+([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$') {
                    $obj[$Matches[1]] = Convert-YamlScalar $Matches[2]
                }
                $j++
            }
            $items += , $obj
            $i = $j
        }
        else {
            $items += , (Convert-YamlScalar $head)
            $i++
        }
    }
    return , $items
}

function Convert-YamlScalar {
    param([string]$Raw)
    $v = $Raw.Trim()
    if ($v -eq '' -or $v -eq 'null' -or $v -eq '~') { return $null }
    if ($v -eq 'true')  { return $true }
    if ($v -eq 'false') { return $false }
    if ($v -eq '[]')    { return @() }
    if ($v -match '^-?\d+$') { return [int]$v }
    if ($v.StartsWith('"') -and $v.EndsWith('"')) {
        return ($v.Substring(1, $v.Length - 2) -replace '\\"', '"' -replace '\\\\', '\')
    }
    if ($v.StartsWith("'") -and $v.EndsWith("'")) {
        return $v.Substring(1, $v.Length - 2)
    }
    return $v
}

function Test-FrontMatterShape {
    param([Parameter(Mandatory)] $FrontMatter)

    $errors = @()
    $required = 'id', 'title', 'product', 'category', 'script_version', 'status', 'targets'
    foreach ($key in $required) {
        if (-not $FrontMatter.Contains($key) -or $null -eq $FrontMatter[$key] -or "$($FrontMatter[$key])".Trim() -eq '') {
            $errors += "Required field missing or empty: $key"
        }
    }

    $allowedProducts = 'DVLS', 'RDM', 'Hub', 'RDMBatchAction'
    if ($FrontMatter.product -and $FrontMatter.product -notin $allowedProducts) {
        $errors += "Invalid product '$($FrontMatter.product)' (allowed: $($allowedProducts -join ', '))."
    }

    $allowedStatus = 'active', 'legacy', 'deprecated'
    if ($FrontMatter.status -and $FrontMatter.status -notin $allowedStatus) {
        $errors += "Invalid status '$($FrontMatter.status)' (allowed: $($allowedStatus -join ', '))."
    }

    if ($FrontMatter.script_version -and $FrontMatter.script_version -notmatch '^\d+\.\d+\.\d+(-[A-Za-z0-9.-]+)?$') {
        $errors += "Invalid script_version '$($FrontMatter.script_version)' (must be SemVer)."
    }

    if ($FrontMatter.targets -is [System.Collections.IDictionary]) {
        $allowedSurfaces = 'devolutions_powershell', 'rdm', 'dvls', 'hub'
        foreach ($surface in $FrontMatter.targets.Keys) {
            if ($surface -notin $allowedSurfaces) {
                $errors += "Unknown target surface '$surface' (allowed: $($allowedSurfaces -join ', '))."
                continue
            }
            $block = $FrontMatter.targets[$surface]
            if ($block -isnot [System.Collections.IDictionary]) {
                $errors += "targets.$surface must be an object with min/tested_up_to."
                continue
            }
            foreach ($f in @('min', 'tested_up_to')) {
                if (-not $block.Contains($f) -or "$($block[$f])".Trim() -eq '') {
                    $errors += "targets.$surface.$f is required."
                }
                elseif ($block[$f] -notmatch '^\d+\.\d+(\.\d+)?$') {
                    $errors += "targets.$surface.$f = '$($block[$f])' must look like 'N.N' or 'N.N.N'."
                }
            }
        }
    }
    elseif ($FrontMatter.Contains('targets')) {
        $errors += "targets must be an object."
    }

    return $errors
}

# --- Main ---

$resolved = (Resolve-Path -LiteralPath $Path).Path
$relative = [System.IO.Path]::GetRelativePath($repoRoot, $resolved).Replace('\', '/')
$ext      = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
$isInSrc  = $relative.StartsWith('src/')

$content = Get-Content -LiteralPath $resolved -Raw

$openTag  = if ($ext -eq '.md') { '<!--FRONTMATTER' } else { '<#FRONTMATTER' }
$closeTag = if ($ext -eq '.md') { 'FRONTMATTER-->' }    else { 'FRONTMATTER#>' }

$pattern = [regex]::Escape($openTag) + '(?<body>[\s\S]*?)' + [regex]::Escape($closeTag)
$match   = [regex]::Match($content, $pattern)

$result = [ordered]@{
    Path           = $relative
    HasFrontMatter = $match.Success
    Valid          = $false
    Errors         = @()
    Status         = $null
    Targets        = $null
    FrontMatter    = $null
}

if (-not $match.Success) {
    if ($isInSrc) {
        $result.Errors += "Missing <#FRONTMATTER#> block (required for files under src/)."
    }
    else {
        $result.Status = 'legacy'
        $result.Valid  = $true
    }
    [pscustomobject]$result
    return
}

$yaml = $match.Groups['body'].Value
try {
    $fm = ConvertFrom-MinimalYaml -Yaml $yaml
}
catch {
    $result.Errors += "YAML parse failed: $($_.Exception.Message)"
    [pscustomobject]$result
    return
}

$result.FrontMatter = $fm
$result.Status      = $fm.status
$result.Targets     = $fm.targets

foreach ($e in (Test-FrontMatterShape -FrontMatter $fm)) {
    $result.Errors += $e
}

if ($isInSrc -and $fm.status -ne 'active') {
    $result.Errors += "Files under src/ must declare status: active (declared: $($fm.status))."
}
if (-not $isInSrc -and $fm.status -eq 'active') {
    $result.Errors += "Legacy-path files must not declare status: active (use 'legacy' or omit front matter)."
}

$result.Valid = ($result.Errors.Count -eq 0)
[pscustomobject]$result
