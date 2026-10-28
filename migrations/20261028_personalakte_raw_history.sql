-- Isolated staging and compact, untransformed import history.
-- Existing import, transfer, and consumer objects are not changed.
CREATE TABLE `tbl_import_personalakte_scd_backfill` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_import_personalakte_scd_backfill`
  ADD KEY `ix_personalakte_scd_backfill_filedate` (`filedate`),
  ADD KEY `ix_personalakte_scd_backfill_person_filedate` (`pers_nr`, `filedate`);

-- CTAS copies the import columns without inheriting an import-table key that
-- could restrict a person to one raw history interval.
CREATE TABLE `tbl_import_personalakte_scd_raw` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_import_personalakte_scd_raw`
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  ADD PRIMARY KEY (`pers_nr`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_raw_validity` (`gueltig_von`, `gueltig_bis`, `pers_nr`);

CREATE TABLE `tbl_import_personalakte_scd_dates` (
  `snapshot_date` date NOT NULL,
  `filedate` datetime NOT NULL,
  PRIMARY KEY (`snapshot_date`),
  UNIQUE KEY `uq_personalakte_scd_dates_filedate` (`filedate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
