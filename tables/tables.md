# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## `tbl_ueb_personalakte_scd`

- **Grain:** one row per `persnr` for each maximal interval during which the
  normalized personalakte business attributes are unchanged.
- **Key:** `(persnr, gueltig_von)`.
- **Identity:** `persnr` is the canonical number for the person across
  recorded PersNr changes. `persnr_alt` is the source number active during
  that interval. PersNr changes create SCD boundaries; the old-to-new links
  come from `tbl_uebertrag_aenderungen_werte` (`wert` = old, `persnr` = new).
- **Validity:** `gueltig_von` and `gueltig_bis` are inclusive `DATE` bounds;
  the current version ends at `9999-12-31`. These fields describe the validity
  of the complete row and are independent of employment dates `beginn`/`ende`.
- **Join:** join facts that contain historical source numbers by `persnr_alt`
  and the fact's date between the validity bounds. Use canonical `persnr` to
  group a person across number changes. The primary key supports canonical
  access, and `(persnr_alt, gueltig_von, gueltig_bis)` supports historical
  source-number lookups.
- **Source:** rebuilt from compact normalized snapshot history in
  `tbl_ueb_personalakte_scd_snapshot` and effective-dated records in
  `tbl_uebertrag_aenderungen_werte`.
- **Reconciliation:** for each effective date and field, the latest
  `aenderungsdatum` wins. If equally recent change rows disagree, a date value
  cannot be parsed, or a change already known by the snapshot's `filedate`
  disagrees with that snapshot, the field falls back to the personalakte
  snapshot. The issue is recorded in
  `tbl_ueb_personalakte_scd_reconciliation`. A later-imported retroactive
  change remains authoritative over an older snapshot.
- **Storage:** identical consecutive normalized values, including
  `persnr_alt`, reuse one version; `filedate` and `last_insert_update` do not
  split intervals.
- **Coverage:** migration seeds the current snapshot only. Dates before the
  first loaded snapshot require historical CSV replay and must not be assumed
  to have a known state.

## `tbl_ueb_personalakte_scd_snapshot`

- **Grain:** one row per person per maximal interval of unchanged normalized
  snapshot values. It retains fallback evidence for retroactive or conflicting
  changes without keeping every daily export.
- **Key:** `(persnr, gueltig_von)` with inclusive validity bounds.
- **Identity:** `persnr` is the raw number in that snapshot; reconciliation
  copies it to the serving SCD's `persnr_alt` before resolving canonical IDs.
- **Use:** internal reconciliation input; reporting joins should use
  `tbl_ueb_personalakte_scd`.

## `tbl_ueb_personalakte_scd_reconciliation`

- **Grain:** one snapshot fallback decision or PersNr snapshot handoff per
  person, effective boundary, and field. `persnr_alias_handoff` records when
  a linked new-number snapshot supersedes a still-present old-number row.
- **Use:** inspect fields where equally recent change rows disagree, a change
  date is invalid, or a change known at snapshot time disagrees with the
  snapshot. Reconciliation refreshes this table whenever it rebuilds the
  serving SCD.

## `tbl_import_personalakte_scd_backfill`

- **Grain:** source personalakte rows from historical CSV snapshots; the schema
  matches `tbl_import_personalakte` and rows are distinguished by `filedate`.
- **Keys:** non-unique indexes on `filedate` and `(pers_nr, filedate)` allow the
  same person to appear in many snapshots.
- **Use:** isolated staging input for the historical replay. Never load historic
  rows into `tbl_import_personalakte`, which remains the latest import used by
  other procedures. Truncate this staging table after reviewing a successful
  backfill.
