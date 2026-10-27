-- Managed by db-workbench; source of truth: db-report/procedures/proc_ueb_personalakte_scd_snapshot_sync.sql
-- Store only snapshot state changes; unchanged daily imports extend no rows.
DROP PROCEDURE IF EXISTS `proc_ueb_personalakte_scd_snapshot_sync`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_ueb_personalakte_scd_snapshot_sync`(IN p_gueltig_von DATE)
SQL SECURITY DEFINER BEGIN
    IF p_gueltig_von IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Personalakte snapshot history requires a snapshot date';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM tbl_ueb_personalakte_scd_snapshot s
         WHERE s.gueltig_bis = '9999-12-31'
           AND s.gueltig_von > p_gueltig_von
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Personalakte snapshots must be replayed oldest to newest';
    END IF;

    -- Close source-number histories when that PersNr is absent from this
    -- processed snapshot. Reconciliation can then combine old and new numbers
    -- into one canonical history without overlapping source intervals.
    UPDATE tbl_ueb_personalakte_scd_snapshot s
    LEFT JOIN tmp_personalakte_import i
      ON i.pers_nr = s.persnr
     AND i.ende_besch IS NOT NULL
     AND i.ende_besch <> '2022-07-31'
     AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
       SET s.gueltig_bis = DATE_SUB(p_gueltig_von, INTERVAL 1 DAY)
     WHERE s.gueltig_bis = '9999-12-31'
       AND s.gueltig_von < p_gueltig_von
       AND i.pers_nr IS NULL;

    UPDATE tbl_ueb_personalakte_scd_snapshot s
    JOIN tbl_ueb_personalakte c
      ON c.persnr = s.persnr
     AND DATE(c.filedate) = p_gueltig_von
    JOIN tmp_personalakte_import i
      ON i.pers_nr = c.persnr
     AND i.ende_besch IS NOT NULL
     AND i.ende_besch <> '2022-07-31'
     AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
       SET s.gueltig_bis = DATE_SUB(p_gueltig_von, INTERVAL 1 DAY)
     WHERE s.gueltig_bis = '9999-12-31'
       AND s.gueltig_von < p_gueltig_von
       AND NOT (
              s.`name`        <=> c.`name`
          AND s.pdl           <=> c.pdl
          AND s.oe            <=> c.oe
          AND s.schichtgruppe <=> c.schichtgruppe
          AND s.eg            <=> c.eg
          AND s.beginn        <=> c.beginn
          AND s.ende          <=> c.ende
          AND s.taetigkeit    <=> c.taetigkeit
          AND s.team          <=> c.team
          AND s.br            <=> c.br
          AND s.übernahme     <=> c.übernahme
          AND s.taetigkeit2   <=> c.taetigkeit2
          AND s.funktion      <=> c.funktion
       );

    UPDATE tbl_ueb_personalakte_scd_snapshot s
    JOIN tbl_ueb_personalakte c
      ON c.persnr = s.persnr
     AND DATE(c.filedate) = p_gueltig_von
    JOIN tmp_personalakte_import i
      ON i.pers_nr = c.persnr
     AND i.ende_besch IS NOT NULL
     AND i.ende_besch <> '2022-07-31'
     AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
     AND s.gueltig_von = p_gueltig_von
       SET s.`name` = c.`name`
         , s.pdl = c.pdl
         , s.oe = c.oe
         , s.schichtgruppe = c.schichtgruppe
         , s.eg = c.eg
         , s.beginn = c.beginn
         , s.ende = c.ende
         , s.taetigkeit = c.taetigkeit
         , s.team = c.team
         , s.br = c.br
         , s.übernahme = c.übernahme
         , s.taetigkeit2 = c.taetigkeit2
         , s.funktion = c.funktion
         , s.last_insert_update = c.last_insert_update
         , s.filedate = c.filedate
         , s.gueltig_bis = '9999-12-31';

    INSERT INTO tbl_ueb_personalakte_scd_snapshot (
          persnr, `name`, pdl, oe, schichtgruppe, eg, beginn, ende
        , taetigkeit, team, br, übernahme, taetigkeit2, funktion
        , last_insert_update, filedate, gueltig_von, gueltig_bis
    )
    SELECT c.persnr, c.`name`, c.pdl, c.oe, c.schichtgruppe, c.eg, c.beginn, c.ende
         , c.taetigkeit, c.team, c.br, c.übernahme, c.taetigkeit2, c.funktion
         , c.last_insert_update, c.filedate, p_gueltig_von, '9999-12-31'
      FROM tbl_ueb_personalakte c
      JOIN tmp_personalakte_import i
        ON i.pers_nr = c.persnr
       AND i.ende_besch IS NOT NULL
       AND i.ende_besch <> '2022-07-31'
       AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
     WHERE DATE(c.filedate) = p_gueltig_von
       AND NOT EXISTS (
            SELECT 1
              FROM tbl_ueb_personalakte_scd_snapshot s
             WHERE s.persnr = c.persnr
               AND s.gueltig_bis = '9999-12-31'
       );

    UPDATE tbl_ueb_personalakte_scd_snapshot s
    JOIN tbl_ueb_personalakte c
      ON c.persnr = s.persnr
     AND DATE(c.filedate) = p_gueltig_von
    JOIN tmp_personalakte_import i
      ON i.pers_nr = c.persnr
     AND i.ende_besch IS NOT NULL
     AND i.ende_besch <> '2022-07-31'
     AND i.beginn_besch BETWEEN '2000-01-01' AND '9999-12-31'
       SET s.last_insert_update = c.last_insert_update
         , s.filedate = c.filedate
     WHERE s.gueltig_bis = '9999-12-31'
       AND s.`name`        <=> c.`name`
       AND s.pdl           <=> c.pdl
       AND s.oe            <=> c.oe
       AND s.schichtgruppe <=> c.schichtgruppe
       AND s.eg            <=> c.eg
       AND s.beginn        <=> c.beginn
       AND s.ende          <=> c.ende
       AND s.taetigkeit    <=> c.taetigkeit
       AND s.team          <=> c.team
       AND s.br            <=> c.br
       AND s.übernahme     <=> c.übernahme
       AND s.taetigkeit2   <=> c.taetigkeit2
       AND s.funktion      <=> c.funktion;
END//
