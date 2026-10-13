-- Managed by db-workbench; source of truth: db-report/procedures/xxx_proc_ueb_fz_forecast_tj.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `xxx_proc_ueb_fz_forecast_tj`//
CREATE DEFINER=CURRENT_USER PROCEDURE `xxx_proc_ueb_fz_forecast_tj`()
SQL SECURITY DEFINER BEGIN
SET @forecast_date = CURDATE();
SET @forecast_time = (SELECT TIME(MAX(filedate)) FROM tbl_ueb_fz_buchungen);
SET @filedate = (SELECT MAX(filedate) FROM tbl_import_aenderungen);
-- Aktualisierungszeitraum
SET @mindate = CURDATE() - INTERVAL 7 DAY; -- '2022-08-01';  --  
SET @maxdate = CURDATE() + INTERVAL 182 DAY; -- '2024-01-01'; -- 

############## ROHDATEN ####################
    INSERT INTO tbl_ueb_fz_forecast(datum, schicht, gruppe, schichtgr, actuals, actuals_geplant, actuals_URL, total_days, w_lag, decay, soll)
    
    #### decay ####
    WITH dataset AS (
				SELECT a.wert
					  , a.datum
				     , LEAST( a.bekannt_seit -- Änderungsdatum oder spätestens mit Schichtbeginn
					         , a.datum + INTERVAL CASE WHEN f.schicht = 'früh' THEN 6 
																  WHEN f.schicht = 'spät' THEN 14 
																  ELSE 0
															END HOUR) AS bekannt_seit
				     , GREATEST( WEEKDAY(a.bekannt_seit) + DATEDIFF(a.datum, a.bekannt_seit) -- Wochentag der Fehlzeit; + 7 für Folgewoche etc
					            , WEEKDAY(a.datum)) AS wochentag 
				     , s.schicht_int AS schicht
				     , DATEDIFF(a.datum, a.bekannt_seit) AS dd
				     , WEEKDAY(a.bekannt_seit) AS wd_b
				     , WEEKDAY(a.datum) AS wd_d
				     , WEEKDAY(a.bekannt_seit) + DATEDIFF(a.datum, a.bekannt_seit) AS wd2	
				  FROM tbl_ueb_aend_fz_kalender a
			LEFT JOIN tbl_datum d 					ON a.datum = d.datum
			LEFT JOIN tbl_ueb_personalakte p 	ON a.persnr = p.persnr
			LEFT JOIN tbl_ueb_fz_buchungen f 	ON f.PersNr = a.persnr AND f.Datum = a.datum
			LEFT JOIN tbl_abwesenheitsgrund b 	ON a.wert = b.kuerzel
			LEFT JOIN tbl_schichten s ON f.schicht = s.schicht AND s.index <= 3
	
				 WHERE a.Datum BETWEEN '2023-01-31' AND @forecast_date AND d.arbeitstag = 1 
				   AND a.persnr > 8000 AND b.anwesenheit IN ('Lfz', 'Sonst.', 'KE', 'oLfz') -- NOT IN ('Frei', 'URL') AND b.kuerzel <> 'GLZ'
				   AND WEEKDAY(a.bekannt_seit) + DATEDIFF(a.datum, a.bekannt_seit) <= 19
				   AND p.taetigkeit IN ('Lagerhelfer', 'Staplerfahrer', 'QS')
					AND f.schicht <> '' -- AND f.schicht IS NOT null
)

 , WEEK00 AS (
				 SELECT a.wochentag - 14 AS wochentag
				      , schicht
				      , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY < TIME(@filedate) + INTERVAL WEEKDAY(@filedate) + 14 DAY) AS früher
					   , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY >= TIME(@filedate) + INTERVAL WEEKDAY(@filedate) + 14 DAY) AS später
				   FROM dataset a
			  GROUP BY a.wochentag, schicht
) 

, WEEK0 AS (
				 SELECT a.wochentag - 7 AS wochentag
				      , schicht
				      , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY < TIME(@filedate) + INTERVAL WEEKDAY(@filedate) + 7 DAY) AS früher
					   , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY >= TIME(@filedate) + INTERVAL WEEKDAY(@filedate) + 7 DAY) AS später
				   FROM dataset a
			  GROUP BY a.wochentag, schicht
)

, WEEK1 AS (
				 SELECT a.wochentag
				      , schicht
				      , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY < TIME(@filedate) + INTERVAL WEEKDAY(@filedate) DAY) AS früher
					   , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY >= TIME(@filedate) + INTERVAL WEEKDAY(@filedate) DAY) AS später
				   FROM dataset a
			  GROUP BY a.wochentag, schicht
)

