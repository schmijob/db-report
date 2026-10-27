-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_aenderungen.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_aenderungen`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_aenderungen`()
SQL SECURITY DEFINER BEGIN
DECLARE p_mindate DATE;
DECLARE p_maxdate DATE;

    -- Ermitteln von last_insert_update
SELECT last_insert_update INTO @liu FROM tbl_import_aenderungen LIMIT 1;
CALL schreibe_log("proc_uebertrag_aenderungen", "uebertrag start", 0);
	-- Einfügen der neuen Daten in tbl_uebertrag_aenderungen
	INSERT INTO tbl_uebertrag_aenderungen (persnr, `name`, geaendert_von, feld, datum, wert, gueltig_von, gueltig_bis, beschreibung, filedate)
     SELECT CAST(REGEXP_REPLACE(ua.geaendert_fuer, '\[(\d+)\].*', '\1') AS INT) AS persnr
          , REGEXP_REPLACE(ua.geaendert_fuer, '\[.*\] ', '') AS `name`
          , REGEXP_REPLACE(ua.geaendert_von, '\[.*\] ', '') AS geaendert_von
			 , feld
			 , datum
			 , TRIM(BOTH '\r\n' from wert) AS wert
			 , case when gueltig_von IN ('Systemstart', '') then DATE('2000-01-01') else str_to_date(ua.gueltig_von, '%d.%m.%Y') end AS gueltig_von
			 , case when gueltig_bis in ('Unbegrenzt', '') then DATE('9999-12-31') else str_to_date(ua.gueltig_bis, '%d.%m.%Y') END AS gueltig_bis
			 , TRIM(BOTH '\r\n' from beschreibung) AS beschreibung
			 , filedate 
	    FROM tbl_import_aenderungen ua
		WHERE geaendert_fuer LIKE '[%]%'
        ON DUPLICATE KEY UPDATE
		      filedate = VALUES(filedate)
        ;
