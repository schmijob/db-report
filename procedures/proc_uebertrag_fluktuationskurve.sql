-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fluktuationskurve.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fluktuationskurve`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fluktuationskurve`()
SQL SECURITY DEFINER BEGIN
SET @asof_date := CURDATE();
SET @epoch_start := DATE('2022-08-01');
SET @horizon_days := 999; -- or DATEDIFF(@asof_date, @epoch_start);

-- de-spike controls (daily output)
SET @despike_start_day := 90;   -- don't touch the steep first 90 days
SET @w_days := 14;              -- neighborhood radius (broad enough to catch 1y humps)
SET @core_days := 2;            -- exclude +/- core_days around the current day (ring neighborhood)

SET @spike_mult := 7.0;         -- ratio trigger
SET @delta_min := 0.020;        -- absolute trigger (daily hazard units)
SET @min_events := 5;           -- require some volume
SET @min_at_risk := 50;         -- avoid tail weirdness

SET @half_life_days := 365;     -- recency bias half life
SET @supplier_change := DATE('2026-01-01'); -- supplier change date
SET @supplier_weight_mult := 2.0; -- supplier bias

DELETE FROM tbl_ueb_fluktuationskurve;
INSERT INTO tbl_ueb_fluktuationskurve(`employee_type`,
	`day_since_hire`,
	`n_at_risk`,
	`n_events`,
	`hazard_raw`,
	`hazard_despiked`,
	survival_raw,
	anw)
	
WITH RECURSIVE
personal AS (
    SELECT
        p.persnr
      , CASE WHEN p.eg = 'ZAK' THEN 'ZAK' ELSE 'DPW' END AS employee_type
      , p.beginn AS start_date
      , NULLIF(p.ende, DATE('9999-12-31')) AS end_date
    FROM tbl_ueb_personalakte_scd p
    LEFT JOIN tbl_stamm_kategorie_abteilung k
      ON p.taetigkeit = k.`tätigkeit`
    WHERE k.kategorie = 'Operativ'
      AND p.beginn IS NOT NULL
      AND p.beginn <= @asof_date
      AND @asof_date BETWEEN p.gueltig_von AND p.gueltig_bis
)
, anw_by_day AS (
    SELECT
        CASE WHEN p.eg = 'ZAK' THEN 'ZAK' ELSE 'DPW' END AS employee_type
      , DATEDIFF(b.datum, p.beginn) AS day_since_hire
      , SUM(b.anwesenheit = 'anw') 
        / NULLIF(SUM(b.anwesenheit <> 'frei'), 0) AS anw
    FROM vp_buchungen b
    JOIN tbl_ueb_personalakte_scd p
      ON b.persnr = p.persnr
     AND b.datum BETWEEN p.gueltig_von AND p.gueltig_bis
    JOIN tbl_stamm_kategorie_abteilung k 
      ON p.taetigkeit = k.`tätigkeit`
     AND k.kategorie = 'Operativ'
    JOIN tbl_datum d 
      ON b.datum = d.datum 
     AND d.arbeitstag = 1
    WHERE DATEDIFF(b.datum, p.beginn) BETWEEN 0 AND @horizon_days
      AND p.beginn IS NOT NULL
      AND p.beginn <= @asof_date
    GROUP BY
        CASE WHEN p.eg = 'ZAK' THEN 'ZAK' ELSE 'DPW' END,
        DATEDIFF(b.datum, p.beginn)
)
, dur AS (
    SELECT
        employee_type
      , GREATEST(
            0
          , DATEDIFF(
                COALESCE(LEAST(end_date, @asof_date), @asof_date)
              , start_date
            )
        ) AS tenure_days
      , CASE
            WHEN end_date IS NOT NULL
             AND end_date <= @asof_date
            THEN 1
            ELSE 0
        END AS is_event
      , POWER(0.5
		       , DATEDIFF(@asof_date, start_date) / @half_life_days
			    )
		  * CASE WHEN employee_type = 'ZAK'
		          AND start_date >= @supplier_change
		         THEN @supplier_weight_mult
		         ELSE 1.0
		    END AS obs_weight  
    FROM personal
)

, totals AS (
    SELECT
        employee_type
      , SUM(obs_weight) AS n_total
    FROM dur
    GROUP BY employee_type
)

, by_day AS (
    SELECT
        employee_type
      , tenure_days AS day_since_hire
      , SUM(obs_weight) AS ended_or_censored
      , SUM(is_event * obs_weight) AS events
      , SUM(is_event) AS events_raw
    FROM dur
    GROUP BY employee_type, tenure_days
)

