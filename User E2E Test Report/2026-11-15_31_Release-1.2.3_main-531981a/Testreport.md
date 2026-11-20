# Testreport Lauf 31: Release 1.2.3 auf Simulator, Emulator und Mac (Testplan TP-FN-REL-123)

**Datum:** 15.11.2026 · **Getesteter Commit:** `531981a` (origin/main, Merge PR #493), `pubspec.yaml` 1.2.3+29 · **Plan:** `User E2E Test/Release_1.2.3_v01/Release-Test_1.2.3_v01.md` (Ausführung nach v03; der Plan wurde währenddessen auf v04 gehoben, Soll-Version 30).
**Bezug zu `main` heute (`e921f3f`):** Seit `531981a` änderten sich in `lib/`, `ios/`, `macos/`, `android/`, `test/` nur `lib/app/app_version.dart` und `pubspec.yaml` (Build-Nummer 29 → 30, PR #495). Die Befunde gelten damit für den App-Code von `main`; nur die Versionsschritte (RT3-V-01, V-02, V-05) erwarten „30“ und sind auf diesem Commit nicht erfüllbar.
**Tester:** vier getrennte Tester-Agenten (Android Vorschau-Modus, iOS/iPad, Mac, Dev) plus Nachprüfung durch den Hauptagenten (iPad-Start, E2E-Wiederholung). Keiner änderte Code. Kein Tag, keine Build-Nummer, kein Upload, keine echten Konten.

## Ergebnis in einem Satz

**Der Lauf belegt die Pflichtteile und einen Teil der Oberfläche auf Android, aber keines der Issues ist auf iOS, macOS oder Android vollständig abnehmbar.** Ursache sind nicht App-Fehler, sondern Werkzeuggrenzen: keine Tippsteuerung im iOS-Simulator, Schlüsselbund-Dialog auf dem Mac, nicht vertrauenswürdiges Zertifikat des lokalen Synapse in App und Emulator.

## Zählung (Zeilen der Ergebnisdateien, Schrittgruppen teils zusammengefasst)

| Bereich | ✅ | ⚠️ | ❌ | ⏳ | n/a | Datei |
|---|---|---|---|---|---|---|
| Dev (Pflichtteil, Dateien) | 11 | 4 | 0 | 2 | – | `Ergebnisse_Dev.tsv` |
| iOS / iPad (Simulator) | 7 | 4 | 2* | 28 | 5 | `Ergebnisse_iOS.tsv` |
| Mac (App, Entwicklungssignatur) | 2 | 4 | 0 | 19 | – | `Ergebnisse_Mac.tsv` |
| Android (Vorschau-Modus, Pixel 8 und Tablet) | 23 | 32 | 0 | 63 | 4 | `Ergebnisse_Android.tsv` |

\* Die zwei ❌ (RT3-A-01/A-02 iPad: nur Startbild) sind **nicht reproduzierbar**: Ein Neustart auf dem iPad Pro 13" zeigt die Willkommensseite (`screenshots/X-IPAD-RERUN_40.png`); der Bogen unten rechts war das Debug-Banner. Eingestuft als ⚠️ (langsamer Debug-Start bei voller Platte und Parallellast; Startzeit nur am Release-Build/Gerät belegbar).

## Belegt (✅)

- **Pflichtteil:** `flutter analyze` ohne Befund; `flutter test` 2591 bestanden, 0 fehlgeschlagen (zwei Läufe, ein erster hing bei vollem Datenträger); CI auf `531981a` alle fünf Jobs grün; Web-Rauchtest 5/5; Mutationsprobe L-05 (zwei Tests rot ohne `local:`); Release Notes, Datenschutz, README, ARCHITEKTUR.md; Bildpaket #349 (14 PNG, 1080×1920, kein Alpha, Test 35/35).
- **Builds:** iOS-Simulator, macOS (debug) und Android-APK (regulär und Vorschau) gelingen mit `webview_flutter` (T-08).
- **Android (Vorschau-Modus, uiautomator, kein TalkBack):** Avatar-Auswahl (D-01), Kalender-Themen-Farben (E-01), Jahresfortschritt (E-07), Gespräch bleibt beim Tab-Wechsel (C-04), Semantik „Nachricht von dir“ und Einzelchat-Label (C-13, K-01, K-02, K-05), englische Monatszellen (P-09), Editor bei Schrift 200 % (P-13), `FLAG_SECURE` (#144 Android), Tablet-Layout Rail ab 600 dp und zweispaltig ab 1000 dp (J-01, J-03, C-07).
- **iOS:** Simulator-Integrationstests `db_security` (6) und `event_store` (10) grün.
- **E2E (T-03, `tool/e2e.sh` gegen lokalen Synapse):** 110 bestanden, 1 Zeitüberschreitung (30 s) in `gateway_security_e2e_test.dart` „eigener Termin: Scan im Zustand gesendet, danach Echo“ unter Last; Einzelwiederholung grün (5 s). Der Anhang-Download-Test (#458, Foto) lief grün. **Keine Aussage** zu `set_presence` (#451) gegen echten Synapse: Es gibt dafür keinen eigenen E2E-Test, nur den Dart-Regressionstest.

## Befunde (⚠️, zur Klärung; keine bestätigten App-Fehler außer wo vermerkt)

| Nr. | Befund | Einordnung |
|---|---|---|
| B1 | **#350 „App bewerten“ (I-03):** Tap löst keine Aktivität aus, kein Fehlerhinweis; ein adb-VIEW-Intent auf denselben Link öffnet den Play Store | Ursache offen (Emulator, Vorschau-Fake oder echter Fehler); am Gerät/regulär nachprüfen, vermutlich neues Issue |
| B2 | **E-02 Themen-Chips fehlen** unter „Geteilt“ im Termin-Editor, obwohl Thema „Schule“ angelegt | Vorschau-Fake oder Fehler (#424); mit echtem Server prüfen |
| B3 | **J-04 Schrift 200 % (Telefon):** „Fußballtrainin\|g“, „Woch\|e“, „Agend\|a“ brechen im Wort, Filterchips laufen rechts heraus | bekannt aus Lauf 22 (#274); weiter offen |
| B4 | **R-07 Hell-Theme:** Statusleisten-Symbole weiß auf hellem Grund | Android-Darstellung prüfen |
| B5 | **H-03 Tour:** letzter Schritt „Let’s go“ statt „Überspringen“ | Planabweichung klären (Plan: Überspringen jederzeit) |
| B6 | **I-01 App teilen:** Text „Link zum Store-Eintrag kopiert“ statt „Link kopiert“ | Wortlaut im Plan oder in der App angleichen |
| B7 | **Android-Standard Bildschirmschutz an** (`app_settings.dart:17`): adb-Screenshots der regulären App sind schwarz | Hinweis für künftige Läufe, kein Fehler |
| B8 | **iPad Ersttest ❌** nicht reproduzierbar (siehe oben) | Startzeit am Release-Build/Gerät nachmessen |
| B9 | `integration_test/manual/ui_tour_test.dart` bricht ab (Tab „Einstellungen“ nicht gefunden), `store_screenshots_test.dart` bricht an mehrdeutigem „Ben“ ab | veraltete Testskripte nach Gesprächsliste; nicht Teil der Gates, Folge-Issue prüfen |
| B10 | **#486** ändert Swift (`AppDelegate.swift`, `MainFlutterWindow.swift`), nur durch Dart-Test belegt | Nachtest G-12 auf iOS und Mac nötig |
| B11 | **#485** ohne Eintrag in `ENTSCHEIDUNGEN.md`; „Gesprächsleiste“ noch in `KONTAKTE.md` und `ENTSCHEIDUNGEN.md` | Unterlagen nachziehen |
| B12 | Flatpak-Metainfo `1.2.3` mit Datum 10.11., vor Build 29/30 | Datum beim Release prüfen (E10) |

## Nicht ausgeführt (⏳) und Grund

1. **Mac (19 Zeilen, u. a. 46 Mac-Zeilen aus #381):** macOS fragt beim Start nach dem Schlüsselbund-Passwort für `flutter_secure_storage_service`. Es wurde nichts eingegeben und kein Systemzertifikat vertraut.
2. **iOS (28 Zeilen):** keine Tippsteuerung im Simulator (`idb` nicht vorhanden, nichts installiert). Das Synapse-Root-Zertifikat war im iPhone-Simulator vertraut; ohne Bedienung lief kein Serverschritt.
3. **Android (63 Zeilen):** Vorschau-Modus ohne Server; alle Zwei-Konten- und Server-Abläufe (C, D, E, F, G, P-01…P-08) offen. Das selbstsignierte Zertifikat des Test-Synapse ist in der App auf Android nicht zulassbar (Play-Store-Image, kein Root).
4. **Matrix.org, Fremdanbieter, Passkeys (G-04…G-08, G-14):** keine Freigabe für echte Konten.
5. **P-12 `appstreamcli`:** nicht installiert.
6. **P-02/P-03 Oberflächenteile:** echter Hilfsclient-Flut-Test fehlt im Repo; Netzabbruch-Test nicht ausgeführt.

## Abnahme der Issues (Plan Abschnitt 14, ehrlich)

**Kein Issue erfüllt „alle Schritte ✅ und Rest ‚–‘“ auf iOS, macOS und Android.** Teilbelege:

- **Android teilweise belegt:** #144 (Android-Teil), #274 (Telefon/Tablet-Layout; J-04 ⚠️), #332 und #463 (Semantik, kein TalkBack), #345/#316 (nur Ablauf), #422/#423/#424 (Oberfläche; Zwei-Konten offen), #445 (Editor-Gegenprobe).
- **Dateien/Dev belegt:** #446, #447, #449 (P-10, P-11 ✅), #448 (Datei ✅, `appstreamcli` ⏳), #440 (L-05 ✅, optional E2E), #349 (Bildpaket ✅, Upload manuell).
- **Nicht belegt:** #254, #381, #266, #268, #297, #441, #450, #451, #458, #317, #326, #350, #351 (B1), #483 bis #486 am Gerät.
- **Nicht Teil der Abnahme:** #15, #348 (manuell), #263, #325, #330 (Windows).

## Voraussetzungen, damit ein Wiederholungslauf Issues schließen kann

1. **Server für die App erreichbar:** Test-Synapse mit von der App akzeptiertem Zertifikat (iOS-Simulator: Root per `simctl keychain` vertrauen und App neu starten; Android: rootbares AVD ohne Play Store oder Testbuild mit Testzertifikat; Mac: Zertifikat im Schlüsselbund oder Testserver mit gültigem Zertifikat).
2. **Bedienbarkeit:** Tippsteuerung (z. B. `idb` oder Flutter-`integration_test`-Szenarien) für iOS und Mac; Schlüsselbund-Zugriff auf dem Mac freigeben.
3. **Build 30 vom aktuellen `main`** (`e921f3f` oder neuer) statt 29.
4. Entscheidung E12 (Schließen mit Rest am Gerät).

## Nachtrag: Wiederholungslauf iOS/iPad mit `idb` (Commit `e921f3f`, Version 1.2.3+30, Debug-Build)

Datei: `Ergebnisse_iOS_idb.tsv` (Screenshots `screenshots/idb_*`, Logs `logs/ios_idb_*`). Zwei Simulatoren (iPhone 17 Pro = G1, iPad Pro 13" = G2) gegen den lokalen Synapse, Wegwerfkonten, Root-Zertifikat nur im Simulator vertraut. Zeilen: **57 ✅, 20 ⚠️ (davon 7 reine Beobachtungen), 0 ❌, 61 ⏳, 8 n/a**. Die Zählung habe ich gegen die TSV geprüft; P-06 stichprobenartig am Screenshot (Dora erscheint bei Carl nur noch als „Eben noch online“, nicht als online; das ist eine Momentaufnahme kurz nach dem Umschalten, kein Beleg für den späteren Zustand).

**Neu belegt auf iOS/iPad:** Version „1.2.3 (30)“ (V-02), Heute-Karten je einmal (B-01), Gesprächsliste und Chat (C-01…C-09, C-13), Avatare (D-01, D-03, D-04, D-06), Themen im Editor inkl. Mitglieds-Sicht (E-01, E-02, E-04; der Android-Befund B2 tritt auf iOS **nicht** auf), Jahresfortschritt (E-07), Systemdialog und lokale Meldung (F-01 bis F-03), Konto anlegen/abmelden/anmelden am lokalen Synapse (G-01), Einführungstour (H-01, H-02), Teilen/Bewerten-Einträge (I-01, I-04), Datenübersicht de/en (I-08), Semantikbaum (K-01…K-05), **Zwei-Konten-Fixes #450 (P-05) und #451 (P-06)**, #463 (P-09, Semantik), Editor bei Schrift 200 % (P-13), Rauchtest (R-01, R-08), Konto löschen (Z-01).

**Neue Befunde (zur Klärung, noch nicht als Issue):**

| Nr. | Befund | Einordnung |
|---|---|---|
| B13 | **Einladungslink eines Servers mit Port** trägt den Anbieter ohne Port; Beitritt zeigt „localhost ist gerade nicht erreichbar“, bis der Anbieter von Hand auf `localhost:18448` gesetzt wird (zweimal reproduziert) | betrifft Heimnetz-/Entwicklungsserver mit Port; vermutlich echter Fehler, Issue prüfen |
| B14 | Heute-Karte „Erinnerungen“ zeigt zugleich „Keine Erinnerung geplant“ und „2 Erinnerungen fällig“ | widersprüchlicher Text, #317-Umfeld; Issue prüfen |
| B4 (iOS) | Statusleistensymbole weiß auf hellem Grund im Hell-Design | wie Android: bestätigt auf beiden Plattformen |
| B3 (iOS) | Schrift 200 %: „Woch/e“, „Mona/t“, „Agen/da“, abgeschnittene Platzhalter im Einkauf; Mitglieds-ID bricht mitten im Wort | bestätigt #274 auf iPhone |
| B15 | Avatar-Dialog: nach „Speichern“ bleibt der Dialog offen, Schaltfläche deaktiviert, keine sichtbare Rückmeldung (1-s-Stichprobe) | beobachten; Avatar kam beim Mitglied an |
| B16 | Einführungstour erscheint nach erneuter Anmeldung desselben Kontos wieder, bei neuen Konten auf demselben Gerät nicht | Soll prüfen (E-95) |
| B17 | P-14: Ende vor Beginn zeigt inline „Das Ende muss nach dem Beginn liegen.“ statt „… nicht gespeichert“ | Plan-Wortlaut anpassen; `eventSaveError`-Pfad nicht auslösbar |

**Weiterhin ⏳ (Grund):** eingebettete Anmeldung (G-09 bis G-13, J-08, P-15 bis P-18): der lokale Synapse hat keinen OAuth-Anbieter, ohne App-Code ist keine Testseite einhängbar; G-04 bis G-08 und G-14 ohne Freigabe; Zeitwähler-Eingabe per `idb` nicht möglich (F-06, B-05, E-11); Systemdatum (P-07), Emoji-Eingabe (P-08); iPad-Querformat und Split View; P-04 (Sync schneller als der Tipp), D-07/D-08 (keine Familie vor 1.2.3), F-04 (Zähler am Symbol nur am echten iPhone); Video- und Startzeitbelege (A-03, A-04, A-07).

**Abnahme iOS/iPad (Abschnitt 14), ehrlich:** weiterhin **kein Issue vollständig abnehmbar**. Am weitesten: #450 und #451 (Zwei-Konten-Schritt ✅; #451 ohne eigenen E2E gegen Synapse), #423, #422, #424 (Hauptschritte ✅, Randschritte ⏳), #144 (iOS-Text ✅), #317 (B-01 ✅). Nicht belegbar ohne neue Mittel: #441, #297, #486 (eingebettete Ansicht), #316/#345 (Startzeit/Video), #445 (P-04), #458, #326, #274 (Querformat).

**Zugangsdaten/Aufräumen:** Zwei erste Wegwerfkonten (`annagonea1`, `bobgonea2`) bleiben auf dem lokalen Synapse (Notfall-Schlüssel nicht gesichert, nicht mehr anmeldbar); der Test-Synapse ist Wegwerf und wird mit `tool/synapse/down.sh` entfernt. Passwörter liegen nur unter dem Scratchpad `secure/`, nicht im Report.
