# Data model

This is the user-facing reference for understanding the database before querying it.

## Data trust

- **PROD** is the current source and is accessed read-only through the configured credential.
- **LOCAL** is a sanitized snapshot for analysis and development. It may omit data, transform sensitive fields, or lag behind PROD.
- **HYBRID** routes an operation between PROD and LOCAL. Use it only when the intended source and target are clear.

## How to read the model

For each domain area, document and read:

1. the business grain of each table or view;
2. primary keys and stable identifiers;
3. relationships and approved join paths;
4. date, status, and freshness fields;
5. sensitive or transformed fields; and
6. the authoritative source and known snapshot limitations.

Versioned SQL defines the database structure. This directory explains its meaning, relationships, and safe usage. Update both when a SQL change alters the model or the way analysts should query it.

# Database Architecture Map

## Purpose

This database contains several adjacent but distinct operational domains in one MariaDB schema. Do not infer domain ownership purely from naming: some personnel tables are shared inputs to other domains.

The main domains are:

1. **Personalplanung** - personnel master data, bookings, absences, staffing requirements, personnel planning and forecasts.
2. **Performance** - operational performance, HDR/KHDR/OEE, targets, NIO and Andon.
3. **CAPS** - skills, training and capability data.
4. **Nettoanwesenheit / Abrechnung** - net attendance, working-time accounting, allocation and charge rates.
5. **Shared / reference / infrastructure** - calendar, shifts, mappings, logs and common personnel inputs.

MariaDB version: **10.11.18**.

---

# 1. Naming Conventions

The table prefixes generally describe pipeline stage rather than business domain.

| Prefix | Meaning |
|---|---|
| `tbl_import_*` | Raw/current imported source data |
| `tbl_uebertrag_*` | Persisted/history/transfer layer |
| `tbl_ueb_*` | Further transformed/materialized working or analytical layer |
| `tbl_stamm_*`, `tbl_konfiguration_*` | Reference/master/mapping data |
| `tbl_perfor_*` | Performance-domain result tables |
| `tbl_targets_*` | Performance targets |
| `view_*` | Reporting/analytical view |
| `vp_*_i` | Usually normalized view over an import layer |
| `vp_*_u` | Usually normalized view over a transfer/derived layer |
| `proc_uebertrag_*` | Import -> persistent/history transformation |
| `proc_ueb_*` | Downstream transformation/materialization |
| `proc_00_*` | Orchestration |

There are few useful declarative foreign keys. Stored procedures and views are therefore the real architecture.

Trace dependencies through routine and view definitions rather than relying on FK metadata.

---

# 2. Shared Foundation

These objects occur across domains and should not automatically be classified as belonging to whichever procedure references them.

## Calendar / Shift

- `tbl_datum`
- `tbl_schichten`
- `tbl_wochentag`

`tbl_datum` is the central calendar/date dimension. Filter `tbl_datum.arbeitstag = 1` for workdays excluding holidays; Saturday shifts exist but are excluded from the forecast model.
`tbl_schichten` uses `tbl_datum.schichtindex` to map the shift cycle (Nacht, Früh, Spät) to the week and Shift group (A, B, C). Sometimes it is used with `Index <= 3` to translate the different forms (e.g. Nacht = 1N = 1). Internally, store `Schicht_int` and `Schichtgr_int`; display `Schichtgruppe` / `Schicht`

## Personnel / Organizational Reference

- `tbl_import_personalakte`
- `tbl_uebertrag_personalakte` # depreceated
- `tbl_ueb_personalakte`
- `tbl_stamm_OE_translate`
- `tbl_stamm_taetigkeit_translate`
- `tbl_stamm_kategorie_abteilung`
- `tbl_stamm_persnr`

The important personnel chain is:

```text
tbl_import_personalakte
        |
        v
proc_uebertrag_personalakte
        |
        v
tbl_ueb_personalakte
        |
        +-> vp_personal_u
        +-> Personalplanung
        +-> Nettoanwesenheit
        +-> CAPS
        +-> assorted reporting
```

`vp_personal_u` is one of the most important shared dimensions in the schema.

## Logging / Infrastructure

- `tbl_check_procedurlauf`
- `tbl_check_fehlerprotokoll`
- `tbl_check_etl_log`
- `schreibe_log`
- `proc_fehler_log`

