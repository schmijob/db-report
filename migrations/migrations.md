# Database migrations

Versioned database migrations belong here when a schema change needs an ordered
upgrade or rollback step. Keep deployment tooling in `db-workbench`.

## `20261026_personalakte_scd.sql`

Creates the isolated historical upload table, compact snapshot intervals, the
date-sensitive Personalakte table, and reconciliation evidence. It does not
change the live import, current materialized table, views, or existing
procedures. The new backfill procedure rebuilds only these new interval and
evidence tables from `tbl_import_personalakte_scd_backfill`; it reads the
existing current Personalakte and change history when resolving candidate
PersNr handoffs.

Load dated exports into `tbl_import_personalakte_scd_backfill` using the
prepared TSV. First run:

```powershell
python scripts/prepare_personalliste_backfill.py `
  C:\db-report\.worktrees\personalakte-backfill\raw --validate-only
```

Then run it with `--output <path>` under `.worktrees` or `consumers` to write
one consolidated TSV for the bulk upload. The parser matches headers by label
while preserving empty separator columns. Each field header is optional and a
missing field is emitted as SQL `NULL`; blank PersNr rows are discarded. If a
file has no PersNr column, all of its people rows are discarded because they
cannot be identified. The footer row is ignored. `Druckdatum` supplies
`filedate`; `lastinsertupdate` is the preparation timestamp. Use
`--structure-only --validate-only` when a sample has had personal values
removed and only its layout should be checked.

After bulk loading the prepared file, call
`proc_ueb_personalakte_scd_backfill()` once. It replays all available Druckdatum
dates oldest to newest and rebuilds the snapshot and serving intervals. Keep
the upload table until the result has been reviewed and copied to the sanitized
LOCAL database. Birthday values are optional evidence in the raw snapshot
table and are not exposed by the serving SCD.
