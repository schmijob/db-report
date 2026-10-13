-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fanf.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fanf`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fanf`()
SQL SECURITY DEFINER BEGIN
	-- 
	SELECT MAX(last_insert_update) INTO @liu FROM vp_fanf_i;
	IF NOT EXISTS (SELECT 1 FROM tbl_uebertrag_fanf WHERE last_insert_update > @liu LIMIT 1) THEN
	
	  DROP TEMPORARY TABLE IF EXISTS tmp_daterange;
	  CREATE TEMPORARY TABLE tmp_daterange ENGINE=MEMORY AS
		  SELECT schicht, GREATEST(MIN(datum), '2026-02-23') AS mindate, MAX(datum) AS maxdate
		    FROM vp_fanf_i
		   GROUP BY schicht
		;
	
	  DELETE u FROM tbl_uebertrag_fanf u
	    JOIN tmp_daterange w 
		   ON w.schicht = u.schicht AND u.datum BETWEEN w.mindate AND w.maxdate
			AND u.datum NOT BETWEEN '2025-12-22' AND '2025-12-30';
	
	  -- =========================
	  -- Check: fehlen Funktionen im Stamm?
	  -- (nur 1 Log-Eintrag pro Lauf; proc_fehler_log macht Upsert+Counter)
	  -- =========================
	  SET @missing_cnt := 0;
	  SET @missing_list := NULL;
	
	  SELECT
	      COUNT(DISTINCT f.funktion) AS missing_cnt,
	      LEFT(GROUP_CONCAT(DISTINCT f.funktion ORDER BY f.funktion SEPARATOR ', '), 512) AS missing_list
	    INTO @missing_cnt, @missing_list
	    FROM vp_fanf_i f
	    LEFT JOIN tbl_stamm_funktionen s ON s.funktion = f.funktion
	   WHERE s.funktion IS NULL
		;
	
	  IF @missing_cnt > 0 THEN
	    CALL proc_fehler_log(
	      NOW(),
	      'missing_funktion_in_stamm',
	      'ERROR',
	      CONCAT('Es fehlen ', @missing_cnt, ' Funktion(en) in tbl_stamm_funktionen; INNER JOIN dropt Zeilen.'),
	      'tbl_import_fanf_*',
	      'funktion',
	      @missing_list,
	      JSON_OBJECT('missing_cnt', @missing_cnt, 'missing_list', @missing_list),
	      @missing_cnt
	    );
	  END IF;
	
	  -- =========================
	  -- Load
	  -- =========================
	  INSERT INTO tbl_uebertrag_fanf (datum, schicht, oe, tätigkeit, beauftragung, filedate)
	
	  SELECT
	      f.datum,
	      f.schicht,
	      s.oe,
	      s.tätigkeit,
	      SUM(f.beauftragung) AS beauftragung,
	      MAX(f.filedate) AS filedate
	    FROM vp_fanf_i f
	    JOIN tbl_stamm_funktionen s ON f.funktion = s.funktion
	    JOIN tbl_datum d ON f.datum = d.datum AND d.arbeitstag = 1
	     AND d.datum NOT BETWEEN '2025-12-22' AND '2025-12-30'
	    JOIN tmp_daterange w ON w.schicht = f.schicht AND f.datum BETWEEN w.mindate AND w.maxdate
	   GROUP BY f.datum, f.schicht, s.oe, s.tätigkeit
	   	   	
	   
	  ON DUPLICATE KEY UPDATE
	      beauftragung = VALUES(beauftragung),
	      filedate     = VALUES(filedate);
	
	  CALL proc_ueb_fz_forecast_soll();
	  DROP TEMPORARY TABLE tmp_daterange;
	  
	  CALL proc_uebertrag_fanf2();
	  
	END IF;
END//
