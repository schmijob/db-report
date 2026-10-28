-- Managed by db-workbench; source of truth: db-report/procedures/proc_bm_funktionsgestellung.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_bm_funktionsgestellung`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_bm_funktionsgestellung`()
SQL SECURITY DEFINER BEGIN
SET @mindate = DATE_FORMAT(CURDATE() - INTERVAL 1 MONTH, '%Y-%m-01');
SET @maxdate = LAST_DAY(CURDATE() - INTERVAL 0 MONTH);
SET @maxdate = LEAST(@maxdate, CURDATE());

DELETE FROM tbl_bm_funktionsgestellung WHERE monat BETWEEN @mindate AND @maxdate;

INSERT INTO tbl_bm_funktionsgestellung (monat, gruppe, malusfaktor, unterdeckung_sum, unterdeckung_avg, häufigkeit, malus)

WITH anwesenheit AS (
	SELECT b.datum
		, b.schicht
		, SUM(p.oe IN ('PRD', 'Leitstand', 'Trainer') AND p.taetigkeit NOT IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator')) + IFNULL(v.prd, 0) AS `PRD/LS/Trainer`
		, SUM(p.oe IN ('PRD', 'Leitstand', 'Trainer') AND p.taetigkeit = 'Teamleiter') AS `PRD/LS/Trainer_TL`
		, SUM(p.oe IN ('WA', 'WE', 'BGL') AND p.taetigkeit <> 'Schichtleiter') + IFNULL(v.WA, 0) + IFNULL(v.WE, 0) + IFNULL(v.BGL, 0) - IFNULL(v.yard, 0) AS `WA/WE/BGL`
		, SUM(p.oe IN ('WA', 'WE', 'BGL') AND p.taetigkeit = 'Teamleiter') AS `WA/WE/BGL_TL`
		, IFNULL(v.yard, 0) AS Yard
		, SUM(p.oe = 'QS' AND p.taetigkeit <> 'Schichtleiter') + IFNULL(v.qs, 0) AS QS
		, SUM(p.oe = 'QS' AND p.taetigkeit = 'Teamleiter') AS QS_TL
		, SUM(p.taetigkeit IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator')) AS Schichtleiter
	FROM tbl_ueb_fz_buchungen b	
	LEFT JOIN tbl_ueb_personalakte_scd p ON b.PersNr = p.persnr_alt AND b.datum BETWEEN p.gueltig_von AND p.gueltig_bis
	LEFT JOIN tbl_stamm_kategorie_abteilung k ON p.taetigkeit = k.`tätigkeit`
	LEFT JOIN tbl_import_verschiebung v ON v.datum = b.datum AND v.schicht = b.schicht
  WHERE b.anwesenheit = 'anw'
	 AND kategorie NOT IN ('admin', 'leitung (at)')
	 AND b.datum BETWEEN @mindate AND @maxdate
  GROUP BY datum, schicht
)
, fanf AS (
	SELECT f.datum, f.oe, f.`tätigkeit`, f.beauftragung, s.schicht FROM tbl_uebertrag_fanf f
	-- JOIN tbl_datum d ON f.datum = d.datum AND d.arbeitstag = 1
	LEFT JOIN tbl_schichten s ON s.schicht_int = f.schicht AND s.`Index` <= 3
	WHERE f.datum BETWEEN @mindate AND @maxdate
)
, fanf2 AS (
	SELECT f.datum
		, f.schicht
		, SUM((f.beauftragung ) * (f.tätigkeit NOT IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator') AND f.oe IN ('PRD', 'Leitstand', 'Trainer'))) - IF(f.schicht = 'Früh', 1, 0) AS `PRD/LS/Trainer`
		, SUM((f.beauftragung ) * (f.tätigkeit = 'Teamleiter' AND f.oe IN ('PRD', 'Leitstand', 'Trainer'))) AS `PRD/LS/Trainer_TL`
		, SUM((f.beauftragung ) * (f.tätigkeit NOT IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator') AND f.oe IN ('WA', 'WE', 'BGL'))) - 2 AS `WA/WE/BGL`
		, SUM((f.beauftragung ) * (f.tätigkeit = 'Teamleiter' AND f.oe IN ('WA', 'WE', 'BGL'))) - 2 AS `WA/WE/BGL_TL`
		, 2 AS Yard
		, SUM((f.beauftragung ) * (f.tätigkeit NOT IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator') AND f.oe = 'QS')) AS QS
		, SUM((f.beauftragung ) * (f.tätigkeit = 'Teamleiter' AND f.oe = 'QS')) AS QS_TL
		, SUM((f.beauftragung ) * (f.tätigkeit IN ('Schichtleiter', 'Trainingskoordinator', 'Qualifizierungskoordinator'))) + IF(f.schicht = 'Früh', 1, 0)
		AS Schichtleiter
	FROM fanf f
	GROUP BY f.datum, f.schicht
)

, basis AS (

    SELECT
          g.datum
        , g.schicht
        , g.gruppe
        , g.ist
        , f.fanf
        , GREATEST(0, f.fanf - g.ist) AS unterdeckung
        , (g.ist - f.fanf) / NULLIF(f.fanf , 0) AS abweichung

    FROM (
        SELECT 'PRD/LS/Trainer'  AS gruppe, `PRD/LS/Trainer`  AS ist, datum, schicht FROM anwesenheit
        UNION ALL
        SELECT 'WA/WE/BGL'   , `WA/WE/BGL`                , datum, schicht FROM anwesenheit
        UNION ALL
        SELECT 'Yard' , `Yard`                     , datum, schicht FROM anwesenheit
        UNION ALL
        SELECT 'QS'   , `QS`                       , datum, schicht FROM anwesenheit
--        UNION ALL
--        SELECT 'SL'   , `Schichtleiter`            , datum, schicht FROM anwesenheit
    ) g

    JOIN (
        SELECT 'PRD/LS/Trainer'  AS gruppe, `PRD/LS/Trainer`  AS fanf, datum, schicht FROM fanf2
        UNION ALL
        SELECT 'WA/WE/BGL'   , `WA/WE/BGL`                , datum, schicht FROM fanf2
        UNION ALL
        SELECT 'Yard' , `Yard`                     , datum, schicht FROM fanf2
        UNION ALL
        SELECT 'QS'   , `QS`                       , datum, schicht FROM fanf2
--        UNION ALL
--       SELECT 'SL'   , `Schichtleiter`            , datum, schicht FROM fanf2
    ) f
      ON f.datum   = g.datum
     AND f.schicht = g.schicht
     AND f.gruppe  = g.gruppe
)

, berechnung AS (
    SELECT
          datum
        , schicht
        , gruppe
        , ist
        , fanf
		  , unterdeckung
		  , GREATEST(abweichung, 0) AS abweichung
        , CASE
            WHEN abweichung >= -0.03 THEN 0
            WHEN abweichung >= -0.05 THEN 0.05
            WHEN abweichung >= -0.10 THEN 0.10
            ELSE 0.15
          END AS malusfaktor

        , 40 * 7.6
          * unterdeckung
          * CASE
            WHEN abweichung >= -0.03 THEN 0
            WHEN abweichung >= -0.05 THEN 0.05
            WHEN abweichung >= -0.10 THEN 0.10
            ELSE 0.15
          END AS malus

    FROM basis
)

SELECT DATE_FORMAT(MIN(datum), '%Y-%m-01') AS monat
     , gruppe
     , malusfaktor
     , SUM(unterdeckung) AS unterdeckung_sum
     , CAST(AVG(unterdeckung) AS DECIMAL(6,3)) AS unterdeckung_avg
     , COUNT(*) AS häufigkeit
     , CAST(sum(malus) AS DECIMAL(8,2)) AS malus
  FROM berechnung
 GROUP BY year(datum), month(datum), gruppe, malusfaktor
 ORDER BY FIELD(gruppe, 'PRD/LS/Trainer','WA/WE/BGL','Yard','QS','SL')
	  , malusfaktor;
END//
