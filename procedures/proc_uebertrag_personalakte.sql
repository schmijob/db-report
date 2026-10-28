-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    DECLARE var_maxdate DATE;

    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
    CREATE TEMPORARY TABLE tmp_personalakte_import LIKE tbl_import_personalakte;
    INSERT INTO tmp_personalakte_import
    SELECT * FROM tbl_import_personalakte;
    
    -- Prüfung, ob neue Änderungen vorhanden sind
    SELECT MAX(filedate) INTO var_filedate FROM tmp_personalakte_import imp;
    SELECT MAX(datum) INTO var_maxdate FROM tbl_datum;
    
	 IF var_filedate IS NOT NULL
	    AND NOT EXISTS (
	        SELECT 1
	          FROM tbl_ueb_personalakte ueb
	         WHERE ueb.filedate = var_filedate
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

		-- Compact current source snapshots without writing to the backfill table.
		UPDATE tbl_ueb_personalakte_scd_snapshot s
		LEFT JOIN tmp_personalakte_import i
		  ON i.pers_nr = s.persnr
		 AND i.ende_besch IS NOT NULL
		 AND i.ende_besch <> '2022-07-31'
		 AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		   SET s.gueltig_bis = DATE_SUB(DATE(var_filedate), INTERVAL 1 DAY)
		 WHERE s.gueltig_bis = '9999-12-31'
		   AND s.gueltig_von < DATE(var_filedate)
		   AND i.pers_nr IS NULL;

		UPDATE tbl_ueb_personalakte_scd_snapshot s
		JOIN tbl_ueb_personalakte c
		  ON c.persnr = s.persnr
		 AND DATE(c.filedate) = DATE(var_filedate)
		JOIN tmp_personalakte_import i
		  ON i.pers_nr = c.persnr
		 AND i.ende_besch IS NOT NULL
		 AND i.ende_besch <> '2022-07-31'
		 AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		   SET s.gueltig_bis = DATE_SUB(DATE(var_filedate), INTERVAL 1 DAY)
		 WHERE s.gueltig_bis = '9999-12-31'
		   AND s.gueltig_von < DATE(var_filedate)
		   AND NOT (
		          s.`name`        <=> c.`name`
		      AND (i.gebdatum IS NULL OR i.gebdatum = '0000-00-00' OR s.gebdatum <=> i.gebdatum)
		      AND s.pdl           <=> c.pdl
		      AND s.oe            <=> c.oe
		      AND s.schichtgruppe <=> c.schichtgruppe
		      AND s.eg            <=> c.eg
		      AND s.beginn        <=> c.beginn
		      AND s.ende          <=> c.ende
		      AND s.taetigkeit    <=> c.taetigkeit
		      AND s.team          <=> c.team
		      AND s.br            <=> c.br
		      AND s.übernahme     <=> c.übernahme
		      AND s.taetigkeit2   <=> c.taetigkeit2
		      AND s.funktion      <=> c.funktion
		   );

		UPDATE tbl_ueb_personalakte_scd_snapshot s
		JOIN tbl_ueb_personalakte c
		  ON c.persnr = s.persnr
		 AND DATE(c.filedate) = DATE(var_filedate)
		JOIN tmp_personalakte_import i
		  ON i.pers_nr = c.persnr
		 AND i.ende_besch IS NOT NULL
		 AND i.ende_besch <> '2022-07-31'
		 AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		 AND s.gueltig_von = DATE(var_filedate)
		   SET s.`name` = c.`name`
		     , s.gebdatum = COALESCE(NULLIF(i.gebdatum, '0000-00-00'), s.gebdatum)
		     , s.pdl = c.pdl
		     , s.oe = c.oe
		     , s.schichtgruppe = c.schichtgruppe
		     , s.eg = c.eg
		     , s.beginn = c.beginn
		     , s.ende = c.ende
		     , s.taetigkeit = c.taetigkeit
		     , s.team = c.team
		     , s.br = c.br
		     , s.übernahme = c.übernahme
		     , s.taetigkeit2 = c.taetigkeit2
		     , s.funktion = c.funktion
		     , s.last_insert_update = c.last_insert_update
		     , s.filedate = c.filedate
		     , s.gueltig_bis = '9999-12-31';

		INSERT INTO tbl_ueb_personalakte_scd_snapshot (
		      persnr, gebdatum, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
		    , taetigkeit, team, br, übernahme, taetigkeit2, funktion
		    , last_insert_update, filedate, gueltig_von, gueltig_bis
		)
		SELECT c.persnr, NULLIF(i.gebdatum, '0000-00-00'), c.`name`, c.pdl, c.oe
		     , c.schichtgruppe, c.eg, c.beginn, c.ende, c.taetigkeit, c.team, c.br
		     , c.übernahme, c.taetigkeit2, c.funktion
		     , c.last_insert_update, c.filedate, DATE(var_filedate), '9999-12-31'
		  FROM tbl_ueb_personalakte c
		  JOIN tmp_personalakte_import i
		    ON i.pers_nr = c.persnr
		   AND i.ende_besch IS NOT NULL
		   AND i.ende_besch <> '2022-07-31'
		   AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		 WHERE DATE(c.filedate) = DATE(var_filedate)
		   AND NOT EXISTS (
		        SELECT 1
		          FROM tbl_ueb_personalakte_scd_snapshot s
		         WHERE s.persnr = c.persnr
		           AND s.gueltig_bis = '9999-12-31'
		   );

		UPDATE tbl_ueb_personalakte_scd_snapshot s
		JOIN tbl_ueb_personalakte c
		  ON c.persnr = s.persnr
		 AND DATE(c.filedate) = DATE(var_filedate)
		JOIN tmp_personalakte_import i
		  ON i.pers_nr = c.persnr
		 AND i.ende_besch IS NOT NULL
		 AND i.ende_besch <> '2022-07-31'
		 AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
		   SET s.last_insert_update = c.last_insert_update
		     , s.filedate = c.filedate
		     , s.gebdatum = COALESCE(NULLIF(i.gebdatum, '0000-00-00'), s.gebdatum)
		 WHERE s.gueltig_bis = '9999-12-31'
		   AND (i.gebdatum IS NULL OR i.gebdatum = '0000-00-00' OR s.gebdatum <=> i.gebdatum)
		   AND s.`name`        <=> c.`name`
		   AND s.pdl           <=> c.pdl
		   AND s.oe            <=> c.oe
		   AND s.schichtgruppe <=> c.schichtgruppe
		   AND s.eg            <=> c.eg
		   AND s.beginn        <=> c.beginn
		   AND s.ende          <=> c.ende
		   AND s.taetigkeit    <=> c.taetigkeit
		   AND s.team          <=> c.team
		   AND s.br            <=> c.br
		   AND s.übernahme     <=> c.übernahme
		   AND s.taetigkeit2   <=> c.taetigkeit2
		   AND s.funktion      <=> c.funktion;

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
		        SELECT p.persnr_alt
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
		
		SELECT s.persnr_alt
		     , d.datum
		     , IF(d.arbeitstag = 1, '*', '')
		     , p.filedate
		  FROM tbl_ueb_personalakte_scd s
			JOIN tmp_personalakte_import p ON p.pers_nr = s.persnr_alt
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
		    SELECT p.persnr_alt
		         , d.datum
		      FROM tbl_ueb_personalakte_scd p
		      JOIN tbl_datum d
		        ON d.datum BETWEEN p.beginn AND p.ende
		       AND d.datum BETWEEN p.gueltig_von AND p.gueltig_bis
		     WHERE d.datum >= CURDATE() - INTERVAL 60 DAY
		) p
	       ON p.persnr_alt = j.persnr
		      AND p.datum  = j.datum
		
		SET
		      j.pa_fz              = 'XXX'
		    , j.pa_taetigkeit      = NULL
		    , j.pa_oe              = NULL
		    , j.pa_schichtgr       = NULL
		    , j.pa_filedate        = v_filedate
          , j.last_insert_update = NOW()
		
		WHERE j.datum >= CURDATE() - INTERVAL 60 DAY
		  AND p.persnr_alt IS NULL
		  AND j.pa_filedate IS NOT NULL
		  AND j.pa_fz <> 'XXX'
		;


		CALL proc_ueb_fz_geister_loeschen();
			 	
	END IF;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
END//
