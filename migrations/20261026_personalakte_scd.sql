-- Keep the materialized current-state table at its existing name.
-- Date-sensitive consumers use the separate SCD table.
CREATE TABLE `tbl_ueb_personalakte_scd` LIKE `tbl_ueb_personalakte`;

CREATE TABLE `tbl_ueb_personalakte_scd_snapshot` LIKE `tbl_ueb_personalakte`;

-- Historical CSVs are loaded here so the live latest-snapshot import is not
-- overwritten during backfill.
CREATE TABLE `tbl_import_personalakte_scd_backfill` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_import_personalakte_scd_backfill`
  ADD KEY `ix_personalakte_scd_backfill_filedate` (`filedate`),
  ADD KEY `ix_personalakte_scd_backfill_person_filedate` (`pers_nr`, `filedate`);

ALTER TABLE `tbl_ueb_personalakte_scd`
  ADD COLUMN `persnr_alt` int(13) DEFAULT NULL AFTER `persnr`,
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`persnr`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_alt_date` (`persnr_alt`, `gueltig_von`, `gueltig_bis`);

ALTER TABLE `tbl_ueb_personalakte_scd_snapshot`
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`persnr`, `gueltig_von`);

CREATE TABLE IF NOT EXISTS `tbl_ueb_personalakte_scd_reconciliation` (
  `persnr` int(13) NOT NULL,
  `datum` date NOT NULL,
  `feld` varchar(50) NOT NULL,
  `snapshot_wert` text DEFAULT NULL,
  `aenderungswerte` text DEFAULT NULL,
  `grund` varchar(100) NOT NULL,
  PRIMARY KEY (`persnr`, `datum`, `feld`),
  KEY `ix_personalakte_scd_reconciliation_date` (`datum`, `feld`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed the date-sensitive table with the current snapshot. Historical CSVs can
-- later replace this current-only seed by replaying snapshots oldest to newest.
INSERT INTO `tbl_ueb_personalakte_scd_snapshot` (
      `persnr`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`
    , `taetigkeit`, `team`, `br`, `übernahme`, `taetigkeit2`, `funktion`
    , `last_insert_update`, `filedate`, `gueltig_von`, `gueltig_bis`
)
SELECT `persnr`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`
     , `taetigkeit`, `team`, `br`, `übernahme`, `taetigkeit2`, `funktion`
     , `last_insert_update`, `filedate`, COALESCE(DATE(`filedate`), CURDATE()), '9999-12-31'
  FROM `tbl_ueb_personalakte`;

INSERT INTO tbl_ueb_personalakte_scd (
      `persnr`, `persnr_alt`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`
    , `taetigkeit`, `team`, `br`, `übernahme`, `taetigkeit2`, `funktion`
    , `last_insert_update`, `filedate`, `gueltig_von`, `gueltig_bis`
)
SELECT `persnr`, `persnr`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`
     , `taetigkeit`, `team`, `br`, `übernahme`, `taetigkeit2`, `funktion`
     , `last_insert_update`, `filedate`, `gueltig_von`, `gueltig_bis`
  FROM tbl_ueb_personalakte_scd_snapshot;

CREATE OR REPLACE VIEW `vp_personal_u` AS
SELECT p.`persnr` AS `persnr`
     , p.`name` AS `name`
     , p.`pdl` AS `pdl`
     , p.`oe` AS `oe`
     , p.`schichtgruppe` AS `schichtgruppe`
     , p.`eg` AS `eg`
     , p.`beginn` AS `beginn`
     , p.`ende` AS `ende`
     , p.`taetigkeit` AS `taetigkeit`
     , p.`team` AS `team`
     , p.`br` AS `br`
     , p.`übernahme` AS `uebernahme`
     , p.`last_insert_update` AS `last_insert_update`
     , p.`filedate` AS `filedate`
  FROM `tbl_ueb_personalakte` p;
