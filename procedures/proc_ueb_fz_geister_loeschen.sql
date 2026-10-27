-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_fz_geister_loeschen.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_ueb_fz_geister_loeschen`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_fz_geister_loeschen`()
SQL SECURITY DEFINER BEGIN
-- SELECT * FROM tbl_ueb_personalakte p WHERE p.persnr = 52519
-- SELECT * FROM tbl_ueb_fz_buchungen p WHERE p.persnr = 52519
-- SELECT * FROM tbl_stamm_persnr p WHERE p.persnr = 52519
-- SELECT * FROM tbl_uebertrag_aenderungen_werte a WHERE a.feld = 'personalnummer'
-- SELECT p.persnr, p.last_insert_update, p.filedate, b.* 
DELETE p, b
FROM tbl_ueb_personalakte p
LEFT JOIN tbl_import_personalakte p2 ON p.persnr = p2.pers_nr
LEFT JOIN tbl_ueb_fz_buchungen b ON p.persnr = b.PersNr
WHERE p2.pers_nr IS NULL
AND b.Kommen IS NULL
AND p.filedate <= (SELECT MAX(filedate) FROM tbl_import_personalakte);
END//
