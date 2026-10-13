-- Managed by db-workbench; source of truth: db-report/procedures/proc_05_uebertrag_kennzahlen_caps.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_05_uebertrag_kennzahlen_caps`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_05_uebertrag_kennzahlen_caps`()
SQL SECURITY DEFINER BEGIN
#Caps
call schreibe_log("proc_05_uebertrag_kennzahlen_caps", "Start", 0); 
INSERT ignore INTO tbl_abteilungen_caps
SELECT distinct caps.funktion,NULL,null 
FROM tbl_import_caps_rohdaten AS caps
LEFT JOIN tbl_abteilungen_caps AS abt ON abt.funktion_caps = caps.funktion
WHERE abt.funktion_caps IS NULL;




#SELECT abt.abteilung,abt.funktion,ifnull(ip.abteilung,abt.abteilung) AS abteilung,ifnull(ip.taetigkeit,abt.funktion)AS Funktion FROM 
update tbl_abteilungen_caps AS abt
LEFT JOIN tbl_import_caps_rohdaten AS caps ON abt.funktion_caps = caps.funktion
LEFT JOIN tbl_import_personalakte AS ip ON ip.pers_nr = caps.personalnummer
SET abt.abteilung = ip.oe_der_person,abt.funktion = ip.taetigkeit
WHERE abt.abteilung IS NULL OR abt.funktion IS NULL;


#Qualiquoten


#DELETE kz FROM tbl_uebertrag_kennzahlen AS kz 
#WHERE kz.kennzahl IN ("Gesamt DLZ Crossdock","TASK_WE_Behälter_vereinnahmt","TASK_WE_Behälter_vereinnahmt_vortag") 
#  AND kz.filedate >= DATE(NOW());

call schreibe_log("proc_05_uebertrag_kennzahlen_caps", "Step1", 1); 

#1.Übertrag Rohdaten Import in Übertragstabelle#################################################################

#2.Übertrag berechnete Kennzahlen#################################################################

insert ignore into tbl_uebertrag_kennzahlen_caps
SELECT 
DATE(ifnull(caps.filedate,NOW())) AS datum,
sum(if(replace(replace(replace(replace(caps.`status`,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"ÃŸ","ß")='Fähigkeit vorhanden' or caps.status='Nachweis läuft bald ab' , 1, 0)) AS Anzahl_Bestanden,
COUNT(*) AS Anzahl_Schulungen, 
#COUNT(DISTINCT caps.personalnummer) AS Anzahl_MA,
#Nur MA mit offenen Schulungen

COUNT(DISTINCT if(replace(replace(replace(replace(caps.`status`,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"ÃŸ","ß")='Nachweis erforderlich', caps.personalnummer,NULL)) AS Anzahl_MA,
ROUND(     sum(if(replace(replace(replace(replace(caps.`status`,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"ÃŸ","ß")='Fähigkeit vorhanden' 
	            or replace(replace(replace(replace(caps.`status`,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"ÃŸ","ß")='Nachweis läuft bald ab', 1, 0))/ COUNT(*) * 100 ,4) AS "Quote", 
"St" AS Einheit,
ifnull(caps.funktion,"") AS Funktionen,
IFNULL(ip.oe_der_person,"kein Bereich im Zeus") AS Bereiche,
"Caps" AS Kennzahl,###############################################
ifnull(replace(replace(replace(caps.rubrik,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"") as filtern,
"Schulung" AS gruppe,
NOW() AS Zeitstempel
FROM tbl_import_caps_rohdaten AS caps
LEFT JOIN tbl_import_personalakte AS ip ON ip.pers_nr = caps.personalnummer
LEFT JOIN tbl_abteilungen_caps AS abt ON abt.funktion_caps = caps.funktion
WHERE replace(replace(replace(replace(caps.`status`,"Ã¤","ä"),"Ã¼","ü"),"Ã¶","ö"),"ÃŸ","ß") <> 'Deaktiviert / Vorübergehend pausiert' and caps.status <> 'Einarbeitungszeit'
GROUP BY Bereiche,filtern;

call schreibe_log("proc_05_uebertrag_kennzahlen_caps", "Step2", 2); 

#3.Erstellung Kennzahl "Neu hinzugekommene Schulungen ggü. Vorwoche"#################################################################

#insert ignore INTO tbl_uebertrag_kennzahlen
#select
#caps1.lastinsertupdate as datum,
#count(caps1.mitarbeiter) as wert,
#count(distinct caps1.mitarbeiter) as anzahl,
#0 as zielwert,
#"ST" as einheit,
#"mehrere" as detail,
#mb.bwa as filter,
#"Anzahl_neue_Qualifikationen" as kennzahl,
#"MAT" as bereich,
#"CAPS" as system,
#now(),caps1.lastinsertupdate 
#from tbl_import_caps as caps1
#left join tbl_uebertrag_rohdaten_caps as caps2 on caps2.mitarbeiter = caps1.mitarbeiter and caps2.faehigkeit = caps1.faehigkeit
#where caps2.mitarbeiter is null;
#group by mb.buch_dat, mb.bwa;





END//
