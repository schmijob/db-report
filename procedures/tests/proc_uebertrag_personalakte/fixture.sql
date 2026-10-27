-- Synthetic-only schema for testing historical replay without the live import.
CREATE TABLE `tbl_import_personalakte` (
  `pers_nr` int(13) NOT NULL,
  `name_vorname` varchar(255) DEFAULT NULL,
  `zeitarbeitsfirma` varchar(100) DEFAULT NULL,
  `oe_der_person` varchar(100) DEFAULT NULL,
  `schicht` varchar(50) DEFAULT NULL,
  `info` varchar(50) DEFAULT NULL,
  `beginn_besch` date DEFAULT NULL,
  `ende_besch` date DEFAULT NULL,
  `eg` varchar(50) DEFAULT NULL,
  `geschlecht` varchar(50) DEFAULT NULL,
  `taetigkeit` varchar(100) DEFAULT NULL,
  `team` varchar(50) DEFAULT NULL,
  `betriebsrat` varchar(50) DEFAULT NULL,
  `einstellungsdatum` date DEFAULT NULL,
  `taetigkeit2` varchar(50) DEFAULT NULL,
  `funktion` varchar(100) DEFAULT NULL,
  `gebdatum` date DEFAULT NULL,
  `lastinsertupdate` datetime DEFAULT NULL,
  `filedate` datetime DEFAULT NULL,
  PRIMARY KEY (`pers_nr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `tbl_import_personalakte_scd_backfill` AS
SELECT * FROM `tbl_import_personalakte` WHERE 1 = 0;
ALTER TABLE `tbl_import_personalakte_scd_backfill`
  ADD KEY `ix_test_backfill_filedate` (`filedate`),
  ADD KEY `ix_test_backfill_person_filedate` (`pers_nr`, `filedate`);

CREATE TABLE `tbl_ueb_personalakte` (
  `persnr` int(13) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `pdl` varchar(50) DEFAULT NULL,
  `oe` varchar(50) DEFAULT NULL,
  `schichtgruppe` varchar(50) DEFAULT NULL,
  `eg` varchar(50) DEFAULT NULL,
  `beginn` date DEFAULT NULL,
  `ende` date DEFAULT NULL,
  `taetigkeit` varchar(100) DEFAULT NULL,
  `team` varchar(50) DEFAULT NULL,
  `br` varchar(50) DEFAULT NULL,
  `übernahme` varchar(50) DEFAULT NULL,
  `taetigkeit2` varchar(50) DEFAULT NULL,
  `funktion` varchar(50) DEFAULT NULL,
  `last_insert_update` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `filedate` datetime DEFAULT NULL,
  PRIMARY KEY (`persnr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `tbl_ueb_personalakte_scd` (
  `persnr` int(13) NOT NULL,
  `persnr_alt` int(13) DEFAULT NULL,
  `name` varchar(255) DEFAULT NULL,
  `pdl` varchar(50) DEFAULT NULL,
  `oe` varchar(50) DEFAULT NULL,
  `schichtgruppe` varchar(50) DEFAULT NULL,
  `eg` varchar(50) DEFAULT NULL,
  `beginn` date DEFAULT NULL,
  `ende` date DEFAULT NULL,
  `taetigkeit` varchar(100) DEFAULT NULL,
  `team` varchar(50) DEFAULT NULL,
  `br` varchar(50) DEFAULT NULL,
  `übernahme` varchar(50) DEFAULT NULL,
  `taetigkeit2` varchar(50) DEFAULT NULL,
  `funktion` varchar(50) DEFAULT NULL,
  `last_insert_update` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `filedate` datetime DEFAULT NULL,
  `gueltig_von` date NOT NULL,
  `gueltig_bis` date NOT NULL,
  PRIMARY KEY (`persnr`, `gueltig_von`),
  KEY `ix_personalakte_scd_alt_date` (`persnr_alt`, `gueltig_von`, `gueltig_bis`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tbl_ueb_personalakte_scd_snapshot` LIKE `tbl_ueb_personalakte_scd`;
ALTER TABLE `tbl_ueb_personalakte_scd_snapshot`
  DROP KEY `ix_personalakte_scd_alt_date`,
  DROP COLUMN `persnr_alt`;

CREATE TABLE `tbl_stamm_OE_translate` (
  `OE_alt` varchar(100) NOT NULL,
  `OE_neu` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`OE_alt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tbl_stamm_taetigkeit_translate` (
  `taetigkeit_alt` varchar(100) NOT NULL,
  `taetigkeit_neu` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`taetigkeit_alt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tbl_stamm_persnr` (
  `persnr` int(13) NOT NULL,
  `ende` date DEFAULT NULL,
  `oe` varchar(100) DEFAULT NULL,
  `taetigkeit` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`persnr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
CREATE TABLE `tbl_datum` (
  `datum` date NOT NULL,
  `arbeitstag` tinyint NOT NULL DEFAULT 0,
  PRIMARY KEY (`datum`)
) ENGINE=InnoDB;
INSERT INTO `tbl_datum` (`datum`, `arbeitstag`) VALUES ('2026-10-27', 1);

CREATE TABLE `test_assertions` (
  `assertion_id` int NOT NULL AUTO_INCREMENT,
  `passed` tinyint NOT NULL,
  PRIMARY KEY (`assertion_id`),
  CONSTRAINT `chk_test_assertion_passed` CHECK (`passed` = 1)
) ENGINE=InnoDB;
