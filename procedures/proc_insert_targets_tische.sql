-- Managed by db-workbench; source of truth: db-report/procedures/proc_insert_targets_tische.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_insert_targets_tische`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_insert_targets_tische`(IN `p_gueltig` date)
SQL SECURITY DEFINER BEGIN

  /*──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                       Import entpivotieren und neue Targets einfügen                              │
  └──────────────────────────────────────────────────────────────────────────────────────────────────*/

    INSERT INTO tbl_targets_tische(auftragstyp_id, tischtyp_id, auftragstyp, tischtyp, target, gueltig)
    WITH src AS (
        SELECT CASE WHEN i.spalte1 = 'BEST FIT' THEN NULL
                    ELSE CONCAT('K', UPPER(i.spalte1))
               END AS tischtyp
             , i.`03t`
             , i.`08t`
             , i.`99t`
             , i.`03p`
             , i.`99p`
             , i.plp
             , i.plpk
          FROM tbl_import_targets_tische i
    )

    , unpvt AS (
        SELECT COALESCE(tischtyp, 'K03T') AS tischtyp
             , 'K03T'                     AS auftragstyp
             , `03t`                      AS target
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'K08T')
             , 'K08T'
             , `08t`
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'K99T')
             , 'K99T'
             , `99t`
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'K03P')
             , 'K03P'
             , `03p`
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'K99P')
             , 'K99P'
             , `99p`
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'PLP')
             , 'PLP'
             , plp
          FROM src

        UNION ALL

        SELECT COALESCE(tischtyp, 'PLPK')
             , 'PLPK'
             , plpk
          FROM src
    )

    SELECT at.auftragstyp_id
         , tt.auftragstyp_id
         , u.auftragstyp
         , u.tischtyp
         , u.target
         , p_gueltig
      FROM unpvt u
      JOIN tbl_stamm_tische at ON at.auftragstyp = u.auftragstyp
      JOIN tbl_stamm_tische tt ON tt.auftragstyp = u.tischtyp
     WHERE u.target IS NOT NULL
       AND NOT EXISTS ( SELECT 1
			                 FROM tbl_targets_tische t
			                WHERE t.auftragstyp_id = at.auftragstyp_id
			                  AND t.tischtyp_id    = tt.auftragstyp_id
			                  AND t.gueltig_bis    = DATE '9999-12-31'
			                  AND t.target         = u.target
                      )
    ;

  /*──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                     gueltig_bis aktualisieren                                     │
  └──────────────────────────────────────────────────────────────────────────────────────────────────*/

    UPDATE tbl_targets_tische t
       SET t.gueltig_bis = COALESCE( ( SELECT MIN(t2.gueltig) - INTERVAL 1 DAY
                                         FROM tbl_targets_tische t2
                                        WHERE t2.auftragstyp_id = t.auftragstyp_id
                                          AND t2.tischtyp_id    = t.tischtyp_id
                                          AND t2.gueltig        > t.gueltig )
                                   , DATE '9999-12-31' )
    ;

  /*──────────────────────────────────────────────────────────────────────────────────────────────────┐
  │                                   Targets in perfor_hdr updaten                                   │
  └──────────────────────────────────────────────────────────────────────────────────────────────────*/

	UPDATE tbl_perfor_hdr p
	  JOIN tbl_stamm_apid a ON a.apid = p.apid
	  JOIN tbl_targets_tische t ON t.Auftragstyp_ID = p.auftragstyp
	                           AND t.Tischtyp       = a.Arbeitsplatztyp
	                           AND p.datum BETWEEN t.gueltig AND t.gueltig_bis
	   SET p.target = t.target
	 WHERE p.datum >= p_gueltig
	;

END//
