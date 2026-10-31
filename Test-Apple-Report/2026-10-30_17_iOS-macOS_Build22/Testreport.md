# Testreport TP-FN-001 v1.8 – Lauf 17 – Build 1.2.1 (22)

**Datum:** 30.10.2026, ca. 20:40–22:35. **Tester:** automatisiert (Claude Code: Mausereignisse, Tastatur, `simctl`, `curl`). Datumsteil der Konten: `1030c`.
**Umfang:** vollständiger Plan (V, A bis H). G1 = iPhone-17-Simulator, iOS 27.0 (Simulator-Build aus `main` @ dddf22d), G2 = macOS 27.2 (TestFlight-Build 1.2.1 (22)). Server: `matrix-synapse-3ues.srv1348446.hstgr.cloud`. Bildschirmschoner und Ruhezustand per `caffeinate -dimsu` gesperrt.

PDF im AURORA-Design: `Testreport_2026-10-30_17_iOS-macOS_Build22_DE.pdf`. Einzelergebnisse: `Fortschritt.md`.

## Zusammenfassung

Schritte gesamt: 123 · bestanden 107, mit Befund 7, **fehlgeschlagen 1 (D-02)**, offen 7, n/a 1. Konten n1, n12, i2 am Ende gelöscht. `flutter analyze` ohne Meldung, `flutter test`: 786 bestanden, 49 übersprungen.

## Befunde

| Nr. | Schwere | Schritt | Beschreibung |
|---|---|---|---|
| 1 | Hoch | D-02 | Ablehnung einer Beitrittsanfrage (Familien-Code) kommt auf dem Mac nicht an (6 min, auch nach Neustart; Ziel ≤ 20 s, #43/#75) |
| 2 | Mittel | A-09 | Erstes Antippen „Konto erstellen“ auf iOS: „Unbekannter Fehler.“, zweiter Versuch gelang |
| 3 | Niedrig | H-18 | Nach „Alle lokalen Daten löschen“ sofort neue leere Datenbankdateien (iOS) |
| 4 | Info | H-12 | Familienname als Raumname im Klartext, in der Datenschutzerklärung nicht genannt |
| 5 | Info | B-17, B-18, H-02, H-07, H-10, H-19 | Grenzen der Automatisierung |
| 6–7 | Info | V-06, iOS | Namensdatum, Ersatzschreibung |

## Nicht ausgeführt (⏳)

B-17, D-07, G-04, G-06, G-07, H-19; H-02 auf dem Mac (Container geschützt).
