#Requires -Version 7.0

[CmdletBinding(DefaultParameterSetName = 'Skeleton')]
param(
    [Parameter(ParameterSetName = 'Skeleton', Mandatory)]
    [switch]$Skeleton,

    [Parameter(ParameterSetName = 'Skeleton', Mandatory)]
    [ValidateSet('DVLS', 'RDM', 'Hub', 'RDMBatchAction')]
    [string]$Product,

    [Parameter(ParameterSetName = 'Skeleton', Mandatory)]
    [string]$Category,

    [Parameter(ParameterSetName = 'Skeleton', Mandatory)]
    [string]$Title,

    [Parameter(ParameterSetName = 'Skeleton')]
    [string]$Id,

    [Parameter(ParameterSetName = 'InferFrom', Mandatory)]
    [string]$InferFrom
)

$ErrorActionPreference = 'Stop'

$toolsDir       = Split-Path -Parent $PSCommandPath
$versionsFile   = Join-Path $toolsDir 'product-versions.psd1'
$productVersions = Import-PowerShellDataFile -Path $versionsFile

# Per-product target defaults. min values reflect the floor we publicly support.
$targetDefaults = @{
    devolutions_powershell = @{ min = '2024.3.0' }
    rdm                    = @{ min = '2024.1' }
    dvls                   = @{ min = '2024.2' }
    hub                    = @{ min = '2024.1' }
}

function Get-TargetsForProduct {
    param([string]$ProductName)
    $targets = [ordered]@{}
    switch ($ProductName) {
        'DVLS'           { $surfaces = @('devolutions_powershell', 'dvls') }
        'RDM'            { $surfaces = @('devolutions_powershell', 'rdm')  }
        'Hub'            { $surfaces = @('devolutions_powershell', 'hub')  }
        'RDMBatchAction' { $surfaces = @('rdm') }
    }
    foreach ($s in $surfaces) {
        $targets[$s] = [ordered]@{
            min          = $targetDefaults[$s].min
            tested_up_to = $productVersions[$s]
        }
    }
    return $targets
}

function ConvertTo-IndentedYaml {
    # Minimal YAML emitter for our fixed schema shape. Handles:
    # - Ordered hashtables (objects)
    # - Arrays of strings
    # - Arrays of ordered hashtables (params)
    # - Scalars: string, int, bool, null
    param(
        [Parameter(Mandatory)] $Value,
        [int]$Indent = 0
    )
    $sb  = [System.Text.StringBuilder]::new()
    $pad = ' ' * $Indent

    if ($null -eq $Value) {
        return 'null'
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            $v = $Value[$key]
            if ($null -eq $v) {
                [void]$sb.AppendLine("${pad}${key}: null")
            }
            elseif ($v -is [System.Collections.IDictionary]) {
                [void]$sb.AppendLine("${pad}${key}:")
                [void]$sb.Append((ConvertTo-IndentedYaml -Value $v -Indent ($Indent + 2)))
            }
            elseif ($v -is [System.Collections.IList] -and $v -isnot [string]) {
                if ($v.Count -eq 0) {
                    [void]$sb.AppendLine("${pad}${key}: []")
                }
                else {
                    [void]$sb.AppendLine("${pad}${key}:")
                    foreach ($item in $v) {
                        if ($item -is [System.Collections.IDictionary]) {
                            $itemYaml = (ConvertTo-IndentedYaml -Value $item -Indent ($Indent + 4)) -split "`n"
                            $first = $true
                            foreach ($line in $itemYaml) {
                                if (-not $line) { continue }
                                if ($first) {
                                    [void]$sb.AppendLine(("${pad}  - " + $line.TrimStart()))
                                    $first = $false
                                }
                                else {
                                    [void]$sb.AppendLine($line)
                                }
                            }
                        }
                        else {
                            [void]$sb.AppendLine("${pad}  - " + (Format-YamlScalar $item))
                        }
                    }
                }
            }
            else {
                [void]$sb.AppendLine("${pad}${key}: " + (Format-YamlScalar $v))
            }
        }
    }
    return $sb.ToString()
}

function Format-YamlScalar {
    param($Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [bool]) { return $Value.ToString().ToLowerInvariant() }
    if ($Value -is [int] -or $Value -is [long] -or $Value -is [double]) { return [string]$Value }
    $s = [string]$Value
    if ($s -match '^[A-Za-z0-9._/-]+$' -and $s -notmatch '^(true|false|null|yes|no)$') {
        return $s
    }
    return '"' + ($s -replace '\\', '\\\\' -replace '"', '\"') + '"'
}

