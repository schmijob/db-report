-- Managed by db-workbench; source of truth: db-report/procedures/proc_uebertrag_fluktuation_person.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_uebertrag_fluktuation_person`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_uebertrag_fluktuation_person`()
SQL SECURITY DEFINER BEGIN

SET @asof_date := CURDATE();
SET @U := 120;
SET @tail_cut := 500;

DELETE FROM tbl_ueb_fluktuation_person;
INSERT INTO tbl_ueb_fluktuation_person (persnr, datum, employee_type, start_date, end_date, u_days, tenure_days, hazard_base, F_u, hazard_runtime, expected_alive)
    
WITH
-- latest end-date up to asof
end_ranked AS (
    SELECT
        a.persnr,
        STR_TO_DATE(NULLIF(TRIM(a.wert), ''), '%d.%m.%Y') AS end_value,
        ROW_NUMBER() OVER (
            PARTITION BY a.persnr
            ORDER BY a.aenderungsdatum DESC
        ) AS rn
    FROM tbl_uebertrag_aenderungen_werte a
    WHERE a.feld = 'ende beschäftigung'
      AND a.beschreibung NOT LIKE '(Gelöscht)%'
      AND a.aenderungsdatum < DATE_ADD(@asof_date, INTERVAL 1 DAY)
      AND @asof_date BETWEEN gueltig_von AND gueltig_bis
),

emp_raw AS (
    SELECT
        p.persnr,
        CASE WHEN p.eg = 'ZAK' THEN 'ZAK' ELSE 'DPW' END AS employee_type,
        p.beginn AS start_date,
        NULLIF(p.ende, DATE('9999-12-31')) AS end_final
    FROM vp_personal_u p
    WHERE p.beginn IS NOT NULL
      AND p.beginn <= @asof_date
      AND EXISTS (
            SELECT 1
            FROM tbl_stamm_kategorie_abteilung k
            WHERE k.`tätigkeit` = p.taetigkeit
              AND k.kategorie = 'Operativ'
      )
)

, emp AS (
    SELECT
        e.persnr,
        e.employee_type,
        e.start_date,
        CASE
            WHEN r.rn = 1 AND e.end_final IS NOT NULL
                THEN LEAST(r.end_value, e.end_final)
            WHEN r.rn = 1 THEN r.end_value
            ELSE e.end_final
        END AS end_date
    FROM emp_raw e
    LEFT JOIN end_ranked r
      ON r.persnr = e.persnr
     AND r.rn = 1
    WHERE
        (
            CASE
                WHEN r.rn = 1 AND e.end_final IS NOT NULL
                    THEN LEAST(r.end_value, e.end_final)
                WHEN r.rn = 1 THEN r.end_value
                ELSE e.end_final
            END
        ) IS NULL
        OR
        (
            CASE
                WHEN r.rn = 1 AND e.end_final IS NOT NULL
                    THEN LEAST(r.end_value, e.end_final)
                WHEN r.rn = 1 THEN r.end_value
                ELSE e.end_final
            END
        ) >= @asof_date
)

, planned_days AS (
    SELECT DISTINCT
        b.persnr,
        b.datum
    FROM vp_buchungen b
    WHERE b.datum BETWEEN @asof_date
                      AND @asof_date + INTERVAL @U DAY
)

, person_days AS (
    SELECT
        pd.persnr,
        pd.datum,
        e.employee_type,
        e.start_date,
        e.end_date,
        DATEDIFF(pd.datum, @asof_date) AS u,
        DATEDIFF(pd.datum, e.start_date) AS tenure_days
    FROM planned_days pd
    JOIN emp e
      ON e.persnr = pd.persnr
)

, cohort_u AS (
    SELECT DISTINCT
        employee_type,
        start_date,
        u,
        tenure_days
    FROM person_days
)

, tail AS (
    SELECT
        employee_type,
        AVG(hazard_despiked) AS h_tail
    FROM tbl_ueb_fluktuationskurve
    WHERE day_since_hire BETWEEN 500 AND 999
      AND hazard_despiked IS NOT NULL
    GROUP BY employee_type
)

, cohort_hazard AS (
    SELECT
        c.*,
        COALESCE(hc.hazard_despiked, t.h_tail) AS hazard_base,
        f.F_u_smooth,
        COALESCE(hc.hazard_despiked, t.h_tail) * f.F_u_smooth AS hazard_runtime
    FROM cohort_u c
    LEFT JOIN tbl_ueb_fluktuationskurve hc
      ON hc.employee_type = c.employee_type
     AND hc.day_since_hire = c.tenure_days
    LEFT JOIN tail t
      ON t.employee_type = c.employee_type
    LEFT JOIN tbl_ueb_fluktuation_vorlaufzeit f
      ON f.employee_type = c.employee_type
     AND f.u_days = c.u
)

, cohort_survival AS (
    SELECT
        *,
        EXP(
            COALESCE(
                SUM(
                    CASE
                        WHEN hazard_runtime >= 1.0 THEN -1e9
                        ELSE LN(GREATEST(1e-12, 1 - hazard_runtime))
                    END
                ) OVER (
                    PARTITION BY employee_type, start_date
                    ORDER BY u
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                )
            , 0)
        ) AS surv_cond_from_asof
    FROM cohort_hazard
)

SELECT
    p.persnr,
    p.datum,
    p.employee_type,
    p.start_date,
    p.end_date,
    p.u AS u_days,
    p.tenure_days,
    s.hazard_base,
    s.F_u_smooth,
    s.hazard_runtime,
    CASE
        WHEN p.end_date IS NOT NULL AND p.datum > p.end_date THEN 0.0
        ELSE s.surv_cond_from_asof
    END AS expected_alive
FROM person_days p
JOIN cohort_survival s
  ON s.employee_type = p.employee_type
 AND s.start_date = p.start_date
 AND s.u = p.u;

END//
