-- Managed by db-workbench; source of truth: db-report/procedures/proc_01_insert_tbl_datum.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_01_insert_tbl_datum`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_01_insert_tbl_datum`()
SQL SECURITY DEFINER BEGIN
call schreibe_log("proc_01_insert_tbl_datum", "Start", 0);
#	INSERT INTO tbl_datum 
#SELECT DATE_ADD(max(dt.datum),INTERVAL 1 DAY) AS datum , 
# if( WEEKDAY(DATE_ADD(max(dt.datum),INTERVAL 1 DAY)) IN (5,6),1,0) AS feiertag
#FROM tbl_datum AS dt;
call schreibe_log("proc_01_insert_tbl_datum", "Ende", 99);
END//
