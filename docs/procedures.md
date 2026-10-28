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
`procedures/tests/<procedure_name>.sql`. From the db-report checkout root, see
`../db-workbench/docs/architecture/architecture.md#procedure-fixture-suite`
for fixture-runner behavior and
`../db-workbench/docs/skills/using-db-workbench.md` for shared
procedure-development steps. The agent-to-human handoff is defined in this
repository's `AGENTS.md`.

## Personalakte SCD

Build raw import history first with `proc_uebertrag_personalakte_raw_scd(1)`.
It stores untransformed source values in compact raw-state intervals and keeps
each Druckdatum in `tbl_import_personalakte_scd_dates`.

`proc_uebertrag_personalakte_transform_snapshot` contains the shared
normalization and business rules. `proc_uebertrag_personalakte` calls it for
the current import; `proc_ueb_personalakte_scd_backfill()` calls it for every
date in raw history, oldest to newest. The backfill procedure only builds the
normalized snapshot intervals and serving SCD from the transform output. It
does not copy the normalization rules or write the historical rows into the
current materialized Personalakte table.

For each current file, `proc_uebertrag_personalakte` records the raw import,
uses the shared transform, updates `tbl_ueb_personalakte` and the normalized
snapshot intervals, then calls `proc_ueb_personalakte_scd_reconcile()`.
`proc_uebertrag_aenderungen` also rebuilds the SCD after refreshing the change
log. The raw import SCD remains available to rebuild normalized history if
these business rules change.

The SCD uses canonical `persnr` across resolved PersNr changes and stores the
source number active in each interval as `persnr_alt`. Reconciliation uses
change history as the authority for field values and snapshots as fallback
evidence when the two disagree. It applies a unique adjacent-snapshot PersNr
handoff when the old number disappears and the new number begins with the same
name, subject to available birthday consistency, and records the evidence for
HR review. Date-sensitive facts join by `persnr_alt` and their event date;
canonical person reporting groups by `persnr`.
