#Requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Path = '.',
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$repoRoot     = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$testFm       = Join-Path $PSScriptRoot 'Test-FrontMatter.ps1'
$pssaConfig   = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
$versionsFile = Join-Path $PSScriptRoot 'product-versions.psd1'

$productVersions = Import-PowerShellDataFile -Path $versionsFile

function Compare-Version {
    param([string]$A, [string]$B)
    $pa = ($A -split '\.') | ForEach-Object { [int]$_ }
    $pb = ($B -split '\.') | ForEach-Object { [int]$_ }
    $len = [Math]::Max($pa.Length, $pb.Length)
    for ($i = 0; $i -lt $len; $i++) {
        $x = if ($i -lt $pa.Length) { $pa[$i] } else { 0 }
        $y = if ($i -lt $pb.Length) { $pb[$i] } else { 0 }
        if ($x -lt $y) { return -1 }
        if ($x -gt $y) { return  1 }
    }
    return 0
}

function Get-FilesToCheck {
    param([string]$Target)
    $resolved = (Resolve-Path -LiteralPath $Target).Path
    if ((Get-Item -LiteralPath $resolved).PSIsContainer) {
        return Get-ChildItem -LiteralPath $resolved -Recurse -File -Include '*.ps1', '*.md' |
            Where-Object {
                $rel = [System.IO.Path]::GetRelativePath($repoRoot, $_.FullName).Replace('\', '/')
                $rel -notmatch '^\.git/' -and $rel -notmatch '^\.github/' -and $_.Name -ne 'README.md'
            }
    }
    return @(Get-Item -LiteralPath $resolved)
}

function Test-File {
    param([System.IO.FileInfo]$File)

    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $File.FullName).Replace('\', '/')
    $isInSrc = $relPath.StartsWith('src/')
    $ext     = $File.Extension.ToLowerInvariant()

    $issues = New-Object System.Collections.Generic.List[psobject]
    $exit = 0

    # Syntax parse for .ps1
    if ($ext -eq '.ps1') {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $File.FullName, [ref]$tokens, [ref]$errors)
        foreach ($e in $errors) {
            $issues.Add([pscustomobject]@{
                severity = 'Error'
                source   = 'parser'
                message  = $e.Message
                line     = $e.Extent.StartLineNumber
            })
            $exit = [Math]::Max($exit, 1)
        }
    }

    # PSScriptAnalyzer for .ps1
    if ($ext -eq '.ps1' -and (Get-Module -ListAvailable PSScriptAnalyzer)) {
        $findings = Invoke-ScriptAnalyzer -Path $File.FullName -Settings $pssaConfig -ErrorAction SilentlyContinue
        foreach ($f in $findings) {
            $issues.Add([pscustomobject]@{
                severity = "$($f.Severity)"
                source   = 'PSScriptAnalyzer'
                rule     = $f.RuleName
                message  = $f.Message
                line     = $f.Line
            })
            if ($isInSrc -and $f.Severity -eq 'Error') {
                $exit = [Math]::Max($exit, 1)
            }
        }
    }

    # Front matter
    $fm = & $testFm -Path $File.FullName
    foreach ($e in $fm.Errors) {
        $issues.Add([pscustomobject]@{
            severity = if ($isInSrc) { 'Error' } else { 'Information' }
            source   = 'frontmatter'
            message  = $e
        })
        if ($isInSrc) { $exit = [Math]::Max($exit, 2) }
    }

    # Version gate (strict scope only)
    if ($isInSrc -and $fm.FrontMatter -and $fm.FrontMatter.targets) {
        foreach ($surface in $fm.FrontMatter.targets.Keys) {
            $block   = $fm.FrontMatter.targets[$surface]
            $current = [string]$productVersions[$surface]
            if (-not $current) { continue }

            if ($block.min -and (Compare-Version $block.min $current) -gt 0) {
                $issues.Add([pscustomobject]@{
                    severity = 'Error'
                    source   = 'version-gate'
                    message  = "targets.$surface.min ($($block.min)) is above current product version ($current). Script targets the future."
                })
                $exit = [Math]::Max($exit, 3)
            }
            if ($block.tested_up_to -and (Compare-Version $block.tested_up_to $current) -lt 0) {
                $issues.Add([pscustomobject]@{
                    severity = 'Warning'
                    source   = 'version-gate'
                    message  = "targets.$surface.tested_up_to ($($block.tested_up_to)) is below current product version ($current). Re-validate and bump."
                })
            }
        }
    }

    # Legacy nudge
    if (-not $isInSrc) {
        $issues.Add([pscustomobject]@{
            severity = 'Information'
            source   = 'migration'
            message  = "Legacy file edited — consider migrating to src/$relPath via /migrate."
        })
    }

    [pscustomobject]@{
        Path     = $relPath
        InSrc    = $isInSrc
        ExitCode = $exit
        Issues   = $issues.ToArray()
    }
}

$files = Get-FilesToCheck -Target $Path
$results = foreach ($f in $files) { Test-File -File $f }

$overall = 0
foreach ($r in $results) {
    if ($r.ExitCode -gt $overall) { $overall = $r.ExitCode }
}

if ($Json) {
    [pscustomobject]@{
        results  = $results
        exitCode = $overall
    } | ConvertTo-Json -Depth 8
}
else {
    foreach ($r in $results) {
        if ($r.Issues.Count -eq 0) {
            Write-Host "[ok]      $($r.Path)"
            continue
        }
        $errCount  = ($r.Issues | Where-Object severity -eq 'Error').Count
        $warnCount = ($r.Issues | Where-Object severity -eq 'Warning').Count
        $infoCount = ($r.Issues | Where-Object severity -eq 'Information').Count
        $tag = if ($r.InSrc) { 'src' } else { 'legacy' }
        Write-Host "[$tag] $($r.Path) — errors=$errCount warnings=$warnCount info=$infoCount"
        foreach ($iss in $r.Issues) {
            $sev = $iss.severity.ToString().PadRight(11)
            $loc = if ($iss.line) { ":$($iss.line)" } else { '' }
            Write-Host "    $sev $($iss.source)$loc — $($iss.message)"
        }
    }
    Write-Host ""
    Write-Host "Exit: $overall (0=clean/warnings, 1=analyzer error, 2=front-matter error, 3=version gate)"
}

exit $overall
