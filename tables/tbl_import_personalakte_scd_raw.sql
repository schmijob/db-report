-- Raw source values retained by state interval, before Personalakte business
-- normalization. The date table preserves export dates with no row changes.
CREATE TABLE IF NOT EXISTS `tbl_import_personalakte_scd_raw` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_import_personalakte_scd_raw`
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  ADD PRIMARY KEY (`pers_nr`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_raw_validity` (`gueltig_von`, `gueltig_bis`, `pers_nr`);
