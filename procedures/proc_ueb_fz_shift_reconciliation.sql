-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_shift_reconciliation.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_shift_reconciliation`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_shift_reconciliation`(IN `mindate` date, IN `maxdate` date)
SQL SECURITY DEFINER BEGIN

    WITH tp_shift_detail AS (
    SELECT DISTINCT a.kuerzel AS tp
         , a.anwesenheit AS tp_anwesenheit
         , IFNULL(s.schicht_int, 2) AS expected_shift
         , a.sollzeit
      FROM tbl_abwesenheitsgrund a
      LEFT JOIN tbl_schichten s ON a.schicht = s.schicht
                               AND s.schichtindex <= 3
     WHERE LOWER(a.feld) = 'tagesplan'

    UNION ALL

    SELECT 'PV'
         , 'anw'
         , 3
         , TIME('16:30:00')

    UNION ALL

    SELECT 'S+N'
         , 'anw'
         , 3
         , TIME('16:30:00')
    )

    , day_rows AS (
    SELECT j.persnr
         , j.datum
         , j.fz_raw
         , j.tp_raw
         , j.expected_mask
         , j.actual_shift_1
         , j.actual_shift_2
         , j.matched_expected_1
         , j.matched_expected_2
         , j.remaining_expected_mask
         , j.shift_mismatch_1
         , j.shift_mismatch_2
      FROM tbl_ueb_fz_join j
     WHERE j.datum BETWEEN mindate AND maxdate
    )

    , expanded_rows AS (
    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.expected_mask
         , d.remaining_expected_mask
         , d.actual_shift_1 AS resolved_shift
         , d.matched_expected_1 AS expected_shift
         , d.actual_shift_1 AS actual_shift
         , d.shift_mismatch_1 AS shift_mismatch
      FROM day_rows d
     WHERE d.actual_shift_1 IS NOT NULL

    UNION ALL

    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.expected_mask
         , d.remaining_expected_mask
         , d.actual_shift_2
         , d.matched_expected_2
         , d.actual_shift_2
         , d.shift_mismatch_2
      FROM day_rows d
     WHERE d.actual_shift_2 IS NOT NULL

    UNION ALL

    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.expected_mask
         , d.remaining_expected_mask
         , 1
         , 1
         , NULL
         , 0
      FROM day_rows d
     WHERE (d.remaining_expected_mask & 4) <> 0

    UNION ALL

    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.expected_mask
         , d.remaining_expected_mask
         , 2
         , 2
         , NULL
         , 0
      FROM day_rows d
     WHERE (d.remaining_expected_mask & 2) <> 0

    UNION ALL

    SELECT d.persnr
         , d.datum
         , d.fz_raw
         , d.tp_raw
         , d.expected_mask
         , d.remaining_expected_mask
         , 3
         , 3
         , NULL
         , 0
      FROM day_rows d
     WHERE (d.remaining_expected_mask & 1) <> 0
    )

    SELECT e.persnr
         , e.datum
         , e.fz_raw
         , e.tp_raw AS tp
         , e.expected_mask
         , e.expected_shift
         , e.actual_shift
         , e.resolved_shift AS schicht
         , e.shift_mismatch
         , t.tp_anwesenheit
         , t.sollzeit AS tp_sollzeit
         , b.kommen
         , b.minuten
         , b.buchung_status
         , b.filedate
      FROM expanded_rows e
      LEFT JOIN tp_shift_detail t ON t.tp = e.tp_raw
                                 AND t.expected_shift = e.expected_shift
      LEFT JOIN tbl_ueb_buchungen_2 b ON b.persnr = e.persnr
                                     AND b.datum = e.datum
                                     AND b.schicht = e.actual_shift
     ORDER BY e.persnr
            , e.datum
            , e.resolved_shift
    ;
END//
