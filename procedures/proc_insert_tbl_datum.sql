-- Managed by db-workbench; source of truth: db-report/procedures/proc_insert_tbl_datum.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_insert_tbl_datum`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_insert_tbl_datum`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_insert_tbl_datum", "Start", 0);
-- SELECT MAX(YEAR(datum)) + 1 INTO @jahr FROM tbl_datum;
SET @jahr = YEAR(CURDATE()) + 2;
-- SET @jahr = 2027;

REPLACE INTO tbl_datum 
  WITH RECURSIVE all_dates AS (
    SELECT DATE(CONCAT(@jahr - 1, '-12-24')) AS datum
    UNION ALL
    SELECT DATE_ADD(datum, INTERVAL 1 DAY)
    FROM all_dates
    WHERE datum < DATE(CONCAT(@jahr, '-12-31'))
  )
,  ostern AS (
    SELECT DATE('2022-04-17') AS ostersonntag
    UNION VALUES
    ('2023-04-09'), ('2024-03-31'), ('2025-04-20'), ('2026-04-05'), 
    ('2027-03-28'), ('2028-04-16'), ('2029-04-01'), ('2030-04-21'), 
    ('2031-04-13'), ('2032-03-28'), ('2033-04-17'), ('2034-04-09'),
    ('2035-03-25'), ('2036-04-13'), ('2037-04-05'), ('2038-04-25'), 
    ('2039-04-10'), ('2040-04-01'), ('2041-04-21'), ('2042-04-06'), 
    ('2043-03-29'), ('2044-04-17'), ('2045-04-09'), ('2046-03-25'), 
    ('2047-04-14'), ('2048-04-05'), ('2049-04-18'), ('2050-04-10')
  )
,  relative_holidays AS (
    SELECT DATE_ADD(ostersonntag, INTERVAL -2 DAY) AS datum FROM ostern 			  -- Karfreitag
    UNION SELECT DATE_ADD(ostersonntag, INTERVAL 1 DAY) FROM ostern                -- Ostermontag
    UNION SELECT DATE_ADD(ostersonntag, INTERVAL 39 DAY) FROM ostern               -- Christi Himmelfahrt
    UNION SELECT DATE_ADD(ostersonntag, INTERVAL 50 DAY) FROM ostern               -- Pfingstmontag
  )
,  fixed_holidays AS (
    SELECT 1 AS monat, 1 AS tag
    UNION VALUES (1,6), (5,1), (10,3), (10,31), (12,24), (12,25), (12,26), (12,31)
  )
, enriched AS (
    SELECT DATE(d.datum) datum
         , COALESCE(h.datum, f.tag) IS NOT NULL AS feiertag
         , DAYOFWEEK(d.datum) BETWEEN 2 AND 6 
			  AND COALESCE(h.datum, f.tag) IS NULL AS arbeitstag
         , MOD(ROUND(DATEDIFF(d.datum, '2022-01-06')/ 7), 3) AS schichtindex
    FROM all_dates d
    LEFT JOIN relative_holidays h ON d.datum = h.datum
    LEFT JOIN fixed_holidays f ON MONTH(d.datum) = f.monat AND DAY(d.datum) = f.tag
    WHERE d.datum BETWEEN '2022-08-01' AND '2050-12-31'
    ORDER BY d.datum
)
    SELECT datum
	 		, feiertag
    		, arbeitstag
         , ROW_NUMBER() OVER (PARTITION BY YEARWEEK(datum, 3), arbeitstag ORDER BY datum) = 1 
           AND arbeitstag AS wochenbeginn
         , schichtindex
			, NOT LAG(arbeitstag) OVER (ORDER BY datum) 
			  AND NOT LEAD(arbeitstag) OVER (ORDER BY datum)
			  AND arbeitstag AS brueckentag
    FROM enriched e
    WHERE year(datum) = @jahr ;
call schreibe_log("proc_insert_tbl_datum", "Ende", @jahr);
END//
