# Testplan FamilyNexus (Gesamtplan)

**Planversion: 1.4** (27.10.2026) · Dokument-ID `TP-FN-001` · Änderungen siehe „Versionshistorie“ am Ende und Anhang E. Reports und Issues nennen Planversion und Git-Commit (z. B. „TP-FN-001 v1.0 @ 4abf400“).

Ersetzt: `Testplan_Nutzeranlage.md`, `Testplan_Pruefanleitung.md`, `Testplan_Einladung_Zweiter_Nutzer.md`, `Testdaten_Stammdaten.md` (Zuordnung der alten IDs: Anhang C)
Bezug: `Massnahmenplan_App_Store_Review.md` (Maßnahme 6), Issues #10–#14, Nachtest #15
Soll-Version der App: `version:` in `pubspec.yaml` auf aktuellem `main` (beim Schreiben **1.2.1+16** = „1.2.1 (16)“) · Stand: 27.10.2026 (überarbeitet nach den Läufen vom 26./27.10.2026, siehe Anhang E). **Achtung:** Die Build-Nummer 16 gibt es mit und ohne den Fix aus PR #22 (`88dc3ca` setzte 1.2.1+16 vor dem Merge `d20f0e0`); im Report daher immer auch den Commit des installierten Builds nennen

## 1. Ziel und Aufbau

Ein Testlauf prüft **jede Funktion der App mindestens einmal** (Nachweis: Abdeckungsmatrix, Abschnitt 6) mit zwei Geräten gegen den Testserver. Konten, Familien und Beispieldaten entstehen einmal im Lauf und werden danach weiterverwendet (Abschnitt 3).

Jeder Testschritt steht in **einer** Tabellenzeile: Beschreibung des Schritts, erwartetes Ergebnis und daneben das **beobachtete Ergebnis**, der **Screenshot** (Dateiname) und das Ergebnis. Die Spalten „Beobachtet“, „Screenshot“ und „Erg.“ füllt der Tester während des Laufs in einer Kopie dieses Plans aus. Diese Kopie ist der Testreport.

| Abschnitt | Inhalt |
|---|---|
| 2 | Festlegung von Plattform und System (vor Testbeginn ausfüllen) |
| 3 | Testserver, Konten und Stammdaten |
| 4 | Vorbereitung: Version prüfen und installieren, lokale Daten löschen, Server und Namen prüfen |
| 5 | Testschritte A bis H |
| 6 | Abdeckungsmatrix (jede Funktion → Testschritt) |
| 7 | Abnahme und Report |

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ offen (mit Grund) · n/a (auf der festgelegten Plattform nicht vorhanden, mit Grund)

## 2. Festlegung von Plattform und System (Pflicht, vor dem ersten Schritt)

Vor dem Lauf wird für **beide Geräte** festgelegt und im Report eingetragen, auf welcher Plattform und welchem System getestet wird. Ohne vollständige Tabelle beginnt der Test nicht.

| Angabe | G1 (Gerät 1) | G2 (Gerät 2) |
|---|---|---|
| Plattform (iOS / iPadOS / macOS / Android / Linux / Windows / Web) | | |
| Gerät oder Simulator/Emulator (Modell, Name) | | |
| Betriebssystem und Version (z. B. iOS 27.1, macOS 27.0, Android 16 / API 36) | | |
| Bei Web: Browser und Version | | |
| Installationsquelle (TestFlight, App Store, DMG, APK, Build aus `main` …) | | |
| App-Version Soll (aus V-01) / Ist (aus V-02) | | |
| Gerätesprache, Bildschirmsperre eingerichtet (ja/nein) | | |
| Methode für Screenshots (siehe unten) | | |
| Tester / Datum / Uhrzeit Beginn | | |

**Vorgaben:**
- Für die Einreichung bei Apple gilt: **G1 = iPhone** (Gerät oder iOS-Simulator), **G2 = Mac**. Ein Lauf auf anderen Plattformen ist erlaubt, ersetzt aber nicht den Apple-Lauf; der Report nennt die Abweichung auf der ersten Seite.
- Beide Geräte testen dieselbe Soll-Version.
- Plattformabhängige Bedienung: „lange drücken“ heißt auf dem Mac „klicken und halten“ (oder Rechtsklick), „Zurück-Geste“ heißt auf dem Mac Esc bzw. der Pfeil oben links, auf Android zusätzlich die Systemtaste „Zurück“.
- Schritte, die es auf der gewählten Plattform nicht gibt (z. B. G-08 nur für Web), werden mit „n/a“ und Grund eingetragen. Gibt es eine Funktion nur auf einem der beiden Geräte (Linux/Windows: keine App-Sperre, kein Bildschirmschutz, kein Hinweis „Benachrichtigungen sind blockiert“), wird der Schritt auf dem anderen Gerät ausgeführt und das im Report vermerkt (B-02, B-17, B-18).
- **Rollenzuordnung der Geräte:** Die Schritte nennen nur G1 und G2. Wird G1 = Mac und G2 = iPhone/Simulator gewählt (oder umgekehrt), gelten alle Schritte unverändert; im Report steht die Zuordnung in der Tabelle oben. Der Gerätename in der Geräteliste und im Symbolvergleich lautet „FamilyNexus <Plattform>“, also „FamilyNexus macOS“, „FamilyNexus iOS“, „FamilyNexus Android“, „FamilyNexus Linux“ bzw. „FamilyNexus Windows“ (nicht der Name des Geräts).
- **Automatisierte Bedienung** (Eingabe per Skript/Werkzeug): Voraussetzungen und bekannte Einschränkungen stehen in Anhang D. Abweichende Schreibweisen (z. B. „Loeschtest“ statt „Löschtest“) sind zulässig, wenn sie im Report vermerkt werden.

**Screenshots je Plattform:**

| Plattform | Methode |
|---|---|
| iOS-Simulator | `xcrun simctl io booted screenshot <Datei>.png` |
| iPhone/iPad | Seitentaste + Lauter; Bildschirmaufnahme für flüchtige Bildschirme |
| macOS | `screencapture -o -l <Fenster-ID> <Datei>.png` oder ⇧⌘4, Leertaste |
| Android-Emulator | `adb emu screenrecord screenshot <Datei>.png` oder `adb exec-out screencap -p > <Datei>.png`; „Bildschirmschutz“ ist ab Werk **an** (FLAG_SECURE), `adb screencap` liefert dann ein schwarzes Bild – für den Lauf in den Einstellungen ausschalten und das im Report vermerken (B-18 schaltet ihn gezielt an und aus) |
| Android-Gerät | „Bildschirmschutz“ in den Einstellungen erst nach Schritt B-16 aus; davor Foto mit zweitem Gerät |
| Linux | Bildschirmfoto-Werkzeug des Systems (z. B. `spectacle -b -n -a -o <Datei>.png`); bei Bedienung per Skript auf eigenem X-Server siehe Anhang D |
| Windows / Web | Bildschirmfoto-Werkzeug des Systems bzw. des Browsers |

**Dateinamen:** `<Schritt-ID>-<Gerät>.png` (z. B. `E-14-G2.png`); bei mehreren Bildern ein Buchstabe (`E-14a-G1.png`). Ablage: `Test-Apple-Report/<JJJJ-MM-TT>/screenshots/`. Notfall-Schlüssel und Passwörter werden vor der Weitergabe geschwärzt.

## 3. Testserver, Konten und Stammdaten

