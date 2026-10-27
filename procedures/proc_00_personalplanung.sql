-- Managed by db-workbench; source of truth: db-report/procedures/proc_00_personalplanung.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_00_personalplanung`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_00_personalplanung`()
SQL SECURITY DEFINER BEGIN
DECLARE var_datum1 DATETIME;
DECLARE var_datum2 DATETIME;

-- Personalakte
SELECT filedate INTO var_datum1 FROM tbl_import_personalakte LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM tbl_ueb_personalakte_current WHERE filedate = var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_personalakte start", 0);
	CALL proc_uebertrag_personalakte();
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_personalakte ende", ROW_COUNT());
END IF;


-- Fehlzeiten
SELECT filedate INTO var_datum1 FROM tbl_import_fehlzeiten LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM tbl_uebertrag_fehlzeiten WHERE filedate = var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "fehlzeiten start", 0);
   SELECT MIN(datum) INTO var_datum1 FROM tbl_import_fehlzeiten;
   SELECT MAX(datum) INTO var_datum2 FROM tbl_import_fehlzeiten;
	DELETE FROM tbl_uebertrag_fehlzeiten
   WHERE datum BETWEEN var_datum1 AND var_datum2;
   INSERT INTO tbl_uebertrag_fehlzeiten (personalnummer, abwesenheitsgrund, datum, filedate)
   SELECT f.personalnummer, f.abwesenheitsgrund, f.datum, f.filedate FROM tbl_import_fehlzeiten f;
   CALL schreibe_log("proc_00_personalplanung", "fehlzeiten ende", ROW_COUNT());
END IF;


-- Urlaubsvorschau
SELECT filedate INTO var_datum1 FROM tbl_import_personalkalender LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_personalkalender WHERE filedate = var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_urlaubsvorschau_js start", 0);
	CALL proc_uebertrag_urlaubsvorschau_js();
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_urlaubsvorschau_js ende", ROW_COUNT());
END IF;

	
-- Buchungen

SELECT filedate INTO var_datum1 FROM tbl_import_buchungen_mitarbeiter LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM tbl_ueb_buchungen WHERE filedate = var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_buchungen start", 0);
	CALL proc_uebertrag_buchungen();
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_buchungen ende", ROW_COUNT());
END IF;


-- alles Zusammenfügen in tbl_ueb_fz_buchungen

IF NOT EXISTS (
	SELECT 1 
	  FROM tbl_check_procedurlauf
	 WHERE proc = 'proc_00_personalplanung'
	   AND step = 'proc_ueb_fz_buchungen start'
	   AND zeitstempel > NOW() - INTERVAL 15 MINUTE
	           )
THEN
	SET @mindate2 = NULL;
	SET @maxdate2 = NULL;
	-- Zeitraum bei Aktualisierung Buchungen
	SELECT MAX(last_insert_update) INTO var_datum1 FROM tbl_ueb_buchungen;
	IF NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_buchungen WHERE datum = CURDATE() - INTERVAL 1 DAY and last_insert_update > var_datum1 LIMIT 1) THEN
		SET @mindate2 = CURDATE() - INTERVAL 7 DAY;
		SET @maxdate2 = CURDATE();
		CALL schreibe_log("proc_00_personalplanung", CONCAT("buchungen", @mindate2, " - ", @maxdate2), 0);
	END IF;
		-- Zeitraum bei Aktualisierung personalkalender
	SELECT max(filedate) INTO var_datum1 FROM tbl_ueb_fz_personalkalender;
	IF NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_buchungen WHERE datum > CURDATE() AND filedate = var_datum1 LIMIT 1) THEN
		SET @mindate2 = CURDATE() - INTERVAL 14 DAY;
		SET @maxdate2 = last_day(CURDATE() + INTERVAL 2 MONTH);
		CALL schreibe_log("proc_00_personalplanung", CONCAT("urlaub", @mindate2, " - ", @maxdate2), 0);
	END IF;
		-- Zeitraum bei Aktualisierung Personalakte
	IF EXISTS (SELECT 1 FROM tbl_ueb_personalakte_scd p
		        WHERE p.beginn > CURDATE() - INTERVAL 3 DAY
		          AND p.ende >= CURDATE()
		          AND CURDATE() BETWEEN p.gueltig_von AND p.gueltig_bis
				    AND NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_buchungen b WHERE b.PersNr = p.persnr AND b.datum > CURDATE())
				  ) THEN
		SET @mindate2 = LEAST(IFNULL(@mindate2, CURDATE()), CURDATE() - INTERVAL 3 DAY);
		SET @maxdate2 = GREATEST(IFNULL(@maxdate2, CURDATE()), last_day(CURDATE() + INTERVAL 2 MONTH));
		CALL schreibe_log("proc_00_personalplanung", CONCAT("personal", @mindate2, " - ", @maxdate2), 0);  
	END IF;
	
