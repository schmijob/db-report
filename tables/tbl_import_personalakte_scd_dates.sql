-- One row per Druckdatum export, including exports where no raw field changed.
CREATE TABLE IF NOT EXISTS `tbl_import_personalakte_scd_dates` (
  `snapshot_date` date NOT NULL,
  `filedate` datetime NOT NULL,
  PRIMARY KEY (`snapshot_date`),
  UNIQUE KEY `uq_personalakte_scd_dates_filedate` (`filedate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
