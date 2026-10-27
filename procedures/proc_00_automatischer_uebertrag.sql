-- Managed by db-workbench; source of truth: db-report/procedures/proc_00_automatischer_uebertrag.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_00_automatischer_uebertrag`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_00_automatischer_uebertrag`()
SQL SECURITY DEFINER BEGIN

DECLARE var_auswahl INT;
DECLARE var_timediff DOUBLE;
DECLARE var_jetzt DATETIME;
DECLARE var_heute DATETIME;
DECLARE var_datum DATETIME;
DECLARE var_datum1 DATETIME;
DECLARE var_datum2 DATETIME;
DECLARE var_datum3 DATETIME;
DECLARE var_datum4 DATETIME;
DECLARE var_start DATETIME;
DECLARE var_ende DATETIME;
DECLARE test BOOLEAN;
SET test = false;
#SET var_auswahl = 0;#SELECT 0 into var_auswahl;
SELECT NOW() INTO var_jetzt;
SELECT date(NOW()) INTO var_heute;

CALL schreibe_log("proc_00_automatischer_uebertrag", "Start", 0);

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Morgenroutine zwischen 2 und 15 Uhr: 
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
SELECT DATE_ADD(DATE(NOW()),INTERVAL 1.0 HOUR) INTO var_start;
SELECT DATE_ADD(DATE(NOW()),INTERVAL 15.0 HOUR) INTO var_ende;
if TIME_TO_SEC(timediff(var_jetzt,var_start)) >= 0 AND TIME_TO_SEC(timediff(var_jetzt,var_ende)) < 0 then
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_nettoanwesenheit AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_nettoanwesenheit AS kz;
	if var_datum1 > var_datum2 and DATE(var_datum1) = DATE(NOW()) then
	   call schreibe_log("proc_00_automatischer_uebertrag", "Step0.1", 0);
		call proc_34_uebertrag_nettoanwesenheit();
		call schreibe_log("proc_00_automatischer_uebertrag", "Step0.2", 0);
	END if;	
END if;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Morgenroutine zwischen 2 und 23 Uhr: 
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
/*
SELECT DATE_ADD(DATE(NOW()),INTERVAL 2 HOUR) INTO var_start;
SELECT DATE_ADD(DATE(NOW()),INTERVAL 23 HOUR) INTO var_ende;
if TIME_TO_SEC(timediff(var_jetzt,var_start)) > 0 AND TIME_TO_SEC(timediff(var_jetzt,var_ende)) < 0 then
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_personalakte AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_ueb_personalakte_current AS kz;
	if var_datum1 > var_datum2 and DATE(var_datum1) = DATE(NOW()) then
	   call schreibe_log("proc_00_automatischer_uebertrag", "Step50.1", 0);
      CALL proc_uebertrag_personalakte();
		call schreibe_log("proc_00_automatischer_uebertrag", "Step50.2", 0);
	END if;
END if;

*/
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Morgenroutine zwischen 6 und 23 Uhr: 
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	

