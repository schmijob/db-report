-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_personalplanung.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_personalplanung`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_personalplanung`()
SQL SECURITY DEFINER BEGIN
SET @mindate = CURDATE() - INTERVAL 30 DAY;
SET @maxdate = CURDATE() + INTERVAL 60 DAY;
START TRANSACTION;
DELETE FROM tbl_ueb_fz_personalplanung WHERE datum BETWEEN @mindate AND @maxdate;
INSERT INTO tbl_ueb_fz_personalplanung (
    datum,
    schicht,
    taetigkeit,
    oe,
    onboarding,
    total_headcount,
    surviving_headcount,
    anwesend,
    fc_anwesend,
    ausgeplant,
    url,
    beauftragung,
    fc_ungeplant,
    actuals_ungeplant,
    delta,
    abgänge_fc,
	 abgänge_ist
    
) 
WITH fanf AS (
    SELECT d.datum
         , CASE WHEN f.oe = 'Sonderfunktion' AND d.datum >= '2025-01-01' THEN 'QS'
                WHEN f.oe = 'Sonderfunktion' AND d.datum <  '2025-01-01' THEN 'PRD'
                ELSE f.oe
           END AS oe
         , CASE WHEN f.oe IN ('Admin','Leitstand','Trainer','Overhead (AT)')
                THEN f.oe
                WHEN f.`tätigkeit` = 'Kitting' THEN 'Lagerhelfer'
                ELSE f.tätigkeit
           END AS tätigkeit 
         , f.schicht
         , SUM(f.beauftragung /* - IFNULL(r.reduzierung, 0) */ ) AS beauftragung
      FROM tbl_uebertrag_fanf f
      JOIN tbl_datum d ON f.datum = d.datum AND arbeitstag = 1 AND d.datum BETWEEN @mindate AND @maxdate
      LEFT JOIN tbl_schichten s ON f.schicht = s.Schicht_int AND s.`index` <= 3
      GROUP BY 1, 2, 3, 4
)
, dataset AS (
    SELECT b.datum
         , b.persnr
         , p.name
         , d.wochenbeginn
         , b.`Status`
         , IFNULL(s.Schicht, 'Früh') AS schicht
         , b.anwesenheit
         , ifnull(fp.expected_alive, 1) as expected_alive

	        /* normalize activity for overhead-style OEs */
	      , CASE
	        		WHEN p.oe = 'Leitstand' THEN 'Leitstand'
					WHEN k.kategorie IN ('Admin','Trainer','Overhead (AT)') THEN k.kategorie
					when p.taetigkeit IS NULL then ''
	            ELSE TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' from p.taetigkeit))
	         END AS taetigkeit  
	      ,  CASE
	            WHEN p.oe = 'Leitstand' THEN 'Leitstand'
					WHEN k.kategorie IN ('Admin','Trainer','Overhead (AT)') THEN k.kategorie
	            ELSE p.oe
	         END AS oe
        

         , (b.datum < p.beginn + INTERVAL 5 DAY AND ifnull(p.`übernahme`, 0) = 0) AS onboarding

         , CASE WHEN b.datum >= CURDATE() AND b.anwesenheit = 'anw' AND b.kommen IS NULL
	             THEN ((f.forecast_lagged - f.actuals_geplant) * f.decay) * POW(IFNULL(pf.fz_faktor, 1), 0)
	             ELSE NULL
	        END AS krankenquote
	      , IF(p.ende = b.datum, 1, 0) AS abgang_ist
	      , IFNULL(fp.hazard_runtime, 0) AS abgang_fc

         
    FROM tbl_ueb_fz_buchungen b
    JOIN tbl_datum d ON b.datum = d.datum -- AND d.arbeitstag = 1
    LEFT JOIN tbl_schichten s ON b.Schicht = s.Schicht AND s.index <= 3
    LEFT JOIN tbl_ueb_personalakte p ON b.PersNr = p.persnr
    LEFT JOIN tbl_stamm_kategorie_abteilung k ON p.taetigkeit = k.`tätigkeit`
    LEFT JOIN tbl_ueb_fz_forecast f
           ON b.Datum = f.datum
          AND f.schicht = s.Schicht_int
          AND f.gruppe = IF(p.eg = 'ZAK', 'ZAK', 'DPW')
    LEFT JOIN tbl_ueb_fz_persfaktor pf ON b.PersNr = pf.persnr
    LEFT JOIN tbl_ueb_fluktuation_person fp ON fp.persnr = b.persnr AND fp.datum = b.Datum
    WHERE b.Datum BETWEEN @mindate AND @maxdate
    AND p.oe <> 'extern'
    AND (b.anwesenheit <> 'frei' OR b.status = 'KE-a')
)

