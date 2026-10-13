DELETE FROM tbl_ueb_fz_join
 WHERE persnr BETWEEN 99000001 AND 99000004
;

INSERT INTO tbl_ueb_fz_join (persnr, datum, pk_fz, pk_tp, pk_filedate, actual_shift_1, actual_shift_2, last_insert_update, last_calculated)
VALUES (99000001, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', 3, NULL, '2026-10-01 00:00:00', NULL)
     , (99000002, '2026-10-01', 'KE', 'Tag', '2026-10-01 00:00:00', 3, NULL, '2026-10-01 00:00:00', NULL)
     , (99000003, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', 2, 3, '2026-10-01 00:00:00', NULL)
     , (99000004, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', NULL, NULL, '2026-10-01 00:00:00', NULL)
;

CALL proc_ueb_fz_join();

SELECT persnr
     , expected_mask
     , actual_shift_1
     , actual_shift_2
     , matched_expected_1
     , matched_expected_2
     , remaining_expected_mask
     , shift_mismatch_1
     , shift_mismatch_2
  FROM tbl_ueb_fz_join
 WHERE persnr BETWEEN 99000001 AND 99000004
 ORDER BY persnr
;

DELETE FROM tbl_ueb_fz_join
 WHERE persnr BETWEEN 99000001 AND 99000004
;
