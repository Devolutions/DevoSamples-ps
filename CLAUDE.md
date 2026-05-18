# Claude contract for DevoSamples-ps

This is the Devolutions PowerShell samples collection — see `README.md` for product intent. This file tells you (Claude) how to work in this repo.

## Where files live

The repo runs on a strict location-as-status rule:

| Location | Status | Front matter | Lint mode |
|---|---|---|---|
| `src/<product>/<category>/` | `active` | **mandatory** | strict |
| Repo root `DVLS/`, `RDM/`, `Hub/`, `custom_batch_actions/` | implicit `legacy` | not required | lenient |

- **Modern scripts live under `src/`.** New work always lands there.
- **Legacy paths are frozen.** Don't move, rename, or reformat their files. They stay until stakeholders confirm no downstream consumer is loading them, after which a follow-up PR may delete them.
- The version pin lives purely in front-matter metadata, never in folder names — `src/` does not contain a `2026.1/` sub-root.

## Two authoring paths (must stay separated forever)

| Path | Where | Shape |
|---|---|---|
| **Module path** | `src/{DVLS,RDM,Hub}/<category>/*.ps1` | Standalone `.ps1`. Defines `function Verb-DSxxx` / `Verb-RDMxxx` / `Verb-Hubxxx`. Carries comment-based help, `[Parameter(Mandatory)]` blocks, `Import-Module Devolutions.PowerShell -ErrorAction Stop` at the top of the function body. |
| **Batch-action path** | `src/custom_batch_actions/*.md` (or legacy `custom_batch_actions/*.md`) | Snippets pasted into RDM's *Edit → Edit (special actions) → Custom PowerShell command*. **No** `function`, `param`, or `Import-Module`. Operates on the ambient `$connection` / `$RDM`. Ends with `$RDM.Save();`. See `custom_batch_actions/README.md` for the canonical pattern. |

## Front matter

Every file under `src/` carries an inline YAML block:

- `.ps1`: wrapped in `<#FRONTMATTER ... FRONTMATTER#>`
- `.md`:  wrapped in `<!--FRONTMATTER ... FRONTMATTER-->`

Required fields: `id`, `title`, `product`, `category`, `script_version`, `status`, `targets`. The formal contract is `tools/schema/frontmatter.schema.json`.

`script_version` is SemVer (`0.1.0` for a new script; bump on substantive edit).
`status` is one of `active | legacy | deprecated`.
`targets` is a per-product compatibility window:

```yaml
script_version: 0.1.0
status: active
targets:
  devolutions_powershell:
    min: 2024.3.0
    tested_up_to: 2026.1.0
  dvls:                    # or rdm / hub, omit any not used
    min: 2024.2
    tested_up_to: 2026.1
```

**Defaults for this campaign**: `script_version: 0.1.0`, `tested_up_to: 2026.1`. The authoritative current product versions live in `tools/product-versions.psd1` — read it, don't guess. `tools/New-FrontMatter.ps1` reads it automatically.

## Workflows

### Creating a new script

1. `/new-script <product> <category> <name>` — writes under `src/` with front matter pre-filled.
2. Fill in the logic.
3. `/lint <path>` — confirm strict checks pass.
4. `/build-catalog` — refresh the index.

### Editing a script

- **Under `src/`** — the PostEdit hook runs strict checks automatically. Fix any issues before moving on. Bump `script_version` if the change is substantive.
- **At legacy paths** — the hook prints a "consider migrating to `src/`" nudge but doesn't block. Don't reformat opportunistically. If you're touching it for a real reason, consider `/migrate` instead.

### Migrating a legacy script

1. `/migrate <legacy-path>` — copies forward to `src/<same-path>`, infers front matter via AST walk, leaves legacy file untouched.
2. Review the inferred fields (especially `cmdlets` and `params`).
3. `/lint src/<folder>` to resolve any analyzer warnings on the new file.
4. `/build-catalog -UpdateMigrationDoc` to refresh `MIGRATION.md`.

## Idioms to reuse

These canonical patterns live in the legacy file (still the best reference until that folder is migrated):

- Vault lookup with null-check — `DVLS/entries/Update-DSCredentialPassword.ps1:35-38`
- Entry lookup with duplicate guard — `DVLS/entries/Update-DSCredentialPassword.ps1:40-48`
- Property mutation via pipeline — `DVLS/entries/Update-DSCredentialPassword.ps1:52`

## Don't touch

- `.github/CODEOWNERS`, `.github/workflows/`, `.github/scripts/`, `.github/randy.yml`, `.github/dependabot.yml` — CODEOWNED by `@devolutions/devops` and `@devolutions/security-managers`.
- Any file at a legacy repo-root path, unless you're explicitly migrating it (and even then, the legacy file is preserved in place).

## Don't introduce

- `.psd1` module manifests (this is a samples repo, not a module).
- CI workflows under `.github/` (CODEOWNED).
- Integration tests against a live Devolutions instance.
- Version numbers in folder or file names — the version lives in front matter and `tools/product-versions.psd1`.

## Validation anytime

```sh
pwsh -NoProfile -File tools/Invoke-Check.ps1 -Path <file-or-folder>
pwsh -NoProfile -File tools/Build-Catalog.ps1
pwsh -NoProfile -File tools/Build-Catalog.ps1 -CheckOnly   # exits non-zero on src/ issues
```