, base AS (
    SELECT datum
         , wochenbeginn
         , schicht
         , taetigkeit
         , oe
         , onboarding
         , COUNT(*) total_headcount
         , SUM(expected_alive) AS surviving_headcount
         , SUM(expected_alive * IF(anwesenheit = 'anw', 1, 0)) AS anwesend
         , SUM(expected_alive * IF(anwesenheit = 'anw', 1, 0) - IFNULL(krankenquote, 0)) AS fc_anwesend
         , SUM(expected_alive * IF(`status` = 'KE-a', 1, 0)) AS ausgeplant
         , SUM(expected_alive * IF(anwesenheit = 'URL', 1, 0)) AS url
         , SUM(abgang_ist) AS abgänge_ist
         , SUM(expected_alive * abgang_fc) AS abgänge_fc
    FROM dataset
    GROUP BY datum, wochenbeginn, schicht, taetigkeit, oe, onboarding
)
, base_with_plan AS (
    SELECT
        b.*,
        CASE 
            WHEN b.onboarding = 0 THEN IFNULL(fa.beauftragung, 0)
            ELSE 0
        END AS beauftragung
    FROM base b
    LEFT JOIN fanf fa
           ON b.datum = fa.datum
          AND b.oe = fa.oe
          AND b.taetigkeit = fa.tätigkeit
          AND b.schicht = IFNULL((
                SELECT s.Schicht
                FROM tbl_schichten s
                WHERE s.Schicht_int = fa.schicht
                  AND s.index <= 3
                LIMIT 1
          ), 'Früh')
)
/*
, lag_plan AS (
    SELECT fa.datum
         , IFNULL(s.Schicht, 'Früh') AS schicht
         , SUM(fa.beauftragung) AS lag_beauftragung
    FROM fanf fa
    LEFT JOIN tbl_schichten s ON fa.schicht = s.Schicht_int AND s.`index` <= 3
    WHERE fa.oe = 'PRD' AND fa.tätigkeit = 'Lagerhelfer'
    GROUP BY fa.datum, IFNULL(s.Schicht, 'Früh')
)
, kit_plan AS (
    SELECT fa.datum
         , IFNULL(s.Schicht, 'Früh') AS schicht
         , SUM(fa.beauftragung) AS kit_beauftragung
    FROM fanf fa
    LEFT JOIN tbl_schichten s ON fa.schicht = s.Schicht_int AND s.`index` <= 3
    WHERE fa.oe = 'PRD' AND fa.tätigkeit = 'Kitting'
    GROUP BY fa.datum, IFNULL(s.Schicht, 'Früh')
)
, lh0 AS (
    -- actuals currently sitting in Lagerhelfer/PRD onboarding=0 (because Personalakte doesn't split)
    SELECT *
    FROM base_with_plan
    WHERE oe = 'PRD' AND taetigkeit = 'Lagerhelfer' AND onboarding = 0
)
, onb AS (
    -- onboarding actuals: route by wochenbeginn 
    SELECT datum, wochenbeginn, schicht,
           'Kitting' AS taetigkeit,
           oe, onboarding,
           total_headcount, surviving_headcount, anwesend, forecast, ausgeplant, url, beauftragung, abgänge_ist, abgänge_fc
    FROM base_with_plan
    WHERE oe = 'PRD' AND taetigkeit = 'Lagerhelfer' AND onboarding = 1
)
, other AS (
     everything else unchanged (also excludes the PRD/Lagerhelfer rows we are remapping) 
    SELECT *
    FROM base_with_plan
    WHERE NOT (oe = 'PRD' AND taetigkeit = 'Lagerhelfer')
)
, final AS (
SELECT
    o.datum, o.schicht, o.taetigkeit, o.oe, o.onboarding,
     total_headcount, surviving_headcount, o.anwesend, o.forecast AS fc_anwesend, o.ausgeplant, o.url, o.beauftragung, abgänge_ist, abgänge_fc
FROM other o

UNION ALL

-- onboarding routed according to week start 
SELECT
    x.datum, x.schicht, x.taetigkeit, x.oe, x.onboarding,
     total_headcount, surviving_headcount, x.anwesend, x.forecast AS fc_anwesend, x.ausgeplant, x.url, x.beauftragung, abgänge_ist, abgänge_fc
FROM onb x

UNION ALL

-- synthetic Lagerhelfer/PRD onboarding=0 filled to 100% from FANF(Lagerhelfer) 
SELECT
    p.datum,
    p.schicht,
    'Lagerhelfer' AS taetigkeit,
    'PRD'         AS oe,
    0             AS onboarding,
    p.lag_beauftragung AS total_headcount,
    p.lag_beauftragung AS surviving_headcount,
    p.lag_beauftragung AS anwesend,
    p.lag_beauftragung AS fc_anwesend,
    0 AS ausgeplant,
    0 AS url,
    p.lag_beauftragung AS beauftragung,
    0 AS abgänge_ist,
	 0 AS abgänge_fc
FROM lag_plan p
WHERE p.lag_beauftragung <> 0

UNION ALL

-- Kitting/PRD onboarding=0 = overflow actuals after filling Lagerhelfer 
SELECT
    COALESCE(k.datum, p.datum) AS datum,
    COALESCE(k.schicht, p.schicht) AS schicht,
    'Kitting' AS taetigkeit,
    'PRD'     AS oe,
    0         AS onboarding,

    GREATEST(IFNULL(a.total_headcount, 0) - IFNULL(p.lag_beauftragung, 0), 0) AS total_headcount,
    GREATEST(IFNULL(a.surviving_headcount, 0) - IFNULL(p.lag_beauftragung, 0), 0) AS surviving_headcount,
    GREATEST(IFNULL(a.anwesend, 0)  - IFNULL(p.lag_beauftragung, 0), 0) AS anwesend,
    GREATEST(IFNULL(a.forecast, 0)  - IFNULL(p.lag_beauftragung, 0), 0) AS fc_anwesend,

    -- Lagerhelfer forced to 0, so keep these metrics on the overflow side 
    IFNULL(a.ausgeplant, 0) AS ausgeplant,
    IFNULL(a.url, 0)        AS url,

    IFNULL(k.kit_beauftragung, 0) AS beauftragung
    , ifnull(abgänge_ist, 0) AS abgänge_ist
    , ifnull(abgänge_fc, 0) AS abgänge_fc
FROM kit_plan k
LEFT JOIN lag_plan p
       ON k.datum = p.datum AND k.schicht = p.schicht
LEFT JOIN lh0 a
       ON k.datum = a.datum AND k.schicht = a.schicht
WHERE IFNULL(k.kit_beauftragung, 0) <> 0
   OR IFNULL(a.total_headcount, 0) <> 0
) */
SELECT
    datum,
    schicht,
    taetigkeit,
    oe,
    onboarding,

    total_headcount,

    CAST(surviving_headcount AS DECIMAL(7,4)) AS surviving_headcount,
    CAST(anwesend            AS DECIMAL(7,4)) AS anwesend,
    CAST(fc_anwesend         AS DECIMAL(7,4)) AS fc_anwesend,

    ausgeplant,

    CAST(url                 AS DECIMAL(7,4)) AS url,

    beauftragung,

    CAST(anwesend - fc_anwesend                           AS DECIMAL(7,4)) AS fc_ungeplant,
    CAST(surviving_headcount - anwesend - ausgeplant - url AS DECIMAL(7,4)) AS actuals_ungeplant,
    CAST(fc_anwesend - beauftragung                       AS DECIMAL(7,4)) AS delta,
    CAST(abgänge_fc AS DECIMAL(7,4)) AS abgänge_fc,
	 abgänge_ist
    
FROM base_with_plan -- final
/*
ON DUPLICATE KEY UPDATE
    total_headcount       = VALUES(total_headcount),

    surviving_headcount   = VALUES(surviving_headcount),
    anwesend              = VALUES(anwesend),
    fc_anwesend           = VALUES(fc_anwesend),

    ausgeplant            = VALUES(ausgeplant),
    url                   = VALUES(url),

    beauftragung          = VALUES(beauftragung),

    fc_ungeplant          = VALUES(fc_ungeplant),
    actuals_ungeplant     = VALUES(actuals_ungeplant),
    delta                 = VALUES(delta),
	 abgänge_fc 			  = VALUES(abgänge_fc),
    abgänge_ist 			  = VALUES(abgänge_ist)

*/
;
COMMIT;
END//
