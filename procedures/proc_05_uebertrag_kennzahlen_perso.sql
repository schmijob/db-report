-- Managed by db-workbench; source of truth: db-report/procedures/proc_05_uebertrag_kennzahlen_perso.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_05_uebertrag_kennzahlen_perso`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_05_uebertrag_kennzahlen_perso`()
SQL SECURITY DEFINER BEGIN
DECLARE var_anzahl INT;
SELECT 5 into var_anzahl;

call proc_01_insert_tbl_datum;

#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Start", 0);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#Anzahl_aktive_Mitarbeiter  ok
#urlaub_bezahlt	ok
#krank_bezahlt		ok
#krank_unbezahlt	ok
#sonst_abwesend
#brutto_MA_ZAK
#ZAK_abwesend
#krank_ohne_lfz
#Anzahl_Mitarbeiter_Stunden
#MA_h_pro_Tag
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
(SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
count(distinct pa.pers_nr ) as wert,
"MA" AS Einheit,
pa.taetigkeit as funktionen,
pa.oe_der_person AS bereiche,
"Anzahl_aktive_Mitarbeiter" as kennzahl, #######################################################
if(pa.info = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_personalakte AS pa
#LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = pa.pers_nr AND fz.datum = (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) 
where pa.ende_besch >= (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) and pa.oe_der_person <> "Externer Support"

Group by datums,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step1", 1);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pa.taetigkeit as funktionen,
pa.oe_der_person AS bereiche,
"urlaub_bezahlt" as kennzahl, #######################################################
if(pa.info = "ZAK","ZAK","DPWorld") as filtern,
'' as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner JOIN db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pa on pa.pers_nr = fz.personalnummer
Where ag.anwesenheit = "URL" and pa.info <> "ZAK" and pa.oe_der_person <> "Externer Support" #And ks.bezeichnung_kurz <> "Verwaltung"
#AND ag.kuerzel <> "UU"
Group by datum,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step2", 2);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"krank_bezahlt" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
Where ag.anwesenheit = "Lfz" and pak.info <> "ZAK" and pak.oe_der_person <> "Externer Support" 
Group by datum,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step3", 3);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"krank_unbezahlt" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
Where ag.anwesenheit = "oLfz" and  pak.info <> "ZAK" and pak.oe_der_person <> "Externer Support" 
Group by datum,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step4", 4);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"sonst_abwesend" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
'' as gruppe,
now() as zeitstempel#,ag.abwgruppe,fz.abwesenheitsgrund
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
WHERE ag.anwesenheit = "sonst." and pak.info <> "ZAK" and pak.oe_der_person <> "Externer Support" 
Group by datum,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step5", 5);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
/*replace into tbl_uebertrag_kennzahlen_personal
#Alle gewerblichen MA Imperial ohne Fix und Overhead    = fehlede + Anwesende:
SELECT datum,count(distinct personalnummer),Einheit,funktionen,bereiche,kennzahl,filtern,gruppe,now() as zeitstempel FROM(
SELECT fz.datum,personalnummer,"MA" AS Einheit,
pak.taetigkeit as funktionen,pak.oe_der_person AS bereiche,
"brutto_MA_gewerblich" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,'' as gruppe
FROM tbl_import_fehlzeiten as fz
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= 1
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
#WHERE vgb.filter_verwaltung = 0
union all
Select
fz.datum,fz.pers_nr,"MA" AS Einheit,
pak.taetigkeit as funktionen,pak.oe_der_person AS bereiche,
"brutto_MA_gewerblich" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,'' as gruppe
FROM tbl_import_buchungen_mitarbeiter as fz
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= 1
left join tbl_import_personalakte as pak on pak.pers_nr = fz.pers_nr
#WHERE vgb.filter_verwaltung = 0
) AS temp
Where filtern = "DPWorld"
Group by datum,funktionen,bereiche,filtern,gruppe;*/
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
/*call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step6", 6);
replace into tbl_uebertrag_kennzahlen_personal
#Alle Zeitarbeiter  = fehlede + Anwesende:
SELECT datum,count(distinct personalnummer),Einheit,funktionen,bereiche,kennzahl,filtern,gruppe,now() as zeitstempel FROM(
Select
fz.datum,personalnummer,"MA" AS Einheit,
pak.taetigkeit as funktionen,pak.oe_der_person AS bereiche,
"brutto_MA_ZAK" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,'' as gruppe
FROM tbl_import_fehlzeiten as fz
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= 1
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
union all
Select
fz.datum,fz.pers_nr as personalnummer,"MA" AS Einheit,
pak.taetigkeit as funktionen,pak.oe_der_person AS bereiche,
"brutto_MA_ZAK" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,'' as gruppe
FROM tbl_import_buchungen_mitarbeiter as fz
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= 1
left join tbl_import_personalakte as pak on pak.pers_nr = fz.pers_nr
) AS temp
Where filtern <> "DPWorld"
Group by datum,funktionen,bereiche,filtern,gruppe;*/
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step7", 7);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"ZAK_abwesend" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
'' as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= 1
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
WHERE  pak.info = "ZAK" 
Group by datum,funktionen,filtern,bereiche,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step8", 8);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
count(fz.personalnummer) as wert,
"MA" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"krank_ohne_lfz" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
Where ag.anwesenheit = "oLfz" and  pak.info <> "ZAK"
Group by datum,funktionen,bereiche,filtern,gruppe;
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step9", 9);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
replace into tbl_uebertrag_kennzahlen_personal
Select
(SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
sum(pa.urlaubsanspruch_alt) as wert,

"Tage" AS Einheit,
pa.taetigkeit as funktionen,
pa.abteilung AS bereiche,
"Resturlaub_Vorjahr" as kennzahl, #######################################################
if(pa.info_2 = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_personalstamm AS pa
where pa.info_2 <> "ZAK" and pa.abteilung <> "Externer Support"
#LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = pa.pers_nr AND fz.datum = (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) 
Group by datums,funktionen,bereiche,filtern,gruppe;
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step10", 10);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
replace into tbl_uebertrag_kennzahlen_personal
Select
(SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
sum(pa.urlaubsguthaben) as wert,
"Tage" AS Einheit,
pa.taetigkeit as funktionen,
pa.abteilung AS bereiche,
"Resturlaub_aktuell" as kennzahl, #######################################################
if(pa.info_2 = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_personalstamm AS pa
where pa.info_2 <> "ZAK" and pa.abteilung <> "Externer Support"
#LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = pa.pers_nr AND fz.datum = (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) 
Group by datums,funktionen,bereiche,filtern,gruppe;
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step11", 11);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
replace into tbl_uebertrag_kennzahlen_personal
Select
fz.datum,
sum(lohn.std_entgelt_mit_sv) as wert,
"€" AS Einheit,
pak.taetigkeit as funktionen,
pak.oe_der_person AS bereiche,
"lohnausfallkosten_operativ" as kennzahl, #######################################################
if(pak.info = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_fehlzeiten as fz
left join tbl_abwesenheitsgrund as ag on ag.kuerzel = fz.abwesenheitsgrund
inner join db_report_lza_apollo.view_arbeitstage_mit_id_bis_heute as td on td.datum = fz.datum and td.Nr <= var_anzahl
left join tbl_import_personalakte as pak on pak.pers_nr = fz.personalnummer
left join tbl_import_personalstamm as pak2 on pak2.persnr = fz.personalnummer
LEFT JOIN tbl_konfiguration_lohnkosten as lohn on lohn.personalnummer = fz.personalnummer
Where ag.anwesenheit = "Lfz" and pak.info <> "ZAK" 
Group by datum,funktionen,bereiche,filtern,gruppe;
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step12", 12);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
replace into tbl_uebertrag_kennzahlen_personal
Select
(SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
sum(if(pa.saldo < 0,pa.saldo,0))/60 as wert,
"h" AS Einheit,
pa.taetigkeit as funktionen,
pa.abteilung AS bereiche,
"Stundenkonto_minus" as kennzahl, #######################################################
if(pa.info_2 = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_personalstamm AS pa
where pa.info_2 <> "ZAK" and pa.abteilung <> "Externer Support"
#LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = pa.pers_nr AND fz.datum = (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) 
Group by datums;#,funktionen,bereiche,filtern,gruppe;
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step13", 13);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
replace into tbl_uebertrag_kennzahlen_personal
Select
(SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
sum(if(pa.saldo > 0,pa.saldo,0))/60 as wert,
"h" AS Einheit,
pa.taetigkeit as funktionen,
pa.abteilung AS bereiche,
"Stundenkonto_plus" as kennzahl, #######################################################
if(pa.info_2 = "ZAK","ZAK","DPWorld") as filtern,
"" as gruppe,
now() as zeitstempel
FROM tbl_import_personalstamm AS pa
where pa.info_2 <> "ZAK" and pa.abteilung <> "Externer Support"
#LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = pa.pers_nr AND fz.datum = (SELECT MAX(datum) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) 
Group by datums;#,funktionen,bereiche,filtern,gruppe;
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step14", 14);
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
/*replace into tbl_uebertrag_kennzahlen_personal
SELECT datums,round(sum(stunden)),Einheit,funktionen,bereiche,kennzahl,filtern,gruppe,zeitstempel FROM (
SELECT 
fz.pers_nr,
date(fz.datum) as datums,
#round(sum(
if(round(time_to_sec(Timediff( MAX(fz.zeit),MIN(fz.zeit)))/60/60,2) < 12,
	round(time_to_sec(Timediff( MAX(fz.zeit),MIN(fz.zeit)))/60/60,2),
	ROUND((time_to_sec(Timediff( MIN(fz.zeit),TIME("00:00:0000")))+ time_to_sec(Timediff(TIME("24:00:0000"), MAX(fz.zeit))))/60/60,2))
#),2) as wert,
AS stunden,
"h" AS Einheit,
ifnull(per.taetigkeit,"") as funktionen,
ifnull(per.oe_der_person,"") as bereiche,
"Anzahl_Mitarbeiter_Stunden" as kennzahl, #######################################################
if(per.info = "ZAK","ZAK","DPWorld") as filtern,
'' as gruppe,
now() as zeitstempel
FROM tbl_import_buchungen_mitarbeiter as fz 
left JOIN tbl_import_personalakte AS per on per.pers_nr = fz.pers_nr
WHERE datum > 0
Group by datums,pers_nr,funktionen,bereiche,filtern
)AS Utable
Group by datums,funktionen,bereiche,filtern;*/
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step15", 15);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
/*replace into tbl_uebertrag_kennzahlen_personal
SELECT datums,round(sum(stunden)) AS stunden,Einheit,funktionen,bereiche,kennzahl,filtern,gruppe,zeitstempel FROM (
SELECT
per.pers_nr,
(SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where datum < DATE(NOW())) as datums,
fz.datum,
if(round(time_to_sec(Timediff( MAX(ks.zeit),MIN(ks.zeit)))/60/60,2) < 12,
	round(time_to_sec(Timediff( MAX(ks.zeit),MIN(ks.zeit)))/60/60,2),
	ROUND((time_to_sec(Timediff( MIN(ks.zeit),TIME("00:00:0000")))+ time_to_sec(Timediff(TIME("24:00:0000"), MAX(ks.zeit))))/60/60,2))
AS stunden,
"h" AS Einheit,
ifnull(per.taetigkeit,"") as funktionen,
ifnull(per.oe_der_person,"") as bereiche,
"MA_h_pro_Tag" as kennzahl, #######################################################
if(per.info = "ZAK","ZAK","DPWorld") as filtern,
'' as gruppe,
now() as zeitstempel
FROM tbl_import_personalakte AS per
LEFT JOIN tbl_import_fehlzeiten AS fz ON fz.personalnummer = per.pers_nr AND date(fz.datum) = (SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where date(datum) < DATE(NOW())) 
LEFT JOIN tbl_import_buchungen_mitarbeiter AS ks on ks.pers_nr = per.pers_nr AND date(ks.datum) = (SELECT date(MAX(datum)) FROM tbl_import_buchungen_mitarbeiter where date(datum) < DATE(NOW()))
WHERE not(ks.pers_nr IS NULL) 
Group by datum,pers_nr,funktionen,bereiche,filtern,gruppe
)AS Utable
WHERE stunden >  0 
Group by datums,funktionen,bereiche,filtern;*/
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Step16", 16);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>


#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
call schreibe_log("proc_05_uebertrag_kennzahlen_perso", "Ende", 99);
#>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
END//