function New-Skeleton {
    param([string]$ProductName, [string]$CategoryName, [string]$TitleText, [string]$IdText)

    $effectiveId = if ($IdText) { $IdText } else { ($TitleText -replace '\s+', '-') }

    $fm = [ordered]@{
        id             = $effectiveId
        title          = $TitleText
        product        = $ProductName
        category       = $CategoryName
        script_version = '0.1.0'
        status         = 'active'
        targets        = Get-TargetsForProduct -ProductName $ProductName
        cmdlets        = @()
        params         = @()
        tags           = @()
        author         = ''
        last_updated   = (Get-Date -Format 'yyyy-MM-dd')
    }

    return ConvertTo-IndentedYaml -Value $fm
}

function Get-InferredFrontMatter {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "File not found: $Path"
    }

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $Path).Path, [ref]$tokens, [ref]$errors)

    $functionAst = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)

    $funcName = if ($functionAst) { $functionAst.Name } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }

    # Heuristic product inference from function verb-noun.
    $inferredProduct = 'DVLS'
    if ($funcName -match '-(DS|DVLS)[A-Z]') { $inferredProduct = 'DVLS' }
    elseif ($funcName -match '-RDM[A-Z]')    { $inferredProduct = 'RDM' }
    elseif ($funcName -match '-Hub[A-Z]')    { $inferredProduct = 'Hub' }
    elseif ([System.IO.Path]::GetExtension($Path) -eq '.md') { $inferredProduct = 'RDMBatchAction' }

    # Params from [Parameter] blocks.
    $params = @()
    if ($functionAst -and $functionAst.Body.ParamBlock) {
        foreach ($p in $functionAst.Body.ParamBlock.Parameters) {
            $isMandatory = $false
            foreach ($attr in $p.Attributes) {
                if ($attr.TypeName.Name -eq 'Parameter') {
                    foreach ($na in $attr.NamedArguments) {
                        if ($na.ArgumentName -eq 'Mandatory') { $isMandatory = $true }
                    }
                }
            }
            $typeName = if ($p.StaticType) { $p.StaticType.Name } else { 'object' }
            $params += [ordered]@{
                name      = $p.Name.VariablePath.UserPath
                type      = $typeName
                mandatory = $isMandatory
            }
        }
    }

    # Cmdlets called inside the script — only collect Devolutions ones.
    $cmdletNames = @{}
    $commands = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
    foreach ($cmd in $commands) {
        $name = $cmd.GetCommandName()
        if ($name -and ($name -match '-(DS|RDM|Hub|DVLS)\w+$')) {
            $cmdletNames[$name] = $true
        }
    }

    # Category from path: parent folder name.
    $category = (Split-Path -Parent $Path | Split-Path -Leaf).ToLowerInvariant()

    $fm = [ordered]@{
        id             = $funcName
        title          = $funcName
        product        = $inferredProduct
        category       = $category
        script_version = '0.1.0'
        status         = 'active'
        targets        = Get-TargetsForProduct -ProductName $inferredProduct
        cmdlets        = @($cmdletNames.Keys | Sort-Object)
        params         = $params
        tags           = @()
        author         = ''
        last_updated   = (Get-Date -Format 'yyyy-MM-dd')
    }

    return ConvertTo-IndentedYaml -Value $fm
}

function Wrap-Block {
    param([string]$Yaml, [string]$Format)
    if ($Format -eq 'md') {
        return "<!--FRONTMATTER`n$Yaml`nFRONTMATTER-->"
    }
    return "<#FRONTMATTER`n$Yaml`nFRONTMATTER#>"
}

switch ($PSCmdlet.ParameterSetName) {
    'Skeleton' {
        $yaml = New-Skeleton -ProductName $Product -CategoryName $Category -TitleText $Title -IdText $Id
        $fmt = if ($Product -eq 'RDMBatchAction') { 'md' } else { 'ps1' }
        Wrap-Block -Yaml $yaml.TrimEnd() -Format $fmt
    }
    'InferFrom' {
        $yaml = Get-InferredFrontMatter -Path $InferFrom
        $fmt  = if ([System.IO.Path]::GetExtension($InferFrom) -eq '.md') { 'md' } else { 'ps1' }
        Wrap-Block -Yaml $yaml.TrimEnd() -Format $fmt
    }
}
