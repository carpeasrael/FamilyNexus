# Testreport FamilyNexus – TP-FN-001 v1.5 @ 7159ddc

Lauf vom 27.10.2026 (20:40 bis 23:25), Apple-Lauf: G1 = iPhone (iOS-Simulator), G2 = Mac. Soll-Version 1.2.1+17 (V-01), Ist auf beiden Geräten 1.2.1 (17). Hinweis: Bedienung per Klick-/Tipp-Skript (kein Mensch am Gerät); Umlaute und Großbuchstaben kamen im Simulator teils falsch an (siehe Befunde E1/E2).

## 1. Plattform und System (Abschnitt 2)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iOS (Simulator) | macOS |
| Gerät | iPhone 15 Test (Device Hub) | Mac (Fenster 800 × 632 pt) |
| Betriebssystem | iOS 27.0 | macOS 27.2 |
| Installationsquelle | Build aus `main` (7159ddc) | `flutter build macos --release` aus `main`, von `build/` gestartet (nicht nach /Applications kopiert; dort lag Build 16) |
| App-Version Soll / Ist | 1.2.1 (17) / 1.2.1 (17) | 1.2.1 (17) / 1.2.1 (17) |
| Gerätesprache, Sperre | Deutsch; **keine Bildschirmsperre** | Deutsch; Sperre nicht geprüft |
| Screenshot-Methode | `xcrun simctl io booted screenshot` | `screencapture -R` |
| Tester / Beginn | Claude (automatisiert) / 27.10.2026 20:40 | dto. |

## 2. Vorbereitung V-01 bis V-07
V-01 ✅ (main = origin/main, 1.2.1+17). V-02 ✅ (Mac /Applications: Build 16 → V-03). V-03 ✅ (Mac-Build 17 gebaut). V-04 ✅ (beide „Willkommen“). V-05 ✅ (Server erreichbar, `m.login.dummy`). V-06 ✅ (Datumsteil `1027`, alle Namen frei). V-07 ⏳ (Systemeinstellungen/Bildschirmsperre nicht geprüft).

## 3. Zusammenfassung

| Ergebnis | Anzahl Schritte (104, wie im PDF) |
|---|---|
| ✅ bestanden | 84 |
| ⚠️ bestanden mit Befund / teilweise | 9 (A-07, B-01, B-03, B-19, B-21, D-02, E-05, E-21, E-25) |
| ❌ fehlgeschlagen | 0 |
| ⏳ nicht ausgeführt | 11 (V-07, B-17, B-18, B-20, D-07, E-12, E-17, G-04, G-06, G-07, G-08) |

Englischer Report mit Bildern: `Testreport_FamilyNexus_EN_AURORA.pdf` (Schritt-Übersicht, Befunde, Details je Schritt mit Screenshots).

**Abnahme (Abschnitt 7): nicht bestanden.** Es bestehen ⏳-Schritte (V-07, B-17, B-18, B-20, E-12, E-17, G-06 und Teile von B-19, B-21, E-05), die vor der Antwort an Apple nachgeholt werden müssen; B-17/B-18 gehen nur auf einem echten iPhone mit Gerätesperre. Zusätzlich fehlen die ⚠️-Befunde als angelegte Issues (nicht angelegt).

## 4. Befundliste

| Nr. | Schwere | Schritt | Beschreibung |
|---|---|---|---|
| D1 | mittel | D-02 | Nach „Ablehnen“ durch den Moderator zeigt der Beitretende dauerhaft „Fast geschafft!“, nie „Deine Anfrage wurde abgelehnt“ (Issue #30 weiterhin offen) Issue #43. |
| A1 | niedrig | A-07 | Benutzername `Anna` wird zu `anna` umgewandelt statt abgelehnt (laut Plan Fehlermeldung); Fehlertext bei ungültigen Namen im Bild abgeschnitten Issue #44. |
| E3 | niedrig | E-25 | Hinweis „Meldung gesendet.“ blieb stehen und verdeckte die Bedienung bis zum App-Neustart Issue #45. |
| B3 | niedrig | B-03/B-12/B-14 | Eingabe „Testnotiz“ erschien als „Restitution“, Großbuchstaben fehlten: wahrscheinlich Skript/Simulator (Autokorrektur), nicht bestätigt |
| E2 | niedrig | E-21 | Nach Wechsel auf „Privat“ zeigte die noch geöffnete Detailseite „Gelöscht“ Issue #46. |
| T1 | Testumgebung | C-06 | Eigene Fehleingaben (Skript) lösten das Server-Ratenlimit („Zu viele Anfragen“) für ca. 1 h aus |
| T2 | Testumgebung | F-05 | Simulator verlor beim Tippen Großbuchstaben; Notfall-Schlüssel nur per Zwischenablage eingebbar |

Behoben bzw. nicht mehr beobachtet (gegenüber Plan 1.4): #10, #11, #12, #14, #26, #28 (nicht aufgetreten), #31, #34, #35, #36, #38 ✅.

## 5. Automatische Tests (G)
| ID | Beobachtet | Erg. |
|---|---|---|
| G-01 | `flutter analyze`: No issues found! (`logs/G-01_analyze_lauf.txt`) | ✅ |
| G-02 | `flutter test`: 744 bestanden, 48 übersprungen, 0 fehlgeschlagen (`logs/G-02_flutter_test_lauf.txt`) | ✅ |
| G-03 | `review_notes_test.dart`: 4 bestanden | ✅ |
| G-04 | optionaler E2E-Lauf nicht ausgeführt | n/a |
| G-05 | in G-02 enthalten und grün | ✅ |
| G-06 | Review-Notizen nicht manuell nachvollzogen | ⏳ |
| G-07 | keine Person ohne Vorwissen verfügbar | n/a |
| G-08 | nur Web | n/a |

## 6. Schritte A bis F
Einzelergebnisse mit Beobachtung und Screenshot: siehe `Ergebnisse.md` (Tabellen je Abschnitt), Screenshots in `screenshots/` (Dateinamen nach Schritt-ID), Vorbereitung in `Vorbereitung.md`. Notfall-Schlüssel und Passwörter sind nicht im Report; Bilder mit Schlüsseln sind geschwärzt oder entfernt.

## 7. Zustand am Ende (F-08)
Konten `fnt-1027-n1`, `-n12`, `-i2` gelöscht (curl-Anmeldung `403`), `-n9` nie angelegt; Registrierung offen; G1/G2 zeigen „Willkommen“.
