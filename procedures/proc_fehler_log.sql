-- Managed by db-workbench; source of truth: db-report/procedures/proc_fehler_log.sql
-- The CURRENT_USER definer keeps local and PROD deployments portable.
DROP PROCEDURE IF EXISTS `proc_fehler_log`//
CREATE DEFINER=CURRENT_USER PROCEDURE `proc_fehler_log`(IN `p_run_id` char(36), IN `p_check_name` varchar(128), IN `p_severity` varchar(16), IN `p_msg` varchar(512), IN `p_src_table` varchar(128), IN `p_key_name` varchar(128), IN `p_key_value` varchar(512), IN `p_details` longtext, IN `p_n_rows` int(11))
SQL SECURITY DEFINER BEGIN
    /* ============================================================================
proc_fehler_log  (MariaDB)

ZWECK
- Universeller Logger für Datenqualitäts-/ETL-Checks.
- Verhindert Log-Spam: derselbe Fehler wird nicht jedes Mal neu eingefügt,
  sondern per UPSERT zusammengeführt und gezählt (cnt++).
- Das ist der zentrale Entry-Point: Checks rufen *nur* diese Proc auf.

VORAUSSETZUNGEN (Tabelle)
- tbl_check_fehlerprotokoll hat mindestens diese Spalten:
    run_id, check_name, severity, msg, src_table, key_name, key_value,
    details, n_rows, cnt, last_seen, created_at (created_at kann Default haben)

- Dedup/Upsert funktioniert nur mit UNIQUE KEY, z.B.:
    UNIQUE (check_name, severity, src_table, key_name, key_value, msg)

DUPLIKAT-DEFINITION (wichtig!)
- Zwei Fehler gelten als "gleich", wenn alle Spalten aus dem UNIQUE KEY gleich sind.
- run_id ist *nicht* Teil davon (damit über Läufe hinweg gezählt wird).
- Wenn du pro Umgebung trennen willst: env/host in Tabelle aufnehmen und in UNIQUE KEY.

CALL-PATTERN (best practice)
- Pro Check/Lauf idealerweise nur 1x callen (Aggregat-Fehler),
  nicht pro Zeile. key_value/details können eine Liste/Sample enthalten.
- p_details ist LONGTEXT; wenn möglich JSON_OBJECT(...) verwenden.

SEVERITY
- Akzeptiert 'INFO', 'WARN'/'WARNING', sonst 'ERROR'. Wird normalisiert.

UPSERT-LOGIK
- INSERT wenn neu.
- ON DUPLICATE:
    cnt++ (Häufigkeit)
    last_seen = NOW(6)
    run_id wird auf den letzten gesehenen Lauf gesetzt (nur wenn geliefert)
    n_rows wird aufsummiert (praktisch für "wie viele Rows betroffen")
    details wird nur überschrieben, wenn neue details geliefert werden
============================================================================ */
	 
	 DECLARE v_sev ENUM('INFO','WARN','ERROR');

    -- Severity normalisieren (alles Unbekannte => ERROR)
    SET v_sev = CASE UPPER(IFNULL(p_severity,''))
                  WHEN 'INFO'    THEN 'INFO'
                  WHEN 'WARN'    THEN 'WARN'
                  WHEN 'WARNING' THEN 'WARN'
                  ELSE 'ERROR'
                END;

    -- Hinweis: Dedup/Upsert wird über UNIQUE KEY in tbl_check_fehlerprotokoll gesteuert.
    INSERT INTO tbl_check_fehlerprotokoll
      ( run_id -- optional: Batch/Lauf-ID (UUID oder Timestamp-Token). '' => NULL
      , check_name -- eindeutiger Check-Name (z.B. 'missing_funktion_in_stamm')
      , severity -- 'INFO'|'WARN'|'WARNING'|'ERROR' (alles andere => ERROR)
      , msg -- kurze, dedup-relevante Fehlermeldung (Teil vom UNIQUE KEY!)
      , src_table -- optionale Quelle (Import-/Staging-Tabelle)
      , key_name -- z.B. 'funktion' oder 'datum,schicht'
      , key_value -- z.B. 'GW Anlagenfahrer' oder kommagetrennte Liste (max 512)
      , details -- optional: JSON/Text (mehr Kontext, Sample, Counts, Zeitfenster)
      , n_rows -- optional: betroffene Row-Anzahl (wird bei Dups aufsummiert)
      , cnt -- Häufigkeit hochzählen statt neue Zeile
      , last_seen -- "zuletzt gesehen" aktualisieren
      )
    VALUES( NULLIF(p_run_id,'')
          , p_check_name
          , v_sev
          , p_msg
          , NULLIF(p_src_table,'')
          , NULLIF(p_key_name,'')
          , NULLIF(p_key_value,'')
          , p_details
          , p_n_rows
          , 1
          , NOW(6)
          )
    ON DUPLICATE KEY UPDATE
          cnt       = cnt + 1
        , last_seen = NOW(6)
        -- Lauf-ID auf den letzten Lauf setzen, aber nur wenn geliefert
        , run_id    = COALESCE(VALUES(run_id), run_id)
        -- betroffene Zeilen aufsummieren (NULL-sicher)
        , n_rows    = COALESCE(n_rows,0) + COALESCE(VALUES(n_rows),0)
        -- details nur überschreiben, wenn neue details geliefert werden
        , details   = COALESCE(VALUES(details), details);
END//
