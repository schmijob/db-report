-- Managed by db-workbench; source of truth: db-report/procedures/proc_02_nachtlauf.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_02_nachtlauf`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_02_nachtlauf`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_02_nachtlauf", "Start", 0);
DROP TABLE IF EXISTS tbl_uebertrag_ma_aenderungen2; CREATE TABLE tbl_uebertrag_ma_aenderungen2 AS

SELECT distinct na.persnr,na.datum,
#----------------------------------
na.info_2 AS entgeldgruppe_org,
IFNULL(eg.wert,
IFNULL((SELECT max(info_2) FROM tbl_uebertrag_nettoanw_aend_management WHERE  persnr = na.persnr 
			and datum = (SELECT LAST_DAY(na.datum - INTERVAL 1 MONTH)) 
			and import_version = "vormonat"), 
	na.info_2)) AS entgeldgruppe,	
#----------------------------------	
na.abteilung AS abteilung_org, 
trim(oe_aenderung.wert) AS abteilung_aenderung,
#IFNULL(tr.OE_neu, IFNULL(abteilung_vormonat.abteilung, na.abteilung)) AS Abteilung_Uebersetzt,
IFNULL(IFNULL(tr2.OE_neu,trim(oe_aenderung.wert)), IFNULL(tr.OE_neu, IFNULL(abteilung_vormonat.abteilung, na.abteilung))) AS Abteilung_Uebersetzt,
zo.zuordnung,
zo.oe_bericht,
zo.info,
eg.gueltig_von AS gueltig_von_eg, eg.gueltig_bis AS gueltig_bis_eg, eg.gueltig_bis_org AS gueltig_bis_org_eg,
oe_aenderung.gueltig_von AS gueltig_von_oe, oe_aenderung.gueltig_bis AS gueltig_bis_oe, oe_aenderung.gueltig_bis_org AS gueltig_bis_org_oe,
NOW() AS lastinsert
FROM tbl_uebertrag_nettoanwesenheit AS na
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,aw.gueltig_bis)
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Info 2" AND beschreibung <> "gelöscht" #"Organisationseinheit der Person" 
			) AS eg ON eg.persnr = na.persnr AND na.datum BETWEEN eg.gueltig_von AND eg.gueltig_bis AND eg.gueltig_von < eg.gueltig_bis 
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,if(aw.gueltig_bis = "9999-12-31" ,NOW(),aw.gueltig_bis))
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Organisationseinheit der Person" AND beschreibung <> "gelöscht"
			) AS oe_aenderung ON oe_aenderung.persnr = na.persnr AND na.datum BETWEEN oe_aenderung.gueltig_von AND oe_aenderung.gueltig_bis AND oe_aenderung.gueltig_von < oe_aenderung.gueltig_bis

LEFT JOIN (	SELECT distinct
				FIRST_VALUE(abteilung) OVER (PARTITION BY persnr,DATE_FORMAT(datum, '%Y-%m') ORDER by datum,filedate desc) AS abteilung,
				#FIRST_VALUE(datum) OVER (PARTITION BY persnr,DATE_FORMAT(datum, '%Y-%m') ORDER by datum,filedate desc) AS datum,
            persnr,
            DATE_FORMAT(datum, '%Y-%m') AS ym,
            month(datum) + 1 AS monat
            #EXTRACT(YEAR_MONTH FROM datum)
        FROM tbl_uebertrag_nettoanw_aend_management
        WHERE EXTRACT(YEAR_MONTH FROM datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 3 MONTH))
          #AND EXTRACT(YEAR_MONTH FROM datum) >= EXTRACT(YEAR_MONTH FROM (filedate - INTERVAL 2 MONTH))
          AND import_version = "aktueller Monat"
          AND persnr > 0
) AS abteilung_vormonat ON abteilung_vormonat.persnr = na.persnr AND abteilung_vormonat.monat = month(na.datum) AND oe_aenderung.wert IS NULL
LEFT JOIN tbl_stamm_OE_translate AS tr ON tr.OE_alt = trim(IFNULL(abteilung_vormonat.abteilung, na.abteilung))
LEFT JOIN tbl_stamm_OE_translate AS tr2 ON tr2.OE_alt = trim(oe_aenderung.wert)
LEFT JOIN tbl_konfiguration_eg_bereich_zuordnung AS zo 
		 ON  zo.entgeltgruppe  = IFNULL(eg.wert, na.info_2) 
		 AND zo.oe_person = IFNULL(IFNULL(tr2.OE_neu,trim(oe_aenderung.wert)) , IFNULL(tr.OE_neu, IFNULL(abteilung_vormonat.abteilung, na.abteilung)))
		 
WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 2 MONTH))
AND na.persnr > 0;
call schreibe_log("proc_02_nachtlauf", "Step1", 1);
DROP TABLE IF EXISTS tbl_uebertrag_ma_aenderungen; 
call schreibe_log("proc_02_nachtlauf", "Step2", 2);
ALTER TABLE tbl_uebertrag_ma_aenderungen2 RENAME tbl_uebertrag_ma_aenderungen;
call schreibe_log("proc_02_nachtlauf", "Step3", 3);
#AND na.persnr < 17083;

#DROP VIEW IF EXISTS view_mitarbeiter_zuordnung;
#CREATE VIEW view_mitarbeiter_zuordnung AS
/*
SELECT distinct na.persnr,na.datum,
#----------------------------------
na.info_2 AS entgeldgruppe_org,
IFNULL(eg.wert,
IFNULL((SELECT max(info_2) FROM tbl_uebertrag_nettoanw_aend_management WHERE  persnr = na.persnr 
			and datum = (SELECT LAST_DAY(na.datum - INTERVAL 1 MONTH)) 
			and import_version = "vormonat"), 
	na.info_2)) AS entgeldgruppe,	
#----------------------------------	
na.abteilung AS abteilung_org, 
ifnull(tr.OE_neu,na.abteilung) AS Abteilung_Abkuerzung,
ifnull(br.zuordnung,na.abteilung) AS Abteilung_ersetzt,
IFNULL(oe.wert,
IFNULL((SELECT max(abteilung) FROM tbl_uebertrag_nettoanw_aend_management WHERE  persnr = na.persnr 
			and datum = (SELECT LAST_DAY(na.datum - INTERVAL 1 MONTH)) 
			and import_version = "vormonat"), 
	na.abteilung)) AS abteilung,	
naw.abteilungungen,
if(oe.wert IS NULL,naw.anzahl,null) AS anzahl,
eg.gueltig_von AS gueltig_von_eg, eg.gueltig_bis AS gueltig_bis_eg, eg.gueltig_bis_org AS gueltig_bis_org_eg,
oe.gueltig_von AS gueltig_von_oe, oe.gueltig_bis AS gueltig_bis_oe, oe.gueltig_bis_org AS gueltig_bis_org_oe
FROM tbl_uebertrag_nettoanwesenheit AS na
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,aw.gueltig_bis)
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Info 2" AND beschreibung <> "gelöscht" #"Organisationseinheit der Person" 
			) AS eg ON eg.persnr = na.persnr AND na.datum BETWEEN eg.gueltig_von AND eg.gueltig_bis AND eg.gueltig_von < eg.gueltig_bis 
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,if(aw.gueltig_bis = "9999-12-31" ,NOW(),aw.gueltig_bis))
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Organisationseinheit der Person" AND beschreibung <> "gelöscht"
			) AS oe ON oe.persnr = na.persnr AND na.datum BETWEEN oe.gueltig_von AND oe.gueltig_bis AND oe.gueltig_von < oe.gueltig_bis
LEFT JOIN tbl_konfiguration_bereich_abrechnung AS br ON br.entgeltgruppe = IFNULL(eg.wert, na.info_2) AND br.oe_person_zeus = na.abteilung
LEFT JOIN tbl_konfiguration_bereich_abrechnung AS oe2 ON oe2.entgeltgruppe = IFNULL(eg.wert, na.info_2) AND trim(oe2.oe_kurz) = trim(oe.wert) AND oe2.oe_kurz IS NOT null
LEFT JOIN (	SELECT persnr, month(datum) AS monat, GROUP_CONCAT(distinct abteilung) AS abteilungungen,COUNT( DISTINCT abteilung) AS anzahl 
				FROM tbl_uebertrag_nettoanw_aend_management
			  	WHERE EXTRACT(YEAR_MONTH FROM datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 3 MONTH)) AND persnr >0
			  	GROUP by persnr, monat
) AS naw ON naw.persnr =na.persnr AND naw.monat = month(na.datum) AND oe.wert IS NULL
LEFT JOIN tbl_stamm_OE_translate AS tr ON tr.OE_alt = na.abteilung
WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 2 MONTH))
AND na.persnr > 0;
*/
call schreibe_log("proc_02_nachtlauf", "Step4", 4);
#ALTER TABLE tbl_uebertrag_ma_aenderungen
#ADD PRIMARY KEY (`persnr`, `datum`) USING BTREE;
ALTER TABLE tbl_uebertrag_ma_aenderungen
MODIFY persnr INT NOT NULL,
MODIFY datum DATE NOT NULL,
ADD PRIMARY KEY (`persnr`, `datum`) USING BTREE;

