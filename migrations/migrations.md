# Database migrations

Versioned database migrations belong here when a schema change needs an ordered
upgrade or rollback step. Keep deployment tooling in `db-workbench`.

## `20261026_personalakte_scd.sql`

Renames the existing one-row-per-person table to
`tbl_ueb_personalakte_current`, creates the compact snapshot baseline and the
reconciled `tbl_ueb_personalakte_scd`, and records unresolved change/snapshot conflicts in
`tbl_ueb_personalakte_scd_reconciliation`. It seeds both interval tables from
the current snapshot, then restores `tbl_ueb_personalakte` and `vp_personal_u`
as compatibility views. This is a one-time migration and must run before
deploying procedures that reference the SCD table. Keep the current backing
table during the compatibility period.

Apply the view definitions under `views/` after the migration. In particular,
the cluster and attendance views no longer reconstruct OE/activity from the
change log for each read; they join the materialized personalakte version by
the fact date.

The migration cannot supply historical coverage. When daily CSV snapshots are
available, clear the two interval tables and replay the files oldest to newest
through `tbl_import_personalakte` with `@personalakte_scd_backfill = 1`. Then
call `proc_ueb_personalakte_scd_reconcile()` and clear the session flag. The
snapshot baseline coalesces identical adjacent states; the serving table adds
only boundaries where a resolved business value changes. Neither stores one
row per person per day.
