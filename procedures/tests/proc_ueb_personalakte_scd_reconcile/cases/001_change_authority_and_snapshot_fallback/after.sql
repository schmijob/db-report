-- A later-imported retroactive change wins and splits the effective interval.
INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte_scd`
 WHERE `persnr` = 999901
   AND `gueltig_von` = '2020-01-01'
   AND `gueltig_bis` = '2021-12-31'
   AND `team` = 'Team A';

INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte_scd`
 WHERE `persnr` = 999901
   AND `gueltig_von` = '2022-01-01'
   AND `gueltig_bis` = '9999-12-31'
   AND `team` = 'Team B';

-- A change already known by the snapshot date conflicts with its value, so the
-- snapshot remains authoritative for that date and the disagreement is logged.
INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte_scd`
 WHERE `persnr` = 999902
   AND `gueltig_von` = '2020-01-01'
   AND `gueltig_bis` = '9999-12-31'
   AND `team` = 'Team X';

INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte_scd_reconciliation`
 WHERE `persnr` = 999902
   AND `datum` = '2022-01-01'
   AND `feld` = '13 Team'
   AND `snapshot_wert` = 'Team X'
   AND `aenderungswerte` = 'Team Y';
