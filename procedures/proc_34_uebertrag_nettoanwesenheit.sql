-- Managed by db-workbench; source of truth: db-report/procedures/proc_34_uebertrag_nettoanwesenheit.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_34_uebertrag_nettoanwesenheit`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_34_uebertrag_nettoanwesenheit`()
SQL SECURITY DEFINER BEGIN
DECLARE var_interval INT;
DECLARE var_jetzt DATETIME;
DECLARE var_vormonat INT;
#SET var_auswahl = 0;
#SELECT 0 into var_auswahl;
SELECT 3 INTO var_interval;
SELECT NOW() INTO var_jetzt;
SELECT month(MAX(datum)) <> month(MAX(filedate)) INTO var_vormonat FROM tbl_import_nettoanwesenheit;

#Uebertrag_der_aktuellen_Importdaten
#Änderungsmanagement
#Anwesenheiten / Betriebszugehörigkeit
#Prüfung auf ungültige oder fehlende Verrechnungssätze
#Preisstaffel 0
#Preisstaffel 9
#Preisstaffel 12
#Preisstaffel 13
#Feiertage
#Überstunden
#Überstunden pro Monat nach AT gestaffelt
#Nachtschichtzuschläge
#Sonderzahlung 10. Monat
#Leeren der Spalte na.pruefung für den letzten Monat
#Prüfung fehlender Einträge in Verrechnungssätzen 
#Zurücksetzen der Prüfspalte mit Fehlergrund
	


#-------------------------------------------------------------------		
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Start", 0);	
#-------------------------------------------------------------------	

INSERT ignore INTO tbl_uebertrag_verrechnungssaetze
SELECT
dat.datum, vs.*
FROM tbl_konfiguration_verrechnungssaetze AS vs, tbl_datum AS dat
WHERE dat.datum >= "2024-05-01" and dat.datum < NOW() AND dat.feiertag = 0;

		DELETE na From tbl_uebertrag_nettoanwesenheit AS na 
		WHERE na.datum IN(
								SELECT
								na2.datum
								FROM tbl_import_nettoanwesenheit AS na2
								#WHERE na2.datum > DATE_SUB(date(NOW()),INTERVAL 7 DAY)
								GROUP BY na2.datum);
								#AND na.update_stundensatz <> 1; #nur bei neu import leeren!!!
#-------------------------------------------------------------------		
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step1.1", 1);	
#-------------------------------------------------------------------				

		replace INTO tbl_uebertrag_nettoanwesenheit (
		id, persnr, name_vorname, ausweisnummer, arbeitgeber, abteilung,
		taetigkeit, beginn_besch, ende_besch, pt, schicht, erste_bg,
		letzte_bg, taetigkeit_14, info_2, ma_kreis, wt, datum,
		kein_einsatz, stunden, nacht_zuschlag, sonntag_zuschlag, mehr_zuschlag, feiertag_zuschlag,
		ft_140_la2230_gelnt_tag, ft_140_la2231_gelnt_tag, ft_140_la2102_gelnt_tag, n_25_gelnt_tag, ssf_gelnt_tag, ssp_gelnt_tag,
		gr_1_h_gelnt_tag, ab_4_h_tag_tag, ft_100_la2206_gelnt_tag, ft_100_la2108_gelnt_tag, krank_gemeldet_gelstd_tag, krank_lfz_gelstd_tag,
		krank_olfz_gelstd_tag, krank_au_liegt_vor_g_tag, kind_krank_gelstd_tag, arbeitsunfall_gelstd_tag, kur_lfz_gelstd_tag, urlaub_gelstd_tag,
		sonderurlaub_gelstd_tag, t_zug_geltag_tag, info_schul_gelstd_tag, schulung_gelstd_tag, fehlt_unentsch_tag, fehlt_entsch_g_tag,
		br_sitzung_gelstd_tag, dg_gelst_tag, gleitzeit_rstBr_tag, gleitzeit_gelnt_tag, schule_gelstd_tag, zaw_gelstd_tag,
		lastinsertupdate, filedate)
		Select na.id, na.persnr, na.name_vorname, na.ausweisnummer, na.arbeitgeber,
		na.abteilung, na.taetigkeit, na.beginn_besch, na.ende_besch, na.pt, na.schicht,
		na.erste_bg, na.letzte_bg, na.`14_taetigkeit`, na.info_2, na.ma_kreis,
		na.wt, na.datum, na.kein_einsatz, na.stunden/60, na.nacht_zuschlag/60, na.sonntag_zuschlag/60,
		na.mehr_zuschlag/60, na.feiertag_zuschlag/60, na.ft_140_la2230_gelnt_tag/60, na.ft_140_la2231_gelnt_tag/60, 
		na.ft_140_la2102_fz_ausgl_tag/60, na.n_25_gelnt_tag/60, na.ssf_gelnt_tag/60, na.ssp_gelnt_tag/60, 
		na.gr_1_h_gelnt_tag/60, na.ab_4_h_tag_tag/60, na.ft_100_la2206_gelnt_tag/60, na.ft_100_la2108_gelnt_tag/60, 
		na.krank_gemeldet_gelstd_tag/60,	na.krank_lfz_gelstd_tag/60, na.krank_olfz_gelstd_tag/60, na.krank_au_liegt_vor_g_tag/60, 
		na.kind_krank_gelstd_tag/60, na.arbeitsunfall_gelstd_tag/60, na.kur_lfz_gelstd_tag/60,na.urlaub_gelstd_tag/60, 
		na.sonderurlaub_gelstd_tag/60, na.t_zug_geltag_tag/60, na.info_schul_gelstd_tag/60, na.schulung_gelstd_tag/60, 
		na.fehlt_unentsch_tag/60,na.fehlt_entsch_g_tag/60, na.br_sitzung_gelstd_tag/60, na.dg_gelst_tag/60, 
		na.gleitzeit_rstBr_tag/60, na.gleitzeit_gelnt_tag/60, schule_gelstd_tag/60, zaw_gelstd_tag/60,		
		na.lastinsertupdate,na.filedate
		from tbl_import_nettoanwesenheit as na;
		
		#Wenn 1. Arbeitstag Nachtschichtverschiebung, muss ein Vortag erzeugt werden wohin die Stunden verschoben werden können. (Andernfalls sind diese weg) 

		INSERT INTO tbl_uebertrag_nettoanwesenheit (persnr, name_vorname, zutritt, `status`, taetigkeit, arbeitgeber, schicht, abteilung, erste_bg, letzte_bg, hauptkostenstelle, wt, datum, filedate)
		SELECT sr.persnr, pa.name_vorname, pa.zutritt, pa.`status`,pa.taetigkeit,pa.arbeitgeber,pa.schicht, pa.abteilung,
		0,0, pa.hauptkostenstelle, "So", sr.zuweisungstag, pa.filedate
		FROM view_sonderregelungen_nachschicht_feiertag AS sr 
		LEFT JOIN tbl_uebertrag_nettoanwesenheit AS na ON na.persnr = sr.persnr AND na.datum = sr.zuweisungstag
		LEFT JOIN (SELECT* FROM tbl_uebertrag_nettoanwesenheit GROUP BY persnr) AS pa ON pa.persnr = sr.persnr
		WHERE na.persnr IS NULL;
		
		#SELECT distinct na.datum, wt.kurz, WEEKDAY(na.datum), na.wt
		#From
		update 
		tbl_uebertrag_nettoanwesenheit AS na
		LEFT JOIN tbl_wochentag AS wt ON wt.id = WEEKDAY(na.datum)
		SET na.wt = wt.kurz
		WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
		AND (LENGTH(na.wt)<> 2 OR na.wt IS NULL);
		#ORDER BY datum desc
		
		
		#Archiv zwecks Nachverfolgung Änderungsmanagement
		
