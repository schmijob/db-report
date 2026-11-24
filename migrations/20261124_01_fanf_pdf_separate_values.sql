ALTER TABLE tbl_import_fanf_pdf
    ADD COLUMN IF NOT EXISTS pdf_value VARCHAR(23) NULL AFTER pdf_line,
    DROP PRIMARY KEY,
    ADD COLUMN fanf_pdf_import_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT FIRST,
    ADD PRIMARY KEY (fanf_pdf_import_id),
    ADD KEY idx_fanf_pdf_import_file (filedate, filename);

ALTER TABLE tbl_uebertrag_fanf_pdf
    ADD COLUMN IF NOT EXISTS pdf_value VARCHAR(23) NULL AFTER pdf_line,
    DROP PRIMARY KEY,
    ADD COLUMN fanf_pdf_archive_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT FIRST,
    ADD PRIMARY KEY (fanf_pdf_archive_id),
    ADD KEY idx_fanf_pdf_archive_file (filedate, filename);
