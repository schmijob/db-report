-- Compatibility view: preserves the existing normalized current-personnel projection.
CREATE OR REPLACE VIEW `vp_personal_u` AS
SELECT p.`persnr` AS `persnr`
     , p.`name` AS `name`
     , p.`pdl` AS `pdl`
     , p.`oe` AS `oe`
     , p.`schichtgruppe` AS `schichtgruppe`
     , p.`eg` AS `eg`
     , p.`beginn` AS `beginn`
     , p.`ende` AS `ende`
     , p.`taetigkeit` AS `taetigkeit`
     , p.`team` AS `team`
     , p.`br` AS `br`
     , p.`übernahme` AS `uebernahme`
     , p.`last_insert_update` AS `last_insert_update`
     , p.`filedate` AS `filedate`
  FROM `tbl_ueb_personalakte` p;