if HOUR(var_jetzt)< 5 or var_vormonat = 1 then
		
		insert ignore INTO tbl_uebertrag_nettoanw_aend_management (
		id, persnr, name_vorname, ausweisnummer, arbeitgeber, abteilung,
		taetigkeit, beginn_besch, ende_besch, pt, schicht, erste_bg,
		letzte_bg, taetigkeit_14, info_2, ma_kreis, wt, datum,
		kein_einsatz, stunden, nacht_zuschlag, sonntag_zuschlag, mehr_zuschlag, 
		feiertag_zuschlag, ft_140_la2230_gelnt_tag, ft_140_la2231_gelnt_tag, ft_140_la2102_gelnt_tag, 
		n_25_gelnt_tag, ssf_gelnt_tag, ssp_gelnt_tag,gr_1_h_gelnt_tag, ab_4_h_tag_tag, 		
		ft_100_la2206_gelnt_tag, ft_100_la2108_gelnt_tag, krank_gemeldet_gelstd_tag, krank_lfz_gelstd_tag,
		krank_olfz_gelstd_tag, krank_au_liegt_vor_g_tag, kind_krank_gelstd_tag, arbeitsunfall_gelstd_tag,		
		kur_lfz_gelstd_tag, urlaub_gelstd_tag,	sonderurlaub_gelstd_tag, t_zug_geltag_tag, 		
		info_schul_gelstd_tag, schulung_gelstd_tag, fehlt_unentsch_tag, fehlt_entsch_g_tag,
		br_sitzung_gelstd_tag, dg_gelst_tag, gleitzeit_rstBr_tag, gleitzeit_gelnt_tag, 
		`2106_ssp_gelnt_tag`, schule_gelstd_tag, zaw_gelstd_tag,
		lastinsertupdate, filedate)
		Select 
		na.id, na.persnr, na.name_vorname, na.ausweisnummer, na.arbeitgeber,	na.abteilung, 
		na.taetigkeit, na.beginn_besch, na.ende_besch, na.pt, na.schicht,	na.erste_bg, 
		na.letzte_bg, na.`14_taetigkeit`, na.info_2, na.ma_kreis,na.wt, na.datum, 
		na.kein_einsatz/60, na.stunden/60, na.nacht_zuschlag/60, na.sonntag_zuschlag/60, na.mehr_zuschlag/60, 
		na.feiertag_zuschlag/60, na.ft_140_la2230_gelnt_tag/60, na.ft_140_la2231_gelnt_tag/60, na.ft_140_la2102_fz_ausgl_tag/60, 
		na.n_25_gelnt_tag/60, na.ssf_gelnt_tag/60, na.ssp_gelnt_tag/60, na.gr_1_h_gelnt_tag/60, na.ab_4_h_tag_tag/60, 		
		na.ft_100_la2206_gelnt_tag/60, na.ft_100_la2108_gelnt_tag/60, na.krank_gemeldet_gelstd_tag/60,	na.krank_lfz_gelstd_tag/60,		
		na.krank_olfz_gelstd_tag/60, na.krank_au_liegt_vor_g_tag/60, na.kind_krank_gelstd_tag/60, na.arbeitsunfall_gelstd_tag/60, 		
		na.kur_lfz_gelstd_tag/60,na.urlaub_gelstd_tag/60, 	na.sonderurlaub_gelstd_tag/60, na.t_zug_geltag_tag/60, 		
		na.info_schul_gelstd_tag/60, na.schulung_gelstd_tag/60, na.fehlt_unentsch_tag/60,na.fehlt_entsch_g_tag/60, 
		na.br_sitzung_gelstd_tag/60, na.dg_gelst_tag/60,na.gleitzeit_rstBr_tag/60, na.gleitzeit_gelnt_tag/60, 
		na.`2106_ssp_gelnt_tag`/60,na.schule_gelstd_tag/60,na.zaw_gelstd_tag/60,
		na.lastinsertupdate,na.filedate
		from tbl_import_nettoanwesenheit as na;
		
END if;

		
#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step1", 1);	
#-------------------------------------------------------------------
#
#Identifiziert Tage für Feiertags,- Nachtschichtregelung 
#
#UPDATE tbl_uebertrag_nettoanwesenheit AS na SET na.stundenkorrektur_anweisung = NULL WHERE na.datum >= "2025-01-01";
#SELECT na.datum, na.persnr, na.name_vorname, na.arbeitgeber,na.erste_bg, na.letzte_bg,na.stundenkorrektur_anweisung,
# ifnull(if(vt.feiertag = 1, ftk.feiertagkorrektur_anweisung,NULL),ntk.stundenkorrektur_anweisung) AS korrektur_anweisung,
# na.stunden,na.nacht_zuschlag,na.feiertag_zuschlag,na.sonntag_zuschlag,
# vt.feiertag  FROM
UPDATE 
tbl_uebertrag_nettoanwesenheit AS na
LEFT JOIN tbl_datum AS vt ON vt.datum = date(na.erste_bg) and vt.feiertag = 1
inner JOIN tbl_datum AS dt ON dt.datum = date(na.letzte_bg)
left JOIN tbl_zeitarbeitsfirmen AS ntk ON ntk.pdl=na.arbeitgeber AND ntk.stundenkorrektur_anweisung IS NOT null AND  (WEEKDAY(na.datum) = 0 OR DAYOFMONTH(na.datum) = 1)
left JOIN tbl_zeitarbeitsfirmen AS ftk ON ftk.pdl=na.arbeitgeber AND ftk.feiertagkorrektur_anweisung IS NOT NULL
SET na.stundenkorrektur_anweisung = ifnull(if(vt.feiertag = 1, ftk.feiertagkorrektur_anweisung,NULL),ntk.stundenkorrektur_anweisung)
WHERE na.datum >= "2025-01-01" #EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 3 MONTH))	   
AND date(na.erste_bg) <> date(na.letzte_bg) 
AND (ifnull(if(vt.feiertag = 1, ftk.feiertagkorrektur_anweisung,NULL),ntk.stundenkorrektur_anweisung) IS NOT NULL)
AND na.stundenkorrektur_anweisung IS NULL
ORDER BY na.datum;

