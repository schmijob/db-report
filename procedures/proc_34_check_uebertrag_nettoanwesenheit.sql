-- Managed by db-workbench; source of truth: db-report/procedures/proc_34_check_uebertrag_nettoanwesenheit.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_34_check_uebertrag_nettoanwesenheit`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_34_check_uebertrag_nettoanwesenheit`()
SQL SECURITY DEFINER BEGIN

#Prüfung:		
#Anwesenheiten / Betriebszugehörigkeit

		SELECT* From
		tbl_uebertrag_nettoanwesenheit AS na
		WHERE na.filedate >= DATE_SUB(DATE(NOW()),INTERVAL 7 DAY) and
	 		(na.vortag IS NULL OR 
	 		na.abwesend IS NULL OR 
	 		na.tage_anwesend IS NULL OR 
	 		na.monate_anwesend IS NULL) and		
			na.persnr > 0 AND NOT (na.arbeitgeber = "Imperial Standort AVZ");

#Prüfung ob Datensatz als Funktion und als Verrechnungssatz existiert (AG / Funktion) 

SELECT* From
tbl_uebertrag_nettoanwesenheit AS na
LEFT JOIN (SELECT DISTINCT funktion, firmeneintrag_zeuss FROM tbl_uebertrag_verrechnungssaetze_zak) AS vs ON vs.funktion = na.funktion
AND vs.firmeneintrag_zeuss = na.arbeitgeber
where na.funktion IS NULL OR vs.funktion IS NULL;

#Prüfung Update auf Preisstaffeln und Zuschläge

SELECT* From 
tbl_uebertrag_nettoanwesenheit AS na
#inner JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.arbeitgeber 
#AND vs.funktion = na.funktion AND vs.preisstaffel = 0 
Where
(	EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 MONTH)) 
OR EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 - 1 MONTH)) 
OR na.update_stundensatz = 1
) 
AND ( 
na.preisstaffel IS NULL or
na.verrechnungssatz IS NULL or 
na.nachtzuschlag IS NULL or
na.ueberstunden_zs_ab_40h IS NULL or 
na.ueberstunden_zs_ab_41h IS NULL or
na.zs_feiertag IS NULL or 
na.zs_sonntag IS NULL);

			
END//
