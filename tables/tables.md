# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## `tbl_ueb_personalakte_scd`

- **Grain:** one row per `persnr` for each maximal interval during which the
  normalized personalakte business attributes are unchanged.
- **Key:** `(persnr, gueltig_von)`.
- **Identity:** `persnr` is the canonical number for the person across
  recorded PersNr changes. `persnr_alt` is the source number active during
  that interval. Reconciliation uses explicit old-to-new change-log links when
  present and applies a unique adjacent-snapshot handoff with matching names
  when the old number has left current personalakte and birthdays do not
  conflict. It records the evidence for HR review.
- **Validity:** `gueltig_von` and `gueltig_bis` are inclusive `DATE` bounds;
  the current version ends at `9999-12-31`. These fields describe the validity
  of the complete row and are independent of employment dates `beginn`/`ende`.
- **Join:** join facts that contain historical source numbers by `persnr_alt`
  and the fact's date between the validity bounds. Use canonical `persnr` to
  group a person across number changes. The primary key supports canonical
  access, and `(persnr_alt, gueltig_von, gueltig_bis)` supports historical
  source-number lookups.
- **Source:** rebuilt from compact normalized snapshot history in
  `tbl_ueb_personalakte_scd_snapshot`, effective-dated records in
  `tbl_uebertrag_aenderungen_werte`, and name evidence in
  `tbl_uebertrag_aenderungen`.
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
- **Coverage:** the additive migration creates empty SCD tables. Historical
  coverage comes from staged CSV exports; dates before the earliest staged
  export must not be assumed to have a known state. After cutover, the normal
  Personalakte transfer keeps the latest interval current.
- **Repeated PersNr in one export:** raw history retains every tenure row. The
  normalized transform chooses the latest employment start at or before the
  snapshot date; before that start, the previous tenure remains selected. If
  distinct rows for one PersNr share the same employment start, the transform
  stops for review instead of choosing arbitrarily.

## `tbl_ueb_personalakte_scd_snapshot`

- **Grain:** one row per person per maximal interval of unchanged normalized
  snapshot values. It retains fallback evidence for retroactive or conflicting
  changes without keeping every daily export.
- **Key:** `(persnr, gueltig_von)` with inclusive validity bounds.
- **Index:** `(gueltig_bis, persnr)` supports matching adjacent snapshot
  intervals during identity reconciliation.
- **Identity:** `persnr` is the raw number in that snapshot; reconciliation
  copies it to the serving SCD's `persnr_alt` before resolving canonical IDs.
  Optional `gebdatum` is retained here as identity-candidate evidence and is
  not exposed by the serving SCD.
- **Use:** internal reconciliation input; reporting joins should use
  `tbl_ueb_personalakte_scd`.

## `tbl_ueb_personalakte_scd_reconciliation`

- **Grain:** one snapshot fallback decision, identity candidate, or PersNr
  snapshot handoff per person, effective boundary, and field.
  `persnr_alias_handoff` records when a linked new-number snapshot supersedes
  a still-present old-number row.
- **Use:** inspect fields where equally recent change rows disagree, a change
  date is invalid, or a change known at snapshot time disagrees with the
  snapshot. It also records applied PersNr identity candidates with snapshot
  and change-log evidence, plus ambiguous or birthday-conflicting candidates.
  Reconciliation refreshes this table whenever it rebuilds the serving SCD.

## Raw Personalakte import history

- `tbl_import_personalakte_scd_backfill` is the isolated bulk-upload target for
  dated source exports. Its columns mirror `tbl_import_personalakte`; its
  indexes are non-unique so the same PersNr can occur multiple times in one
  export and in many exports.
- `tbl_import_personalakte_scd_raw` stores every raw source field and one row
  per source-row occurrence per maximal unchanged interval. Multiple rows may
  share a PersNr and validity start. `row_hash` and `duplicate_ordinal`
  identify equal row occurrences for interval comparison; neither is unique.
  No normalization rules are applied here.
- `tbl_import_personalakte_scd_dates` stores each export's Druckdatum date and
  timestamp, including dates where no person's raw fields changed. It allows
  downstream transformations to reconstruct a complete source snapshot for
  any export date without storing a row per person per day.

`proc_uebertrag_personalakte_raw_scd(1)` rebuilds raw history from the staging
table; `(0)` appends one current import snapshot. Both paths write only to the
raw-history tables. Keep the staging rows until the raw history has been
reviewed and copied to sanitized LOCAL.

The preparation migration adds only these raw-history objects. The later
cutover migration and procedures build normalized history from this raw layer.
