DELETE FROM tbl_ueb_fz_join
 WHERE persnr BETWEEN 99000001 AND 99000004
;

DELETE FROM tbl_ueb_buchungen_2
 WHERE persnr BETWEEN 99000001 AND 99000004
;

INSERT INTO tbl_ueb_fz_join (persnr, datum, pk_fz, pk_tp, pk_filedate, actual_shift_1, actual_shift_2, last_insert_update, last_calculated)
VALUES (99000001, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', 3, NULL, '2026-10-01 00:00:00', NULL)
     , (99000002, '2026-10-01', 'KE', 'Tag', '2026-10-01 00:00:00', 3, NULL, '2026-10-01 00:00:00', NULL)
     , (99000003, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', 2, 3, '2026-10-01 00:00:00', NULL)
     , (99000004, '2026-10-01', 'KE', 'PV', '2026-10-01 00:00:00', NULL, NULL, '2026-10-01 00:00:00', NULL)
;

INSERT INTO tbl_ueb_buchungen_2 (persnr, datum, schicht, tp, kommen, minuten, buchung_status, filedate)
VALUES (99000001, '2026-10-01', 3, 'PV', '2026-10-01 16:30:00', 480, '*', '2026-10-01 23:00:00')
     , (99000002, '2026-10-01', 3, 'Tag', '2026-10-01 16:30:00', 60, '*-', '2026-10-01 23:00:00')
     , (99000003, '2026-10-01', 2, 'PV', '2026-10-01 06:00:00', NULL, '*!', '2026-10-01 23:00:00')
     , (99000003, '2026-10-01', 3, 'PV', '2026-10-01 16:30:00', 480, '*', '2026-10-01 23:00:00')
;

CALL proc_ueb_fz_join();
CALL proc_ueb_fz_shift_reconciliation('2026-10-01', '2026-10-01');

DELETE FROM tbl_ueb_fz_join
 WHERE persnr BETWEEN 99000001 AND 99000004
;

DELETE FROM tbl_ueb_buchungen_2
 WHERE persnr BETWEEN 99000001 AND 99000004
;
