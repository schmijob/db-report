-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_buchungen.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_buchungen`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_buchungen`(IN `mindate` date, IN `maxdate` date)
SQL SECURITY DEFINER BEGIN
######## zusammenfassen von Fehlzeiten, Buchungen, Urlaubsvorschau, Änderungen in tbl_ueb_fz_buchungen	
		
		SELECT TIME(filedate) INTO @filedate FROM tbl_import_buchungen_mitarbeiter LIMIT 1;
		SET @mindate = mindate;
--		SET @mindate = CURDATE() - INTERVAL 14 DAY;
      SET @maxdate = maxdate;
--		SET @maxdate = CURDATE() + INTERVAL 60 DAY;
		
		DROP TEMPORARY TABLE IF EXISTS tmp_fz_buchungen
		;
		
  		CREATE TEMPORARY TABLE tmp_fz_buchungen AS SELECT * FROM tbl_ueb_fz_buchungen LIMIT 0
		;
		
		INSERT IGNORE INTO tmp_fz_buchungen (persnr, datum, `status`, schichtgruppe, kommen, schicht, minuten, anwesenheit, tp, filedate)
		
		WITH fehlzeiten AS (                
		
		SELECT persnr, datum, ifnull(fz, tp) AS abwesenheitsgrund, tp, filedate
		 FROM tbl_ueb_fz_personalkalender
		WHERE datum BETWEEN @mindate AND @maxdate

		UNION DISTINCT 
				SELECT 
					s.persnr, d.datum, IF(d.arbeitstag = 1 , '*' , '') AS abwesenheitsgrund, NULL,  NULL
				FROM 
					tbl_stamm_persnr s 																-- Virtuelle Urlaubsvorschau für manuell überschriebenes Enddatum
				LEFT JOIN 
					tbl_datum d ON d.datum > s.uebernahme_am -- s.ende
				WHERE d.datum BETWEEN @mindate AND @maxdate AND s.uebernahme_am >= CURDATE()
		UNION DISTINCT 
				SELECT 
					s.persnr, d.datum, IF(d.arbeitstag = 1 , '*' , '') AS abwesenheitsgrund, NULL, p.filedate
				FROM 
					tbl_ueb_personalakte_scd s 															-- Virtuelle Urlaubsvorschau für ZAK nach 3 Monaten Probezeit
				LEFT JOIN 
					tbl_import_personalakte p ON p.pers_nr = s.persnr
				LEFT JOIN 
					tbl_datum d ON d.datum BETWEEN NULLIF(p.ende_besch, '9999-12-31') + INTERVAL 1 day AND s.ende
					           AND d.datum BETWEEN s.gueltig_von AND s.gueltig_bis
				WHERE 
					d.datum BETWEEN @mindate AND @maxdate AND p.ende_besch > CURDATE()
		UNION DISTINCT
				SELECT 
					s.persnr, d.datum, IF(d.arbeitstag = 1 , '*' , '') AS abwesenheitsgrund, NULL, s.filedate
				FROM 
					tbl_ueb_personalakte_scd s 															-- Virtuelle Urlaubsvorschau für neu angelegte MA
				LEFT JOIN 
					tbl_ueb_fz_personalkalender u ON u.persnr = s.persnr
				LEFT JOIN 
					tbl_datum d ON d.datum BETWEEN s.beginn AND s.ende
					           AND d.datum BETWEEN s.gueltig_von AND s.gueltig_bis
				WHERE 
					u.datum IS NULL AND d.datum BETWEEN @mindate AND @maxdate AND s.ende > CURDATE() -- AND s.pdl IS NULL				
		),
		
		Stage1 AS (               -- modifiziert Status
		SELECT 
		    f.persnr,
		    f.datum, 
		    CASE 
		    	  WHEN ag.anwesenheit = 'anw' AND f.datum = CURDATE() AND @filedate > ag.sollzeit AND bu.kommen IS null THEN '~' -- Unerlaubt keine Buchung
		        WHEN bu.minuten IS NULL AND time(bu.kommen) > 0 AND bu.status = '' AND bu.bg = 'Ko' and f.datum = CURDATE() THEN COALESCE(bu.tp, f.tp, '*')
				  WHEN bu.minuten IS NOT NULL THEN
		        		CASE WHEN f.abwesenheitsgrund = 'WEG' THEN 'WEG'                                      -- Wiedereingliederung
		        		     WHEN COALESCE(afz2.wert, bu.tp) = 'PV' AND COALESCE(bu.schicht, NULLIF(ag.schicht, ''), s.schicht, '') = 'Früh' THEN 'F4' -- verhindert duplizierung von PV durch falschen TP
						     WHEN bu.minuten > 120 OR (k.kategorie = 'admin' AND f.datum = CURDATE()) THEN COALESCE(bu.tp, f.tp, '*')                     -- war da
						     WHEN bu.Minuten = 0 AND TIME(bu.kommen) <> 0 AND f.datum = CURDATE() THEN COALESCE(bu.tp, f.tp, '*') -- Fehlzeit und trotzdem da
		        			  ELSE '*-'																							-- war weniger als 2h da. Nicht für Admins am laufenden Tag (Raucherpausen)
						END                                 
		        WHEN month(d.datum) = 12 AND DAY(d.datum) IN (24, 31) THEN 'H/S'                     -- Heiligabend/Silvester 
				  WHEN d.arbeitstag = 0 THEN
		        		IF(ag.anwesenheit <> 'anw' AND ag.anwesenheit <> 'Frei', '', f.abwesenheitsgrund)  -- löscht Abwesenheiten an Nichtarbeitstagen
		        WHEN bu.bg = 'Tag' AND bu.filedate > greatest(ifnull(afz.bekannt_seit, DATE(0)), f.filedate) AND ifnull(afz.wert, 0) <> 'KE-a' then bu.`Status`
		        WHEN afz.bekannt_seit > f.filedate THEN afz.wert												  -- Status aus neuesten Änderungen
		        WHEN afz.wert = 'KE-a' THEN 'KE-a'																  -- Ausgeplant aus Änderungen
				  ELSE f.abwesenheitsgrund                                             					  -- Status Fehlzeiten
		    END AS `status`,
		    p.schichtgruppe,
			 bu.kommen,
		    COALESCE(bu.schicht, NULLIF(ag.schicht, ''), s.schicht, '') AS schicht,  -- priorisiert Schicht aus Stechzeit, Tagesplan, Schichtgruppe
		    COALESCE(bu.minuten, 0) AS minuten, -- trägt 0 ein, wenn keine Minuten hinterlegt sind
			 COALESCE(afz2.wert, bu.tp, f.tp) AS tp,
		    GREATEST(coalesce(afz2.filedate, 0), coalesce(afz.filedate, 0), coalesce(f.filedate, 0)) AS filedate                           

		    
		FROM 
			fehlzeiten f
		LEFT JOIN 
		    tbl_ueb_personalakte_scd p ON f.persnr = p.persnr
		                          AND f.datum BETWEEN p.gueltig_von AND p.gueltig_bis
		LEFT JOIN
			tbl_stamm_persnr sp ON sp.persnr = p.persnr
		INNER JOIN 
		    tbl_datum d ON f.datum = d.datum AND (d.datum between COALESCE(p.beginn , '0000-00-00') AND COALESCE(p.ende, '9999-12-31') OR d.datum >= sp.uebernahme_am )
		LEFT JOIN 
		    tbl_ueb_buchungen bu ON f.persnr = bu.persnr AND f.datum = bu.datum
		LEFT JOIN
			 tbl_ueb_aend_fz_kalender afz ON f.persnr = afz.persnr AND f.datum = afz.datum AND afz.feld = 'fehlzeit'
		LEFT JOIN
			 tbl_ueb_aend_fz_kalender afz2 ON f.persnr = afz2.persnr AND f.datum = afz2.datum AND afz2.feld = 'tagesplan'			 
		LEFT JOIN 
		    tbl_abwesenheitsgrund ag ON if(afz.bekannt_seit > f.filedate, afz.wert, f.abwesenheitsgrund) = ag.kuerzel
		LEFT JOIN 
		    tbl_schichten s ON d.schichtindex = s.schichtindex AND p.schichtgruppe = s.schichtgruppe
		LEFT JOIN 
			 tbl_stamm_kategorie_abteilung k ON k.`tätigkeit` = p.taetigkeit 
		    
	   ),
	   Stage2 AS(
	   SELECT 
			f.persnr,
			f.datum,
			f.`status`,
			f.schichtgruppe,
			CASE WHEN ag.anwesenheit = 'anw' OR f.`status` = '*-' THEN f.kommen END AS kommen,
			coalesce(ag2.schicht, f.schicht) AS schicht,
			f.minuten,
		   COALESCE(ag.anwesenheit, 'Frei') AS anwesenheit,
		   CASE WHEN f.`status` = 'F4' THEN 'F4' ELSE f.tp END AS tp,
		   f.filedate
		FROM 
			Stage1 f
		LEFT JOIN 
		    tbl_abwesenheitsgrund ag ON f.`status` = ag.kuerzel
		LEFT JOIN 
		    tbl_abwesenheitsgrund ag2 ON CASE WHEN f.`status` = 'F4' THEN 'F4' ELSE f.tp END = ag2.kuerzel AND ag2.feld = 'tagesplan'
		),

		7000er AS (
			SELECT * 
			FROM Stage2 
			WHERE persnr BETWEEN 7000 AND 8000
			AND `status` NOT IN ('S38', 'F38', 'N38', 'Sam', '')
			OR `status` IN ('PV', 'S+N')
		),
		
		stammschichten AS (
			SELECT persnr, MIN(datum) AS datum, schicht 
			FROM (
				SELECT persnr, datum, 'Früh' COLLATE utf8mb4_unicode_ci AS schicht FROM 7000er WHERE `status` = 'F4' OR schicht = 'Früh'
				UNION ALL
			   SELECT persnr, datum, 'Spät' COLLATE utf8mb4_unicode_ci AS schicht FROM 7000er WHERE `status` = 'S4'
			   UNION ALL
			   SELECT persnr, datum, 'Nacht' COLLATE utf8mb4_unicode_ci AS schicht  FROM 7000er WHERE `status` IN ('PV', 'S+N') OR schicht = 'Nacht' 
			) s
		   GROUP BY s.persnr, s.schicht
		),	
	
		7000er_Schicht AS ( -- Alle Buchungen, ersetzt Null-Schichten durch die Stammschicht.
			SELECT 
				e.persnr, 
				e.datum, 
				e.`status`, 
				e.schichtgruppe, 
				e.kommen, 
				COALESCE(nullif(e.Schicht, ''), s.Schicht, '') AS schicht, 
				e.minuten, 
				e.anwesenheit, 
				e.tp,
				e.filedate,
				s.schicht AS stamm
			FROM 
				7000er e
			LEFT JOIN 
				stammschichten s
				ON e.persnr = s.persnr 
				AND s.datum = COALESCE(
										(SELECT MAX(s2.datum) FROM Stammschichten s2 WHERE s2.persnr = e.persnr AND s2.datum <= e.datum), 
										(SELECT MIN(s3.datum) FROM Stammschichten s3 WHERE s3.persnr = e.persnr)
									)
			
		),
		
		virtuelle_Nachtschicht AS ( -- Dupliziert Alle Nacht-Stammschichten, für die es keine Spät-Buchung gibt
			SELECT 
				e.persnr, 
				e.datum, 
				e.`status`, 
				e.schichtgruppe, 
				NULL AS kommen, 
				'Spät' COLLATE utf8mb4_unicode_ci AS schicht, 
				0 AS minuten, 
				e.anwesenheit,
				e.tp,
				e.filedate
				-- e.stamm
			FROM 
				7000er_Schicht e
			LEFT JOIN 
				7000er_Schicht e2 ON e2.Schicht = 'Spät' AND e.persnr = e2.persnr AND e.datum = e2.datum
			WHERE e.stamm = 'Nacht' AND e.anwesenheit <> 'Frei' and e2.Schicht is NULL
         AND e.datum >= CURDATE()
		)	
		
	
		SELECT 
			persnr, datum, `status`, schichtgruppe, kommen, schicht, minuten, anwesenheit, tp, filedate
		FROM 
			7000er_Schicht
		UNION ALL 
			SELECT * FROM virtuelle_Nachtschicht
		UNION ALL 
			SELECT * FROM Stage2 WHERE persnr < 7000 OR persnr > 8000 AND `status` <> 'PV' OR `status` IN ('S38', 'F38', 'N38', 'Sam', '')
		
		;
		CALL schreibe_log("proc_ueb_fz_buchungen", 'tmp ready', 0);
		
