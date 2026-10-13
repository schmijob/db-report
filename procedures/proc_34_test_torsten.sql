-- Managed by db-workbench; source of truth: db-report/procedures/proc_34_test_torsten.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_34_test_torsten`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_34_test_torsten`()
SQL SECURITY DEFINER BEGIN
Call db_de_tal002_report.proc_01_check_import;

SELECT * 
#DELETE mw
FROM tbl_uebertrag_abr_schaeffler_monatswerte AS mw
WHERE mw.key_datum = "2026-03-05"
AND mw.oe_bericht IS NULL 
AND mw.stunden = 0;

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
		sum(na.ft_140_la2102_gelnt_tag/60) as ft_140_la2102_gelnt,
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
		from tbl_uebertrag_nettoanw_aend_management as na 
	   LEFT Join tbl_uebertrag_ma_aenderungen AS zo ON zo.persnr = na.persnr AND zo.datum = na.datum
	   LEFT JOIN tbl_wochentag AS wt ON wt.id = WEEKDAY(na.datum)
	   LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = na.persnr
		WHERE date(na.filedate) = "2026-03-05"#################################################################
		AND  na.import_version = "Aktueller monat"
		and na.letzte_bg < date(na.filedate) AND na.datum < date(na.filedate)
		GROUP BY key_datum,na.persnr,info2_neu,oe_person_neu,zo.entgeldgruppe,oe_person_neu
		ORDER BY na.persnr,datum;
END//