call schreibe_log("proc_02_nachtlauf", "Step5", 5);
ALTER TABLE tbl_uebertrag_ma_aenderungen
ADD INDEX idx_sortierung_abteilung (Abteilung_Uebersetzt);
call schreibe_log("proc_02_nachtlauf", "Step6", 6);
ALTER TABLE tbl_uebertrag_ma_aenderungen
ADD INDEX idx_sortierung_entgeldgruppe (entgeldgruppe );
call schreibe_log("proc_02_nachtlauf", "Step7", 7);
INSERT IGNORE INTO tbl_konfiguration_eg_bereich_zuordnung
(entgeltgruppe,oe_person,zuordnung, oe_bericht, info)
SELECT ma.entgeldgruppe,ma.Abteilung_Uebersetzt,ma.zuordnung,ma.oe_bericht,ma.info FROM tbl_uebertrag_ma_aenderungen AS ma
WHERE ma.zuordnung IS NULL;
call schreibe_log("proc_02_nachtlauf", "Step8", 8);
#SELECT 
#DISTINCT
#ae.abteilung_org,
#ae.abteilung
/*
UPDATE 
tbl_uebertrag_ma_aenderungen AS ae 
#FROM tbl_uebertrag_ma_aenderungen AS ae 
SET ae.abteilung = ae.abteilung_org
WHERE ae.abteilung_org <> ae.abteilung AND CHAR_LENGTH(ae.abteilung) < 3;
*/


#AND na.persnr = 36103225
#ORDER BY na.persnr,na.datum
#HAVING info_2 <> egg
#HAVING zuordnung <> zuordnung2
#HAVING entgeldgruppe = "E3"
/* #Fehlerkorrektur für entgeldklasse:
		update
		tbl_uebertrag_abr_schaeffler_monatswerte as na 
	   LEFT Join tbl_uebertrag_ma_aenderungen AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
      SET na.eg_original = zo.entgeldgruppe_org,
      	 na.info_2 = ifnull(zo.entgeldgruppe, na.info_2)
		WHERE na.filedate > DATE_SUB(DATE(NOW()),INTERVAL 3 day)
		AND na.info = "vormonat" AND na.persnr > 0
		AND na.info_2 <> ifnull(zo.entgeldgruppe, na.info_2)
		AND na.eg_original IS null
*/
######################################################################################################
##################################Prüfung auf fehlende zuordnung######################################
/*
SELECT distinct ma.entgeldgruppe,ma.abteilung_org,ma.abteilung_aenderung,  ma.Abteilung_Uebersetzt, ma.zuordnung,ma.oe_bericht,ma.info 
FROM tbl_uebertrag_ma_aenderungen AS ma
WHERE ma.zuordnung IS NULL;
SELECT * FROM tbl_konfiguration_eg_bereich_zuordnung
*/

