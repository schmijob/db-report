-- Managed by db-workbench; source of truth: db-report/procedures/proc_insert_khdr.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_insert_khdr`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_insert_khdr`()
SQL SECURITY DEFINER BEGIN

-- #### HDR ####

	SELECT max(last_insert_update) INTO @hdr FROM tbl_import_hdr -- LIMIT 1
	;
   IF @hdr IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tbl_uebertrag_hdr WHERE last_insert_update >= @hdr LIMIT 1) THEN
-- Targets vorbereiten
		
		CALL schreibe_log("proc_insert_khdr", "hdr start", 0);
		
-- HDR vorbereiten
		UPDATE tbl_import_hdr
			SET start_ust = IF(`start` = 0, NULL, STR_TO_DATE(`start`, '%Y%m%d%H%i%s'))
		  	  , ende_ust = IF(ende = 0, NULL, STR_TO_DATE(ende, '%Y%m%d%H%i%s'))
		 WHERE start_ust IS NULL OR ende_ust IS NULL 
		;
	
-- HDR fortschreiben
		INSERT INTO tbl_uebertrag_hdr (auftragsnr, auftragstyp, apid, start_ust, ende_ust, name, auftragsstatus_id, filedate)
		SELECT i.auftragsnr
		     , i.auftragstyp
		     , i.apid
		     , i.start_ust
		     , i.ende_ust
		     , i.name
		     , s.auftragsstatus_id
		     , i.filedate
		  FROM tbl_import_hdr i
		  JOIN tbl_stamm_auftragsstatus s ON s.auftragsstatus = i.auftragsstatus
		ON DUPLICATE KEY UPDATE
		  auftragstyp       = VALUES(auftragstyp)
		, apid              = VALUES(apid)
		, start_ust         = VALUES(start_ust)
		, ende_ust          = VALUES(ende_ust)
		, name              = VALUES(name)
		, auftragsstatus_id = VALUES(auftragsstatus_id)
		, filedate          = VALUES(filedate)
		;
	
-- HDR berechnen
		INSERT INTO tbl_perfor_hdr (auftragsnr, auftragstyp, apid, datum, schicht, `start`, ende, bruttozeit, filedate, name_schicht, target)
		  WITH timezone_calc AS (
				SELECT i.auftragsnr
				     , t.auftragstyp_id AS auftragstyp
				     , IF(i.auftragstyp = 'SPEC' AND a.apid IS NULL, 402, a.apid) AS apid
				     , DATE(CONVERT_TZ(ende_ust, '+00:00', @@global.time_zone) + INTERVAL 1.9 HOUR) AS datum -- 2.1 = 22:06 -> 00:00 
				     , 1 + HOUR(CONVERT_TZ(ende_ust, '+00:00', @@global.time_zone) + INTERVAL 1.9 HOUR) DIV 8 AS schicht
				     , CONVERT_TZ(start_ust, '+00:00', @@global.time_zone) AS start
				     , CONVERT_TZ(ende_ust, '+00:00', @@global.time_zone) AS ende
				     , TIMESTAMPDIFF(SECOND, start_ust, ende_ust) AS bruttozeit
				     , i.filedate
				     , a.Arbeitsplatztyp
				     , i.name
				  FROM tbl_import_hdr i
				  LEFT JOIN tbl_stamm_tische t ON i.auftragstyp = t.auftragstyp
				  LEFT JOIN tbl_stamm_apid   a ON a.Arbeitsplatz_ID = i.apid
				 WHERE i.auftragsstatus = '11'
				   AND start_ust IS NOT NULL
				   AND ende_ust IS NOT NULL
		)
		
		SELECT p.auftragsnr, p.auftragstyp, p.apid, p.datum, p.schicht, p.`start`, p.ende, p.bruttozeit, p.filedate
			  , IF(LEFT(p.`name`, 2) = 'L_' OR LEFT(p.`name`, 7) = 'GENERIC', CONCAT(p.`name`, '-', s.Schichtgr_kurz), p.`name`) AS name_schicht
			--  , p.`name` AS name_schicht
			  , t.target
		  FROM timezone_calc p
