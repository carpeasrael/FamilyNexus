# Testreport Lauf 34: Release 1.2.3 (Build 31), Android-Emulator, origin/main 9e55155

**Datum:** 16.11.2026 · **Commit:** `9e55155727e6061437842f58a7e4178d5859f050` (origin/main, Merge PR #530), `pubspec.yaml` 1.2.3+31
**Fingerabdruck** (`tool/check_release_review.sh --print` im Worktree): `27b319f5a7fbc2d5fe6a3a1aecbb91f1e011f2a3` (wie erwartet)
**Gerät:** Android-Emulator, eigenes AVD `FN_E2E_B31M` (Pixel 8, API 35, Google APIs Playstore, arm64, 4 GB, `-wipe-data`, Port 5570). AVDs des Nutzers unberührt.
**Build-Art:** Debug-APK arm64 im Worktree auf 9e55155 ohne Änderungen, einmal regulär, einmal Vorschau-Einstieg (`-t tool/preview/preview_main.dart`, Fake-Server, erfundene Daten). Kein Release-/AAB-Build. Installiert: versionCode 31, versionName 1.2.3 (`logs/package_regular.txt`).
**Tester:** Tester-Agent; kein Code geändert, nichts committet. Bedienung per `adb` und `uiautomator dump` (ui.py aus `User E2E Test/Default_test_G1-G2/sandbox/`). Vorläufe (u. a. Lauf 33) unverändert.

## Zusammenfassung
Keine ❌. Pflichtteil, alle wiederholten Oberflächenschritte und die neue Prüfung #506 bestanden. #510 ist nur als Code-Test (flutter test) belegt, nicht am Gerät. Server-/Zwei-Konten-Abläufe und `tool/e2e.sh` bleiben ⏳ nicht getestet.

| ID | Schritt | Ergebnis | Beleg | Screenshot |
|---|---|---|---|---|
| P-ANA | `flutter analyze` | ✅ | `logs/analyze.txt`: „No issues found!“, exit 0 | - |
| P-TEST | `flutter test` | ✅ | `logs/flutter_test_tail.txt`: „+2622 ~115: All tests passed!“, exit 0 | - |
| P-BLD | Debug-APK regulär und Vorschau | ✅ | `logs/build_regular.txt`, `logs/build_preview.txt`: Built | - |
| RT3-V-01 | pubspec 1.2.3+31, Fingerabdruck | ✅ | `version: 1.2.3+31`; Fingerabdruck `27b319f…` | - |
| RT3-V-02 | Menü „Version 1.2.3 (31)“ | ✅ | `logs/ui_menu.txt`: `Version 1.2.3 (31)` | `screenshots/RT3-V-02_And.png` |
| RT3-V-05 | Einstellungen unten „Version 1.2.3 (31)“ | ✅ | uiautomator (Einstellungen, ganz unten) | `screenshots/RT3-V-05_And_Einstellungen_Version.png` |
| RT3-V-03 / #144 | Frische reguläre Installation: Willkommensseite (EN), 3 Optionen; Fenster `SECURE`, Bild schwarz | ✅ | `logs/ui_welcome.txt`, `logs/secure_regular.txt` (`fl=... SECURE ...`) | `screenshots/RT3-V-03_And_Willkommen_schwarz-FLAG_SECURE.png` (schwarz, nur Beleg für FLAG_SECURE) |
| RT3-A-06 | Vorschau: Heute (Termine, Erinnerungen, Einkaufszettel, 5 Tabs) | ✅ | `logs/ui_A06.txt` | `screenshots/RT3-A-06_And.png` |
| RT3-E-01 | Kalender: Tag/Woche/Monat/Agenda, November 2026, Mitgliederfilter | ✅ (Oberfläche, Vorschau) | `logs/ui_E01.txt` | `screenshots/RT3-E-01_And.png` |
| RT3-C-01 | Chat-Tab beginnt mit Gesprächsliste (Familienchat, Einzelchat Ben, Ungelesen) | ✅ (Vorschau) | `logs/ui_C01.txt` | `screenshots/RT3-C-01_And.png` |
| RT3-C-02/C-13/K-01 | Familienchat; „Nachricht von Ben / dir / Clara“, „Ende-zu-Ende-verschlüsselt“ als Semantik | ✅ (Vorschau, ohne TalkBack) | `logs/ui_C02.txt` | `screenshots/RT3-C-02_Familienchat_And.png` |
| RT3-C-04 | Familienchat offen > Einkauf > Chat: Gespräch bleibt, 3 Nachrichten | ✅ | `logs/ui_C04.txt`: 3 Knoten „Nachricht von“ | `screenshots/RT3-C-04_And.png` |
| Einkauf | Einkauf-Tab | ✅ (Oberfläche) | `logs/ui_K01.txt` | `screenshots/RT3-K-01_Einkauf_And.png` |
| RT3-D-01 | Familie-Tab: Name, Einladung, Familien-Code, Themen, Mitglieder | ✅ (Vorschau) | `logs/ui_D01.txt` | `screenshots/RT3-D-01_Familie_And.png` |
| RT3-R-01 | Einstellungen: Sprache, Design, Akzentfarben, Effekte reduzieren, Konto | ✅ | `logs/ui_settings.txt` | `screenshots/RT3-R-01_Einstellungen_And.png` |
| RT3-R-07 / #501 Dunkel | Statusleisten-Symbole hell | ✅ | `logs/appearance_dark.txt`: ohne `LIGHT_STATUS_BARS`; Bild: Uhr/Akku weiß auf dunkel (RT3-V-02) | `screenshots/RT3-R-07_And_Dunkel_Einstellungen.png` |
| RT3-R-07 / #501 Hell | Symbole dunkel auf hellem Grund (Einstellungen, Familie) | ✅ | `logs/appearance_light.txt`: `LIGHT_STATUS_BARS ...`; Bild angesehen | `screenshots/RT3-R-07_And_Hell_Einstellungen.png`, `screenshots/RT3-R-07_And_Hell_Familie.png` |
| RT3-I-01 / #503 de | „App teilen“ zeigt „Link kopiert“ | ✅ | `logs/ui_I01_de.txt` | `screenshots/RT3-I-01_And_de_Link-kopiert.png` |
| RT3-I-01 / #503 en | „Share app“ zeigt „Link copied“ | ✅ | `logs/ui_I01_en.txt` | `screenshots/RT3-I-01_And_en_Link-copied.png` |
| NEU #506 | Avatar > „Pfote“ wählen > Speichern: Bildschirm schließt, Rückkehr zur Familie-Seite | ✅ (Vorschau, Moderator Anna) | vorher `logs/ui_avatar_before.txt` (Titel „Avatar“, „Initialen … Ausgewählt“), gewählt `logs/ui_avatar_picked.txt` (Vorschau „Pfote“, Speichern klickbar), nachher `logs/ui_avatar_after.txt`: Familie-Seite, „Avatar ändern“ wieder sichtbar, kein Avatar-Titel | `screenshots/RT3-A-Avatar_vorher.png`, `screenshots/RT3-A-Avatar_Pfote_gewaehlt.png`, `screenshots/RT3-A-Avatar_nachher.png` |
| NEU #510 | Einladungsdialog: Servername ohne Port wie leeres Feld | ✅ nur als Code-Test | reine Gateway-Logik; durch `flutter test` (alle grün) belegt, kein Geräteschritt, am Gerät nicht geprüft | - |
| T-03 | `tool/e2e.sh` | ⏳ | nicht ausgeführt, siehe unten | - |
| C-xx, D-02…, E-02…E-11, F, G, H, P-01…P-08, P-15…P-17 | Server-/Zwei-Konten-/Matrix-Abläufe | ⏳ | kein Server für die App erreichbar | - |
| J, I (außer I-01), R-02…R-06, P-13/14, TalkBack | nicht wiederholt | ⏳ | keine Tablet-AVD, keine Schriftskalierung, kein TalkBack | - |
| G-04…G-08, G-14 | matrix.org, Fremdanbieter, Passkeys | ⏳ | keine Freigabe für echte Konten | - |

## Befunde
- **B1 (Hinweis):** Standard „Bildschirmschutz an“ macht adb-Bilder der regulären App schwarz; Bilder stammen aus dem Vorschau-Modus.
- **B2 (Hinweis):** Die Snackbar „Avatar gespeichert“ nach dem Speichern wurde nicht als Bild belegt (Aufnahme 0,4 s nach dem Tippen zeigte noch den Auswahlzustand und wurde verworfen); belegt ist das Schließen des Bildschirms.
- **B3 (Hinweis, Testwerkzeug):** Einmal sprang die Oberfläche beim Skripten von Einstellungen zurück zur Familie-Seite (nach `uiautomator dump`/Taste); Wiederholung verlief normal, kein reproduzierbarer App-Fehler beobachtet.
- Keine neuen Fehler.

## Nicht ausgeführt / nicht getestet
Alle Serverabläufe, `tool/e2e.sh`, Tablet, Schrift 200 %, TalkBack, Release-/AAB-Build mit Signatur, echtes Gerät, #510 am Gerät. Gelten als nicht getestet, nicht als bestanden.
