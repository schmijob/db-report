-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte_raw_snapshot.sql
-- Store one dated raw import as compact, untransformed source-state intervals.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte_raw_snapshot`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte_raw_snapshot`(
    IN p_snapshot_date DATE,
    IN p_from_backfill TINYINT
)
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    DECLARE var_bad_rows BIGINT DEFAULT 0;
    DECLARE var_latest_date DATE;

    IF p_snapshot_date IS NULL OR p_from_backfill NOT IN (0, 1) OR p_from_backfill IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A snapshot date and a valid source flag are required';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_import;
    CREATE TEMPORARY TABLE tmp_pa_raw_import LIKE tbl_import_personalakte;

    IF p_from_backfill = 1 THEN
        INSERT INTO tmp_pa_raw_import
        SELECT *
          FROM tbl_import_personalakte_scd_backfill
         WHERE filedate >= p_snapshot_date
           AND filedate < DATE_ADD(p_snapshot_date, INTERVAL 1 DAY);
    ELSE
        INSERT INTO tmp_pa_raw_import
        SELECT *
          FROM tbl_import_personalakte
         WHERE filedate >= p_snapshot_date
           AND filedate < DATE_ADD(p_snapshot_date, INTERVAL 1 DAY);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tmp_pa_raw_import) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No raw Personalakte rows exist for this snapshot date';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_pa_raw_import
         WHERE pers_nr IS NULL OR filedate IS NULL
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Raw Personalakte rows require PersNr and Druckdatum';
    END IF;

    SELECT COUNT(*) INTO var_bad_rows
      FROM (
            SELECT pers_nr
              FROM tmp_pa_raw_import
             GROUP BY pers_nr
            HAVING COUNT(*) > 1
      ) duplicate_people;
    IF var_bad_rows > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A raw Personalakte snapshot has duplicate personnel numbers';
    END IF;

    SELECT MAX(filedate) INTO var_filedate FROM tmp_pa_raw_import;
    SELECT MAX(snapshot_date) INTO var_latest_date
      FROM tbl_import_personalakte_scd_dates;

    IF var_latest_date > p_snapshot_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Raw Personalakte snapshots must be replayed oldest to newest';
    END IF;

    -- A corrected export for the latest date replaces that date. Reopening
    -- the prior intervals lets the ordinary comparison below apply the new
    -- raw values without leaving duplicate or orphaned states.
    IF EXISTS (
        SELECT 1
          FROM tbl_import_personalakte_scd_dates
         WHERE snapshot_date = p_snapshot_date
    ) THEN
        DELETE FROM tbl_import_personalakte_scd_raw
         WHERE gueltig_von = p_snapshot_date;

        UPDATE tbl_import_personalakte_scd_raw r
        LEFT JOIN tbl_import_personalakte_scd_raw later_state
          ON later_state.pers_nr = r.pers_nr
         AND later_state.gueltig_von > p_snapshot_date
           SET r.gueltig_bis = '9999-12-31'
         WHERE r.gueltig_bis = DATE_SUB(p_snapshot_date, INTERVAL 1 DAY)
           AND r.gueltig_von < p_snapshot_date
           AND later_state.pers_nr IS NULL;

        DELETE FROM tbl_import_personalakte_scd_dates
         WHERE snapshot_date = p_snapshot_date;
    END IF;

    INSERT INTO tbl_import_personalakte_scd_dates (snapshot_date, filedate)
    VALUES (p_snapshot_date, var_filedate);

    UPDATE tbl_import_personalakte_scd_raw r
    LEFT JOIN tmp_pa_raw_import i
      ON i.pers_nr = r.pers_nr
       SET r.gueltig_bis = DATE_SUB(p_snapshot_date, INTERVAL 1 DAY)
     WHERE r.gueltig_bis = '9999-12-31'
       AND r.gueltig_von < p_snapshot_date
       AND i.pers_nr IS NULL;

    UPDATE tbl_import_personalakte_scd_raw r
    JOIN tmp_pa_raw_import i
      ON i.pers_nr = r.pers_nr
       SET r.gueltig_bis = DATE_SUB(p_snapshot_date, INTERVAL 1 DAY)
     WHERE r.gueltig_bis = '9999-12-31'
       AND r.gueltig_von < p_snapshot_date
       AND NOT (
              r.name_vorname       <=> i.name_vorname
          AND r.zeitarbeitsfirma   <=> i.zeitarbeitsfirma
          AND r.oe_der_person      <=> i.oe_der_person
          AND r.schicht            <=> i.schicht
          AND r.info               <=> i.info
          AND r.beginn_besch       <=> i.beginn_besch
          AND r.ende_besch         <=> i.ende_besch
          AND r.eg                 <=> i.eg
          AND r.geschlecht         <=> i.geschlecht
          AND r.taetigkeit         <=> i.taetigkeit
          AND r.team               <=> i.team
          AND r.betriebsrat        <=> i.betriebsrat
          AND r.einstellungsdatum  <=> i.einstellungsdatum
          AND r.taetigkeit2        <=> i.taetigkeit2
          AND r.funktion           <=> i.funktion
          AND r.gebdatum           <=> i.gebdatum
       );

    INSERT INTO tbl_import_personalakte_scd_raw (
          pers_nr, name_vorname, zeitarbeitsfirma, oe_der_person, schicht, info
        , beginn_besch, ende_besch, eg, geschlecht, taetigkeit, team, betriebsrat
        , einstellungsdatum, taetigkeit2, funktion, gebdatum, lastinsertupdate
        , filedate, gueltig_von, gueltig_bis
    )
    SELECT i.pers_nr, i.name_vorname, i.zeitarbeitsfirma, i.oe_der_person
         , i.schicht, i.info, i.beginn_besch, i.ende_besch, i.eg, i.geschlecht
         , i.taetigkeit, i.team, i.betriebsrat, i.einstellungsdatum, i.taetigkeit2
         , i.funktion, i.gebdatum, i.lastinsertupdate, i.filedate
         , p_snapshot_date, '9999-12-31'
      FROM tmp_pa_raw_import i
     WHERE NOT EXISTS (
           SELECT 1
             FROM tbl_import_personalakte_scd_raw r
            WHERE r.pers_nr = i.pers_nr
              AND r.gueltig_bis = '9999-12-31'
     );

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_import;
END//