-- LEFT JOIN tbl_import_hdr i ON p.auftragsnr = i.auftragsnr
		  LEFT JOIN tbl_datum d ON p.datum = d.datum
		  LEFT JOIN tbl_schichten s ON d.schichtindex = s.Schichtindex 
									     AND s.schicht_int = p.schicht 
										  AND s.`index` <= 9
		  LEFT JOIN tbl_targets_tische t ON p.auftragstyp = t.Auftragstyp_ID 
											 AND p.Arbeitsplatztyp = t.Tischtyp 
											 AND p.datum BETWEEN t.gueltig AND t.gueltig_bis
		
		ON DUPLICATE KEY UPDATE
		  auftragstyp = VALUES(auftragstyp)
		, apid        = VALUES(apid)
		, datum       = VALUES(datum)
		, schicht     = VALUES(schicht)
		, `start`     = VALUES(`start`)
		, ende        = VALUES(ende)
		, bruttozeit  = VALUES(bruttozeit)
		, name_schicht = VALUES(name_schicht)
		, target			= VALUES(target)
		, filedate    = VALUES(filedate)
		;
		
		-- HDR import leeren
		DELETE i
		FROM tbl_import_hdr i
		JOIN tbl_uebertrag_hdr u ON u.auftragsnr = i.auftragsnr
		;
		
		CALL schreibe_log("proc_insert_khdr", "hdr ende", ROW_COUNT());		

	END IF
	;
	
-- #### KHDR ####

	SELECT max(last_insert_update) INTO @khdr FROM tbl_import_khdr --  LIMIT 1
	;
	IF @khdr IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tbl_uebertrag_khdr WHERE last_insert_update >= @khdr LIMIT 1) THEN
		
		CALL schreibe_log("proc_insert_khdr", "khdr start", 0);		
-- KHDR vorbereiten
		UPDATE tbl_import_khdr
			SET start_ust = IF(`start` = 0, NULL, STR_TO_DATE(`start`, '%Y%m%d%H%i%s'))
		     , ende_ust = IF(ende = 0, NULL, STR_TO_DATE(ende, '%Y%m%d%H%i%s'))
		 WHERE start_ust IS NULL OR ende_ust IS NULL
		;
			
-- KHDR fortschreiben
		INSERT INTO tbl_uebertrag_khdr (auftragsnr, kitbelegnr, kitmatnr, start_ust, ende_ust, quell_klt, name, kit_status, gewicht, filedate)
		SELECT auftragsnr
		     , kitbelegnr
		     , kitmatnr
		     , start_ust
		     , ende_ust
		     , quell_klt
		     , name
		     , kit_status
		     , gewicht
		     , filedate
		  FROM tbl_import_khdr
		ON DUPLICATE KEY UPDATE
		  auftragsnr = VALUES(auftragsnr)
		, kitmatnr   = VALUES(kitmatnr)
		, start_ust  = VALUES(start_ust)
		, ende_ust   = VALUES(ende_ust)
		, quell_klt  = VALUES(quell_klt)
		, name       = VALUES(name)
		, kit_status = VALUES(kit_status)
		, gewicht    = VALUES(gewicht)
		, filedate   = VALUES(filedate)
		;
		
-- Kitdaten einfügen oder aktualisieren
	    INSERT INTO tbl_perfor_hdr (auftragsnr, kits, nettozeit, kitmatnr, quell_klt, gewicht)
	    SELECT k.auftragsnr
	         , COUNT(*) AS kits
	         , SUM(TIMESTAMPDIFF(SECOND, k.start_ust, k.ende_ust)) AS nettozeit
	         , MAX(k.kitmatnr) AS kitmatnr
	         , SUM(k.quell_klt) AS quell_klt
	         , MAX(k.gewicht) AS gewicht
	      FROM tbl_uebertrag_khdr k
	     INNER JOIN (SELECT DISTINCT auftragsnr FROM tbl_import_khdr) i ON k.auftragsnr = i.auftragsnr
	     WHERE k.kit_status = 9
	       AND k.start_ust IS NOT NULL
	       AND k.ende_ust IS NOT NULL
