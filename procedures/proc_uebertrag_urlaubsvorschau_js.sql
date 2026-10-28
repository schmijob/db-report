-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_urlaubsvorschau_js.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_urlaubsvorschau_js`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_urlaubsvorschau_js`()
SQL SECURITY DEFINER BEGIN
CALL schreibe_log("proc_uebertrag_urlaubsvorschau_js", "Start", 0);

## neuer Personalkalender
SELECT MIN(DATE_FORMAT(monat, '%Y-%m-01')) INTO @mindate FROM tbl_import_personalkalender;
SELECT last_day(MAX(DATE_FORMAT(monat, '%Y-%m-01'))) INTO @maxdate FROM tbl_import_personalkalender;

DELETE k FROM tbl_ueb_fz_personalkalender k
WHERE k.datum BETWEEN @mindate 
                  AND @maxdate
;

INSERT INTO tbl_ueb_fz_personalkalender (persnr, datum, fz, tp, filedate)

WITH RECURSIVE seq AS (
    SELECT 1 AS d
    UNION ALL
    SELECT d + 1
    FROM seq
    WHERE d < 31
)
, unpivot AS (
SELECT k.persnr
     , CAST(CONCAT(LEFT(k.monat,8), LPAD(seq.d,2,'0')) AS DATE) AS datum
     , k.typ
     , ELT(seq.d
          , k.t1 , k.t2 , k.t3 , k.t4 , k.t5 , k.t6 , k.t7 , k.t8
          , k.t9 , k.t10, k.t11, k.t12, k.t13, k.t14, k.t15, k.t16
          , k.t17, k.t18, k.t19, k.t20, k.t21, k.t22, k.t23, k.t24
          , k.t25, k.t26, k.t27, k.t28, k.t29, k.t30, k.t31
       ) AS v
     , k.filedate
    FROM tbl_import_personalkalender k
    JOIN seq
   WHERE seq.d <= DAY(LAST_DAY(k.monat))
)
SELECT persnr
     , datum
     , MAX(CASE WHEN typ='Fehlzeit'  THEN v END) AS fz
     , MAX(CASE WHEN typ='Tagesplan' THEN v END) AS tp
     , filedate
  FROM unpivot
 WHERE v <> ''
 GROUP BY persnr, datum
 ;
 
 	DELETE FROM tbl_uebertrag_urlaubsvorschau;

   INSERT INTO tbl_uebertrag_urlaubsvorschau(datum, personalnummer,abwesenheitsgrund,lastinsertupdate,filedate)
	SELECT
	    datum,
	    persnr,
	    coalesce(fz, tp),
	    NOW(),
	    filedate
	FROM tbl_ueb_fz_personalkalender
  WHERE datum >= CURDATE();
	
	SET @rowcount = ROW_COUNT();

	call schreibe_log("proc_uebertrag_personalkalender_js", "Ende", ROW_COUNT());

	INSERT INTO tbl_ueb_fz_join (persnr, datum, pk_fz, pk_tp, pk_filedate, last_insert_update)
	SELECT p.persnr
	     , p.datum
	     , p.fz
	     , p.tp
	     , p.filedate
	     , NOW() AS last_insert_update
	  FROM tbl_ueb_fz_personalkalender p
	 WHERE p.datum BETWEEN @mindate AND @maxdate
	
	ON DUPLICATE KEY UPDATE
	      last_insert_update = IF(    NOT (tbl_ueb_fz_join.pk_fz <=> VALUES(pk_fz))
										 OR NOT (tbl_ueb_fz_join.pk_tp <=> VALUES(pk_tp))
									   , VALUES(last_insert_update)
									   , tbl_ueb_fz_join.last_insert_update
									   )
	    , pk_fz       = VALUES(pk_fz)
	    , pk_tp       = VALUES(pk_tp)
	    , pk_filedate = VALUES(pk_filedate)
	;

	UPDATE tbl_ueb_fz_join j
	  LEFT JOIN tbl_ueb_fz_personalkalender p ON p.persnr = j.persnr AND p.datum  = j.datum
	   SET j.pk_fz       = 'XXX'
	     , j.pk_tp       = NULL
	     , j.pk_filedate = (SELECT filedate FROM tbl_import_personalkalender LIMIT 1)
	     , j.last_insert_update = NOW()
	
	WHERE j.datum BETWEEN @mindate AND @maxdate
	  AND p.persnr IS NULL
	  AND j.pk_filedate IS NOT NULL
	  AND (NOT (j.pk_fz <=> 'XXX') OR j.pk_tp IS NOT NULL)
	;


END//
