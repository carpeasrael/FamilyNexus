# Testreport TP-FN-001 v1.7 – Lauf 13 – Build 1.2.1 (20)

**Datum:** 29.10.2026 (Abend) bis 30.10.2026 (Morgen). **Tester:** automatisiert (Claude Code, Maus- und Tastaturereignisse, `simctl`, `curl`). Datumsteil der Konten: 1029.
**Umfang:** vollständiger Plan (V, A bis G). G1 = macOS (TestFlight-Build 1.2.1 (20)), G2 = iPhone-17-Simulator, iOS 27.0 (statt iPhone 15: Simulator.app fehlt, nur DeviceHub). Server: `matrix-synapse-3ues.srv1348446.hstgr.cloud`.

PDF-Fassung im AURORA-Design: `Testreport_2026-10-29_13_macOS-iOS_Build20_DE.pdf`. Einzelergebnisse mit Beobachtungen: `Fortschritt.md`. Aufnahmen: `screenshots/`.

## Zusammenfassung

Schritte gesamt: 101 · bestanden 81, mit Befund 4, fehlgeschlagen 0, offen 15, n. a. 1. Alle Wegwerf-Konten (n1, n12, i2) am Ende gelöscht (curl: 403 `M_FORBIDDEN`); `fnt-1029-n9` nie angelegt. `flutter analyze` ohne Meldung, `flutter test`: 782 bestanden, 49 übersprungen.

## Nachtest der offenen Issues

| Issue | Schritt | Ergebnis | Beobachtung |
|---|---|---|---|
| #77 | E-18 | bestanden | Einzelnachricht sofort sichtbar, kein Reiterwechsel |
| #76 | E-23 | bestanden | „Mo–Fr“ / „Montag bis Freitag“, nicht „Täglich“ |
| #59 | E-07, E-12 | teilweise | iOS ok (https- und `familynexus://join#…`-Link); Mac-Zweig `open -a` nicht geprüft |
| #75 | D-02 | bestanden (Simulator) | Ablehnung nach ca. 10 s (Ziel ≤ 20 s); kein echtes iPhone |
| #57 | B-02, B-10 | teilweise | B-10 ok; B-02 am Mac nicht auslösbar; iOS: Darstellungsfehler (Befund 1) |

## Befunde

| Nr. | Schwere (Einschätzung) | Schritt | Beschreibung |
|---|---|---|---|
| 1 | Mittel | B-02 (iOS) | Hinweis zu den Systemeinstellungen in sehr schmaler Spalte, unten abgeschnitten, nicht scrollbar; Schaltfläche unsichtbar (`B-02d-G2`) |
| 2 | Niedrig | F-05 | Aufgabenliste zeigt Matrix-ID des gelöschten Kontos I2 statt „Ehemaliges Mitglied“ (`F-05i-G1`) |
| 3 | Niedrig | E-30 | Empfehlung „Ernenne einen zweiten Moderator.“ blieb nach der Ernennung sichtbar (nur einmal gesehen) |
| 4 | Niedrig | C-03, F-01 | „Geräte deines Kontos“ zeigt nur das eigene Gerät |
| 5 | Info | B-04 | Endzeit beim ersten Anlegen nicht übernommen (vermutlich Bedienartefakt) |
| 6 | Info | #61, F-05 | Anbieter steht nach Abmelden/Löschen wieder auf matrix.org (bekannt) |

## Nicht ausgeführt

E-17, E-19 bis E-22, E-25 bis E-27, Reaktion in E-16, D-07, G-04, G-06 bis G-08; B-02 (Mac) und B-17 nicht prüfbar; B-18 n. a. (macOS).

## Zuordnung zu Issues

Kein Issue wurde kommentiert oder geschlossen. #77 und #76 haben Nachweise; #59, #75 und #57 bleiben offen (siehe Tabelle oben).