call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step2", 2);
#Fortlaufende Berechnungen:		
#Anwesenheiten / Betriebszugehörigkeit
			
	/*SELECT na.datum, 
	na.persnr,
	na.name_vorname,
	na.taetigkeit,
	na.erste_bg,
	na.letzte_bg,
	na.nacht_zuschlag,
	na.samstag_zuschlag,
	na.stunden,
	SUM(na.stunden),
	na.abwesenheitsgrund, 
	(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr) AS erste_buchungen,
	(SELECT max(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr AND datum < na.datum) AS vortag,
	DATEDIFF(na.datum,(SELECT max(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr AND datum < na.datum))-1 as Abwesend,
	if(DATEDIFF(na.datum,(SELECT max(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr AND datum < na.datum))-1> 91,"Prüfen","") AS Abwesend_CHECK,
	DATEDIFF(na.datum,if(na.datum < na.erste_buchung ,(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr),na.erste_buchung)) AS Tage_Anwesend,
	if(na.datum < na.erste_buchung, "Prüfen","") AS checking,
	##ROUND((
	##DATEDIFF(na.datum,if(na.datum < na.erste_buchung ,(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr),na.erste_buchung))/30.5)-0.4999,0)+1 AS Anwesende_Monate,
	TIMESTAMPDIFF(MONTH,if(na.datum < na.erste_buchung ,(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr),na.erste_buchung),na.datum) AS Anwesende_Monate
	FROM */
		update 
		tbl_uebertrag_nettoanwesenheit AS na
		SET
	 		na.vortag = (SELECT max(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr AND datum < na.datum),
	 		na.abwesend = DATEDIFF(na.datum,(SELECT max(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr AND datum < na.datum))-1,
	 		na.tage_anwesend = DATEDIFF(na.datum,if(na.datum < na.erste_buchung ,(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr),na.erste_buchung)),
	 		na.monate_anwesend = TIMESTAMPDIFF(MONTH,if(na.datum < na.erste_buchung ,(SELECT min(datum) AS vortag FROM tbl_uebertrag_nettoanwesenheit WHERE persnr = na.persnr),na.erste_buchung),na.datum)
		WHERE #(na.filedate >= DATE_SUB(DATE(NOW()),INTERVAL 7 day)
		na.ma_kreis = "ZAK" 
		AND na.monate_anwesend IS NULL#) OR na.update_stundensatz = 1 OR na.update_persnr = 1
		#AND EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 0 MONTH))
	/*GROUP BY datum,na.persnr	ORDER BY na.persnr, na.datum*/
	;
#-------------------------------------------------------------------	
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step3", 3);
#-------------------------------------------------------------------
#Spalte Funktion einheitlich befüllen (wird aktuell nicht benötigt, weil Spalte berits Stapler und... beinhaltet)

update 
tbl_uebertrag_nettoanwesenheit AS na
SET na.funktion = na.taetigkeit
where na.funktion IS NULL;

#-------------------------------------------------------------------	
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step4", 4);
#-------------------------------------------------------------------

#Prüfung auf ungültige oder fehlende Verrechnungssätze,
#Kennzeichnung zwecks Update
#***********************************************************

#SELECT na.datum, na.arbeitgeber, vs.firmeneintrag_zeuss, na.funktion, na.monate_anwesend, na.update_stundensatz, na.preisstaffel, vs.preisstaffel, vs.verrechnungssatz,
#na.verrechnungssatz,
#vs.ueberstunden_zs_ab_41h, na.ueberstunden_zs_ab_41h, vs.zs_feiertag, na.zs_feiertag, vs.zs_sonntag, na.zs_sonntag,
#vs.sonderzahlung, na.sonderzahlung FROM
UPDATE 
tbl_uebertrag_nettoanwesenheit AS na
inner JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.arbeitgeber 
AND vs.funktion = na.funktion AND vs.preisstaffel = 0 AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis)
SET na.update_stundensatz = 1
WHERE 
EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
AND vs.verrechnungssatz <> na.verrechnungssatz 
and na.ma_kreis = "ZAK";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step5", 5);
#-------------------------------------------------------------------
#Preisstaffel 0

#SELECT na.datum, na.arbeitgeber, vs.firmeneintrag_zeuss, na.funktion, na.monate_anwesend, na.update_stundensatz, na.preisstaffel, vs.preisstaffel, vs.verrechnungssatz,
#na.verrechnungssatz,
#vs.ueberstunden_zs_ab_41h, na.ueberstunden_zs_ab_41h, vs.zs_feiertag, na.zs_feiertag, vs.zs_sonntag, na.zs_sonntag,
#vs.sonderzahlung, na.sonderzahlung FROM
UPDATE 
tbl_uebertrag_nettoanwesenheit AS na
inner JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.arbeitgeber 
AND vs.funktion = na.funktion AND vs.preisstaffel = 0 AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis)
SET na.preisstaffel = vs.preisstaffel, na.verrechnungssatz = vs.verrechnungssatz, na.nachtzuschlag = vs.nachtzuschlag,
na.ueberstunden_zs_ab_40h = vs.ueberstunden_zs_ab_40h, na.ueberstunden_zs_ab_41h = vs.ueberstunden_zs_ab_41h,
na.zs_feiertag = vs.zs_feiertag, na.zs_sonntag = vs.zs_sonntag
WHERE
EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
AND (na.preisstaffel IS NULL OR na.update_stundensatz = 1)
and na.ma_kreis = "ZAK";


#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step6", 6);
#-------------------------------------------------------------------
#Anpassung Stundensätze Pausenvertretung wenn von Lagerhelfer abweicht !!!


#SELECT na.datum, na.arbeitgeber, vs.firmeneintrag_zeuss, na.funktion, na.taetigkeit_14, na.monate_anwesend, na.update_stundensatz, na.preisstaffel, vs.preisstaffel, vs.verrechnungssatz,
#na.verrechnungssatz,
#vs.ueberstunden_zs_ab_41h, na.ueberstunden_zs_ab_41h, vs.zs_feiertag, na.zs_feiertag, vs.zs_sonntag, na.zs_sonntag,
#vs.sonderzahlung, na.sonderzahlung FROM
UPDATE
tbl_uebertrag_nettoanwesenheit AS na
inner JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.arbeitgeber 
AND vs.funktion = taetigkeit_14 AND vs.preisstaffel = 0 AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis)
SET na.preisstaffel = vs.preisstaffel, na.verrechnungssatz = vs.verrechnungssatz, na.nachtzuschlag = vs.nachtzuschlag,
na.ueberstunden_zs_ab_40h = vs.ueberstunden_zs_ab_40h, na.ueberstunden_zs_ab_41h = vs.ueberstunden_zs_ab_41h,
na.zs_feiertag = vs.zs_feiertag, na.zs_sonntag = vs.zs_sonntag
WHERE
EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
#AND 
#(na.preisstaffel IS NULL OR na.update_stundensatz = 1)
and na.ma_kreis = "ZAK" AND na.taetigkeit_14 = "Pausenvertretung";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step7", 7);
#-------------------------------------------------------------------
#Überstunden 40 h pro Woche

