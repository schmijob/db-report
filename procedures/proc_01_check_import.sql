-- Managed by db-workbench; source of truth: db-report/procedures/proc_01_check_import.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_01_check_import`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_01_check_import`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_01_check_import", "Start", 0);
SELECT 'tbl_import_buchungen_mitarbeiter' AS tabelle,MAX(filedate),MAX(last_insert_update),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk
FROM db_de_tal002_report.tbl_import_buchungen_mitarbeiter
UNION ALL
SELECT 'tbl_uebertrag_buchungen_mitarbeiter' AS tabelle,MAX(filedate),MAX(last_insert_update),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk
FROM db_de_tal002_report.tbl_uebertrag_buchungen_mitarbeiter
UNION all
SELECT 'tbl_import_fehlzeiten' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_fehlzeiten as tbl
UNION all
SELECT 'tbl_uebertrag_fehlzeiten' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_fehlzeiten as tbl
UNION all
SELECT 'tbl_import_personalakte' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_personalakte as tbl
#UNION all
#SELECT 'tbl_uebertrag_personalakte' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
#if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
#FROM db_de_tal002_report.tbl_uebertrag_personalakte as tbl########################################################
UNION ALL
SELECT 'tbl_import_personalstamm' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_personalstamm as tbl
#SELECT 'tbl_import_stundenreport' AS tabelle,MAX(tbl.filedate),MAX(tbl.last_insert_update),
#if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
#FROM tbl_import_stundenreport as tbl
#UNION all
#SELECT 'tbl_uebertrag_stundenreport' AS tabelle,MAX(tbl.filedate),MAX(tbl.last_insert_update),
#if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
#FROM tbl_uebertrag_stundenreport as tbl
UNION all
SELECT 'tbl_import_urlaubsvorschau' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_urlaubsvorschau as tbl
UNION all
SELECT 'tbl_uebertrag_urlaubsvorschau' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_urlaubsvorschau as tbl
UNION ALL
#SELECT 'tbl_import_training' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsterupdate),
#if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
#FROM db_de_tal002_report.tbl_import_training as tbl
#UNION all
SELECT 'tbl_uebertrag_kennzahlen_personal' AS tabelle,MAX(tbl.zeitstempel),MAX(tbl.zeitstempel),
if(DATE(MAX(zeitstempel))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_kennzahlen_personal as tbl
UNION ALL
SELECT 'tbl_import_aenderungen' AS tabelle,MAX(tbl.filedate),MAX(tbl.last_insert_update),
if(DATE(MAX(filedate)) >= DATE_SUB(NOW(),INTERVAL 2 day),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_aenderungen as tbl
WHERE MONTH(tbl.datum) = MONTH(tbl.filedate)
UNION ALL
SELECT 'tbl_import_nettoanwesenheit' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_nettoanwesenheit as tbl
WHERE MONTH(tbl.datum) = MONTH(tbl.filedate)
UNION ALL
SELECT 'tbl_uebertrag_nettoanwesenheit' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_nettoanwesenheit as tbl
WHERE MONTH(tbl.datum) = MONTH(tbl.filedate)
UNION ALL
SELECT 'tbl_uebertrag_abr_schaeffler_monatswerte (AM)' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_abr_schaeffler_monatswerte as tbl
WHERE tbl.filedate > DATE_SUB(DATE(NOW()),INTERVAL 5 day)
and MONTH(tbl.datum) = MONTH(tbl.filedate)
UNION all
SELECT 'tbl_uebertrag_abr_schaeffler_monatswerte (VM)' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_abr_schaeffler_monatswerte as tbl
WHERE tbl.filedate > DATE_SUB(DATE(NOW()),INTERVAL 5 day)
and MONTH(tbl.datum) <> MONTH(tbl.filedate)
UNION ALL
SELECT 'tbl_uebertrag_nettoanw_aend_management (AM)' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_nettoanw_aend_management as tbl
WHERE tbl.filedate > DATE_SUB(DATE(NOW()),INTERVAL 5 day)
and MONTH(tbl.datum) = MONTH(tbl.filedate)
UNION all
SELECT 'tbl_uebertrag_nettoanw_aend_management (VM)' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_uebertrag_nettoanw_aend_management as tbl
WHERE tbl.filedate > DATE_SUB(DATE(NOW()),INTERVAL 5 day)
and MONTH(tbl.datum) <> MONTH(tbl.filedate)
UNION all
SELECT 'tbl_import_leistungsstunden_untertaegig' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_leistungsstunden_untertaegig as tbl
UNION ALL
SELECT 'tbl_import_kst_umbuchungen_untertaegig' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_kst_umbuchungen_untertaegig as tbl
UNION ALL
SELECT 'tbl_import_claimx' AS tabelle,MAX(tbl.filedate),MAX(tbl.lastinsertupdate),
if(DATE(MAX(filedate))=DATE(NOW()),"OK","nio") AS Chk  
FROM db_de_tal002_report.tbl_import_claimx as tbl
;

call schreibe_log("proc_01_check_import", "Step1", 1);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Prüfen, wenn bei schichtverlängerung die Zeit bei 00:06 endet!! stunden müßten doch zum Packvolumen in den Vortag verschoben werden?

WITH tag_personal_kostenstelle AS (
	SELECT kst.datum, kst.personalnummer, kst.kostenstelle, CAST(DATE_FORMAT(kst.uhrzeit, '%Y-%m-%d %H:%i:00') AS DATETIME) AS beginn 
	#TIMESTAMPDIFF(MINUTE, CAST(DATE_FORMAT(kst.uhrzeit, '%Y-%m-%d %H:%i:00')AS DATETIME), kst.filedate) / 60.0 AS stunden
	FROM db_de_tal002_report.tbl_import_kst_umbuchungen_untertaegig AS kst
UNION 
	SELECT ls.datum, ls.personalnummer, ls.kostenstelle, CAST(DATE_FORMAT(ls.uhrzeit_beginn, '%Y-%m-%d %H:%i:00') AS DATETIME) AS beginn 
	#ls.leistungsstunden AS stunden
	FROM db_de_tal002_report.tbl_import_leistungsstunden_untertaegig AS ls
)
SELECT 
	per.datum,
   per.personalnummer, 
   per.kostenstelle,   
   kst.kostenstellenbezeichnung,
   kst.bereich,
   kst.funktion,
   per.beginn,
   if(SUM(ls.leistungsstunden) IS NOT NULL,ls.uhrzeit_ende,
	if(DATE_ADD(CURDATE(), INTERVAL st.ende HOUR_MINUTE) < kstb.filedate,DATE_ADD(CURDATE(), INTERVAL st.ende HOUR_MINUTE), kstb.filedate )) AS ende, 
   if(pa.taetigkeit2 = "Pausenvertretung","Pausenvertretung",pa.taetigkeit) AS taetigkeit,  
	if( if(SUM(ls.leistungsstunden) IS NOT NULL,SUM(ls.leistungsstunden),TIMESTAMPDIFF(MINUTE, per.beginn, kstb.filedate) / 60.0) < 9.0,
       if(SUM(ls.leistungsstunden) IS NOT NULL,SUM(ls.leistungsstunden),TIMESTAMPDIFF(MINUTE, per.beginn, kstb.filedate) / 60.0) ,
		 if(DATE_ADD(CURDATE(), INTERVAL st.ende HOUR_MINUTE) IS NOT NULL,TIMESTAMPDIFF(MINUTE, per.beginn, DATE_ADD(CURDATE(), INTERVAL st.ende HOUR_MINUTE)) / 60.0,8) - 
		 if(if(SUM(ls.leistungsstunden) IS NOT NULL,SUM(ls.leistungsstunden),TIMESTAMPDIFF(MINUTE, per.beginn, kstb.filedate) / 60.0) > 5, 0.5,0)
	)
	AS stunden, 
   (SELECT COUNT(*) FROM tag_personal_kostenstelle WHERE datum = per.datum and personalnummer = per.personalnummer) AS Anzahl_Buchungen,
   #<><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><><>
   if(ls.uhrzeit_ende IS NOT null, "Buchung abgeschlossen",
   if(ls.uhrzeit_ende IS null, "Buchung offen","") ) AS info,
   if(ls.uhrzeit_ende IS null, 
   	IFNULL((SELECT SUM(leistungsstunden)+0 FROM db_de_tal002_report.tbl_import_leistungsstunden_untertaegig 
		        WHERE datum = per.datum and personalnummer = per.personalnummer) ,0)
		+
		(SELECT max(TIMESTAMPDIFF(MINUTE, CAST(DATE_FORMAT(uhrzeit, '%Y-%m-%d %H:%i:00')AS DATETIME), filedate)) / 60.0 
		 FROM db_de_tal002_report.tbl_import_kst_umbuchungen_untertaegig WHERE datum = per.datum and personalnummer = per.personalnummer) 
	,
		null
	) AS Gesamtstundenpruefung,
	kstb.uhrzeit AS kst_Beginn_offene_Buchung,
	ls.uhrzeit_beginn AS ls_Beginn_Buchung,
	ls.uhrzeit_ende AS ls_Ende_Buchung,
	DATE_ADD(CURDATE(), INTERVAL st.ende HOUR_MINUTE) AS endzeit,
	#SUM(ls.leistungsstunden) AS leistungsstunden,
	#na.erste_bg AS Beginn_arbeitszeit,
	#na.letzte_bg AS Ende_arbeitszeit, 
   #sum(na.stunden) AS na_stunden,
	pa.schicht,na.schicht,na.pt,
   st.beginn,st.ende,   
	kstb.filedate,
	ls.filedate,
	na.filedate
FROM tag_personal_kostenstelle AS per
left join db_de_tal002_report.tbl_import_kst_umbuchungen_untertaegig AS kstb 
		on kstb.datum = per.datum AND kstb.personalnummer = per.personalnummer AND kstb.kostenstelle = per.kostenstelle 
		AND DATE_FORMAT(kstb.uhrzeit, '%Y-%m-%d %H:%i:00') = per.beginn
LEFT Join db_de_tal002_report.tbl_import_leistungsstunden_untertaegig AS ls
		ON ls.datum = per.datum AND ls.personalnummer = per.personalnummer AND ls.kostenstelle = per.kostenstelle 
		AND DATE_FORMAT(ls.uhrzeit_beginn, '%Y-%m-%d %H:%i:00') = per.beginn	
LEFT JOIN db_de_tal002_report.tbl_uebertrag_nettoanwesenheit AS na 
		ON na.datum = (SELECT MAX(datum) FROM db_de_tal002_report.tbl_import_kst_umbuchungen_untertaegig)
		AND na.persnr = per.personalnummer #AND na.hauptkostenstelle = per.kostenstelle 
		AND DATE_FORMAT(na.erste_bg, '%Y-%m-%d %H:%i:00') = per.beginn
left join db_de_tal002_report.tbl_kostenstellen as kst on kst.kostenstelle = per.kostenstelle
left join db_de_tal002_report.tbl_import_personalakte as pa on pa.pers_nr = per.personalnummer
LEFT JOIN db_de_tal002_report.tbl_konfiguration_schichten AS st ON st.schicht = IFLeerOrNULL(IFLeerOrNULL(na.pt,na.schicht),pa.schicht)
#where not(pa.feld2 in ("Lfz","Kk","URL","KO","Sch","KG"))	  
GROUP BY per.datum, per.personalnummer,per.kostenstelle,per.beginn;
call schreibe_log("proc_01_check_import", "Step2", 2);

SELECT key_datum,COUNT( DISTINCT datum) AS Tage , COUNT(*),filedate,
if(MONTH(datum) <> MONTH(filedate),'Vormonat','Aktueller') AS info 
FROM db_de_tal002_report.tbl_uebertrag_abr_schaeffler_monatswerte
WHERE filedate >= '2025-10-01'
GROUP BY filedate
ORDER BY filedate DESC,info;

call schreibe_log("proc_01_check_import", "Ende", 99);
END//
