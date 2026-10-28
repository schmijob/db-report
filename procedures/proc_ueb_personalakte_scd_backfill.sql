-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_personalakte_scd_backfill.sql
-- Rebuild compact snapshots and the serving SCD using only the isolated upload table.
DROP PROCEDURE IF EXISTS `proc_ueb_personalakte_scd_backfill`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_personalakte_scd_backfill`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_done TINYINT DEFAULT 0;
    DECLARE var_snapshot_date DATE;
    DECLARE var_filedate DATETIME;
    DECLARE var_maxdate DATE;
    DECLARE var_bad_rows BIGINT DEFAULT 0;

    DECLARE snapshot_dates CURSOR FOR
        SELECT DISTINCT DATE(filedate)
          FROM tbl_import_personalakte_scd_backfill
         ORDER BY DATE(filedate);
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET var_done = 1;

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
            SET MESSAGE_TEXT = 'Staged Personalakte snapshots require PersNr and Druckdatum';
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
            SET MESSAGE_TEXT = 'A staged snapshot has duplicate personnel numbers';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_backfill_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_backfill_current;
    CREATE TEMPORARY TABLE tmp_pa_scd_backfill_import LIKE tbl_import_personalakte;
    CREATE TEMPORARY TABLE tmp_pa_scd_backfill_current LIKE tbl_ueb_personalakte;

    -- These are new, isolated objects. Re-running the procedure is a full rebuild.
    TRUNCATE TABLE tbl_ueb_personalakte_scd_snapshot;
    TRUNCATE TABLE tbl_ueb_personalakte_scd;
    TRUNCATE TABLE tbl_ueb_personalakte_scd_reconciliation;
    SELECT MAX(datum) INTO var_maxdate FROM tbl_datum;

    OPEN snapshot_dates;
    snapshot_loop: LOOP
        FETCH snapshot_dates INTO var_snapshot_date;
        IF var_done = 1 THEN
            LEAVE snapshot_loop;
        END IF;

        DELETE FROM tmp_pa_scd_backfill_import;
        DELETE FROM tmp_pa_scd_backfill_current;
        INSERT INTO tmp_pa_scd_backfill_import
        SELECT *
          FROM tbl_import_personalakte_scd_backfill
         WHERE filedate >= var_snapshot_date
           AND filedate < DATE_ADD(var_snapshot_date, INTERVAL 1 DAY);
        SELECT MAX(filedate) INTO var_filedate FROM tmp_pa_scd_backfill_import;

        INSERT INTO tmp_pa_scd_backfill_current (
              persnr, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
            , taetigkeit, team, br, übernahme, taetigkeit2, funktion, filedate
        )
        WITH personalakte AS (
            SELECT p.pers_nr
                 , REGEXP_REPLACE(p.name_vorname, '^[0-9]{2}\.[0-9]{2}\.[0-9]{2} ', '') AS name_vorname
                 , p.zeitarbeitsfirma
                 , TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' FROM p.oe_der_person)) AS oe_der_person
                 , p.schicht
                 , COALESCE(NULLIF(p.info, ''), IF(p.pers_nr < 95000, 'ZAK', 'DPW')) AS info
                 , p.beginn_besch
                 , TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' FROM p.taetigkeit)) AS taetigkeit
                 , CASE WHEN p.team IN ('8', '9', '10') THEN ''
                        ELSE TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' FROM p.team)) END AS team
                 , p.betriebsrat
                 , p.filedate
                 , CASE
                     WHEN p.info = 'ZAK'
                      AND p.ende_besch > DATE(var_filedate)
                      AND p.ende_besch BETWEEN p.beginn_besch + INTERVAL 80 DAY
                                           AND p.beginn_besch + INTERVAL 100 DAY
                       THEN p.beginn_besch + INTERVAL 15 MONTH
                     ELSE p.ende_besch
                   END AS ende_besch
                 , p.taetigkeit2
                 , p.funktion
              FROM tmp_pa_scd_backfill_import p
             WHERE p.ende_besch IS NOT NULL
               AND p.ende_besch <> '2022-07-31'
               AND p.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
        )
        SELECT p1.pers_nr
             , p1.name_vorname
             , p1.zeitarbeitsfirma
             , CASE
                 WHEN p1.betriebsrat = 'Freigestellt' THEN 'Freigestellter BR'
                 WHEN p1.team LIKE '%BGL%' THEN 'BGL'
                 WHEN p1.oe_der_person = 'alle ausgeschiedenen MAInnen'
                  AND p1.team REGEXP '^[A-Z]-[A-Z]+-[0-9]+$'
                   THEN REGEXP_REPLACE(p1.team, '^[A-Z]-([A-Z]+)(?:-[0-9]+)?$', '\1')
                 WHEN p1.oe_der_person = 'alle ausgeschiedenen MAInnen' THEN ''
                 ELSE COALESCE(pt.oe, ot.OE_neu, p1.oe_der_person)
               END
             , p1.schicht
             , p1.info
             , p1.beginn_besch
             , CASE
                 WHEN DATE(COALESCE(pt.ende, p1.ende_besch)) > var_maxdate
                   THEN DATE(COALESCE(pt.ende, p1.ende_besch))
                 ELSE (
                     SELECT MAX(d.datum)
                       FROM tbl_datum d
                      WHERE d.arbeitstag = 1
                        AND DATE(d.datum) <= DATE(COALESCE(pt.ende, p1.ende_besch))
                 )
               END
             , CASE
                 WHEN p1.betriebsrat = 'Freigestellt' THEN 'Freigestellter BR'
                 WHEN p1.pers_nr BETWEEN 7000 AND 7999 THEN 'Pausenvertretung'
                 WHEN ot.OE_neu = 'QS'
                  AND COALESCE(tt.taetigkeit_neu, p1.taetigkeit) = 'Lagerhelfer' THEN 'QS'
                 ELSE COALESCE(pt.taetigkeit, tt.taetigkeit_neu, p1.taetigkeit)
               END
             , p1.team
             , p1.betriebsrat
             , MAX(CASE
                   WHEN p2.beginn_besch - INTERVAL 60 DAY
                        BETWEEN p1.ende_besch - INTERVAL 60 DAY AND p1.ende_besch THEN 1
                   WHEN p2.ende_besch BETWEEN p1.beginn_besch - INTERVAL 60 DAY
                                          AND p1.beginn_besch THEN 2
                   ELSE 0
               END)
             , p1.taetigkeit2
             , p1.funktion
             , p1.filedate
          FROM personalakte p1
          LEFT JOIN tbl_stamm_OE_translate ot
            ON p1.oe_der_person = ot.OE_alt
          LEFT JOIN tbl_stamm_taetigkeit_translate tt
            ON p1.taetigkeit = tt.taetigkeit_alt
          LEFT JOIN tbl_stamm_persnr pt
            ON p1.pers_nr = pt.persnr
          LEFT JOIN personalakte p2
            ON CONCAT(SUBSTRING_INDEX(p1.name_vorname, ', ', 1), ', ',
                      SUBSTRING_INDEX(SUBSTRING_INDEX(p1.name_vorname, ', ', -1), ' ', 1))
             = CONCAT(SUBSTRING_INDEX(p2.name_vorname, ', ', 1), ', ',
                      SUBSTRING_INDEX(SUBSTRING_INDEX(p2.name_vorname, ', ', -1), ' ', 1))
           AND p1.pers_nr <> p2.pers_nr
         GROUP BY p1.pers_nr;

        -- Match the live transfer's one special upsert rule: blank OE values
        -- do not erase a previously stored nonblank OE for the same PersNr.
        UPDATE tmp_pa_scd_backfill_current c
        JOIN tbl_ueb_personalakte_scd_snapshot s
          ON s.persnr = c.persnr
         AND s.gueltig_bis = '9999-12-31'
           SET c.oe = s.oe
         WHERE c.oe = '';

        -- A missing or changed source number closes its old interval on the
        -- day before this export. Unchanged rows stay compact and open.
        UPDATE tbl_ueb_personalakte_scd_snapshot s
        LEFT JOIN tmp_pa_scd_backfill_current c
          ON c.persnr = s.persnr
           SET s.gueltig_bis = DATE_SUB(var_snapshot_date, INTERVAL 1 DAY)
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von < var_snapshot_date
           AND c.persnr IS NULL;

        UPDATE tbl_ueb_personalakte_scd_snapshot s
        JOIN tmp_pa_scd_backfill_current c
          ON c.persnr = s.persnr
           SET s.gueltig_bis = DATE_SUB(var_snapshot_date, INTERVAL 1 DAY)
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von < var_snapshot_date
           AND NOT (
                  s.`name`        <=> c.`name`
              AND s.pdl           <=> c.pdl
              AND s.oe            <=> c.oe
              AND s.schichtgruppe <=> c.schichtgruppe
              AND s.eg            <=> c.eg
              AND s.beginn        <=> c.beginn
              AND s.ende          <=> c.ende
              AND s.taetigkeit    <=> c.taetigkeit
              AND s.team          <=> c.team
              AND s.br            <=> c.br
              AND s.übernahme     <=> c.übernahme
              AND s.taetigkeit2   <=> c.taetigkeit2
              AND s.funktion      <=> c.funktion
           );

        INSERT INTO tbl_ueb_personalakte_scd_snapshot (
              persnr, gebdatum, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
            , taetigkeit, team, br, übernahme, taetigkeit2, funktion
            , last_insert_update, filedate, gueltig_von, gueltig_bis
        )
        SELECT c.persnr, NULLIF(i.gebdatum, '0000-00-00'), c.`name`, c.pdl, c.oe
             , c.schichtgruppe, c.eg, c.beginn, c.ende, c.taetigkeit, c.team, c.br
             , c.übernahme, c.taetigkeit2, c.funktion, CURRENT_TIMESTAMP, c.filedate
             , var_snapshot_date, '9999-12-31'
          FROM tmp_pa_scd_backfill_current c
          JOIN tmp_pa_scd_backfill_import i ON i.pers_nr = c.persnr
         WHERE NOT EXISTS (
               SELECT 1
                 FROM tbl_ueb_personalakte_scd_snapshot s
                WHERE s.persnr = c.persnr
                  AND s.gueltig_bis = '9999-12-31'
         );

        UPDATE tbl_ueb_personalakte_scd_snapshot s
        JOIN tmp_pa_scd_backfill_current c ON c.persnr = s.persnr
        JOIN tmp_pa_scd_backfill_import i ON i.pers_nr = c.persnr
           SET s.gebdatum = COALESCE(NULLIF(i.gebdatum, '0000-00-00'), s.gebdatum)
             , s.last_insert_update = CURRENT_TIMESTAMP
             , s.filedate = c.filedate
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von <= var_snapshot_date
           AND s.`name`        <=> c.`name`
           AND s.pdl           <=> c.pdl
           AND s.oe            <=> c.oe
           AND s.schichtgruppe <=> c.schichtgruppe
           AND s.eg            <=> c.eg
           AND s.beginn        <=> c.beginn
           AND s.ende          <=> c.ende
           AND s.taetigkeit    <=> c.taetigkeit
           AND s.team          <=> c.team
           AND s.br            <=> c.br
           AND s.übernahme     <=> c.übernahme
           AND s.taetigkeit2   <=> c.taetigkeit2
           AND s.funktion      <=> c.funktion;
    END LOOP;
    CLOSE snapshot_dates;

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_backfill_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_backfill_current;
    CALL proc_ueb_personalakte_scd_reconcile();
END//
