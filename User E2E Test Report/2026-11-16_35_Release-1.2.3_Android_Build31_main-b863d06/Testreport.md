# Testreport Lauf 35: Release 1.2.3 (Build 31), Android-Emulator, origin/main b863d06

**Datum:** 16.11.2026 · **Commit:** `b863d06240442bcc32b5d1e9de00f1ec3f06bc67` (origin/main, Merge PR #535, Fix #531), `pubspec.yaml` 1.2.3+31
**Fingerabdruck** (`tool/check_release_review.sh --print` im Worktree, `logs/worktree_state.txt`): `7cb13574001bb6d6aa315ff265fe609bb8929f24` (wie erwartet)
**Gerät:** Android-Emulator, eigenes AVD `FN_E2E_B31N` (Pixel 8, API 35, Google APIs Playstore, arm64, 4 GB, `-wipe-data`, Port 5570). AVDs des Nutzers unberührt; AVD, Emulator und Worktree nach dem Lauf entfernt.
**Build-Art:** Debug-APK arm64 im Worktree auf b863d06 ohne Änderungen, einmal regulär, einmal Vorschau-Einstieg (`-t tool/preview/preview_main.dart`, Fake-Server, erfundene Daten). Kein Release-/AAB-Build. Installiert: versionCode 31, versionName 1.2.3 (`logs/package_regular.txt`).
**Tester:** Tester-Agent; kein Code geändert, nichts committet. Bedienung per `adb` und `uiautomator dump` (ui.py aus `User E2E Test/Default_test_G1-G2/sandbox/`, nur Portnummer angepasst). Vorläufe unverändert (Lauf 34 auf 9e55155 als Vorlage).

## Zusammenfassung
Keine ❌. Pflichtteil, alle wiederholten Oberflächenschritte und die neue Prüfung #531 (Standardfall) bestanden. Das Szenario „Dialog über dem AvatarScreen“ ist am Gerät nicht erzeugbar und nur als Code-Test belegt. Server-/Zwei-Konten-Abläufe und `tool/e2e.sh` bleiben ⏳ nicht getestet.

| ID | Schritt | Ergebnis | Beleg | Screenshot |
|---|---|---|---|---|
| P-ANA | `flutter analyze` | ✅ | `logs/analyze.txt`: „No issues found!“, exit 0 | - |
| P-TEST | `flutter test` | ✅ | `logs/flutter_test_full.txt`: „+2627 ~115: All tests passed!“, exit 0 | - |
| P-531 | `flutter test test/features/avatar_ui_test.dart` (Gruppe „#531: schließt nur die eigene Route“: Dialog darüber, Echo kommt bzw. Frist läuft ab; Dialog bleibt) | ✅ Code-Test | `logs/avatar_ui_test.txt`: „+19: All tests passed!“, exit 0. Rot ohne Fix wurde hier nicht erneut ausgeführt (Aufgabe des Issue-Ablaufs) | - |
| P-BLD | Debug-APK regulär und Vorschau | ✅ | `logs/build_regular.txt`, `logs/build_preview.txt`: Built | - |
| RT3-V-01 | pubspec 1.2.3+31, Fingerabdruck | ✅ | `version: 1.2.3+31`; `7cb1357…` | - |
| RT3-V-02 | Menü „Version 1.2.3 (31)“ | ✅ | `logs/ui_menu.txt`: `Version 1.2.3 (31)`; Bild angesehen | `screenshots/RT3-V-02_And.png` |
| RT3-V-05 | Einstellungen unten „Version 1.2.3 (31)“ | ✅ | `logs/ui_V05.txt`; Bild angesehen | `screenshots/RT3-V-05_And_Einstellungen_Version.png` |
| RT3-V-03 / #144 | Frische reguläre Installation: Willkommensseite (EN), 3 Optionen; Fenster `SECURE`, Bild schwarz | ✅ | `logs/ui_welcome.txt`, `logs/secure_regular.txt` (`fl=... SECURE ...`) | `screenshots/RT3-V-03_And_Willkommen_schwarz-FLAG_SECURE.png` (schwarz, nur Beleg für FLAG_SECURE, nicht als Oberflächenbeleg gezählt) |
| RT3-A-06 | Vorschau: Heute (Termine, Erinnerungen, Einkaufszettel, 5 Tabs) | ✅ | `logs/ui_A06.txt`; Bild angesehen | `screenshots/RT3-A-06_And.png` |
| RT3-E-01 | Kalender: Tag/Woche/Monat/Agenda, November 2026, Mitgliederfilter | ✅ (Oberfläche, Vorschau) | `logs/ui_E01.txt`; Bild angesehen | `screenshots/RT3-E-01_And.png` |
| RT3-C-01 | Chat-Tab beginnt mit Gesprächsliste (Familienchat, Einzelchat Ben, Ungelesen) | ✅ (Vorschau) | `logs/ui_C01.txt` | `screenshots/RT3-C-01_And.png` |
| RT3-C-02/C-13/K-01 | Familienchat; „Nachricht von Ben / dir / Clara“, „Ende-zu-Ende-verschlüsselt“ als Semantik | ✅ (Vorschau, ohne TalkBack) | `logs/ui_C02.txt` | `screenshots/RT3-C-02_Familienchat_And.png` |
| RT3-C-04 | Familienchat offen > Einkauf > Chat: Gespräch bleibt, 3 Nachrichten | ✅ | `logs/ui_C04.txt`: 3 Knoten „Nachricht von“ | `screenshots/RT3-C-04_And.png` |
| Einkauf | Einkauf-Tab | ✅ (Oberfläche) | `logs/ui_K01.txt` | `screenshots/RT3-K-01_Einkauf_And.png` |
| RT3-D-01 | Familie-Tab: Name, Einladung, Familien-Code, Themen, Mitglieder | ✅ (Vorschau) | `logs/ui_D01.txt` | `screenshots/RT3-D-01_Familie_And.png` |
| RT3-R-01 | Einstellungen: Sprache, Design, Akzentfarben, Effekte reduzieren, Konto | ✅ | `logs/ui_settings.txt` | `screenshots/RT3-R-01_Einstellungen_And.png` |
| RT3-R-07 / #501 Dunkel | Statusleisten-Symbole hell | ✅ | `logs/appearance_dark.txt`: ohne `LIGHT_STATUS_BARS`; Bild: Uhr/Akku weiß auf dunkel | `screenshots/RT3-R-07_And_Dunkel_Einstellungen.png` |
| RT3-R-07 / #501 Hell | Symbole dunkel auf hellem Grund (Einstellungen, Familie) | ✅ | `logs/appearance_light.txt`: `LIGHT_STATUS_BARS ...`; Bilder angesehen | `screenshots/RT3-R-07_And_Hell_Einstellungen.png`, `screenshots/RT3-R-07_And_Hell_Familie.png` |
| RT3-I-01 / #503 de | „App teilen“ zeigt „Link kopiert“ | ⚠️ | `logs/ui_I01_de.txt`: Knoten „Link kopiert“ vorhanden. Im Bild verdeckt das Android-Zwischenablage-Overlay (zeigt den kopierten Text „Ich nutze FamilyNexus …“) die Snackbar-Beschriftung; der Text selbst ist nur per uiautomator belegt, nicht im Bild lesbar | `screenshots/RT3-I-01_And_de_Link-kopiert.png` |
| RT3-I-01 / #503 en | „Share app“ zeigt „Link copied“ | ⚠️ | `logs/ui_I01_en.txt`: Knoten „Link copied“; Bild wie oben (Overlay verdeckt Text, Wiederholung nach 2 s gleich) | `screenshots/RT3-I-01_And_en_Link-copied.png` |
| NEU #531 (Standardfall) | Avatar > „Pfote“ wählen > Speichern: Bildschirm schließt, Rückkehr zur Familie-Seite | ✅ (Vorschau, Moderator Anna) | vorher `logs/ui_avatar_before.txt` (Titel „Avatar“, „Initialen (kein Avatar), Ausgewählt“), gewählt `logs/ui_avatar_picked.txt` (Vorschau „Pfote“, Speichern klickbar), nachher `logs/ui_avatar_after.txt`: Familie-Seite, „Avatar ändern“ wieder sichtbar, kein Avatar-Titel; Bilder angesehen | `screenshots/RT3-A-Avatar_vorher.png`, `screenshots/RT3-A-Avatar_Pfote_gewaehlt.png`, `screenshots/RT3-A-Avatar_nachher.png` |
| NEU #531 (Dialog über AvatarScreen während des Speicherns) | Verifizierungsdialog erscheint zwischen Speichern und Echo | ⏳ nicht ausführbar | Der Dialog kommt vom `VerificationListener` bei einer echten Verifizierungsanfrage eines zweiten Geräts; der Fake-Server der Vorschau erzeugt keine. Nur durch Code-Test P-531 belegt | - |
| T-03 | `tool/e2e.sh` | ⏳ | nicht ausgeführt (Docker/Synapse hier nicht gestartet) | - |
| C-xx, D-02…, E-02…E-11, F, G, H, P-01…P-08, P-15…P-17 | Server-/Zwei-Konten-/Matrix-Abläufe | ⏳ | kein Server für die App erreichbar | - |
| J, I (außer I-01), R-02…R-06, P-13/14, TalkBack | nicht wiederholt | ⏳ | keine Tablet-AVD, keine Schriftskalierung, kein TalkBack | - |
| G-04…G-08, G-14 | matrix.org, Fremdanbieter, Passkeys | ⏳ | keine Freigabe für echte Konten | - |

## Befunde
- **B1 (Hinweis):** Standard „Bildschirmschutz an“ (FLAG_SECURE) macht adb-Bilder der regulären App schwarz; Oberflächenbilder stammen aus dem Vorschau-Modus.
- **B2 (Hinweis):** Die Snackbar „Avatar gespeichert“ nach dem Speichern wurde nicht als Bild belegt; belegt ist das Schließen des Bildschirms (uiautomator, Bild).
- **B3 (Hinweis, Testwerkzeug):** Das Android-Zwischenablage-Overlay verdeckt die Snackbar bei „App teilen“ im Bild (I-01); kein App-Fehler, Text per uiautomator belegt.
- Die Speicherorte in den Einstellungen zeigen im Vorschau-Modus Linux-Pfade (`/home/test/...`): Eigenheit der Vorschau-Daten, nicht der regulären App.
- Keine neuen Fehler.

## Nicht ausgeführt / nicht getestet
Alle Serverabläufe, `tool/e2e.sh`, Tablet, Schrift 200 %, TalkBack, Release-/AAB-Build mit Signatur, echtes Gerät, #531-Szenario „Dialog darüber“ am Gerät. Gelten als nicht getestet, nicht als bestanden.
