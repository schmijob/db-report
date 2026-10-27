-- Compatibility view: current one-row-per-person semantics for external users.
CREATE OR REPLACE VIEW `tbl_ueb_personalakte` AS
SELECT `persnr`, `name`, `pdl`, `oe`, `schichtgruppe`, `eg`, `beginn`, `ende`
     , `taetigkeit`, `team`, `br`, `übernahme`, `taetigkeit2`, `funktion`
     , `last_insert_update`, `filedate`
  FROM `tbl_ueb_personalakte_current`;
