# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## Raw Personalakte import history

- `tbl_import_personalakte_scd_backfill` is the isolated bulk-upload target for
  dated source exports. Its columns mirror `tbl_import_personalakte`; its
  indexes are non-unique so the same PersNr can occur in many exports.
- `tbl_import_personalakte_scd_raw` stores every raw source field and one row
  per person per maximal unchanged source-state interval. `pers_nr` is the
  source identifier, and inclusive `gueltig_von` / `gueltig_bis` bounds record
  when that raw state appeared in the exports. No normalization rules are
  applied here.
- `tbl_import_personalakte_scd_dates` stores each export's Druckdatum date and
  timestamp, including dates where no person's raw fields changed. It allows
  downstream transformations to reconstruct a complete source snapshot for
  any export date without storing a row per person per day.

`proc_uebertrag_personalakte_raw_scd(1)` rebuilds the raw history from the
staging table. `proc_uebertrag_personalakte_raw_scd(0)` appends one current
import snapshot. Both paths write only to the new raw-history tables. The
staging table can be truncated after the raw SCD has been reviewed and copied
to sanitized LOCAL.
