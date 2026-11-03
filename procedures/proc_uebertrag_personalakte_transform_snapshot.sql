-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte_transform_snapshot.sql
-- Shared current and historical Personalakte normalization.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte_transform_snapshot`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte_transform_snapshot`(
    IN p_snapshot_date DATE,
    IN p_from_raw_history TINYINT
)
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    DECLARE var_maxdate DATE;
    DECLARE var_ambiguous_tenures BIGINT DEFAULT 0;

    IF p_snapshot_date IS NULL OR p_from_raw_history IS NULL
       OR p_from_raw_history NOT IN (0, 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A snapshot date and a valid source flag are required';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import_raw;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_normalized;
    -- The raw staging table is deliberately keyless so duplicate PersNr rows
    -- survive until the tenure selection below.
    CREATE TEMPORARY TABLE tmp_personalakte_import_raw AS
    SELECT * FROM tbl_import_personalakte WHERE 1 = 0;
    CREATE TEMPORARY TABLE tmp_personalakte_import LIKE tbl_import_personalakte;
    CREATE TEMPORARY TABLE tmp_personalakte_normalized LIKE tbl_ueb_personalakte;

    IF p_from_raw_history = 1 THEN
        SELECT d.filedate INTO var_filedate
          FROM tbl_uebertrag_personalakte_scd_dates d
         WHERE d.snapshot_date = p_snapshot_date;

        INSERT INTO tmp_personalakte_import_raw (
              pers_nr, name_vorname, zeitarbeitsfirma, oe_der_person, schicht
            , info, beginn_besch, ende_besch, eg, geschlecht, taetigkeit, team
            , betriebsrat, einstellungsdatum, taetigkeit2, funktion, gebdatum
            , lastinsertupdate, filedate
        )
        SELECT r.pers_nr, r.name_vorname, r.zeitarbeitsfirma, r.oe_der_person
             , r.schicht, r.info, r.beginn_besch, r.ende_besch, r.eg, r.geschlecht
             , r.taetigkeit, r.team, r.betriebsrat, r.einstellungsdatum
             , r.taetigkeit2, r.funktion, r.gebdatum, r.lastinsertupdate
             , var_filedate
          FROM tbl_uebertrag_personalakte_scd_raw r
         WHERE r.gueltig_von <= p_snapshot_date
           AND r.gueltig_bis >= p_snapshot_date;
    ELSE
        INSERT INTO tmp_personalakte_import_raw
        SELECT *
          FROM tbl_import_personalakte
         WHERE filedate >= p_snapshot_date
           AND filedate < DATE_ADD(p_snapshot_date, INTERVAL 1 DAY);
        SELECT MAX(filedate) INTO var_filedate FROM tmp_personalakte_import_raw;
    END IF;

    IF var_filedate IS NULL OR NOT EXISTS (SELECT 1 FROM tmp_personalakte_import_raw) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'No Personalakte input exists for the requested snapshot date';
    END IF;

    -- Same-PersNr rows with different employment starts represent separate
    -- tenures. If two different rows share the same start, neither is a safe
    -- winner for the one-person normalized snapshot.
    SELECT COUNT(*) INTO var_ambiguous_tenures
      FROM (
            SELECT p.pers_nr, p.beginn_besch
              FROM tmp_personalakte_import_raw p
             WHERE p.ende_besch IS NOT NULL
               AND p.ende_besch <> '2022-07-31'
               AND p.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
             GROUP BY p.pers_nr, p.beginn_besch
            HAVING COUNT(DISTINCT SHA2(JSON_ARRAY(
                       p.name_vorname, p.zeitarbeitsfirma, p.oe_der_person
                     , p.schicht, p.info, p.beginn_besch, p.ende_besch, p.eg
                     , p.geschlecht, p.taetigkeit, p.team, p.betriebsrat
                     , p.einstellungsdatum, p.taetigkeit2, p.funktion, p.gebdatum
                   ), 256)) > 1
           ) ambiguous;
    IF var_ambiguous_tenures > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Different Personalakte rows share a PersNr and employment start';
    END IF;

    -- Keep the latest tenure that has started as of this snapshot. If all
    -- available tenures start later, retain the nearest upcoming tenure.
    INSERT INTO tmp_personalakte_import (
          pers_nr, name_vorname, zeitarbeitsfirma, oe_der_person, schicht
        , info, beginn_besch, ende_besch, eg, geschlecht, taetigkeit, team
        , betriebsrat, einstellungsdatum, taetigkeit2, funktion, gebdatum
        , lastinsertupdate, filedate
    )
    SELECT p.pers_nr, p.name_vorname, p.zeitarbeitsfirma, p.oe_der_person
         , p.schicht, p.info, p.beginn_besch, p.ende_besch, p.eg, p.geschlecht
         , p.taetigkeit, p.team, p.betriebsrat, p.einstellungsdatum
         , p.taetigkeit2, p.funktion, p.gebdatum, p.lastinsertupdate, p.filedate
      FROM (
            SELECT source_row.*
                 , ROW_NUMBER() OVER (
                       PARTITION BY source_row.pers_nr
                       ORDER BY (source_row.beginn_besch > p_snapshot_date)
                              , CASE WHEN source_row.beginn_besch <= p_snapshot_date
                                     THEN source_row.beginn_besch END DESC
                              , CASE WHEN source_row.beginn_besch > p_snapshot_date
                                     THEN source_row.beginn_besch END ASC
                              , source_row.ende_besch DESC
                              , source_row.name_vorname
                              , source_row.zeitarbeitsfirma
                              , source_row.oe_der_person
                              , source_row.schicht
                              , source_row.info
                              , source_row.eg
                              , source_row.geschlecht
                              , source_row.taetigkeit
                              , source_row.team
                              , source_row.betriebsrat
                              , source_row.einstellungsdatum
                              , source_row.taetigkeit2
                              , source_row.funktion
                              , source_row.gebdatum
                              , source_row.lastinsertupdate DESC
                   ) AS tenure_rank
              FROM tmp_personalakte_import_raw source_row
             WHERE source_row.ende_besch IS NOT NULL
               AND source_row.ende_besch <> '2022-07-31'
               AND source_row.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
           ) p
     WHERE p.tenure_rank = 1;

    SELECT MAX(datum) INTO var_maxdate FROM tbl_datum;

    -- Keep all Personalakte normalization and business rules in this one query.
    INSERT INTO tmp_personalakte_normalized (
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
          FROM tmp_personalakte_import p
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
         , var_filedate
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

    -- Preserve the existing transfer's blank-OE upsert rule in both current
    -- and historical runs, using the prior state appropriate to that run.
    IF p_from_raw_history = 1 THEN
        UPDATE tmp_personalakte_normalized n
        JOIN (
            SELECT s.persnr, s.oe
              FROM tbl_ueb_personalakte_scd_snapshot s
              JOIN (
                    SELECT persnr, MAX(gueltig_von) AS gueltig_von
                      FROM tbl_ueb_personalakte_scd_snapshot
                     WHERE gueltig_von < p_snapshot_date
                     GROUP BY persnr
              ) latest
                ON latest.persnr = s.persnr
               AND latest.gueltig_von = s.gueltig_von
        ) previous_state
          ON previous_state.persnr = n.persnr
           SET n.oe = previous_state.oe
         WHERE n.oe = '';
    ELSE
        UPDATE tmp_personalakte_normalized n
        JOIN tbl_ueb_personalakte current_state
          ON current_state.persnr = n.persnr
           SET n.oe = current_state.oe
         WHERE n.oe = '';
    END IF;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import_raw;
END//
