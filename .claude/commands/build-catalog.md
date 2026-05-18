---
description: Regenerate CATALOG.md and catalog.json from src/ and legacy paths
---

Regenerate the catalog.

## What to do

1. Run `pwsh -NoProfile -File tools/Build-Catalog.ps1`.
2. If the tool exits non-zero, surface the error to the user — don't proceed.
3. Show the user the diff vs the previous `CATALOG.md` and `catalog.json` using `git diff -- CATALOG.md catalog.json`.
4. If `MIGRATION.md` should be refreshed (i.e. files were just migrated), re-run with `-UpdateMigrationDoc`:
   `pwsh -NoProfile -File tools/Build-Catalog.ps1 -UpdateMigrationDoc`.
5. Tell the user the active/stale/legacy counts (from the tool's final line of stdout).

## Do not

- Commit the regenerated files automatically — the user decides whether to commit.
- Edit `CATALOG.md` or `catalog.json` by hand. They are generated.