, WEEK2 AS (
				  SELECT a.wochentag + 7 AS wochentag
				       , schicht
				      , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY < TIME(@filedate) + INTERVAL WEEKDAY(@filedate) - 7 DAY) AS früher
					   , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY >= TIME(@filedate) + INTERVAL WEEKDAY(@filedate) - 7 DAY) AS später
				    FROM dataset a
				   WHERE a.wochentag <= 4
				GROUP BY a.wochentag, schicht
) 
 , WEEK3 AS (
				  SELECT a.wochentag + 14 AS wochentag
				       , schicht
				      , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY < TIME(@filedate) + INTERVAL WEEKDAY(@filedate) - 14 DAY) AS früher
					   , SUM(TIME(a.bekannt_seit) + INTERVAL WEEKDAY(a.bekannt_seit) DAY >= TIME(@filedate) + INTERVAL WEEKDAY(@filedate) - 14 DAY) AS später
				    FROM dataset a
				   WHERE a.wochentag <= 4
				GROUP BY a.wochentag, schicht
) 

, 3weeks AS (
			   SELECT a.wochentag
			        , a.schicht
			        , a.früher + coalesce(b.früher, 0) + coalesce(c.früher, 0)  + coalesce(d.früher, 0) + coalesce(e.früher, 0) AS früher
				     , a.später + coalesce(b.später, 0) + coalesce(c.später, 0)  + coalesce(d.später, 0) + coalesce(e.später, 0) AS später
			     FROM WEEK1 a
			LEFT JOIN WEEK2 b ON a.wochentag = b.wochentag AND a.schicht = b.schicht
			LEFT JOIN WEEK0 c ON a.wochentag = c.wochentag AND a.schicht = c.schicht
			LEFT JOIN WEEK3 d ON a.wochentag = d.wochentag AND a.schicht = d.schicht
			LEFT JOIN WEEK00 e ON a.wochentag = e.wochentag AND a.schicht = e.schicht
			ORDER BY a.wochentag, a.schicht
			
)

