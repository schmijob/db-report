-- The selected backfill row becomes the current materialized state and a
-- snapshot at DATE(filedate); reconciliation remains deferred during replay.
INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte`
 WHERE `persnr` = 999903
   AND `name` = 'Synthetic, Backfill'
   AND `oe` = 'Test OE'
   AND `team` = 'Test team'
   AND `filedate` = '2021-01-02 05:00:00';

INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 1
  FROM `tbl_ueb_personalakte_scd_snapshot`
 WHERE `persnr` = 999903
   AND `gueltig_von` = '2021-01-02'
   AND `gueltig_bis` = '9999-12-31'
   AND `filedate` = '2021-01-02 05:00:00';

INSERT INTO `test_assertions` (`passed`)
SELECT COUNT(*) = 0 FROM `tbl_ueb_personalakte_scd`;
