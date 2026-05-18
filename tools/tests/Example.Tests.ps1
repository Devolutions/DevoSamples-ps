#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }

Describe 'Phase 0 tooling sanity' {
    BeforeAll {
        $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..' '..')).Path
        $script:Canonical  = Join-Path $RepoRoot 'DVLS/entries/Update-DSCredentialPassword.ps1'
        $script:Versions   = Join-Path $RepoRoot 'tools/product-versions.psd1'
    }

    It 'parses the canonical DVLS sample with no parser errors' {
        $tokens = $null
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:Canonical, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty
    }

    It 'product-versions.psd1 declares all four Devolutions surfaces' {
        $data = Import-PowerShellDataFile -Path $script:Versions
        $data.Keys | Should -Contain 'devolutions_powershell'
        $data.Keys | Should -Contain 'rdm'
        $data.Keys | Should -Contain 'dvls'
        $data.Keys | Should -Contain 'hub'
    }

    It 'Test-FrontMatter treats legacy files as valid status: legacy' {
        $result = & (Join-Path $RepoRoot 'tools/Test-FrontMatter.ps1') -Path $script:Canonical
        $result.Valid  | Should -BeTrue
        $result.Status | Should -Be 'legacy'
    }
}
