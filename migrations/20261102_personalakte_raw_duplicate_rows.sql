-- Preserve multiple source rows with the same PersNr in one snapshot.
-- The migration is additive to the raw-history schema; no unique key is
-- retained on PersNr or the derived row identity.
ALTER TABLE `tbl_import_personalakte_scd_raw`
  ADD COLUMN `row_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER `filedate`,
  ADD COLUMN `duplicate_ordinal` int unsigned NOT NULL DEFAULT 1 AFTER `row_hash`;

UPDATE `tbl_import_personalakte_scd_raw`
   SET `row_hash` = SHA2(JSON_ARRAY(
       `pers_nr`, `name_vorname`, `zeitarbeitsfirma`, `oe_der_person`, `schicht`, `info`,
       `beginn_besch`, `ende_besch`, `eg`, `geschlecht`, `taetigkeit`, `team`,
       `betriebsrat`, `einstellungsdatum`, `taetigkeit2`, `funktion`, `gebdatum`
   ), 256);

ALTER TABLE `tbl_import_personalakte_scd_raw`
  DROP PRIMARY KEY,
  MODIFY COLUMN `row_hash` char(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  MODIFY COLUMN `duplicate_ordinal` int unsigned NOT NULL,
  ADD KEY `ix_personalakte_scd_raw_identity`
    (`pers_nr`, `row_hash`, `duplicate_ordinal`, `gueltig_von`),
  ADD CONSTRAINT `fk_personalakte_scd_raw_start_date`
    FOREIGN KEY (`gueltig_von`)
    REFERENCES `tbl_import_personalakte_scd_dates` (`snapshot_date`);
