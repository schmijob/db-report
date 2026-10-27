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

Use the `db-workbench` TUI to synchronize PROD procedures into this directory
and LOCAL, create an ignored `.worktrees/<name>` task worktree, test the change,
commit and push it, review the GitHub diff, and explicitly deploy the reviewed
worktree. Optional LOCAL smoke tests live in `tests/<procedure_name>.sql`.

The repository root stays on `main`; `.worktrees/` is temporary and must never
be committed.

`proc_ueb_personalakte_scd_sync(p_gueltig_von)` records one normalized snapshot
in compact intervals and, outside backfill, rebuilds the serving SCD. The
reconciler takes the latest `aenderungsdatum` for each effective date and
field. If equally recent records disagree, a date value is invalid, or a change
already present by the snapshot's `filedate` disagrees with that snapshot, it
uses the snapshot value for that field and records the conflict in
`tbl_ueb_personalakte_scd_reconciliation`. A later-imported retroactive change
remains authoritative over an older snapshot.

For historical CSV replay, set `@personalakte_scd_backfill = 1`, truncate
`tbl_ueb_personalakte_scd_snapshot` and `tbl_ueb_personalakte_scd`, then load
each CSV into `tbl_import_personalakte` oldest to newest and call
`proc_uebertrag_personalakte`. After the last snapshot, call
`proc_ueb_personalakte_scd_reconcile()` and reset the flag to `0`. Backfill
skips the current-day calendar side effects and delays reconciliation until the
full snapshot range is loaded. `proc_uebertrag_aenderungen` also rebuilds the
serving SCD after refreshing the change log.