-- Werte aktualisieren
IF NOT EXISTS (SELECT 1 FROM tbl_uebertrag_aenderungen_werte ueb WHERE ueb.last_insert_update > @liu) THEN 
	CALL schreibe_log("proc_uebertrag_aenderungen", "werte start", 0);
   INSERT INTO tbl_uebertrag_aenderungen_werte (persnr, aenderungsdatum, feld, wert, gueltig_von, gueltig_bis, beschreibung, filedate, gelöscht)
		  WITH step1 AS(
				  	SELECT	ua.persnr -- CAST(REGEXP_REPLACE(ua.geaendert_fuer, '\\[(\\d+)\\].*', '\\1') AS INT) AS persnr, 
					,	ua.datum AS aenderungsdatum
					,	ua.feld
					,	REGEXP_REPLACE(ua.wert, '\[.*\] ', '') AS wert
					,	ua.gueltig_von
					,	ua.gueltig_bis
					,	ua.beschreibung
					,	ua.filedate
					FROM tbl_uebertrag_aenderungen ua
					WHERE feld NOT IN ('Fehlzeit', 'Tagesplan') AND ua.wert <> '[141049999] alle ausgeschiedenen MAInnen'
		   )
				SELECT ua.persnr, ua.aenderungsdatum, ua.feld, COALESCE(o.OE_neu, t.taetigkeit_neu, ua.wert) AS wert, ua.gueltig_von, ua.gueltig_bis, ua.beschreibung, ua.filedate, ua.beschreibung LIKE ('(Gelöscht)%') AS gelöscht
				FROM step1 ua
				LEFT JOIN tbl_stamm_OE_translate o ON o.OE_alt = ua.wert AND ua.feld = 'Organisationseinheit der Person'
				LEFT JOIN tbl_stamm_taetigkeit_translate t ON t.taetigkeit_alt = ua.wert AND ua.feld LIKE '%Tätigkeit'
        ON DUPLICATE KEY UPDATE
		filedate = VALUES(filedate)
			
        ;

			
	-- Personalakte updaten
	CALL schreibe_log("proc_uebertrag_aenderungen", "personalakte start", 0);
	SELECT filedate INTO @filedate FROM tbl_import_personalakte LIMIT 1;
	
	INSERT INTO tbl_ueb_personalakte(persnr, name, pdl, oe, schichtgruppe, eg, beginn, ende, taetigkeit, team, br, filedate)
	WITH aenderungen AS (
		SELECT ua.*
		     , ROW_NUMBER() OVER (PARTITION BY persnr, feld ORDER BY aenderungsdatum DESC) AS rn 
		  FROM tbl_uebertrag_aenderungen_werte ua
		 WHERE aenderungsdatum > @filedate AND ua.beschreibung <> '(gelöscht)'
			AND (ua.feld = 'Beginn Beschäftigung' AND ua.gueltig_von = '2000-01-01' 
			    OR ua.feld = 'Ende Beschäftigung' AND ua.gueltig_bis = '9999-12-31' 
				 OR ua.feld NOT IN ('Beginn Beschäftigung', 'Ende Beschäftigung', 'Buchungsaktion'))
	)
	, aenderungen2 AS (
		SELECT ua.persnr
			  , GROUP_CONCAT( case when ua.feld = 'Nachname' 								then ua.wert END ) AS nachname
			  , GROUP_CONCAT( case when ua.feld = 'Vorname' 								then ua.wert END ) AS vorname
			  , GROUP_CONCAT( case when ua.feld = 'Organisationseinheit der Person' then ua.wert END ) AS oe
			  , GROUP_CONCAT( case when ua.feld = '10 Schicht' 							then ua.wert END ) AS schichtgruppe
			  , GROUP_CONCAT( case when ua.feld = 'Info 2' 									then ua.wert END ) AS eg
			  , GROUP_CONCAT( case when ua.feld = 'Beginn Beschäftigung'				then ua.wert END ) AS beginn
			  , GROUP_CONCAT( case when ua.feld = 'Ende Beschäftigung'					then ua.wert END ) AS ende
			  , GROUP_CONCAT( case when ua.feld = 'Tätigkeit'								then ua.wert END ) AS taetigkeit
			  , GROUP_CONCAT( case when ua.feld = '13 Team' 								then ua.wert END ) AS team
			  , GROUP_CONCAT( ua.beschreibung ) AS beschreibung
			  , MAX(ua.filedate) AS filedate
		  FROM aenderungen ua
	    WHERE ua.rn = 1
		 GROUP BY ua.persnr
	)
	, dates1 AS (
		SELECT a.persnr -- CAST(REGEXP_REPLACE(a.geaendert_fuer, '\\[(\\d+)\\].*', '\\1') AS INT) AS persnr
			  , a.feld
			  , a.wert
			  , ROW_NUMBER() OVER (PARTITION BY a.`name`, a.feld ORDER BY a.datum DESC) AS rn
	     FROM tbl_uebertrag_aenderungen a 
		 WHERE (a.feld = 'Beginn Beschäftigung' AND a.gueltig_von = '2000-01-01' OR a.feld = 'Ende Beschäftigung' AND a.gueltig_bis = '9999-12-31')
			    AND a.beschreibung NOT LIKE '(Gelöscht)%'
	)
	, dates2 AS (
	 	SELECT persnr
	        , STR_TO_DATE(left(GROUP_CONCAT( case when feld = 'Beginn Beschäftigung' then if(wert = '', '01.01.2000', wert) END ), 10), '%d.%m.%Y') AS beginn
			  , STR_TO_DATE(left(GROUP_CONCAT( case when feld = 'Ende Beschäftigung'   then if(wert = '', '31.12.9999', wert) END ), 10), '%d.%m.%Y') AS ende
	     FROM dates1
		 WHERE rn = 1
		 GROUP BY persnr
	)
				
		SELECT a.persnr 
			  , coalesce(CONCAT(trim(a.nachname), ', ', trim(a.vorname)), p.name_vorname) AS `name`
			  , p.zeitarbeitsfirma AS pdl
			  , a.oe
			  , COALESCE(a.schichtgruppe, p.schicht) AS schichtgruppe
			  , COALESCE(a.eg, p.info) AS eg
			  , COALESCE(s.beginn, p.beginn_besch, CURDATE() - INTERVAL WEEKDAY(CURDATE()) day) AS beginn
			  , COALESCE(s.ende, p.ende_besch, CURDATE() + INTERVAL 4 MONTH) AS ende
			  , a.taetigkeit
			  , COALESCE(a.team, p.team) AS team
			  , p.betriebsrat AS br
			  , COALESCE(a.filedate, p.filedate) AS filedate
		  FROM aenderungen2 a
		  LEFT JOIN dates2 s ON a.persnr = s.persnr
		  LEFT JOIN tbl_import_personalakte p ON a.persnr = p.pers_nr AND p.oe_der_person <> 'alle ausgeschiedenen MAInnen'
        ON DUPLICATE KEY UPDATE
            tbl_ueb_personalakte.`name`        = COALESCE(VALUES(`name`), tbl_ueb_personalakte.`name`)
            , tbl_ueb_personalakte.oe            = COALESCE(VALUES(oe), tbl_ueb_personalakte.oe)
            , tbl_ueb_personalakte.schichtgruppe = COALESCE(VALUES(schichtgruppe), tbl_ueb_personalakte.schichtgruppe)
            , tbl_ueb_personalakte.eg            = COALESCE(VALUES(eg), tbl_ueb_personalakte.eg)
            , tbl_ueb_personalakte.beginn        = COALESCE(s.beginn, tbl_ueb_personalakte.beginn)
            , tbl_ueb_personalakte.ende          = COALESCE(s.ende, tbl_ueb_personalakte.ende)
            , tbl_ueb_personalakte.taetigkeit    = COALESCE(VALUES(taetigkeit), tbl_ueb_personalakte.taetigkeit)
            , tbl_ueb_personalakte.team          = COALESCE(VALUES(team), tbl_ueb_personalakte.team)
            , tbl_ueb_personalakte.br            = COALESCE(VALUES(br), tbl_ueb_personalakte.br)
            , tbl_ueb_personalakte.filedate      = COALESCE(VALUES(filedate), tbl_ueb_personalakte.filedate)
		  
        ;
