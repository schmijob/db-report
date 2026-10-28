# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## Personalakte history preparation

- `tbl_import_personalakte_scd_backfill` is a separate upload target for dated
  historical exports. It must not replace the current-only
  `tbl_import_personalakte` input.
- `tbl_ueb_personalakte_scd_snapshot` stores only source-number state changes
  and their inclusive validity ranges. It also retains optional birthday
  evidence for identity review.
- `tbl_ueb_personalakte_scd` stores the reconciled date-sensitive history with
  canonical `persnr` and the source number in effect as `persnr_alt`.
- `tbl_ueb_personalakte_scd_reconciliation` stores field conflicts and
  candidate PersNr handoff evidence from the rebuild.

The backfill procedure rebuilds the three interval/evidence tables from the
isolated upload table. Existing current-state tables and procedures remain
unchanged by this preparation step.