IF @mindate2 IS NOT NULL THEN
   CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_buchungen start", 0);

    -- Batch 1: Historie vor den letzten 7 Tagen
    IF @mindate2 < CURDATE() - INTERVAL 7 DAY THEN
        CALL proc_ueb_fz_buchungen(
            @mindate2,
            LEAST(@maxdate2, CURDATE() - INTERVAL 8 DAY)
        );
         CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_buchungen batch 1 ende", ROW_COUNT());
    END IF;

    -- Batch 2: Letzte 7 Tage inkl. heute
    IF @maxdate2 >= CURDATE() - INTERVAL 7 DAY THEN
        CALL proc_ueb_fz_buchungen(
            GREATEST(@mindate2, CURDATE() - INTERVAL 7 DAY),
            LEAST(@maxdate2, CURDATE())
        );
         CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_buchungen batch 2 ende", ROW_COUNT());
    END IF;

    -- Batch 3: Zukunft
    IF @maxdate2 > CURDATE() THEN
        CALL proc_ueb_fz_buchungen(
            GREATEST(@mindate2, CURDATE() + INTERVAL 1 DAY),
            @maxdate2
        );
         CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_buchungen batch 3 ende", ROW_COUNT());
    END IF;

END IF;
END IF;

-- Änderungen

SELECT last_insert_update INTO var_datum1 FROM tbl_import_aenderungen imp LIMIT 1;
IF NOT EXISTS (SELECT 1 FROM tbl_uebertrag_aenderungen WHERE last_insert_update > var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_aenderungen start", 0);  
	CALL proc_uebertrag_aenderungen();
	CALL schreibe_log("proc_00_personalplanung", "proc_uebertrag_aenderungen ende", ROW_COUNT());
END IF;

-- join
CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_join start", 0);
CALL proc_ueb_fz_join();
CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_join ende", ROW_COUNT());
-- CALL proc_uebertrag_fanf();

-- Forecast
IF NOW() > IFNULL((SELECT MAX(last_insert_update) FROM tbl_ueb_fluktuationskurve), '1000-01-01')  + INTERVAL 7 DAY 
	THEN CALL proc_uebertrag_fluktuationskurve(); 
END IF;
IF NOW() > IFNULL((SELECT MAX(last_insert_update) FROM tbl_ueb_fluktuation_person), '1000-01-01')
   THEN CALL proc_uebertrag_fluktuation_person();
END IF;

SELECT MAX(last_insert_update) INTO var_datum1 FROM tbl_ueb_fz_buchungen;
IF NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_forecast WHERE last_insert_update > var_datum1) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_forecast start", 0);
	CALL proc_ueb_fz_forecast();
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_forecast ende", ROW_COUNT());
END IF;


-- Forecast Persfaktor updaten
/*
SELECT MAX(last_insert_update) INTO var_datum1 FROM tbl_ueb_fz_forecast;
IF NOT EXISTS (SELECT 1 FROM tbl_ueb_fz_persfaktor WHERE last_insert_update > date(var_datum1)) THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_forecast_persfaktor", 0);
	CALL proc_ueb_fz_forecast_persfaktor();
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_fz_forecast_persfaktor ende", ROW_COUNT());
END IF;
*/

-- KHDR
 CALL proc_insert_khdr();

-- PeKo
SELECT MAX(last_insert_update) INTO var_datum1 FROM tbl_ueb_peko_archiv;
IF NOW() > var_datum1 + INTERVAL 5 HOUR AND HOUR(NOW()) BETWEEN 6 AND 16 THEN
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_peko start", 0);
	CALL proc_ueb_peko();
	CALL schreibe_log("proc_00_personalplanung", "proc_ueb_peko ende", ROW_COUNT());
END IF;

END//
