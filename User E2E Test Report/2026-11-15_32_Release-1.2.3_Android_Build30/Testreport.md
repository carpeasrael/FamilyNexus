# Testreport Lauf 32: Release 1.2.3 (Build 30), Android-Emulator (Teil von TP-FN-REL-123)

**Datum:** 15.11.2026 · **Commit:** `cdeeb988e2391ec787d56904cd02b9fe471102c5` (origin/main, Merge PR #511), `pubspec.yaml` 1.2.3+30
**Fingerabdruck** (`tool/check_release_review.sh --print` im Worktree): `ab5d83191b6e9e95972449da655589c396de34fa`
**Gerät:** Android-Emulator, eigenes AVD `FN_E2E_B30` (Pixel 8, `sdk_gphone64_arm64`, API 35, Google APIs Playstore, arm64, 4 GB, `-wipe-data`). AVD des Nutzers (`Pixel8_API35`, `fn_tablet`, `fn_test`) unberührt.
**Build-Art:** Debug-APK, arm64 (`flutter build apk --debug --target-platform android-arm64`), einmal regulär, einmal Vorschau-Einstieg (`-t tool/preview/preview_main.dart`, Fake-Matrix-Server, erfundene Daten). Gebaut im Worktree auf origin/main, ohne Änderungen. Kein Release-/AAB-Build (Release-Signatur nicht vorhanden).
**Tester:** Tester-Agent; kein App-Code geändert, nichts committet, kein Tag, keine Build-Nummer, kein Upload, keine Konten. Bedienung per `adb` und `uiautomator dump` (kein TalkBack).
**Plan:** `User E2E Test/Release_1.2.3_v01/Release-Test_1.2.3_v01.md` (liegt nur auf Branch `origin/docs/release-testplan-1-2-3`, nicht auf main).

## Zusammenfassung

Pflichtteil bestanden, Android-Oberflächen- und Versionsschritte ohne ❌ belegt. **Alle Zwei-Konten- und Serverabläufe sind nicht getestet (⏳)**, ebenso `tool/e2e.sh`. Die Plattform-Abnahme ist damit auf dem Niveau eines Rauchtests (Start, Version, Navigation, Vorschau-Oberfläche, FLAG_SECURE), nicht der vollen Android-Schritte des Plans.

| ID | Schritt | Ergebnis | Beleg | Screenshot |
|---|---|---|---|---|
| P-ANA | `flutter analyze` im Worktree | ✅ | `logs/analyze.txt`: „No issues found!“, exit 0 | - |
| P-TEST | `flutter test` im Worktree | ✅ | `logs/flutter_test_tail.txt`: „+2608 ~115: All tests passed!“, exit 0 (2608 bestanden, 115 übersprungen, 0 fehlgeschlagen) | - |
| P-BLD | Build Debug-APK regulär und Vorschau | ✅ | `logs/build_regular.txt`, `logs/build_preview.txt`: „Built build/app/outputs/flutter-apk/app-debug.apk“ | - |
| RT3-V-01 | pubspec 1.2.3+30, Fingerabdruck | ✅ | `grep ^version pubspec.yaml` = `1.2.3+30`; Fingerabdruck `ab5d831…` wie erwartet | - |
| RT3-V-02 | Menü unten „Version 1.2.3 (30)“ | ✅ | uiautomator: `Version 1.2.3 (30) [324,2248,596,2295]` | `screenshots/RT3-V-02_And.png` |
| RT3-V-03 | Frische Installation regulär: Willkommensseite, Sprache Gerät (EN), Optionen „Start a new family / I was invited / I already have an account“ | ✅ | uiautomator-Text der Willkommensseite (Emulator-Sprache Englisch) | Bild bewusst schwarz, siehe B1 |
| RT3-V-05 | Build zeigt (30) | ✅ | wie V-02, Einstellungen/Menü | `screenshots/RT3-V-02_And.png` |
| #144 Android | Bildschirmschutz: Fenster `SECURE`, adb-Screenshot der regulären App schwarz | ✅ | `dumpsys window windows`: `fl=... SECURE ...`; Screenshot schwarz mit Schild-Symbol in der Statusleiste | `screenshots/RT3-V-03_And_Willkommen_schwarz-FLAG_SECURE.png` (Beleg für Schwarz, zählt nicht als Oberflächen-Screenshot) |
| RT3-A-06 | Start in Vorschau-Modus, Heute-Tab mit Terminen, Erinnerungen, Einkaufszettel | ✅ | uiautomator: „Nächste Termine“, Zahnarzt Lena, Fußballtraining, Familienessen bei Oma, 5 Tabs | `screenshots/RT3-A-06_And.png` |
| RT3-E-01 | Kalender-Tab: Tag/Woche/Monat/Agenda, November 2026, Mitgliederfilter | ✅ (Oberfläche, Vorschau) | uiautomator-Dump Kalender | `screenshots/RT3-E-01_And.png` |
| RT3-C-01 | Chat-Tab beginnt mit Gesprächsliste (Familienchat, Einzelchat Ben, Ungelesen-Zähler) | ✅ (Vorschau) | uiautomator-Text | `screenshots/RT3-C-01_And.png` |
| RT3-C-02 / C-13 / K-01 | Familienchat öffnet, „Nachricht von Ben / von dir / von Clara“ als Semantik, „Ende-zu-Ende-verschlüsselt“ | ✅ (Vorschau, ohne TalkBack) | uiautomator-Labels | `screenshots/RT3-C-02_Familienchat_And.png` |
| RT3-C-04 | Gespräch bleibt beim Tab-Wechsel (Chat > Einkauf > Chat zeigt weiter die 3 Nachrichten) | ✅ | uiautomator: 3 Knoten „Nachricht von“ nach Rückkehr | `screenshots/RT3-C-04_And.png` |
| Einkauf | Einkauf-Tab | ✅ (Oberfläche) | Screenshot | `screenshots/RT3-K-01_Einkauf_And.png` |
| RT3-D-01 | Familie-Tab: Familienname, Einladung, Familien-Code, Kalender-Themen | ✅ (Vorschau) | uiautomator-Dump | `screenshots/RT3-D-01_Familie_And.png` |
| RT3-R-01 | Einstellungen: Sprache, Design, Akzentfarben, Effekte reduzieren, Konto | ✅ (Oberfläche) | uiautomator-Dump | `screenshots/RT3-R-01_Einstellungen_And.png` |
| T-03 | `tool/e2e.sh` gegen lokalen Synapse | ⏳ | nicht ausgeführt (Docker läuft mit fremden Containern; Synapse-Zertifikat ist in der App auf dem Play-Store-Emulator nicht zulassbar, siehe Lauf 31) | - |
| C-xx, D-02…, E-02…E-11, F, G, P-01…P-08, P-15…P-17 | Zwei-Konten-/Server-/Matrix-Abläufe | ⏳ | kein Server für die App erreichbar; Vorschau-Modus hat keine echten Abläufe | - |
| J-xx, I-xx, H-xx, R-02…R-08, P-13/14 (Schriftgrößen, Tablet, Teilen, Tour, Themen) | nicht erneut ausgeführt | ⏳ | in Lauf 31 auf Build 29 belegt bzw. ⚠️; auf Build 30 nicht wiederholt (nur Pixel-8-AVD, keine Tablet-AVD, keine Schriftskalierung) | - |
| G-04…G-08, G-14 | matrix.org, Fremdanbieter, Passkeys | ⏳ | keine Freigabe für echte Konten | - |

## Befunde

- **B1 (Hinweis, kein Fehler):** Der Standard „Bildschirmschutz an“ (`lib/domain/app_settings.dart:17`) macht adb-Screenshots der regulären App schwarz; für Bilder dient der Vorschau-Modus (dort `SECURE` nicht gesetzt). Der Beleg für #144 ist das SECURE-Flag und das schwarze Bild.
- Keine neuen Befunde. Die offenen Befunde B1…B12 aus Lauf 31 (z. B. „App bewerten“, Themen-Chips, Schrift 200 %, Statusleiste hell) wurden auf Build 30 nicht erneut geprüft; Statusleisten-Fix #501 liegt auf einem eigenen Branch, nicht auf main.

## Nicht ausgeführt / nicht getestet

Alle Serverabläufe (siehe Tabelle), `tool/e2e.sh`, Tablet-Layouts, Schrift 200 %, englische Oberfläche über Sprachumschaltung, TalkBack, Release-/AAB-Build mit Signatur, echtes Gerät. Diese gelten als nicht getestet, nicht als bestanden.
