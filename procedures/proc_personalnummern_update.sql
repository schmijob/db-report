-- Managed by db-workbench; source of truth: db-report/procedures/proc_personalnummern_update.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_personalnummern_update`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_personalnummern_update`()
SQL SECURITY DEFINER BEGIN
UPDATE tbl_uebertrag_fehlzeiten fz
JOIN tbl_uebertrag_aenderungen ae 
    ON fz.personalnummer = ae.wert
SET fz.personalnummer = CAST(SUBSTRING(ae.geaendert_fuer, 2, LOCATE(']', ae.geaendert_fuer) - 2) AS UNSIGNED)
WHERE ae.feld = 'personalnummer' 
    AND fz.personalnummer BETWEEN 115 AND 500
    AND ae.wert BETWEEN 115 AND 500;
END//