, decay AS(
			SELECT DATE(@filedate) + INTERVAL wochentag - weekday(DATE(@filedate)) day AS datum , schicht -- , früher, später
			, später / (früher+später) AS decay
			FROM 3weeks 
) 
##### FANF #####
, reduzierung AS (
      SELECT datum, oe, taetigkeit, s.schicht_int AS schicht, SUM(reduzierung) AS reduzierung 
		FROM tbl_import_reduzierung r
		LEFT JOIN tbl_schichten s ON r.schicht = s.Schicht AND s.`Index` <= 3
		GROUP BY r.datum, r.oe, r.taetigkeit, r.schicht
)
, fanf AS (
		SELECT d.datum, f.oe, f.tätigkeit, f.schicht, SUM(f.beauftragung) as beauftragung
		FROM tbl_import_fanf f
		LEFT JOIN tbl_datum d ON d.datum BETWEEN f.datum AND LAST_DAY(f.datum) 
		                      OR f.datum = (SELECT MAX(datum) FROM tbl_import_fanf) AND d.datum > LAST_DAY(f.datum) AND d.datum <= @maxdate -- <= LAST_DAY(CURDATE() + INTERVAL 3 MONTH)
		GROUP BY d.datum, f.oe, f.tätigkeit, f.schicht
)
, fanf2 AS (
		SELECT     f.datum
		    ,      f.schicht
		    ,      SUM((f.beauftragung - IFNULL(r.reduzierung, 0)) * (f.tätigkeit IN ('Lagerhelfer', 'Pausenvertretung', 'Staplerfahrer', 'QS'))) AS soll  
		FROM fanf f
		LEFT JOIN reduzierung r ON f.datum = r.datum AND f.oe = r.oe AND f.tätigkeit = r.taetigkeit AND f.schicht = r.schicht
		GROUP BY f.datum, f.schicht
)
#### actuals ####
, actuals AS (
    SELECT b.Datum 						
         , IFNULL(s.schicht_int, 0) AS schicht
         , IF(p.eg = 'ZAK', 'ZAK', 'DPW') AS gruppe
			, IFNULL(s.Schichtgr_kurz, '?') AS schichtgr
         , SUM(b.anwesenheit IN ('Lfz', 'Sonst.', 'KE', 'oLfz')) AS actuals
			, SUM(b.anwesenheit IN ('Lfz', 'Sonst.', 'KE', 'oLfz') AND (WEEKDAY(ak.bekannt_seit) + DATEDIFF(ak.datum, ak.bekannt_seit) > 19))  AS actuals_geplant   
			, SUM(b.anwesenheit IN ('URL', 'Frei')) AS actuals_URL
         , COUNT(*) AS total_days
         , d.wochenbeginn
      FROM tbl_ueb_fz_buchungen b
      LEFT JOIN tbl_ueb_aend_fz_kalender ak ON b.datum = ak.datum AND b.persnr = ak.persnr
      LEFT JOIN tbl_ueb_personalakte p ON b.PersNr = p.persnr
      LEFT JOIN tbl_stamm_kategorie_abteilung k ON p.taetigkeit = k.`tätigkeit`
     INNER JOIN tbl_datum d ON b.datum = d.datum AND d.arbeitstag = 1
      LEFT JOIN tbl_schichten s ON d.schichtindex = s.schichtindex AND b.schicht = s.schicht AND s.index <= 9
     WHERE k.kategorie = 'Operativ'
       AND b.datum BETWEEN @mindate AND @maxdate -- @forecast_date
     GROUP BY b.datum, p.eg = 'ZAK', ifnull(s.schicht_int, 0)
)
    SELECT a1.datum
	      , a1.schicht
	      , a1.gruppe
	      , a1.schichtgr
	      , CAST((a1.actuals + ifnull(a2.actuals, 0) / 3) / (a1.total_days + ifnull(a2.total_days, 0) / 3) AS DECIMAL(5,4)) AS actuals -- actuals mit 1/3 der unbekannten Schichten
	      , CAST((a1.actuals_geplant + ifnull(a2.actuals_geplant, 0) / 3) / (a1.total_days + ifnull(a2.total_days, 0) / 3) AS DECIMAL(5,4)) AS actuals_geplant
	      , CAST((a1.actuals_URL + ifnull(a2.actuals_URL, 0) / 3) / (a1.total_days + ifnull(a2.total_days, 0) / 3) AS DECIMAL(5,4)) AS actuals_URL
	      , a1.total_days + ifnull(a2.total_days, 0) / 3 AS total_days
	      , CASE WHEN YEARWEEK(a1.datum, 3) <= YEARWEEK(@forecast_date, 3) 
		          THEN CASE WHEN a1.wochenbeginn = 0
                          THEN 1
                          ELSE 0.8 END
		          WHEN YEARWEEK(a1.datum, 3) = YEARWEEK(@forecast_date + INTERVAL 7 day, 3) THEN 0.8
                WHEN YEARWEEK(a1.datum, 3) = YEARWEEK(@forecast_date + INTERVAL 14 day, 3) THEN 0.4
                ELSE 0 END AS w_lag
	      , CAST(IFNULL(dc.decay, IF(a1.datum > @forecast_date, 1, 0)) AS DECIMAL(5,4)) AS decay
	      , f2.soll
	   FROM actuals a1
	   LEFT JOIN actuals a2 ON a1.datum = a2.datum AND a1.gruppe = a2.gruppe AND a2.schicht = 0 -- 1/3 der unbekannten Schichten aufteilen
		LEFT JOIN decay dc ON a1.datum = dc.datum AND a1.Schicht = dc.schicht
      LEFT JOIN fanf2 f2 ON a1.datum = f2.datum AND a1.schicht = f2.schicht AND a1.gruppe = 'DPW'
	  WHERE a1.schicht <> 0
        ON DUPLICATE KEY UPDATE
           schichtgr = VALUES(schichtgr)
         , actuals = VALUES(actuals)
         , actuals_geplant = VALUES(actuals_geplant)
         , actuals_URL = VALUES(actuals_URL)
         , total_days = VALUES(total_days)
         , w_lag = VALUES(w_lag)
         , decay = VALUES(decay)
         , soll = VALUES(soll)
;
-- Trend berechnen
    UPDATE tbl_ueb_fz_forecast ex
       SET ex.trend = CAST((
                SELECT SUM(actuals * total_days) / SUM(total_days)
                  FROM tbl_ueb_fz_forecast
                 WHERE datum BETWEEN ex.datum - INTERVAL 182 DAY -- CMA +- 6 Monate
                                 AND ex.datum + INTERVAL 182 DAY
                   AND gruppe = ex.gruppe
            ) AS DECIMAL(5,4))
        WHERE ex.datum <= @forecast_date - INTERVAL 182 DAY
