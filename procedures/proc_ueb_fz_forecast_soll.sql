-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_forecast_soll.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_forecast_soll`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_forecast_soll`()
SQL SECURITY DEFINER BEGIN
SELECT MAX(datum) INTO @maxdate FROM vp_urlaub_u;
INSERT INTO tbl_ueb_fz_forecast(datum, schicht, gruppe, soll)
WITH reduzierung AS (
      SELECT r.datum
           , r.oe
           , r.taetigkeit
           , s.schicht_int AS schicht
           , SUM(reduzierung) AS reduzierung
        FROM tbl_import_reduzierung r
        LEFT JOIN tbl_schichten s ON r.schicht = s.Schicht AND s.`Index` <= 3
       GROUP BY r.datum, r.oe, r.taetigkeit, s.schicht_int
)
, fanf AS (
		SELECT datum, oe, tätigkeit, schicht, beauftragung
		  FROM tbl_uebertrag_fanf
		  WHERE datum BETWEEN '2026-01-01' AND @maxdate
)
, fanf2 AS (
      SELECT f.datum
           , f.schicht
           , SUM((f.beauftragung - IFNULL(r.reduzierung, 0)) * (f.tätigkeit IN ('Lagerhelfer', 'Pausenvertretung', 'Staplerfahrer', 'QS', 'Kitting'))) AS soll
        FROM fanf f
        LEFT JOIN reduzierung r ON f.datum = r.datum AND f.oe = r.oe AND f.tätigkeit = r.taetigkeit AND f.schicht = r.schicht
       INNER JOIN tbl_datum d ON d.datum = f.datum AND d.arbeitstag = 1
       GROUP BY f.datum, f.schicht
)
SELECT f2.datum
     , f2.schicht
     , 'DPW' AS gruppe
     , f2.soll
  FROM fanf2 f2
ON DUPLICATE KEY UPDATE
     soll = VALUES(soll);
END//
