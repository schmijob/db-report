-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_onboarding_planung.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_onboarding_planung`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_onboarding_planung`()
SQL SECURITY DEFINER BEGIN
INSERT IGNORE INTO tbl_uebertrag_onboarding_planung (datum, kw, oe, taetigkeit, typ, onboarding_plan, consumed, rest, filedate)
SELECT datum, kw, oe, taetigkeit, typ, onboarding_plan, consumed, rest, last_insert_update AS filedate
FROM tbl_import_onboarding_planung;
END//