#es muss noch geprüft werden, wenn Sa-Arbeit darf Überstunde nicht für Freitag und Sa. ermittelt werden, 
#Voraussetzung Sa. = AT Zeile 21


#SELECT na.persnr, na.datum, na.ueberstunden_kw, filtern.ueberstunden FROM 
update 
tbl_uebertrag_nettoanwesenheit AS na
INNER JOIN (
		SELECT 
		na.persnr,
		WEEK(na.datum) AS kw,
		MAX(na.datum) AS tag,
		WEEKDAY(MAX(na.datum)) AS WT,
		round(SUM(na.stunden),3) AS stunden,
		round(SUM(na.stunden)-zu.ueberstunden,3) AS ueberstunden,
		zu.ueberstunden AS stundengrenze
		FROM tbl_uebertrag_nettoanwesenheit AS na
		INNER JOIN tbl_zeitarbeitsfirmen AS zu ON zu.pdl = na.arbeitgeber AND zu.ueberstunden IS NOT NULL 
		#left JOIN tbl_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.zutritt 
		WHERE na.datum > "2024-01-01" AND persnr > 0 #AND na.arbeitgeber= "ZAK Standort AVZ"
		AND WEEKDAY(na.datum) <5 #Wenn Samstag = AT dann <=5 bzw. <6
		GROUP BY na.persnr, WEEK(na.datum), Year(na.datum) 
		HAVING stunden > stundengrenze
) AS filtern ON filtern.tag = na.datum AND filtern.persnr = na.persnr
SET na.ueberstunden_kw = filtern.ueberstunden
WHERE (
	EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
) AND (na.ueberstunden_kw IS NULL OR na.update_stundensatz = 1)
and na.ma_kreis = "ZAK";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step8", 8);
#-------------------------------------------------------------------

#Überstunden pro Monat nach AT gestaffelt 

UPDATE tbl_uebertrag_nettoanwesenheit AS naw 
#SELECT* FROM tbl_uebertrag_nettoanwesenheit AS naw 
INNER JOIN(
SELECT na.persnr AS personalnr, 
	max(na.datum) as datum, 
	na.arbeitgeber, 
	SUM(na.stunden) AS monatsstunden, 
	zfi.grenze,
	round(SUM(na.stunden)-zfi.grenze,2) AS ueberstunden
	FROM 
	#update 
	tbl_uebertrag_nettoanwesenheit AS na
		INNER JOIN (SELECT zf.pdl,
				if(SUM(dat.arbeitstag)=20,zf.monatstage_20,
				if(SUM(dat.arbeitstag)=21,zf.monatstage_21,
				if(SUM(dat.arbeitstag)=22,zf.monatstage_22,
				if(SUM(dat.arbeitstag)=23,zf.monatstage_23,
				NULL)))) AS grenze,
				SUM(dat.arbeitstag) AS arbeitstage
		FROM tbl_datum AS dat,tbl_zeitarbeitsfirmen AS zf
		Where	EXTRACT(YEAR_MONTH FROM dat.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) #Vormonat
		#Where	EXTRACT(YEAR_MONTH FROM dat.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 MONTH)) #Vormonat
		AND zf.ueberstunden IS null  
		GROUP BY pdl) 
	AS zfi ON zfi.pdl = na.arbeitgeber
	WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) #Vormonat
	#WHERE EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 MONTH)) #Vormonat
	GROUP BY personalnr
	HAVING monatsstunden > grenze
) AS filtern ON filtern.personalnr = naw.persnr AND filtern.datum = naw.datum
SET naw.ueberstunden_kw = ueberstunden 
WHERE EXTRACT(YEAR_MONTH FROM naw.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
AND (naw.ueberstunden_kw IS NULL OR naw.update_stundensatz = 1)
and naw.ma_kreis = "ZAK";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step9", 9);
#-------------------------------------------------------------------

#Nachtschichtzuschläge

#UPDATE tbl_uebertrag_nettoanwesenheit AS naw
##SELECT naw.persnr, naw.datum, naw.nacht_zuschlag, zf.nachtzuschl_korrektur, 
##(naw.nacht_zuschlag + zf.nachtzuschl_korrektur) AS nacht_zuschlag_korr
##FROM tbl_uebertrag_nettoanwesenheit AS naw
#INNER JOIN tbl_zeitarbeitsfirmen AS zf ON zf.pdl = naw.arbeitgeber
#SET naw.nacht_zuschlag_korr = zf.nachtzuschl_korrektur #= round(naw.nacht_zuschlag+zf.nachtzuschl_korrektur,2)
#WHERE EXTRACT(YEAR_MONTH FROM naw.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 MONTH)) #Vormonat
#and naw.nacht_zuschlag >0
#and zf.nachtzuschl_korrektur IS NOT NULL AND naw.nacht_zuschlag_korr IS null;

#GROUP BY persnr, datum

#-------------------------------------------------------------------
#call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step13", 13);
#-------------------------------------------------------------------

#Sonderzahlung 10. Monat (zum 1. des 10. anwesenden Monats zugeordnet)

##UPDATE tbl_uebertrag_nettoanwesenheit AS na2 SET na2.sonderzahlung = NULL;

#SELECT na2.* FROM
#Update 
#tbl_uebertrag_nettoanwesenheit AS na2
#INNER JOIN(SELECT
#				na.persnr, na.zutritt,na.funktion,na.monate_anwesend,min(na.datum) AS datum, na.arbeitgeber, vs.sonderzahlung#, vs.*
#				FROM tbl_uebertrag_nettoanwesenheit AS na
#				inner JOIN (SELECT vz.firmeneintrag_zeuss AS firma,vz.preisstaffel,vz.funktion,vz.sonderzahlung FROM tbl_verrechnungssaetze_zak AS vz WHERE vz.sonderzahlung > 0) AS vs ON vs.firma=na.zutritt
#				AND vs.funktion = na.funktion
#				where na.arbeitgeber= "ZAK Standort AVZ" AND na.monate_anwesend = 10
#				GROUP BY na.persnr) AS filtern ON filtern.persnr = na2.persnr AND filtern.datum = na2.datum
#SET na2.sonderzahlung = filtern.sonderzahlung
#WHERE EXTRACT(YEAR_MONTH FROM na2.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
#and na2.sonderzahlung IS NULL;
/*
if EXTRACT(YEAR_MONTH FROM var_jetzt) = EXTRACT(YEAR_MONTH FROM(CONCAT(YEAR(NOW()),"-12-01"))) then
#if TIME_TO_SEC(timediff(var_jetzt,var_jetzt)) > 0 AND TIME_TO_SEC(timediff(var_jetzt,var_jetzt)) < 0 then
	#SELECT na2.* , vs.sonderzahlung,  If(vs.sonderzahlung is NULL, "Sonderzahlung Prüfen", NULL) FROM
	Update 
	tbl_uebertrag_nettoanwesenheit AS na2
	left JOIN (SELECT vz.firmeneintrag_zeuss AS firma,vz.preisstaffel,vz.funktion,vz.sonderzahlung FROM tbl_uebertrag_verrechnungssaetze_zak AS vz WHERE vz.sonderzahlung > 0) AS vs ON vs.firma=na2.zutritt
	AND vs.funktion = na2.funktion
	SET na2.sonderzahlung = vz.sonderzahlung, na2.pruefung = If(vs.sonderzahlung is NULL, "Sonderzahlung Prüfen", NULL)
	WHERE (na2.arbeitgeber= "ZAK Standort AVZ"
	And na2.datum = CONCAT(YEAR(NOW()),"-11-30") AND monate_anwesend >= 10 
	and na2.sonderzahlung IS NULL) OR na.update_stundensatz = 1;
END if;
#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step13", 13);
#-------------------------------------------------------------------
*/

#-------------------------------------------------------------------
#--------------------------Prüfungen: ------------------------------
#-------------------------------------------------------------------

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step10", 10);
#-------------------------------------------------------------------

#Leeren der Spalte na.pruefung für den letzten Monat

update 
tbl_uebertrag_nettoanwesenheit AS na
SET na.pruefung = NULL
WHERE EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
and na.ma_kreis = "ZAK";
#(
	#EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
#OR EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval -1 MONTH)));
#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step11", 11);
#-------------------------------------------------------------------

# Prüfung fehlender Einträge in Verrechnungssätzen 

#SELECT * FROM
UPDATE 
tbl_uebertrag_nettoanwesenheit AS na
left JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.zutritt 
AND vs.funktion = na.funktion AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis)
SET na.pruefung = "Kein Eintrag in den Verrechungssätzen"
WHERE (EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
#OR EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval -1 MONTH)) 
OR na.update_stundensatz = 1)
#AND na.arbeitgeber= "ZAK Standort AVZ" 
AND na.preisstaffel IS NULL  
AND na.pruefung IS NULL
and na.ma_kreis = "ZAK";