These are infrastructure, not business-domain tables.

---

# 3. Personalplanung

Personalplanung is the most interconnected domain.

Conceptually:

```text
                     IMPORTS
                        |
       +----------------+----------------+
       |                |                |
       v                v                v
 personalakte       buchungen       aenderungen
       |                |                |
       v                v                v
 personnel          normalized       personnel /
 dimension           shifts          absence changes
       |                |                |
       +--------+-------+--------+-------+
                |                |
                v                v
         daily personnel / attendance
                |
                v
           FZ forecast
                |
                v
        Personalplanung output
```

## 3.1 Main Orchestrator

`proc_00_personalplanung` is the practical orchestration entry point.

Due to siloed editing rights of procedures between devs, it coordinates not just personalplanung but everything owned by this user.

Important calls include:

```text
proc_00_personalplanung
|
+-> proc_uebertrag_aenderungen
+-> proc_uebertrag_buchungen
+-> proc_uebertrag_fanf
+-> proc_uebertrag_fluktuationskurve
+-> proc_uebertrag_fluktuation_person
+-> proc_uebertrag_personalakte
+-> proc_uebertrag_urlaubsvorschau_js
+-> proc_ueb_fz_buchungen
+-> proc_ueb_fz_forecast
+-> proc_ueb_fz_forecast_persfaktor
+-> proc_ueb_peko
+-> logging
```

Do not assume execution order from this list. Inspect the procedure before changing pipeline sequencing.

---

# 4. Personal Master-Data Pipeline

Primary source:

```text
tbl_import_personalakte
```

Transformation:

```text
proc_uebertrag_personalakte
```

Important dependencies:

```text
tbl_import_personalakte
tbl_stamm_OE_translate
tbl_stamm_persnr
tbl_stamm_taetigkeit_translate
tbl_uebertrag_aenderungen
tbl_uebertrag_aenderungen_beginn_ende
        |
        v
tbl_ueb_personalakte
```

Common access view:

```text
vp_personal_u
    |
    +-> tbl_ueb_personalakte
```
Mapping taetigkeit to categories:
`tbl_stamm_kategorie_abteilung`


When investigating a person's classification, shift, activity status or organizational assignment, start here.
There are two taetigkeit columns (taetigkeit/taetigkeit2). This is the result of an incomplete cutover in the source: taetigkeit is a free text field and can contain typos, taetigkeit2 uses an enum but is only partially filled and can disagree. The model currently uses taetigkeit.

---

# 5. Change-History / Personnel-Change Pipeline

Source:

```text
tbl_import_aenderungen
```

Primary procedure:

```text
proc_uebertrag_aenderungen
```

Main persistent tables:

```text
tbl_uebertrag_aenderungen
tbl_uebertrag_aenderungen_werte
tbl_uebertrag_aenderungen_fehlzeiten
tbl_uebertrag_aenderungen_beginn_ende
```

Derived calendar:

```text
tbl_ueb_aend_fz_kalender
```

The high-level pipeline is:

```text
tbl_import_aenderungen
        |
        v
proc_uebertrag_aenderungen
        |
        +-> tbl_uebertrag_aenderungen
        +-> tbl_uebertrag_aenderungen_werte
        +-> tbl_uebertrag_aenderungen_fehlzeiten
        |
        v
tbl_ueb_aend_fz_kalender
        |
        +-> attendance/FZ processing
        +-> forecast
        +-> reporting views
```

`tbl_uebertrag_aenderungen` is a major cross-domain history source.

It contains effective-dated changes such as shift, team, activity, employment start/end, absences and Tagesplan changes.
`tbl_uebertrag_aenderungen_werte` extracts master data; `tbl_uebertrag_aenderungen_fehlzeiten` extracts attendance data.

`tbl_ueb_aend_fz_kalender` converts effective-dated absence/change periods into date-granular records.

The import occurs every half-hour and serves as an incremental update for the other pipelines.
---

# 6. Booking / Attendance Pipeline

Raw source:

```text
tbl_import_buchungen_mitarbeiter
```

Historical transfer:

```text
tbl_import_buchungen_mitarbeiter
        |
        v
proc_uebertrag_buchungen
        |
        v
tbl_uebertrag_buchungen_mitarbeiter
```

Further normalization:

