-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_buchungen.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_buchungen`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_buchungen`()
SQL SECURITY DEFINER BEGIN
/* Test Dataset:
SELECT * FROM tbl_uebertrag_buchungen_mitarbeiter b
WHERE 0
   OR ( b.pers_nr = 91789    AND date(b.datum) = '2025-04-29' ) -- Ibrahimova, Allie         Normale schicht, dfbg = 0
   OR ( b.pers_nr = 36101962 AND date(b.datum) = '2024-11-26' ) -- Seyffart, Stephanie       Raucherpausen
   OR ( b.pers_nr = 36101671 AND date(b.datum) = '2024-07-01' ) -- Domann, Edgar Dean        Fehlzeit + Kommen am selben tag
   OR ( b.pers_nr = 91823    AND DATE(b.datum) = '2024-03-26' ) -- Majdosz, Tomasz           Zeit ohne -
   OR ( b.pers_nr = 36104224 AND DATE(b.datum) = '2025-06-24' ) -- Horn, Anna-Maria          Ko - Ko - Ge Sequenz 
   OR ( b.pers_nr = 91743    AND DATE(b.datum) = '2024-12-09' ) -- Bykova, Anjela            Ko ohne folgendes Ge 
   OR ( b.pers_nr = 36102005 AND DATE(b.datum) = '2022-09-11' ) -- Wege, Christina           Ge ohne vorheriges Ko  
   OR ( b.pers_nr = 36102250 AND DATE(b.datum) = '2023-03-02' ) -- Finder, Rommy Hannelore   13 Stunden Tag
   OR ( b.pers_nr = 7063     AND DATE(b.datum) = '2024-10-04' ) -- Dobroc, Daria Patrycja    Normale Pausenvertretung
*/
 -- view_buchungen_kommen_all
