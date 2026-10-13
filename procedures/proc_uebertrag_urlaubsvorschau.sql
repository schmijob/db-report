-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_urlaubsvorschau.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_urlaubsvorschau`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_urlaubsvorschau`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_uebertrag_urlaubsvorschau", "Start", 0);
delete from tbl_uebertrag_urlaubsvorschau;

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-01") as Datum, uv.persnr, uv.t1,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t1 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-02") as Datum, uv.persnr, uv.t2,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t2 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-03") as Datum, uv.persnr, uv.t3,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t3 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-04") as Datum, uv.persnr, uv.t4,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t4 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-05") as Datum, uv.persnr, uv.t5,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t5 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-06") as Datum, uv.persnr, uv.t6,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t6 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-07") as Datum, uv.persnr, uv.t7,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t7 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-08") as Datum, uv.persnr, uv.t8,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t8 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-09") as Datum, uv.persnr, uv.t9,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t9 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-10") as Datum, uv.persnr, uv.t10,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t10 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-11") as Datum, uv.persnr, uv.t11,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t11 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-12") as Datum, uv.persnr, uv.t12,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t12 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-13") as Datum, uv.persnr, uv.t13,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t13 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-14") as Datum, uv.persnr, uv.t14,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t14 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-15") as Datum, uv.persnr, uv.t15,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t15 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-16") as Datum, uv.persnr, uv.t16,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t16 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-17") as Datum, uv.persnr, uv.t17,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t17 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-18") as Datum, uv.persnr, uv.t18,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t18 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-19") as Datum, uv.persnr, uv.t19,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t19 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-20") as Datum, uv.persnr, uv.t20,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t20 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-21") as Datum, uv.persnr, uv.t21,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t21 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-22") as Datum, uv.persnr, uv.t22,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t22 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-23") as Datum, uv.persnr, uv.t23,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t23 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-24") as Datum, uv.persnr, uv.t24,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t24 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-25") as Datum, uv.persnr, uv.t25,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t25 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-26") as Datum, uv.persnr, uv.t26,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t26 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-27") as Datum, uv.persnr, uv.t27,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) where uv.t27 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") as Datum, uv.persnr, uv.t28,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)  
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") AS DATE)
where uv.t28 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") as Datum, uv.persnr, uv.t29,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") AS DATE)
where uv.t29 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") as Datum, uv.persnr, uv.t30,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") AS DATE)
where uv.t30 <> "";

replace into tbl_uebertrag_urlaubsvorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") as Datum, uv.persnr, uv.t31,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") AS DATE)
where uv.t31 <> "";

delete from tbl_uebertrag_urlaubsvorschau WHERE datum < DATE(NOW());

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
delete from tbl_uebertrag_ma_vorschau;

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-01") as Datum, uv.persnr, uv.t1,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-01") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-01") AS DATE) <= pa.ende_besch;  #uv.t1 <> "";
  
replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-02") as Datum, uv.persnr, uv.t2,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-02") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-02") AS DATE) <= pa.ende_besch;  #uv.t2 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-03") as Datum, uv.persnr, uv.t3,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-03") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-03") AS DATE) <= pa.ende_besch;  #uv.t3 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-04") as Datum, uv.persnr, uv.t4,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3) 
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-04") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-04") AS DATE) <= pa.ende_besch;  #uv.t4 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-05") as Datum, uv.persnr, uv.t5,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-05") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-05") AS DATE) <= pa.ende_besch;  # where uv.t5 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-06") as Datum, uv.persnr, uv.t6,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-06") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-06") AS DATE) <= pa.ende_besch;  # where uv.t6 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-07") as Datum, uv.persnr, uv.t7,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-07") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-07") AS DATE) <= pa.ende_besch;  # where uv.t7 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-08") as Datum, uv.persnr, uv.t8,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-08") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-08") AS DATE) <= pa.ende_besch;  # where uv.t8 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-09") as Datum, uv.persnr, uv.t9,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-09") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-09") AS DATE) <= pa.ende_besch;  # where uv.t9 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-10") as Datum, uv.persnr, uv.t10,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-10") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-10") AS DATE) <= pa.ende_besch;  # where uv.t10 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-11") as Datum, uv.persnr, uv.t11,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-11") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-11") AS DATE) <= pa.ende_besch;  # where uv.t11 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-12") as Datum, uv.persnr, uv.t12,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-12") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-12") AS DATE) <= pa.ende_besch;  # where uv.t12 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-13") as Datum, uv.persnr, uv.t13,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-13") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-13") AS DATE) <= pa.ende_besch;  # where uv.t13 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-14") as Datum, uv.persnr, uv.t14,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-14") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-14") AS DATE) <= pa.ende_besch;  # where uv.t14 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-15") as Datum, uv.persnr, uv.t15,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-15") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-15") AS DATE) <= pa.ende_besch;  # where uv.t15 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-16") as Datum, uv.persnr, uv.t16,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-16") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-16") AS DATE) <= pa.ende_besch;  # where uv.t16 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-17") as Datum, uv.persnr, uv.t17,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-17") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-17") AS DATE) <= pa.ende_besch;  # where uv.t17 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-18") as Datum, uv.persnr, uv.t18,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-18") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-18") AS DATE) <= pa.ende_besch;  # where uv.t18 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-19") as Datum, uv.persnr, uv.t19,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-19") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-19") AS DATE) <= pa.ende_besch;  # where uv.t19 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-20") as Datum, uv.persnr, uv.t20,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-20") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-20") AS DATE) <= pa.ende_besch;  # where uv.t20 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-21") as Datum, uv.persnr, uv.t21,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-21") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-21") AS DATE) <= pa.ende_besch;  # where uv.t21 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-22") as Datum, uv.persnr, uv.t22,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-22") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-22") AS DATE) <= pa.ende_besch;  # where uv.t22 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-23") as Datum, uv.persnr, uv.t23,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-23") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-23") AS DATE) <= pa.ende_besch;  # where uv.t23 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-24") as Datum, uv.persnr, uv.t24,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-24") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-24") AS DATE) <= pa.ende_besch;  # where uv.t24 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-25") as Datum, uv.persnr, uv.t25,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-25") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-25") AS DATE) <= pa.ende_besch;  # where uv.t25 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-26") as Datum, uv.persnr, uv.t26,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-26") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-26") AS DATE) <= pa.ende_besch;  # where uv.t26 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-27") as Datum, uv.persnr, uv.t27,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-27") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-27") AS DATE) <= pa.ende_besch;  # where uv.t27 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") as Datum, uv.persnr, uv.t28,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") AS DATE)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-28") AS DATE) <= pa.ende_besch;  # where uv.t28 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") as Datum, uv.persnr, uv.t29,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") AS DATE)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-29") AS DATE) <= pa.ende_besch;  # where uv.t29 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") as Datum, uv.persnr, uv.t30,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") AS DATE)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-30") AS DATE) <= pa.ende_besch;  # where uv.t30 <> "";

replace into tbl_uebertrag_ma_vorschau
select concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") as Datum, uv.persnr, uv.t31,pa.beginn_besch,pa.ende_besch,uv.lastinsertupdate,uv.filedate
from tbl_import_urlaubsvorschau as uv 
LEFT JOIN tbl_import_personalakte AS pa ON pa.pers_nr = uv.PersNr
left join tbl_monate as mon on mon.kurz = left(uv.monat,3) 					
left join tbl_monate as mon2 on mon2.kurz_eng = left(uv.monat,3)
INNER JOIN tbl_datum AS dt ON dt.datum = cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") AS DATE)
WHERE cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") AS DATE) >= pa.beginn_besch 
  AND cast(concat("20",RIGHT(uv.monat,2),"-",ifnull(mon.zahl,mon2.zahl),"-31") AS DATE) <= pa.ende_besch;  # where uv.t31 <> "";

call schreibe_log("proc_uebertrag_urlaubsvorschau", "Ende", 99);

END//