/*		SELECT group_concat(persnr, ', ') INTO @dupes FROM tmp_fz_buchungen GROUP BY persnr, datum, schicht HAVING COUNT(*) > 1;
		
		IF @dupes IS NOT NULL THEN
	    CALL proc_fehler_log(
	      NOW(),
	      'duplicate_buchungen',
	      'ERROR',
	      null,
	      'tbl_ueb_fz_buchungen',
	      null,
	      @dupes,
	      null,
	      null
	    );
	  END IF;
*/				
--		START TRANSACTION
--		;
		
		INSERT IGNORE INTO tbl_ueb_fz_buchungen (persnr, datum, `status`, schichtgruppe, kommen, schicht, minuten, anwesenheit, tp, filedate)
  		SELECT persnr, datum, `status`, schichtgruppe, kommen, schicht, minuten, anwesenheit, tp, filedate
  		FROM tmp_fz_buchungen
  		ON DUPLICATE KEY UPDATE
	      `status`      = VALUES(`status`)
	    , schichtgruppe = VALUES(schichtgruppe)
	    , kommen        = VALUES(kommen)
	    , minuten       = VALUES(minuten)
	    , anwesenheit   = VALUES(anwesenheit)
	    , tp            = VALUES(tp)
	    , filedate      = VALUES(filedate)
		;
		

    
 --     COMMIT
--		;
      
      DELETE t
  		FROM tbl_ueb_fz_buchungen t
  		LEFT JOIN tmp_fz_buchungen s ON s.persnr = t.persnr AND s.datum  = t.datum AND s.schicht = t.schicht
  		WHERE t.datum BETWEEN @mindate AND @maxdate AND s.persnr IS NULL
		;
      
      DROP TEMPORARY TABLE tmp_fz_buchungen
		;
		
		CALL schreibe_log("proc_ueb_fz_buchungen", 'ende', 0);
		

		
END//
