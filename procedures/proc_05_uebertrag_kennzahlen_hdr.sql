-- Managed by db-workbench; source of truth: db-report/procedures/proc_05_uebertrag_kennzahlen_hdr.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_05_uebertrag_kennzahlen_hdr`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_05_uebertrag_kennzahlen_hdr`()
SQL SECURITY DEFINER BEGIN



DELETE FROM tbl_uebertrag_kennzahlen
WHERE kennzahl = "Anzahl Backlog KITS" AND datum = (SELECT MAX(DATE(last_insert_update)) FROM tbl_uebertrag_hdr where DATE(last_insert_update) = DATE(NOW()));
call schreibe_log("proc_05_uebertrag_kennzahlen_hdr", "löschen", 0);

#########################vvv#########################
	replace INTO tbl_uebertrag_kennzahlen
	SELECT
	(select max(date(filedate)) from tbl_uebertrag_hdr) AS datum,
	COUNT(DISTINCT tab.auftragsnr) AS wert,
	COUNT(DISTINCT tab.auftragsnr) AS anzahl,
	COUNT(DISTINCT tab.auftragsnr) AS zielwert,
	"Auftraege" AS einheit,
	if(tab.start_ust <> "0000-00-00 00:00:00", "Auftrag begonnen","Auftrag nicht begonnen") as detail,
	config.definition AS filter,
	"Anzahl Backlog KITS" AS kennzahl,######################
	ifnull(a.Arbeitsplatztyp,tab.auftragstyp) AS bereich,    #time(tab.erstellzeitpunkt) 
	"Alle" AS system,
	config.auftragsstatus AS gruppe,
	now(),ifnull(tab.filedate,tab.last_insert_update)
	FROM  tbl_uebertrag_hdr AS tab
	left join tbl_stamm_auftragsstatus as config on config.auftragsstatus_id = tab.auftragsstatus_id
	LEFT JOIN tbl_stamm_apid as a on a.Arbeitsplatz_ID = tab.apid
	where tab.auftragsstatus_id <> 11
	GROUP BY datum,kennzahl,bereich,detail,filter;
call schreibe_log("proc_05_uebertrag_kennzahlen_hdr", "KZ erstellen", 1);	
	
END//
