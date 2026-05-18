---
description: Run PSScriptAnalyzer + front-matter + version-gate checks
argument-hint: [path]
---

Run the unified check.

## What to do

1. If `$ARGUMENTS` is empty, run `pwsh -NoProfile -File tools/Invoke-Check.ps1` (whole repo). Otherwise pass the argument as `-Path`.
2. Report:
   - Files with errors (per the tool's `errors=` count). Strict mode applies to anything under `src/`.
   - Files with warnings (per `warnings=` count).
   - The exit code: `0` clean, `1` analyzer error in strict scope, `2` missing/invalid front matter in strict scope, `3` version-gate failure.
3. If exit was non-zero, propose a fix for the first error before continuing.

## Do not

- Modify legacy files to "clean up" warnings. Legacy files are intentionally lenient and stay as-is until migrated via `/migrate`.
- Auto-bump `tested_up_to` to silence a version-gate warning. Re-validate the script against the new product version first.
