# Testreport TP-FN-001 v1.8 – Lauf 16 – Build 1.2.1 (22)

**Datum:** 30.10.2026, ca. 17:35–19:25. **Tester:** automatisiert (Claude Code: Mausereignisse, Tastatur, `simctl`, `curl`). Datumsteil der Konten: `1030b`.
**Umfang:** vollständiger Plan (V, A bis H). G1 = macOS 27.2 (TestFlight-Build 1.2.1 (22), „TestFlight Beta Distribution“), G2 = iPhone-17-Simulator, iOS 27.0 (Simulator-Build aus `main` @ dddf22d). Server: `matrix-synapse-3ues.srv1348446.hstgr.cloud`. Bildschirmschoner und Ruhezustand per `caffeinate -dimsu` gesperrt (keine Systemeinstellung geändert).

PDF im AURORA-Design: `Testreport_2026-10-30_16_macOS-iOS_Build22_DE.pdf`. Einzelergebnisse: `Fortschritt.md`. Aufnahmen: `screenshots/`, Konsolenausgaben: `logs/`.

## Zusammenfassung

Schritte gesamt: 123 · bestanden 108, mit Befund 6, fehlgeschlagen 0, offen 7, n/a 2. Wegwerf-Konten n1, n12, i2 am Ende gelöscht (403 `M_FORBIDDEN`); `fnt-1030b-n9` nie angelegt. `flutter analyze` ohne Meldung, `flutter test`: 786 bestanden, 49 übersprungen.

## Befunde

| Nr. | Schwere | Schritt | Beschreibung |
|---|---|---|---|
| 1 | Niedrig | H-18 | Nach „Alle lokalen Daten löschen“ (Mac) bleibt `fn.key.db.matrix` im Schlüsselbund; `fn.key.db.app` wird neu angelegt. Simulator: sofort neue leere DB-Dateien |
| 2 | Info | H-12 | Familienname als Raumname im Klartext auf dem Server, in der Datenschutzerklärung nicht genannt |
| 3 | Info | B-21 | Anzeigename „Test N1“ fehlt im lokalen Protokoll |
| 4 | Info | E-16 | Zähler „Ungelesene Nachrichten“ vor dem Öffnen nicht gemessen (#65) |
| 5 | Info | B-17, H-02, H-05, H-19 | Grenzen der Automatisierung (Systempasswort, Simulator-Code, Mac-Container) |
| 6 | Info | F-07 | Server-Ratenbegrenzung bei Gegenproben |
| 7 | Info | iOS-Schritte | Ersatzschreibung für Umlaute auf dem Simulator |

## Nicht ausgeführt (⏳)

B-17 (Systempasswort/Gerätecode), D-07, G-04, G-06, G-07, H-02 (Mac-Container, Ersatz auf G2), H-19.
