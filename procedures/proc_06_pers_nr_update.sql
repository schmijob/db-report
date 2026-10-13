-- Managed by db-workbench; source of truth: db-report/procedures/proc_06_pers_nr_update.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_06_pers_nr_update`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_06_pers_nr_update`()
SQL SECURITY DEFINER BEGIN
    -- Update tbl_uebertrag_fehlzeiten
    UPDATE tbl_uebertrag_fehlzeiten AS u
    LEFT JOIN tbl_import_personalnummern_update AS i
    ON u.personalnummer = i.pers_nr_alt
    SET u.personalnummer = i.pers_nr_neu
    WHERE i.pers_nr_alt IS NOT NULL;

    -- Update tbl_uebertrag_buchungen_mitarbeiter
    UPDATE tbl_uebertrag_buchungen_mitarbeiter AS u
    LEFT JOIN tbl_import_personalnummern_update AS i
    ON u.pers_nr = i.pers_nr_alt
    SET u.pers_nr = i.pers_nr_neu
    WHERE i.pers_nr_alt IS NOT NULL;
END//