```text
tbl_uebertrag_buchungen_mitarbeiter
        |
        v
proc_uebertrag_buchungen
        |
        +-> tbl_ueb_buchungen
        +-> tbl_ueb_buchungen_2
```

Relevant views include:

```text
view_buchungen_kommen (legacy)
view_buchungen_kommen_all (legacy)
vp_buchungen = tbl_ueb_fz_buchungen
vp_buchungen_u = tbl_ueb_buchungen
```

The FZ processing stage is:

```text
tbl_ueb_buchungen
        |
        +-> personnel master
        +-> absence/change calendar
        +-> personnel calendar
        |
        v
proc_ueb_fz_buchungen
        |
        v
tbl_ueb_fz_buchungen
```

For questions about actual personnel attendance, `vp_buchungen` is the more useful starting point than the raw booking import.

---

# 7. Absence / Fehlzeit Semantics

Central dictionaries:

```text
tbl_abwesenheitsgrund
tbl_abwesenheitsgrund_translate
```

These translate source absence and Tagesplan codes into normalized concepts such as:

- attendance/absence category
- sickness
- LFZ status (1 = paid)
- shift (schicht)
- planned start time (sollzeit)
- short code (kuerzel)

The mapping distinguishes at least:

```text
Fehlzeit
Tagesplan
```

Do not interpret raw source codes without checking these tables.

Source data has multiple variants of the same code under different zeus_id. tbl_abwesenheitsgrund_translate maps these IDs to their codes. tbl_abwesenheitsgrund is the basic code dictionary. Different consumers use different definistions of absence, e.g. counting `GLZ` to Urlaub or sonstige.

Historical absence data also exists in:

```text
tbl_import_fehlzeiten
        |
        v
tbl_uebertrag_fehlzeiten
```

Useful views include:

```text
vp_fehlzeiten_i
vp_fehlzeiten_u
view_fehlzeiten_detail
view_fehlzeit_query
view_aenderungen_fehlzeiten
```

---

# 8. Urlaub / Personnel Calendar

Relevant sources:

```text
tbl_import_urlaubsvorschau
tbl_import_personalkalender
```

Persistent/derived:

```text
tbl_uebertrag_urlaubsvorschau
tbl_ueb_fz_personalkalender
```

Current custom procedure:

```text
proc_uebertrag_urlaubsvorschau_js
```

Pipeline:

```text
tbl_import_personalkalender
        |
        v
proc_uebertrag_urlaubsvorschau_js
        |
        +-> tbl_uebertrag_urlaubsvorschau
        +-> tbl_ueb_fz_personalkalender
        +-> tbl_ueb_fz_join
```

The older `tbl_import_urlaubsvorschau` and `proc_uebertrag_urlaubsvorschau` is superseded for this workflow. Personalkalender contains both historical Fehlzeiten and future Urlaubsvorschau and separates Fehlzeit and Tagesplan into different columns (which previously had to be inferred from the code). Fehlzeiten and Urlaubsvorschau are legacy pipelines for downstream consumers, newer consumers use the combined Personalkalender.

---

# 9. FANF / Staffing Requirements

FANF represents staffing/function requirements and feeds personnel planning.

Sources:

```text
tbl_import_fanf
tbl_import_fanf_pdf
tbl_import_fanf_frueh / spaet / nacht (depreceated)
```

Primary normalization:

```text
vp_fanf_i
```

Main pipelines:

```text
tbl_import_fanf
     |
     v
proc_uebertrag_fanf3
     |
     +-> tbl_uebertrag_fanf
     +-> tbl_uebertrag_fanf_funktion
     +-> tbl_uebertrag_fanf_changelog

tbl_import_fanf_pdf
     |
     v
proc_uebertrag_fanf_pdf
     |
     v
tbl_uebertrag_fanf_pdf
     |
     v
tbl_uebertrag_fanf_pdf_parsed
     |
     +-> tbl_uebertrag_fanf
     +-> tbl_uebertrag_fanf_funktion
     +-> tbl_uebertrag_fanf_changelog
```

The FANF procedure family includes:

```text
proc_uebertrag_fanf (superseded)
proc_uebertrag_fanf2 (superseded)
proc_uebertrag_fanf3 
proc_uebertrag_fanf_pdf 
```

The fanf_anwesenheit family represents attendance captured manually by supervisors and is used for reconciliation, but is not the main source of the data model.


