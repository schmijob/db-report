-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_join.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_join`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_join`()
SQL SECURITY DEFINER BEGIN

    DROP TEMPORARY TABLE IF EXISTS tmp_ueb_fz_join_reconcile;

    CREATE TEMPORARY TABLE tmp_ueb_fz_join_reconcile AS
    WITH resolved_day AS (
    SELECT j.persnr
         , j.datum
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
         , j.last_insert_update
         , j.last_calculated
         , j.actual_shift_1
         , j.actual_shift_2
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
           END AS fz_raw
         , CASE WHEN j.aend_filedate >= GREATEST(COALESCE(j.pk_filedate, '1000-01-01 00:00:00'), COALESCE(j.bu_filedate, '1000-01-01 00:00:00'))
                     AND (j.aend_fz IS NOT NULL OR j.aend_tp IS NOT NULL)
                THEN 'aend'
                WHEN j.bu_filedate >= COALESCE(j.pk_filedate, '1000-01-01 00:00:00')
                 AND (j.bu_fz IS NOT NULL OR j.bu_tp IS NOT NULL)
                THEN 'bu'
                WHEN j.pk_filedate IS NOT NULL
                 AND (j.pk_fz IS NOT NULL OR j.pk_tp IS NOT NULL)
                THEN 'pk'
                WHEN j.pa_filedate IS NOT NULL
                THEN 'pa'
           END AS winner
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
      FROM tbl_ueb_fz_join j
     WHERE j.last_insert_update > COALESCE(j.last_calculated, '1000-01-01 00:00:00')
    )

    , tp_shift_detail AS (
    SELECT DISTINCT a.kuerzel AS tp
         , a.anwesenheit AS tp_anwesenheit
         , CASE IFNULL(s.schicht_int, 2)
                WHEN 1 THEN 4
                WHEN 2 THEN 2
                WHEN 3 THEN 1
           END AS expected_shift_bit
         , a.sollzeit
      FROM tbl_abwesenheitsgrund a
      LEFT JOIN tbl_schichten s ON a.schicht = s.schicht
                               AND s.schichtindex <= 3
     WHERE LOWER(a.feld) = 'tagesplan'

    UNION ALL

    SELECT 'PV'
         , 'anw'
         , 1
         , TIME('16:30:00')

    UNION ALL

    SELECT 'S+N'
         , 'anw'
         , 1
         , TIME('16:30:00')
    )

    , tp_expanded AS (
    SELECT tp
         , MAX(tp_anwesenheit) AS tp_anwesenheit
         , CAST(BIT_OR(expected_shift_bit) AS UNSIGNED) AS expected_mask
         , MAX(CASE WHEN expected_shift_bit = 4 THEN sollzeit END) AS nacht_sollzeit
         , MAX(CASE WHEN expected_shift_bit = 2 THEN sollzeit END) AS frueh_sollzeit
         , MAX(CASE WHEN expected_shift_bit = 1 THEN sollzeit END) AS spaet_sollzeit
      FROM tp_shift_detail
     GROUP BY tp
    )

    , day_stage AS (
    SELECT r.persnr
         , r.datum
         , r.fz_raw
         , r.tp_raw
         , r.winner
         , COALESCE(t.expected_mask, 0) AS expected_mask
         , r.actual_shift_1
         , r.actual_shift_2
      FROM resolved_day r
      LEFT JOIN tp_expanded t ON t.tp = r.tp_raw
    )

    , actual_bits AS (
    SELECT d.*
         , CASE d.actual_shift_1
                WHEN 1 THEN 4
                WHEN 2 THEN 2
                WHEN 3 THEN 1
                ELSE 0
           END AS actual_bit_1
         , CASE d.actual_shift_2
                WHEN 1 THEN 4
                WHEN 2 THEN 2
                WHEN 3 THEN 1
                ELSE 0
           END AS actual_bit_2
      FROM day_stage d
    )

    , exact_matches AS (
    SELECT d.*
         , CASE WHEN d.actual_shift_1 IS NOT NULL
                     AND (d.expected_mask & d.actual_bit_1) <> 0
                THEN d.actual_bit_1
                ELSE 0
           END AS exact_bit_1
         , CASE WHEN d.actual_shift_2 IS NOT NULL
                     AND NOT (d.actual_shift_2 <=> d.actual_shift_1)
                     AND (d.expected_mask & d.actual_bit_2) <> 0
                THEN d.actual_bit_2
                ELSE 0
           END AS exact_bit_2
      FROM actual_bits d
    )

    , after_exact AS (
    SELECT e.*
         , e.expected_mask ^ (e.exact_bit_1 | e.exact_bit_2) AS remaining_after_exact_mask
      FROM exact_matches e
    )

    , matched_first AS (
    SELECT e.*
         , CASE WHEN e.actual_shift_1 IS NULL
                THEN NULL
                WHEN e.exact_bit_1 <> 0
                THEN e.actual_shift_1
                WHEN (e.remaining_after_exact_mask & 4) <> 0
                THEN 1
                WHEN (e.remaining_after_exact_mask & 2) <> 0
                THEN 2
                WHEN (e.remaining_after_exact_mask & 1) <> 0
                THEN 3
           END AS matched_expected_1
      FROM after_exact e
    )

    , after_first AS (
    SELECT f.*
         , f.remaining_after_exact_mask ^ CASE WHEN f.exact_bit_1 <> 0
                                               THEN 0
                                               WHEN f.matched_expected_1 = 1
                                               THEN 4
                                               WHEN f.matched_expected_1 = 2
                                               THEN 2
                                               WHEN f.matched_expected_1 = 3
                                               THEN 1
                                               ELSE 0
                                          END AS remaining_after_first_mask
      FROM matched_first f
    )

    , matched_day AS (
    SELECT f.persnr
         , f.datum
         , f.fz_raw
         , f.tp_raw
         , f.winner
         , f.expected_mask
         , f.actual_shift_1
         , f.actual_shift_2
         , f.matched_expected_1
         , CASE WHEN f.actual_shift_2 IS NULL
                THEN NULL
                WHEN f.exact_bit_2 <> 0
                THEN f.actual_shift_2
                WHEN (f.remaining_after_first_mask & 4) <> 0
                THEN 1
                WHEN (f.remaining_after_first_mask & 2) <> 0
                THEN 2
                WHEN (f.remaining_after_first_mask & 1) <> 0
                THEN 3
           END AS matched_expected_2
         , f.remaining_after_first_mask
         , f.exact_bit_2
      FROM after_first f
    )

    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.winner
         , d.expected_mask
         , d.actual_shift_1
         , d.actual_shift_2
         , d.matched_expected_1
         , d.matched_expected_2
         , d.remaining_after_first_mask ^ CASE WHEN d.exact_bit_2 <> 0
                                               THEN 0
                                               WHEN d.matched_expected_2 = 1
                                               THEN 4
                                               WHEN d.matched_expected_2 = 2
                                               THEN 2
                                               WHEN d.matched_expected_2 = 3
                                               THEN 1
                                               ELSE 0
                                          END AS remaining_expected_mask
         , IF(d.actual_shift_1 IS NOT NULL
              AND d.matched_expected_1 IS NOT NULL
              AND d.actual_shift_1 <> d.matched_expected_1, 1, 0) AS shift_mismatch_1
         , IF(d.actual_shift_2 IS NOT NULL
              AND d.matched_expected_2 IS NOT NULL
              AND d.actual_shift_2 <> d.matched_expected_2, 1, 0) AS shift_mismatch_2
      FROM matched_day d;

    ALTER TABLE tmp_ueb_fz_join_reconcile ADD PRIMARY KEY (persnr, datum);

    UPDATE tbl_ueb_fz_join j
    JOIN tmp_ueb_fz_join_reconcile r
      ON r.persnr = j.persnr
     AND r.datum = j.datum
       SET j.fz_raw = r.fz_raw
         , j.tp_raw = r.tp_raw
         , j.winner = r.winner
         , j.expected_mask = r.expected_mask
         , j.actual_shift_1 = r.actual_shift_1
         , j.actual_shift_2 = r.actual_shift_2
         , j.matched_expected_1 = r.matched_expected_1
         , j.matched_expected_2 = r.matched_expected_2
         , j.remaining_expected_mask = r.remaining_expected_mask
         , j.shift_mismatch_1 = r.shift_mismatch_1
         , j.shift_mismatch_2 = r.shift_mismatch_2
         , j.last_calculated = j.last_insert_update;

    CALL schreibe_log('proc_ueb_fz_join', 'shift reconciliation ende', ROW_COUNT());

    DROP TEMPORARY TABLE tmp_ueb_fz_join_reconcile;
END//
