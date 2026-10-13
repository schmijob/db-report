-- Managed by db-workbench; source of truth: db-report/procedures/HeidiSQL_temproutine_2.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `HeidiSQL_temproutine_2`//
CREATE DEFINER=CURRENT_USER PROCEDURE `HeidiSQL_temproutine_2`()
SQL SECURITY DEFINER BEGIN

############################################################
## FANF PDF
## tbl_import_fanf_pdf -> tbl_uebertrag_fanf_pdf
############################################################
-- filedate trennen, falls 
UPDATE tbl_import_fanf_pdf t
JOIN (
      SELECT filename
		     , filedate
			  , filedate + INTERVAL (ROW_NUMBER() OVER (partition by filedate ORDER BY filename) - 1) SECOND AS adjusted_filedate
        FROM tbl_import_fanf_pdf
       GROUP BY 1, 2
) f ON t.filename = f.filename AND t.filedate = f.filedate
SET t.filedate = f.adjusted_filedate
;
-- load start
INSERT IGNORE INTO tbl_check_etl_log (quelltabelle, zieltabelle, filedate, filename, rowcount, load_status)
SELECT 'tbl_import_fanf_pdf' AS quelltabelle
     , 'tbl_uebertrag_fanf_pdf' AS zieltabelle
     , q.filedate
     , q.filename
     , COUNT(*) AS rowcount
     , 'loading' AS load_status
     FROM tbl_import_fanf_pdf q
     GROUP BY q.filedate, q.filename
;

-- Übertrag fanf pdf
REPLACE INTO tbl_uebertrag_fanf_pdf (filename, filedate, start_date, end_date, schicht, funktion, beauftragung)
-- start date, end date, schicht ermitteln
WITH vw_fanf_metadata AS (
	SELECT filename
	     , MAX(
            CASE WHEN pdf_line LIKE 'Forcast-Start%'
                 THEN REPLACE(pdf_line, 'Forcast-Start', '')
            END
        ) AS start_date
		  , MAX(
            CASE WHEN pdf_line LIKE 'Forecast-Ende%'
                 THEN REPLACE(pdf_line, 'Forecast-Ende', '')
            END
        ) AS end_date,
        MAX(
            CASE WHEN pdf_line IN ('SchichtNachtschicht','SchichtFrühschicht','SchichtSpätschicht')
                 THEN REPLACE(pdf_line, 'Schicht', '')
            END
        ) AS schicht
    FROM tbl_import_fanf_pdf
    GROUP BY filedate, filename
),
-- Daten formatieren
final AS (
	SELECT r.filename
	     , r.filedate
		  , CAST(m.start_date as DATE) AS start_date
		  , CAST(m.end_date as DATE) AS end_date
		  , m.schicht
		  , map.clean_label AS funktion
		  , CAST(
	        NULLIF(
	            REGEXP_SUBSTR(
	                TRIM(
	                    REPLACE(r.pdf_line, map.raw_label, '')
	                ),
	                '[0-9]+'
	            ),
	            ''
	        ) AS UNSIGNED
	       ) AS beauftragung
	
	FROM tbl_import_fanf_pdf r
	JOIN tbl_stamm_fanf_pdf_translate map ON r.pdf_line LIKE CONCAT(map.raw_label, '%')
	LEFT JOIN vw_fanf_metadata m ON m.filename = r.filename
)

SELECT * FROM final
 WHERE beauftragung IS NOT NULL
