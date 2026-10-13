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

    SELECT persnr
         , datum
         , fz_raw
         , tp_raw
         , winner
      FROM resolved_day;

    ALTER TABLE tmp_ueb_fz_join_reconcile ADD PRIMARY KEY (persnr, datum);

    UPDATE tbl_ueb_fz_join j
    JOIN tmp_ueb_fz_join_reconcile r
      ON r.persnr = j.persnr
     AND r.datum = j.datum
       SET j.fz_raw = r.fz_raw
         , j.tp_raw = r.tp_raw
         , j.winner = r.winner
         , j.last_calculated = j.last_insert_update;

    CALL schreibe_log('proc_ueb_fz_join_reconcile', 'ende', ROW_COUNT());

    DROP TEMPORARY TABLE tmp_ueb_fz_join_reconcile;
END//