DECLARE p_mindate DATE;
DECLARE p_maxdate DATE;
DECLARE v_filedate DATETIME;
SELECT MIN(date(datum)) INTO p_mindate FROM tbl_import_buchungen_mitarbeiter;
SELECT MAX(date(datum)) + INTERVAL 1 DAY INTO p_maxdate FROM tbl_import_buchungen_mitarbeiter;
SELECT MAX(filedate) INTO v_filedate FROM tbl_import_buchungen_mitarbeiter;

		DELETE FROM tbl_ueb_buchungen WHERE datum BETWEEN p_mindate AND p_maxdate;

		INSERT INTO tbl_ueb_buchungen (PersNr, bg, Datum, `Status`, Kommen, Schicht, Minuten, tp, filedate)
		WITH KoRows AS ( -- Kommen-Buchungen und Tages-Buchungen (Fehlzeiten)
		    SELECT
		        pers_nr,
		        DATE(datum) AS datum,
		        CASE WHEN bg = 'Ko' then datum END AS kommen, -- nullt Buchungszeit für Tagesbuchungen
		        zeit,
		        fz,
		        bg,
		        CASE WHEN bg = 'Ko' THEN                                -- für Kommen-Buchungen, bestimme Schicht aus Buchungszeit
					  CASE WHEN t.schicht <> 'Tag' AND t.schicht IS NOT NULL AND t.kuerzel <> 'PV' THEN t.schicht
					       WHEN EXTRACT(HOUR FROM datum) >= 4 AND EXTRACT(HOUR FROM datum) < 12 THEN 'Früh'
			             WHEN EXTRACT(HOUR FROM datum) >= 12 AND EXTRACT(HOUR FROM datum) < 20 THEN 'Spät'
			             ELSE 'Nacht'
			        END 
			     END AS schicht,
			     t.kuerzel AS tp,
			     
				  filedate 
		    FROM
		        tbl_import_buchungen_mitarbeiter b
		    LEFT JOIN
		    	  (SELECT DISTINCT erklaerung, feld, kuerzel, schicht FROM tbl_abwesenheitsgrund_translate) t ON b.tp = t.erklaerung AND t.feld = 'Tagesplan'
		    WHERE
		        bg IN ('Ko', 'Tag')
				  AND NOT (b.fz = 'SJF' AND b.pers_nr = 36101933 AND DATE(datum) = CURDATE() AND NOT EXISTS (SELECT 1 FROM tbl_stamm_sjf WHERE datum = CURDATE()))    
		),
		NextGe AS (                                                        -- Fügt alle Gehen-Buchungen eines Tages an
		    SELECT
		        k.pers_nr,
		        k.Datum,
		        k.Kommen,
		        g.datum AS gehen,
		        k.zeit,
		        k.fz,
		        k.Schicht,
		        k.bg,
		        g.dfbg,
		        k.tp,
		        k.filedate,
		        ROW_NUMBER() OVER (
		            PARTITION BY k.pers_nr, k.Datum, k.Kommen
		            ORDER BY g.datum
		        ) AS rn
		    FROM
		        KoRows k
		    LEFT JOIN
		        tbl_import_buchungen_mitarbeiter g
		    ON
		        g.pers_nr = k.pers_nr
		        AND g.bg = 'Ge'
		        AND k.bg = 'Ko'
		        AND ( CASE WHEN k.zeit LIKE '_____-' 
				             THEN k.Kommen - INTERVAL 1 DAY   -- bei Nachtschicht wird der Vortag genommen
							    ELSE k.Kommen 
						  END 
						) BETWEEN g.datum - INTERVAL (case when g.zeit LIKE '_____-' then 2 ELSE 1 END) DAY 
						      AND (case when g.zeit LIKE '_____-' then g.datum - INTERVAL 1 day ELSE g.datum END)                                 -- Gehen BETWEEN Kommen AND Kommen +1 (also alle Gehen-Buchungen innerhalb eines Tages), = Kommen BETWEEN Gehen -1 AND Gehen
		
		    ORDER BY k.pers_nr, if(k.fz = 'WEG', 1, k.bg), k.Kommen  -- Sortiert nach PersNr, dann alle WEG Tage, dann Buchungen (Ko > Tag), dann Zeitpunkt um die erste Buchung anzuzeigen. Durch die spätere Gruppierung wird gefiltert.
		)
		
		
		
		SELECT
		    n.pers_nr AS PersNr,
		    n.bg,
		    n.datum,
		    n.fz AS `Status`,
		    COALESCE(n.Kommen, n.datum) AS Kommen,
		    n.Schicht,
		    CASE WHEN TIMESTAMPDIFF( MINUTE
			                        , MIN( CASE WHEN n.zeit LIKE '_____-' 
											            THEN n.Kommen - INTERVAL 1 DAY 
															ELSE n.Kommen 
													 END
												  )
											, MAX( n.gehen )
											) 
											> 1 
					 AND SUM(n.dfbg) = 0 
					THEN 456 -- behebt Bug, wo 0 Minuten trotz gehen Buchung angezeigt werden
		         ELSE SUM(n.dfbg) 
			 END AS Minuten, -- summiert alle Raucherpausen
		    n.tp,
		    n.filedate
		FROM
		    NextGe n
		WHERE
		    n.rn = 1
			 -- AND n.pers_nr =   36101962  -- Test für Raucherpausen
			 -- AND n.pers_nr =   36101671 AND n.Datum BETWEEN DATE('2024-07-01') AND DATE('2024-07-03')  -- Test für Fehlzeit + Kommen an einem Tag
		GROUP BY
		    n.pers_nr,
		    n.Datum,
		   -- n.fz,
		    CASE WHEN n.pers_nr BETWEEN 7000 AND 8000 OR n.tp = 'PV' THEN n.schicht END	    
	;
	
	DELETE FROM tbl_ueb_buchungen_2 WHERE datum BETWEEN CURDATE() - INTERVAL 7 DAY AND CURDATE()
	;
	INSERT INTO tbl_ueb_buchungen_2 (persnr, datum, schicht, tp, kommen, minuten, buchung_status, filedate)
	
	SELECT b.persnr
	     , b.datum
	     , s.schicht_int AS schicht
	     , b.tp
	     , b.kommen
	     , b.minuten
	     , CASE WHEN b.minuten >= 120
	            THEN '*' 					-- anwesend

	            WHEN b.minuten BETWEEN 0 AND 119
	             AND k.kategorie = 'admin'
	             AND b.datum = CURDATE()
	            THEN '*' 					-- Admins today count as present despite short booking time
	
	            WHEN ( b.minuten IS NULL OR b.minuten = 0 )
	             AND b.kommen IS NOT NULL
	             AND b.datum = CURDATE()
	            THEN '*!' 					-- eingestochen
	
	            WHEN b.minuten BETWEEN 1 AND 119
			   THEN '*-' 					-- Früher gegangen
	            
	            ELSE '*-' 					-- incomplete or invalid duration is treated as partial attendance
	       END AS buchung_status
	     , b.filedate
	  FROM vp_buchungen_u b
	  LEFT JOIN vp_personal_u p ON b.persnr = p.persnr
	  LEFT JOIN tbl_stamm_kategorie_abteilung k ON p.taetigkeit = k.`tätigkeit`
	  LEFT JOIN tbl_schichten s ON b.schicht = s.schicht
	                           AND s.index <= 3
	  WHERE b.datum BETWEEN CURDATE() - INTERVAL 7 DAY AND CURDATE()
	    AND b.bg = 'ko'
	;
	
	INSERT INTO tbl_ueb_fz_join (persnr, datum, bu_fz, bu_tp, bu_filedate, last_insert_update)
	WITH buchungen AS (
	SELECT persnr
	     , datum
	     , `status`
	     , tp
	     , filedate
	  FROM tbl_ueb_buchungen
	 WHERE datum BETWEEN p_mindate AND p_maxdate
	)
	
	SELECT persnr
	     , datum
	     , MAX(`status`) AS bu_fz
	     , MAX(tp) AS bu_tp
	     , MAX(filedate) AS bu_filedate
	     , NOW() AS last_insert_update
	  FROM buchungen
	 GROUP BY persnr
	        , datum
	
	ON DUPLICATE KEY UPDATE
	      last_insert_update = IF(    NOT (tbl_ueb_fz_join.bu_fz <=> VALUES(bu_fz))
										 OR NOT (tbl_ueb_fz_join.bu_tp <=> VALUES(bu_tp))
										 OR NOT (tbl_ueb_fz_join.bu_filedate <=> VALUES(bu_filedate))
									   , VALUES(last_insert_update)
									   , tbl_ueb_fz_join.last_insert_update
									   )
	    , bu_fz           = VALUES(bu_fz)
	    , bu_tp           = VALUES(bu_tp)
	    , bu_filedate     = VALUES(bu_filedate)
	;
	
	UPDATE tbl_ueb_fz_join j	
	LEFT JOIN ( SELECT DISTINCT persnr, datum
	              FROM tbl_ueb_buchungen
	             WHERE datum BETWEEN p_mindate AND p_maxdate
	          ) b
	       ON b.persnr = j.persnr
	      AND b.datum  = j.datum	
   SET
	      j.bu_fz               = 'XXX'
	    , j.bu_tp               = NULL
	    , j.bu_filedate         = v_filedate
	    , j.last_insert_update  = NOW()
	
	WHERE j.datum BETWEEN p_mindate AND p_maxdate
	  AND b.persnr IS NULL
	  AND j.bu_filedate IS NOT NULL
	  AND (NOT (j.bu_fz <=> 'XXX') OR j.bu_tp IS NOT NULL)
	;

END//
