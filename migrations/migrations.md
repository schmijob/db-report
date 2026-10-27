# Database migrations

Versioned database migrations belong here when a schema change needs an ordered
upgrade or rollback step. Keep deployment tooling in `db-workbench`.

## `20261026_personalakte_scd.sql`

Keeps the existing materialized one-row-per-person table, creates the compact
snapshot baseline, the reconciled `tbl_ueb_personalakte_scd`, the reconciliation
inspection table, and a separate import-schema staging table for historical
CSVs. It seeds both interval tables from the current snapshot and recreates the
legacy `tbl_ueb_personalakte` and `vp_personal_u` views over the materialized
current table. This is a one-time migration and must run before deploying
procedures that reference the SCD table.

Apply the view definitions under `views/` after the migration. In particular,
the cluster and attendance views no longer reconstruct OE/activity from the
change log for each read; they join the materialized personalakte version by
the fact date.

The migration cannot supply historical coverage. When daily CSV snapshots are
available, load them into `tbl_import_personalakte_scd_backfill`, not the live
`tbl_import_personalakte`. Clear the two interval tables, set
`@personalakte_scd_backfill = 1`, and replay each date oldest to newest by
setting `@personalakte_scd_backfill_date` and calling
`proc_uebertrag_personalakte`. Reconcile once after replay, then clear both
session variables and truncate the staging table after reviewing the result.
The snapshot baseline coalesces identical adjacent states;
the serving table adds only boundaries where a resolved business value changes.
Neither stores one row per person per day.
