-- Managed by db-workbench; source of truth: db-report/procedures/schreibe_log.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `schreibe_log`//
CREATE DEFINER=CURRENT_USER PROCEDURE `schreibe_log`(IN `Param1` varchar(50), IN `Param2` varchar(50), IN `Param3` int(11))
SQL SECURITY DEFINER BEGIN
INSERT INTO tbl_check_procedurlauf
SELECT null,Param1,Param2,Param3,now();
END//
