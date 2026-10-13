# Database migrations

Versioned database migrations belong here when a schema change needs an ordered
upgrade or rollback step. Keep deployment tooling in `db-workbench`.

The shift-reconciliation migration
[`20261013_add_fz_shift_reconciliation.sql`](20261013_add_fz_shift_reconciliation.sql)
must be applied before deploying the matching changes to
`proc_uebertrag_buchungen` and `proc_ueb_fz_join`. It adds only derived,
day-grain fields to `tbl_ueb_fz_join`; the existing final
`tbl_ueb_fz_buchungen` pipeline remains unchanged while the parallel result is
validated.