;
-- Trend Forecast berechnen
UPDATE tbl_ueb_fz_forecast ex
LEFT JOIN (SELECT l1.gruppe
			       ,	l2.trend AS trend_last_day
                , l2.datum AS trend_last_day_date
                , POWER(l2.trend / l1.trend, 1/91) AS trend_ratio
        FROM 
            (SELECT @forecast_date - INTERVAL 273 DAY as datum, gruppe, AVG(trend) AS trend 
             FROM tbl_ueb_fz_forecast 
             WHERE datum = (SELECT MAX(d.datum) FROM tbl_datum d WHERE d.arbeitstag = 1 AND d.datum <= @forecast_date - INTERVAL 273 DAY)
             GROUP BY gruppe) l1
        LEFT JOIN 
            (SELECT @forecast_date - INTERVAL 182 DAY as datum, gruppe, AVG(trend) AS trend 
             FROM tbl_ueb_fz_forecast 
             WHERE datum = (SELECT MAX(d.datum) FROM tbl_datum d WHERE d.arbeitstag = 1 AND d.datum <= @forecast_date - INTERVAL 182 DAY) 
             GROUP BY gruppe) l2 
        ON l1.gruppe = l2.gruppe
    ) trend_calculation ON ex.gruppe = trend_calculation.gruppe 
SET ex.trend = CAST(
    trend_last_day * POWER(trend_ratio, LEAST(200, datediff(ex.datum, trend_last_day_date)))  AS DECIMAL(5,4))
WHERE ex.datum BETWEEN @forecast_date - INTERVAL 182 DAY AND @forecast_date + INTERVAL 182 DAY
;
    UPDATE tbl_ueb_fz_forecast ex
	    SET ex.detrended = CAST(ex.actuals / ex.trend AS DECIMAL(6,4))
	  WHERE ex.datum < @forecast_date 
	    AND actuals + actuals_URL < 0.6 -- Ausreißer löschen
;

############ SAISONALITÄT ################    
IF (SELECT MAX(last_insert_update) FROM tbl_ueb_fz_saisonalität_woche) < @forecast_date THEN
-- Saisonalität auf Wochenbasis berechnen
    DELETE FROM tbl_ueb_fz_saisonalität_woche
;
    INSERT INTO tbl_ueb_fz_saisonalität_woche(woche, gruppe, total_days, saisonalität)
    SELECT WEEK(datum, 3) AS woche
         , gruppe
         , SUM(total_days) AS total_days
         , CAST(SUM(Detrended * total_days) / SUM(total_days) AS DECIMAL(5,4)) AS saisonalität -- Gewichtung nach Anzahl Mitarbeiter
      FROM tbl_ueb_fz_forecast s -- seasonality s
     WHERE datum < @forecast_date
       AND actuals + actuals_URL < 0.6 -- Ausreißer löschen
     GROUP BY WEEK(datum, 3), gruppe
; 
    UPDATE tbl_ueb_fz_saisonalität_woche ss
      LEFT JOIN (SELECT gruppe, CAST(1 - AVG(saisonalität) AS DECIMAL(5,4)) as bias 
                   FROM tbl_ueb_fz_saisonalität_woche
                  GROUP BY gruppe
                ) s1 ON ss.gruppe = s1.gruppe
       SET ss.saisonalität = CAST(ss.`saisonalität` - s1.bias AS DECIMAL(5,4))
;
-- Saisonalität auf Wochentags- und Schichtbasis berechnen
    DELETE FROM tbl_ueb_fz_saisonalität_schicht
;
    INSERT INTO tbl_ueb_fz_saisonalität_schicht(wochentag, schicht, gruppe, total_days, saisonalität)
    SELECT WEEKDAY(s.datum) AS wochentag
         , s.schicht
         , s.gruppe
         , SUM(total_days) AS total_days
         , CAST(SUM(Detrended * s.total_days) / SUM(s.total_days) AS DECIMAL(5,4)) AS shift_seas
      FROM tbl_ueb_fz_forecast s -- seasonality s
     WHERE datum BETWEEN '2023-02-01' AND @forecast_date - INTERVAL 1 day
       AND WEEKDAY(s.datum) < 5
       AND actuals + actuals_URL < 0.6 -- Ausreißer löschen
     GROUP BY WEEKDAY(datum), gruppe, schicht