END IF;

CALL proc_ueb_personalakte_scd_reconcile();

-- Fehlzeiten updaten
IF TRUE OR NOT EXISTS (SELECT 1 FROM tbl_uebertrag_aenderungen_fehlzeiten ueb WHERE ueb.last_insert_update > @liu) THEN  
        -- Änderungsprotokoll Fehlzeiten und Tagespläne erzeugen
        CALL schreibe_log("proc_uebertrag_aenderungen", "fehlzeiten start", 0);
  	      REPLACE INTO tbl_uebertrag_aenderungen_fehlzeiten (persnr, aenderungsdatum, wert, gueltig_von, gueltig_bis, beschreibung, feld, filedate)      
			  	SELECT CAST(REGEXP_REPLACE(ua.geaendert_fuer, '\[(\d+)\].*', '\1') AS INT) AS persnr -- extrahiert zahlenkette zwischen []
					  , ua.datum AS aenderungsdatum 
					  , CASE WHEN a.kuerzel = 'KE' AND ua.beschreibung REGEXP '.*(nach R`mit PDL|aus(ge)?plan|überdeck|Reduzierung der Produktion durch Schaeffler|Weihnachtspause).*' 
					         THEN 'KE-a' 
								ELSE COALESCE(a.kuerzel, ua.wert) END AS wert -- ausgeplant, ausplanung, überdeckung
					  , STR_TO_DATE(ua.gueltig_von, '%d.%m.%Y') AS gueltig_von
					  , STR_TO_DATE(ua.gueltig_bis, '%d.%m.%Y') AS gueltig_bis
					  , ua.beschreibung
					  , ua.feld
					  , ua.filedate 
				  FROM tbl_import_aenderungen ua
				  LEFT JOIN tbl_abwesenheitsgrund_translate a 
				       ON a.feld = ua.feld 
						 AND ((ua.feld = 'Tagesplan' AND a.zeus_id = CAST(NULLIF(REGEXP_REPLACE(ua.wert, '\[(\d+)\].*', '\1'), '') AS INT)) 
					    	    OR (ua.feld = 'Fehlzeit' AND a.erklaerung = ua.wert))				
				 WHERE ua.feld IN ('Fehlzeit', 'Tagesplan') AND geaendert_fuer LIKE '[%]%'
			;
			CALL schreibe_log("proc_uebertrag_aenderungen", "aend_fz_kalender start", 0);
			DELETE FROM tbl_ueb_aend_fz_kalender WHERE datum >= '2025-01-01'
			;
			-- Änderungen zu Personen-Kalender expandieren und duplikate löschen
			INSERT INTO tbl_ueb_aend_fz_kalender (persnr, datum, aenderungsdatum, feld, wert, gueltig_von, gueltig_bis, beschreibung, bekannt_seit, filedate)
			WITH expanded AS (
				SELECT f.persnr
					  , d.datum
					  , f.aenderungsdatum
					  , f.wert
					  , f.gueltig_von
					  , f.gueltig_bis
					  , f.beschreibung
					  , f.feld
					  , MIN(f.aenderungsdatum) OVER (PARTITION BY f.persnr, d.datum, a.feld) AS bekannt_seit
					  , f.filedate
					  , ROW_NUMBER() OVER (PARTITION BY f.persnr, d.datum, a.feld ORDER BY f.aenderungsdatum DESC) AS rn
				  FROM tbl_uebertrag_aenderungen_fehlzeiten f
				  INNER JOIN tbl_datum d ON d.datum BETWEEN f.gueltig_von AND f.gueltig_bis AND d.datum >= '2025-01-01'
				  LEFT JOIN tbl_abwesenheitsgrund a ON f.wert = a.kuerzel AND f.feld = a.feld
				 WHERE a.kuerzel IS NOT NULL
			)	
				SELECT persnr
					  , datum
					  , aenderungsdatum
					  , feld
					  , IF(beschreibung LIKE '(Gelöscht)%', '*', wert) AS wert
					  , gueltig_von
					  , gueltig_bis
					  , beschreibung
					  , bekannt_seit
					  , filedate
				  FROM expanded
				 WHERE rn = 1
			;
			CALL schreibe_log("proc_uebertrag_aenderungen", "buchungen start", 0);
			SET @filedate = (SELECT MAX(filedate) FROM tbl_uebertrag_aenderungen_fehlzeiten)
			;
