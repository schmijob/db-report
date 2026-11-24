# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## FANF PDF

`tbl_import_fanf_pdf` stores rows extracted with the `FANF PDF` db-workbench
profile. `filename` and `filedate` identify the source PDF; `pdf_line` is the
left text label and `pdf_value` is the separately extracted right-hand value.
Repeated labels are valid, so both staging and raw archive tables use generated
row IDs instead of unique keys on the text.

`tbl_uebertrag_fanf_pdf` archives every extracted row for each imported file,
including repeated labels. `tbl_uebertrag_fanf_pdf_parsed` stores one row per
file and function. The procedure takes numeric assignments from `pdf_value`
and matches `pdf_line` directly to `tbl_stamm_funktionen.funktion`. It
deduplicates identical rows for parsing and rejects unknown numeric labels,
conflicting values, and missing forecast metadata.

One known PDF error is handled narrowly during normalization: the first
`Staplerfahrer` row after the `Warenausgang:` section marker becomes the
existing `LBH Teamleiter / Koordinator` function with value `0`. Other
`Staplerfahrer` rows remain unchanged. `tbl_stamm_fanf_pdf_translate` is no
longer part of this pipeline.
