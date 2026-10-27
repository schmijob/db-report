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

For historical CSV replay, load all files into
`tbl_import_personalakte_scd_backfill`, which has the import schema. Do not
replace the live `tbl_import_personalakte`: other procedures read it as the
latest import. Clear `tbl_ueb_personalakte_scd_snapshot` and
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