| Angabe | Wert |
|---|---|
| Anbieter-Adresse (in der App eingeben) | `matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| Servername in den Matrix-IDs | `matrix.chaostribunal.de` → IDs lauten `@<name>:matrix.chaostribunal.de` |
| Anmeldung | Benutzername + Passwort in der App (kein OAuth, kein Browser) |
| Registrierung | muss offen sein (`m.login.dummy`), außer im optionalen Schritt D-07 |
| Kontolöschung | in der App mit Passwort (`/account/deactivate`, `erase`) |

**Besonderheiten dieses Servers:**
- Die App schlägt immer `matrix.org` vor (E-70). Vor jeder Kontoanlage und Anmeldung unter **„Erweitert“ → „Anderen Anbieter verwenden“** die Anbieter-Adresse eintragen; weiter erst, wenn „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“ steht.
- Beim Anmelden **nur den kurzen Benutzernamen** eingeben (`fnt-…`), nie die vollständige ID; `matrix.chaostribunal.de` ist nicht erreichbar.
- Einladungslinks: im Einladungsdialog „Erweitert“ → „Konto-Server für Neue“ auf die Anbieter-Adresse setzen, sonst zeigt der Link auf den unerreichbaren Servernamen (E-05).
- Bei matrix.org wird in diesem Plan **kein** Konto angelegt.

**Konten** (werden im Lauf angelegt; `MMTT` = Datum des Laufs, am selben Tag Buchstaben anhängen, z. B. `1027b`):

| Kürzel | Benutzername | Anzeigename | Gerät | angelegt in | gelöscht in |
|---|---|---|---|---|---|
| **N1** | `fnt-MMTT-n1` | Test N1 | G1 (auch auf G2 angemeldet in C) | A-09 | F-06 |
| **N2** | `fnt-MMTT-n12` (Vorschlag der App) | Test N2 | G2 | D-01 | F-01 |
| **I2** | `fnt-MMTT-i2` | Test Nutzer 2 | G2 | E-09 (über Einladungslink) | E-32 |

**Notfall-Schlüssel:** KN1 (N1, A-10, ungültig ab C-05), KN1b (N1, C-05), KN2 (N2, D-01), KI2 (I2, E-10).
**Familien:** F1 „Testfamilie MMTT“ (N1, A-11; I2 tritt in E-11 bei), F2 „Löschtest MMTT“ (N2, D-03).
**Beispieldaten in F1:** in Abschnitt B angelegt (Termine, Chat, Einkauf, Aufgabenliste) und in E weiterverwendet.

Passwörter erzeugt der Tester beim Anlegen (mind. 8 Zeichen, Passwortmanager). Passwörter und Schlüssel stehen weder im Plan noch im Report, sondern nur im Passwortmanager oder in `../secure/` (von Git ignoriert).

**Reihenfolge ist verbindlich:** A → B → C → D → E → F. Konten werden **erst in F** (und in E-32) gelöscht. Vor F-01 müssen alle Schritte E-01 bis E-31 (insbesondere die Mehrnutzer-Schritte E-14 bis E-27) abgeschlossen oder begründet als ⏳ eingetragen sein; wer F früher beginnt, verliert die Konten für diese Schritte (so im Lauf vom 26.10. geschehen: E-14 bis E-27 fehlten). Vor dem Beginn von F die Abnahme von E im Report abhaken.

**Namen aus früheren Läufen:** Gelöschte Konten bleiben auf dem Server als „vergeben“ (`M_USER_IN_USE`). Am selben Tag erhält jeder Lauf einen eigenen Datumsteil (`1026`, `1026b`, `1026c` …). Altkonten eines abgebrochenen Laufs sind im Report als Zustand am Ende (F-08) zu führen.

**Regeln:** Vorhandenes wird wiederverwendet, nicht neu angelegt. Braucht ein Schritt ein Konto auf dem anderen Gerät, wird angemeldet (Benutzername, Passwort, Notfall-Schlüssel). Aufgeräumt wird am Ende (F), nicht nach jedem Abschnitt. Bricht der Lauf ab, F-06 bis F-08 für alle noch bestehenden Konten ausführen.

## 4. Vorbereitung (vor jedem Lauf, Ergebnis im Report)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| V-01 | – | **Soll-Version ermitteln:** `git fetch origin && git status -sb` (main = origin/main, sonst `git pull --ff-only`); `grep '^version:' pubspec.yaml` | Soll-Version und Build stehen fest (z. B. `1.2.1+16`); in Abschnitt 2 eintragen | | – | |
| V-02 | G1, G2 | **Ist-Version prüfen:** Mac: `defaults read /Applications/FamilyNexus.app/Contents/Info CFBundleShortVersionString` und `… CFBundleVersion`; iOS-Simulator: `xcrun simctl listapps booted \| grep -A12 -i familynexus` (Ausgabe: `CFBundleShortVersionString`, `CFBundleVersion`); iPhone: TestFlight zeigt den Build; Android: `adb shell dumpsys package de.inneso.familynexus \| grep version`; Linux-Flatpak: `flatpak info de.inneso.familynexus` und `flatpak run --command=cat de.inneso.familynexus /app/familynexus/data/flutter_assets/version.json` (`build_number`); sonst nach dem Start im Menü unten „Version …“ | Ist = Soll auf beiden Geräten. Bei Abweichung oder fehlender App weiter mit V-03, sonst V-04 | | V-02-G1, V-02-G2 | |
| V-03 | G1, G2 | **Aktuellste Version installieren** (nur bei Abweichung): iOS: neuesten TestFlight-Build installieren; fehlt er, `tool/build_ios_release.sh` und hochladen bzw. im Simulator entweder `flutter run -d <Simulator>` oder `flutter build ios --simulator --debug` und `xcrun simctl install booted build/ios/iphonesimulator/Runner.app` (aus `main`). macOS: `tool/build_macos_dmg.sh`, App nach `/Applications` kopieren. Android: `flutter build apk` und `adb install -r build/app/outputs/flutter-apk/app-*.apk`; **x86_64-Emulator:** die Release-APK v1.2.1 stürzt dort beim Start ab (Issue #32) → `flutter build apk --debug` aus `main` bzw. einen arm64-Emulator verwenden und das im Report vermerken. Linux: Flatpak-Bundle aus dem Release (`flatpak install --user FamilyNexus-v1.2.1.flatpak`, `.sha256` prüfen) oder `tool/build_appimage.sh`. Web: `tool/build_web.sh`. Release-Dateien von GitHub nur, wenn ihr Build dem Soll entspricht (Release v1.2.1: Build 16 aus `85d9245` für APK/AAB, Flatpak, AppImage, Windows und Web; macOS-DMG noch Build 14). Danach V-02 wiederholen | Ist = Soll auf beiden Geräten | | V-03-G1, V-03-G2 | |
| V-04 | G1, G2 | **Lokale Daten löschen:** App starten. Zeigt sie nicht „Willkommen“: Einstellungen → „Alle lokalen Daten löschen“ → „Endgültig löschen“ (bei gesperrter oder kaputter Datenbank: „Lokale Daten zurücksetzen“). Achtung iOS/macOS: Löschen der App allein reicht nicht, der Schlüsselbund bleibt; deshalb immer über die App löschen. Danach App beenden und neu starten | Nach dem **Neustart** „Willkommen“ mit drei Wegen und Sprachwahl. Direkt nach dem Löschen „Willkommen“ (Builds **ohne** PR #22, d. h. vor Commit `d20f0e0`, zeigen „Anmelden“ (Befund B-1, Issue #23) → ⚠️; das gilt auch für frühe Builds mit der Nummer 16. Builds ab `d20f0e0`, z. B. die Release-Dateien v1.2.1 vom 26.10.2026 außer der macOS-DMG, zeigen „Willkommen“. Maßgeblich ist der Commit aus V-01/V-03, nicht die Build-Nummer). Erscheint auch nach dem Neustart „Anmelden“ oder ein altes Konto → Schritt wiederholen. **Linux-Flatpak:** Liegen Daten einer fremden Sitzung vor, den Ordner `~/.var/app/de.inneso.familynexus` nicht löschen, sondern vor dem Lauf umbenennen und danach zurücklegen (der Schlüsselbund liegt im selben Ordner). **iOS-Simulator, falls „Endgültig löschen“ nicht reagiert:** `xcrun simctl uninstall booted de.inneso.familynexus`, `xcrun simctl keychain booted reset`, App neu installieren (V-03) | | V-04-G1, V-04-G2 | |
| V-05 | – | **Server prüfen:** `S=https://matrix-synapse-3ues.srv1348446.hstgr.cloud; curl -s $S/_matrix/client/versions; curl -s -X POST -H 'Content-Type: application/json' -d '{}' $S/_matrix/client/v3/register` | JSON mit `"versions"`; Registrierung liefert `flows` mit `m.login.dummy`, **nicht** „Registration has been disabled“ | | – (Konsolenausgabe im Report) | |
| V-06 | – | **Benutzernamen frei:** `for u in fnt-MMTT-n1 fnt-MMTT-n12 fnt-MMTT-i2 fnt-MMTT-n9; do echo "$u: $(curl -s "$S/_matrix/client/v3/register/available?username=$u")"; done` | Alle `{"available":true}`; bei `M_USER_IN_USE` (auch bei Altkonten desselben Tages) Datumsteil ändern (`1026b` …), Tabelle in Abschnitt 3 anpassen, wiederholen. Im Report notieren, welche Namen vorher belegt waren. Suffix durchprobieren (`1027`, `1027b`, `1027c` …) bis alle vier Namen frei sind; fremde oder alte Konten (z. B. `fnt-1026c-n1` ohne eigenen Lauf) niemals benutzen oder löschen | | – | |
| V-07 | G1, G2 | Systemeinstellungen: Gerätesprache notieren; Bildschirmsperre (PIN/Code) eingerichtet (für B-17); Benachrichtigungen der App nicht vorab erlaubt | Stand notiert; Bildschirmsperre vorhanden | | – | |

## 5. Testschritte

