-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fanf_pdf.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fanf_pdf`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fanf_pdf`()
SQL SECURITY DEFINER BEGIN
############################################################
## VORBEREITEN
## 
############################################################

-- filedate trennen falls mehrere Dateien gleichen Zeitstempel haben
UPDATE tbl_import_fanf_pdf t
JOIN (
    SELECT filename,
           filedate,
           filedate + INTERVAL (
               ROW_NUMBER() OVER (
                   PARTITION BY filedate
                   ORDER BY filename
               ) - 1
           ) SECOND AS adjusted_filedate
    FROM tbl_import_fanf_pdf
    WHERE filedate IN (
        SELECT filedate
        FROM (
            SELECT filedate
            FROM tbl_import_fanf_pdf
            GROUP BY filedate
            HAVING COUNT(*) > 1
        ) d
    )
) x
    ON t.filename = x.filename
   AND t.filedate = x.filedate
SET t.filedate = x.adjusted_filedate
WHERE t.filedate <> x.adjusted_filedate;

-- scope definieren: tmp_fanf_updatelist

DROP TEMPORARY TABLE IF EXISTS tmp_fanf_updatelist
;

CREATE TEMPORARY TABLE tmp_fanf_updatelist (
    filedate DATETIME
  , filename VARCHAR(255)
  , mindate DATE
  , maxdate DATE
  , PRIMARY KEY (filedate)
)
;

INSERT INTO tmp_fanf_updatelist (filedate, filename)

SELECT filedate, filename
  FROM tbl_import_fanf_pdf
 GROUP BY 1, 2
;

############################################################
## FANF PDF
## tbl_import_fanf_pdf -> tbl_uebertrag_fanf_pdf_parsed
############################################################

-- raw archivieren
REPLACE INTO tbl_uebertrag_fanf_pdf (
    filename
  , filedate
  , pdf_line
)
SELECT filename
     , filedate
     , pdf_line
  FROM tbl_import_fanf_pdf
;

-- parsed materialisieren
REPLACE INTO tbl_uebertrag_fanf_pdf_parsed (
    filename
  , filedate
  , start_date
  , end_date
  , schicht
  , funktion
  , beauftragung
)

WITH metadata AS (
	SELECT r.filename
	     , r.filedate
	     , MAX(
	           CASE
	               WHEN r.pdf_line LIKE 'Forcast-Start%'
	               THEN REPLACE(r.pdf_line, 'Forcast-Start', '')
	           END
	       ) AS start_date
	     , MAX(
	           CASE
	               WHEN r.pdf_line LIKE 'Forecast-Ende%'
	               THEN REPLACE(r.pdf_line, 'Forecast-Ende', '')
	           END
	       ) AS end_date
	     , MAX(
	           CASE
	               WHEN r.pdf_line IN (
	                    'SchichtNachtschicht'
	                  , 'SchichtFrühschicht'
	                  , 'SchichtSpätschicht'
	               )
	               THEN REPLACE(r.pdf_line, 'Schicht', '')
	           END
	       ) AS schicht

	  FROM tbl_import_fanf_pdf r

	  JOIN tmp_fanf_updatelist u
	    ON u.filedate = r.filedate

	 GROUP BY 1
	        , 2
)

