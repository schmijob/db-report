-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte_raw_scd.sql
-- Rebuild raw import history from staged exports, or append the current import.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte_raw_scd`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte_raw_scd`(
    IN p_rebuild_from_backfill TINYINT
)
SQL SECURITY DEFINER BEGIN
    DECLARE var_done TINYINT DEFAULT 0;
    DECLARE var_snapshot_date DATE;
    DECLARE var_bad_rows BIGINT DEFAULT 0;

    DECLARE snapshot_dates CURSOR FOR
        SELECT DISTINCT DATE(filedate)
          FROM tbl_import_personalakte_scd_backfill
         ORDER BY DATE(filedate);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_done = 1;

    IF p_rebuild_from_backfill IS NULL OR p_rebuild_from_backfill NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Choose raw SCD rebuild (1) or current import append (0)';
    END IF;

    IF p_rebuild_from_backfill = 1 THEN
        IF NOT EXISTS (SELECT 1 FROM tbl_import_personalakte_scd_backfill) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No staged Personalakte snapshots are available';
        END IF;

        IF EXISTS (
            SELECT 1
              FROM tbl_import_personalakte_scd_backfill
             WHERE pers_nr IS NULL OR filedate IS NULL
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Staged raw rows require PersNr and Druckdatum';
        END IF;

        SELECT COUNT(*) INTO var_bad_rows
          FROM (
                SELECT DATE(filedate), pers_nr
                  FROM tbl_import_personalakte_scd_backfill
                 GROUP BY DATE(filedate), pers_nr
                HAVING COUNT(*) > 1
          ) duplicate_people;
        IF var_bad_rows > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A staged raw snapshot has duplicate personnel numbers';
        END IF;

        SELECT COUNT(*) INTO var_bad_rows
          FROM (
                SELECT DATE(filedate)
                  FROM tbl_import_personalakte_scd_backfill
                 GROUP BY DATE(filedate)
                HAVING COUNT(DISTINCT filedate) > 1
          ) multiple_exports_per_day;
        IF var_bad_rows > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Choose one Druckdatum export per calendar date before loading';
        END IF;

        TRUNCATE TABLE tbl_import_personalakte_scd_raw;
        TRUNCATE TABLE tbl_import_personalakte_scd_dates;

        OPEN snapshot_dates;
        snapshot_loop: LOOP
            FETCH snapshot_dates INTO var_snapshot_date;
            IF var_done = 1 THEN
                LEAVE snapshot_loop;
            END IF;
            CALL proc_uebertrag_personalakte_raw_snapshot(var_snapshot_date, 1);
        END LOOP;
        CLOSE snapshot_dates;
    ELSE
        IF NOT EXISTS (SELECT 1 FROM tbl_import_personalakte) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The current Personalakte import is empty';
        END IF;

        SELECT COUNT(DISTINCT DATE(filedate)) INTO var_bad_rows
          FROM tbl_import_personalakte;
        IF var_bad_rows <> 1 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'The current Personalakte import must contain one Druckdatum';
        END IF;

        SELECT MAX(DATE(filedate)) INTO var_snapshot_date
          FROM tbl_import_personalakte;
        CALL proc_uebertrag_personalakte_raw_snapshot(var_snapshot_date, 0);
    END IF;
END//
