-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_join.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
-- Builds the v2 shadow output; create tbl_ueb_fz_buchungen_v2 before deploying this procedure.
-- The first run backfills all source days; later runs use dirty days and the legacy date window.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_join`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_join`()
SQL SECURITY DEFINER BEGIN

    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_affected;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_virtual;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_resolved_day;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_tp_shift;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_expected_slots;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_bookings;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_actual_slots;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_day_slots;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_exact_matches;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_remaining_expected;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_assignments;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_shift_rows;
    DROP TEMPORARY TABLE IF EXISTS tmp_fz_join_output;

    CREATE TEMPORARY TABLE tmp_fz_join_affected AS
    SELECT candidates.persnr
         , candidates.datum
      FROM (
            SELECT j.persnr
                 , j.datum
              FROM tbl_ueb_fz_join j
             WHERE j.last_insert_update > COALESCE(j.last_calculated, '1000-01-01 00:00:00')
                OR j.datum BETWEEN CURDATE() AND CURDATE() + INTERVAL 1 DAY

            UNION DISTINCT

            SELECT j.persnr
                 , j.datum
              FROM tbl_ueb_fz_join j
             WHERE NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_buchungen_v2)

            UNION DISTINCT

            SELECT b.persnr
                 , b.datum
              FROM tbl_ueb_buchungen b
             WHERE b.datum BETWEEN COALESCE(@mindate2, CURDATE() - INTERVAL 1 DAY)
                               AND COALESCE(@maxdate2, CURDATE() + INTERVAL 1 DAY)

            UNION DISTINCT

            SELECT old_row.persnr
                 , old_row.datum
              FROM tbl_ueb_fz_buchungen_v2 old_row
             WHERE old_row.datum BETWEEN COALESCE(@mindate2, CURDATE() - INTERVAL 1 DAY)
                                     AND COALESCE(@maxdate2, CURDATE() + INTERVAL 1 DAY)

            UNION DISTINCT

            SELECT sp.persnr
                 , d.datum
              FROM tbl_stamm_persnr sp
              JOIN tbl_datum d ON d.datum > sp.uebernahme_am
                               AND d.datum BETWEEN CURDATE() - INTERVAL 1 DAY
                                               AND CURDATE() + INTERVAL 90 DAY
             WHERE sp.uebernahme_am >= CURDATE()

            UNION DISTINCT

            SELECT old_row.persnr
                 , old_row.datum
              FROM tbl_ueb_fz_buchungen_v2 old_row
              LEFT JOIN tbl_ueb_fz_join j ON j.persnr = old_row.persnr
                                         AND j.datum = old_row.datum
             WHERE old_row.datum BETWEEN CURDATE() - INTERVAL 1 DAY
                                     AND CURDATE() + INTERVAL 90 DAY
               AND j.persnr IS NULL
           ) candidates;

    ALTER TABLE tmp_fz_join_affected ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_virtual AS
    SELECT sp.persnr
         , d.datum
         , MAX(IF(d.arbeitstag = 1, '*', '')) COLLATE utf8mb4_unicode_ci AS virtual_fz
      FROM tbl_stamm_persnr sp
      JOIN tbl_datum d ON d.datum > sp.uebernahme_am
                       AND d.datum BETWEEN CURDATE() - INTERVAL 1 DAY
                                       AND CURDATE() + INTERVAL 90 DAY
      JOIN tmp_fz_join_affected a ON a.persnr = sp.persnr
                                  AND a.datum = d.datum
     WHERE sp.uebernahme_am >= CURDATE()
     GROUP BY sp.persnr
            , d.datum;

    ALTER TABLE tmp_fz_join_virtual ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_resolved_day AS
    WITH source_resolution AS (
    SELECT a.persnr
         , a.datum
         , j.pk_fz
         , j.pk_tp
         , j.pk_filedate
         , j.aend_fz
         , j.aend_tp
         , j.aend_filedate
         , j.bu_fz
         , j.bu_tp
         , j.bu_filedate
         , j.pa_fz
         , j.pa_taetigkeit
         , j.pa_oe
         , j.pa_schichtgr
         , j.pa_filedate
         , v.virtual_fz
         , COALESCE(p.schichtgruppe, j.pa_schichtgr) AS schichtgruppe
         , p.taetigkeit
         , d.arbeitstag
         , d.schichtindex
         , CASE WHEN j.aend_filedate >= GREATEST(COALESCE(j.pk_filedate, '1000-01-01 00:00:00'), COALESCE(j.bu_filedate, '1000-01-01 00:00:00'))
                     AND j.aend_fz IS NOT NULL
                THEN IF(j.aend_fz = 'KE-a', 'KE', j.aend_fz)
                WHEN j.bu_filedate >= COALESCE(j.pk_filedate, '1000-01-01 00:00:00')
                 AND j.bu_fz IS NOT NULL
                THEN j.bu_fz
                WHEN j.pk_filedate IS NOT NULL
                 AND j.pk_fz IS NOT NULL
                THEN j.pk_fz
                WHEN j.pa_filedate IS NOT NULL
                THEN j.pa_fz
                WHEN v.virtual_fz IS NOT NULL
                THEN v.virtual_fz
           END AS fz_raw
         , CASE WHEN j.aend_filedate >= GREATEST(COALESCE(j.pk_filedate, '1000-01-01 00:00:00'), COALESCE(j.bu_filedate, '1000-01-01 00:00:00'))
                     AND j.aend_tp IS NOT NULL
                THEN j.aend_tp
                WHEN j.bu_filedate >= COALESCE(j.pk_filedate, '1000-01-01 00:00:00')
                 AND j.bu_tp IS NOT NULL
                THEN j.bu_tp
                WHEN j.pk_filedate IS NOT NULL
                 AND j.pk_tp IS NOT NULL
                THEN j.pk_tp
           END AS tp_raw
         , CASE WHEN GREATEST(COALESCE(j.pk_filedate, '1000-01-01 00:00:00'), COALESCE(j.aend_filedate, '1000-01-01 00:00:00'), COALESCE(j.bu_filedate, '1000-01-01 00:00:00'), COALESCE(j.pa_filedate, '1000-01-01 00:00:00')) = '1000-01-01 00:00:00'
                THEN NULL
                ELSE GREATEST(COALESCE(j.pk_filedate, '1000-01-01 00:00:00'), COALESCE(j.aend_filedate, '1000-01-01 00:00:00'), COALESCE(j.bu_filedate, '1000-01-01 00:00:00'), COALESCE(j.pa_filedate, '1000-01-01 00:00:00'))
           END AS source_filedate
      FROM tmp_fz_join_affected a
      JOIN tbl_datum d ON d.datum = a.datum
      LEFT JOIN tbl_ueb_fz_join j ON j.persnr = a.persnr
                                 AND j.datum = a.datum
      LEFT JOIN tmp_fz_join_virtual v ON v.persnr = a.persnr
                                     AND v.datum = a.datum
      LEFT JOIN tbl_ueb_personalakte p ON p.persnr = a.persnr
      LEFT JOIN tbl_stamm_persnr sp ON sp.persnr = a.persnr
     WHERE d.datum BETWEEN COALESCE(p.beginn, '0000-01-01') AND COALESCE(p.ende, '9999-12-31')
        OR d.datum >= sp.uebernahme_am
    )

    SELECT r.persnr
         , r.datum
         , r.pk_fz
         , r.pk_tp
         , r.pk_filedate
         , r.aend_fz
         , r.aend_tp
         , r.aend_filedate
         , r.bu_fz
         , r.bu_tp
         , r.bu_filedate
         , r.pa_fz
         , r.pa_taetigkeit
         , r.pa_oe
         , r.pa_schichtgr
         , r.pa_filedate
         , r.schichtgruppe
         , r.taetigkeit
         , r.arbeitstag
         , r.schichtindex
         , r.fz_raw
         , r.tp_raw
         , CASE WHEN r.fz_raw = 'KE' AND r.aend_fz = 'KE-a'
                THEN 'KE-a'
                WHEN r.fz_raw = 'XXX'
                THEN ''
                ELSE r.fz_raw
           END COLLATE utf8mb4_unicode_ci AS fz_base
         , r.source_filedate
         , ag.anwesenheit AS absence_anwesenheit
         , ag.schicht AS absence_schicht
         , tp.anwesenheit AS tp_anwesenheit
         , tp.sollzeit AS tp_sollzeit
         , COALESCE(absence_shift.schicht_int, default_shift.schicht_int, 0) AS fallback_shift
      FROM source_resolution r
      LEFT JOIN (
                SELECT kuerzel
                     , MAX(anwesenheit) AS anwesenheit
                     , MAX(schicht) AS schicht
                  FROM tbl_abwesenheitsgrund
                 WHERE feld = 'fehlzeit'
                 GROUP BY kuerzel
                ) ag ON ag.kuerzel = r.fz_raw
      LEFT JOIN (
                SELECT kuerzel
                     , MAX(anwesenheit) AS anwesenheit
                     , MAX(sollzeit) AS sollzeit
                  FROM tbl_abwesenheitsgrund
                 WHERE feld = 'tagesplan'
                 GROUP BY kuerzel
                ) tp ON tp.kuerzel = r.tp_raw
      LEFT JOIN (
                SELECT schicht
                     , MIN(schicht_int) AS schicht_int
                  FROM tbl_schichten
                 WHERE `Index` <= 3
                 GROUP BY schicht
                ) absence_shift ON absence_shift.schicht = ag.schicht
      LEFT JOIN tbl_schichten default_shift ON default_shift.schichtgruppe = r.schichtgruppe
                                           AND default_shift.schichtindex = r.schichtindex;

    ALTER TABLE tmp_fz_join_resolved_day ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_tp_shift AS
    SELECT tp.tp COLLATE utf8mb4_unicode_ci AS tp
         , tp.tp_anwesenheit
         , COALESCE(tp.shift_int, IF(tp.schicht = 'Tag' AND tp.tp_anwesenheit = 'anw', 2, NULL)) AS schicht
         , MAX(tp.sollzeit) AS sollzeit
      FROM (
            SELECT a.kuerzel AS tp
                 , a.anwesenheit AS tp_anwesenheit
                 , shifts.schicht_int AS shift_int
                 , a.schicht
                 , a.sollzeit
              FROM tbl_abwesenheitsgrund a
              LEFT JOIN (
                        SELECT schicht
                             , MIN(schicht_int) AS schicht_int
                          FROM tbl_schichten
                         WHERE `Index` <= 3
                         GROUP BY schicht
                        ) shifts ON shifts.schicht = a.schicht
             WHERE a.feld = 'tagesplan'

            UNION ALL

            SELECT 'PV', 'anw', 3, 'Spät', CAST('16:30:00' AS TIME)

            UNION ALL

            SELECT 'S+N', 'anw', 3, 'Spät', CAST('16:30:00' AS TIME)
           ) tp
     GROUP BY tp.tp
            , tp.tp_anwesenheit
            , COALESCE(tp.shift_int, IF(tp.schicht = 'Tag' AND tp.tp_anwesenheit = 'anw', 2, NULL));

    ALTER TABLE tmp_fz_join_tp_shift ADD KEY ix_tmp_fz_join_tp_shift_tp (tp, schicht);

    CREATE TEMPORARY TABLE tmp_fz_join_expected_slots AS
    WITH expected_ranked AS (
    SELECT r.persnr
         , r.datum
         , tp.schicht
         , tp.sollzeit
         , ROW_NUMBER() OVER (PARTITION BY r.persnr, r.datum ORDER BY tp.schicht) AS slot
      FROM tmp_fz_join_resolved_day r
      JOIN tmp_fz_join_tp_shift tp ON tp.tp = r.tp_raw
                                  AND tp.tp_anwesenheit = 'anw'
                                  AND tp.schicht IS NOT NULL
    )

    SELECT r.persnr
         , r.datum
         , MAX(CASE WHEN e.slot = 1 THEN e.schicht END) AS expected_shift_1
         , MAX(CASE WHEN e.slot = 2 THEN e.schicht END) AS expected_shift_2
         , MAX(CASE WHEN e.slot = 1 THEN e.sollzeit END) AS expected_sollzeit_1
         , MAX(CASE WHEN e.slot = 2 THEN e.sollzeit END) AS expected_sollzeit_2
      FROM tmp_fz_join_resolved_day r
      LEFT JOIN expected_ranked e ON e.persnr = r.persnr
                                 AND e.datum = r.datum
     GROUP BY r.persnr
            , r.datum;

    ALTER TABLE tmp_fz_join_expected_slots ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_bookings AS
    SELECT b.persnr
         , b.datum
         , b.schicht
         , b.kommen
         , b.minuten
         , CASE WHEN b.minuten >= 120
                THEN '*'
                WHEN b.minuten BETWEEN 0 AND 119
                 AND k.kategorie = 'admin'
                 AND b.datum = CURDATE()
                THEN '*'
                WHEN b.minuten BETWEEN 1 AND 119
                THEN '*-'
                WHEN (b.minuten IS NULL OR b.minuten = 0)
                 AND b.kommen IS NOT NULL
                 AND b.datum = CURDATE()
                THEN '*!'
                ELSE '*-'
           END AS buchung_status
         , b.filedate
      FROM tbl_ueb_buchungen_2 b
      JOIN tmp_fz_join_affected a ON a.persnr = b.persnr
                                 AND a.datum = b.datum
      LEFT JOIN tbl_ueb_personalakte p ON p.persnr = b.persnr
      LEFT JOIN tbl_stamm_kategorie_abteilung k ON k.`tätigkeit` = p.taetigkeit

    UNION ALL

    SELECT b.persnr
         , b.datum
         , COALESCE(shifts.schicht_int, 0) AS schicht
         , b.kommen
         , b.minuten
         , CASE WHEN b.minuten >= 120
                THEN '*'
                WHEN b.minuten BETWEEN 0 AND 119
                 AND k.kategorie = 'admin'
                 AND b.datum = CURDATE()
                THEN '*'
                WHEN b.minuten BETWEEN 1 AND 119
                THEN '*-'
                WHEN (b.minuten IS NULL OR b.minuten = 0)
                 AND b.kommen IS NOT NULL
                 AND b.datum = CURDATE()
                THEN '*!'
                ELSE '*-'
           END AS buchung_status
         , b.filedate
      FROM tbl_ueb_buchungen b
      JOIN tmp_fz_join_affected a ON a.persnr = b.persnr
                                 AND a.datum = b.datum
      LEFT JOIN (
                SELECT schicht
                     , MIN(schicht_int) AS schicht_int
                  FROM tbl_schichten
                 WHERE `Index` <= 3
                 GROUP BY schicht
                ) shifts ON shifts.schicht = b.schicht
      LEFT JOIN tbl_ueb_buchungen_2 recent ON recent.persnr = b.persnr
                                          AND recent.datum = b.datum
                                          AND recent.schicht = COALESCE(shifts.schicht_int, 0)
      LEFT JOIN tbl_ueb_personalakte p ON p.persnr = b.persnr
      LEFT JOIN tbl_stamm_kategorie_abteilung k ON k.`tätigkeit` = p.taetigkeit
     WHERE b.bg = 'Ko'
       AND recent.persnr IS NULL;

    ALTER TABLE tmp_fz_join_bookings ADD PRIMARY KEY (persnr, datum, schicht);

    CREATE TEMPORARY TABLE tmp_fz_join_actual_slots AS
    WITH actual_ranked AS (
    SELECT b.persnr
         , b.datum
         , b.schicht
         , ROW_NUMBER() OVER (PARTITION BY b.persnr, b.datum ORDER BY b.kommen, b.schicht, b.filedate) AS slot
      FROM tmp_fz_join_bookings b
    )

    SELECT r.persnr
         , r.datum
         , MAX(CASE WHEN b.slot = 1 THEN b.schicht END) AS actual_shift_1
         , MAX(CASE WHEN b.slot = 2 THEN b.schicht END) AS actual_shift_2
      FROM tmp_fz_join_resolved_day r
      LEFT JOIN actual_ranked b ON b.persnr = r.persnr
                               AND b.datum = r.datum
     GROUP BY r.persnr
            , r.datum;

    ALTER TABLE tmp_fz_join_actual_slots ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_day_slots AS
    SELECT r.*
         , e.expected_shift_1
         , e.expected_shift_2
         , e.expected_sollzeit_1
         , e.expected_sollzeit_2
         , a.actual_shift_1
         , a.actual_shift_2
      FROM tmp_fz_join_resolved_day r
      LEFT JOIN tmp_fz_join_expected_slots e ON e.persnr = r.persnr
                                            AND e.datum = r.datum
      LEFT JOIN tmp_fz_join_actual_slots a ON a.persnr = r.persnr
                                          AND a.datum = r.datum;

    ALTER TABLE tmp_fz_join_day_slots ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_exact_matches AS
    SELECT d.*
         , CASE WHEN d.actual_shift_1 = d.expected_shift_1 THEN d.expected_shift_1
                WHEN d.actual_shift_1 = d.expected_shift_2 THEN d.expected_shift_2
           END AS exact_expected_1
         , CASE WHEN d.actual_shift_2 = d.expected_shift_1
                     AND NOT (d.actual_shift_1 <=> d.expected_shift_1)
                THEN d.expected_shift_1
                WHEN d.actual_shift_2 = d.expected_shift_2
                     AND NOT (d.actual_shift_1 <=> d.expected_shift_2)
                THEN d.expected_shift_2
           END AS exact_expected_2
      FROM tmp_fz_join_day_slots d;

    ALTER TABLE tmp_fz_join_exact_matches ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_remaining_expected AS
    SELECT e.*
         , CASE WHEN e.expected_shift_1 IS NOT NULL
                     AND NOT (e.expected_shift_1 <=> e.exact_expected_1)
                     AND NOT (e.expected_shift_1 <=> e.exact_expected_2)
                THEN e.expected_shift_1
                WHEN e.expected_shift_2 IS NOT NULL
                     AND NOT (e.expected_shift_2 <=> e.exact_expected_1)
                     AND NOT (e.expected_shift_2 <=> e.exact_expected_2)
                THEN e.expected_shift_2
           END AS remaining_expected_1
         , CASE WHEN e.expected_shift_1 IS NOT NULL
                     AND e.expected_shift_2 IS NOT NULL
                     AND NOT (e.expected_shift_1 <=> e.exact_expected_1)
                     AND NOT (e.expected_shift_1 <=> e.exact_expected_2)
                     AND NOT (e.expected_shift_2 <=> e.exact_expected_1)
                     AND NOT (e.expected_shift_2 <=> e.exact_expected_2)
                THEN e.expected_shift_2
           END AS remaining_expected_2
      FROM tmp_fz_join_exact_matches e;

    ALTER TABLE tmp_fz_join_remaining_expected ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_assignments AS
    SELECT e.*
         , CASE WHEN e.actual_shift_1 IS NULL THEN NULL
                ELSE COALESCE(e.exact_expected_1, e.remaining_expected_1)
           END AS matched_expected_1
         , CASE WHEN e.actual_shift_2 IS NULL THEN NULL
                ELSE COALESCE(e.exact_expected_2,
                              CASE WHEN e.actual_shift_1 IS NOT NULL
                                     AND e.exact_expected_1 IS NULL
                                   THEN e.remaining_expected_2
                                   ELSE e.remaining_expected_1
                               END)
           END AS matched_expected_2
      FROM tmp_fz_join_remaining_expected e;

    ALTER TABLE tmp_fz_join_assignments ADD PRIMARY KEY (persnr, datum);

    CREATE TEMPORARY TABLE tmp_fz_join_shift_rows AS
    SELECT a.persnr
         , a.datum
         , a.fz_raw
         , a.fz_base
         , a.aend_fz
         , a.tp_raw
         , a.source_filedate
         , a.schichtgruppe
         , a.arbeitstag
         , a.absence_anwesenheit
         , a.tp_anwesenheit
         , a.tp_sollzeit
         , a.fallback_shift
         , a.actual_shift_1 AS actual_shift
         , a.matched_expected_1 AS expected_shift
         , CASE WHEN a.matched_expected_1 = a.expected_shift_1 THEN a.expected_sollzeit_1
                WHEN a.matched_expected_1 = a.expected_shift_2 THEN a.expected_sollzeit_2
           END AS expected_sollzeit
         , a.actual_shift_1 AS schicht
         , 1 AS actual_slot
      FROM tmp_fz_join_assignments a
     WHERE a.actual_shift_1 IS NOT NULL

    UNION ALL

    SELECT a.persnr
         , a.datum
         , a.fz_raw
         , a.fz_base
         , a.aend_fz
         , a.tp_raw
         , a.source_filedate
         , a.schichtgruppe
         , a.arbeitstag
         , a.absence_anwesenheit
         , a.tp_anwesenheit
         , a.tp_sollzeit
         , a.fallback_shift
         , a.actual_shift_2 AS actual_shift
         , a.matched_expected_2 AS expected_shift
         , CASE WHEN a.matched_expected_2 = a.expected_shift_1 THEN a.expected_sollzeit_1
                WHEN a.matched_expected_2 = a.expected_shift_2 THEN a.expected_sollzeit_2
           END AS expected_sollzeit
         , a.actual_shift_2 AS schicht
         , 2 AS actual_slot
      FROM tmp_fz_join_assignments a
     WHERE a.actual_shift_2 IS NOT NULL

    UNION ALL

    SELECT a.persnr
         , a.datum
         , a.fz_raw
         , a.fz_base
         , a.aend_fz
         , a.tp_raw
         , a.source_filedate
         , a.schichtgruppe
         , a.arbeitstag
         , a.absence_anwesenheit
         , a.tp_anwesenheit
         , a.tp_sollzeit
         , a.fallback_shift
         , NULL AS actual_shift
         , a.expected_shift_1 AS expected_shift
         , a.expected_sollzeit_1 AS expected_sollzeit
         , a.expected_shift_1 AS schicht
         , 0 AS actual_slot
      FROM tmp_fz_join_assignments a
     WHERE a.expected_shift_1 IS NOT NULL
       AND NOT (a.expected_shift_1 <=> a.matched_expected_1)
       AND NOT (a.expected_shift_1 <=> a.matched_expected_2)

    UNION ALL

    SELECT a.persnr
         , a.datum
         , a.fz_raw
         , a.fz_base
         , a.aend_fz
         , a.tp_raw
         , a.source_filedate
         , a.schichtgruppe
         , a.arbeitstag
         , a.absence_anwesenheit
         , a.tp_anwesenheit
         , a.tp_sollzeit
         , a.fallback_shift
         , NULL AS actual_shift
         , a.expected_shift_2 AS expected_shift
         , a.expected_sollzeit_2 AS expected_sollzeit
         , a.expected_shift_2 AS schicht
         , 0 AS actual_slot
      FROM tmp_fz_join_assignments a
     WHERE a.expected_shift_2 IS NOT NULL
       AND NOT (a.expected_shift_2 <=> a.matched_expected_1)
       AND NOT (a.expected_shift_2 <=> a.matched_expected_2)

    UNION ALL

    SELECT a.persnr
         , a.datum
         , a.fz_raw
         , a.fz_base
         , a.aend_fz
         , a.tp_raw
         , a.source_filedate
         , a.schichtgruppe
         , a.arbeitstag
         , a.absence_anwesenheit
         , a.tp_anwesenheit
         , a.tp_sollzeit
         , a.fallback_shift
         , NULL AS actual_shift
         , NULL AS expected_shift
         , NULL AS expected_sollzeit
         , a.fallback_shift AS schicht
         , 0 AS actual_slot
      FROM tmp_fz_join_assignments a
     WHERE a.actual_shift_1 IS NULL
       AND a.actual_shift_2 IS NULL
       AND a.expected_shift_1 IS NULL
       AND a.expected_shift_2 IS NULL
       AND NOT (a.fz_raw <=> 'XXX' AND a.tp_raw IS NULL);

    CREATE TEMPORARY TABLE tmp_fz_join_output AS
    WITH output_base AS (
    SELECT r.persnr
         , r.datum
         , CASE WHEN r.actual_shift IS NOT NULL
                     AND r.fz_base = 'WEG'
                THEN 'WEG'
                WHEN r.actual_shift IS NOT NULL
                     AND r.absence_anwesenheit IS NOT NULL
                     AND r.absence_anwesenheit NOT IN ('anw', 'Frei')
                     AND (a.expected_shift_1 IS NULL OR a.expected_shift_1 = a.matched_expected_1 OR a.expected_shift_1 = a.matched_expected_2)
                     AND (a.expected_shift_2 IS NULL OR a.expected_shift_2 = a.matched_expected_1 OR a.expected_shift_2 = a.matched_expected_2)
                THEN '*&'
                WHEN r.actual_shift IS NOT NULL
                THEN b.buchung_status
                WHEN MONTH(r.datum) = 12
                 AND DAY(r.datum) IN (24, 31)
                THEN 'H/S'
                WHEN r.tp_anwesenheit = 'anw'
                 AND r.expected_shift IS NOT NULL
                 AND (r.expected_shift = 1 OR COALESCE(r.expected_sollzeit, r.tp_sollzeit) IS NOT NULL)
                 AND ((r.expected_shift = 1 AND r.datum BETWEEN CURDATE() AND CURDATE() + INTERVAL 1 DAY)
                   OR (r.expected_shift <> 1 AND r.datum = CURDATE()))
                 AND NOW() >= TIMESTAMP(CASE WHEN r.expected_shift = 1 THEN r.datum - INTERVAL 1 DAY ELSE r.datum END,
                                         CASE WHEN r.expected_shift = 1 THEN '22:00:00' ELSE COALESCE(r.expected_sollzeit, r.tp_sollzeit, '00:00:00') END)
                THEN '~'
                WHEN r.arbeitstag = 0
                 AND r.absence_anwesenheit IS NOT NULL
                 AND r.absence_anwesenheit NOT IN ('anw', 'Frei')
                THEN ''
                WHEN r.fz_base IS NOT NULL
                 AND r.fz_base <> ''
                THEN r.fz_base
                WHEN r.tp_anwesenheit = 'anw'
                THEN '*'
                ELSE ''
           END COLLATE utf8mb4_unicode_ci AS status
         , COALESCE(r.schichtgruppe, '') AS schichtgruppe
         , CASE WHEN (r.fz_base IS NULL OR r.fz_base <> 'WEG')
                  AND b.buchung_status IN ('*', '*!', '*-', '*&')
                THEN b.kommen
           END AS kommen
         , r.schicht
         , COALESCE(b.minuten, 0) AS minuten
         , r.tp_raw AS tp
         , NOW() AS last_insert_update
         , CASE WHEN GREATEST(COALESCE(r.source_filedate, '1000-01-01 00:00:00'), COALESCE(b.filedate, '1000-01-01 00:00:00')) = '1000-01-01 00:00:00'
                THEN NULL
                ELSE GREATEST(COALESCE(r.source_filedate, '1000-01-01 00:00:00'), COALESCE(b.filedate, '1000-01-01 00:00:00'))
           END AS filedate
      FROM tmp_fz_join_shift_rows r
      LEFT JOIN tmp_fz_join_bookings b ON b.persnr = r.persnr
                                      AND b.datum = r.datum
                                      AND b.schicht = r.actual_shift
      LEFT JOIN tmp_fz_join_assignments a ON a.persnr = r.persnr
                                         AND a.datum = r.datum
    )

    SELECT o.persnr
         , o.datum
         , o.status
         , o.schichtgruppe
         , o.kommen
         , o.schicht
         , o.minuten
         , COALESCE(status_group.anwesenheit, 'Frei') AS anwesenheit
         , o.tp
         , o.last_insert_update
         , o.filedate
      FROM output_base o
      LEFT JOIN (
                SELECT kuerzel
                     , MAX(anwesenheit) AS anwesenheit
                  FROM tbl_abwesenheitsgrund
                 WHERE feld = 'fehlzeit'
                 GROUP BY kuerzel
                ) status_group ON status_group.kuerzel = o.status;

    ALTER TABLE tmp_fz_join_output ADD PRIMARY KEY (persnr, datum, schicht);

    INSERT INTO tbl_ueb_fz_buchungen_v2 (persnr, datum, status, schichtgruppe, kommen, schicht, minuten, anwesenheit, tp, last_insert_update, filedate)
    SELECT persnr
         , datum
         , status
         , schichtgruppe
         , kommen
         , schicht
         , minuten
         , anwesenheit
         , tp
         , last_insert_update
         , filedate
      FROM tmp_fz_join_output
    ON DUPLICATE KEY UPDATE
          status = VALUES(status)
        , schichtgruppe = VALUES(schichtgruppe)
        , kommen = VALUES(kommen)
        , minuten = VALUES(minuten)
        , anwesenheit = VALUES(anwesenheit)
        , tp = VALUES(tp)
        , filedate = VALUES(filedate)
        , last_insert_update = IF(    NOT (tbl_ueb_fz_buchungen_v2.status <=> VALUES(status))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.schichtgruppe <=> VALUES(schichtgruppe))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.kommen <=> VALUES(kommen))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.minuten <=> VALUES(minuten))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.anwesenheit <=> VALUES(anwesenheit))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.tp <=> VALUES(tp))
                                   OR NOT (tbl_ueb_fz_buchungen_v2.filedate <=> VALUES(filedate))
                                 , NOW()
                                 , tbl_ueb_fz_buchungen_v2.last_insert_update
                                 );

    DELETE existing_row
      FROM tbl_ueb_fz_buchungen_v2 existing_row
      JOIN tmp_fz_join_affected a ON a.persnr = existing_row.persnr
                                 AND a.datum = existing_row.datum
      LEFT JOIN tmp_fz_join_output current_row ON current_row.persnr = existing_row.persnr
                                              AND current_row.datum = existing_row.datum
                                              AND current_row.schicht = existing_row.schicht
     WHERE current_row.persnr IS NULL;

    UPDATE tbl_ueb_fz_join j
    JOIN tmp_fz_join_affected a ON a.persnr = j.persnr
                               AND a.datum = j.datum
       SET j.last_calculated = COALESCE(j.last_insert_update, NOW());

    CALL schreibe_log('proc_ueb_fz_join', 'ende', ROW_COUNT());

    DROP TEMPORARY TABLE tmp_fz_join_output;
    DROP TEMPORARY TABLE tmp_fz_join_shift_rows;
    DROP TEMPORARY TABLE tmp_fz_join_assignments;
    DROP TEMPORARY TABLE tmp_fz_join_remaining_expected;
    DROP TEMPORARY TABLE tmp_fz_join_exact_matches;
    DROP TEMPORARY TABLE tmp_fz_join_day_slots;
    DROP TEMPORARY TABLE tmp_fz_join_actual_slots;
    DROP TEMPORARY TABLE tmp_fz_join_bookings;
    DROP TEMPORARY TABLE tmp_fz_join_expected_slots;
    DROP TEMPORARY TABLE tmp_fz_join_tp_shift;
    DROP TEMPORARY TABLE tmp_fz_join_resolved_day;
    DROP TEMPORARY TABLE tmp_fz_join_virtual;
    DROP TEMPORARY TABLE tmp_fz_join_affected;
END//
