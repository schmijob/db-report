INSERT INTO `tbl_ueb_personalakte_scd_snapshot` (
    `persnr`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`,
    `taetigkeit`, `team`, `br`, `taetigkeit2`, `funktion`,
    `last_insert_update`, `filedate`, `gueltig_von`, `gueltig_bis`
) VALUES
  (999901, 'Synthetic, Retro', 'Test', 'Test OE', 'Frueh', 'DPW',
   '2020-01-01', '9999-12-31', 'Test role', 'Team A', NULL, NULL, NULL,
   '2023-01-01 00:00:00', '2023-01-01 00:00:00', '2020-01-01', '9999-12-31'),
  (999902, 'Synthetic, Conflict', 'Test', 'Test OE', 'Frueh', 'DPW',
   '2020-01-01', '9999-12-31', 'Test role', 'Team X', NULL, NULL, NULL,
   '2023-01-01 00:00:00', '2023-01-01 00:00:00', '2020-01-01', '9999-12-31');

INSERT INTO `tbl_uebertrag_aenderungen_werte` (
    `persnr`, `aenderungsdatum`, `feld`, `wert`, `gueltig_von`, `gueltig_bis`,
    `beschreibung`, `filedate`
) VALUES
  (999901, '2024-01-10 00:00:00', '13 Team', 'Team B',
   '2022-01-01', '9999-12-31', 'Synthetic retroactive change', '2024-01-10 00:00:00'),
  (999902, '2022-02-01 00:00:00', '13 Team', 'Team Y',
   '2022-01-01', '9999-12-31', 'Synthetic change known by snapshot', '2022-02-01 00:00:00');
