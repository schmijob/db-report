-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    DECLARE var_maxdate DATE;

    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
    CREATE TEMPORARY TABLE tmp_personalakte_import LIKE tbl_import_personalakte;

    IF COALESCE(@personalakte_scd_backfill, 0) = 1 THEN
        IF @personalakte_scd_backfill_date IS NULL THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Set @personalakte_scd_backfill_date before replaying a personalakte snapshot';
        END IF;

        IF NOT EXISTS (
            SELECT 1
              FROM tbl_import_personalakte_scd_backfill
             WHERE filedate >= DATE(@personalakte_scd_backfill_date)
               AND filedate < DATE_ADD(DATE(@personalakte_scd_backfill_date), INTERVAL 1 DAY)
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'No staged personalakte snapshot exists for the requested date';
        END IF;

        IF EXISTS (
            SELECT pers_nr
              FROM tbl_import_personalakte_scd_backfill
             WHERE filedate >= DATE(@personalakte_scd_backfill_date)
               AND filedate < DATE_ADD(DATE(@personalakte_scd_backfill_date), INTERVAL 1 DAY)
             GROUP BY pers_nr
            HAVING COUNT(*) > 1
        ) THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'A staged personalakte snapshot contains duplicate personnel numbers';
        END IF;

        INSERT INTO tmp_personalakte_import
        SELECT *
          FROM tbl_import_personalakte_scd_backfill
         WHERE filedate >= DATE(@personalakte_scd_backfill_date)
           AND filedate < DATE_ADD(DATE(@personalakte_scd_backfill_date), INTERVAL 1 DAY);
    ELSE
        INSERT INTO tmp_personalakte_import
        SELECT * FROM tbl_import_personalakte;
    END IF;
    
    -- Prüfung, ob neue Änderungen vorhanden sind
    SELECT MAX(filedate) INTO var_filedate FROM tmp_personalakte_import imp;
    SELECT MAX(datum) INTO var_maxdate FROM tbl_datum;
    
	 IF var_filedate IS NOT NULL
	    AND (
	        COALESCE(@personalakte_scd_backfill, 0) = 1
	        OR NOT EXISTS (
	        SELECT 1
	          FROM tbl_ueb_personalakte ueb
	         WHERE ueb.filedate = var_filedate
	        )
	    ) THEN
	 	-- Personalakte übertragen
		INSERT INTO tbl_ueb_personalakte (persnr, `name`, pdl, oe, schichtgruppe, eg, beginn, ende, taetigkeit, team, br, übernahme, taetigkeit2, funktion, filedate)
		
		-- In Zeus gelöschte MA (=kein Enddatum) rausfiltern
		WITH personalakte AS (
		    SELECT p.pers_nr
				 , REGEXP_REPLACE(p.name_vorname, '^[0-9]{2}\.[0-9]{2}\.[0-9]{2} ', '') AS name_vorname
				 , p.zeitarbeitsfirma
				 , TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' from p.oe_der_person)) AS oe_der_person
				 , p.schicht
				 , COALESCE(NULLIF(p.info,  ''), IF(p.pers_nr < 95000, 'ZAK', 'DPW')) AS info
				 , p.beginn_besch -- COALESCE(b.beginn, p.beginn_besch) AS beginn_besch
				 , TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' from p.taetigkeit)) AS taetigkeit
				 , CASE WHEN p.team IN ('8', '9', '10') THEN '' ELSE TRIM(BOTH ' ' FROM TRIM(BOTH '\r\n' from p.team)) END AS team
				 , p.betriebsrat
				 , p.filedate 
			    		   -- Bei ZAK verlängere 3 Monate 'Probezeit'-Befristung auf 15 Monate 
				   , CASE WHEN p.info = 'ZAK' AND p.ende_besch > DATE(var_filedate) AND p.ende_besch BETWEEN p.beginn_besch + INTERVAL 80 DAY AND p.beginn_besch + INTERVAL 100 DAY
			    		  THEN p.beginn_besch + INTERVAL 15 MONTH
			    		  ELSE p.ende_besch -- COALESCE(b.ende, p.ende_besch) 
					END AS ende_besch
				 , p.taetigkeit2
				 , p.funktion
			 FROM tmp_personalakte_import p
		--	 LEFT JOIN tbl_uebertrag_aenderungen_beginn_ende b ON p.pers_nr = b.persnr
			 WHERE p.ende_besch IS NOT NULL AND p.ende_besch <> '2022-07-31'
		    AND beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		      
		)
		-- Bereinige Personalakte und suche übernommene ZAK (neuer Eintrag mit gleichem Namen)
		SELECT p1.pers_nr AS persnr 
			, p1.name_vorname AS `name` 
			, p1.zeitarbeitsfirma AS pdl 
			, CASE WHEN p1.betriebsrat = 'Freigestellt' THEN 'Freigestellter BR'																		-- OE der Person:
					 WHEN p1.team LIKE '%BGL%' THEN 'BGL'						-- 'BGL' aus Team
					 WHEN p1.oe_der_person = 'alle ausgeschiedenen MAInnen' AND p1.team REGEXP '^[A-Z]-[A-Z]+-[0-9]+$'
					      THEN REGEXP_REPLACE(p1.team, '^[A-Z]-([A-Z]+)(?:-[0-9]+)?$', '\1')
					 WHEN p1.oe_der_person = 'alle ausgeschiedenen MAInnen' THEN ''
					 ELSE COALESCE(pt.oe, ot.OE_neu, p1.oe_der_person) 		-- OE aus tbl_stamm_persnr (persönliche Ersetzungstabelle), tbl_stamm_OE_translate (OE-Ersetzungstabelle) oder original
			  END AS OE 
			, p1.schicht AS schichtgruppe 
			, p1.info AS eg 														-- Endgeltgruppe
			, p1.beginn_besch AS beginn 
			, CASE WHEN DATE(coalesce(pt.ende, p1.ende_besch)) > var_maxdate THEN DATE(coalesce(pt.ende, p1.ende_besch))							-- nach 2025: Ende Beschäftigung aus tbl_stamm_persnr oder Original
					 ELSE (SELECT MAX(d.datum) FROM tbl_datum d WHERE d.arbeitstag = 1 AND DATE(d.datum) <= DATE(coalesce(pt.ende, p1.ende_besch)))  -- ersetzt Ende Beschäftigung durch letzten gültigen Arbeitstag
			  END AS ende
			, CASE WHEN p1.betriebsrat = 'Freigestellt' THEN 'Freigestellter BR'                             -- BR
					 WHEN p1.pers_nr BETWEEN 7000 AND 7999 THEN 'Pausenvertretung'  											-- Pausenvertretung
					 WHEN ot.OE_neu = 'QS' AND coalesce(tt.taetigkeit_neu, p1.taetigkeit) = 'Lagerhelfer' then 'QS' -- QS-Mitarbeiter
					 ELSE COALESCE(pt.taetigkeit, tt.taetigkeit_neu, p1.taetigkeit) 											-- Tätigkeit aus persönlicher Ersetzungstabelle, Tätigkeit-Übersetzungstabelle oder Original
			  END AS Tätigkeit 
			, p1.team AS Team
			, p1.betriebsrat AS BR
			, MAX(CASE WHEN p2.beginn_besch - INTERVAL 60 day BETWEEN p1.ende_besch   - INTERVAL 60 DAY AND p1.ende_besch   THEN 1		-- ZAK, der übernommen wurde (keine Fluktuation)
					     WHEN p2.ende_besch                     BETWEEN p1.beginn_besch - INTERVAL 60 DAY AND p1.beginn_besch THEN 2 							-- fester MA, der vorher ZAK war (kein Onboarding)
					     ELSE 0 																																		-- keine Übernahme
		  	  END) AS Übernahme	
			, p1.taetigkeit2
			, p1.funktion																														-- hier wird das Original-Enddatum genommen
			, p1.filedate
						 
		FROM personalakte p1 
		LEFT JOIN tbl_stamm_OE_translate ot ON p1.oe_der_person = ot.OE_alt  								-- Übersetzungstabelle für OE der Person
		LEFT JOIN tbl_stamm_taetigkeit_translate tt ON p1.taetigkeit = tt.taetigkeit_alt 				-- Übersetzungstabelle für Tätigkeit
		LEFT JOIN tbl_stamm_persnr pt ON p1.pers_nr = pt.persnr 												-- Ersetzungen für Einzelpersonen
		LEFT JOIN personalakte p2																						-- Sucht nach Übernahmen über Name + 1. Vorname
			ON   CONCAT(SUBSTRING_INDEX(p1.name_vorname, ', ', 1), ', ', SUBSTRING_INDEX(SUBSTRING_INDEX(p1.name_vorname, ', ', -1), ' ', 1)) 
			   = CONCAT(SUBSTRING_INDEX(p2.name_vorname, ', ', 1), ', ', SUBSTRING_INDEX(SUBSTRING_INDEX(p2.name_vorname, ', ', -1), ' ', 1))
			AND p1.pers_nr <> p2.pers_nr
		GROUP BY p1.pers_nr
		ON DUPLICATE KEY 
		UPDATE `name` = VALUES(`name`)
			  , pdl = VALUES(pdl)
			  , oe = IF(VALUES(oe) = '', oe, VALUES(oe))
			  , schichtgruppe = VALUES(schichtgruppe)
			  , eg = VALUES(eg)
			  , beginn = VALUES(beginn)
			  , ende = VALUES(ende)
			  , taetigkeit = VALUES(taetigkeit)
			  , team = VALUES(team)
			  , br = VALUES(br)
			  , übernahme = VALUES(übernahme)
			  , taetigkeit2 = VALUES(taetigkeit2)
			  , funktion = VALUES(funktion)
			  , filedate = VALUES(filedate)

		;

		CALL proc_ueb_personalakte_scd_snapshot_sync(DATE(var_filedate));

		IF COALESCE(@personalakte_scd_backfill, 0) = 0 THEN
			CALL proc_ueb_personalakte_scd_reconcile();
				
				
				-- übernommene ZAK aus Verlängerungsliste (=tbl_stamm_persnr ersetzt Ende Beschäftigung) löschen
		DELETE s FROM tbl_stamm_persnr s
		LEFT JOIN tbl_ueb_personalakte p ON s.persnr = p.persnr
		WHERE p.`übernahme` = 1;
				-- Geplante Verlängerungen aus Verlängerungsliste löschen
		DELETE s FROM tbl_stamm_persnr s
		LEFT JOIN tmp_personalakte_import p ON s.persnr = p.pers_nr
		WHERE p.ende_besch = s.ende;
		
		-- neue MA aus Personalakte in Buchungen anlegen
		INSERT INTO tbl_ueb_fz_join (persnr, datum, pa_fz, pa_taetigkeit, pa_oe, pa_schichtgr, pa_filedate, last_insert_update)
		SELECT persnr
		     , datum
		     , IF(arbeitstag = 1, '*', '') AS pa_fz
		     , taetigkeit
		     , oe
		     , schichtgruppe
		     , filedate
		     , NOW() AS last_insert_update
		  FROM (
		        SELECT p.persnr
		             , d.datum
		             , d.arbeitstag
		             , p.taetigkeit
		             , p.oe
		             , p.schichtgruppe
		             , p.filedate
		          FROM tbl_ueb_personalakte_scd p
		          JOIN tbl_datum d
		            ON d.datum BETWEEN p.beginn AND p.ende
		           AND d.datum BETWEEN p.gueltig_von AND p.gueltig_bis
		         WHERE d.datum BETWEEN CURDATE() - INTERVAL 7 DAY
		                           AND CURDATE() + INTERVAL 90 DAY
		       ) x
		
		ON DUPLICATE KEY UPDATE
		      pa_fz               = VALUES(pa_fz)
		    , pa_taetigkeit       = VALUES(pa_taetigkeit)
		    , pa_oe               = VALUES(pa_oe)
		    , pa_schichtgr        = VALUES(pa_schichtgr)
		    , pa_filedate         = VALUES(pa_filedate)
		    , last_insert_update  = IF( pa_fz <> VALUES(pa_fz)
	    								      , NOW()
											   , last_insert_update
											   )  
		;
		
		-- ZAK Probezeitverlängerung
		INSERT INTO tbl_ueb_fz_join (persnr, datum, pa_fz, pa_filedate)
		
		SELECT s.persnr
		     , d.datum
		     , IF(d.arbeitstag = 1, '*', '')
		     , p.filedate
		  FROM tbl_ueb_personalakte_scd s
		  JOIN tmp_personalakte_import p ON p.pers_nr = s.persnr
		  JOIN tbl_datum d ON d.datum BETWEEN NULLIF(p.ende_besch, '9999-12-31') + INTERVAL 1 DAY
		                                  AND s.ende
		                  AND d.datum BETWEEN s.gueltig_von AND s.gueltig_bis
		 WHERE d.datum BETWEEN CURDATE() - INTERVAL 7 DAY
		                   AND CURDATE() + INTERVAL 90 DAY
		   AND p.ende_besch > CURDATE()
		
		ON DUPLICATE KEY UPDATE
		      pa_fz               = VALUES(pa_fz)
		    , pa_filedate         = VALUES(pa_filedate)
		    , last_insert_update  = IF( pa_fz <> VALUES(pa_fz)
	    								      , NOW()
											   , tbl_ueb_fz_join.last_insert_update
											   )  
		;


		UPDATE tbl_ueb_fz_join j
		
		LEFT JOIN (
		    SELECT p.persnr
		         , d.datum
		      FROM tbl_ueb_personalakte_scd p
		      JOIN tbl_datum d
		        ON d.datum BETWEEN p.beginn AND p.ende
		       AND d.datum BETWEEN p.gueltig_von AND p.gueltig_bis
		     WHERE d.datum >= CURDATE() - INTERVAL 60 DAY
		) p
		       ON p.persnr = j.persnr
		      AND p.datum  = j.datum
		
		SET
		      j.pa_fz              = 'XXX'
		    , j.pa_taetigkeit      = NULL
		    , j.pa_oe              = NULL
		    , j.pa_schichtgr       = NULL
		    , j.pa_filedate        = v_filedate
          , j.last_insert_update = NOW()
		
		WHERE j.datum >= CURDATE() - INTERVAL 60 DAY
		  AND p.persnr IS NULL
		  AND j.pa_filedate IS NOT NULL
		  AND j.pa_fz <> 'XXX'
		;


		CALL proc_ueb_fz_geister_loeschen();
		END IF;
			 	
	END IF;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
END//
