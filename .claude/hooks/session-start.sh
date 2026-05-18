#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

echo "Setting up Devolutions PowerShell sample env..."

if ! command -v pwsh >/dev/null 2>&1; then
  echo "pwsh not available — batch-action editing still works; module-path scripts and tooling won't run"
  exit 0
fi

pwsh_version="$(pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>/dev/null || echo 'unknown')"

set +e
timeout 120 pwsh -NoProfile -Command '
$ErrorActionPreference = "Stop"
if (-not (Get-Module -ListAvailable Devolutions.PowerShell)) {
    Install-Module Devolutions.PowerShell -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
}
if (-not (Get-Module -ListAvailable Pester)) {
    Install-Module Pester -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
}
if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
    Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -ErrorAction Stop
}
' >/dev/null 2>&1
install_status=$?
set -e

if [ $install_status -ne 0 ]; then
  echo "Warning: one or more PowerShell module installs failed or timed out (status=$install_status). Continuing — tooling may be unavailable until you install manually."
fi

mod_version() {
  local name="$1"
  pwsh -NoProfile -Command "
    \$m = Get-Module -ListAvailable $name | Sort-Object Version -Descending | Select-Object -First 1
    if (\$m) { \$m.Version.ToString() } else { 'missing' }
  " 2>/dev/null || echo 'missing'
}

devo_ver="$(mod_version Devolutions.PowerShell)"
pester_ver="$(mod_version Pester)"
pssa_ver="$(mod_version PSScriptAnalyzer)"

echo "pwsh=${pwsh_version}, Devolutions.PowerShell=${devo_ver}, Pester=${pester_ver}, PSScriptAnalyzer=${pssa_ver}"
