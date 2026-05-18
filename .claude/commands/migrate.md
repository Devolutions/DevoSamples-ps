---
description: Migrate a legacy script into src/ with full front matter
argument-hint: <legacy-path>
---

You are migrating a legacy Devolutions sample script into the modern `src/` root.

**Argument**: `$ARGUMENTS` — the legacy file path (e.g. `DVLS/entries/Update-DSCredentialPassword.ps1`).

## What to do

1. Validate the path:
   - Must exist.
   - Must NOT already be under `src/`.
   - Must be one of `.ps1` or `.md` (under `custom_batch_actions/`).
2. Compute the target path: `src/<original-relative-path>`. Examples:
   - `DVLS/entries/Update-DSCredentialPassword.ps1` → `src/DVLS/entries/Update-DSCredentialPassword.ps1`
   - `Hub/Security/ExportPermission.ps1` → `src/Hub/security/ExportPermission.ps1` (normalize the directory casing to lowercase for `security`).
3. If the target already exists, stop and ask the user how to proceed.
4. Generate the front matter by running `pwsh -NoProfile -File tools/New-FrontMatter.ps1 -InferFrom <legacy-path>`. Capture its stdout.
5. Read the legacy file content.
6. Compose the new file:
   - **For `.ps1`**: the front-matter block first, then a blank line, then the legacy file's content **unchanged** (don't reformat).
   - **For `.md`**: the front-matter block (HTML-comment variant) first, blank line, then the legacy content unchanged.
7. Write the new file at the target path. **Leave the legacy file untouched** — it stays in place for downstream consumers.
8. Show the user the inferred front matter and ask them to confirm fields (especially `category`, `cmdlets`, `params`). If anything is wrong, edit the new file in place.
9. Run `pwsh -NoProfile -File tools/Invoke-Check.ps1 -Path <target-path>`. Resolve any errors.
10. Run `pwsh -NoProfile -File tools/Build-Catalog.ps1 -UpdateMigrationDoc` and show the user the resulting diff.

## Do not

- Move, rename, or modify the legacy file.
- Reformat the original script body during migration (front matter is added; the rest is verbatim).
- Skip the inference review — the AST walker can guess wrong on `cmdlets` and `params`.
