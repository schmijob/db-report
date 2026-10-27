-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_peko.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_peko`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_peko`()
SQL SECURITY DEFINER BEGIN

    TRUNCATE tbl_ueb_peko;

    INSERT INTO tbl_ueb_peko (
          ord
        , metric
        , prev_week
        , curr_week
        , next_week
    )

WITH params AS (
    SELECT
        CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY - INTERVAL 7 DAY AS curr_monday,
        CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY - INTERVAL 14 DAY AS prev_monday,
        CURDATE() - INTERVAL WEEKDAY(CURDATE()) DAY AS next_monday
),

date_range AS (
    SELECT d.datum
    FROM tbl_datum d
    CROSS JOIN params p
    WHERE d.arbeitstag = 1
      AND d.datum BETWEEN p.prev_monday
                      AND p.next_monday + INTERVAL 4 DAY
),

fanf AS (
    SELECT
        f.datum,

        SUM(
            f.beauftragung *
            (
                f.tätigkeit IN (
                    'Lagerhelfer',
                    'Pausenvertretung',
                    'Staplerfahrer',
                    'QS',
                    'Kitting',
                    'Teamleiter',
                    'Trainer',
                    'Leitstand'
                )
            )
        ) AS bc_beauftragung,
        
                SUM(
            f.beauftragung *
            (
                f.oe IN ('PRD', 'Leitstand', 'Trainer')
                AND f.tätigkeit NOT IN (
                    'Schichtleiter',
                    'Trainingskoordinator',
                    'Qualifizierungskoordinator'
                )
            )
        ) AS soll_prd_ls_trainer,

        SUM(
            f.beauftragung *
            (
                f.oe = 'QS'
                AND f.tätigkeit NOT IN (
                    'Schichtleiter',
                    'Trainingskoordinator',
                    'Qualifizierungskoordinator'
                )
            )
        ) AS soll_qs,

        SUM(
            f.beauftragung *
            (
                f.oe IN ('WA', 'WE', 'BGL')
                AND f.tätigkeit NOT IN (
                    'Schichtleiter',
                    'Trainingskoordinator',
                    'Qualifizierungskoordinator'
                )
            )
        ) AS soll_wa_we_bgl,

        SUM(
            f.beauftragung *
            (
                f.tätigkeit IN (
                    'Schichtleiter',
                    'Trainingskoordinator',
                    'Qualifizierungskoordinator'
                ) OR f.oe = 'admin'
            )
        ) AS soll_admin_sl


    FROM tbl_uebertrag_fanf f
    JOIN date_range d
      ON d.datum = f.datum

    GROUP BY f.datum
),

base AS (
    SELECT
        b.datum,
        YEARWEEK(b.datum, 3) AS iso_week,

        b.persnr,
        b.anwesenheit,
        b.status,

        p.eg,
        p.oe,
        k.kategorie,

        p.oe AS effective_oe,
        p.taetigkeit AS effective_taetigkeit,

        CASE
            WHEN k.kategorie = 'Operativ'
              OR p.taetigkeit IN (
                    'Teamleiter',
                    'Trainer',
                    'Leitstand'
                 )
            THEN 1
            ELSE 0
        END AS is_bc

    FROM tbl_ueb_fz_buchungen b

    JOIN date_range d
      ON d.datum = b.datum

    LEFT JOIN tbl_ueb_personalakte_scd p
           ON p.persnr = b.persnr
          AND b.datum BETWEEN p.gueltig_von AND p.gueltig_bis

    LEFT JOIN tbl_stamm_kategorie_abteilung k
           ON k.tätigkeit = p.taetigkeit

    WHERE p.oe <> 'Extern' AND k.kategorie <> 'Overhead (AT)'
),

