-- Synthetic-only schema for the SCD reconciliation procedure suite.
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

CREATE TABLE `tbl_uebertrag_aenderungen_werte` (
  `persnr` int(13) NOT NULL,
  `aenderungsdatum` datetime DEFAULT NULL,
  `feld` varchar(100) DEFAULT NULL,
  `wert` text DEFAULT NULL,
  `gueltig_von` date DEFAULT NULL,
  `gueltig_bis` date DEFAULT NULL,
  `beschreibung` text DEFAULT NULL,
  `filedate` datetime DEFAULT NULL,
  KEY `ix_test_aenderungen_person_date` (`persnr`, `gueltig_von`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `test_assertions` (
  `assertion_id` int NOT NULL AUTO_INCREMENT,
  `passed` tinyint NOT NULL,
  PRIMARY KEY (`assertion_id`),
  CONSTRAINT `chk_test_assertion_passed` CHECK (`passed` = 1)
) ENGINE=InnoDB;
