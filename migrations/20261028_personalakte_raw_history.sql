-- Isolated staging and compact, untransformed import history.
-- Existing import, transfer, and consumer objects are not changed.
-- Source-row identity is non-unique so one PersNr may have multiple rows in
-- the same export, including identical repeated rows.
CREATE TABLE `tbl_import_personalakte_scd_backfill` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_import_personalakte_scd_backfill`
  ADD KEY `ix_personalakte_scd_backfill_filedate` (`filedate`),
  ADD KEY `ix_personalakte_scd_backfill_person_filedate` (`pers_nr`, `filedate`);

CREATE TABLE `tbl_uebertrag_personalakte_scd_dates` (
  `snapshot_date` date NOT NULL,
  `filedate` datetime NOT NULL,
  PRIMARY KEY (`snapshot_date`),
  UNIQUE KEY `uq_personalakte_scd_dates_filedate` (`filedate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- CTAS copies source columns without inheriting the current import's PersNr
-- primary key. Hash plus ordinal preserves repeated source-row occurrences.
CREATE TABLE `tbl_uebertrag_personalakte_scd_raw` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;

ALTER TABLE `tbl_uebertrag_personalakte_scd_raw`
  ADD COLUMN `row_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL AFTER `filedate`,
  ADD COLUMN `duplicate_ordinal` int unsigned NOT NULL AFTER `row_hash`,
  ADD COLUMN `gueltig_von` date NOT NULL,
  ADD COLUMN `gueltig_bis` date NOT NULL,
  ADD KEY `ix_personalakte_scd_raw_identity`
    (`pers_nr`, `row_hash`, `duplicate_ordinal`, `gueltig_von`),
  ADD KEY `ix_personalakte_scd_raw_validity` (`gueltig_von`, `gueltig_bis`, `pers_nr`),
  ADD CONSTRAINT `fk_personalakte_scd_raw_start_date`
    FOREIGN KEY (`gueltig_von`)
    REFERENCES `tbl_uebertrag_personalakte_scd_dates` (`snapshot_date`);