### A. Start und Kontoanlage in der App (G1, N1)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| A-01 | G1 | Startseite ansehen | „Willkommen bei FamilyNexus“ mit „Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“; Hinweise (keine Telemetrie, Ende-zu-Ende-Verschlüsselung, private Termine bleiben auf den Geräten); unten „Sprache“ mit „Gerätesprache“, „Deutsch“, „English“; kein eigener Sprach- oder Server-Schritt | | A-01-G1 | |
| A-02 | G1 | „English“ antippen, danach „Deutsch“ | Texte wechseln sofort in die gewählte Sprache, ohne Neustart; danach Deutsch | | A-02a-G1, A-02b-G1 | |
| A-03 | G1 | „Neue Familie gründen“, Anbieter nicht ändern | „Konto erstellen“, „Schritt 1 von 3“; „Bei matrix.org legst du dein Konto auf der Seite des Anbieters an. …“, Feld „Wie heißt du?“, „Konto bei matrix.org erstellen“ (**nicht antippen**); „Dein Konto liegt bei matrix.org.“ | | A-03-G1 | |
| A-04 | G1 | „Erweitert“ → „Anderen Anbieter verwenden“ → „Adresse des Anbieters“: `nicht-vorhanden.invalid` | Fehlermeldung, z. B. „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“; „Konto erstellen“ nicht nutzbar | | A-04-G1 | |
| A-05 | G1 | Adresse ändern auf `matrix-synapse-3ues.srv1348446.hstgr.cloud` | „Verbinde mit …“, dann „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“, „Betreiber: …“, „Kontakt: …“, Hinweis zu Metadaten; Felder „Wie heißt du?“, „Dein Benutzername“, „Passwort“ mit Hinweisen; „Konto erstellen“ ausgegraut | | A-05-G1 | |
| A-06 | G1 | **Namensvorschlag:** „Wie heißt du?“: `Joerg Muessig`, danach ändern auf `Jörg Müßig` (Umlaute über die Bildschirmtastatur) | Benutzername folgt dem Namen: `joerg.muessig`; nach kurzer Pause „Der Benutzername ist frei.“ mit Häkchen (oder Vergeben-Hinweis) | | A-06-G1 | |
| A-07 | G1 | **Ungültige Benutzernamen** nacheinander: `ab`, `Anna`, `anna müller`, `.anna`, `anna.`, 33 × `a` | Jeweils „Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.“; „Konto erstellen“ ausgegraut | | A-07a-G1 … A-07f-G1 (je Eingabe ein Bild) | |
| A-08 | G1 | Benutzername `fnt-MMTT-n1`, danach Name auf `Test N1` ändern; Passwort mit 7 Zeichen, dann 8 oder mehr; Augen-Symbol antippen; Namen kurz leeren und wieder `Test N1` eintragen | Benutzername bleibt `fnt-MMTT-n1` (nach eigener Eingabe kein Überschreiben); „Der Benutzername ist frei.“; bei 7 Zeichen ausgegraut, ab 8 aktiv; „Passwort anzeigen“/„Passwort verbergen“ wirkt; leerer Name: ausgegraut | | A-08-G1 | |
| A-09 | G1 | **N1 anlegen:** „Konto erstellen“ | „Erstelle Konto …“; **kein** Zusatzschritt („Noch ein kurzer Schritt“ erscheint nicht); „Dein Notfall-Schlüssel“, „Schritt 2 von 3“. **Bleibt die App länger als 30 s auf „Schritt 1 von 3“** (Passwortfeld leer, kein „Erstelle Konto …“; im Lauf vom 26.10. einmal beobachtet): mit `…/register/available` prüfen, ob das Konto angelegt wurde; App neu starten und Befund eintragen. Dann nicht denselben Namen erneut anlegen | | A-09a-G1, A-09b-G1 | |
| A-10 | G1 | „Notfall-Schlüssel erstellen“ (Bildschirmvideo läuft); 20 s warten; „Kopieren“; „Als Datei speichern“ (Speicherort wählen); Häkchen; „Weiter“ | Schlüssel erscheint und **bleibt stehen** (#10); „Kopieren“ meldet „Kopiert. … Die Zwischenablage wird nach einer Minute geleert.“; Datei `FamilyNexus-Notfall-Schluessel.txt` gespeichert (Speicherort im Report notieren; „Gespeichert. …“) mit Konto, Anbieter, Datum, Schlüssel; „Weiter“ erst nach dem Häkchen aktiv. Schlüssel als **KN1** ablegen | | A-10a-G1 (sofort), A-10b-G1 (nach 20 s), A-10c-G1 | |
| A-11 | G1 | „Name der Familie“: `Testfamilie MMTT` → „Familie gründen“ | Hinweise zu Moderator und Einwilligung bei Kindern; „Fertig! „Testfamilie MMTT“ ist eingerichtet.“ mit „Später“ und „Jetzt einladen“ | | A-11-G1 | |
| A-12 | G1 | „Später“ | Hauptansicht „Heute“ | | A-12-G1 | |

### B. Hauptfunktionen mit einem Nutzer (G1, N1)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| B-01 | G1 | Hauptansicht „Heute“ ansehen | Kacheln „Nächste Termine“, „Erinnerungen“, „Wer ist online“, „Einkaufszettel“, „Aufgaben“, „Ungelesene Nachrichten“; unten Heute/Kalender/Chat/Einkauf/Familie; „Menü öffnen“ oben rechts; Schaltfläche „Neuer Termin“. Sobald Termine aus B-03 bis B-06 bestehen (Bild nach B-06 wiederholen): „Nächste Termine“ chronologisch (Issue #33: ganztägige Termine späterer Tage stehen zuerst → ⚠️) | | B-01-G1 | |
| B-02 | G1 | Hinweis „Benachrichtigungen sind blockiert. …“ → „Erlauben“ → Systemdialog → erlauben (Linux/Windows: kein Hinweis, keine Berechtigung → Schritt auf G2 ausführen, sofern G2 iOS/Android ist) | Systemdialog erscheint; danach ist der Hinweis weg | | B-02a-G1, B-02b-G1 | |
| B-03 | G1 | **Kalender, geteilter Termin:** Kalender → morgen wählen → „Neuer Termin“ → Titel `Test geteilt`, 10:00–11:00, „Geteilt“, Ort `Küche`, Notiz `Testnotiz`, eine andere Farbe → „Speichern“ | Sichtbarkeit steht zuerst auf „Privat“; bei „Geteilt“ der Hinweis „Verschlüsselt an die Familie gesendet. …“; Termin erscheint mit „Geteilt“ | | B-03a-G1, B-03b-G1 | |
| B-04 | G1 | **Pflichtfelder:** „Neuer Termin“ ohne Titel → „Speichern“; Ende vor Beginn setzen → „Speichern“ (danach bis zum Formularende scrollen); danach „Zurück“ ohne Speichern | „Bitte einen Titel eingeben.“; „Das Ende liegt vor dem Beginn.“ (steht am unteren Formularende, Issue #34); nichts gespeichert | | B-04-G1 | |
| B-05 | G1 | **Privater Termin:** morgen 21:00–22:00 (Beginn **und** Ende einstellen: das Ende wandert beim Ändern des Beginns nicht mit, Issue #34), Titel `Test privat`, Sichtbarkeit „Privat“ → „Speichern“ | Termin mit „Privat“; Hinweis „Nur auf deinen eigenen Geräten. …“ | | B-05-G1 | |
| B-06 | G1 | **Ganztägig und Wiederholung:** Termin `Test Serie`, übermorgen, Sichtbarkeit bleibt „Privat“ (Standard), „Ganztägig“ an, „Wöchentlich“, „Endet“ → „Nach Anzahl“: 3 → „Speichern“ | Drei Vorkommen im Abstand einer Woche; Kennzeichnung „Wiederholt“, „Wöchentlich“ | | B-06-G1 | |
| B-07 | G1 | **Ansichten und Navigation:** „Tag“, „Woche“, „Monat“, „Agenda“; „Zurück“, „Weiter“, „Heute“ | Alle Ansichten zeigen die Termine; Navigation wechselt den Zeitraum, „Heute“ springt zurück | | B-07a-G1 … B-07d-G1 | |
| B-08 | G1 | **Termin ansehen und bearbeiten:** „Test geteilt“ öffnen → „Termin bearbeiten“ → Titel `Test geteilt 2` → „Speichern“ → „Verlauf“ | Detailansicht mit „Von dir“, Sichtbarkeit, Ort, Notiz; nach dem Speichern neuer Titel; „Verlauf (1)“ zeigt die **frühere** Fassung „Test geteilt – Version 1“ (die aktuelle Fassung steht nicht im Verlauf) | | B-08a-G1, B-08b-G1 | |
| B-09 | G1 | **Erinnerung je Termin:** in „Test geteilt 2“ unter „Deine Erinnerungen“ eine zusätzliche Erinnerung wählen, danach „Standard verwenden“ | Auswahl wird übernommen und wieder zurückgesetzt | | B-09-G1 | |
| B-10 | G1 (Linux per Skript: G2) | **Erinnerung kommt an:** Termin `Test Erinnerung` in 12 Minuten (privat), Standard-Erinnerung 10 Minuten; App in den Hintergrund; warten | Nach etwa 2 Minuten Systembenachrichtigung „Erinnerung“ / „Termin in 10 Minuten“, **ohne** Titel oder Ort | | B-10-G1 | |
| B-11 | G1 | **Termin löschen:** ein Vorkommen von „Test Serie“ öffnen → „Termin löschen“ → „Nur dieses“; danach „Test Erinnerung“ → „Termin löschen“ → „Löschen“ | „Alle Vorkommen oder nur dieses löschen?“; nur das gewählte Vorkommen verschwindet; „Diesen Termin wirklich löschen?“; Termin weg | | B-11-G1 | |
| B-12 | G1 | **Chat:** Tab „Chat“ → `Hallo Testfamilie` → „Senden“ (Schaltfläche; auf dem Desktop sendet Enter nicht, Issue #37) | „Ende-zu-Ende-verschlüsselt“; Nachricht erscheint mit Uhrzeit | | B-12-G1 | |
| B-13 | G1 | **Termin im Chat teilen:** „Test geteilt 2“ öffnen → „Im Chat teilen“ → Chat öffnen | „Im Chat geteilt“; im Chat eine Karte „Termin“ mit dem Termin | | B-13-G1 | |
| B-14 | G1 | **Einkauf:** „Milch“ mit Menge `2 l` → „Hinzufügen“ (Schaltfläche; Enter fügt auf dem Desktop nicht hinzu, Issue #37); „Brot“ hinzufügen; „Milch“ abhaken; Menü am Eintrag „Brot“ → „Bearbeiten“ → `Vollkornbrot`; ungültig: leeren Eintrag hinzufügen | „Zu besorgen (2)“; abgehakt unter „Erledigt (1)“; Text geändert; leerer Eintrag: „Hinzufügen“ bewirkt nichts, es entsteht kein Eintrag | | B-14a-G1, B-14b-G1 | |
| B-15 | G1 | **Aufgaben (Moderator):** „Menü öffnen“ → „Aufgaben“ → „Neue Aufgabenliste“: Titel `Bad putzen`, „Zugewiesen an“: Du, „Wiederholung“: „Wöchentlich“ mit Wochentag, Punkte `Waschbecken` und `Spiegel` (einer pro Zeile) → „Speichern“; einen Punkt abhaken, Kommentar `erledigt` → „Erledigt“; „Verlauf“ | Hinweis „Nur Moderatoren legen Listen an. …“; Liste unter „Mir zugewiesen“ mit „1 von 2 erledigt“, „Nächster Neustart: …“; Verlauf mit Eintrag und Uhrzeit (Datum steht im ISO-Format `JJJJ-MM-TT`, Issue #38 → ⚠️); „Heute“ zeigt „Aufgaben für dich: 1 offen“. Leeres Speichern: „Bitte Titel, Person und mindestens einen Punkt angeben.“ | | B-15a-G1, B-15b-G1 | |
| B-16 | G1 | **Einstellungen – Darstellung:** „Menü öffnen“ → „Einstellungen“: „Sprache“ (English → Deutsch), „Design“ (Hell/Dunkel/Wie Gerät), „Akzentfarbe“ (z. B. Magenta, dann zurück), „Effekte reduzieren“ an/aus | Jede Änderung wirkt sofort und bleibt nach einem Neustart erhalten | | B-16a-G1 … B-16c-G1 | |
| B-17 | G1 (Linux/Windows: G2) | **App-Sperre:** „App-Sperre“ an, „Sperren nach“: „Sofort“; App in den Hintergrund und wieder öffnen → „Entsperren“ mit Gerätesperre; danach wieder aus | „FamilyNexus ist gesperrt“, „Entsperren“; Entsperren mit PIN/Biometrie öffnet die App. Ohne Gerätesperre: „Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.“ | | B-17-G1 | |
| B-18 | G1 (Linux/Windows: G2) | **Bildschirmschutz:** „Bildschirmschutz“ an: Screenshot versuchen und App-Übersicht öffnen; danach aus und wiederholen | An: Inhalt in der App-Übersicht verborgen, Screenshot blockiert oder leer (je nach Plattform; Android: `adb exec-out screencap` liefert ein schwarzes Bild); aus: normal sichtbar. Unter Linux/Windows gibt es den Schalter nicht | | B-18-G1 | |
| B-19 | G1 | **Datenschutz:** „Online-Status teilen“ an/aus (Wirkung in E-15); „Blockierte Mitglieder“ öffnen; „Datenschutzerklärung“ öffnen | „Du hast niemanden blockiert.“; Datenschutzerklärung vollständig, Abschnitte lesbar | | B-19-G1 | |
| B-20 | G1 | **Erinnerungen:** „Standard-Erinnerung“ ändern (z. B. 30 Minuten) | Neue Termine übernehmen die Vorgabe; „Erinnerungen sind lokale Benachrichtigungen …“ | | B-20-G1 | |
| B-21 | G1 | **Über die App:** „Speicherorte“, „Protokoll: alle lokal gespeicherten Daten zeigen“ (dann „Kopieren“), „Protokoll: alle online gespeicherten Daten zeigen“ | Speicherorte mit Schlüsselspeicher der Plattform (z. B. „Schlüsselbund des Geräts (nicht in iCloud)“); lokales Protokoll mit „App-Version …“ = Soll, Termine, Einkauf, Aufgaben, Anzeigename „Test N1“; Warnhinweis zum Klartext; „Protokoll kopiert.“; Online-Protokoll mit Konto, Geräten, Räumen | | B-21a-G1 … B-21c-G1 | |
| B-22 | G1 | **Version und Konto:** Menü unten ablesen; Einstellungen → „Über die App“ → „Version …“; Einstellungen → „Konto“ | Menü und Einstellungen zeigen „Version <Soll>“, z. B. „Version 1.2.1 (16)“ (#14); „Konto“: „Server“ = Anbieter-Adresse, „Benutzername“ = `@fnt-MMTT-n1:matrix.chaostribunal.de` | | B-22a-G1, B-22b-G1 | |

### C. Zweites Gerät, Geräteprüfung und Notfall-Schlüssel (G1 und G2, N1)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| C-01 | G2 | „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter-Adresse → `fnt-MMTT-n1` + **falsches** Passwort → „Anmelden“ | „Melde an …“, dann „Benutzername oder Passwort stimmen nicht.“; keine Anmeldung | | C-01-G2 | |
| C-02 | G2, G1 | Richtiges Passwort → „Anmelden“ → „Dieses Gerät freischalten“ → „Mit „FamilyNexus <Plattform von G1>“ bestätigen“ (z. B. „FamilyNexus macOS“, „FamilyNexus Linux“); auf G1 die Anfrage annehmen und die Symbole vergleichen → beide „Sie stimmen überein“ | G1: „… möchte die Verifizierung starten.“; beide zeigen dieselben Symbole in gleicher Reihenfolge (die Bedienungshilfe liest die Namen englisch, Issue #39); beide „Verifiziert.“; G2 öffnet die Hauptansicht mit F1 und den Daten aus B (geteilte und private Termine, Chat, Einkauf, Aufgaben) | | C-02a-G2, C-02b-G1, C-02c-G2 | |
| C-03 | G2 | Einstellungen → „Notfall-Schlüssel und Geräte“ | „Dieses Gerät ist verifiziert.“; „Geräte deines Kontos“ zeigt beide als „Verifiziert“, eines mit „(Dieses Gerät)“; „Neuen Notfall-Schlüssel erstellen“ vorhanden | | C-03-G2 | |
| C-04 | G2 | Einstellungen → „Abmelden“ → im Dialog „Abmelden“ | Die App zeigt direkt „Anmelden“ (nicht „Willkommen“) | | C-04-G2 | |
| C-05 | G1 | **Neuen Notfall-Schlüssel erstellen (#11):** Einstellungen → „Neuen Notfall-Schlüssel erstellen“ → Erklärung lesen → „Neuen Notfall-Schlüssel erstellen“ (Video); dann Zurück-Pfeil, System-Zurück bzw. Geste versuchen; Häkchen → „Weiter“ | Seite „Neuer Notfall-Schlüssel“ („Der alte funktioniert danach nicht mehr …“); neuer Schlüssel angezeigt; **alle Zurück-Wege gesperrt**, bis Häkchen und „Weiter“; danach zurück in den Einstellungen. Ablegen als **KN1b** | | C-05a-G1 … C-05d-G1 | |
| C-06 | G2 | „Anmelden“ mit `fnt-MMTT-n1` → „Dieses Gerät freischalten“ → **KN1** → „Freischalten“ | „Schalte frei …“, dann „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“; Gerät bleibt gesperrt | | C-06-G2 | |
| C-07 | G2 | **KN1b** → „Freischalten“ | Gerät freigeschaltet, Hauptansicht mit F1 und Daten aus B | | C-07-G2 | |
| C-08 | G2 | Abmelden wie C-04 | „Anmelden“ | | C-08-G2 | |

### D. Weitere Wege der Kontoanlage und Beitritt per Familien-Code (G2, N2; G1, N1)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| D-01 | G2 | **Vergebener Name und Ausweichvorschlag:** „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse → Name `Test N2`, Benutzername `fnt-MMTT-n1` → Chip antippen → Passwort → „Konto erstellen“ → „Notfall-Schlüssel erstellen“ → Häkchen → „Weiter“ | „Schon vergeben – wie wäre es mit „fnt-MMTT-n12“?“, Chip „„fnt-MMTT-n12“ verwenden“, „Konto erstellen“ ausgegraut; nach dem Chip „Der Benutzername ist frei.“; Konto angelegt, Schlüssel bleibt stehen; Ablage **KN2**; Familienschritt erscheint | | D-01a-G2, D-01b-G2 | |
| D-02 | G1, G2 | **Familien-Code und Ablehnung:** G1: Tab „Familie“ → „Familien-Code“ → „Code kopieren“ und an G2 übertragen (Code beginnt mit `!` und endet auf den Servernamen; iOS-Simulator: Zwischenablage mit `pbpaste` lesen und mit `xcrun simctl pbcopy booted` setzen, dann Menü Bearbeiten → „Einsetzen“; siehe Anhang D). G2 (Familienschritt nach D-01; nach „Noch kein Konto? Jetzt erstellen“ zeigt er den Umschalter „Gründen \| Beitreten“ → „Beitreten“; nur nach „Neue Familie gründen“ steht dort stattdessen „Ich wurde doch eingeladen“) → „Ohne Link beitreten (Familien-Code)“ → zuerst `abc` → dann den Code von G1 → „Beitritt anfragen“. G1: Anfrage ansehen → „Ablehnen“ | G1: „Code kopiert“. G2: bei `abc` „Das ist kein gültiger Familien-Code. …“; danach „Fast geschafft! …“ (Lauf 1: „Unbekannter Fehler.“, Issue #25; Lauf 2: nicht reproduziert. Tritt der Fehler auf: als ❌/⚠️ eintragen und mit einem Matrix-Knock des Kontos gegenprüfen, um die Anfrage-Seite von G1 trotzdem zu testen). G1: Tab „Familie – 1 offene Anfragen“, Anfrage mit „Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du … kennst“; nach „Ablehnen“ verschwindet sie. Bei einer über die API gesendeten Anfrage steht dort „Unbekannter Link – von keinem Moderator ausgegeben“ und „Bestätigen“ ist ausgegraut; nur „Ablehnen“ prüfen. G2: „Deine Anfrage wurde abgelehnt. …“ mit „Verstanden“ – **bis zu 3 Minuten warten** (Lauf 3, Android: nach ca. 2,5 Min.; Dauer notieren). Erscheint die Meldung nicht (Lauf 2, iOS: G2 blieb auf „Fast geschafft!“, Issue #30): als ⚠️ eintragen, App neu starten und für D-03 „Gründen“ wählen | | D-02a-G1, D-02b-G2, D-02c-G1, D-02d-G2 | |
| D-03 | G2 | „Verstanden“ → Umschalter „Gründen“ (bzw. „Stattdessen eine neue Familie gründen“) → `Löschtest MMTT` → „Familie gründen“ → falls angezeigt „Später“ | Familie F2 angelegt, Hauptansicht „Heute“ (auf diesem Weg ohne Zwischenschritt „Fertig!“) | | D-03-G2 | |
| D-04 | G2 | Abmelden (wie C-04) → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse → Name `Test`, Benutzername `fnt-MMTT-n12` → unten „Ich habe schon ein Konto“ | „Anmelden“ mit vorausgefülltem Benutzernamen `fnt-MMTT-n12` | | D-04-G2 | |
| D-05 | G2 | Mit Passwort von N2 anmelden → „Dieses Gerät freischalten“ → **KN2** → „Freischalten“ | N2 hat kein anderes Gerät (beim Abmelden in D-04 hat der Server das Gerät entfernt): statt „Mit „…“ bestätigen“ steht „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; mit KN2 freigeschaltet, F2 erkannt. Bleibt „Synchronisiere …“ länger als 60 s stehen (einmal am 26.10. beobachtet, Befund B-2): App beenden, neu starten, Schlüssel erneut eingeben und den Befund eintragen | | D-05-G2 | |
| D-06 | G2 | Abmelden → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse → Name, Benutzername `fnt-MMTT-n9`, Passwort → Zurück-Pfeil, **ohne** „Konto erstellen“ | Startseite „Willkommen“; kein Konto. Gegenprobe: `…/register/available?username=fnt-MMTT-n9` liefert `available: true` | | D-06-G2 | |
| D-07 | G1 | **Optional, nur mit Serverzugang:** Betreiber setzt `enable_registration: false` und startet Synapse neu (V-05 meldet „Registration has been disabled“). Auf einem freien Gerät: „Neue Familie gründen“ → Anbieter-Adresse. Danach Registrierung **wieder öffnen** und V-05 wiederholen | „Bei matrix-synapse-3ues.srv1348446.hstgr.cloud kann die App kein Konto anlegen. …“, Schaltflächen „Element starten“ und „Ich habe ein Konto – anmelden“; kein Formular | | D-07-G1 | |

### E. Einladung und Zusammenspiel zweier Nutzer (G1 = N1, G2 = I2)

G2 zeigt nach D-06 „Willkommen“ (N2 ist abgemeldet und wird erst in F-01 wieder angemeldet). Bei Schritten mit beiden Geräten beide Bildschirme innerhalb von 2 Sekunden aufnehmen und im Report nebeneinander zeigen.

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| E-01 | G1 | Tab „Familie“ | „Testfamilie MMTT“, „Empfehlung: Ernenne einen zweiten Moderator.“, Mitglieder: nur Test N1 (Moderator); „Mitglied einladen“, „Familien-Code“ | | E-01-G1 | |
| E-02 | G1 | **Familienname ändern** → `Testfamilie MMTT neu` → speichern | „Name geändert.“; neuer Name überall (Familie, Chat) | | E-02-G1 | |
| E-03 | G1 | **Per Benutzer-ID einladen:** zuerst `abc` → „Einladen“; dann `@fnt-MMTT-n12:matrix.chaostribunal.de` → „Einladen“ → bestätigen | `abc`: „Bitte eine gültige Benutzer-ID eingeben, …“; danach Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme …“; „Einladung gesendet.“; N2 steht mit „Eingeladen“ in der Liste | | E-03-G1 | |
| E-04 | G1 | **Eingeladenen entfernen:** Aktionen für Test N2 → „Entfernen“ → bestätigen | Rückfrage „… wirklich aus der Familie entfernen? …“; N2 verschwindet aus der Liste | | E-04-G1 | |
| E-05 | G1 | **Einladungslink:** „Jemanden einladen“ → „Gültig für“ ansehen → „Erweitert“ → „Konto-Server für Neue“: `matrix-synapse-3ues.srv1348446.hstgr.cloud` → „Neuen Link erzeugen“; QR-Code ansehen (wird direkt angezeigt, keine eigene Schaltfläche); „Per E-Mail senden“ (Entwurf nicht abschicken; Linux-Flatpak per Skript: öffnet das Mailprogramm des echten Desktops → auf G2 prüfen, sobald G2 nach E-30 Moderator ist, oder ⏳); „Link kopieren“ und an G2 übertragen (Simulator: `xcrun simctl pbcopy booted` bzw. `xcrun simctl openurl booted '<Link>'`) | QR-Code und Link; Hinweis „Der Link ist … gültig und nur einmal verwendbar. …“; E-Mail-Entwurf mit Betreff „Einladung zu FamilyNexus“ und Link (ohne Mailprogramm: „Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.“); „Link kopiert.“; Der Link ist eine Web-Adresse `https://carpeasrael.github.io/FamilyNexus/join/#v=3&…` (enthält Familienname, Einladenden und `srv` = Konto-Server für Neue); die Seite öffnet die App über das Schema `familynexus://join` (Befund B-4: Plan und Meldungstext früher mit `familynexus://join` am Linkanfang) | | E-05a-G1 … E-05c-G1 | |
| E-06 | G2 | „Ich wurde eingeladen“ → nacheinander einfügen: `abc`; den Link **ohne den Teil `&n=…`** (Einmal-Code; nur das Ende abzuschneiden kürzt lediglich den Einladernamen `by=`, und die App nimmt den Link an) (Einfügen im Simulator über Menü Bearbeiten → „Einsetzen“; erscheint nichts, den Test als ⏳ mit Grund eintragen) | `abc`: „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „familynexus://join“.“ (Text passt nicht zur https-Adresse, Issue #26 → ⚠️); ohne `n=`: „Der Link ist unvollständig oder beschädigt …“ | | E-06a-G2, E-06b-G2 | |
| E-07 | G2 | Vollständigen Link einfügen **oder** über das System öffnen (**vorher Safari auf dem Simulator beenden: `xcrun simctl terminate booted com.apple.mobilesafari`, sonst zeigt Safari ggf. die Seite eines früheren Links und die Beitrittskarte nennt die falsche Familie**; `xcrun simctl openurl booted '<Link>'`: Web-Seite „Einladung zu FamilyNexus“ → „App öffnen“ → „In FamilyNexus öffnen?“ → „Öffnen“) → „Details“. **Hat G2 noch kein Konto (Normalfall nach D-06), führt der Link zuerst zur Kontoanlage (E-08 bis E-10); die Beitrittskarte erscheint erst nach dem Notfall-Schlüssel („Schritt 4 von 4“) und wird dann hier bewertet.** Android: `adb shell am start -a android.intent.action.VIEW -d '<Link>'` öffnet die Web-Seite im Browser → „App öffnen“ | Beitrittskarte „Du trittst der Familie „Testfamilie MMTT neu“ bei. Eingeladen hat dich Test N1 (Konto bei …).“; Details mit Benutzer-ID `@fnt-MMTT-n1:…` und Server der Familie; „Verwerfen“ vorhanden | | E-07-G2 | |
| E-08 | G2 | Beitreten → Kontoanlage | Anbieter ist bereits `matrix-synapse-3ues.srv1348446.hstgr.cloud` (aus dem Link), nicht matrix.org | | E-08-G2 | |
| E-09 | G2 | **I2 anlegen:** Name `Test Nutzer 2`, Benutzername `fnt-MMTT-i2`, Passwort → „Konto erstellen“ | Konto ohne Zusatzschritt angelegt, weiter zum Notfall-Schlüssel | | E-09-G2 | |
| E-10 | G2 | „Notfall-Schlüssel erstellen“ (Video) → Häkchen → „Weiter“; **G1 bleibt geöffnet** | Schlüssel bleibt stehen (#10); Ablage **KI2**; danach Beitrittskarte „Familie beitreten“ („Schritt 4 von 4“) → „Beitritt anfragen“ antippen, danach „Fast geschafft! …“ | | E-10-G2 | |
| E-11 | G1, G2 | Aufnahme abwarten (Dauer notieren) | I2 wird automatisch aufgenommen; G2 zeigt die Hauptansicht. Zeigt G1 stattdessen „Familie – 1 offene Anfragen“ mit „Gültiger Einladungslink“: „Bestätigen“ → Rückfrage „… in die Familie aufnehmen? …“ und Verhalten notieren | | E-11-G1, E-11-G2 | |
| E-12 | G2 | **Verbrauchter Link über das System öffnen:** den Link aus E-05 auf G2 über das Betriebssystem öffnen (Mac: `open '<Link>'`, iOS-Simulator: `xcrun simctl openurl booted '<Link>'`, iPhone: in Notizen antippen, Android: `adb shell am start -a android.intent.action.VIEW -d '<Link>'`, öffnet die Web-Seite im Browser → „App öffnen“) | G2: „Du bist bereits in einer Familie.“ (kurze Meldung am unteren Rand, verschwindet nach wenigen Sekunden – Bildschirmvideo oder Screenshot sofort nach dem Öffnen); nichts ändert sich, kein Absturz | | E-12-G2 | |
| E-13 | G1, G2 | Tab „Familie“ auf beiden | Beide Mitglieder: Test N1 (Moderator), Test Nutzer 2 (Mitglied, „Nicht persönlich geprüft“); Familienname „Testfamilie MMTT neu“ auch bei I2 | | E-13-G1, E-13-G2 | |
| E-14 | G2 | I2: Tab „Familie“ → keine Verwaltungsaktionen; Menü → „Aufgaben“ (**muss vor E-30 erfolgen; danach ist I2 Moderator und sieht „+“ bei Aufgaben**) | Unter dem Familiennamen „Nur Moderatoren verwalten die Familie.“; kein „Familienname ändern“, kein „Mitglied einladen“, kein „Familien-Code“; im Menü der Mitglieder nur „Verifizieren“ und „… blockieren“ (kein „Zum Moderator ernennen“, kein „Entfernen“); bei Aufgaben keine Schaltfläche „Neue Aufgabenliste“ | | E-14-G2 | |
| E-15 | G1, G2 | **Online-Status:** beide Apps im Vordergrund auf „Heute“; dann auf G1 Einstellungen → „Online-Status teilen“ aus, G1 Tab „Familie“ und G2 „Heute“ und „Familie“ ansehen; danach wieder an | An: „Wer ist online“ zeigt „Test N1 – Online“ bzw. „Test Nutzer 2 – Online“; im Tab „Familie“ beim eigenen Eintrag „Du bist online“. Aus: G1 meldet sofort „offline“; G2 zeigt unter „Wer ist online“ „Gerade ist sonst niemand online.“ und im Tab „Familie“ bei Test N1 „Zuletzt online gerade eben“ (später „vor … Min.“); G1 zeigt beim eigenen Eintrag „Dein Status wird nicht geteilt“. Wieder an: G2 zeigt N1 erneut als „Online“ | | E-15a-G1, E-15b-G2 | |
| E-16 | G1, G2 | **Chat:** G1 sendet `Hallo von Nutzer 1`; G2 antwortet über „Antworten“ mit `Hallo zurück von Nutzer 2`; G1 reagiert per lange drücken → Reaktion (z. B. 👍) | Nachricht bei G2; G2 zeigt „Antwort an Test N1“ beim Schreiben; Antwort mit Bezug bei G1; Reaktion bei beiden; „Ungelesene Nachrichten“ auf „Heute“ zählt vor dem Öffnen. **Ereignisse aus der Zeit vor dem Beitritt von I2 (Chat, aber auch Termin-, Einkaufs- und Aufgabenänderungen) erscheinen bei G2 als „Nachricht kann nicht entschlüsselt werden“ – nach heutigem Stand erwartet; Anzahl notieren, Verbesserung in Issue #35** | | E-16a-G1 … E-16c-G2 | |
| E-17 | G1, G2 | **Anhang:** G1 „Datei anhängen“ → ein kleines Bild und eine Textdatei senden; G2 beim Bild „Anhang laden“, bei der Textdatei „Speichern“ (Linux-Flatpak per Skript: Dateiauswahl öffnet sich auf dem echten Desktop → Richtung umkehren, G2 sendet, G1 empfängt; im Report vermerken) | Beide Anhänge erscheinen beim Empfänger; Bild nach „Anhang laden“ sichtbar (Bilder lassen sich derzeit nicht speichern, Issue #40); Textdatei: vor dem Speichern Warnung „Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. …“; Datei im gewählten Ordner | | E-17a-G1, E-17b-G2 | |
| E-18 | G1, G2 | **Einzelchat (zuvor erscheint nach E-24 im Einzelchat der Rohtext „Attempting verification request. …“, Issue #29, als ⚠️ vermerken; E-24 daher nach E-18 ausführen, wenn der Chat sauber bleiben soll):** G1: Tab „Familie“ → bei Test Nutzer 2 „Nachricht schreiben“ → **vor dem Senden Screenshot und prüfen, dass oben „Nur zwischen dir und Test Nutzer 2“ steht** (beim ersten Mal bleibt der Familienchat ausgewählt, Issue #31 → ❌; dann nicht senden, sondern den Reiter „Test Nutzer 2“ wählen) → `Nur für dich`; G2: Chat → „Gespräche“ | Einzelchat „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“; bei G2 unter „Gespräche“ „Einzelchat mit Test N1“ mit der Nachricht, nicht im Familienchat | | E-18a-G1, E-18b-G2 | |
| E-19 | G1, G2 | **Termine:** G2 Kalender und „Heute“ ansehen; „Nach Person filtern“ → Test N1 → „Alle“ | „Test geteilt 2“ sichtbar, **„Test privat“ und „Test Serie“ nicht** (beide privat, B-05/B-06); Filter wirkt („Test Nutzer 2“: „Keine Termine“) | | E-19-G2 | |
| E-20 | G2, G1 | **Zu- und Absage:** G2 öffnet „Test geteilt 2“ → „Zusagen“; G1 öffnet denselben Termin | G2: „Nur der Ersteller kann diesen Termin ändern.“ (kein Bearbeiten); G2 sieht unter „Antwort“ die Schaltflächen „Zusagen“, „Vielleicht“, „Absagen“ (vorher „Keine Antwort“); G1 sieht unter „Antwort“ die Zeile „Test Nutzer 2 – Zugesagt“; „Im Chat teilen“ nur beim Ersteller (G1) | | E-20a-G2, E-20b-G1 | |
| E-21 | G2, G1 | **Eigener Termin von I2:** G2 legt `Termin I2` geteilt an; G1 sieht ihn; G2 ändert ihn auf „Privat“ | Termin erscheint bei G1 mit „Von Test Nutzer 2“; beim Wechsel auf „Privat“ Hinweis „Bereits an die Familie gesendete Inhalte bleiben …“ | | E-21a-G2, E-21b-G1 | |
| E-22 | G2, G1 | **Einkauf gemeinsam:** G2 sieht „Milch“/„Vollkornbrot“, legt `Käse` an; G1 hakt „Käse“ ab; G1 „Erledigte entfernen“ → bestätigen; G2 löscht „Vollkornbrot“ | Einträge erscheinen auf beiden mit „zuletzt von …“; „… erledigte Einträge für die ganze Familie entfernen?“, „… Einträge entfernt“; Löschen wirkt auf beiden | | E-22a-G2 … E-22c-G1 | |
| E-23 | G1, G2 | **Aufgabe für I2:** G1 legt `Müll rausbringen` an, „Zugewiesen an“: Test Nutzer 2, „Täglich“ → „Montag bis Freitag (ohne Wochenende)“, ein Punkt; G2 hakt ab mit Kommentar; G1 öffnet „Verlauf“; G1 löscht die Liste „Bad putzen“ („Liste löschen“) | G2: Liste unter „Mir zugewiesen“, „Aufgaben für dich: 1 offen“ auf „Heute“; G1 kann den Punkt nicht abhaken (nur zugewiesene Person); Verlauf „… erledigt“ mit Name und Zeit; „Liste „Bad putzen“ löschen?“ → weg | | E-23a-G1 … E-23c-G1 | |
| E-24 | G1, G2 | **Person verifizieren:** G1: Aktionen für Test Nutzer 2 → „Verifizieren“; Symbole auf beiden vergleichen → „Sie stimmen überein“ | Beide zeigen „Verifiziert.“; Mitgliederliste zeigt den Status „Verifiziert“ | | E-24a-G1, E-24b-G2 | |
| E-25 | G1 | **Melden:** Nachricht von Test Nutzer 2 lange drücken → „Nachricht melden“ → Grund „Spam oder Werbung“, Text → „Melden“ | Dialog „Nachricht melden“ mit Hinweis auf den Betreiber und vier Gründen; „Meldung gesendet.“; Angebot „Absender blockieren“ | | E-25-G1 | |
| E-26 | G1, G2 | **Blockieren:** Nachricht von Test Nutzer 2 lange drücken → „Test Nutzer 2 blockieren“ → „Blockieren“; G2 sendet `Noch da?` | „Test Nutzer 2 blockieren?“ mit Erklärung; „Test Nutzer 2 ist blockiert.“; Nachrichten von I2 bei G1 ausgeblendet, Mitglied mit „Blockiert“; G2 bekommt keine Fehlermeldung | | E-26a-G1, E-26b-G2 | |
| E-27 | G1 | Einstellungen → „Blockierte Mitglieder“ → „Blockierung aufheben“ | „Blockierung von Test Nutzer 2 aufgehoben.“; Nachrichten wieder sichtbar, auch `Noch da?` | | E-27-G1 | |
| E-28 | G1, G2 | **Version:** auf beiden Menü und Einstellungen → „Über die App“ | Beide „Version <Soll>“ (#14) | | E-28-G1, E-28-G2 | |
| E-29 | G1 | **Einziger Moderator:** Einstellungen → „Konto löschen“ → nur Dialog ansehen → „Abbrechen“ | „Konto löschen?“ mit „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“ (#12); „Konto endgültig löschen“ ohne Passwort inaktiv; nach „Abbrechen“ unverändert | | E-29-G1 | |
| E-30 | G1, G2 | **Zum Moderator ernennen:** Aktionen für Test Nutzer 2 → „Zum Moderator ernennen“ → bestätigen | Rückfrage „… zum Moderator ernennen? …“; beide sehen Test Nutzer 2 als Moderator; Empfehlung zum zweiten Moderator verschwindet | | E-30-G1 | |
| E-31 | G1 | Einstellungen → „Konto löschen“ → Dialog ansehen → „Abbrechen“ | **Kein** Hinweis „einziger Moderator“ mehr | | E-31-G1 | |
| E-32 | G2, G1 | **Mitglied löscht sein Konto:** G2 Einstellungen → „Konto löschen“ → Passwort von I2 → „Konto endgültig löschen“; danach G1 Tab „Familie“ und Chat | G2: kein Moderator-Hinweis (N1 ist Moderator), danach „Willkommen“ (nicht „Anmelden“; B-1 vom 26.10. behoben). G1: Test Nutzer 2 ist nicht mehr Mitglied; frühere Nachrichten bleiben sichtbar | | E-32a-G2, E-32b-G1 | |

### F. Lokale Daten, Löschen und Aufräumen

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| F-01 | G2 | **Kontolöschung mit falschem und richtigem Passwort (N2; bei „Unbekannter Fehler.“ nach der Anmeldung App neu starten – Issue #28 –, dann „Dieses Gerät freischalten“):** „Ich habe schon ein Konto“ → N2 anmelden mit KN2 → Einstellungen → „Konto löschen“ → falsches Passwort → „Konto endgültig löschen“; dann richtiges Passwort | Dialog nennt `@fnt-MMTT-n12:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, Nachrichten bleiben bei anderen sichtbar; kein Moderator-Hinweis (allein in F2); falsch: Fehlermeldung (derzeit „Benutzername oder Passwort stimmen nicht.“, Issue #36), Dialog bleibt, nichts gelöscht; richtig: alle lokalen Daten gelöscht, „Willkommen“ (Builds **ohne** PR #22, d. h. vor Commit `d20f0e0`, zeigen „Anmelden“ (Befund B-1, Issue #23) → ⚠️; das gilt auch für frühe Builds mit der Nummer 16. Builds ab `d20f0e0`, z. B. die Release-Dateien v1.2.1 vom 26.10.2026 außer der macOS-DMG, zeigen „Willkommen“. Maßgeblich ist der Commit aus V-01/V-03, nicht die Build-Nummer). Das Passwortfeld ist bei der Wiederholung vorher vollständig zu leeren (Cursor ans Ende, Rückschritt), sonst bleibt das falsche Passwort teilweise stehen | | F-01a-G2 … F-01c-G2 | |
| F-02 | – | Gegenprobe N2: Anmeldung per `curl` oder in der App mit `fnt-MMTT-n12` und richtigem Passwort | `403 M_FORBIDDEN` bzw. „Benutzername oder Passwort stimmen nicht.“ | | – | |
| F-03 | G1 | **Alle lokalen Daten löschen (N1):** Einstellungen → „Alle lokalen Daten löschen“ → „Endgültig löschen“ | Rückfrage „Alle lokalen Daten löschen?“; danach „Willkommen“ (Builds **ohne** PR #22, d. h. vor Commit `d20f0e0`, zeigen „Anmelden“ (Befund B-1, Issue #23) → ⚠️; das gilt auch für frühe Builds mit der Nummer 16. Builds ab `d20f0e0`, z. B. die Release-Dateien v1.2.1 vom 26.10.2026 außer der macOS-DMG, zeigen „Willkommen“. Maßgeblich ist der Commit aus V-01/V-03, nicht die Build-Nummer); das Konto besteht weiter | | F-03-G1 | |
| F-04 | G1 | App beenden, neu starten | „Willkommen“ (nicht „Anmelden“): Einstellungen und Daten sind weg | | F-04-G1 | |
| F-05 | G1 | „Ich habe schon ein Konto“ → N1 anmelden → „Dieses Gerät freischalten“ mit **KN1b** | Freigeschaltet; Termine (auch private, über den privaten Raum), Chat, Einkauf und Aufgaben vom Server wiederhergestellt | | F-05-G1 | |
| F-06 | G1 | **N1 löschen:** Einstellungen → „Konto löschen“ → Passwort → „Konto endgültig löschen“ | Kein Moderator-Hinweis (allein); „Willkommen“ (Builds **ohne** PR #22, d. h. vor Commit `d20f0e0`, zeigen „Anmelden“ (Befund B-1, Issue #23) → ⚠️; das gilt auch für frühe Builds mit der Nummer 16. Builds ab `d20f0e0`, z. B. die Release-Dateien v1.2.1 vom 26.10.2026 außer der macOS-DMG, zeigen „Willkommen“. Maßgeblich ist der Commit aus V-01/V-03, nicht die Build-Nummer) | | F-06a-G1, F-06b-G1 | |
| F-07 | – | Gegenprobe N1 und I2: Anmeldung mit `fnt-MMTT-n1` bzw. `fnt-MMTT-i2` | Beide scheitern (`403 M_FORBIDDEN`) | | – | |
| F-08 | – | **Zustand am Ende:** V-06 für alle Konten des Laufs; Registrierung offen lassen oder schließen (Absprache mit dem Betreiber) | Alle Konten gelöscht (`register/available` liefert für gelöschte Konten weiterhin `M_USER_IN_USE`, daher F-02/F-07 maßgeblich); Zustand im Report | | – | |

### G. Automatische Tests und Sonderfälle

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtetes Ergebnis | Screenshot | Erg. |
|---|---|---|---|---|---|---|
| G-01 | – | `flutter analyze` | „No issues found!“ | | – (Ausgabe) | |
| G-02 | – | `flutter test` (Linux: `LD_LIBRARY_PATH` auf libsqlcipher) | Alle Tests bestehen; Anzahl bestanden/übersprungen notieren | | – | |
| G-03 | – | `flutter test test/store/review_notes_test.dart` (Review-Notizen gegen die App, #13) | Grün; jede zitierte Beschriftung steht so in der App, Länge ≤ 4000 | | – | |
| G-04 | – | Optional: `tool/e2e.sh` (lokaler Synapse) | Alle E2E-Tests bestehen | | – | |
| G-05 | – | **Nicht manuell auslösbar, durch Tests abgedeckt:** Zusatzschritte der Registrierung (Bedingungen, E-Mail, Zugangscode, Captcha: `test/features/registration_test.dart`), Anmeldung im Browser/OAuth (`test/data/sdk_registration_test.dart`), abgelaufener Link und Link aus neuerer Version (`test/domain/invite_link_test.dart`), geänderte Identität eines Mitglieds, Startfehler „Lokale Daten nicht lesbar“ | In G-02 enthalten und grün | | – | |
| G-06 | G1 | **Review-Notizen manuell:** `store/metadata/ios/review_notes.txt` (bzw. `macos/`) Schritt für Schritt in der App nachvollziehen | Jeder Schritt auffindbar; Abweichung bei der Anmeldung im Browser (matrix.org) ist erwartet und gehört zu #15 | | G-06-G1 | |
| G-07 | G1 | **Durchlauf mit einer Person ohne Vorwissen:** A-01 bis A-12 und B-01 bis B-03 nach Anleitung | Ohne Rückfrage ausführbar; Rückfragen notieren | | – | |
| G-08 | Web | **Nur Plattform Web:** erster Aufruf → „Browser-Tresor einrichten“ (Passwort < 10 Zeichen, nicht übereinstimmend, dann gültig); Seite neu laden → „FamilyNexus entsperren“ (falsches, dann richtiges Passwort); zweiten Tab öffnen; „Passwort vergessen? Alle lokalen Daten löschen“ | „Mindestens 10 Zeichen.“, „Die Passwörter stimmen nicht überein.“, „Falsches Passwort.“; Entsperren klappt; zweiter Tab: „FamilyNexus ist schon geöffnet“; Löschen führt zu „Willkommen“ | | G-08a … | |

## 6. Abdeckungsmatrix

Jede Funktion der App ist mindestens einem Schritt zugeordnet. Wird eine Funktion ergänzt, kommt sie hier mit Schritt hinzu.

| Bereich | Funktion | Schritt(e) |
|---|---|---|
| Installation | Soll-Version, Ist-Version, Nachinstallation | V-01 bis V-03 |
| Lokale Daten | Löschen vor dem Lauf, „Alle lokalen Daten löschen“, Neustart, Wiederherstellung | V-04, F-03 bis F-05 |
| Start | Startseite, drei Einstiege, Sprachwahl | A-01, A-02 |
| Anbieter | Vorschlag matrix.org, anderer Anbieter, unerreichbare Adresse, Betreiberangaben | A-03 bis A-05 |
| Kontoanlage | Namensvorschlag, Umlaute, Prüfregeln Benutzername und Passwort, Passwort zeigen, Anlage ohne Zusatzschritt | A-06 bis A-09 |
| Kontoanlage | vergebener Name mit Vorschlag, Wechsel zur Anmeldung mit Namen, Abbruch ohne Konto, Registrierung geschlossen | D-01, D-04, D-06, D-07 |
| Kontoanlage | über Einladungslink (Anbieter aus dem Link) | E-08, E-09 |
| Kontoanlage | Zusatzschritte, Browser/OAuth | G-05 |
| Notfall-Schlüssel | erstellen, bleibt stehen, kopieren, als Datei speichern, Häkchen-Pflicht (#10) | A-10, D-01, E-10 |
| Notfall-Schlüssel | neu erstellen, Zurück gesperrt, alter ungültig (#11) | C-05 bis C-07 |
| Anmeldung | falsches Passwort, richtiges Passwort, Freischalten per Schlüssel, per anderem Gerät (Symbolvergleich), kein anderes Gerät | C-01, C-02, C-06, C-07, D-05 |
| Abmelden | Dialog, danach „Anmelden“ | C-04 |
| Familie | gründen, „Später“, umbenennen, Empfehlung zweiter Moderator | A-11, A-12, E-01, E-02 |
| Familie | Familien-Code kopieren, Beitritt per Code, Anfrage ablehnen, Ablehnung beim Anfragenden, Wechsel „neue Familie gründen“ | D-02, D-03 |
| Familie | Einladen per Benutzer-ID, Eingeladenen entfernen | E-03, E-04 |
| Einladung | Link mit Gültigkeit, Konto-Server für Neue, QR-Code, E-Mail, Link kopieren | E-05 |
| Einladung | kein Link, beschädigter Link, Beitrittskarte mit Details, automatische Aufnahme bzw. Bestätigen, verbrauchter Link über das System, bereits Mitglied | E-06, E-07, E-10 bis E-12 |
| Rollen | Mitglied ohne Verwaltung, nur Moderatoren legen Aufgaben an, zum Moderator ernennen | E-14, E-30 |
| Heute | Kacheln, Benachrichtigungen erlauben, nächster Termin, ungelesene Nachrichten, offene Aufgaben, Wer ist online | B-01, B-02, B-15, E-15, E-16 |
| Kalender | geteilt/privat, Pflichtfelder, Ort/Notiz/Farbe, ganztägig, Wiederholung mit Ende, Ansichten, Navigation | B-03 bis B-07 |
| Kalender | Detail, bearbeiten, Verlauf, Erinnerung je Termin, Erinnerung kommt an, löschen (eins/Serie), im Chat teilen | B-08 bis B-11, B-13 |
| Kalender | privater Termin bei anderen unsichtbar, Filter nach Person, Zu-/Absage, nur Ersteller ändert, Sichtbarkeitswechsel | E-19 bis E-21 |
| Chat | senden, Familienchat, Termin-Karte | B-12, B-13 |
| Chat | Antworten, Reaktion, Anhang laden/speichern mit Warnung, Einzelchat, Gespräche | E-16 bis E-18 |
| Einkauf | anlegen mit Menge, abhaken, bearbeiten, ungültiger Eintrag | B-14 |
| Einkauf | gemeinsam, „zuletzt von“, Erledigte entfernen, löschen | E-22 |
| Aufgaben | Liste anlegen, Wiederholung, Punkte, abhaken mit Kommentar, Verlauf, Prüfregel | B-15 |
| Aufgaben | Zuweisung an anderes Mitglied, nur Zugewiesene hakt ab, Montag bis Freitag, Liste löschen | E-23 |
| Sicherheit | Gerätestatus, Geräteliste, Gerät verifizieren, Person verifizieren | C-02, C-03, E-24 |
| Moderation | Nachricht melden, blockieren, Blockierung aufheben, Liste blockierter Mitglieder | B-19, E-25 bis E-27 |
| Anwesenheit | Online-Status teilen an/aus | B-19, E-15 |
| Einstellungen | Sprache, Design, Akzentfarbe, Effekte reduzieren | B-16 |
| Einstellungen | App-Sperre, Bildschirmschutz, Standard-Erinnerung | B-17, B-18, B-20 |
| Einstellungen | Datenschutzerklärung, Speicherorte, Protokoll lokal/online, kopieren | B-19, B-21 |
| Version | Menü, Einstellungen, Protokoll (#14) | B-21, B-22, E-28 |
| Konto | Server und Benutzername, Konto löschen (falsch/richtig, einziger Moderator, Mitglied mit Austragen) (#12) | B-22, E-29, E-31, E-32, F-01, F-06 |
| Review | Review-Notizen automatisch und manuell (#13), Person ohne Vorwissen | G-03, G-06, G-07 |
| Web | Browser-Tresor, Entsperren, zweiter Tab, Passwort vergessen | G-08 |
| Nicht manuell | Zusatzschritte, OAuth, abgelaufener Link, geänderte Identität, Startfehler | G-05 |

## 7. Abnahme und Report

**Bestanden**, wenn Abschnitt 2 vollständig ist, V-01 bis V-07 erfüllt sind und alle Schritte aus A bis G ✅ oder begründet „n/a“ sind. Optional: D-07, G-04. ⚠️ ist zulässig, wenn der Befund im Report steht und als Issue angelegt ist. ⏳ muss vor der Antwort an Apple nachgeholt werden.

**Report:** eine Kopie dieses Plans mit ausgefüllten Spalten „Beobachtet“, „Screenshot“, „Erg.“, abgelegt als `Test-Apple-Report/<JJJJ-MM-TT>/Testreport.md` und als PDF. Erste Seite: Abschnitt 2 (Plattform und System), Ergebnis von V-01 bis V-07, Zusammenfassung (Anzahl je Ergebnis) und Befundliste (Nr., Schwere, Schritt, Beschreibung). Screenshots stehen neben dem jeweiligen Schritt (im PDF als Bild in der Zeile oder direkt darunter); bei Schritten mit zwei Geräten nebeneinander. Passwörter und Notfall-Schlüssel sind geschwärzt.

## Anhang A: Vorbereitung iOS-Simulator

```sh
xcrun simctl create "iPhone 15 Test" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-27-1
xcrun simctl boot "iPhone 15 Test" && open -a Simulator   # unter Xcode 27 öffnet sich ggf. „Device Hub“ statt „Simulator“; Runtime nach Plan wählen (z. B. iOS-27-0 oder iOS-27-1) und in Abschnitt 2 eintragen
flutter run -d "iPhone 15 Test"                 # aktueller main
xcrun simctl io booted screenshot <Datei>.png   # Screenshot
xcrun simctl pbpaste booted                     # Zwischenablage lesen (Einladungslink)
```

## Anhang B: Apple-Prüfkonto (matrix.org) – nicht Teil dieses Plans

Nur für die Einreichung bei Apple und den matrix.org-Nachtest in #15. Zugangsdaten stehen nicht im Repository, sondern lokal in `../secure/Zugangsdaten.local.md` bzw. im Passwortmanager.

## Anhang C: Zuordnung der alten Testfall-IDs

| Alt | Neu |
|---|---|
| TV-01 / TV-02 / TV-03 | V-01 bis V-03 / V-05 / V-06 |
| TN-00 | V-05 |
| TN-01 bis TN-11 | A-01 bis A-11 |
| TN-12 | B-21, B-22 |
| TN-13, TN-14 | C-01, C-02 |
| TN-15, TN-16, TN-17, TN-18 | D-01, D-04, D-06, D-07 |
| TN-19 | G-02, G-05 |
| TC-00 bis TC-06 | V-05, A-01 bis A-11 |
| TC-07 bis TC-10 | B-01 bis B-14 |
| TC-11 | B-22, E-28 |
| TC-12 bis TC-14 | C-05, C-06/C-07, C-03 |
| TC-15 | G-03, G-06 |
| TC-16 | F-01, F-02 |
| TC-17 | G-07 |
| TC-18 | G-01, G-02, G-04 |
| TI-01 bis TI-03 | V-04, C-02 |
| TI-05 bis TI-11 | E-01, E-05 bis E-10 |
| TI-12, TI-13 | E-11, E-13 |
| TI-14 bis TI-16 | E-16, E-18 |
| TI-17, TI-18 | E-19, E-22 |
| TI-19 bis TI-21 | E-25 bis E-27 |
| TI-22, TI-23 | E-12, E-28 |
| TI-24 bis TI-27 | E-29, E-32, F-06, F-07 |

## Anhang D: Hinweise zur automatisierten Bedienung

- **Berechtigungen:** Das aufrufende Programm (Terminal/IDE) braucht „Bedienungshilfen“ (Systemeinstellungen → Datenschutz & Sicherheit) und für Screenshots „Bildschirmaufnahme“. Ohne die Berechtigung kommen Tastendrücke nicht in der App an (Mausklicks funktionieren trotzdem).
- **Fenster fixieren:** Mac-Fenster auf feste Position/Größe stellen (z. B. 800 × 900 pt), damit Klickkoordinaten stabil bleiben; Screenshot mit `screencapture -x -R<x>,<y>,<b>,<h>`. Der iOS-Simulator wird mit `xcrun simctl io booted screenshot` aufgenommen; Klickkoordinaten müssen auf das Gerätefenster umgerechnet werden (Skalierung beachten).
- **Eingabe:** Zeichen einzeln als Tastendrücke senden; Umlaute und `ß` gehen so nicht → Ersatzschreibung (ae, oe, ue, ss) zulässig. Großbuchstaben mit Umschalttaste, `!` und `:` mit Umschalttaste auf der entsprechenden Taste. Felder vor dem Eintippen leeren (Cursor ans Ende, viele Rückschritte). Lange Werte (Notfall-Schlüssel, Code, Link): Zwischenablage (Simulator: `xcrun simctl pbcopy booted`) und Menü Bearbeiten → „Einsetzen“.
- **Klicken:** Schaltflächen im Simulator reagieren teils erst auf einen längeren Klick; Ergebnis immer per Screenshot bestätigen, ein Dialog ohne Reaktion ist kein App-Fehler, bevor ein zweiter Versuch fehlschlug.
- **Geheimnisse:** Passwörter und Schlüssel nur in Dateien mit Rechten 600 im Sitzungsverzeichnis halten, nie im Report; Screenshots vor der Ablage schwärzen.

- **iOS-Simulator unter „Device Hub“ (Xcode 27):** Klicks mit Bildschirmkoordinaten auf das Gerätefenster (Fenster fest platzieren, Skalierung des Bildes beachten), Screenshots mit `xcrun simctl io booted screenshot`. Texte nur über Tastenereignisse oder Zwischenablage (Menü Bearbeiten → „Einsetzen“; iOS fragt einmalig „Einsetzen erlauben?“). Mehrzeilige Felder (Notfall-Schlüssel) leeren: Zeiger ans Ende (Pfeil rechts), dann viele Rückschritte; Cmd+A funktioniert im Simulator nicht zuverlässig, Menü Bearbeiten → „Alles auswählen“ schon.
- **Langes Drücken** (Nachricht melden/blockieren) am Mac: Maustaste ca. 1 s halten; Schaltflächen im Simulator brauchen teils einen längeren Klick.
- **Linux-Flatpak per Skript:** Den echten Desktop nicht fernsteuern (KDE fragt nach „Fernsteuerung“ – nicht bestätigen). Stattdessen eigenen X-Server starten (`Xvfb :99 -screen 0 1000x1100x24`) und die App dort öffnen: `DISPLAY=:99 flatpak run --socket=x11 --nosocket=wayland --env=GDK_BACKEND=x11 de.inneso.familynexus`. Eingaben per XTEST (z. B. python-xlib), Text finden per OCR (`tesseract -l deu+eng`), Screenshots aus dem Fenster. Dialoge des Desktop-Portals (Dateiauswahl, Mailprogramm, Benachrichtigungen) öffnen sich trotzdem auf dem echten Desktop → A-10 „Als Datei speichern“, E-05 „Per E-Mail senden“, E-17 und B-10 auf G2 prüfen.
- **Android-Emulator per adb:** `adb shell input text` kann keine Umlaute, kein `ß` und kein `„“` → Ersatzschreibung (z. B. `Kaese`, `Loeschtest`), im Report vermerken. Lange Werte (Schlüssel, Link) per Zwischenablage einfügen oder Zeichen für Zeichen tippen und vor dem Absenden per Screenshot gegen die Ablage prüfen. Elemente über `adb shell uiautomator dump` finden; „Bildschirmschutz“ vor dem Lauf aus (siehe Abschnitt 2). Bildschirmsperre (für B-17) mit `adb shell locksettings set-pin <PIN>` einrichten und am Ende mit `locksettings clear --old <PIN>` entfernen. Bei paralleler VirtualBox-VM kann der Emulator abstürzen (KVM belegt).
- **Dauerlauf:** Ein vollständiger Lauf dauert etwa 2 bis 3 Stunden. Skripte für Abschnitte mit Zeitlimit (`timeout`) starten, damit eine blockierte Eingabe nicht den Lauf anhält; Eingaben, die ohne Wirkung bleiben, per Screenshot prüfen, bevor weitergemacht wird.

## Anhang E: Änderungen nach den Läufen vom 26./27.10.2026

Quelle (Planversion 1.0 → 1.1): Report `Test-Apple-Report/2026-10-26/Testreport_FamilyNexus_EN_AURORA.pdf`. Korrigierte Planfehler:

| Nr. | Betrifft | Fehler im Plan | Korrektur |
|---|---|---|---|
| P-1 | Abschnitt 3, F | Reihenfolge nicht verbindlich; Konten wurden vor E-14 bis E-27 gelöscht | Verbindliche Reihenfolge und Vorbedingung für F |
| P-2 | V-04, F-03, F-06, E-32, F-01 | „Willkommen“ nach dem Löschen erwartet; App zeigt „Anmelden“ (B-1) | Erwartung mit Befundhinweis, Neustart-Schritt, Simulator-Alternative |
| P-3 | V-06, Abschnitt 3 | Namen gelöschter und Altkonten blieben unbeachtet | Regel zu Datumsteil `1026b`, Altkonten im Report |
| P-4 | E-05, E-06, E-07, E-12, Anhang A | Link als `familynexus://join` beschrieben; tatsächlich https-Adresse mit Weiterleitung; Simulator-Aufruf fehlte | Beschreibung und `simctl openurl` ergänzt |
| P-5 | E-10 | Zwischenschritt „Beitritt anfragen“ nach dem Schlüssel fehlte | ergänzt |
| P-6 | D-02 | Beitritt per Code erwartete „Fast geschafft!“; App meldete „Unbekannter Fehler.“ (B-3); Anfrage-Seite nicht prüfbar | Befundhinweis, Gegenprobe über Matrix-Knock, Übertragung des Codes beschrieben |
| P-7 | D-05, A-09 | Hänger („Synchronisiere …“, Schritt 1) nicht vorgesehen (B-2) | Wartezeiten und Vorgehen ergänzt |
| P-8 | E-16, E-13 | Alte Nachrichten für neues Mitglied nicht erwähnt; Status „Nicht persönlich geprüft“ fehlte | Erwartung ergänzt |
| P-9 | C-02, Abschnitt 2 | Gerätename „<Name von G1>“ unklar; Rollen G1/G2 nur für iPhone/Mac beschrieben | Gerätenamen „FamilyNexus macOS/iOS“, Rollenzuordnung |
| P-10 | A-07, A-09, A-10 | Ein Screenshot für sechs Eingaben; Speicherort der Datei nicht festgehalten | Bildnamen je Eingabe, Speicherort notieren |
| P-11 | Anhang D (neu) | Voraussetzungen der Bedienung per Werkzeug fehlten (Bedienungshilfen, Umlaute, Einfügen) | neuer Anhang |
| P-12 | D-02 | Erwartung „Unbekannter Fehler.“ als Normalfall von Lauf 1; Lauf 2 zeigte „Fast geschafft!“, aber keine Ablehnungsmeldung (#30) | Erwartung für beide Fälle, Issue-Verweise |
| P-13 | E-07 | Stale Safari-Seite führte zur falschen Familie | Safari vorher beenden |
| P-14 | E-14, E-18, E-24 | Reihenfolge: E-14 nach E-30 sinnlos; Verifizierungs-Rohtext (#29) im Einzelchat | Reihenfolgehinweise |
| P-15 | F-01 | Anmeldefehler nach Login (#28) nicht vorgesehen | Hinweis, Neustart |
| P-16 | V-06 | Fremde Altkonten (`fnt-1026c-n1`) | Suffix-Regel, nie fremde Konten benutzen |
| P-17 | Anhang D | Bedienung des Simulators unter „Device Hub“ und Dauer fehlten | ergänzt |

Quelle (Planversion 1.3 → 1.4): Lauf 3 auf Linux-Flatpak (G1) und Android-Emulator (G2) nach v1.0 @ `4abf400`, Report `Test-Apple-Report/2026-10-26_Linux-Android/Testreport_FamilyNexus_Linux-Android_EN_AURORA.pdf`; App-Befunde als Issues #31 bis #40, Ergänzungen in #23, #26, #30.

| Nr. | Betrifft | Fehler im Plan | Korrektur |
|---|---|---|---|
| P-18 | Kopf, V-03, V-04, F-01, F-03, F-06 | Erwartung „Build 16: Anmelden“; die Nummer 16 gibt es vor und nach PR #22, Release-Dateien v1.2.1 vom 26.10. zeigen „Willkommen“. V-03 nannte Release v1.2.1 mit Build 13 | Unterscheidung nach Commit `d20f0e0`; aktueller Stand der Release-Dateien |
| P-19 | V-02, V-03, Abschnitt 2 | Linux-Flatpak und x86_64-Emulator fehlten (Release-APK stürzt dort ab, #32); Bildschirmschutz ist ab Werk an | Befehle für Flatpak, Debug-APK für den Emulator, Hinweis zu FLAG_SECURE |
| P-20 | Abschnitt 2, C-02 | Verweis „Abschnitt G5“ statt G-08; Gerätenamen nur für macOS/iOS | G-08; „FamilyNexus <Plattform>“ |
| P-21 | B-02, B-10, B-17, B-18 | Funktionen ohne Gegenstück unter Linux/Windows nicht geregelt | Schritt auf G2, Vermerk im Report |
| P-22 | B-08 | „Verlauf“ zeigt „Version 1 und 2“; die App listet nur frühere Fassungen | Erwartung „Verlauf (1)“ mit „Version 1“ |
| P-23 | D-02, D-03 | Einstieg „Ich wurde doch eingeladen“ gibt es nach „Noch kein Konto? Jetzt erstellen“ nicht (Umschalter „Gründen \| Beitreten“); Ablehnung kommt verzögert; D-03 erwartete „Später“ | Beide Einstiege, Wartezeit 3 Min., Ende ohne „Fertig!“ |
| P-24 | E-05 | Schaltfläche „QR-Code anzeigen“ gibt es nicht | QR-Code wird direkt angezeigt |
| P-25 | E-06 | Gekürzter Link (letzte 10 Zeichen) wird angenommen, weil nur der Einladername fehlt | Teil `&n=…` entfernen |
| P-26 | E-07 bis E-10 | Beitrittskarte direkt nach dem Link erwartet; ohne Konto kommt erst die Kontoanlage | Reihenfolge erklärt, Android-Aufruf |
| P-27 | E-12 | Gerät G1 statt G2; Android öffnet den Link im Browser; Meldung ist flüchtig | G2, Browser-Weg, sofort aufnehmen |
| P-28 | E-17 | Speichern eines Bildes erwartet; Bilder haben nur „Anhang laden“ (#40) | Bild und Textdatei, Speichern mit der Textdatei |
| P-29 | E-19 | „Test Serie“ für I2 sichtbar erwartet; sie ist privat (Standard) | Erwartung „nicht sichtbar“, B-06 nennt „Privat“ |
| P-30 | B-01, B-04, B-05, B-12, B-14, B-15, C-02, E-16, E-18, F-01, Anhang D | Bekannte App-Befunde ohne Hinweis; Bedienung unter Linux/Android fehlte | Issue-Verweise #31 bis #39, Schutz gegen versehentliches Senden in E-18, Anhang D für Linux und Android |

## Versionshistorie

Regel: Änderungen an Schritten, erwarteten Ergebnissen oder Reihenfolge erhöhen die Nebenversion (1.1 → 1.2); Umbau der Struktur oder des Umfangs die Hauptversion (1.x → 2.0); reine Tippfehler bleiben ohne neue Version. Jeder Report trägt auf der ersten Seite „TP-FN-001 v<Version> @ <Commit>“, jedes Issue aus einem Lauf verweist auf Planversion, Commit und Schritt-ID.

| Version | Datum | Commit | Änderung |
|---|---|---|---|
| 1.0 | 26.10.2026 | `4abf400` | Gesamtplan, ersetzt `Testplan_Nutzeranlage.md`, `Testplan_Pruefanleitung.md`, `Testplan_Einladung_Zweiter_Nutzer.md`, `Testdaten_Stammdaten.md` (Zuordnung alter IDs: Anhang C); Erwartungen gegen den Code bestätigt |
| 1.1 | 26.10.2026 | `4f03868` | Korrekturen P-1 bis P-11 nach dem Lauf vom 26.10.2026 (Anhang E): verbindliche Reihenfolge, Erwartungen zu B-1 bis B-4, Link-Format, Beitrittsschritte, Datumsteil für Läufe am selben Tag, Anhang D (automatisierte Bedienung) |
| 1.2 | 26.10.2026 | `d6cecbf` | Konfliktauflösung mit PR #22 (B-1 auf `main` behoben): Erwartungen „Willkommen“ nach Löschen, Hinweis für Build 16; Issues #23 bis #27 verlinkt |
| 1.3 | 27.10.2026 | `dd389fe` | Korrekturen P-12 bis P-17 nach Lauf 2 (Anhang E); Issues #28 bis #30 verlinkt |
| 1.4 | 27.10.2026 | `e31cd04` | Korrekturen P-18 bis P-30 nach Lauf 3 (Linux/Android, Anhang E); Issues #31 bis #40 verlinkt |

**Zuordnung Issues zur Planversion:** #23 bis #27 (Lauf 1) beziehen sich auf v1.0 (`4abf400`), #28 bis #30 (Lauf 2) auf v1.2 (`d6cecbf`), #31 bis #40 (Lauf 3, Linux/Android) auf v1.0 (`4abf400`); die Plantexte dazu stehen seit v1.1, v1.3 bzw. v1.4 im Plan.
