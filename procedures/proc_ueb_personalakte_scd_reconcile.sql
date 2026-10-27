-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_personalakte_scd_reconcile.sql
-- Rebuild the serving intervals from compact snapshots and effective-dated changes.
DROP PROCEDURE IF EXISTS `proc_ueb_personalakte_scd_reconcile`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_personalakte_scd_reconcile`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_map_iterations INT DEFAULT 0;
    DECLARE var_map_changes INT DEFAULT 0;

    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_events;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_persnr_links;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_persnr_map;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_snapshots;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_identity_handoffs;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_bounds;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_state;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_candidates;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_latest;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_values;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_wide;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_conflicts;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_next;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_lagged;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_markers;
    DROP TEMPORARY TABLE IF EXISTS tmp_pa_scd_groups;

    -- The change log records a new PersNr in `persnr` and the old one in
    -- `wert`. Resolve chains to the latest canonical number; keep each
    -- interval's source number in persnr_alt.
    CREATE TEMPORARY TABLE tmp_pa_scd_persnr_links ENGINE=InnoDB AS
    SELECT DISTINCT CAST(TRIM(wert) AS UNSIGNED) AS old_persnr,
                    persnr AS new_persnr
      FROM tbl_uebertrag_aenderungen_werte
     WHERE LOWER(TRIM(feld)) = 'personalnummer'
       AND TRIM(wert) REGEXP '^[0-9]+$'
       AND CAST(TRIM(wert) AS UNSIGNED) > 0
       AND persnr > 0
       AND CAST(TRIM(wert) AS UNSIGNED) <> persnr
       AND LOWER(COALESCE(beschreibung, '')) NOT LIKE '(gel%';

    IF EXISTS (
        SELECT old_persnr
          FROM tmp_pa_scd_persnr_links
         GROUP BY old_persnr
        HAVING COUNT(DISTINCT new_persnr) > 1
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'A source PersNr maps to multiple new PersNr values';
    END IF;

    ALTER TABLE tmp_pa_scd_persnr_links
      ADD PRIMARY KEY (old_persnr),
      ADD KEY ix_tmp_pa_scd_persnr_links_new (new_persnr);

    CREATE TEMPORARY TABLE tmp_pa_scd_persnr_map (
        source_persnr INT NOT NULL,
        canonical_persnr INT NOT NULL,
        PRIMARY KEY (source_persnr),
        KEY ix_tmp_pa_scd_persnr_map_canonical (canonical_persnr)
    ) ENGINE=InnoDB;

    INSERT INTO tmp_pa_scd_persnr_map (source_persnr, canonical_persnr)
    SELECT source_persnr, source_persnr
      FROM (
            SELECT persnr AS source_persnr
              FROM tbl_ueb_personalakte_scd_snapshot
            UNION
            SELECT old_persnr FROM tmp_pa_scd_persnr_links
            UNION
            SELECT new_persnr FROM tmp_pa_scd_persnr_links
      ) source_ids;

    UPDATE tmp_pa_scd_persnr_map m
    JOIN tmp_pa_scd_persnr_links l ON l.old_persnr = m.source_persnr
       SET m.canonical_persnr = l.new_persnr;

    SET var_map_changes = 1;
    WHILE var_map_changes > 0 DO
        UPDATE tmp_pa_scd_persnr_map m
        JOIN tmp_pa_scd_persnr_links l ON l.old_persnr = m.canonical_persnr
           SET m.canonical_persnr = l.new_persnr
         WHERE m.canonical_persnr <> l.new_persnr;
        SET var_map_changes = ROW_COUNT();
        SET var_map_iterations = var_map_iterations + 1;
        IF var_map_iterations > 1000 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'PersNr change history contains a cycle';
        END IF;
    END WHILE;

    CREATE TEMPORARY TABLE tmp_pa_scd_snapshots LIKE tbl_ueb_personalakte_scd;
    ALTER TABLE tmp_pa_scd_snapshots
      DROP PRIMARY KEY,
      DROP KEY ix_personalakte_scd_alt_date;

    INSERT INTO tmp_pa_scd_snapshots (
          persnr, persnr_alt, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
        , taetigkeit, team, br, `übernahme`, taetigkeit2, funktion
        , last_insert_update, filedate, gueltig_von, gueltig_bis
    )
    SELECT s.persnr, s.persnr, s.`name`, s.pdl, s.oe, s.schichtgruppe, s.eg, s.beginn, s.ende
         , s.taetigkeit, s.team, s.br, s.`übernahme`, s.taetigkeit2, s.funktion
         , s.last_insert_update, s.filedate, s.gueltig_von, s.gueltig_bis
      FROM tbl_ueb_personalakte_scd_snapshot s;

    -- If an old source number remains in later exports, stop its snapshot
    -- history when the linked new-number history first appears. The effective
    -- date inside that interval still comes from the change log event below.
    CREATE TEMPORARY TABLE tmp_pa_scd_identity_handoffs ENGINE=InnoDB AS
    SELECT l.old_persnr,
           l.new_persnr,
           MIN(s.gueltig_von) AS new_first_date
      FROM tmp_pa_scd_persnr_links l
      JOIN tbl_ueb_personalakte_scd_snapshot s
        ON s.persnr = l.new_persnr
     WHERE EXISTS (
            SELECT 1
              FROM tbl_ueb_personalakte_scd_snapshot old_snapshot
             WHERE old_snapshot.persnr = l.old_persnr
               AND old_snapshot.gueltig_bis >= s.gueltig_von
       )
     GROUP BY l.old_persnr, l.new_persnr;

    ALTER TABLE tmp_pa_scd_identity_handoffs
      ADD PRIMARY KEY (old_persnr);

    DELETE s
      FROM tmp_pa_scd_snapshots s
      JOIN tmp_pa_scd_identity_handoffs h
        ON h.old_persnr = s.persnr
     WHERE s.gueltig_von >= h.new_first_date;

    UPDATE tmp_pa_scd_snapshots s
    JOIN tmp_pa_scd_identity_handoffs h
      ON h.old_persnr = s.persnr
       SET s.gueltig_bis = DATE_SUB(h.new_first_date, INTERVAL 1 DAY)
     WHERE s.gueltig_von < h.new_first_date
       AND s.gueltig_bis >= h.new_first_date;

    UPDATE tmp_pa_scd_snapshots s
    JOIN tmp_pa_scd_persnr_map m ON m.source_persnr = s.persnr
       SET s.persnr = m.canonical_persnr;

    IF EXISTS (
        SELECT 1
          FROM tmp_pa_scd_snapshots a
          JOIN tmp_pa_scd_snapshots b
            ON b.persnr = a.persnr
           AND (b.gueltig_von > a.gueltig_von
                OR (b.gueltig_von = a.gueltig_von AND b.persnr_alt > a.persnr_alt))
           AND b.gueltig_von <= a.gueltig_bis
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Canonical PersNr histories overlap; inspect the snapshot intervals';
    END IF;

    ALTER TABLE tmp_pa_scd_snapshots
      ADD PRIMARY KEY (persnr, gueltig_von);

    CREATE TEMPORARY TABLE tmp_pa_scd_events ENGINE=InnoDB AS
    SELECT COALESCE(m.canonical_persnr, e.persnr) AS persnr,
           e.aenderungsdatum,
           CASE WHEN LOWER(TRIM(e.feld)) = 'personalnummer' THEN 'persnr_alt'
                ELSE CONVERT(e.feld USING utf8mb4) COLLATE utf8mb4_unicode_ci END AS feld,
           CASE WHEN LOWER(TRIM(e.feld)) = 'personalnummer' THEN CAST(e.persnr AS CHAR)
                ELSE CONVERT(e.wert USING utf8mb4) COLLATE utf8mb4_unicode_ci END AS wert,
           e.gueltig_von,
           e.gueltig_bis,
           e.filedate
      FROM tbl_uebertrag_aenderungen_werte e
      LEFT JOIN tmp_pa_scd_persnr_map m ON m.source_persnr = e.persnr
     WHERE CONVERT(e.beschreibung USING utf8mb4) COLLATE utf8mb4_unicode_ci
               NOT LIKE _utf8mb4'(Gelöscht)%' COLLATE utf8mb4_unicode_ci
       AND (LOWER(TRIM(e.feld)) = 'personalnummer'
         OR CONVERT(e.feld USING utf8mb4) COLLATE utf8mb4_unicode_ci IN (
             _utf8mb4'Nachname', _utf8mb4'Vorname'
           , _utf8mb4'Organisationseinheit der Person'
           , _utf8mb4'10 Schicht', _utf8mb4'Info 2', _utf8mb4'13 Team', _utf8mb4'Betriebsrat'
           , _utf8mb4'Beginn Beschäftigung'
           , _utf8mb4'Ende Beschäftigung'
           , _utf8mb4'Tätigkeit', _utf8mb4'14 Tätigkeit'
       ));
    ALTER TABLE tmp_pa_scd_events
      ADD KEY ix_tmp_pa_scd_events_person_date (persnr, gueltig_von, gueltig_bis, feld);

    CREATE TEMPORARY TABLE tmp_pa_scd_bounds (
        persnr INT NOT NULL,
        datum DATE NOT NULL,
        PRIMARY KEY (persnr, datum)
    ) ENGINE=InnoDB;

    INSERT IGNORE INTO tmp_pa_scd_bounds (persnr, datum)
    SELECT persnr, gueltig_von
      FROM tmp_pa_scd_snapshots;

    INSERT IGNORE INTO tmp_pa_scd_bounds (persnr, datum)
    SELECT persnr, DATE_ADD(gueltig_bis, INTERVAL 1 DAY)
      FROM tmp_pa_scd_snapshots
     WHERE gueltig_bis < '9999-12-31';

    INSERT IGNORE INTO tmp_pa_scd_bounds (persnr, datum)
    SELECT e.persnr, GREATEST(e.gueltig_von, c.min_datum)
      FROM tmp_pa_scd_events e
      JOIN (
            SELECT persnr, MIN(gueltig_von) AS min_datum, MAX(gueltig_bis) AS max_datum
              FROM tmp_pa_scd_snapshots
             GROUP BY persnr
      ) c ON c.persnr = e.persnr
     WHERE e.gueltig_bis >= c.min_datum
       AND e.gueltig_von <= c.max_datum;

    INSERT IGNORE INTO tmp_pa_scd_bounds (persnr, datum)
    SELECT e.persnr, DATE_ADD(e.gueltig_bis, INTERVAL 1 DAY)
      FROM tmp_pa_scd_events e
      JOIN (
            SELECT persnr, MIN(gueltig_von) AS min_datum, MAX(gueltig_bis) AS max_datum
              FROM tmp_pa_scd_snapshots
             GROUP BY persnr
      ) c ON c.persnr = e.persnr
     WHERE e.gueltig_bis >= c.min_datum
       AND e.gueltig_von <= c.max_datum
       AND e.gueltig_bis < c.max_datum;

    CREATE TEMPORARY TABLE tmp_pa_scd_state LIKE tbl_ueb_personalakte_scd;
    ALTER TABLE tmp_pa_scd_state
      DROP PRIMARY KEY,
      DROP KEY ix_personalakte_scd_alt_date,
      ADD COLUMN boundary_date DATE NOT NULL,
      ADD COLUMN base_gueltig_von DATE NOT NULL,
      ADD COLUMN base_gueltig_bis DATE NOT NULL,
      ADD COLUMN segment_end DATE NULL,
      ADD KEY ix_tmp_pa_scd_state_person_boundary (persnr, boundary_date);

    INSERT INTO tmp_pa_scd_state
    SELECT s.*, b.datum, s.gueltig_von, s.gueltig_bis, NULL
      FROM tmp_pa_scd_snapshots s
      JOIN tmp_pa_scd_bounds b
        ON b.persnr = s.persnr
       AND b.datum BETWEEN s.gueltig_von AND s.gueltig_bis;

    CREATE TEMPORARY TABLE tmp_pa_scd_candidates ENGINE=InnoDB AS
    SELECT s.persnr, s.boundary_date, e.feld, e.wert, e.aenderungsdatum, e.filedate
      FROM tmp_pa_scd_state s
      JOIN tmp_pa_scd_events e
        ON e.persnr = s.persnr
       AND s.boundary_date BETWEEN e.gueltig_von AND e.gueltig_bis;
    ALTER TABLE tmp_pa_scd_candidates
      ADD KEY ix_tmp_pa_scd_candidates_person_date_field (persnr, boundary_date, feld, aenderungsdatum);

    CREATE TEMPORARY TABLE tmp_pa_scd_latest ENGINE=InnoDB AS
    SELECT persnr,
           boundary_date,
           feld,
           MAX(aenderungsdatum) AS latest_aenderungsdatum,
           MAX(filedate) AS latest_filedate
      FROM tmp_pa_scd_candidates
     GROUP BY persnr, boundary_date, feld;
    ALTER TABLE tmp_pa_scd_latest
      ADD KEY ix_tmp_pa_scd_latest_person_date_field (persnr, boundary_date, feld, latest_aenderungsdatum);

    CREATE TEMPORARY TABLE tmp_pa_scd_values ENGINE=InnoDB AS
    SELECT c.persnr,
           c.boundary_date,
           c.feld,
           MAX(c.filedate) AS event_filedate,
           COUNT(DISTINCT c.wert) AS value_count,
           MIN(c.wert) AS event_value,
           GROUP_CONCAT(DISTINCT c.wert SEPARATOR ' | ') AS event_values
      FROM tmp_pa_scd_candidates c
      JOIN tmp_pa_scd_latest l
        ON l.persnr = c.persnr
       AND l.boundary_date = c.boundary_date
       AND l.feld = c.feld
       AND l.latest_aenderungsdatum = c.aenderungsdatum
       AND l.latest_filedate <=> c.filedate
     GROUP BY c.persnr, c.boundary_date, c.feld;
    ALTER TABLE tmp_pa_scd_values
      ADD KEY ix_tmp_pa_scd_values_person_date (persnr, boundary_date, feld);

    CREATE TEMPORARY TABLE tmp_pa_scd_wide ENGINE=InnoDB AS
    SELECT persnr,
           boundary_date,
           MAX(CASE WHEN feld = 'persnr_alt' THEN value_count END) AS cnt_persnr_alt,
           MAX(CASE WHEN feld = 'persnr_alt' THEN event_value END) AS value_persnr_alt,
           MAX(CASE WHEN feld = 'persnr_alt' THEN event_values END) AS values_persnr_alt,
           MAX(CASE WHEN feld = 'persnr_alt' THEN event_filedate END) AS filedate_persnr_alt,
           MAX(CASE WHEN feld = 'Nachname' THEN value_count END) AS cnt_nachname,
           MAX(CASE WHEN feld = 'Nachname' THEN event_value END) AS value_nachname,
           MAX(CASE WHEN feld = 'Nachname' THEN event_values END) AS values_nachname,
           MAX(CASE WHEN feld = 'Nachname' THEN event_filedate END) AS filedate_nachname,
           MAX(CASE WHEN feld = 'Vorname' THEN value_count END) AS cnt_vorname,
           MAX(CASE WHEN feld = 'Vorname' THEN event_value END) AS value_vorname,
           MAX(CASE WHEN feld = 'Vorname' THEN event_values END) AS values_vorname,
           MAX(CASE WHEN feld = 'Vorname' THEN event_filedate END) AS filedate_vorname,
           MAX(CASE WHEN feld = 'Organisationseinheit der Person' THEN value_count END) AS cnt_oe,
           MAX(CASE WHEN feld = 'Organisationseinheit der Person' THEN event_value END) AS value_oe,
           MAX(CASE WHEN feld = 'Organisationseinheit der Person' THEN event_values END) AS values_oe,
           MAX(CASE WHEN feld = 'Organisationseinheit der Person' THEN event_filedate END) AS filedate_oe,
           MAX(CASE WHEN feld = '10 Schicht' THEN value_count END) AS cnt_schicht,
           MAX(CASE WHEN feld = '10 Schicht' THEN event_value END) AS value_schicht,
           MAX(CASE WHEN feld = '10 Schicht' THEN event_values END) AS values_schicht,
           MAX(CASE WHEN feld = '10 Schicht' THEN event_filedate END) AS filedate_schicht,
           MAX(CASE WHEN feld = 'Info 2' THEN value_count END) AS cnt_eg,
           MAX(CASE WHEN feld = 'Info 2' THEN event_value END) AS value_eg,
           MAX(CASE WHEN feld = 'Info 2' THEN event_values END) AS values_eg,
           MAX(CASE WHEN feld = 'Info 2' THEN event_filedate END) AS filedate_eg,
           MAX(CASE WHEN feld = (_utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN value_count END) AS cnt_beginn,
           MAX(CASE WHEN feld = (_utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_value END) AS value_beginn,
           MAX(CASE WHEN feld = (_utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_values END) AS values_beginn,
           MAX(CASE WHEN feld = (_utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_filedate END) AS filedate_beginn,
           MAX(CASE WHEN feld = (_utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN value_count END) AS cnt_ende,
           MAX(CASE WHEN feld = (_utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_value END) AS value_ende,
           MAX(CASE WHEN feld = (_utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_values END) AS values_ende,
           MAX(CASE WHEN feld = (_utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci) THEN event_filedate END) AS filedate_ende,
           MAX(CASE WHEN feld = (_utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN value_count END) AS cnt_taetigkeit,
           MAX(CASE WHEN feld = (_utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_value END) AS value_taetigkeit,
           MAX(CASE WHEN feld = (_utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_values END) AS values_taetigkeit,
           MAX(CASE WHEN feld = (_utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_filedate END) AS filedate_taetigkeit,
           MAX(CASE WHEN feld = '13 Team' THEN value_count END) AS cnt_team,
           MAX(CASE WHEN feld = '13 Team' THEN event_value END) AS value_team,
           MAX(CASE WHEN feld = '13 Team' THEN event_values END) AS values_team,
           MAX(CASE WHEN feld = '13 Team' THEN event_filedate END) AS filedate_team,
           MAX(CASE WHEN feld = 'Betriebsrat' THEN value_count END) AS cnt_br,
           MAX(CASE WHEN feld = 'Betriebsrat' THEN event_value END) AS value_br,
           MAX(CASE WHEN feld = 'Betriebsrat' THEN event_values END) AS values_br,
           MAX(CASE WHEN feld = 'Betriebsrat' THEN event_filedate END) AS filedate_br,
           MAX(CASE WHEN feld = (_utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN value_count END) AS cnt_taetigkeit2,
           MAX(CASE WHEN feld = (_utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_value END) AS value_taetigkeit2,
           MAX(CASE WHEN feld = (_utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_values END) AS values_taetigkeit2,
           MAX(CASE WHEN feld = (_utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci) THEN event_filedate END) AS filedate_taetigkeit2
      FROM tmp_pa_scd_values
     GROUP BY persnr, boundary_date;
    ALTER TABLE tmp_pa_scd_wide
      ADD KEY ix_tmp_pa_scd_wide_person_date (persnr, boundary_date);

    CREATE TEMPORARY TABLE tmp_pa_scd_conflicts ENGINE=InnoDB AS
    SELECT s.persnr, s.boundary_date AS datum, 'persnr_alt' AS feld,
           CAST(s.persnr_alt AS CHAR) AS snapshot_wert,
           w.values_persnr_alt AS aenderungswerte,
           'Conflicting latest aenderungen values; snapshot fallback' AS grund
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_persnr_alt > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'persnr_alt',
           CAST(s.persnr_alt AS CHAR), w.values_persnr_alt,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_persnr_alt = 1
       AND (w.filedate_persnr_alt IS NULL OR s.filedate IS NULL OR w.filedate_persnr_alt <= s.filedate)
       AND NOT (CAST(w.value_persnr_alt AS UNSIGNED) <=> s.persnr_alt)
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Nachname',
           CAST(SUBSTRING_INDEX(s.`name`, ', ', 1) AS CHAR) AS snapshot_wert,
           w.values_nachname AS aenderungswerte,
           'Conflicting latest aenderungen values; snapshot fallback' AS grund
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_nachname > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Vorname',
           CAST(SUBSTRING_INDEX(s.`name`, ', ', -1) AS CHAR), w.values_vorname,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_vorname > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Organisationseinheit der Person',
           CAST(s.oe AS CHAR), w.values_oe,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_oe > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, '10 Schicht',
           CAST(s.schichtgruppe AS CHAR), w.values_schicht,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_schicht > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Info 2',
           CAST(s.eg AS CHAR), w.values_eg,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_eg > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.beginn AS CHAR), w.values_beginn,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_beginn > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.ende AS CHAR), w.values_ende,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_ende > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci,
           CAST(s.taetigkeit AS CHAR), w.values_taetigkeit,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_taetigkeit > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, '13 Team',
           CAST(s.team AS CHAR), w.values_team,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_team > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Betriebsrat',
           CAST(s.br AS CHAR), w.values_br,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_br > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci,
           CAST(s.taetigkeit2 AS CHAR), w.values_taetigkeit2,
           'Conflicting latest aenderungen values; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_taetigkeit2 > 1
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.beginn AS CHAR), w.values_beginn,
           'Invalid aenderungen date; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_beginn = 1
       AND w.value_beginn <> ''
       AND COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                    STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) IS NULL
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.ende AS CHAR), w.values_ende,
           'Invalid aenderungen date; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_ende = 1
       AND w.value_ende <> ''
       AND COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                    STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d')) IS NULL
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Nachname',
           CAST(SUBSTRING_INDEX(s.`name`, ', ', 1) AS CHAR), w.values_nachname,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_nachname = 1
       AND (w.filedate_nachname IS NULL OR s.filedate IS NULL OR w.filedate_nachname <= s.filedate)
       AND NOT (w.value_nachname <=> SUBSTRING_INDEX(s.`name`, ', ', 1))
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Vorname',
           CAST(SUBSTRING_INDEX(s.`name`, ', ', -1) AS CHAR), w.values_vorname,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_vorname = 1
       AND (w.filedate_vorname IS NULL OR s.filedate IS NULL OR w.filedate_vorname <= s.filedate)
       AND NOT (w.value_vorname <=> SUBSTRING_INDEX(s.`name`, ', ', -1))
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Organisationseinheit der Person',
           CAST(s.oe AS CHAR), w.values_oe,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_oe = 1
       AND (w.filedate_oe IS NULL OR s.filedate IS NULL OR w.filedate_oe <= s.filedate)
       AND NOT (w.value_oe <=> s.oe)
    UNION ALL
    SELECT s.persnr, s.boundary_date, '10 Schicht',
           CAST(s.schichtgruppe AS CHAR), w.values_schicht,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_schicht = 1
       AND (w.filedate_schicht IS NULL OR s.filedate IS NULL OR w.filedate_schicht <= s.filedate)
       AND NOT (w.value_schicht <=> s.schichtgruppe)
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Info 2',
           CAST(s.eg AS CHAR), w.values_eg,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_eg = 1
       AND (w.filedate_eg IS NULL OR s.filedate IS NULL OR w.filedate_eg <= s.filedate)
       AND NOT (w.value_eg <=> s.eg)
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Beginn Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.beginn AS CHAR), w.values_beginn,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_beginn = 1
       AND (w.filedate_beginn IS NULL OR s.filedate IS NULL OR w.filedate_beginn <= s.filedate)
       AND (w.value_beginn = '' OR COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                                            STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) IS NOT NULL)
       AND NOT ((CASE WHEN w.value_beginn = '' THEN DATE('2000-01-01')
                      ELSE COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                                    STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) END) <=> s.beginn)
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Ende Beschäftigung' COLLATE utf8mb4_unicode_ci,
           CAST(s.ende AS CHAR), w.values_ende,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_ende = 1
       AND (w.filedate_ende IS NULL OR s.filedate IS NULL OR w.filedate_ende <= s.filedate)
       AND (w.value_ende = '' OR COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                                          STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d')) IS NOT NULL)
       AND NOT ((CASE WHEN w.value_ende = '' THEN DATE('9999-12-31')
                      ELSE COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                                    STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d')) END) <=> s.ende)
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'Tätigkeit' COLLATE utf8mb4_unicode_ci,
           CAST(s.taetigkeit AS CHAR), w.values_taetigkeit,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_taetigkeit = 1
       AND (w.filedate_taetigkeit IS NULL OR s.filedate IS NULL OR w.filedate_taetigkeit <= s.filedate)
       AND NOT (w.value_taetigkeit <=> s.taetigkeit)
    UNION ALL
    SELECT s.persnr, s.boundary_date, '13 Team',
           CAST(s.team AS CHAR), w.values_team,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_team = 1
       AND (w.filedate_team IS NULL OR s.filedate IS NULL OR w.filedate_team <= s.filedate)
       AND NOT (w.value_team <=> s.team)
    UNION ALL
    SELECT s.persnr, s.boundary_date, 'Betriebsrat',
           CAST(s.br AS CHAR), w.values_br,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_br = 1
       AND (w.filedate_br IS NULL OR s.filedate IS NULL OR w.filedate_br <= s.filedate)
       AND NOT (w.value_br <=> s.br)
    UNION ALL
    SELECT s.persnr, s.boundary_date, _utf8mb4'14 Tätigkeit' COLLATE utf8mb4_unicode_ci,
           CAST(s.taetigkeit2 AS CHAR), w.values_taetigkeit2,
           'Snapshot disagrees with aenderungen already known at filedate; snapshot fallback'
      FROM tmp_pa_scd_state s JOIN tmp_pa_scd_wide w USING (persnr, boundary_date)
     WHERE w.cnt_taetigkeit2 = 1
       AND (w.filedate_taetigkeit2 IS NULL OR s.filedate IS NULL OR w.filedate_taetigkeit2 <= s.filedate)
       AND NOT (w.value_taetigkeit2 <=> s.taetigkeit2);

    DELETE FROM tbl_ueb_personalakte_scd_reconciliation;
    INSERT INTO tbl_ueb_personalakte_scd_reconciliation
    SELECT persnr, datum, feld, snapshot_wert, aenderungswerte, grund
      FROM tmp_pa_scd_conflicts;

    INSERT INTO tbl_ueb_personalakte_scd_reconciliation (
        persnr, datum, feld, snapshot_wert, aenderungswerte, grund
    )
    SELECT m.canonical_persnr,
           h.new_first_date,
           'persnr_alias_handoff',
           GROUP_CONCAT(DISTINCT h.old_persnr ORDER BY h.old_persnr),
           GROUP_CONCAT(DISTINCT h.new_persnr ORDER BY h.new_persnr),
           'Linked source-number snapshot overlaps; later PersNr snapshot takes over'
      FROM tmp_pa_scd_identity_handoffs h
      JOIN tmp_pa_scd_persnr_map m
        ON m.source_persnr = h.old_persnr
     GROUP BY m.canonical_persnr, h.new_first_date;

    UPDATE tmp_pa_scd_state s
    LEFT JOIN tmp_pa_scd_wide w
      ON w.persnr = s.persnr
     AND w.boundary_date = s.boundary_date
       SET s.persnr_alt = CASE
             WHEN w.cnt_persnr_alt = 1
              AND ((s.filedate IS NOT NULL AND w.filedate_persnr_alt > s.filedate)
                   OR CAST(w.value_persnr_alt AS UNSIGNED) <=> s.persnr_alt)
               THEN CAST(w.value_persnr_alt AS UNSIGNED)
             ELSE s.persnr_alt
           END,
           s.`name` = CASE
             WHEN COALESCE(w.cnt_nachname, 0) = 0 AND COALESCE(w.cnt_vorname, 0) = 0 THEN s.`name`
             ELSE CONCAT(
                    CASE WHEN w.cnt_nachname = 1
                               AND ((s.filedate IS NOT NULL AND w.filedate_nachname > s.filedate)
                                    OR w.value_nachname <=> SUBSTRING_INDEX(s.`name`, ', ', 1))
                         THEN w.value_nachname ELSE SUBSTRING_INDEX(s.`name`, ', ', 1) END,
                    ', ',
                    CASE WHEN w.cnt_vorname = 1
                               AND ((s.filedate IS NOT NULL AND w.filedate_vorname > s.filedate)
                                    OR w.value_vorname <=> SUBSTRING_INDEX(s.`name`, ', ', -1))
                         THEN w.value_vorname ELSE SUBSTRING_INDEX(s.`name`, ', ', -1) END
                  )
           END,
           s.oe = CASE WHEN w.cnt_oe = 1
                            AND ((s.filedate IS NOT NULL AND w.filedate_oe > s.filedate) OR w.value_oe <=> s.oe)
                       THEN w.value_oe ELSE s.oe END,
           s.schichtgruppe = CASE WHEN w.cnt_schicht = 1
                                       AND ((s.filedate IS NOT NULL AND w.filedate_schicht > s.filedate) OR w.value_schicht <=> s.schichtgruppe)
                                  THEN w.value_schicht ELSE s.schichtgruppe END,
           s.eg = CASE WHEN w.cnt_eg = 1
                            AND ((s.filedate IS NOT NULL AND w.filedate_eg > s.filedate) OR w.value_eg <=> s.eg)
                       THEN w.value_eg ELSE s.eg END,
           s.beginn = CASE
             WHEN w.cnt_beginn = 1
              AND (w.value_beginn = '' OR COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                                                     STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) IS NOT NULL)
              AND ((s.filedate IS NOT NULL AND w.filedate_beginn > s.filedate)
                   OR (CASE WHEN w.value_beginn = '' THEN DATE('2000-01-01')
                            ELSE COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                                          STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) END) <=> s.beginn)
              AND w.value_beginn = '' THEN '2000-01-01'
             WHEN w.cnt_beginn = 1
              AND COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                           STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) IS NOT NULL
              AND ((s.filedate IS NOT NULL AND w.filedate_beginn > s.filedate)
                   OR COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                               STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d')) <=> s.beginn)
               THEN COALESCE(STR_TO_DATE(LEFT(w.value_beginn, 10), '%d.%m.%Y'),
                             STR_TO_DATE(LEFT(w.value_beginn, 10), '%Y-%m-%d'))
             ELSE s.beginn
           END,
           s.ende = CASE
             WHEN w.cnt_ende = 1
              AND w.value_ende = ''
              AND ((s.filedate IS NOT NULL AND w.filedate_ende > s.filedate)
                   OR DATE('9999-12-31') <=> s.ende) THEN '9999-12-31'
             WHEN w.cnt_ende = 1
              AND COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                           STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d')) IS NOT NULL
              AND ((s.filedate IS NOT NULL AND w.filedate_ende > s.filedate)
                   OR COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                               STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d')) <=> s.ende)
               THEN COALESCE(STR_TO_DATE(LEFT(w.value_ende, 10), '%d.%m.%Y'),
                             STR_TO_DATE(LEFT(w.value_ende, 10), '%Y-%m-%d'))
             ELSE s.ende
           END,
           s.taetigkeit = CASE WHEN w.cnt_taetigkeit = 1
                                    AND ((s.filedate IS NOT NULL AND w.filedate_taetigkeit > s.filedate) OR w.value_taetigkeit <=> s.taetigkeit)
                               THEN w.value_taetigkeit ELSE s.taetigkeit END,
           s.team = CASE WHEN w.cnt_team = 1
                              AND ((s.filedate IS NOT NULL AND w.filedate_team > s.filedate) OR w.value_team <=> s.team)
                         THEN w.value_team ELSE s.team END,
           s.br = CASE WHEN w.cnt_br = 1
                            AND ((s.filedate IS NOT NULL AND w.filedate_br > s.filedate) OR w.value_br <=> s.br)
                       THEN w.value_br ELSE s.br END,
           s.taetigkeit2 = CASE WHEN w.cnt_taetigkeit2 = 1
                                     AND ((s.filedate IS NOT NULL AND w.filedate_taetigkeit2 > s.filedate) OR w.value_taetigkeit2 <=> s.taetigkeit2)
                                THEN w.value_taetigkeit2 ELSE s.taetigkeit2 END
      ;

    CREATE TEMPORARY TABLE tmp_pa_scd_next ENGINE=InnoDB AS
    SELECT persnr,
           boundary_date,
           CASE
             WHEN next_boundary IS NULL THEN base_gueltig_bis
             WHEN DATE_SUB(next_boundary, INTERVAL 1 DAY) > base_gueltig_bis THEN base_gueltig_bis
             ELSE DATE_SUB(next_boundary, INTERVAL 1 DAY)
           END AS segment_end
      FROM (
            SELECT persnr,
                   boundary_date,
                   base_gueltig_bis,
                   LEAD(boundary_date) OVER (PARTITION BY persnr ORDER BY boundary_date) AS next_boundary
              FROM tmp_pa_scd_state
      ) n;

    UPDATE tmp_pa_scd_state s
    JOIN tmp_pa_scd_next n
      ON n.persnr = s.persnr
     AND n.boundary_date = s.boundary_date
       SET s.segment_end = n.segment_end;

    CREATE TEMPORARY TABLE tmp_pa_scd_lagged ENGINE=InnoDB AS
    SELECT s.persnr,
           s.boundary_date,
           s.segment_end,
           LAG(s.segment_end) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_segment_end,
           LAG(s.persnr_alt) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_persnr_alt,
           LAG(s.`name`) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_name,
           LAG(s.pdl) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_pdl,
           LAG(s.oe) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_oe,
           LAG(s.schichtgruppe) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_schichtgruppe,
           LAG(s.eg) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_eg,
           LAG(s.beginn) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_beginn,
           LAG(s.ende) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_ende,
           LAG(s.taetigkeit) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_taetigkeit,
           LAG(s.team) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_team,
           LAG(s.br) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_br,
           LAG(s.übernahme) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_übernahme,
           LAG(s.taetigkeit2) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_taetigkeit2,
           LAG(s.funktion) OVER (PARTITION BY s.persnr ORDER BY s.boundary_date) AS prev_funktion
      FROM tmp_pa_scd_state s;

    CREATE TEMPORARY TABLE tmp_pa_scd_markers ENGINE=InnoDB AS
    SELECT persnr,
           boundary_date,
           segment_end,
           SUM(starts_new_state) OVER (PARTITION BY persnr ORDER BY boundary_date) AS state_group
      FROM (
            SELECT l.persnr,
                   l.boundary_date,
                   l.segment_end,
                   CASE
                     WHEN l.prev_segment_end = DATE_SUB(l.boundary_date, INTERVAL 1 DAY)
                      AND s.persnr_alt    <=> l.prev_persnr_alt
                      AND s.`name`        <=> l.prev_name
                      AND s.pdl           <=> l.prev_pdl
                      AND s.oe            <=> l.prev_oe
                      AND s.schichtgruppe <=> l.prev_schichtgruppe
                      AND s.eg            <=> l.prev_eg
                      AND s.beginn        <=> l.prev_beginn
                      AND s.ende          <=> l.prev_ende
                      AND s.taetigkeit    <=> l.prev_taetigkeit
                      AND s.team          <=> l.prev_team
                      AND s.br            <=> l.prev_br
                      AND s.übernahme     <=> l.prev_übernahme
                      AND s.taetigkeit2   <=> l.prev_taetigkeit2
                      AND s.funktion      <=> l.prev_funktion
                       THEN 0
                     ELSE 1
                   END AS starts_new_state
              FROM tmp_pa_scd_lagged l
              JOIN tmp_pa_scd_state s
                ON s.persnr = l.persnr
               AND s.boundary_date = l.boundary_date
      ) changed;

    CREATE TEMPORARY TABLE tmp_pa_scd_groups ENGINE=InnoDB AS
    SELECT m.persnr,
           m.state_group,
           MIN(m.boundary_date) AS first_boundary,
           MAX(m.segment_end) AS last_boundary,
           MAX(s.last_insert_update) AS last_insert_update,
           MAX(s.filedate) AS filedate
      FROM tmp_pa_scd_markers m
      JOIN tmp_pa_scd_state s
        ON s.persnr = m.persnr
       AND s.boundary_date = m.boundary_date
     GROUP BY m.persnr, m.state_group;

    UPDATE tmp_pa_scd_state s
    JOIN tmp_pa_scd_groups g
      ON g.persnr = s.persnr
     AND g.first_boundary = s.boundary_date
       SET s.gueltig_von = g.first_boundary,
           s.gueltig_bis = g.last_boundary,
           s.last_insert_update = g.last_insert_update,
           s.filedate = g.filedate;

    DELETE s
      FROM tmp_pa_scd_state s
      LEFT JOIN tmp_pa_scd_groups g
        ON g.persnr = s.persnr
       AND g.first_boundary = s.boundary_date
     WHERE g.persnr IS NULL;

    ALTER TABLE tmp_pa_scd_state
      DROP COLUMN boundary_date,
      DROP COLUMN base_gueltig_von,
      DROP COLUMN base_gueltig_bis,
      DROP COLUMN segment_end,
      ADD PRIMARY KEY (persnr, gueltig_von);

    DELETE FROM tbl_ueb_personalakte_scd;
    INSERT INTO tbl_ueb_personalakte_scd
    SELECT * FROM tmp_pa_scd_state;
END//