SELECT DATE_ADD(DATE(NOW()),INTERVAL 6 HOUR) INTO var_start;
SELECT DATE_ADD(DATE(NOW()),INTERVAL 23 HOUR) INTO var_ende;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	#if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Start", 0); END if;
	#if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_start, TIME_TO_SEC(timediff(var_jetzt,var_start))); END if;
	#if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_ende, TIME_TO_SEC(timediff(var_jetzt,var_ende))); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Kennzahlen Morgenroutine zwischen 6 und 8 Uhr:   proc_00_after_import_01_lis_wa_ta_we_lag_tvp
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
if TIME_TO_SEC(timediff(var_jetzt,var_start)) > 0 AND TIME_TO_SEC(timediff(var_jetzt,var_ende)) < 0 then
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 0); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	/*
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_urlaubsvorschau AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_urlaubsvorschau AS kz;
	if (var_datum1 > var_datum2 and date(var_datum1) = DATE(NOW())) OR var_datum2 IS null then
		call schreibe_log("proc_00_automatischer_uebertrag", "Step1.0", 1);
		call proc_uebertrag_urlaubsvorschau();
		call schreibe_log("proc_00_automatischer_uebertrag", "Step1.1", 1);
		###1.Prüfung:
		###DROP TABLE IF EXISTS tbl_uebertrag_anwesenheitsvorschau; CREATE TABLE tbl_uebertrag_anwesenheitsvorschau AS
		##delete FROM tbl_uebertrag_anwesenheitsvorschau;
		##call schreibe_log("proc_00_automatischer_uebertrag", "Step1.2", 1);
		##INSERT INTO tbl_uebertrag_anwesenheitsvorschau
		##SELECT
    	##	p.pers_nr AS PersNr,
    	##	d.datum AS Datum,
    	##	p.schicht AS Schichtgruppe,
    	##	u.abwesenheitsgrund AS Status
		##FROM
    	##	(SELECT DISTINCT pers_nr, schicht, beginn_besch, ende_besch FROM tbl_import_personalakte) p
		##CROSS JOIN (SELECT DISTINCT datum AS datum FROM tbl_uebertrag_urlaubsvorschau) AS d
		##LEFT JOIN tbl_uebertrag_urlaubsvorschau u ON p.pers_nr = u.personalnummer AND d.datum = u.datum
		##WHERE	d.datum BETWEEN p.beginn_besch AND p.ende_besch;
		##call schreibe_log("proc_00_automatischer_uebertrag", "Step1.3", 1);
	END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 1); END if;*/
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	/*
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_fehlzeiten AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_fehlzeiten AS kz;
	if (var_datum1 > var_datum2 and date(var_datum1) = DATE(NOW())) OR var_datum2 IS null then
		DELETE ma FROM tbl_uebertrag_fehlzeiten as ma WHERE date(ma.datum) >=
      (select date(MIN(datum)) FROM tbl_import_fehlzeiten);
		insert into tbl_uebertrag_fehlzeiten
		select * FROM tbl_import_fehlzeiten;
		call schreibe_log("proc_00_automatischer_uebertrag", "Step2", 2);
	END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 2); END if;*/
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	#SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_personalakte AS zf;
	#SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_personalakte AS kz;
	#if (var_datum1 > var_datum2 and date(var_datum1) = DATE(NOW())) OR var_datum2 IS null then
		#replace into tbl_uebertrag_personalakte
		#select * FROM tbl_import_personalakte;

		##fehlende Abteilung in  Tabelle tbl_abteilungen übertragen:
		#insert into tbl_abteilung (abteilung)
		#select distinct pa.abteilung
		#FROM tbl_import_personalakte as pa
		#left join tbl_abteilung as ab on ab.abteilung = pa.abteilung
		#where ab.abteilung is null;

		#insert ignore into tbl_funktionen (funktion,aktiv,Zuordnung)
		#select pa.taetigkeit as funktion,1 as aktiv,0 as Zuordnung
		#FROM tbl_import_personalakte as pa
		#left join tbl_funktionen as fkt on fkt.funktion = pa.taetigkeit
		#where fkt.funktion is null;
	#	call schreibe_log("proc_00_automatischer_uebertrag", "Step3", 3);
	#END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 3); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_buchungen_mitarbeiter AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_buchungen_mitarbeiter AS kz;
	if (var_datum1 > var_datum2 and date(var_datum1) = DATE(NOW())) OR var_datum2 IS null then
	   call schreibe_log("proc_00_automatischer_uebertrag", "Step4", 4);
	   DELETE ma FROM tbl_uebertrag_buchungen_mitarbeiter as ma WHERE date(ma.datum) >=
      (select date(MIN(datum)) FROM tbl_import_buchungen_mitarbeiter WHERE pers_nr > 0 AND datum > 0)
		AND date(ma.datum) <=
      (select date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter WHERE pers_nr > 0 AND datum > 0);
		insert into tbl_uebertrag_buchungen_mitarbeiter
		select * FROM tbl_import_buchungen_mitarbeiter WHERE pers_nr > 0 AND datum > 0;
		call schreibe_log("proc_00_automatischer_uebertrag", "Step4", 4);
	END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 4); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(tbl.filedate) INTO var_datum1 FROM tbl_import_caps_rohdaten AS tbl;
	if var_datum1 IS NULL then
		UPDATE tbl_import_caps_rohdaten SET filedate = lastinsertupdate where filedate is NULL;
	END if;
	SELECT MAX(tbl.filedate) INTO var_datum1 FROM tbl_import_caps_rohdaten AS tbl;
	SELECT MAX(tbl.filedate) INTO var_datum2 FROM tbl_uebertrag_caps_rohdaten AS tbl;
	if date(var_datum1) > date(var_datum2) then
		INSERT INTO tbl_uebertrag_caps_rohdaten
		SELECT * FROM tbl_import_caps_rohdaten;
		DELETE cap FROM tbl_import_caps_rohdaten AS cap WHERE cap.filedate < DATE_SUB(DATE(NOW()),INTERVAL 14 DAY);
		call schreibe_log("proc_00_automatischer_uebertrag", "Step5", 5);
		CALL `proc_05_uebertrag_kennzahlen_caps`();
		call schreibe_log("proc_00_automatischer_uebertrag", "Step5", 5);
	END if;
	
	SELECT MAX(tbl.filedate) INTO var_datum1 FROM tbl_import_kst_umbuchungen_untertaegig AS tbl;
	SELECT DATE_SUB(NOW(),INTERVAL 5 MINUTE) INTO var_datum2;
	if date(var_datum1) > date(var_datum2) then
		DROP TABLE if EXISTS tbl_temp;
		CREATE TABLE tbl_temp (
		    id INT AUTO_INCREMENT PRIMARY KEY,
		    kostenstelle VARCHAR(50),
		    max_id integer
		);
		INSERT INTO tbl_temp(kostenstelle,max_id)
		SELECT kb.kostenstelle, (select MAX(ks_id) FROM tbl_kostenstellen) FROM tbl_import_kst_umbuchungen_untertaegig AS kb
		LEFT JOIN tbl_kostenstellen AS kst ON kst.kostenstelle = kb.kostenstelle
		WHERE kst.kostenstelle IS NULL AND LENGTH(kb.kostenstelle) < 15 group BY kb.kostenstelle;
		
		INSERT INTO tbl_kostenstellen(kostenstelle,ks_id)
		SELECT kostenstelle,id + max_id FROM tbl_temp;
		INSERT IGNORE INTO tbl_konfiguration_schichten (schicht)
		SELECT DISTINCT imp.schicht FROM tbl_import_nettoanwesenheit AS imp;
		INSERT IGNORE INTO tbl_konfiguration_schichten (schicht)
		SELECT DISTINCT imp.pt FROM tbl_import_nettoanwesenheit AS imp;
	END if;	
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Test", 5); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>	
	SELECT date(MAX(zf.filedate)) INTO var_datum1 FROM tbl_import_urlaubsvorschau AS zf;
	SELECT date(MAX(zf.filedate)) INTO var_datum2 FROM tbl_import_personalakte AS zf;
	SELECT date(MAX(zf.filedate)) INTO var_datum3 FROM tbl_import_fehlzeiten AS zf;
	SELECT date(MAX(zf.filedate)) INTO var_datum4 FROM tbl_import_buchungen_mitarbeiter AS zf;
	SELECT date(MAX(zf.zeitstempel)) INTO var_datum FROM tbl_uebertrag_kennzahlen_personal AS zf;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", date(var_datum1), 51); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", date(var_datum2), 52); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", date(var_datum3), 53); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", date(var_datum4), 54); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_heute, 55); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_datum4, 56); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_datum, 57); END if;
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", var_jetzt, 58); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	if (	 date(var_datum1) = var_heute 
		AND date(var_datum2) = var_heute 
		and date(var_datum3) = var_heute /*AND date(var_datum4) = DATE(NOW())*/ 
		AND      var_datum3  > var_datum) then
		CALL proc_05_uebertrag_kennzahlen_perso();
		call schreibe_log("proc_00_automatischer_uebertrag", "Step6", 6);
	END if;