#Updatefehler Nachtschicht + Korrektur

#UPDATE tbl_uebertrag_nettoanwesenheit AS naw
#SELECT naw.persnr, naw.datum, naw.nacht_zuschlag, zf.nachtzuschl_korrektur, 
#naw.nacht_zuschlag_korr, "Updatefehler Nachtschicht" AS test
#FROM tbl_uebertrag_nettoanwesenheit AS naw
#INNER JOIN tbl_zeitarbeitsfirmen AS zf ON zf.pdl = naw.arbeitgeber and zf.nachtzuschl_korrektur IS NOT NULL
#SET naw.pruefung = "Update Nachtschicht prüfen"
#WHERE EXTRACT(YEAR_MONTH FROM naw.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) #Vormonat
#and naw.nacht_zuschlag >0
#AND (naw.nacht_zuschlag_korr IS NULL OR naw.nacht_zuschlag_korr <> zf.nachtzuschl_korrektur)
#and naw.ma_kreis = "ZAK";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step12", 12);
#-------------------------------------------------------------------

#Zurücksetzen der Prüfspalte mit Fehlergrund

#SELECT * FROM
UPDATE 
tbl_uebertrag_nettoanwesenheit AS na
left JOIN tbl_uebertrag_verrechnungssaetze_zak AS vs ON vs.firmeneintrag_zeuss=na.zutritt 
AND vs.funktion = na.funktion AND (na.datum BETWEEN vs.gueltig_ab AND vs.gueltig_bis) 
SET na.pruefung = null
WHERE (
	EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH)) 
#OR EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval -1 MONTH)) 
OR na.update_stundensatz = 1
)
#AND na.arbeitgeber= "ZAK Standort AVZ" 
AND not(na.preisstaffel IS NULL)
AND na.pruefung = "Kein Eintrag in den Verrechungssätzen"
and na.ma_kreis = "ZAK";


#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step13", 13);
#-------------------------------------------------------------------

#Zurücksetzen der Spalte Update Stundensatz


UPDATE 
#SELECT na.datum, vs.gueltig_ab, na.preisstaffel, na.zutritt, vs.firmeneintrag_zeuss, na.persnr FROM 
tbl_uebertrag_nettoanwesenheit AS na
SET na.update_stundensatz = 0
WHERE EXTRACT(YEAR_MONTH FROM na.datum) = EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL var_interval MONTH))
and na.ma_kreis = "ZAK";

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step14", 14);
#-------------------------------------------------------------------
#SELECT na.persnr,na.datum,zo.*,
#na.filedate
#FROM 
update
tbl_uebertrag_nettoanw_aend_management AS na
LEFT JOIN view_mitarbeiter_zuordnung_uet AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
SET na.taetigkeit_korrigiert = zo.taetigkeit,
    na.taetigkeit14_korrigiert = zo.taetigkeit14,
    na.abteilung_korrigiert = zo.abteilung,
    na.entgeldgruppe_korrigiert = zo.entgeldgruppe,
    na.abwesenheitsgrund_korrigiert = zo.abwesenheitsgrund,
    na.oe_der_person_korrigiert = zo.oe_der_person,
    na.import_version = if(month(na.datum) = month(na.filedate),"aktueller Monat","Vormonat")
WHERE na.filedate > DATE_SUB(DATE(NOW()),INTERVAL 5 DAY)
and DATE(na.filedate) = DATE(zo.filedate)
AND (na.taetigkeit_korrigiert IS NULL OR entgeldgruppe_korrigiert IS null); #DATE(NOW()); #AND na.persnr = 92310;


#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step15", 15);
#-------------------------------------------------------------------
#Befüllen tbl_uebertrag_abr_schaeffler_monatswerte (kumulierte Monatssicht) mit Nettoanwesenheit