--	       AND k.ende_ust >= (SELECT MIN(ende_ust) FROM tbl_import_khdr) - INTERVAL 5 DAY
	     GROUP BY k.auftragsnr
	    ON DUPLICATE KEY UPDATE
	      kits      = VALUES(kits)
	    , nettozeit = VALUES(nettozeit)
	    , kitmatnr  = VALUES(kitmatnr)
	    , quell_klt = VALUES(quell_klt)
	    , gewicht   = VALUES(gewicht)
		;
		
		-- KHDR import leeren
		DELETE i
		FROM tbl_import_khdr i
		JOIN tbl_uebertrag_khdr u ON u.kitbelegnr = i.kitbelegnr
		;
		
		CALL schreibe_log("proc_insert_khdr", "khdr ende", ROW_COUNT());		
	END IF
	;
	
-- #### OEE ####	
	
-- OEE einfügen
	SELECT MAX(filedate) INTO @liu FROM tbl_import_oee
   ;
	IF NOT EXISTS (SELECT 1 FROM tbl_uebertrag_oee WHERE last_insert_update >= @liu) THEN
	   -- import übertragen
		INSERT INTO tbl_uebertrag_oee (datum, arbeitsplatztyp, schicht, oee, filedate)
			SELECT o.datum
			     , o.arbeitsplatztyp
				  , o.schicht
				  , o.oee
				  , o.filedate
			  FROM tbl_import_oee o
			    ON DUPLICATE KEY UPDATE
			       oee        = VALUES(oee)
			     , oee_filled = NULLIF(VALUES(oee), 0)
			     , filedate   = VALUES(filedate)
		;
		-- Datenlücken füllen
		INSERT IGNORE INTO tbl_uebertrag_oee (arbeitsplatztyp, datum, schicht)
		WITH schichten AS ( VALUES (1), (2), (3) )
		, arbeitsplätze AS ( SELECT auftragstyp AS arbeitsplatztyp FROM tbl_stamm_tische where auftragstyp_id <= 5 )
		, daterange AS ( SELECT datum FROM tbl_datum WHERE datum BETWEEN ( SELECT MIN(datum) FROM tbl_import_oee ) AND CURDATE() )
		
		SELECT arbeitsplatztyp, datum, `1` AS schicht
		FROM arbeitsplätze o 
		CROSS JOIN daterange
		CROSS JOIN schichten
		;
		-- Werte für OEE = NULL interpolieren
		UPDATE tbl_uebertrag_oee t
		JOIN ( SELECT t.datum
		            , t.arbeitsplatztyp
		            , t.schicht
		            , CASE WHEN next_oee IS NULL THEN NULL
		                   WHEN prev_oee IS NULL THEN next_oee
		                   ELSE ( prev_oee + next_oee ) / 2
		              END AS oee_filled
		         FROM ( SELECT t.datum
		                     , t.arbeitsplatztyp
		                     , t.schicht
		                     , ( SELECT p.oee
		                          FROM tbl_uebertrag_oee p
		                         WHERE p.arbeitsplatztyp = t.arbeitsplatztyp
		                           AND p.oee > 0
		                           AND (    p.datum < t.datum
		                               OR ( p.datum = t.datum AND p.schicht < t.schicht )
		                               )
		                         ORDER BY p.datum DESC, p.schicht DESC
		                        LIMIT 1
		                       ) AS prev_oee
		                     , ( SELECT n.oee
		                           FROM tbl_uebertrag_oee n
		                          WHERE n.arbeitsplatztyp = t.arbeitsplatztyp
		                            AND n.oee > 0
		                            AND (    n.datum > t.datum
		                                OR ( n.datum = t.datum AND n.schicht > t.schicht )
		                                )
		                          ORDER BY n.datum, n.schicht
		                          LIMIT 1
		                       ) AS next_oee
		                  FROM tbl_uebertrag_oee t
		                 WHERE t.oee_filled IS NULL
		               ) t
		     ) x
		  ON x.datum           = t.datum
		 AND x.arbeitsplatztyp = t.arbeitsplatztyp
		 AND x.schicht         = t.schicht
		 SET t.oee_filled = x.oee_filled
		;
	END IF; 
		UPDATE tbl_perfor_hdr p
		LEFT JOIN tbl_stamm_apid a ON p.apid = a.apid
		LEFT JOIN tbl_uebertrag_oee o ON o.datum = p.datum AND o.arbeitsplatztyp = a.Arbeitsplatztyp AND o.schicht = p.schicht
		SET p.oee = ifnull(o.oee_filled, o.oee)
		WHERE p.oee IS NULL
		;

END//
