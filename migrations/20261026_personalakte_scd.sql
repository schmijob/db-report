-- Additive objects for loading and preparing the Personalakte SCD.
-- Existing source, transfer, and consumer objects are intentionally untouched.
CREATE TABLE `tbl_import_personalakte_scd_backfill` LIKE `tbl_import_personalakte`;

ALTER TABLE `tbl_import_personalakte_scd_backfill`
  ADD KEY `ix_personalakte_scd_backfill_filedate` (`filedate`),
  ADD KEY `ix_personalakte_scd_backfill_person_filedate` (`pers_nr`, `filedate`);

CREATE TABLE `tbl_ueb_personalakte_scd` LIKE `tbl_ueb_personalakte`;

ALTER TABLE `tbl_ueb_personalakte_scd`
  ADD COLUMN `persnr_alt` int(13) DEFAULT NULL AFTER `persnr`,
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`persnr`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_alt_date` (`persnr_alt`, `gueltig_von`, `gueltig_bis`);

CREATE TABLE `tbl_ueb_personalakte_scd_snapshot` LIKE `tbl_ueb_personalakte`;

ALTER TABLE `tbl_ueb_personalakte_scd_snapshot`
  ADD COLUMN `gebdatum` date DEFAULT NULL AFTER `persnr`,
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  DROP PRIMARY KEY,
  ADD PRIMARY KEY (`persnr`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_snapshot_valid_to` (`gueltig_bis`, `persnr`);

CREATE TABLE `tbl_ueb_personalakte_scd_reconciliation` (
  `persnr` int(13) NOT NULL,
  `datum` date NOT NULL,
  `feld` varchar(50) NOT NULL,
  `snapshot_wert` text DEFAULT NULL,
  `aenderungswerte` text DEFAULT NULL,
  `grund` varchar(100) NOT NULL,
  PRIMARY KEY (`persnr`, `datum`, `feld`),
  KEY `ix_personalakte_scd_reconciliation_date` (`datum`, `feld`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