;
-- importtabelle leeren
/* DELETE q FROM tbl_import_fanf_pdf q
  JOIN tbl_check_etl_log e ON q.filedate = e.filedate AND e.load_status = 'loading' AND quelltabelle = 'tbl_import_fanf_pdf' AND zieltabelle = 'tbl_uebertrag_fanf_pdf'
; */
-- load ende
UPDATE tbl_check_etl_log l
JOIN (
    SELECT z.filedate
         , z.filename
	      , MIN(z.start_date) AS mindate
			, MAX(z.end_date) AS maxdate
    FROM tbl_uebertrag_fanf_pdf z
    JOIN tbl_check_etl_log l2
      ON l2.filedate = z.filedate
     AND l2.load_status = 'loading'
     AND l2.quelltabelle = 'tbl_import_fanf_pdf'
     AND l2.zieltabelle = 'tbl_uebertrag_fanf_pdf'
    GROUP BY z.filedate, z.filename
) x
  ON x.filedate = l.filedate 
 AND x.filename = l.filename

SET l.load_status = 'complete',
    l.mindate = x.mindate,
    l.maxdate = x.maxdate

WHERE l.load_status = 'loading'
  AND l.quelltabelle = 'tbl_import_fanf_pdf'
  AND l.zieltabelle = 'tbl_uebertrag_fanf_pdf';


############################################################
## FANF FUNKTION
## tbl_uebertrag_fanf_pdf -> tbl_uebertrag_fanf_funktion
############################################################

-- load start
INSERT INTO tbl_check_etl_log (quelltabelle, zieltabelle, filedate, mindate, maxdate, rowcount, load_status)
SELECT 'tbl_uebertrag_fanf_pdf' AS quelltabelle
     , v.`tbl_uebertrag_fanf_funktion` AS zieltabelle
     , q.filedate
     , MIN(CASE WHEN q.schicht = 'nachtschicht' then q.start_date + INTERVAL 1 DAY ELSE q.start_date END) AS mindate
     , MAX(CASE WHEN q.schicht = 'nachtschicht' then q.end_date + INTERVAL 1 DAY ELSE q.end_date END) AS maxdate
     , COUNT(*) AS rowcount
     , `loading` AS load_status
     FROM tbl_uebertrag_fanf_pdf q
     JOIN (VALUES ('tbl_uebertrag_fanf_funktion', 'loading')
	             , ('tbl_uebertrag_fanf', 'pending')
					 , ('tbl_uebertrag_fanf_changelog', 'pending')) v ON TRUE
     GROUP BY 2, 3
ON DUPLICATE KEY UPDATE
     rowcount = VALUES(rowcount);

-- FANF Funktion
REPLACE INTO tbl_uebertrag_fanf_funktion (datum, schicht, oe, tätigkeit, funktion, beauftragung, filedate)
WITH updatelist AS(
	SELECT filedate 
	  FROM tbl_check_etl_log
	 WHERE quelltabelle = 'tbl_uebertrag_fanf_pdf' 
	   AND zieltabelle = 'tbl_uebertrag_fanf_funktion'
	   AND load_status = 'loading'
)
, schichten AS(
	SELECT *, concat(s.Schicht, 'schicht') AS schicht_lang
	  FROM tbl_schichten s
	 WHERE s.index <= 3
)
-- prio nach filedate
, base AS(
	SELECT p.funktion, p.schicht, p.start_date, p.end_date, p.beauftragung, p.last_insert_update, p.filedate
	     , ROW_NUMBER() OVER (PARTITION BY funktion, schicht, d.datum ORDER BY filedate DESC) rn 
	FROM tbl_uebertrag_fanf_pdf p
	JOIN updatelist u ON u.filedate = p.filedate
)
SELECT d.datum + INTERVAL IF(s.schicht_int = 1, 1, 0) DAY AS datum
     , s.Schicht_int AS schicht
	  , f2.oe
	  , f2.tätigkeit
	  , f2.funktion
	  , f.beauftragung
	  , ifnull(f.filedate, f.last_insert_update) AS filedate 
FROM base f
JOIN schichten s ON f.schicht = s.schicht_lang
LEFT JOIN tbl_stamm_funktionen f2 ON f.funktion = f2.funktion
LEFT JOIN tbl_datum d ON d.datum BETWEEN f.start_date AND f.end_date
WHERE rn = 1
;

