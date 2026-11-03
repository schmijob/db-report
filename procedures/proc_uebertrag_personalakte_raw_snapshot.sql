-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte_raw_snapshot.sql
-- Store one dated raw import as compact, untransformed source-row intervals.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte_raw_snapshot`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte_raw_snapshot`(
    IN p_snapshot_date DATE,
    IN p_from_backfill TINYINT
)
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    DECLARE var_latest_date DATE;

    IF p_snapshot_date IS NULL OR p_from_backfill NOT IN (0, 1) OR p_from_backfill IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A snapshot date and a valid source flag are required';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_source;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_import;
    -- CTAS intentionally avoids the current import's PersNr primary key.
    CREATE TEMPORARY TABLE tmp_pa_raw_source AS
    SELECT * FROM tbl_import_personalakte WHERE 1 = 0;

    IF p_from_backfill = 1 THEN
        INSERT INTO tmp_pa_raw_source
        SELECT *
          FROM tbl_import_personalakte_scd_backfill
         WHERE filedate >= p_snapshot_date
           AND filedate < DATE_ADD(p_snapshot_date, INTERVAL 1 DAY);
    ELSE
        INSERT INTO tmp_pa_raw_source
        SELECT *
          FROM tbl_import_personalakte
         WHERE filedate >= p_snapshot_date
           AND filedate < DATE_ADD(p_snapshot_date, INTERVAL 1 DAY);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM tmp_pa_raw_source) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No raw Personalakte rows exist for this snapshot date';
    END IF;

    IF EXISTS (
        SELECT 1 FROM tmp_pa_raw_source
         WHERE pers_nr IS NULL OR filedate IS NULL
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Raw Personalakte rows require PersNr and Druckdatum';
    END IF;

    -- Hash only source attributes, excluding import timestamps and filedate.
    -- The ordinal preserves multiplicity when identical source rows repeat.
    CREATE TEMPORARY TABLE tmp_pa_raw_import AS
    SELECT hashed_rows.*
         , ROW_NUMBER() OVER (
               PARTITION BY hashed_rows.pers_nr, hashed_rows.row_hash
               ORDER BY hashed_rows.pers_nr, hashed_rows.row_hash
           ) AS duplicate_ordinal
      FROM (
            SELECT src.*
                 , SHA2(JSON_ARRAY(
                       src.pers_nr, src.name_vorname, src.zeitarbeitsfirma
                     , src.oe_der_person, src.schicht, src.info, src.beginn_besch
                     , src.ende_besch, src.eg, src.geschlecht, src.taetigkeit
                     , src.team, src.betriebsrat, src.einstellungsdatum
                     , src.taetigkeit2, src.funktion, src.gebdatum
                   ), 256) AS row_hash
              FROM tmp_pa_raw_source src
           ) hashed_rows;

    SELECT MAX(filedate) INTO var_filedate FROM tmp_pa_raw_import;
    SELECT MAX(snapshot_date) INTO var_latest_date
      FROM tbl_uebertrag_personalakte_scd_dates;

    IF var_latest_date > p_snapshot_date THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Raw Personalakte snapshots must be replayed oldest to newest';
    END IF;

    -- A corrected export for the latest date replaces that date. Reopen prior
    -- intervals by source-row identity, including the duplicate occurrence.
    IF EXISTS (
        SELECT 1
          FROM tbl_uebertrag_personalakte_scd_dates
         WHERE snapshot_date = p_snapshot_date
    ) THEN
        DELETE FROM tbl_uebertrag_personalakte_scd_raw
         WHERE gueltig_von = p_snapshot_date;

        UPDATE tbl_uebertrag_personalakte_scd_raw r
        LEFT JOIN tbl_uebertrag_personalakte_scd_raw later_state
          ON later_state.pers_nr = r.pers_nr
         AND later_state.row_hash = r.row_hash
         AND later_state.duplicate_ordinal = r.duplicate_ordinal
         AND later_state.gueltig_von > p_snapshot_date
           SET r.gueltig_bis = '9999-12-31'
         WHERE r.gueltig_bis = DATE_SUB(p_snapshot_date, INTERVAL 1 DAY)
           AND r.gueltig_von < p_snapshot_date
           AND later_state.pers_nr IS NULL;

        DELETE FROM tbl_uebertrag_personalakte_scd_dates
         WHERE snapshot_date = p_snapshot_date;
    END IF;

    INSERT INTO tbl_uebertrag_personalakte_scd_dates (snapshot_date, filedate)
    VALUES (p_snapshot_date, var_filedate);

    -- Close each previous source-row occurrence that is absent from this file.
    UPDATE tbl_uebertrag_personalakte_scd_raw r
    LEFT JOIN tmp_pa_raw_import i
      ON i.pers_nr = r.pers_nr
     AND i.row_hash = r.row_hash
     AND i.duplicate_ordinal = r.duplicate_ordinal
       SET r.gueltig_bis = DATE_SUB(p_snapshot_date, INTERVAL 1 DAY)
     WHERE r.gueltig_bis = '9999-12-31'
       AND r.gueltig_von < p_snapshot_date
       AND i.pers_nr IS NULL;

    -- Start an interval only when that exact row occurrence is not already active.
    INSERT INTO tbl_uebertrag_personalakte_scd_raw (
          pers_nr, name_vorname, zeitarbeitsfirma, oe_der_person, schicht, info
        , beginn_besch, ende_besch, eg, geschlecht, taetigkeit, team, betriebsrat
        , einstellungsdatum, taetigkeit2, funktion, gebdatum, lastinsertupdate
        , filedate, row_hash, duplicate_ordinal, gueltig_von, gueltig_bis
    )
    SELECT i.pers_nr, i.name_vorname, i.zeitarbeitsfirma, i.oe_der_person
         , i.schicht, i.info, i.beginn_besch, i.ende_besch, i.eg, i.geschlecht
         , i.taetigkeit, i.team, i.betriebsrat, i.einstellungsdatum, i.taetigkeit2
         , i.funktion, i.gebdatum, i.lastinsertupdate, i.filedate, i.row_hash
         , i.duplicate_ordinal, p_snapshot_date, '9999-12-31'
      FROM tmp_pa_raw_import i
     WHERE NOT EXISTS (
           SELECT 1
             FROM tbl_uebertrag_personalakte_scd_raw r
            WHERE r.pers_nr = i.pers_nr
              AND r.row_hash = i.row_hash
              AND r.duplicate_ordinal = i.duplicate_ordinal
              AND r.gueltig_bis = '9999-12-31'
     );

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_raw_source;
END//
