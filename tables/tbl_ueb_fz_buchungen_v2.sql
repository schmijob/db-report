CREATE TABLE IF NOT EXISTS tbl_ueb_fz_buchungen_v2 (
    persnr INT NOT NULL
  , datum DATE NOT NULL
  , status VARCHAR(50) NULL
  , schichtgruppe VARCHAR(50) NULL
  , kommen DATETIME NULL
  , schicht TINYINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'tbl_schichten.schicht_int; 0 means no resolved shift'
  , minuten INT NULL
  , anwesenheit VARCHAR(50) NULL
  , tp VARCHAR(5) NULL
  , last_insert_update TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
  , filedate DATETIME NULL
  , PRIMARY KEY (persnr, datum, schicht)
  , KEY ix_tbl_ueb_fz_buchungen_v2_datum_status (datum, status)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;