SELECT r.filename
     , r.filedate
     , CAST(m.start_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY AS start_date
     , CAST(m.end_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY AS end_date
     , m.schicht
     , map.clean_label AS funktion
     , CAST(
           NULLIF(
               REGEXP_SUBSTR(
                   TRIM(
                       REPLACE(r.pdf_line, map.raw_label, '')
                   )
                 , '[0-9]+'
               )
             , ''
           ) AS UNSIGNED
       ) AS beauftragung

  FROM tbl_import_fanf_pdf r

  JOIN tmp_fanf_updatelist u
    ON u.filedate = r.filedate

  JOIN tbl_stamm_fanf_pdf_translate map
    ON r.pdf_line LIKE CONCAT(map.raw_label, '%')

  LEFT JOIN metadata m
    ON m.filedate = r.filedate
   AND m.filename = r.filename

HAVING beauftragung IS NOT NULL
   AND start_date <= end_date
;

############################################################
## DATE RANGE SCOPE
############################################################

UPDATE tmp_fanf_updatelist u
JOIN (
	SELECT filedate
	     , MIN(start_date) AS mindate
	     , MAX(end_date) AS maxdate
	  FROM tbl_uebertrag_fanf_pdf_parsed
	 WHERE filedate IN (
		SELECT filedate
		  FROM tmp_fanf_updatelist
	 )
	 GROUP BY filedate
) p
  ON p.filedate = u.filedate

SET u.mindate = p.mindate
  , u.maxdate = p.maxdate
;

############################################################
## FANF FUNKTION
## tbl_uebertrag_fanf_pdf_parsed -> tbl_uebertrag_fanf_funktion
############################################################

REPLACE INTO tbl_uebertrag_fanf_funktion (
    datum
  , schicht
  , oe
  , tätigkeit
  , funktion
  , beauftragung
  , filedate
)

WITH schichten AS (
	SELECT *
	     , CONCAT(s.schicht, 'schicht') AS schicht_lang
	  FROM tbl_schichten s
	 WHERE s.index <= 3
)

, base AS (
	SELECT p.funktion
	     , p.schicht
	     , p.start_date
	     , p.end_date
	     , d.datum
	     , p.beauftragung
	     , p.filedate
	     , p.last_insert_update
	     , ROW_NUMBER() OVER (PARTITION BY p.funktion, p.schicht, d.datum ORDER BY p.filedate DESC) rn

	  FROM tbl_uebertrag_fanf_pdf_parsed p

	  JOIN tmp_fanf_updatelist u ON u.filedate = p.filedate
	  
	  LEFT JOIN tbl_datum d ON d.datum BETWEEN p.start_date AND p.end_date
)

SELECT f.datum AS datum
     , s.schicht_int AS schicht
     , f2.oe
     , f2.tätigkeit
     , f2.funktion
     , f.beauftragung
     , IFNULL(f.filedate, f.last_insert_update) AS filedate

  FROM base f

  JOIN schichten s ON f.schicht = s.schicht_lang
  
  LEFT JOIN tbl_uebertrag_fanf_funktion existing ON existing.datum = f.datum
                                                AND existing.schicht = s.schicht_int
                                                AND existing.funktion = f.funktion

  LEFT JOIN tbl_stamm_funktionen f2 ON f.funktion = f2.funktion

 WHERE rn = 1
   AND (    existing.filedate IS NULL 
         OR IFNULL(f.filedate, f.last_insert_update) > existing.filedate
       )
   AND f.datum IS NOT null
;

############################################################
## FANF TÄTIGKEIT
## tbl_uebertrag_fanf_funktion -> tbl_uebertrag_fanf
############################################################

REPLACE INTO tbl_uebertrag_fanf (
    datum
  , schicht
  , oe
  , tätigkeit
  , beauftragung
  , filedate
)

SELECT f.datum
     , f.schicht
     , f.oe
     , f.tätigkeit
     , SUM(f.beauftragung) AS beauftragung
     , MAX(f.filedate) AS filedate

  FROM tbl_uebertrag_fanf_funktion f

 WHERE EXISTS (
	SELECT 1 FROM tmp_fanf_updatelist u 
	 WHERE f.datum BETWEEN u.mindate AND u.maxdate
 )

 GROUP BY 1
        , 2
        , 3
        , 4
;

############################################################
## CHANGELOG
############################################################

INSERT INTO tbl_uebertrag_fanf_changelog (
    datum
  , schicht
  , oe
  , tätigkeit
  , funktion
  , beauftragung
  , filedate_first
  , filedate_latest
)

WITH latest AS (
	SELECT datum
	     , schicht
	     , funktion
	     , beauftragung
	     , filedate_first AS old_filedate_first
	     , ROW_NUMBER() OVER (
	           PARTITION BY datum
	                        , schicht
	                        , funktion
	           ORDER BY filedate_latest DESC
	       ) rn

	  FROM tbl_uebertrag_fanf_changelog
)

SELECT f.datum
     , f.schicht
     , f.oe
     , f.tätigkeit
     , f.funktion
     , f.beauftragung
     , COALESCE(c.old_filedate_first, f.filedate) AS filedate_first
     , f.filedate AS filedate_latest

  FROM tbl_uebertrag_fanf_funktion f

  JOIN tmp_fanf_updatelist u ON u.filedate = f.filedate

  LEFT JOIN latest c
    ON f.datum = c.datum
   AND f.schicht = c.schicht
   AND f.funktion = c.funktion
   AND f.beauftragung = c.beauftragung
   AND c.rn = 1
   
    ON DUPLICATE KEY UPDATE
       filedate_first = LEAST(filedate_first , VALUES(filedate_latest))
     , filedate_latest = GREATEST(filedate_latest, VALUES(filedate_latest))
;

############################################################
## CLEANUP
############################################################

 DELETE i FROM tbl_import_fanf_pdf i
 JOIN tmp_fanf_updatelist u ON i.filedate = u.filedate
 ;

DROP TEMPORARY TABLE IF EXISTS tmp_fanf_updatelist
 ;

END//
