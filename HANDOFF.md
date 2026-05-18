# Handoff — pick up here

> Transient doc. Delete this file when the pwsh install is confirmed working.

## Where we are

- Branch: `claude/setup-scaffolding-0jNdA`, latest commit `0297a5b` ("Migration registry: intent/priority/notes columns in MIGRATION.md").
- Phase 0 scaffolding is committed and pushed: `CLAUDE.md`, `MIGRATION.md` (with the 27-row migration table), `.claude/` (hooks + slash commands + settings.json), `tools/` (PSScriptAnalyzer + Pester configs, product-versions.psd1, JSON schemas, `New-FrontMatter.ps1`, `Test-FrontMatter.ps1`, `Build-Catalog.ps1`, `Invoke-Check.ps1`, one Pester smoke test), `src/README.md`.
- Legacy files (47-ish at repo root) are untouched. `.github/` untouched.

## The one outstanding step

`pwsh` is not present in the web execution environment. Until it is, `Invoke-Check.ps1`, `Build-Catalog.ps1`, the post-edit hook, and `/migrate` all no-op or print "pwsh not available".

**Fix**: paste the snippet below into this repo's environment **Setup script** field in the Claude Code on the web dashboard (Settings → Environments → this repo). Then rebuild the environment.

```bash
#!/bin/bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
. /etc/os-release
wget -q "https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb" -O /tmp/ms.deb
sudo dpkg -i /tmp/ms.deb
sudo apt-get update
sudo apt-get install -y powershell
pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
```

Docs reference: https://code.claude.com/docs/en/claude-code-on-the-web

## Verify after pwsh is in

Start a fresh session. The SessionStart hook should print, as its final line:

```
pwsh=7.x.x, Devolutions.PowerShell=<ver>, Pester=<ver>, PSScriptAnalyzer=<ver>
```

Then run, one at a time:

1. `/lint` — expect exit 0, all legacy files reported as lenient with the "consider migrating" nudge, no errors.
2. `/build-catalog` — expect `CATALOG.md` and `catalog.json` to be created. CATALOG.md should show an empty "Active samples" section and 27 entries under "Legacy samples".
3. `/build-catalog -UpdateMigrationDoc` (run via the slash command or directly) — should leave the curated `intent`/`priority`/`notes` columns in `MIGRATION.md` untouched and confirm all `migrated` boxes are ☐.
4. `pwsh -NoProfile -File tools/Build-Catalog.ps1 -CheckOnly` — should exit 0 (no files under `src/` to validate yet).
5. Spot-test `/new-script DVLS entries Test-Scaffold` in a throwaway worktree to see a full front matter block written under `src/`. Delete the test file after.

If any step fails, the most likely culprits:
- `powershell-yaml` is NOT a dependency — `Test-FrontMatter.ps1` uses a hand-rolled YAML parser tuned to the schema. If it misreads something, the test output will show the line.
- `Invoke-Check.ps1` exit codes: 0 clean/warnings, 1 analyzer error, 2 front-matter error, 3 version-gate failure.

## Ready for Phase 2 once green

After verification:

1. Pick the smallest folder from `MIGRATION.md` (Hub/Security, 1 file).
2. Run `/migrate Hub/Security/ExportPermission.ps1`.
3. Review the inferred front matter; fix `category`, `cmdlets`, `params` if the AST guessed wrong.
4. `/lint src/Hub/security/`.
5. `/build-catalog -UpdateMigrationDoc` — the row's `migrated` should auto-flip to ☑.
6. Commit + push + open the PR. Repeat for the next folder.

`MIGRATION.md` is the to-do list. Edit `intent` (todo|deprecated), `priority` (high|medium|low), and `notes` columns by hand at any time; `Build-Catalog -UpdateMigrationDoc` preserves them and only refreshes `migrated`.

## Things to know

- The `tools/product-versions.psd1` file pins the "current" Devolutions versions (`2026.1` for the campaign). Bumping that file is the single action that retires scripts whose `tested_up_to` falls behind — they auto-downgrade from `active` to `stale` on the next `Build-Catalog` run. No mass edit needed.
- `Bash` tool got disabled in my last session after a resume — I had to push via the GitHub MCP. If that happens again, `mcp__github__push_files` works.
- pwsh is missing on this sandbox so I never end-to-end-ran the PS tooling. First real run will be the verification above.

## Plan source

The detailed approved plan that shaped Phase 0 lives at `/root/.claude/plans/i-want-to-setup-adaptive-storm.md` in the agent's plan dir. Not committed to the repo.
