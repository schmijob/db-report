# Stored procedures

This directory is the Git source of truth for stored procedures. Each procedure
is a top-level `<procedure_name>.sql` file with this executable envelope:

```sql
DROP PROCEDURE IF EXISTS `procedure_name`//
CREATE DEFINER=CURRENT_USER PROCEDURE `procedure_name`(...)
SQL SECURITY DEFINER
BEGIN
  -- procedure body
END//
```

## Procedure tests

Keep repeatable cases beside the procedure source in
`procedures/tests/<procedure_name>/`:

```text
procedures/tests/<procedure_name>/
  fixture.sql
  source-checks.sql    # optional checks for source-data assumptions
  prod-fixture.sql     # optional representative rows from PROD
  cases/
    001_case_name/
      before.sql
      call.sql
      after.sql
      reset.sql
```

Use small synthetic rows in `fixture.sql` to express behavior precisely. Each
case checks its starting conditions in `before.sql`, invokes the procedure in
`call.sql`, checks results in `after.sql`, and restores the baseline in
`reset.sql`. Assertions must fail when expectations are false; a `SELECT` that
only prints an unexpected value does not fail a test.

For aggregation cases that need realistic source rows, `prod-fixture.sql` may
select representative rows from PROD for a fixture. Do not commit query output
or production extracts. Source-backed expectations may change as PROD changes;
record the assumptions and inspect the source query when a test fails before
classifying it as a procedure regression. `source-checks.sql` may contain
read-only checks that each return a single true/false value; use these to make
important source-data assumptions explicit.

Optional interactive smoke tests against configured LOCAL live in
`procedures/tests/<procedure_name>.sql`. See the [db-workbench architecture guide](https://github.com/schmijob/db-workbench/blob/main/docs/architecture/architecture.md#procedure-fixture-suite)
for fixture-runner behavior and the [agent skills](https://github.com/schmijob/db-workbench/blob/main/docs/skills/skills.md#configured-project-changes)
for how to run tests and prepare a candidate. The agent-to-human handoff is
defined in this repository's `AGENTS.md`.

## Personalakte SCD

`proc_uebertrag_personalakte` records one normalized snapshot in compact
intervals by calling `proc_ueb_personalakte_scd_snapshot_sync` and, outside
backfill, rebuilds the serving SCD by calling
`proc_ueb_personalakte_scd_reconcile`.
The reconciler takes the latest `aenderungsdatum` for each effective date and
field. If equally recent records disagree, a date value is invalid, or a
change already present by the snapshot's `filedate` disagrees with that
snapshot, it uses the snapshot value for that field and records the conflict
in `tbl_ueb_personalakte_scd_reconciliation`. A later-imported retroactive
change remains authoritative over an older snapshot.

For historical CSV replay, export the `Personalliste ALL.csv` attachments with
the Outlook macro to `C:\db-report\.worktrees\personalakte-backfill\raw`
or another ignored folder under `.worktrees` or `consumers`. Run
`python scripts/prepare_personalliste_backfill.py <raw-folder> --validate-only`
to validate the complete files. The script locates the report header by its
labels while retaining empty separator columns, reads the `Druckdatum` value
for `filedate`, and checks the footer count, dates, and duplicate personnel
numbers. `--structure-only --validate-only` checks the file layout when a
sample has had person values removed; it does not validate cell values.
After validation, run the script once more with `--output <path>` under
`.worktrees` or `consumers` to create one consolidated TSV. The default output
is beside the raw folder. It fails on conflicting snapshots for one date unless
`--latest-per-day` is explicitly selected. Load only that prepared file once
into `tbl_import_personalakte_scd_backfill`; the raw attachments do not need to
be uploaded or loaded separately.

For procedure tests, use small synthetic people and snapshot dates in the
procedure fixture suite under
`procedures/tests/proc_uebertrag_personalakte/` and
`procedures/tests/proc_ueb_personalakte_scd_reconcile/`. Run it from db-workbench's
**Stored procedure development → Run isolated fixture suite in LOCAL** menu.
The runner loads these synthetic fixtures once into a disposable schema; it
does not read the configured LOCAL tables. Do not use the personal exports as
test fixtures.
`proc_uebertrag_personalakte` also updates the materialized current table and
snapshot history, so run a full replay in a disposable database or LOCAL copy,
not against a shared LOCAL schema. The later production backfill is one staging
load followed by one replay call per snapshot date; those calls process the
already loaded rows and do not import the source files again.

Do not replace the live `tbl_import_personalakte`: other procedures read it as
the latest import. Clear `tbl_ueb_personalakte_scd_snapshot` and
`tbl_ueb_personalakte_scd`, then set `@personalakte_scd_backfill = 1` and
`@personalakte_scd_backfill_date` to each snapshot date, oldest to newest, and
call `proc_uebertrag_personalakte` once per date. The procedure reads only that
date from the staging table, skips current-day side effects, and defers
reconciliation until replay is complete. Then call
`proc_ueb_personalakte_scd_reconcile()` and clear both session variables.
After confirming the backfill, truncate the staging table to remove the raw
copies.
`proc_uebertrag_aenderungen` also rebuilds the serving SCD after refreshing the
change log.
