-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_personalakte.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_personalakte`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_personalakte`()
SQL SECURITY DEFINER BEGIN
    DECLARE var_filedate DATETIME;
    
    -- Prüfung, ob neue Änderungen vorhanden sind
    SELECT MAX(filedate) INTO var_filedate FROM tbl_import_personalakte imp;
    
	 IF var_filedate IS NOT NULL
	    AND NOT EXISTS (
	        SELECT 1
	          FROM tbl_ueb_personalakte ueb
	         WHERE ueb.filedate = var_filedate
	    ) THEN
		-- Preserve source values, then apply the shared Personalakte normalization.
		CALL proc_uebertrag_personalakte_raw_scd(0);
		CALL proc_uebertrag_personalakte_transform_snapshot(DATE(var_filedate), 0);

		INSERT INTO tbl_ueb_personalakte (
		      persnr, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
		    , taetigkeit, team, br, übernahme, taetigkeit2, funktion, filedate
		)
		SELECT persnr, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
		     , taetigkeit, team, br, übernahme, taetigkeit2, funktion, filedate
		  FROM tmp_personalakte_normalized
		ON DUPLICATE KEY UPDATE
		      `name` = VALUES(`name`)
		    , pdl = VALUES(pdl)
		    , oe = VALUES(oe)
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
		    , filedate = VALUES(filedate);
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
		    , j.pa_filedate        = var_filedate
          , j.last_insert_update = NOW()
		
		WHERE j.datum >= CURDATE() - INTERVAL 60 DAY
		  AND p.persnr_alt IS NULL
		  AND j.pa_filedate IS NOT NULL
		  AND j.pa_fz <> 'XXX'
		;


		CALL proc_ueb_fz_geister_loeschen();
			 	
	END IF;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_import;
    DROP TEMPORARY TABLE IF EXISTS tmp_personalakte_normalized;
END//
