-- Managed by db-workbench; source of truth: db-report/procedures/proc_34_uebertrag_verrechnungssaetze_zak.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_34_uebertrag_verrechnungssaetze_zak`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_34_uebertrag_verrechnungssaetze_zak`()
SQL SECURITY DEFINER BEGIN
/*
DECLARE var_interval INT;
DECLARE var_jetzt DATETIME;
SELECT 4 INTO var_interval;
SELECT NOW() INTO var_jetzt;

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Start", 0);	
#-------------------------------------------------------------------

UPDATE 
#SELECT na.datum, vs.gueltig_ab, na.preisstaffel, na.zutritt, vs.firmeneintrag_zeuss, na.persnr FROM 
tbl_uebertrag_nettoanwesenheit AS na
inner JOIN tbl_uebertrag_nettoanwesenheit AS vs ON vs.firmeneintrag_zeuss=na.arbeitgeber #na.zutritt 
AND vs.funktion = if(`taetigkeit_14` <> "" AND taetigkeit <> "Teamleiter",`taetigkeit_14`,taetigkeit) AND vs.gueltig_ab >0 AND vs.preisstaffel = na.preisstaffel
AND na.datum >= vs.gueltig_ab AND EXTRACT(YEAR_MONTH FROM vs.gueltig_ab) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
SET na.update_stundensatz = 1, na.preisstaffel = null
WHERE (
	EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
);

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Step1", 1);	
#-------------------------------------------------------------------

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Step2", 2);	
#-------------------------------------------------------------------

CALL proc_34_uebertrag_nettoanwesenheit;

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Step3", 3);	
#-------------------------------------------------------------------

UPDATE 
#SELECT na.datum, vs.gueltig_ab, na.preisstaffel, na.zutritt, vs.firmeneintrag_zeuss, na.persnr FROM 
tbl_uebertrag_nettoanwesenheit AS na
SET na.update_stundensatz = 0
WHERE (
	EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
);

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Step4", 4);	
#-------------------------------------------------------------------


#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Ende", 99);	
#-------------------------------------------------------------------
*/
DECLARE var_interval INT;
DECLARE var_jetzt DATETIME;
#SET var_auswahl = 0;
#SELECT 0 into var_auswahl;
SELECT 4 INTO var_interval;
SELECT NOW() INTO var_jetzt;

call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Start", 0);
/*
UPDATE 
#SELECT na.datum, vs.gueltig_ab, na.preisstaffel, na.zutritt, vs.firmeneintrag_zeuss, na.persnr FROM 
tbl_uebertrag_nettoanwesenheit AS na
inner JOIN tbl_import_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.zutritt 
AND vs.funktion = na.funktion AND vs.gueltig_ab >0 AND vs.preisstaffel = na.preisstaffel
AND na.datum >= vs.gueltig_ab AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis)
SET na.update_stundensatz = 1, na.preisstaffel = NULL, na.ueberstunden_kw = Null
WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH));
*/

#true für Ausführen setzen, false deaktiviert!

if true then
	DELETE vsi FROM tbl_verrechnungssaetze_zak AS vsi
   WHERE EXTRACT(YEAR_MONTH FROM vsi.gueltig_bis) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH));
   
	INSERT INTO tbl_uebertrag_verrechnungssaetze_zak (firma, vertragsstatus, firmeneintrag_zeuss, preisstaffel, funktion, verrechnungssatz,
	nachtzuschlag, ueberstunden_zs_ab_40h, ueberstunden_zs_ab_41h, zs_feiertag, zs_sonntag,
	sonderzahlung, gueltig_ab, gueltig_bis,filedate)	
	SELECT vsi.firma, vsi.vertragsstatus, vsi.firmeneintrag_zeuss, vsi.preisstaffel, vsi.funktion, vsi.verrechnungssatz,
	vsi.nachtzuschlag, vsi.ueberstunden_zs_ab_40h, vsi.ueberstunden_zs_ab_41h, vsi.zs_feiertag, vsi.zs_sonntag,
	vsi.sonderzahlung, vsi.gueltig_ab, vsi.gueltig_bis ,vsi.filedate
	FROM tbl_import_verrechnungssaetze_zak AS vsi
	WHERE EXTRACT(YEAR_MONTH FROM vsi.gueltig_bis) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH));

END if;

#CALL proc_34_uebertrag_nettoanwesenheit;
/*
UPDATE 
#SELECT na.datum, vs.gueltig_ab, na.preisstaffel, na.zutritt, vs.firmeneintrag_zeuss, na.persnr FROM 
tbl_uebertrag_nettoanwesenheit AS na
SET na.update_stundensatz = 0
WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH));
*/
call schreibe_log("proc_34_uebertrag_verrechnungssaetze_zak", "Ende", 99);
END//
