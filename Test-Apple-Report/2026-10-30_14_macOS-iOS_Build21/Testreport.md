# Testreport TP-FN-001 v1.7 – Lauf 14 – Build 1.2.1 (21)

**Datum:** 30.10.2026, ca. 10:00–11:45. **Tester:** automatisiert (Claude Code, Maus- und Tastaturereignisse, `simctl`, `curl`). Datumsteil der Konten: 1030.
**Umfang:** vollständiger Plan (V, A bis G). G1 = macOS 27.2 (TestFlight-Build 1.2.1 (21)), G2 = iPhone-17-Simulator, iOS 27.0 (Simulator-Build aus `main` @ e4180fb; „iPhone 127“ im Auftrag als iPhone 17 gelesen). Server: `matrix-synapse-3ues.srv1348446.hstgr.cloud`. Bildschirmschoner und Ruhezustand waren per `caffeinate` gesperrt.

PDF-Fassung im AURORA-Design: `Testreport_2026-10-30_14_macOS-iOS_Build21_DE.pdf`. Einzelergebnisse mit Beobachtungen: `Fortschritt.md`. Aufnahmen: `screenshots/`.

## Zusammenfassung

Schritte gesamt: 102 · bestanden 93, mit Befund 2, fehlgeschlagen 0, offen 7. Alle Wegwerf-Konten (n1, n12, i2) am Ende gelöscht (curl: 403 `M_FORBIDDEN`); `fnt-1030-n9` nie angelegt. `flutter analyze` ohne Meldung, `flutter test`: 784 bestanden, 49 übersprungen.

## Nachtest der Issues

| Issue | Schritt | Ergebnis | Beobachtung |
|---|---|---|---|
| #97 | B-02 (iOS) | bestanden | Hinweis zu den Systemeinstellungen in voller Breite, „Einstellungen öffnen“ sichtbar |
| #98 | F-05 | bestanden | „Ehemaliges Mitglied“ in Aufgaben, Terminen und Chat, nie die Matrix-ID |
| #57 | B-02, B-10 | bestanden | Mac: Erinnerung kommt an; Hinweis → „Einstellungen öffnen“ → Hinweis weg |
| #75 | D-02 | bestanden (Simulator) | Ablehnung nach ca. 10 s (Ziel ≤ 20 s); kein echtes iPhone |
| #59, #76, #77 | E-07, E-12, E-23, E-18 | bestanden | erneut bestätigt |

## Befunde

| Nr. | Schwere (Einschätzung) | Schritt | Beschreibung |
|---|---|---|---|
| 1 | Niedrig | V-04, A-03, A-11 | Ein geöffneter Einladungslink bleibt über Neustarts gespeichert, überschreibt den Anbieter beim Weg „Neue Familie gründen“ und zeigt im Familienschritt die Beitrittskarte statt der Gründung; verwerfen erst nach der Kontoanlage |
| 2 | Info | D-04 | Anbieter-Adresse nach „Ich habe schon ein Konto“ leer (in Lauf 13 erhalten) |
| 3 | Info | B-18 (iOS) | Wirkung des Bildschirmschutzes nur auf einem echten iPhone prüfbar |
| 4 | Info | E-32a | Beleg ging beim automatischen Schwärzen verloren (durch F-01a ersetzt) |
| 5 | Info | B-05 | Datumswähler: Ende-Datum wanderte zeitweise mit (Bedienartefakt) |
| 6 | Info | #61, F-05 | Anbieter steht nach Abmelden/Löschen wieder auf matrix.org (bekannt) |

Die Auffälligkeiten aus Lauf 13 (Empfehlung „zweiter Moderator“ nach E-30, Geräteliste in C-03) sind nicht aufgetreten.

## Nicht ausgeführt

B-17 (Systempasswort), B-18 (echtes iPhone), D-07, G-04, G-06 bis G-08; E-05 „Per E-Mail senden“.

## Zuordnung zu Issues

Keine Issues in diesem Lauf kommentiert oder geändert. #57 kann geschlossen werden; #75 bleibt bis zur Messung auf einem echten iPhone offen; Befund 1 ist als Issue anzulegen (Zustimmung nötig).