/*			
			   UPDATE tbl_ueb_fz_buchungen b
				  LEFT JOIN tbl_datum d ON d.datum = b.datum
				  LEFT JOIN tbl_ueb_aend_fz_kalender a ON b.PersNr = a.persnr AND b.Datum = a.datum AND a.feld = 'Fehlzeit'
				  LEFT JOIN tbl_ueb_aend_fz_kalender a2 ON b.PersNr = a2.persnr AND b.Datum = a2.datum AND a2.feld = 'Tagesplan'
				  LEFT JOIN tbl_abwesenheitsgrund ag ON a.wert = ag.kuerzel
				  LEFT JOIN tbl_abwesenheitsgrund ag2 ON a2.wert = ag2.kuerzel AND ag2.feld = 'Tagesplan'
				   SET b.`Status` = ifnull(a.wert, b.`Status`)
				     , b.schicht = if(a2.feld = 'Tagesplan', ag2.schicht, b.schicht)
				     , b.kommen = IF(ag.anwesenheit = 'anw', b.Kommen, NULL)
				 	  , b.anwesenheit = ifnull(ag.anwesenheit, b.anwesenheit)
					  , b.tp = ifnull(a2.wert, b.tp)
				 WHERE d.arbeitstag = 1 AND (a.filedate = @filedate OR a2.filedate = @filedate)
				;
				CALL schreibe_log("proc_uebertrag_aenderungen", "beschäftigungszeiträume start", 0);
				-- nachgetragene Beschäftigungszeiträume in Buchungen einpflegen
				INSERT INTO tbl_ueb_fz_buchungen(persnr, datum, `status`, schichtgruppe, schicht, anwesenheit, filedate)
				WITH step1 AS (
					SELECT p.persnr
					, d.datum
					, ifnull(k.wert, if(d.arbeitstag, '*', '')) AS `status`
					, p.schichtgruppe
					, s.Schicht
					, d.arbeitstag
					, k.filedate
					, COUNT(*) OVER (PARTITION BY persnr) AS anzahl
					FROM tbl_datum d
					LEFT JOIN tbl_ueb_personalakte_scd p
					  ON d.datum BETWEEN p.beginn AND p.ende
					 AND d.datum BETWEEN p.gueltig_von AND p.gueltig_bis
					LEFT JOIN tbl_ueb_fz_buchungen b ON d.datum = b.Datum AND p.persnr = b.PersNr
					LEFT JOIN tbl_ueb_aend_fz_kalender k ON k.persnr = p.persnr AND k.datum = d.datum AND k.feld = 'Fehlzeit'
					LEFT JOIN tbl_schichten s ON d.schichtindex = s.Schichtindex AND p.schichtgruppe = s.Schichtgruppe
					
					WHERE d.datum BETWEEN '2022-08-01' AND CURDATE() - INTERVAL 7 DAY
					AND b.PersNr IS NULL
					
				) 
				SELECT s1.persnr, s1.datum, `status`, schichtgruppe, ifnull(s1.schicht, 'Früh'), ifnull(a.anwesenheit, if(arbeitstag, NULL, 'Frei')) AS anwesenheit, filedate
				FROM step1 s1
				LEFT JOIN tbl_abwesenheitsgrund a ON s1.status = a.kuerzel
				WHERE anzahl < 20
				;
*/				
				
	 END IF;				
