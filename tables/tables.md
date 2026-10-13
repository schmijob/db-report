# Table definitions

Table definitions and table-specific documentation belong here. Keep business
meaning and approved usage in `docs/architecture/`.

## `tbl_ueb_fz_join`

This table has one row per person and day. Source-specific calendar facts stay
in their own `pk_*`, `aend_*`, `bu_*`, and `pa_*` columns. The shift
reconciliation migration adds derived day-level fields:

- `expected_mask` uses the explicit bit mapping Nacht `4`, Früh `2`, Spät `1`;
- `actual_shift_1` and `actual_shift_2` are actual booking shifts ordered by
  clock-in, not expected-shift slots;
- `matched_expected_1` and `matched_expected_2` preserve the expected shift
  consumed by each actual shift;
- `remaining_expected_mask` represents expected shifts without a booking; and
- `shift_mismatch_1` and `shift_mismatch_2` identify actual/expected
  assignments that differ.

Booking details remain in `tbl_ueb_buchungen_2` and are joined after expansion.