/*
#Neu Updaten Spalte oe_bericht:
#SELECT mw.datum,mw.persnr ,mw.oe_bericht,mae.oe_bericht,mw.info_2  FROM 
update
tbl_uebertrag_abr_schaeffler_monatswerte AS mw
LEFT JOIN tbl_uebertrag_ma_aenderungen AS mae ON mae.persnr = mw.persnr 
	AND mae.datum = mw.datum
SET mw.oe_bericht = mae.oe_bericht
WHERE mw.oe_bericht <> mae.oe_bericht
#
update
tbl_uebertrag_abr_schaeffler_monatswerte AS mw
LEFT JOIN tbl_uebertrag_ma_aenderungen AS mae ON mae.persnr = mw.persnr 
	AND mae.datum = mw.datum
SET mw.zuordnung = mae.zuordnung
WHERE mw.zuordnung <> mae.zuordnung
 
#SELECT mw.datum,mw.persnr ,mw.team,pa.team FROM 
update
tbl_uebertrag_abr_schaeffler_monatswerte AS mw
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = mw.persnr 
SET mw.team = pa.team
WHERE mw.team <> pa.team
AND mw.datum > "2026-01-01"


#Abgleich Tag der Rohdaten und Inhalte der Perso Live zum Zeitpunkt: 
SELECT abr.key_datum,abr.datum,abr.persnr,abr.info_2, abr.oe_bericht,abr.gueltig_von_eg,abr.gueltig_von_oe,abr.info, 
org.info,org.key_datum, org.eg_original,org.oe_person_original,
"Test",eg_aenderung.wert AS aenderungswert_eg,eg_aenderung.gueltig_von AS gueltig_von_eg ,
       oe_aenderung.wert AS aenderungswert_oe,oe_aenderung.gueltig_von AS gueltig_von_oe 
FROM tbl_uebertrag_abr_schaeffler_monatswerte AS abr
LEFT JOIN (
	SELECT "originalwerte am Tag aus Personalakte:" AS info, mw.key_datum,mw.persnr,mw.eg_original,
	       IFNULL(tr.OE_neu, mw.oe_person_original) AS oe_person, kon.oe_bericht as  oe_person_original
	FROM tbl_uebertrag_abr_schaeffler_monatswerte AS mw
	LEFT JOIN tbl_stamm_OE_translate AS tr ON tr.OE_alt = mw.oe_person_original
	LEFT JOIN tbl_konfiguration_eg_bereich_zuordnung AS kon ON kon.entgeltgruppe = mw.eg_original AND kon.oe_person = IFNULL(tr.OE_neu, mw.oe_person_original)
	WHERE key_datum >= "2026-03-04" AND mw.persnr > 0
	GROUP BY mw.key_datum,mw.persnr
) AS org ON org.persnr = abr.persnr AND org.key_datum = abr.datum
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,aw.gueltig_bis)
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Info 2" AND beschreibung <> "gelöscht" #"Organisationseinheit der Person" 
) AS eg_aenderung ON eg_aenderung.persnr = abr.persnr 
                  AND abr.datum BETWEEN eg_aenderung.gueltig_von AND eg_aenderung.gueltig_bis 
						AND eg_aenderung.gueltig_von < eg_aenderung.gueltig_bis 
LEFT JOIN (
				SELECT aw.persnr,aw.feld,wert,aw.gueltig_von,
				ifnull(DATE_SUB(
					LAG(aw.gueltig_von, -1) OVER (PARTITION BY aw.persnr,aw.feld ORDER BY aw.gueltig_von,aw.aenderungsdatum ASC)
						,INTERVAL 1 DAY) 
				,if(aw.gueltig_bis = "9999-12-31" ,NOW(),aw.gueltig_bis))
				AS gueltig_bis,
				aw.gueltig_bis AS gueltig_bis_org
				FROM tbl_uebertrag_aenderungen_werte AS aw
				WHERE feld = "Organisationseinheit der Person" AND beschreibung <> "gelöscht"
) AS oe_aenderung ON oe_aenderung.persnr = abr.persnr 
						AND abr.datum BETWEEN oe_aenderung.gueltig_von AND oe_aenderung.gueltig_bis 
						AND oe_aenderung.gueltig_von < oe_aenderung.gueltig_bis

#WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 3 MONTH))
WHERE org.persnr IS NOT NULL  AND org.key_datum <> abr.key_datum and   #abr.info = "Vormonat" AND  muss später aktiviert werden
(org.oe_person_original <> abr.oe_bericht OR org.eg_original <> abr.info_2)
AND abr.info_2 <> "AT"

*/
######################################################################################################
######################################################################################################
call schreibe_log("proc_02_nachtlauf", "Ende", 99);
END//