daily_metrics AS (
    SELECT
        b.datum,
        b.iso_week,

        -- WC AOR
        COUNT(DISTINCT CASE
            WHEN b.is_bc = 0
            THEN b.persnr
        END) AS wc_aor,

        -- WC vacation
        COUNT(DISTINCT CASE
            WHEN b.is_bc = 0
             AND b.anwesenheit = 'URL'
            THEN b.persnr
        END) AS wc_vacation,

        -- WC sickness
        COUNT(DISTINCT CASE
            WHEN b.is_bc = 0
             AND b.anwesenheit = 'Lfz'
            THEN b.persnr
        END) AS wc_sickness,

        -- WC other
        COUNT(DISTINCT CASE
            WHEN b.is_bc = 0
             AND b.anwesenheit IN ('sonst.', 'oLfz')
             AND b.status NOT IN ('kk','FZA','FM','GZS')
            THEN b.persnr
        END) AS wc_other,

        -- BC AOR
        COUNT(DISTINCT CASE
            WHEN b.eg <> 'ZAK'
             AND b.is_bc = 1
            THEN b.persnr
        END) AS bc_aor,

        -- BC vacation
        COUNT(DISTINCT CASE
            WHEN b.eg <> 'ZAK'
             AND b.is_bc = 1
             AND b.anwesenheit = 'URL'
            THEN b.persnr
        END) AS bc_vacation,

        -- BC sickness
        COUNT(DISTINCT CASE
            WHEN b.eg <> 'ZAK'
             AND b.is_bc = 1
             AND b.anwesenheit = 'Lfz'
            THEN b.persnr
        END) AS bc_sickness,

        -- BC other
        COUNT(DISTINCT CASE
            WHEN b.eg <> 'ZAK'
             AND b.is_bc = 1
             AND b.anwesenheit IN ('sonst.', 'oLfz')
             AND b.status NOT IN ('kk','FZA','FM','GZS')
            THEN b.persnr
        END) AS bc_other,

        -- Temp pool total
        COUNT(DISTINCT CASE
            WHEN b.eg = 'ZAK'
            THEN b.persnr
        END) AS temp_pool_total,

        -- Temp absence
        COUNT(DISTINCT CASE
            WHEN b.eg = 'ZAK'
             AND b.anwesenheit <> 'anw'
            THEN b.persnr
        END) AS temp_absence,

        -- IST PRD/LS/Trainer
        COUNT(CASE
		    WHEN b.anwesenheit = 'anw'
		     AND b.effective_oe IN ('PRD', 'Leitstand', 'Trainer')
		     AND b.effective_taetigkeit NOT IN (
		            'Schichtleiter',
		            'Trainingskoordinator',
		            'Qualifizierungskoordinator'
		         )
		    THEN b.persnr
		END) AS ist_prd_ls_trainer,

        -- IST QS
        COUNT(CASE
		    WHEN b.anwesenheit = 'anw'
		     AND b.effective_oe = 'QS'
		     AND b.effective_taetigkeit NOT IN (
		            'Schichtleiter',
		            'Trainingskoordinator',
		            'Qualifizierungskoordinator'
		         )
		    THEN b.persnr
		END) AS ist_qs,

        -- IST WA/WE/BGL
        COUNT(CASE
		    WHEN b.anwesenheit = 'anw'
		     AND b.effective_oe IN ('WA','WE','BGL')
		     AND b.effective_taetigkeit NOT IN (
		            'Schichtleiter',
		            'Trainingskoordinator',
		            'Qualifizierungskoordinator'
		         )
		    THEN b.persnr
		END) AS ist_wa_we_bgl,

        -- IST Admin & SL
        COUNT(CASE
		    WHEN b.anwesenheit = 'anw'
		     AND (
		            b.effective_taetigkeit IN (
		                'Schichtleiter',
		                'Trainingskoordinator',
		                'Qualifizierungskoordinator'
		            )
		            OR b.kategorie IN ('admin')
		         )
		    THEN b.persnr
		END) AS ist_admin_sl


    FROM base b
    GROUP BY b.datum, b.iso_week
),

temp_onboarding_actual AS (
    SELECT
        YEARWEEK(p.beginn, 3) AS iso_week,
        COUNT(DISTINCT p.persnr) AS temp_onboarding_actual

    FROM tbl_ueb_personalakte_scd p
    CROSS JOIN params x

    WHERE p.eg = 'ZAK'
      AND p.beginn >= x.prev_monday
      AND p.beginn BETWEEN p.gueltig_von AND p.gueltig_bis
 --     AND p.beginn < x.curr_monday

    GROUP BY YEARWEEK(p.beginn, 3)
),

