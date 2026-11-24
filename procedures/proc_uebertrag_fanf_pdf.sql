-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fanf_pdf.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fanf_pdf`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fanf_pdf`()
SQL SECURITY DEFINER BEGIN
############################################################
## VORBEREITEN
## 
############################################################

-- Einen Zeitstempel je Datei vergeben. Gezählt werden Dateien, nicht PDF-Zeilen.
UPDATE tbl_import_fanf_pdf t
JOIN (
    SELECT files.filename
         , files.filedate
         , files.filedate + INTERVAL (
               ROW_NUMBER() OVER (
                   PARTITION BY files.filedate
                   ORDER BY files.filename
               ) - 1
           ) SECOND AS adjusted_filedate
      FROM (
          SELECT DISTINCT filename, filedate
            FROM tbl_import_fanf_pdf
      ) files
     WHERE files.filedate IN (
           SELECT repeated.filedate
             FROM (
                 SELECT filedate
                   FROM (
                       SELECT DISTINCT filename, filedate
                         FROM tbl_import_fanf_pdf
                   ) distinct_files
                  GROUP BY filedate
                 HAVING COUNT(*) > 1
             ) repeated
     )
) x
    ON t.filename = x.filename
   AND t.filedate = x.filedate
SET t.filedate = x.adjusted_filedate
WHERE t.filedate <> x.adjusted_filedate;

