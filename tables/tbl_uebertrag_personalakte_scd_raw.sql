-- Raw source values retained by state interval, before Personalakte business
-- normalization. The date table preserves export dates with no row changes.
CREATE TABLE IF NOT EXISTS `tbl_uebertrag_personalakte_scd_raw` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_uebertrag_personalakte_scd_raw`
  ADD COLUMN `row_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  ADD COLUMN `duplicate_ordinal` int unsigned NOT NULL,
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  ADD KEY `ix_personalakte_scd_raw_identity`
    (`pers_nr`, `row_hash`, `duplicate_ordinal`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_raw_validity` (`gueltig_von`, `gueltig_bis`, `pers_nr`),
  ADD CONSTRAINT `fk_personalakte_scd_raw_start_date`
    FOREIGN KEY (`gueltig_von`)
    REFERENCES `tbl_uebertrag_personalakte_scd_dates` (`snapshot_date`);