temp_onboarding_plan AS (
    SELECT
        YEARWEEK(o.datum, 3) AS iso_week,
        SUM(o.onboarding_plan) AS temp_onboarding_plan

    FROM tbl_uebertrag_onboarding_planung o
    CROSS JOIN params p

    WHERE o.filedate = (
        SELECT MAX(filedate)
        FROM tbl_uebertrag_onboarding_planung
    )
      AND o.datum BETWEEN p.curr_monday
                      AND p.next_monday + INTERVAL 5 DAY

    GROUP BY YEARWEEK(o.datum, 3)
),

temp_offboarding AS (
    SELECT
        YEARWEEK(p.ende, 3) AS iso_week,
        COUNT(DISTINCT p.persnr) AS temp_offboarding

    FROM tbl_ueb_personalakte_scd p
    CROSS JOIN params x

    WHERE p.eg = 'ZAK'
      AND p.ende BETWEEN x.prev_monday
                     AND x.next_monday + INTERVAL 6 DAY
      AND p.ende BETWEEN p.gueltig_von AND p.gueltig_bis

    GROUP BY YEARWEEK(p.ende, 3)
),

temp_double_shift AS (
    SELECT
        datum,
        iso_week,
        COUNT(*) AS temp_double_shift

    FROM (
        SELECT
            b.datum,
            YEARWEEK(b.datum, 3) AS iso_week,
            b.persnr

        FROM tbl_ueb_fz_buchungen b

        JOIN date_range d
          ON d.datum = b.datum

        JOIN tbl_ueb_personalakte_scd p
          ON p.persnr = b.persnr
         AND b.datum BETWEEN p.gueltig_von AND p.gueltig_bis

        WHERE p.eg = 'ZAK'
          AND p.oe <> 'Extern'
          AND b.anwesenheit = 'anw'

        GROUP BY b.datum, b.persnr
        HAVING COUNT(*) >= 2
    ) x

    GROUP BY datum, iso_week
),

weekly AS (
    SELECT
        d.iso_week,

        AVG(d.wc_aor) AS wc_aor,
        AVG(d.wc_vacation) AS wc_vacation,
        AVG(d.wc_sickness) AS wc_sickness,
        AVG(d.wc_other) AS wc_other,

        AVG(d.bc_aor) AS bc_aor,
        AVG(d.bc_vacation) AS bc_vacation,
        AVG(d.bc_sickness) AS bc_sickness,
        AVG(d.bc_other) AS bc_other,

        AVG(d.temp_pool_total) AS temp_pool_total,
        AVG(d.temp_absence) AS temp_absence,

        AVG(COALESCE(ds.temp_double_shift,0)) AS temp_double_shift,
        AVG(f.bc_beauftragung) AS bc_beauftragung,
        
		  AVG(d.ist_prd_ls_trainer) AS ist_prd_ls_trainer,
        AVG(d.ist_qs) AS ist_qs,
        AVG(d.ist_wa_we_bgl) AS ist_wa_we_bgl,
        AVG(d.ist_admin_sl) AS ist_admin_sl,

        AVG(f.soll_prd_ls_trainer) AS soll_prd_ls_trainer,
        AVG(f.soll_qs) AS soll_qs,
        AVG(f.soll_wa_we_bgl) AS soll_wa_we_bgl,
        AVG(f.soll_admin_sl) AS soll_admin_sl

    FROM daily_metrics d

    LEFT JOIN temp_double_shift ds
           ON ds.datum = d.datum

    LEFT JOIN fanf f
           ON f.datum = d.datum

    GROUP BY d.iso_week
),

weekly_full AS (
    SELECT
        w.*,

        CASE
            WHEN w.iso_week <= YEARWEEK((SELECT curr_monday FROM params), 3)
                THEN COALESCE(a.temp_onboarding_actual, 0)
            ELSE COALESCE(p.temp_onboarding_plan, 0)
        END AS temp_onboarding,

        COALESCE(ofb.temp_offboarding, 0) AS temp_offboarding

    FROM weekly w

    LEFT JOIN temp_onboarding_actual a
           ON a.iso_week = w.iso_week

    LEFT JOIN temp_onboarding_plan p
           ON p.iso_week = w.iso_week

    LEFT JOIN temp_offboarding ofb
           ON ofb.iso_week = w.iso_week
)