IF EXISTS (
    SELECT filedate
      FROM (
          SELECT DISTINCT filename, filedate
            FROM tbl_import_fanf_pdf
      ) distinct_files
     GROUP BY filedate
    HAVING COUNT(*) > 1
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Datei-Zeitstempel konnten nicht eindeutig vergeben werden.';
END IF;

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
SELECT DISTINCT filedate, filename
  FROM tbl_import_fanf_pdf;

-- Ein einmaliger PDF-Fehler: Im WA-Abschnitt ist Staplerfahrer falsch
-- verknuepft. Nur die erste solche Zeile nach Warenausgang wird normalisiert.
DROP TEMPORARY TABLE IF EXISTS tmp_fanf_pdf_normalized;
CREATE TEMPORARY TABLE tmp_fanf_pdf_normalized AS
SELECT r.fanf_pdf_import_id
     , r.filename
     , r.filedate
     , CASE WHEN wa.fanf_pdf_import_id IS NOT NULL
            THEN 'LBH Teamleiter / Koordinator'
            ELSE r.pdf_line
       END AS pdf_line
     , CASE WHEN wa.fanf_pdf_import_id IS NOT NULL THEN '0'
            ELSE r.pdf_value
       END AS pdf_value
  FROM tbl_import_fanf_pdf r
  LEFT JOIN (
      SELECT candidate.filename
           , candidate.filedate
           , MIN(candidate.fanf_pdf_import_id) AS fanf_pdf_import_id
        FROM tbl_import_fanf_pdf candidate
        JOIN (
            SELECT filename
                 , filedate
                 , MAX(fanf_pdf_import_id) AS section_id
              FROM tbl_import_fanf_pdf
             WHERE pdf_line = 'Warenausgang:'
             GROUP BY filename, filedate
        ) wa_section
          ON wa_section.filename = candidate.filename
         AND wa_section.filedate = candidate.filedate
         AND candidate.fanf_pdf_import_id > wa_section.section_id
       WHERE candidate.pdf_line = 'Staplerfahrer'
       GROUP BY candidate.filename, candidate.filedate
  ) wa
    ON wa.filename = r.filename
   AND wa.filedate = r.filedate
   AND wa.fanf_pdf_import_id = r.fanf_pdf_import_id;

-- Die neue Profilstruktur liefert Metadaten und Werte in getrennten Spalten.
-- Fehlende oder widerspruechliche Metadaten muessen den Import abbrechen.
IF EXISTS (
    SELECT filename, filedate
      FROM tbl_import_fanf_pdf
     GROUP BY filename, filedate
    HAVING COUNT(DISTINCT CASE
               WHEN pdf_line = 'Forcast-Start'
               THEN NULLIF(TRIM(pdf_value), '')
           END) <> 1
        OR COUNT(DISTINCT CASE
               WHEN pdf_line = 'Forecast-Ende'
               THEN NULLIF(TRIM(pdf_value), '')
           END) <> 1
        OR COUNT(DISTINCT CASE
               WHEN pdf_line = 'Schicht'
               THEN NULLIF(TRIM(pdf_value), '')
           END) <> 1
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Forecast-Datum oder Schicht fehlt bzw. ist widerspruechlich.';
END IF;

IF EXISTS (
    SELECT 1
      FROM tbl_import_fanf_pdf
     WHERE pdf_line = 'Forcast-Start'
       AND (
           TRIM(pdf_value) NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
           OR COALESCE(DATE_FORMAT(STR_TO_DATE(TRIM(pdf_value), '%Y-%m-%d'), '%Y-%m-%d'), '') <> TRIM(pdf_value)
       )
) OR EXISTS (
    SELECT 1
      FROM tbl_import_fanf_pdf
     WHERE pdf_line = 'Forecast-Ende'
       AND (
           TRIM(pdf_value) NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
           OR COALESCE(DATE_FORMAT(STR_TO_DATE(TRIM(pdf_value), '%Y-%m-%d'), '%Y-%m-%d'), '') <> TRIM(pdf_value)
       )
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Forecast-Datum hat kein gueltiges ISO-Format.';
END IF;

IF EXISTS (
    SELECT 1
      FROM tbl_import_fanf_pdf
     WHERE pdf_line = 'Schicht'
       AND TRIM(pdf_value) NOT IN ('Nachtschicht', 'Frühschicht', 'Spätschicht')
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Unbekannte Schicht.';
END IF;

-- Numerische Wertzeilen muessen direkt einer Funktion zugeordnet werden.
IF EXISTS (
    SELECT 1
      FROM tmp_fanf_pdf_normalized r
      LEFT JOIN tbl_stamm_funktionen f
        ON f.funktion = r.pdf_line
     WHERE NULLIF(TRIM(r.pdf_value), '') REGEXP '^[0-9]+$'
       AND f.funktion IS NULL
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Numerische Zeile passt zu keiner Funktion in tbl_stamm_funktionen.';
END IF;

IF EXISTS (
    SELECT filename, filedate
      FROM tbl_import_fanf_pdf
     GROUP BY filename, filedate
    HAVING MAX(CASE WHEN pdf_line = 'Forcast-Start'
                    THEN STR_TO_DATE(TRIM(pdf_value), '%Y-%m-%d') END)
           > MAX(CASE WHEN pdf_line = 'Forecast-Ende'
                      THEN STR_TO_DATE(TRIM(pdf_value), '%Y-%m-%d') END)
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Forecast-Start liegt nach Forecast-Ende.';
END IF;

IF EXISTS (
    SELECT 1
      FROM tmp_fanf_pdf_normalized r
      JOIN tbl_stamm_funktionen f
        ON f.funktion = r.pdf_line
     WHERE NULLIF(TRIM(r.pdf_value), '') IS NOT NULL
       AND TRIM(r.pdf_value) NOT REGEXP '^[0-9]+$'
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Funktionswert ist keine ganze Zahl.';
END IF;

IF EXISTS (
    SELECT r.filename, r.filedate, f.funktion
      FROM tmp_fanf_pdf_normalized r
      JOIN tbl_stamm_funktionen f
        ON f.funktion = r.pdf_line
     WHERE NULLIF(TRIM(r.pdf_value), '') REGEXP '^[0-9]+$'
     GROUP BY r.filename, r.filedate, f.funktion
    HAVING COUNT(DISTINCT CAST(TRIM(r.pdf_value) AS UNSIGNED)) > 1
) THEN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'FANF PDF: Eine Funktion hat in derselben Datei mehrere Werte.';
END IF;

############################################################
## FANF PDF
## tbl_import_fanf_pdf -> tbl_uebertrag_fanf_pdf_parsed
############################################################

-- Raw-Archiv fuer die importierten Dateien idempotent ersetzen.
DELETE a
  FROM tbl_uebertrag_fanf_pdf a
  JOIN tmp_fanf_updatelist u
    ON u.filedate = a.filedate
   AND u.filename = a.filename;

INSERT INTO tbl_uebertrag_fanf_pdf (
    filename
  , filedate
  , pdf_line
  , pdf_value
)
SELECT filename
     , filedate
     , pdf_line
     , pdf_value
  FROM tbl_import_fanf_pdf;

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

WITH source_rows AS (
    SELECT DISTINCT filename, filedate, pdf_line, pdf_value
      FROM tmp_fanf_pdf_normalized
), metadata AS (
    SELECT r.filename
         , r.filedate
         , MAX(CASE WHEN r.pdf_line = 'Forcast-Start'
                    THEN NULLIF(TRIM(r.pdf_value), '') END) AS start_date
         , MAX(CASE WHEN r.pdf_line = 'Forecast-Ende'
                    THEN NULLIF(TRIM(r.pdf_value), '') END) AS end_date
         , MAX(CASE WHEN r.pdf_line = 'Schicht'
                    THEN NULLIF(TRIM(r.pdf_value), '') END) AS schicht
      FROM source_rows r
      JOIN tmp_fanf_updatelist u
        ON u.filedate = r.filedate
       AND u.filename = r.filename
     GROUP BY r.filename, r.filedate
), function_values AS (
    SELECT r.filename
         , r.filedate
         , f.funktion
         , MAX(CAST(TRIM(r.pdf_value) AS UNSIGNED)) AS beauftragung
      FROM source_rows r
      JOIN tmp_fanf_updatelist u
        ON u.filedate = r.filedate
       AND u.filename = r.filename
      JOIN tbl_stamm_funktionen f
        ON f.funktion = r.pdf_line
     WHERE NULLIF(TRIM(r.pdf_value), '') REGEXP '^[0-9]+$'
     GROUP BY r.filename, r.filedate, f.funktion
)
SELECT v.filename
     , v.filedate
     , CAST(m.start_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY AS start_date
     , CAST(m.end_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY AS end_date
     , m.schicht
     , v.funktion
     , v.beauftragung
  FROM function_values v
  JOIN metadata m
    ON m.filedate = v.filedate
   AND m.filename = v.filename
 WHERE CAST(m.start_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY
       <= CAST(m.end_date AS DATE) + INTERVAL IF(m.schicht = 'Nachtschicht', 1, 0) DAY;

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

DROP TEMPORARY TABLE IF EXISTS tmp_fanf_pdf_normalized
 ;

END//