if HOUR(var_jetzt) < 5 or var_vormonat = 1 then 

		#update
		#tbl_uebertrag_abr_schaeffler_monatswerte as na 
      #SET na.abrechnung_monat = na.stunden + na.dg_gelst_monat + na.schulung_gelstd_monat + na.br_sitzung_gelstd_monat ,
      #na.o_schulung           = na.stunden + na.dg_gelst_monat + na.schule_gelst_monat + na.br_sitzung_gelstd_monat
		#WHERE MONTH(key_datum) = MONTH(datum)

		INSERT ignore INTO tbl_uebertrag_abr_schaeffler_monatswerte
		(
		key_datum,persnr,info_2,oe_person,schicht,team,name_vorname,zuordnung,arbeitgeber,taetigkeit,ma_kreis,wt,datum,
		stunden,abrechnung_monat,o_schulung,zak_gel_nt_monat,nacht_25_gelnt_monat,sonn_50_gelnt_monat,
		feiertag_100_gelnt_monat,mehr_25_gelnt_monat,intern_gelnt_monat,n_25_gelnt_monat,ssf_50_gelnt_monat,
		ssp_50_gelnt_monat,gr_1_h_gelnt_monat,ab_4_h_tag_monat,ft_100_la2206_gelnt_monat,ft_100_la2108_gelnt_monat,
		ft_140_la2230_gelnt_monat,ft_140_la2231_gelnt_monat,ft_140_la2102_gelnt_monat,krank_lfz_gelstd_monat,krank_olfz_gelstd_monat,
		krank_au_liegt_vor_g_monat,krank_gemeldet_gelstd_monat,info_schul_gelstd_monat,schulung_gelstd_monat,urlaub_gelstd_monat,
		br_sitzung_gelstd_monat,fehlt_entsch_g_monat,sonderurlaub_gelstd_monat,arbeitsunfall_gelstd_monat,kind_krank_gelstd_monat,
		t_zug_geltag_monat,kur_lfz_gelstd_monat,dg_gelst_monat,fehlt_unentsch_monat,gleitzeit_rstBr_monat,
		gleitzeit_rstnt_monat,schule_gelst_monat,kein_einsatz,`2106_ssp_gelnt_monat`,zaw_gelstd_monat,
		update_stundensatz,update_persnr,lastinsertupdate,filedate,info,eg_original,oe_person_original,
		gueltig_von_eg,gueltig_von_oe,oe_bericht
		)
		#na.beginn_besch, na.ende_besch, na.pt,
		#na.erste_bg, na.letzte_bg,		na.kein_einsatz, 	
		
	   Select DATE(na.filedate) AS key_datum, na.persnr,
		ifnull(zo.entgeldgruppe, na.info_2) AS info2_neu,
      IFLeerOrNull(zo.Abteilung_Uebersetzt,na.abteilung)  AS oe_person_neu,  
		na.schicht,pa.team,na.name_vorname,
      IFLeerOrNull(zo.zuordnung,"") AS stellung,  
		na.arbeitgeber, na.taetigkeit,	#na.`14_taetigkeit`
		na.ma_kreis,wt.kurz,min(na.datum) AS datum,
		#2.---------
		SUM(na.stunden/60) AS stunden,
		SUM((na.stunden + na.dg_gelst_tag + na.schulung_gelstd_tag + na.br_sitzung_gelstd_tag)/60) AS abrechnung_monat,
      SUM((na.stunden + na.dg_gelst_tag + na.br_sitzung_gelstd_tag + na.schule_gelstd_tag)/60) AS o_schulung,
		SUM(if(na.arbeitgeber = "",0,na.stunden)/60) as zak_gel_nt,
		sum(na.nacht_zuschlag/60) AS nacht_25_gelnt,  
		sum(na.sonntag_zuschlag/60) AS sonn_50_gelnt,
		#3.---------
		sum(na.feiertag_zuschlag/60) AS feiertag_100_gelnt,
		sum(na.mehr_zuschlag/60) AS mehr_25_gelnt,
		SUM(if(na.arbeitgeber = "",na.stunden,0)/60) as intern_gelnt,
		sum(na.n_25_gelnt_tag/60) AS n_25_gelnt,
		sum(na.ssf_gelnt_tag/60) as ssf_50_gelnt,
		#4.---------
		sum(na.ssp_gelnt_tag/60) as ssp_50_gelnt,
		sum(na.gr_1_h_gelnt_tag/60) as gr_1_h_gelnt,
		sum(na.ab_4_h_tag_tag/60) as ab_4_h_tag,
		sum(na.ft_100_la2206_gelnt_tag/60) as ft_100_la2206_gelnt,
		sum(na.ft_100_la2108_gelnt_tag/60) as ft_100_la2108_gelnt,
		#5.---------
		sum(na.ft_140_la2230_gelnt_tag/60) as ft_140_la2230_gelnt,
		sum(na.ft_140_la2231_gelnt_tag/60) as ft_140_la2231_gelnt,
		sum(na.ft_140_la2102_fz_ausgl_tag/60) as ft_140_la2102_gelnt,
		sum(na.krank_lfz_gelstd_tag/60) as krank_lfz_gelstd,
		sum(na.krank_olfz_gelstd_tag/60) as krank_olfz_gelstd,
		#6.---------
		sum(na.krank_au_liegt_vor_g_tag/60) as krank_au_liegt_vor_g,
		sum(na.krank_gemeldet_gelstd_tag/60) as krank_gemeldet_gelstd,
		sum(na.info_schul_gelstd_tag/60) as info_schul_gelstd,
		sum(na.schulung_gelstd_tag/60) as schulung_gelstd,
		sum(na.urlaub_gelstd_tag/60) as urlaub_gelstd,
		#7.---------
		sum(na.br_sitzung_gelstd_tag/60) as br_sitzung_gelstd,
		sum(na.fehlt_entsch_g_tag/60) as fehlt_entsch_g,
		sum(na.sonderurlaub_gelstd_tag/60) as sonderurlaub_gelstd,
		sum(na.arbeitsunfall_gelstd_tag/60) as arbeitsunfall_gelstd,
		sum(na.kind_krank_gelstd_tag/60) as kind_krank_gelstd,
		#8.---------
		sum(na.t_zug_geltag_tag/60) as t_zug_geltag,
		sum(na.kur_lfz_gelstd_tag/60) as kur_lfz_gelstd,
		sum(na.dg_gelst_tag/60) as dg_gelst,
		sum(na.fehlt_unentsch_tag/60) as fehlt_unentsch,
		sum(na.gleitzeit_rstBr_tag/60) as gleitzeit_rstBr,
		#9.---------
		sum(na.gleitzeit_gelnt_tag/60) as gleitzeit_rstnt,
		SUM(na.schule_gelstd_tag/60) as schule_gelst, #hier fehlt in den Rohdaten die Werte
      sum(na.kein_einsatz/60) as kein_einsatz,
      sum(na.`2106_ssp_gelnt_tag`/60) AS ssp_gelnt_2106,
      SUM(na.zaw_gelstd_tag/60) AS zaw_gelstd,
      #10.---------
		0 as update_stundensatz,
		null as update_persnr,
		na.lastinsertupdate,
		na.filedate,
		if (MONTH(na.filedate) = MONTH(na.datum),"aktueller Monat","Vormonat") AS info,
		na.info_2 AS eg_original,
		na.abteilung AS oe_person_original,
		zo.gueltig_von_eg,
		zo.gueltig_von_oe,
		zo.oe_bericht
		from tbl_import_nettoanwesenheit as na 
	   LEFT Join tbl_uebertrag_ma_aenderungen AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
	   LEFT JOIN tbl_wochentag AS wt ON wt.id = WEEKDAY(na.datum)
	   LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = na.persnr
	   #LEFT JOIN tbl_konfiguration_eg_bereich_zuordnung AS kon ON kon.entgeltgruppe = zo.entgeldgruppe AND kon.oe_person = zo.abteilung
		WHERE na.letzte_bg < DATE(NOW()) AND na.datum < DATE(NOW())
		GROUP BY key_datum,na.persnr,info2_neu,oe_person_neu,zo.entgeldgruppe,oe_person_neu
		ORDER BY na.persnr,datum
