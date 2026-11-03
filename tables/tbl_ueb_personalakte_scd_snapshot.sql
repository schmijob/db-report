-- Compact raw-number snapshots retained as fallback evidence for the SCD.
CREATE TABLE IF NOT EXISTS `tbl_ueb_personalakte_scd_snapshot` (
  `persnr` int(13) NOT NULL,
  `gebdatum` date DEFAULT NULL,
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
  KEY `ix_personalakte_scd_snapshot_valid_to` (`gueltig_bis`, `persnr`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
