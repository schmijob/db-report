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
prepared TSV, then call `proc_ueb_personalakte_scd_backfill()` once. The call
replays all available Druckdatum dates oldest to newest and rebuilds the
snapshot and serving intervals. Keep the upload table until the result has
been reviewed and copied to the sanitized LOCAL database. Birthday values are
optional evidence in the raw snapshot table and are not exposed by the serving
SCD.