; 

END if;

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step16", 16);
#-------------------------------------------------------------------

INSERT ignore INTO tbl_uebertrag_durchsch_ausfall
		(		
		key_datum, Jahr_Monat, info, tag_2, netto_normalstunden, nacht_25_gelnt_monat, ssf_50_gelnt_monat, ssp_50_gelnt_monat,
		ft_100_la2108_gelnt_monat, ft_100_la2206_gelnt_monat, ft_140_la2231_gelnt_monat_125, ft_140_la2231_gelnt_monat_15, 
		ft_140_la2102_gelnt_monat, ft_140_la2230_gelnt_monat, gr_1_h_gelnt_monat, ab_4_h_tag_monat
		)
SELECT
mw.key_datum,
EXTRACT(YEAR_MONTH FROM mw.datum) AS Jahr_Monat,
"Festangestellte ohne ZAK" AS info,
if(tag.arbeitstag_2 = mw.key_datum,1,0) AS tag_2,
SUM(mw.o_schulung) AS "netto_normalstunden",
SUM(mw.nacht_25_gelnt_monat)+SUM(mw.n_25_gelnt_monat) AS "Stunde mit 25% Zuschlag- Nachtschicht", #ZAK + Festang Nachtstunden sind in getrennten Spalten im Zeus !!!
SUM(mw.ssf_50_gelnt_monat) AS "Stunden Wochenende S50%SfMonat",
SUM(mw.ssp_50_gelnt_monat) + SUM(mw.sonn_50_gelnt_monat) AS "Stunden Wochenende S50%SpMonat",
SUM(mw.ft_100_la2108_gelnt_monat) + SUM(mw.feiertag_100_gelnt_monat) AS "Stunden 100% Feiertagsarbeit SV pflichtig",
SUM(mw.ft_100_la2206_gelnt_monat) AS "Stunden 100% Feiertagsarbeit SV frei",
ROUND((SUM(mw.ft_140_la2231_gelnt_monat)*125/140),2) AS "Stunden 125% Feiertagsarbeit SV frei",
ROUND((SUM(mw.ft_140_la2231_gelnt_monat)*15/140),2) AS "Stunden 15% Feiertagsarbeit SV pflichtig",
SUM(mw.ft_140_la2102_gelnt_monat) AS "Stunden Arbeiten an gesetzlichen Wochenfeiertagen 140% SV pflichtig",
SUM(mw.ft_140_la2230_gelnt_monat) AS "Stunden Arbeiten an gesetzlichen Wochenfeiertagen 140% SV frei",
SUM(mw.gr_1_h_gelnt_monat) AS "Stunden Mehrarbeit 1-3 Std 25%",
SUM(mw.ab_4_h_tag_monat) AS "Stunden Mehrarbeit über 3 Std 50%"
FROM tbl_uebertrag_abr_schaeffler_monatswerte AS mw
LEFT JOIN (
				SELECT utable.datum AS arbeitstag_1, 
				MIN(dt.datum) AS arbeitstag_2,
				EXTRACT(YEAR_MONTH FROM dt.datum) AS Jahr_Monat
				FROM tbl_datum AS dt
				LEFT JOIN (
								SELECT
								MIN(dt.datum) AS datum,
								EXTRACT(YEAR_MONTH FROM dt.datum) Jahr_Monat
								FROM tbl_datum AS dt
								WHERE dt.arbeitstag = 1 And EXTRACT(YEAR_MONTH FROM dt.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 2 year))
								GROUP BY EXTRACT(YEAR_MONTH FROM dt.datum)
								) AS utable ON utable.Jahr_Monat = EXTRACT(YEAR_MONTH FROM dt.datum)
				WHERE dt.arbeitstag = 1 AND dt.datum > utable.datum
				GROUP BY EXTRACT(YEAR_MONTH FROM dt.datum)
				) AS tag ON tag.Jahr_Monat = EXTRACT(YEAR_MONTH FROM mw.key_datum)
WHERE mw.key_datum > "2026-01-01" AND mw.info = "Vormonat" AND mw.info_2 <> "ZAK"
#WHERE mw.key_datum = "2026-02-24" AND mw.info = "Vormonat" AND mw.info_2 <> "ZAK" AND persnr > 0
GROUP BY key_datum;

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Step17", 17);
#-------------------------------------------------------------------	
delete na from tbl_uebertrag_abr_schaeffler_wochenwerte as na WHERE
na.key_datum = DATE(NOW());