/*	 
	 INSERT INTO tbl_ueb_fz_join (persnr, datum, aend_fz, aend_tp, aend_filedate, last_insert_update)
	 SELECT persnr
  	      , datum
	      , MAX( CASE WHEN feld = 'fehlzeit' THEN wert END) AS aend_fz
	      , MAX( CASE WHEN feld = 'tagesplan' THEN wert END) AS aend_tp
	      , MAX( filedate ) AS aend_filedate
	      , NOW() AS last_insert_update
	   FROM tbl_ueb_aend_fz_kalender
	  WHERE datum >= CURDATE() - INTERVAL 60 DAY
	  GROUP BY persnr
	         , datum
        ON DUPLICATE KEY UPDATE
	        aend_fz            = VALUES(aend_fz)
	      , aend_tp            = VALUES(aend_tp)
	      , aend_filedate      = VALUES(aend_filedate)
	      , last_insert_update = IF(    aend_fz <> VALUES(aend_fz)
	    								      OR aend_tp <> VALUES(aend_tp)
	    								    , NOW()
										    , tbl_ueb_fz_join.last_insert_update
										    ) 
        ;
*/
	 INSERT INTO tbl_ueb_fz_join (persnr, datum, aend_fz, aend_tp, aend_filedate, last_insert_update)
	 SELECT persnr
  	      , datum
	      , MAX( CASE WHEN feld = 'fehlzeit' THEN wert END) AS aend_fz
	      , MAX( CASE WHEN feld = 'tagesplan' THEN wert END) AS aend_tp
	      , MAX( filedate ) AS aend_filedate
	      , NOW() AS last_insert_update
	   FROM tbl_ueb_aend_fz_kalender
	  WHERE datum >= CURDATE() - INTERVAL 60 DAY
	  GROUP BY persnr
	         , datum
        ON DUPLICATE KEY UPDATE
	       aend_fz = VALUES(aend_fz)
	     , aend_tp = VALUES(aend_tp)
	     , aend_filedate = VALUES(aend_filedate)
	     , last_insert_update = CASE
	                                WHEN NOT (tbl_ueb_fz_join.aend_fz <=> VALUES(aend_fz))
	                                  OR NOT (tbl_ueb_fz_join.aend_tp <=> VALUES(aend_tp))
	                                  OR NOT (tbl_ueb_fz_join.aend_filedate <=> VALUES(aend_filedate))
	                                THEN VALUES(last_insert_update)
	                                ELSE tbl_ueb_fz_join.last_insert_update
	                            END
        ;



CALL schreibe_log("proc_uebertrag_aenderungen", "ende", 0);
END//