############################################################
## FANF TÄTIGKEIT
## tbl_uebertrag_fanf_funktion -> tbl_uebertrag_fanf
############################################################
UPDATE tbl_check_etl_log
   SET load_status = 'loading'
 WHERE load_status = 'pending'
   AND quelltabelle = 'tbl_uebertrag_fanf_pdf'
   AND zieltabelle = 'tbl_uebertrag_fanf'
;

INSERT INTO tbl_uebertrag_fanf (datum, schicht, oe, tätigkeit, beauftragung, filedate)
WITH updatelist AS(
SELECT filedate, mindate, maxdate
FROM tbl_check_etl_log
WHERE quelltabelle = 'tbl_uebertrag_fanf_pdf' 
  AND zieltabelle = 'tbl_uebertrag_fanf'
  AND load_status = 'loading'
)
SELECT datum, schicht, oe, tätigkeit, sum(beauftragung) AS beauftragung, max(filedate) AS filedate
FROM tbl_uebertrag_fanf_funktion f
JOIN updatelist u ON f.datum BETWEEN u.mindate AND u.maxdate
GROUP BY 1, 2, 3, 4
;

UPDATE tbl_check_etl_log
   SET load_status = 'pending'
 WHERE load_status = 'complete'
   AND quelltabelle = 'tbl_uebertrag_fanf_pdf'
   AND zieltabelle = 'tbl_uebertrag_fanf'
;
############################################################
## CHANGELOG
## tbl_uebertrag_fanf_funktion -> tbl_uebertrag_fanf_changelog
############################################################
UPDATE tbl_check_etl_log
   SET load_status = 'loading'
 WHERE load_status = 'pending'
   AND quelltabelle = 'tbl_uebertrag_fanf_pdf'
   AND zieltabelle = 'tbl_uebertrag_fanf_changelog'
;

INSERT INTO tbl_uebertrag_fanf_changelog(datum, schicht, oe, tätigkeit, funktion, beauftragung, filedate_first, filedate_latest)
WITH updatelist AS(
SELECT filedate, mindate, maxdate
FROM tbl_check_etl_log
WHERE quelltabelle = 'tbl_uebertrag_fanf_pdf' 
  AND zieltabelle = 'tbl_uebertrag_fanf_funktion'
  AND load_status = 'loading'
)
-- bestehende Changelog-Einträge sammeln, um ggf zu aktualisieren
, latest AS(
        SELECT datum
		       , schicht
				 , funktion
				 , beauftragung
				 , filedate_first
				 , ROW_NUMBER() OVER (PARTITION BY datum, schicht, funktion ORDER BY filedate_latest DESC) rn
          FROM tbl_uebertrag_fanf_changelog c
          JOIN (SELECT MIN(mindate) AS mindate, MAX(maxdate) AS maxdate FROM updatelist) d ON c.datum BETWEEN d.mindate AND d.maxdate
)
-- Changelog Eintrag generieren
SELECT f.datum
     , f.schicht
	  , f.oe
	  , f.tätigkeit
	  , f.funktion
	  , f.beauftragung
	  , COALESCE(c.filedate_first, f.filedate, f.last_insert_update) AS filedate_first
	  , f.filedate AS filedate_latest
FROM tbl_uebertrag_fanf_funktion f
JOIN updatelist u ON u.filedate = f.filedate
LEFT JOIN latest c ON f.datum = c.datum 
                  AND f.schicht = c.schicht 
						AND f.funktion = c.funktion 
                  AND f.beauftragung = c.beauftragung
                  AND rn = 1
ON DUPLICATE KEY UPDATE
filedate_latest = VALUES(filedate_latest)
;
-- load ende
UPDATE tbl_check_etl_log
   SET load_status = 'complete'
 WHERE load_status = 'loading'
   AND quelltabelle = 'tbl_uebertrag_fanf_pdf'
   AND zieltabelle = 'tbl_uebertrag_fanf_changelog'
;

END//