`tbl_stamm_funktionen` is the principal function reference table.

---

# 10. Forecast / Personalplanung Output

Main forecast procedure:

```text
proc_ueb_fz_forecast
```

Important inputs:

```text
tbl_abwesenheitsgrund
tbl_datum
tbl_import_aenderungen
tbl_schichten
tbl_stamm_kategorie_abteilung
tbl_uebertrag_fanf
tbl_ueb_aend_fz_kalender
tbl_ueb_fz_buchungen
tbl_ueb_personalakte
```

Intermediate tables:

```text
tbl_ueb_fz_saisonalitaet_schicht
tbl_ueb_fz_saisonalitaet_woche
tbl_ueb_fluktuation_person
```

Output:

```text
tbl_ueb_fz_forecast
```

Final personnel-planning aggregation:

```text
proc_ueb_fz_personalplanung
```

Conceptually:

```text
tbl_uebertrag_fanf -----------+
tbl_ueb_fz_buchungen ---------+
tbl_ueb_fz_forecast ----------+
tbl_ueb_personalakte ---------+--> proc_ueb_fz_personalplanung
tbl_ueb_fluktuation_person ---+             |
tbl_ueb_fz_persfaktor --------+             v
                                  tbl_ueb_fz_personalplanung
```

High-level flow:

```text
PERSONNEL -----------+
BOOKINGS ------------+
ABSENCES / CHANGES --+
FANF REQUIREMENTS ---+--> FORECAST --> PERSONALPLANUNG
SEASONALITY ---------+
FLUCTUATION ---------+
```

---

# 11. Fluctuation

Objects:

```text
tbl_ueb_fluktuationskurve
tbl_ueb_fluktuation_person
tbl_ueb_fluktuation_vorlaufzeit
```

Procedures:

```text
proc_uebertrag_fluktuationskurve
proc_uebertrag_fluktuation_person
```

Conceptually:

```text
vp_buchungen -----+
vp_personal_u -----+
                   |
                   v
proc_uebertrag_fluktuationskurve
                   |
                   v
tbl_ueb_fluktuationskurve
                   |
                   +-------------------+
                                       |
tbl_uebertrag_aenderungen -------------+
                                       |
                                       v
                     proc_uebertrag_fluktuation_person
                                       |
                                       v
                          tbl_ueb_fluktuation_person
```

`tbl_ueb_fluktuation_person` can be treated as derived/rebuildable rather than a source of truth.

---

# 12. PEKO / Onboarding

Onboarding:

```text
tbl_import_onboarding_planung
        |
        v
proc_ueb_onboarding_planung
        |
        v
tbl_uebertrag_onboarding_planung
```

PEKO:

```text
onboarding -----------+
personnel ------------+
changes --------------+
FANF -----------------+--> proc_ueb_peko
FZ bookings ----------+         |
                                +-> tbl_ueb_peko
                                +-> tbl_ueb_peko_archiv
```
PEKO is just one downstream consumer of Onboarding, it is not the same pipeline. 
---

# 13. Performance Domain

Performance is logically separate from core Personalplanung.

Major families:

```text
HDR / KHDR
OEE
targets
tables / workstations
NIO
Andon
```

Important objects include:

```text
tbl_import_hdr
tbl_import_khdr
tbl_import_oee

tbl_uebertrag_hdr
tbl_uebertrag_khdr
tbl_uebertrag_oee

tbl_perfor_hdr
tbl_perfor_ergebnis

tbl_import_targets_tische
tbl_targets_tische
tbl_stamm_tische
tbl_stamm_apid

tbl_import_nio_prozess
tbl_uebertrag_nio_prozess

tbl_import_andon
tbl_stamm_andon
```

Main performance transformation:

```text
tbl_import_hdr ----+
tbl_import_khdr ---+
tbl_import_oee ----+
                   |
                   v
            proc_insert_khdr
                   |
                   +-> tbl_uebertrag_hdr
                   +-> tbl_uebertrag_khdr
                   +-> tbl_uebertrag_oee
                   +-> tbl_perfor_hdr
```

Reference/target inputs include:

```text
tbl_datum
tbl_schichten
tbl_stamm_apid
tbl_stamm_tische
tbl_targets_tische
```

Targets are maintained through:

