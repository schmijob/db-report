-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_personalakte_scd_backfill.sql
-- Rebuild normalized history from durable raw imports using the shared transfer transform.
DROP PROCEDURE IF EXISTS `proc_ueb_personalakte_scd_backfill`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_personalakte_scd_backfill`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_done TINYINT DEFAULT 0;
    DECLARE var_snapshot_date DATE;

    DECLARE snapshot_dates CURSOR FOR
        SELECT snapshot_date
          FROM tbl_import_personalakte_scd_dates
         ORDER BY snapshot_date;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_done = 1;

    IF NOT EXISTS (SELECT 1 FROM tbl_import_personalakte_scd_dates)
       OR NOT EXISTS (SELECT 1 FROM tbl_import_personalakte_scd_raw) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Build the raw Personalakte SCD before normalized history';
    END IF;

    -- This rebuild changes only the new normalized-history tables.
    TRUNCATE TABLE tbl_ueb_personalakte_scd_snapshot;
    TRUNCATE TABLE tbl_ueb_personalakte_scd;
    TRUNCATE TABLE tbl_ueb_personalakte_scd_reconciliation;

    OPEN snapshot_dates;
    snapshot_loop: LOOP
        FETCH snapshot_dates INTO var_snapshot_date;
        IF var_done = 1 THEN
            LEAVE snapshot_loop;
        END IF;

        CALL proc_uebertrag_personalakte_transform_snapshot(var_snapshot_date, 1);

        UPDATE tbl_ueb_personalakte_scd_snapshot s
        LEFT JOIN tmp_personalakte_normalized n
          ON n.persnr = s.persnr
           SET s.gueltig_bis = DATE_SUB(var_snapshot_date, INTERVAL 1 DAY)
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von < var_snapshot_date
           AND n.persnr IS NULL;

        UPDATE tbl_ueb_personalakte_scd_snapshot s
        JOIN tmp_personalakte_normalized n
          ON n.persnr = s.persnr
        JOIN tmp_personalakte_import i
          ON i.pers_nr = n.persnr
           SET s.gueltig_bis = DATE_SUB(var_snapshot_date, INTERVAL 1 DAY)
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von < var_snapshot_date
           AND NOT (
                  s.`name`        <=> n.`name`
              AND (i.gebdatum IS NULL OR i.gebdatum = '0000-00-00' OR s.gebdatum <=> i.gebdatum)
              AND s.pdl           <=> n.pdl
              AND s.oe            <=> n.oe
              AND s.schichtgruppe <=> n.schichtgruppe
              AND s.eg            <=> n.eg
              AND s.beginn        <=> n.beginn
              AND s.ende          <=> n.ende
              AND s.taetigkeit    <=> n.taetigkeit
              AND s.team          <=> n.team
              AND s.br            <=> n.br
              AND s.übernahme     <=> n.übernahme
              AND s.taetigkeit2   <=> n.taetigkeit2
              AND s.funktion      <=> n.funktion
           );

        INSERT INTO tbl_ueb_personalakte_scd_snapshot (
              persnr, gebdatum, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
            , taetigkeit, team, br, übernahme, taetigkeit2, funktion
            , last_insert_update, filedate, gueltig_von, gueltig_bis
        )
        SELECT n.persnr, NULLIF(i.gebdatum, '0000-00-00'), n.`name`, n.pdl, n.oe
             , n.schichtgruppe, n.eg, n.beginn, n.ende, n.taetigkeit, n.team, n.br
             , n.übernahme, n.taetigkeit2, n.funktion
             , n.last_insert_update, n.filedate, var_snapshot_date, '9999-12-31'
          FROM tmp_personalakte_normalized n
          JOIN tmp_personalakte_import i ON i.pers_nr = n.persnr
         WHERE NOT EXISTS (
               SELECT 1
                 FROM tbl_ueb_personalakte_scd_snapshot s
                WHERE s.persnr = n.persnr
                  AND s.gueltig_bis = '9999-12-31'
         );

        UPDATE tbl_ueb_personalakte_scd_snapshot s
        JOIN tmp_personalakte_normalized n ON n.persnr = s.persnr
        JOIN tmp_personalakte_import i ON i.pers_nr = n.persnr
           SET s.gebdatum = COALESCE(NULLIF(i.gebdatum, '0000-00-00'), s.gebdatum)
             , s.last_insert_update = n.last_insert_update
             , s.filedate = n.filedate
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von <= var_snapshot_date
           AND (i.gebdatum IS NULL OR i.gebdatum = '0000-00-00' OR s.gebdatum <=> i.gebdatum)
           AND s.`name`        <=> n.`name`
           AND s.pdl           <=> n.pdl
           AND s.oe            <=> n.oe
           AND s.schichtgruppe <=> n.schichtgruppe
           AND s.eg            <=> n.eg
           AND s.beginn        <=> n.beginn
           AND s.ende          <=> n.ende
           AND s.taetigkeit    <=> n.taetigkeit
           AND s.team          <=> n.team
           AND s.br            <=> n.br
           AND s.übernahme     <=> n.übernahme
           AND s.taetigkeit2   <=> n.taetigkeit2
           AND s.funktion      <=> n.funktion;
    END LOOP;
    CLOSE snapshot_dates;

    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_normalized;
    CALL proc_ueb_personalakte_scd_reconcile();
END//
