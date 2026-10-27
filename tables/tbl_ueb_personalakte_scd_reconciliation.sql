-- Rebuilt on each reconciliation; stores only unresolved event conflicts.
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
