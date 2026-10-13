-- Managed by db-workbench; source of truth: db-report/procedures/proc_05_uebertrag_kennzahlen_mindermenge.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_05_uebertrag_kennzahlen_mindermenge`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_05_uebertrag_kennzahlen_mindermenge`()
SQL SECURITY DEFINER BEGIN

call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "Start", 0);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

	replace INTO tbl_uebertrag_kennzahlen
	SELECT
	date(tab.erstellzeitpunkt) AS datum,
	COUNT(DISTINCT tab.nr_ausnahme) AS wert,
	(COUNT(DISTINCT tab.nr_ausnahme)*1500)/60 AS anzahl,
	(COUNT(DISTINCT tab.nr_ausnahme)*1500) * 0.67 AS zielwert,
	"Faelle" AS einheit,
	if(time_to_sec(time(tab.erstellzeitpunkt)) >= time_to_sec("22:00:00") OR time_to_sec(time(tab.erstellzeitpunkt)) < time_to_sec("06:00:00"), "Nachtschicht",
	if(time_to_sec(time(tab.erstellzeitpunkt)) >= time_to_sec("06:00:00") AND time_to_sec(time(tab.erstellzeitpunkt)) <= time_to_sec("14:00:00"),"Frühschicht",
	"Spätschicht")) as detail,
	"" AS filter,
	"Anzahl BGL Mindermenge" AS kennzahl,######################
	""  AS bereich,    #time(tab.erstellzeitpunkt) 
	"Alle" AS system,
	"" AS gruppe,
	now(),ifnull(tab.filedate,NOW())
	FROM  tbl_import_nio_prozess AS tab
	where tab.code_ausnahme = 2004 AND hu BETWEEN 4000000000 AND 4999999999
	GROUP BY datum,kennzahl,detail;

call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "KZ BGL", 2);
###########################################################################
	insert ignore into tbl_uebertrag_nio_prozess	
	select *
	FROM  tbl_import_nio_prozess;
call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "uebertrag", 3);
##########################################################################
call schreibe_log("proc_05_uebertrag_kennzahlen_mindermenge", "Ende", 4);	
	
	
END//