, seq AS (
    SELECT 0 AS day_since_hire
    UNION ALL
    SELECT day_since_hire + 1
    FROM seq
    WHERE day_since_hire + 1 <= @horizon_days
)

, hazard_raw AS (
    SELECT
        t.employee_type
      , s.day_since_hire
      , COALESCE(b.ended_or_censored, 0) AS ended_or_censored
      , COALESCE(b.events, 0) AS events
      , COALESCE(b.events_raw, 0) AS events_raw
      , t.n_total

      , COALESCE(
            SUM(COALESCE(b.ended_or_censored, 0)) OVER (
                PARTITION BY t.employee_type
                ORDER BY s.day_since_hire
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
          , 0
        ) AS ended_before

      , (t.n_total - COALESCE(
            SUM(COALESCE(b.ended_or_censored, 0)) OVER (
                PARTITION BY t.employee_type
                ORDER BY s.day_since_hire
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            )
          , 0
        )) AS at_risk

      , CASE
            WHEN (t.n_total - COALESCE(
                    SUM(COALESCE(b.ended_or_censored, 0)) OVER (
                        PARTITION BY t.employee_type
                        ORDER BY s.day_since_hire
                        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                    )
                  , 0
                )) <= 0 THEN NULL
            ELSE (COALESCE(b.events, 0) / (t.n_total - COALESCE(
                    SUM(COALESCE(b.ended_or_censored, 0)) OVER (
                        PARTITION BY t.employee_type
                        ORDER BY s.day_since_hire
                        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                    )
                  , 0
                )))
        END AS h
    FROM totals t
    JOIN seq s
    LEFT JOIN by_day b
      ON b.employee_type = t.employee_type
     AND b.day_since_hire = s.day_since_hire
)

-- ring neighborhood average excluding +/- core_days to avoid averaging the spike into itself
, neighbor_avg AS (
    SELECT
        a.employee_type
      , a.day_since_hire
      , a.ended_or_censored
      , a.events
      , a.events_raw
      , a.at_risk
      , a.h
      , AVG(b.h) AS h_neighbor_avg
      , COUNT(b.h) AS neighbor_cnt
    FROM hazard_raw a
    LEFT JOIN hazard_raw b
      ON b.employee_type = a.employee_type
     AND b.h IS NOT NULL
     AND b.day_since_hire BETWEEN (a.day_since_hire - @w_days) AND (a.day_since_hire + @w_days)
     AND ABS(b.day_since_hire - a.day_since_hire) > @core_days
    GROUP BY
        a.employee_type
      , a.day_since_hire
      , a.ended_or_censored
      , a.events
      , a.at_risk
      , a.h
)

, despiked AS (
    SELECT
        employee_type
      , day_since_hire
      , at_risk
      , events
      , events_raw
      , h AS hazard_raw
      , h_neighbor_avg
      , neighbor_cnt

      , CASE
            WHEN h IS NULL THEN NULL
            WHEN day_since_hire < @despike_start_day THEN h
            WHEN h_neighbor_avg IS NULL THEN h
            WHEN at_risk < @min_at_risk THEN h
            WHEN events_raw < @min_events THEN h
            WHEN (
                  h > (@spike_mult * h_neighbor_avg)
               OR (h - h_neighbor_avg) > @delta_min
                 )
              THEN h_neighbor_avg
            ELSE h
        END AS hazard_despiked
    FROM neighbor_avg
)

, surv AS (
    SELECT
        employee_type
      , day_since_hire
      , at_risk
      , events
      , events_raw
      , hazard_raw
      , hazard_despiked 
      , h_neighbor_avg
      , neighbor_cnt
      , CASE
            WHEN hazard_despiked IS NULL THEN NULL
            WHEN (1.0 - hazard_despiked) <= 0 THEN -1e9
            ELSE LN(1.0 - hazard_despiked)
        END AS ln_step
    FROM despiked
)

SELECT
    s.employee_type
  , s.day_since_hire
  , s.at_risk AS n_at_risk
--  , s.events
  , s.events_raw AS n_events
  , s.hazard_raw
  , s.hazard_despiked
  , CASE
        WHEN s.at_risk <= 0 THEN NULL
        ELSE EXP(
            SUM(s.ln_step) OVER (
                PARTITION BY s.employee_type
                ORDER BY s.day_since_hire
            )
        )
    END AS survival_raw
  , a.anw
FROM surv s
LEFT JOIN anw_by_day a
  ON a.employee_type = s.employee_type
 AND a.day_since_hire = s.day_since_hire
WHERE (s.employee_type = 'DPW' OR s.day_since_hire <= 500)
ORDER BY s.employee_type, s.day_since_hire
;

END//
