-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_personalakte_scd_sync.sql
-- Append a compact snapshot state, then reconcile effective-dated changes.
DROP PROCEDURE IF EXISTS `proc_ueb_personalakte_scd_sync`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_personalakte_scd_sync`(IN p_gueltig_von DATE)
SQL SECURITY DEFINER BEGIN
    CALL proc_ueb_personalakte_scd_snapshot_sync(p_gueltig_von);

    IF COALESCE(@personalakte_scd_backfill, 0) = 0 THEN
        CALL proc_ueb_personalakte_scd_reconcile();
    END IF;
END//