SELECT
    t.ord,
	 t.metric,

    MAX(CASE WHEN t.iso_week = YEARWEEK((SELECT prev_monday FROM params), 3)
        THEN t.val END) AS prev_week,

    MAX(CASE WHEN t.iso_week = YEARWEEK((SELECT curr_monday FROM params), 3)
        THEN t.val END) AS curr_week,

    MAX(CASE WHEN t.iso_week = YEARWEEK((SELECT next_monday FROM params), 3)
        THEN t.val END) AS next_week

FROM (

    SELECT 1 AS ord, 'WC AOR' AS metric, iso_week, wc_aor AS val
    FROM weekly_full

    UNION ALL
    SELECT 2 AS ord, 'WC HC Vacation' AS metric, iso_week, wc_vacation AS val
    FROM weekly_full

    UNION ALL
    SELECT 3 AS ord, 'WC HC Sickness' AS metric, iso_week, wc_sickness AS val
    FROM weekly_full

    UNION ALL
    SELECT 4 AS ord, 'WC HC other' AS metric, iso_week, wc_other AS val
    FROM weekly_full

    UNION ALL
    SELECT 5 AS ord, 'BC AOR' AS metric, iso_week, bc_aor AS val
    FROM weekly_full

    UNION ALL
    SELECT 6 AS ord, 'BC HC Vacation' AS metric, iso_week, bc_vacation AS val
    FROM weekly_full

    UNION ALL
    SELECT 7 AS ord, 'BC HC Sickness' AS metric, iso_week, bc_sickness AS val
    FROM weekly_full

    UNION ALL
    SELECT 8 AS ord, 'BC HC other' AS metric, iso_week, bc_other AS val
    FROM weekly_full

    UNION ALL
    SELECT 9 AS ord, 'Temp Pool total' AS metric, iso_week, temp_pool_total AS val
    FROM weekly_full

    UNION ALL
    SELECT 10 AS ord, 'Temp Onboarding' AS metric, iso_week, temp_onboarding AS val
    FROM weekly_full

    UNION ALL
    SELECT 11 AS ord, 'Temp Offboarding' AS metric, iso_week, temp_offboarding AS val
    FROM weekly_full

    UNION ALL
    SELECT 12 AS ord, 'Temp Absence' AS metric, iso_week, temp_absence AS val
    FROM weekly_full

    UNION ALL
    SELECT 13 AS ord, 'Temp double shift' AS metric, iso_week, temp_double_shift AS val
    FROM weekly_full

    UNION ALL
    SELECT 14 AS ord, 'BC Beauftragung' AS metric, iso_week, bc_beauftragung AS val
    FROM weekly_full
    
	 UNION ALL
    SELECT 15 AS ord, 'SOLL PRD/LS/Trainer' AS metric, iso_week, soll_prd_ls_trainer AS val FROM weekly_full
    UNION ALL
    SELECT 16 AS ord, 'SOLL QS', iso_week, soll_qs FROM weekly_full
    UNION ALL
    SELECT 17 AS ord, 'SOLL WA/WE/BGL', iso_week, soll_wa_we_bgl FROM weekly_full
    UNION ALL
    SELECT 18 AS ord, 'SOLL Admin & SL', iso_week, soll_admin_sl FROM weekly_full

    UNION ALL
    SELECT 19 AS ord, 'IST PRD/LS/Trainer', iso_week, ist_prd_ls_trainer FROM weekly_full
    UNION ALL
    SELECT 20 AS ord, 'IST QS', iso_week, ist_qs FROM weekly_full
    UNION ALL
    SELECT 21 AS ord, 'IST WA/WE/BGL', iso_week, ist_wa_we_bgl FROM weekly_full
    UNION ALL
    SELECT 22 AS ord, 'IST Admin & SL', iso_week, ist_admin_sl FROM weekly_full

) t

GROUP BY t.ord, t.metric
ORDER BY t.ord;

    INSERT INTO tbl_ueb_peko_archiv (
          ord
        , metric
        , prev_week
        , curr_week
        , next_week
        , last_insert_update
    )
    SELECT
          ord
        , metric
        , prev_week
        , curr_week
        , next_week
        , NOW()
    FROM tbl_ueb_peko;

END//
