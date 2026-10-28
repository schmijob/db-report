# Database migrations

Versioned database migrations belong here when a schema change needs an ordered
upgrade or rollback step. Keep deployment tooling in `db-workbench`.

## `20261028_personalakte_raw_history.sql`

Creates the historical upload table, the compact raw import SCD, and a small
table of export dates. It adds new objects only. The raw SCD retains source
columns as imported, before Personalakte normalization, and stores only state
changes with inclusive `gueltig_von` / `gueltig_bis` ranges. Export dates are
kept separately so unchanged raw rows can be reconstructed for every file.

To prepare the email exports, run:

```powershell
python scripts/prepare_personalliste_backfill.py `
  C:\db-report\.worktrees\personalakte-backfill\raw --validate-only
```

Then run it with `--output <path>` under `.worktrees` or `consumers` to produce
one consolidated TSV for bulk upload. The parser matches labels while
preserving empty separator columns. Every field header can be absent; missing
fields are emitted as SQL `NULL`. Blank PersNr rows are discarded. If a file
has no PersNr column, its people rows are discarded because they cannot be
identified. The footer row is ignored. `Druckdatum` supplies `filedate`, and
`lastinsertupdate` is the preparation timestamp. Use
`--structure-only --validate-only` to check layout without validating values.

After loading the TSV into `tbl_import_personalakte_scd_backfill`, call
`proc_uebertrag_personalakte_raw_scd(1)` once. It rebuilds only the raw SCD and
export-date tables; it does not run any Personalakte business transformations
or write to existing tables. Keep the staging rows until the raw history has
been reviewed and copied to sanitized LOCAL. The downstream normalized SCD
rebuild belongs to the separate cutover change.
