---
description: Scaffold a new sample script under src/ with front matter pre-filled
argument-hint: <product> <category> <name>
---

You are creating a new Devolutions PowerShell sample script.

**Arguments**: `$ARGUMENTS` — expected as `<product> <category> <name>`.

Valid `<product>` values: `DVLS`, `RDM`, `Hub`, `RDMBatchAction`.

## What to do

1. Parse the three arguments. If any are missing or `<product>` is not one of the valid values, stop and ask the user for clarification.
2. Determine the target file:
   - For `DVLS`, `RDM`, `Hub`: `src/<product>/<category>/<name>.ps1`
   - For `RDMBatchAction`: `src/custom_batch_actions/<name>.md`
3. If the target file already exists, refuse and tell the user.
4. **Never** write outside `src/`. If the resolved target path is not under `src/`, refuse.
5. Run `pwsh -NoProfile -File tools/New-FrontMatter.ps1 -Skeleton -Product <product> -Category <category> -Title <name>` to generate the front-matter block. Capture its stdout.
6. Write the file with this content:
   - **For `.ps1` files**: the front-matter block, followed by a blank line, then a comment-based help skeleton (`<# .SYNOPSIS ... #>`), then the `function <name> { param() ... }` shell. Include `Import-Module Devolutions.PowerShell -ErrorAction Stop` at the top of the function body.
   - **For batch-action `.md` files**: the front-matter block (using the `<!--FRONTMATTER ... FRONTMATTER-->` variant the tool emits), a markdown heading describing the snippet, and a placeholder PowerShell fenced block with `$connection... ; $RDM.Save();` and no `function`, `param`, or `Import-Module`.
7. Run `pwsh -NoProfile -File tools/Invoke-Check.ps1 -Path <target-file>` to confirm strict-mode validation passes. Resolve any errors before stopping.
8. Tell the user the path, and remind them to run `/build-catalog` once they've filled in the actual logic.

## Idioms to reuse (for DVLS / RDM / Hub scripts)

Cite these patterns from the legacy canonical example when relevant:

- Vault lookup with null-check — `DVLS/entries/Update-DSCredentialPassword.ps1:35-38`
- Entry lookup with duplicate guard — `DVLS/entries/Update-DSCredentialPassword.ps1:40-48`
- Property mutation via pipeline — `DVLS/entries/Update-DSCredentialPassword.ps1:52`

## Do not

- Write to legacy paths (`DVLS/`, `RDM/`, `Hub/`, `custom_batch_actions/` at repo root). Those are frozen.
- Omit the front-matter block.
- Substitute your own version numbers — `New-FrontMatter.ps1` reads `tools/product-versions.psd1` for the authoritative `tested_up_to` value.
