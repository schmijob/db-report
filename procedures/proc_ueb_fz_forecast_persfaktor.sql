-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_forecast_persfaktor.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_forecast_persfaktor`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_forecast_persfaktor`()
SQL SECURITY DEFINER BEGIN
-- persönlichen Abwesenheitsfaktor updaten
     DELETE FROM tbl_ueb_fz_persfaktor;
     INSERT INTO tbl_ueb_fz_persfaktor
WITH raw_absence AS (
     SELECT b.persnr
 	       , b.datum 
 	       , s.schicht_int AS Schicht
          , IF(p.eg = 'ZAK','ZAK', 'DPW') AS gruppe
          , SUM(b.anwesenheit IN ('Lfz', 'Sonst.', 'KE')) AS krank
          , COUNT(*) AS total_days
          , cast(SUM(b.anwesenheit IN ('Lfz', 'Sonst.', 'KE')) / COUNT(*) AS DECIMAL(5,4)) AS actuals
       FROM tbl_ueb_fz_buchungen b
       LEFT JOIN tbl_ueb_personalakte_scd p ON b.PersNr = p.persnr_alt
                                          AND b.datum BETWEEN p.gueltig_von AND p.gueltig_bis
       LEFT JOIN tbl_stamm_kategorie_abteilung k ON p.taetigkeit = k.`tätigkeit`
      INNER JOIN tbl_datum d ON b.datum = d.datum AND d.arbeitstag = 1
       LEFT JOIN tbl_schichten s ON d.schichtindex = s.schichtindex AND b.Schicht = s.Schicht AND s.index <= 9
      WHERE k.kategorie = 'Operativ' AND b.datum BETWEEN @forecast_date - INTERVAL 1 YEAR and @forecast_date - INTERVAL 1 day AND p.eg IS NOT null
  --    AND  p.ende > CURDATE()
      GROUP BY b.PersNr, b.datum
)     
, quote_tag AS (
     SELECT datum, schicht, gruppe, SUM(krank) as krankentage, SUM(total_days) AS gesamttage, SUM(krank) / SUM(total_days) AS kq 
       FROM raw_absence r GROUP BY datum, gruppe, schicht
) 
, quote_tag_persona AS (
     SELECT r.*, q.krankentage, q.gesamttage  
       FROM raw_absence r
       LEFT JOIN quote_tag q ON r.datum = q.datum AND r.schicht = q.schicht AND r.gruppe = q.gruppe
)
, ergebnis AS (
     SELECT persnr
   --     , SUM(krank) AS krank_p
          , SUM(total_days) AS gesamt_p
   --     , SUM(krankentage) AS krank_a
   --     , SUM(gesamttage) AS gesamt_a
          , SUM(krank) / SUM(total_days) AS kq_p
          , SUM(krankentage)/ SUM(gesamttage) AS kq_a
   --     , (SUM(krank) / SUM(total_days)) - (SUM(krankentage)/ SUM(gesamttage)) AS faktor 
       FROM quote_tag_persona 
		GROUP BY persnr
)
, working_days AS (
     SELECT SUM(arbeitstag) AS wd 
	    FROM tbl_datum 
		WHERE datum BETWEEN @forecast_date - INTERVAL 1 YEAR AND @forecast_date - INTERVAL 1 day
)
, initial_factor AS (
     SELECT e.persnr -- e.*
--        , e.kq_p / e.kq_a AS faktor_roh
--        , 0.5 * gesamt_p / w.wd -- halbe gewichtung für unternehmenszugehörigkeit
          , CAST((0.5 * gesamt_p / w.wd) * (e.kq_p / e.kq_a - 1) + 1 as DECIMAL(5,4)) AS fz_faktor  
       FROM ergebnis e
      CROSS JOIN working_days w
)
, bias AS (      
     SELECT 1 - AVG(fz_faktor) as bias FROM initial_factor p
  --     LEFT JOIN tbl_ueb_personalakte p2 ON p.persnr = p2.persnr
  --    WHERE p2.ende > @forecast_date 
)
     SELECT persnr
          , CAST(fz_faktor - bias as DECIMAL(5,4)) AS fz_faktor
	   FROM initial_factor
	   CROSS JOIN bias 
	   GROUP BY persnr
;
END//
