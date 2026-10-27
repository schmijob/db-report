SET @personalakte_scd_backfill = 1;
SET @personalakte_scd_backfill_date = '2021-01-02';
CALL `proc_uebertrag_personalakte`();
SET @personalakte_scd_backfill = NULL;
SET @personalakte_scd_backfill_date = NULL;