insert INTO tbl_uebertrag_abr_schaeffler_wochenwerte
		(
		key_datum,persnr,info_2,oe_person,schicht,team,name_vorname,zuordnung,arbeitgeber,taetigkeit,ma_kreis,wt,datum,
		KW,Jahr,erster_wt,letzter_wt,
		stunden,abrechnung_monat,o_schulung,zak_gel_nt_monat,nacht_25_gelnt_monat,sonn_50_gelnt_monat,
		feiertag_100_gelnt_monat,mehr_25_gelnt_monat,intern_gelnt_monat,n_25_gelnt_monat,ssf_50_gelnt_monat,
		ssp_50_gelnt_monat,gr_1_h_gelnt_monat,ab_4_h_tag_monat,ft_100_la2206_gelnt_monat,ft_100_la2108_gelnt_monat,
		ft_140_la2230_gelnt_monat,ft_140_la2231_gelnt_monat,ft_140_la2102_gelnt_monat,krank_lfz_gelstd_monat,krank_olfz_gelstd_monat,
		krank_au_liegt_vor_g_monat,krank_gemeldet_gelstd_monat,info_schul_gelstd_monat,schulung_gelstd_monat,urlaub_gelstd_monat,
		br_sitzung_gelstd_monat,fehlt_entsch_g_monat,sonderurlaub_gelstd_monat,arbeitsunfall_gelstd_monat,kind_krank_gelstd_monat,
		t_zug_geltag_monat,kur_lfz_gelstd_monat,dg_gelst_monat,fehlt_unentsch_monat,gleitzeit_rstBr_monat,
		gleitzeit_rstnt_monat,schule_gelst_monat,kein_einsatz,`2106_ssp_gelnt_monat`,zaw_gelstd_monat,
		update_stundensatz,update_persnr,filedate,info,eg_original,oe_person_original,
		gueltig_von_eg,gueltig_von_oe,oe_bericht
		)
		Select 
		DATE(NOW()) AS key_datum, 
		na.persnr,
		ifnull(zo.entgeldgruppe, na.info_2) AS info2_neu,
      IFLeerOrNull(zo.Abteilung_Uebersetzt,na.abteilung)  AS oe_person_neu,  
		na.schicht,pa.team,na.name_vorname,
      IFLeerOrNull(zo.zuordnung,"") AS stellung,  
		na.arbeitgeber, na.taetigkeit,	#na.`14_taetigkeit`
		na.ma_kreis,wt.kurz,na.datum AS datum,
		
		#***************************************************************************************
		WEEKofyear(na.datum) AS kw,
		#DATE_FORMAT(na.datum, '%v') AS kw,
		DATE_FORMAT(na.datum, '%x') AS jahr,
		DATE_SUB(na.datum, INTERVAL WEEKDAY(na.datum) DAY) AS erster_wt,
  		DATE_ADD(na.datum, INTERVAL (6 - WEEKDAY(na.datum)) DAY) AS letzter_wt,
		#***************************************************************************************
		
		#2.---------
		
		SUM(na.stunden) AS stunden,
		SUM((na.stunden + na.dg_gelst_tag + na.schulung_gelstd_tag + na.br_sitzung_gelstd_tag)) AS abrechnung_monat,
      SUM((na.stunden + na.dg_gelst_tag + na.br_sitzung_gelstd_tag + na.schule_gelstd_tag)) AS o_schulung,
		SUM(if(na.arbeitgeber = "",0,na.stunden)) as zak_gel_nt,
		sum(na.nacht_zuschlag) AS nacht_25_gelnt,  
		sum(na.sonntag_zuschlag) AS sonn_50_gelnt,
		#3.---------
		sum(na.feiertag_zuschlag) AS feiertag_100_gelnt,
		sum(na.mehr_zuschlag) AS mehr_25_gelnt,
		SUM(if(na.arbeitgeber = "",na.stunden,0)) as intern_gelnt,
		sum(na.n_25_gelnt_tag) AS n_25_gelnt,
		sum(na.ssf_gelnt_tag) as ssf_50_gelnt,
		#4.---------
		sum(na.ssp_gelnt_tag) as ssp_50_gelnt,
		sum(na.gr_1_h_gelnt_tag) as gr_1_h_gelnt,
		sum(na.ab_4_h_tag_tag) as ab_4_h_tag,
		sum(na.ft_100_la2206_gelnt_tag) as ft_100_la2206_gelnt,
		sum(na.ft_100_la2108_gelnt_tag) as ft_100_la2108_gelnt,
		#5.---------
		sum(na.ft_140_la2230_gelnt_tag) as ft_140_la2230_gelnt,
		sum(na.ft_140_la2231_gelnt_tag) as ft_140_la2231_gelnt,
		sum(na.ft_140_la2102_gelnt_tag) as ft_140_la2102_gelnt,
		sum(na.krank_lfz_gelstd_tag) as krank_lfz_gelstd,
		sum(na.krank_olfz_gelstd_tag) as krank_olfz_gelstd,
		#6.---------
		sum(na.krank_au_liegt_vor_g_tag) as krank_au_liegt_vor_g,
		sum(na.krank_gemeldet_gelstd_tag) as krank_gemeldet_gelstd,
		sum(na.info_schul_gelstd_tag) as info_schul_gelstd,
		sum(na.schulung_gelstd_tag) as schulung_gelstd,
		sum(na.urlaub_gelstd_tag) as urlaub_gelstd,
		#7.---------
		sum(na.br_sitzung_gelstd_tag) as br_sitzung_gelstd,
		sum(na.fehlt_entsch_g_tag) as fehlt_entsch_g,
		sum(na.sonderurlaub_gelstd_tag) as sonderurlaub_gelstd,
		sum(na.arbeitsunfall_gelstd_tag) as arbeitsunfall_gelstd,
		sum(na.kind_krank_gelstd_tag) as kind_krank_gelstd,
		#8.---------
		sum(na.t_zug_geltag_tag) as t_zug_geltag,
		sum(na.kur_lfz_gelstd_tag) as kur_lfz_gelstd,
		sum(na.dg_gelst_tag) as dg_gelst,
		sum(na.fehlt_unentsch_tag) as fehlt_unentsch,
		sum(na.gleitzeit_rstBr_tag) as gleitzeit_rstBr,
		#9.---------
		sum(na.gleitzeit_gelnt_tag) as gleitzeit_rstnt,
		sum(na.schulung_gelstd_tag) as schulung_gelstd,
      sum(na.kein_einsatz) as kein_einsatz,
      sum(na.`2106_ssp_gelnt_tag`) AS ssp_gelnt_2106,
      SUM(na.zaw_gelstd_tag) AS zaw_gelstd,
      #10.---------
		0 as update_stundensatz,
		null as update_persnr,
		na.filedate,
		if (MONTH(na.filedate) = MONTH(na.datum),"aktueller Monat","Vormonat") AS info,
		na.info_2 AS eg_original,
		na.abteilung AS oe_person_original,
		zo.gueltig_von_eg,
		zo.gueltig_von_oe,
		zo.oe_bericht
		from tbl_uebertrag_nettoanwesenheit as na 
	   LEFT Join tbl_uebertrag_ma_aenderungen AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
	   LEFT JOIN tbl_wochentag AS wt ON wt.id = WEEKDAY(na.datum)
	   LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = na.persnr
	   #LEFT JOIN tbl_konfiguration_eg_bereich_zuordnung AS kon ON kon.entgeltgruppe = zo.entgeldgruppe AND kon.oe_person = zo.abteilung
		#WHERE na.letzte_bg < DATE(NOW()) AND na.datum < DATE(NOW())
		Where EXTRACT(YEAR_MONTH FROM na.datum) >= EXTRACT(YEAR_MONTH FROM (NOW() - INTERVAL 1 MONTH))
		#AND na.persnr = 36101347
		GROUP BY WEEKofyear(na.datum), na.persnr,info2_neu,oe_person_neu,zo.entgeldgruppe
		ORDER BY na.persnr,datum;

		
call schreibe_log("proc_34_uebertrag_nettoanwesenheit", "Ende", 99);
END//