; -- Bias entfernen
    UPDATE tbl_ueb_fz_saisonalität_schicht ss
      LEFT JOIN (SELECT gruppe, CAST(1 - AVG(saisonalität) AS DECIMAL(5,4)) as bias 
		             FROM tbl_ueb_fz_saisonalität_schicht
                  GROUP BY gruppe) s1 ON ss.gruppe = s1.gruppe
       SET ss.saisonalität = CAST(ss.`saisonalität` - s1.bias AS DECIMAL(5,4))
;

END IF;

-- Initialen Forecast berechnen
    UPDATE tbl_ueb_fz_forecast a
      LEFT JOIN tbl_ueb_fz_saisonalität_woche sw ON WEEK(a.datum, 3) = sw.woche AND a.gruppe = sw.gruppe
      LEFT JOIN tbl_ueb_fz_saisonalität_schicht ss ON WEEKDAY(a.datum) = ss.wochentag AND a.gruppe = ss.gruppe AND a.schicht = ss.schicht
      LEFT JOIN ( -- Saisonalität ohne Schicht
		           SELECT wochentag, gruppe, sum(`saisonalität` * total_days) / SUM(total_days) AS saisonalität
		             FROM tbl_ueb_fz_saisonalität_schicht
		            GROUP BY wochentag, gruppe
					 ) s2 ON WEEKDAY(a.datum) = s2.wochentag AND a.gruppe = s2.gruppe AND a.schicht = 0
       SET forecast = CAST(a.trend * sw.saisonalität * IFNULL(ss.saisonalität, s2.saisonalität) AS DECIMAL(4,4))
       WHERE a.datum BETWEEN @mindate AND @maxdate       
;
-- Bias entfernen
     UPDATE tbl_ueb_fz_forecast f
       LEFT JOIN ( 
		              SELECT gruppe
                         , CAST(AVG(forecast - actuals) AS DECIMAL(4,4)) AS bias 
                      FROM tbl_ueb_fz_forecast
                     WHERE datum < @forecast_date
                     GROUP BY gruppe
                 ) b ON f.gruppe = b.gruppe
        SET f.forecast_debiased = CAST(f.forecast - b.bias AS DECIMAL(5,4))
      WHERE f.datum BETWEEN @mindate AND @maxdate
;
     UPDATE tbl_ueb_fz_forecast f        
        SET f.fc_error = CAST(IF(f.forecast_debiased <= 0, 1, LEAST(f.actuals / f.forecast_debiased, 9.9)) AS DECIMAL (5,4))       
      WHERE f.datum BETWEEN @mindate AND @maxdate
;
-- lag error term
     UPDATE tbl_ueb_fz_forecast f
       LEFT JOIN tbl_datum d ON f.datum = d.datum  
       LEFT JOIN ( SELECT datum
                        , schicht
                        , schichtgr
								, gruppe
								, LAG(fc_error) OVER (PARTITION BY gruppe, schichtgr ORDER BY datum) AS lagged_error
							FROM tbl_ueb_fz_forecast
							WHERE actuals + actuals_URL < 0.6) f2 -- überspringe Error bei Ausreißern
			ON f.schichtgr = f2.schichtgr AND f.gruppe = f2.gruppe
		  AND f2.datum = CASE WHEN f.datum BETWEEN @forecast_date AND @forecast_date + INTERVAL 21 DAY -- letzter Error für nächste 21 Tage
		                      THEN CASE WHEN @forecast_time < '14:05:00' AND f2.schicht = 3 -- Sonderfall heutige Spätschicht
		                                 THEN @forecast_date
		                                WHEN f.datum = @forecast_date
		                                 THEN f.datum
		                                 ELSE (SELECT MIN(datum) FROM tbl_datum WHERE arbeitstag = 1 AND datum > @forecast_date)
		                           END
		                      WHEN f.datum < @forecast_date
									 THEN f.datum
		                 END
        SET f.lagged_error = CAST(IF(f.datum > @forecast_date + INTERVAL 21 DAY, 1 , IFNULL(f2.lagged_error, 1)) AS DECIMAL(5,4))
      WHERE f.datum BETWEEN @mindate AND @maxdate
;
     UPDATE tbl_ueb_fz_forecast f
        SET f.forecast_lagged = CAST(f.forecast_debiased * POW(f.lagged_error, f.w_lag) AS DECIMAL(5,4))	   
      WHERE f.datum BETWEEN @mindate AND @maxdate
;
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
       LEFT JOIN tbl_ueb_personalakte p ON b.PersNr = p.persnr
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
