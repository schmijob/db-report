-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fanf3.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fanf3`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fanf3`()
SQL SECURITY DEFINER BEGIN
-- neuer fanf import
UPDATE tbl_import_fanf
   SET filedate = lastinsertupdate
 WHERE filedate IS NULL
;

SELECT MIN(datum) INTO @mindate FROM tbl_import_fanf WHERE schicht <> 'nachtschicht';
SELECT MAX(datum) INTO @maxdate FROM tbl_import_fanf WHERE schicht <> 'nachtschicht';
SELECT MAX(filedate) INTO @incoming_filedate FROM tbl_import_fanf;

DELETE FROM tbl_uebertrag_fanf_funktion WHERE datum BETWEEN @mindate AND @maxdate AND ifnull(filedate, '1900-01-01') < @incoming_filedate;
INSERT IGNORE INTO tbl_uebertrag_fanf_funktion (datum, schicht, oe, tätigkeit, funktion, beauftragung, filedate)

WITH schichten AS(
SELECT *, concat(s.Schicht, 'schicht') AS schicht_lang
  FROM tbl_schichten s
 WHERE s.index <= 3
)

SELECT f.datum + INTERVAL IF(s.schicht_int = 1, 1, 0) DAY AS datum
	  , s.Schicht_int AS schicht
	  , f2.oe
     , f2.`tätigkeit`
	  , f.funktion
	  , f.beauftragung * IF(f.funktion = 'Pausenvertretung' AND f.datum >= '2026-10-04', 2, 1) AS beauftragung
	  , ifnull(f.filedate, f.lastinsertupdate) AS filedate
  FROM tbl_import_fanf f
  JOIN schichten s ON f.schicht = s.schicht_lang
  LEFT JOIN tbl_stamm_funktionen f2 ON f.funktion = f2.funktion
 WHERE f.datum + INTERVAL IF(s.schicht_int = 1, 1, 0) DAY BETWEEN @mindate AND @maxdate
;
DELETE FROM tbl_uebertrag_fanf WHERE datum BETWEEN @mindate AND @maxdate AND ifnull(filedate, '1900-01-01') < @incoming_filedate
;
INSERT IGNORE INTO tbl_uebertrag_fanf (datum, schicht, oe, tätigkeit, beauftragung, filedate)
SELECT datum, schicht, oe, tätigkeit, sum(beauftragung) AS beauftragung, max(filedate) AS filedate
FROM tbl_uebertrag_fanf_funktion
WHERE datum BETWEEN @mindate AND @maxdate
GROUP BY 1, 2, 3, 4
;

INSERT INTO tbl_uebertrag_fanf_changelog(datum, schicht, oe, tätigkeit, funktion, beauftragung, filedate_first, filedate_latest)
WITH latest AS(
        SELECT datum
		       , schicht
				 , funktion
				 , beauftragung
				 , filedate_first AS old_filedate_first
				 , ROW_NUMBER() OVER (PARTITION BY datum, schicht, funktion ORDER BY filedate_latest DESC) rn
          FROM tbl_uebertrag_fanf_changelog
         WHERE datum BETWEEN @mindate AND @maxdate
)
SELECT f.datum
     , f.schicht
	  , f.oe
	  , f.tätigkeit
	  , f.funktion
	  , f.beauftragung
	  , COALESCE(c.old_filedate_first, f.filedate) AS filedate_first
	  , COALESCE(f.filedate, f.last_insert_update) AS filedate_latest
FROM tbl_uebertrag_fanf_funktion f
LEFT JOIN latest c ON f.datum = c.datum 
                  AND f.schicht = c.schicht 
						AND f.funktion = c.funktion 
                  AND f.beauftragung = c.beauftragung
                  AND rn = 1
ON DUPLICATE KEY UPDATE
  filedate_first = LEAST(filedate_first, VALUES(filedate_latest))
, filedate_latest = GREATEST(filedate_latest, VALUES(filedate_latest))
;
END//