```text
tbl_import_targets_tische
        |
        v
proc_insert_targets_tische
        |
        +-> tbl_targets_tische
        |
        +-- uses:
            tbl_perfor_hdr
            tbl_stamm_apid
            tbl_stamm_tische
```

Do not treat `proc_insert_khdr` as Personalplanung merely because a global orchestrator may call it.

---

# 14. CAPS Domain

CAPS is the skills/capability domain.

Primary objects:

```text
tbl_import_caps_rohdaten
tbl_import_caps_ma
tbl_import_caps_skills_depts

tbl_uebertrag_caps_rohdaten
tbl_uebertrag_caps_rohdaten_2025
tbl_uebertrag_kennzahlen_caps

tbl_abteilungen_caps
tbl_stamm_caps_abteilungen
tbl_stamm_caps_funktion_mapping
tbl_zuordnung_caps
```

Important views:

```text
view_caps_rohdaten
view_caps_abgleich_rohdaten
view_caps_taeglich_abgleich_rohdaten
view_caps_verlauf_anzahl_schulungen
view_uebertrag_caps_rohdaten
view_uebertrag_caps_rohdaten_montag
```

Conceptually:

```text
CAPS imports
     |
     v
CAPS transfer/history
     |
     +-> personnel master
     +-> CAPS mappings
     |
     v
CAPS comparison / history views
     |
     v
CAPS KPIs
```

Treat CAPS as a separate domain that joins to personnel, not as part of Personalplanung.

---

# 15. Nettoanwesenheit / Abrechnung Domain

This domain is separate from core Personalplanung, but consumes several shared personnel sources. The split is due to different owners, not semantics.

Primary tables:

```text
tbl_import_nettoanwesenheit
tbl_import_nettoanwesenheit_manuell
tbl_import_nettoanwesenheit_roh

tbl_uebertrag_nettoanwesenheit
tbl_uebertrag_nettoanwesenheit_alt
tbl_uebertrag_nettoanwesenheit_monat

tbl_uebertrag_nettoanw_aend_management

tbl_import_stundenuebersicht
tbl_uebertrag_stundenuebersicht

tbl_import_verrechnungssaetze_zak
tbl_uebertrag_verrechnungssaetze
tbl_uebertrag_verrechnungssaetze_zak
```

Configuration/reference:

```text
tbl_konfiguration_bereich_abrechnung
tbl_konfiguration_eg_bereich_zuordnung
tbl_konfiguration_lohnkosten
tbl_konfiguration_stundenverschiebung
tbl_konfiguration_uebersetzg_verrechngssaetze
tbl_konfiguration_verrechnungssaetze
tbl_zeitarbeitsfirmen
```

Important views:

```text
view_nettoanwesenheit
view_anwesenheitsliste
view_mitarbeiter_zuordnung
view_mitarbeiter_zuordnung_ip
view_mitarbeiter_zuordnung_uet
view_tbl_uebertrag_nettoanwesenheit
view_ueberstunden_berechung
view_sonderregelungen_nachschicht_feiertag
view_Sonntagsverschiebung_Zeitarbeiter
view_mehrarbeit_zak
view_ausgangsrechnung_ako
view_ausgangsrechnung_ako_monatswerte
view_ausgangsrechnung_ako_wochenwerte
```

`view_nettoanwesenheit` is an important bridge from Personalplanung-derived data:

```text
tbl_import_buchungen_mitarbeiter --+
tbl_ueb_fz_buchungen --------------+
tbl_ueb_personalakte ---------------+--> view_nettoanwesenheit
tbl_abwesenheitsgrund --------------+
tbl_stamm_kategorie_abteilung ------+
```

The downstream domain is approximately:

```text
PERSONALPLANUNG / SHARED PERSONNEL
              |
              v
      attendance interpretation
              |
              v
       NETTOANWESENHEIT
              |
       +------+------+
       |             |
       v             v
 working time     allocation /
 adjustments      accounting
                     |
                     v
                 invoicing
```

---

# 16. Cross-Domain Dependency Map

The main architectural boundaries are:

```text
                    +------------------+
                    | Shared personnel |
                    | + calendar       |
                    +--------+---------+
                             |
             +---------------+----------------+
             |               |                |
             v               v                v
      Personalplanung       CAPS      Nettoanwesenheit
             |                                |
             |                                v
             |                         Accounting
             |                                ^
             +-- attendance/personnel data ---+


      Performance
          |
          +-> HDR / KHDR / OEE
          +-> targets
          +-> NIO
          +-> Andon

      Performance is mostly independent, sharing
      generic dimensions/infrastructure where required.
```

The important architectural fact is:

**Table-prefix layers cross domain boundaries.**

For example, `tbl_import_*` is not a domain. It is a pipeline stage.

---

# 17. High-Value Views

When investigating business logic, these are useful entry points.

## Personnel

```text
vp_personal_i -> import personnel
vp_personal_u -> transformed personnel
```

## Bookings

```text
vp_buchungen_i -> imported bookings
vp_buchungen_u -> intermediate transformed bookings
vp_buchungen   -> FZ/attendance-ready bookings
```

## Absence

```text
vp_fehlzeiten_i
vp_fehlzeiten_u
view_fehlzeit_query
view_fehlzeiten_detail
```

## Urlaub

```text
vp_urlaub_i
vp_urlaub_u
view_urlaubsvorschau_komplett
```

## FANF

```text
vp_fanf_i
```

The `vp_*` family gives a useful conceptual picture of import (`i`) versus transformed (`u`) data.

---

# 18. Materialized Tables vs Sources of Truth

Be especially careful with:

```text
tbl_ueb_aend_fz_kalender
tbl_ueb_buchungen
tbl_ueb_buchungen_2
tbl_ueb_buchungen_3
tbl_ueb_fz_buchungen
tbl_ueb_fz_join
tbl_ueb_fz_personalkalender
tbl_ueb_fz_forecast
tbl_ueb_fz_persfaktor
tbl_ueb_fz_personalplanung
tbl_ueb_fluktuation_person
```

These are downstream/materialized products.

Before editing data directly, find the procedure that builds them.

`tbl_ueb_fz_join` in particular is a derived integration table touched by several Personalplanung procedures. Do not mistake it for authoritative source data.

---

# 19. Recommended Investigation Order for an Agent

When asked to change or debug something:

1. Identify the business domain.
2. Find the final table/view that exhibits the problem.
3. Find procedures/views referencing that object.
4. Walk upstream through `tbl_ueb_* -> tbl_uebertrag_* -> tbl_import_*`.
5. Identify shared master/reference tables.
6. Check the orchestrator/caller before modifying procedure sequencing.
7. Inspect actual procedure SQL. Dependency presence does not tell whether an object is read, written, truncated or conditionally used.
8. Test against MariaDB, not a SQL approximation.
9. Treat derived tables as rebuildable unless evidence shows otherwise.
10. Check downstream consumers before changing a table's semantics.

For Personalplanung specifically, a good default path is:

```text
proc_00_personalplanung
        |
        v
relevant child procedure
        |
        v
tbl_ueb_* output
        |
        v
tbl_uebertrag_* history
        |
        v
tbl_import_* source
```

---

# 20. One-Screen Mental Model

```text
PERSONALPLANUNG

personalakte -----------------> tbl_ueb_personalakte -----------+
                                                               |
buchungen -> uebertrag -> tbl_ueb_buchungen -> fz_buchungen ---+
                                                               |
aenderungen -> history -> aend_fz_kalender --------------------+
                                                               |
personalkalender / urlaub --------------------------------------+
                                                               |
FANF -> tbl_uebertrag_fanf -------------------------------------+
                                                               |
                                                               v
                                                        fz_forecast
                                                               |
                                                               v
                                                    fz_personalplanung


CAPS

caps imports -> caps history -> comparison/history -> CAPS KPIs
                       ^
                       |
                 personnel master


NETTOANWESENHEIT

personnel + bookings + absences
              |
              v
       netto attendance
              |
              v
   adjustments / working time
              |
              v
    allocation / charge rates
              |
              v
          accounting


PERFORMANCE

HDR ---+
KHDR --+--> proc_insert_khdr --> transfer --> tbl_perfor_hdr
OEE ---+                                ^
                                        |
                               targets / APID / tables

NIO   -> own import/transfer pipeline
Andon -> own import/reference pipeline
```

This map describes architectural ownership and data flow, not transactional guarantees.

Whenever exact behavior matters, the stored procedure or view definition is authoritative.