END if;

#Import Verrechnungssätze ZAK	MW 25.06.2025
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_verrechnungssaetze_zak AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_verrechnungssaetze_zak AS kz;
	if var_datum1 > var_datum2 and DATE(var_datum1) = DATE(NOW()) then
	   call schreibe_log("proc_00_automatischer_uebertrag", "Step8", 8);
		call proc_34_uebertrag_verrechnungssaetze_zak;
		call schreibe_log("proc_00_automatischer_uebertrag", "Step8", 8);
	END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_nio_prozess AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_nio_prozess AS kz;
	#WHERE kz.kennzahl = "Anzahl BGL Mindermenge" ;
	if var_datum1 > var_datum2 and DATE(var_datum1) = DATE(NOW()) then
	   call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "Step9", 9);
		call proc_05_uebertrag_kennzahlen_mindermenge;
		call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "Step9", 9);
	END if;
	#CALL schreibe_log("proc_00_automatischer_uebertrag", "Start", 1);
	call proc_00_personalplanung;
	
	
	###############################################################################
	
	SELECT MAX(zf.lastinsertupdate) INTO var_datum1 FROM tbl_uebertrag_kennzahlen AS zf;
	SELECT MAX(kz.last_insert_update) INTO var_datum2 FROM tbl_uebertrag_hdr AS kz;
	#WHERE kz.kennzahl = "Anzahl BGL Mindermenge" ;
	if var_datum1 < var_datum2 and DATE(var_datum2) = DATE(NOW()) then
	   call schreibe_log("proc_05_uebertrag_kennzahlen_hdr", "Step10", 10);
		call proc_05_uebertrag_kennzahlen_hdr;
		call schreibe_log("proc_05_uebertrag_kennzahlen_hdr", "Step10", 10);
	END if;
	
	
	
	
	
	
	#Import Abr_Schaeffler_Monatswerte
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	SELECT MAX(zf.filedate) INTO var_datum1 FROM tbl_import_abr_schaeffler_monatswerte AS zf;
	SELECT MAX(kz.filedate) INTO var_datum2 FROM tbl_uebertrag_abr_schaeffler_monatswerte AS kz;
	if (var_datum1 > var_datum2 and date(var_datum1) = DATE(NOW())) OR var_datum2 IS null then
		call schreibe_log("proc_00_automatischer_uebertrag", "Step7.1", 7);
		#insert ignore into tbl_uebertrag_abr_schaeffler_monatswerte
		#SELECT DATE(mw1.filedate), mw1.* 
		#FROM tbl_import_abr_schaeffler_monatswerte AS mw1;
		
		#Übersetztungstabelle befüllen:
		#INSERT IGNORE INTO tbl_konfiguration_bereich_abrechnung (entgeltgruppe,oe_person_zeus)
		#SELECT mw.info_2,mw.oe_person FROM tbl_uebertrag_abr_schaeffler_monatswerte AS mw;
		
		#Hier noch für Spalte WT Korrekturprüfung mit Update einfügen, Falls Datum,wt eintragen!!!
		
		call schreibe_log("proc_00_automatischer_uebertrag", "Step7.2", 7);
	END if;

	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
	if test = true then call schreibe_log("proc_00_automatischer_uebertrag", "Ende", 99); END if;
	#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
END//
