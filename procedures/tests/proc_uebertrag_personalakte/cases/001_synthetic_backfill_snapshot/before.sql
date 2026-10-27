INSERT INTO `tbl_import_personalakte_scd_backfill` (
    `pers_nr`, `name_vorname`, `zeitarbeitsfirma`, `oe_der_person`, `schicht`,
    `info`, `beginn_besch`, `ende_besch`, `eg`, `geschlecht`, `taetigkeit`,
    `team`, `betriebsrat`, `einstellungsdatum`, `taetigkeit2`, `funktion`,
    `gebdatum`, `lastinsertupdate`, `filedate`
) VALUES (
    999903, 'Synthetic, Backfill', 'Test company', 'Test OE', 'Frueh', 'DPW',
    '2020-01-01', '9999-12-31', NULL, 'X', 'Test role', 'Test team', NULL,
    '2020-01-01', NULL, 'Test function', '1990-01-01',
    '2021-01-02 05:00:00', '2021-01-02 05:00:00'
);
