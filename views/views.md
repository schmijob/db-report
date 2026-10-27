# Database views

Versioned view definitions belong here. The current db-workbench deployment
workflow covers stored procedures; the local view cutover is represented by
these SQL files and the personalakte migration.

## Personalakte view

- `tbl_ueb_personalakte` remains the materialized current one-row-per-person
  table.
- `vp_personal_u` exposes its normalized current-personnel column projection.
- Internal consumers that evaluate historical dates use
  `tbl_ueb_personalakte_scd` directly, with a validity-range join.

The date-sensitive reporting views are `view_clusterung_anwesenheit`,
`view_decay_fz`, `view_letzte_schicht`, `view_nettoanwesenheit`,
`view_onboarder`, `view_schichtleiter_anwesenheit`,
`view_urlaubsvorschau_komplett`, and `view_urlaubsvorschau_komplett_2`.
`view_last_insert_update` reads its personalakte watermark from the SCD table.
