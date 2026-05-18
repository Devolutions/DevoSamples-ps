# src/ — modern Devolutions sample scripts

This is the canonical root for modern Devolutions PowerShell sample scripts.

Every `.ps1` and `.md` here:

- carries an inline `<#FRONTMATTER ... FRONTMATTER#>` YAML block (HTML-comment variant for batch-action `.md` files)
- has `status: active` and a `targets` block declaring the Devolutions product versions it was tested against
- passes `tools/Invoke-Check.ps1` in strict mode
- is indexed in the repo-root `CATALOG.md`

Pre-migration samples remain at the legacy paths (`/DVLS`, `/RDM`, `/Hub`, `/custom_batch_actions`) untouched; see `MIGRATION.md` for the relocation campaign.

**Never edit files here by hand for the first time.** Create new scripts via `/new-script` so the front matter is generated correctly, or migrate a legacy script via `/migrate <legacy-path>`.
