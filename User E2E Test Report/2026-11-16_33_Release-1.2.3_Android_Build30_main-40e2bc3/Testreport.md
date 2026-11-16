# Testreport Lauf 33: Release 1.2.3 (Build 30), Android-Emulator, Wiederholung auf origin/main 40e2bc3

**Datum:** 16.11.2026 · **Commit:** `40e2bc3f6c863143f2298c12677e7e77585320f9` (origin/main, Merge PR #518), `pubspec.yaml` 1.2.3+30
**Fingerabdruck** (`tool/check_release_review.sh --print` im Worktree): `12f222830be37417421d128654805d739c45447b` (wie erwartet)
**Gerät:** Android-Emulator, eigenes AVD `FN_E2E_B30M` (Pixel 8, API 35, Google APIs Playstore, arm64, 4 GB, `-wipe-data`). AVDs des Nutzers unberührt.
**Build-Art:** Debug-APK arm64 im Worktree auf 40e2bc3 ohne Änderungen, einmal regulär, einmal Vorschau-Einstieg (`-t tool/preview/preview_main.dart`, Fake-Server, erfundene Daten). Kein Release-/AAB-Build. Installiert: versionCode 30, versionName 1.2.3 (`dumpsys package`).
**Tester:** Tester-Agent; kein Code geändert, nichts committet. Bedienung per `adb` und `uiautomator dump`. Der Vorlauf `2026-11-15_32_...` bleibt unverändert.

## Zusammenfassung
Keine ❌. Pflichtteil und Oberflächenschritte bestanden, beide neuen Prüfungen (#501, #503) bestanden. Server-/Zwei-Konten-Abläufe und `tool/e2e.sh` bleiben ⏳ nicht getestet.

| ID | Schritt | Ergebnis | Beleg | Screenshot |
|---|---|---|---|---|
| P-ANA | `flutter analyze` | ✅ | `logs/analyze.txt`: „No issues found!“, exit 0 | - |
| P-TEST | `flutter test` | ✅ | `logs/flutter_test_tail.txt`: „+2613 ~115: All tests passed!“, exit 0 | - |
| P-BLD | Debug-APK regulär und Vorschau | ✅ | `logs/build_regular.txt`, `logs/build_preview.txt`: Built, exit 0 | - |
| RT3-V-01 | pubspec 1.2.3+30, Fingerabdruck | ✅ | `version: 1.2.3+30`; Fingerabdruck `12f2228…` | - |
| RT3-V-02/V-05 | Menü „Version 1.2.3 (30)“ | ✅ | `logs/ui_menu.txt`: `Version 1.2.3 (30)`; Einstellungen unten ebenfalls (Screenshot I-01 en) | `screenshots/RT3-V-02_And.png` |
| RT3-V-03 / #144 | Frische Installation regulär: Willkommensseite (EN), 3 Optionen; Fenster `SECURE`, Bild schwarz | ✅ | uiautomator: „Start a new family / I was invited / I already have an account“; `dumpsys window`: `fl=... SECURE ...` | `screenshots/RT3-V-03_And_Willkommen_schwarz-FLAG_SECURE.png` (schwarz, nur Beleg für FLAG_SECURE) |
| RT3-A-06 | Vorschau: Heute mit Terminen, Erinnerungen, Einkaufszettel, 5 Tabs | ✅ | uiautomator-Texte | `screenshots/RT3-A-06_And.png` |
| RT3-E-01 | Kalender: Tag/Woche/Monat/Agenda, November 2026, Mitgliederfilter | ✅ (Oberfläche, Vorschau) | `logs/ui_E01.txt` | `screenshots/RT3-E-01_And.png` |
| RT3-C-01 | Chat-Tab beginnt mit Gesprächsliste (Familienchat, Einzelchat Ben, Ungelesen) | ✅ (Vorschau) | `logs/ui_C01.txt` | `screenshots/RT3-C-01_And.png` |
| RT3-C-02/C-13/K-01 | Familienchat öffnet; „Nachricht von Ben / dir / Clara“, „Ende-zu-Ende-verschlüsselt“ als Semantik | ✅ (Vorschau, ohne TalkBack) | `logs/ui_C02.txt` | `screenshots/RT3-C-02_Familienchat_And.png` |
| RT3-C-04 | Chat > Einkauf > Chat: Gespräch bleibt, 3 Nachrichten | ✅ | `logs/ui_C04.txt`: 3 Knoten | `screenshots/RT3-C-04_And.png` |
| Einkauf | Einkauf-Tab | ✅ (Oberfläche) | `logs/ui_K01.txt` | `screenshots/RT3-K-01_Einkauf_And.png` |
| RT3-D-01 | Familie-Tab: Name, Einladung, Familien-Code, Themen | ✅ (Vorschau) | `logs/ui_D01.txt` | `screenshots/RT3-D-01_Familie_And.png` |
| RT3-R-01 | Einstellungen: Sprache, Design, Akzentfarben, Effekte reduzieren, Konto | ✅ | `logs/ui_settings.txt` | `screenshots/RT3-R-01_Einstellungen_And.png` |
| RT3-R-07 / #501 Dunkel | Dunkles Design: Statusleisten-Symbole hell | ✅ | `logs/appearance_dark.txt`: `mLastAppearance=LIGHT_NAVIGATION_BARS ...` ohne `LIGHT_STATUS_BARS`; Bild: Uhr/Akku weiß auf dunklem Grund | `screenshots/RT3-A-06_And.png`, `screenshots/RT3-R-01_Einstellungen_And.png`, `screenshots/RT3-R-07_And_Dunkel_Einstellungen.png` |
| RT3-R-07 / #501 Hell | Helles Design: Symbole (Uhr, Akku, Signal) dunkel, auch mit Titelleiste (Einstellungen) und Familie-Tab | ✅ | `dumpsys window`: `mLastAppearance=LIGHT_STATUS_BARS LIGHT_NAVIGATION_BARS ...`; Bild: Symbole dunkel auf hellem Grund | `screenshots/RT3-R-07_And_Hell_Einstellungen.png`, `screenshots/RT3-R-07_And_Hell_Familie.png` |
| RT3-I-01 / #503 de | „App teilen“ (Sprache Deutsch) zeigt „Link kopiert“ | ✅ | uiautomator: Knoten `Link kopiert` | `screenshots/RT3-I-01_And_de_Link-kopiert.png` |
| RT3-I-01 / #503 en | „Share app“ (English) zeigt „Link copied“ | ✅ | uiautomator: Knoten `Link copied` | `screenshots/RT3-I-01_And_en_Link-copied.png` |
| T-03 | `tool/e2e.sh` | ⏳ | nicht ausgeführt, siehe unten | - |
| C-xx, D-02…, E-02…E-11, F, G, H, P-01…P-08, P-15…P-17 | Server-/Zwei-Konten-/Matrix-Abläufe | ⏳ | kein Server für die App erreichbar | - |
| J, I (außer I-01), R-02…R-06, P-13/14 (Schriftgrößen, Tablet, Tour, Themen), TalkBack | nicht wiederholt | ⏳ | keine Tablet-AVD, keine Schriftskalierung, kein TalkBack | - |
| G-04…G-08, G-14 | matrix.org, Fremdanbieter, Passkeys | ⏳ | keine Freigabe für echte Konten | - |

## Befunde
- **B1 (Hinweis):** Standard „Bildschirmschutz an“ macht adb-Bilder der regulären App schwarz; Bilder stammen aus dem Vorschau-Modus.
- **B2 (Hinweis, Vorschau/Emulator):** Im Vorschau-Modus zeigt der Einstellungen-Abschnitt Linux-artige Pfade (`/home/test/.local/share/...familynexus_matrix.db`) und „System keyring (Secret Service)“ auf Android. Vermutlich Fake-Werte des Vorschau-Einstiegs; nicht gegen die reguläre App geprüft, daher nicht als Fehler gewertet.
- **B3 (Hinweis):** Im englischen Screenshot überdeckt die Android-13+-Zwischenablage-Vorschau die Snackbar; der Text „Link copied“ liegt im UI-Baum (uiautomator), das de-Bild zeigt die Snackbar unverdeckt nicht gesondert. Kein App-Fehler.
- Keine neuen Fehler. Statusleiste hell (Befund aus Lauf 31) auf diesem Stand behoben (#501).

## Nicht ausgeführt / nicht getestet
Alle Serverabläufe, `tool/e2e.sh` (kein erreichbarer Synapse für die App auf dem Play-Store-Emulator, Docker mit fremden Containern, in Lauf 31/32 so belegt), Tablet, Schrift 200 %, TalkBack, Release-/AAB-Build mit Signatur, echtes Gerät. Gelten als nicht getestet, nicht als bestanden.
