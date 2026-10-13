-- Managed by db-workbench; source of truth: db-report/procedures/proc_34_uebertrag_nettoanwesenheit_manuell.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_34_uebertrag_nettoanwesenheit_manuell`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_34_uebertrag_nettoanwesenheit_manuell`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_34_uebertrag_nettoanwesenheit_manuell", "Start", 0);

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
		#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit_manuell", "Step1", 1);
#-------------------------------------------------------------------
#SELECT na.persnr,na.datum,zo.*,
#na.filedate
#FROM 

#update
#tbl_uebertrag_nettoanw_aend_management AS na
#LEFT JOIN view_mitarbeiter_zuordnung_uet AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
#SET na.taetigkeit_korrigiert = zo.taetigkeit,
#    na.taetigkeit14_korrigiert = zo.taetigkeit14,
#    na.abteilung_korrigiert = zo.abteilung,
#    na.entgeldgruppe_korrigiert = zo.entgeldgruppe,
#    na.abwesenheitsgrund_korrigiert = zo.abwesenheitsgrund,
#    na.oe_der_person_korrigiert = zo.oe_der_person,
#    na.import_version = if(month(na.datum) = month(na.filedate),"aktueller Monat","Vormonat")
#WHERE DATE(na.filedate) = DATE(zo.filedate); #DATE(NOW()); #AND na.persnr = 92310;

#-------------------------------------------------------------------
call schreibe_log("proc_34_uebertrag_nettoanwesenheit_manuell", "Step2", 2);
#-------------------------------------------------------------------
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
		
call schreibe_log("proc_34_uebertrag_nettoanwesenheit_manuell", "Ende", 99);
END//
