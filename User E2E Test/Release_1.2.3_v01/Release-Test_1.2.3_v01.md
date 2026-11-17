# Release-Test FamilyNexus 1.2.3 (neue Funktionen, Änderungen, offene Nachtests)

**Planversion: v06** (16.11.2026) · Dokument-ID `TP-FN-REL-123` · Stand: `main` @ `531981a` (enthält PR #482 und die Fixes #483 bis #487, PRs #489 bis #493) plus Build-Nummer 30 (PR #495, Branch `chore/build-30`, Commit `7bb3727`); Soll-Version der App **1.2.3 (30)** (`pubspec.yaml`: `1.2.3+30`). **Alle Schritte laufen auf einem Build, der aus dem aktuellen `main`-Stand gebaut wurde (Commit im Report, RT3-V-05), nicht auf dem TestFlight-/APK-Build 29 vom 13.11. (Build 30 ist freigegeben, aber nicht gebaut und nicht hochgeladen).**

Bezug: Milestone „Release v1.2.3“ (39 offene Issues am 15.11. abends, siehe `Sprint/sprint_1.2.3.md`), Release Notes 1.2.3 (`store/metadata/*/release_notes.txt`), `docs/ENTSCHEIDUNGEN.md` (E-93 bis E-102), Release-Review `docs/release-reviews/1.2.3+29.md` (Läufe 1 bis 5) und `1.2.3+30.md` (Lauf 1, PR #496), Gesamtplan `Testplan_FamilyNexus.md` (TP-FN-001), Benachrichtigungsplan `Testplan_Benachrichtigungen_macOS-iOS.md` (TP-FN-NTF-381 v03), Geräte-Checkliste `Checkliste_Geraetenachtests.md`, Vorgänger `../Release-Test_1.2.2_v01.md` (TP-FN-REL-122).

## 1. Ziel und Abgrenzung

Der Plan deckt drei Dinge ab, jeweils auf **echten Geräten und Emulatoren/Simulatoren**:

1. **Neu in 1.2.3** (Abschnitte C bis I): Gesprächsliste, Avatare, Kalender-Themen, Jahresfortschritt, 15-Minuten-Abgleich, Einführungstour, App teilen und bewerten, Ladebild, Identitätsvermerke auf dem Gerät, Textänderungen.
2. **Geänderte Verhalten und Fehlerbehebungen** (Abschnitte B, J bis M): Heute-Karte, Meldungen nur bei geöffneter App, Eingabefeld, Einrichtung, Anmeldung, Tablet, Screenreader, Windows-Overlay, Zeitwähler.
3. **Alle offenen Nachtests** der Issues aus Milestone v1.2.3 (Abschnitt 14 ordnet jedes der 39 offenen Issues zu) und die **Fehlerbehebungen aus dem Release-Review 1.2.3+29** (Abschnitt P, einschließlich #483 bis #487 aus Lauf 4; alle Fixes liegen auf `main`, die Schritte gelten unbedingt) und die **Regression der Umbauten** (Abschnitt R: E-96, E-97, Bildschirme und Gateway zerlegt, ohne Verhaltensänderung).

**Ziel der Abnahme v03:** Die Issues sind für **iOS, macOS und Android** abnehmbar, wenn die zugeordneten Schritte auf dem Simulator (iOS), der gebauten Mac-App und dem Android-Emulator ✅ sind (Abschnitt 2a). Was ein Simulator/Emulator prinzipiell nicht belegt, steht in Abschnitt 2a als **Restpunkt am echten Gerät**; solche Issues schließen nur mit benanntem Rest oder nach dem Gerätetest (CLAUDE.md: Was hier nicht ausführbar ist, gilt als nicht getestet).

Der Plan ergänzt den Gesamtplan TP-FN-001, ersetzt ihn nicht. Wo ein Schritt dort schon ausführlich steht, nennt die Spalte „Vertiefung“ die ID (z. B. B-26, E-18c). Der Plan folgt dem Aufbau von TP-FN-REL-122.

**Nicht Inhalt (nicht gebaut oder nicht im Release):**

- #431 (Termine durch alle Moderatoren bearbeiten, Änderungslog): nach v1.3 verschoben (Entscheidung E1, 15.11.), kein Code.
- Anmeldung auf Linux und Windows (bleibt der externe Browser, E-102); Windows und Linux gehören nicht zu den Plattformen dieser Abnahme (iOS, macOS, Android), ihre Schritte stehen unverändert im Plan.
- Foto-Upload für Avatare (E-101), Push-Dienst (#273/#381 Teil 2), Meldungen bei geschlossener App auf Mobilgeräten (nicht zugesagt, E-88).
- Matrix-Abläufe ohne UI (Wettläufe, Backoff, Verwerfen unverschlüsselter Ereignisse): automatische Tests, Abschnitt T.

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ nicht durchgeführt (mit Grund) · n/a (auf der Plattform nicht vorhanden, mit Grund).
**Ein Schritt gilt nur als ✅, wenn das erwartete Ergebnis am Screenshot (oder an der genannten Ausgabe) nachweisbar ist.** Was nicht ausgeführt wurde, ist ⏳, nie ✅. Beschriftungen stammen aus `lib/l10n/app_de.arb` und `app_en.arb`; weicht ein Wortlaut ab, ist das ein Befund, kein Planfehler.

## 2. Festlegung von Plattform und System (vor dem ersten Schritt ausfüllen)

**Build-Regel (v04):** Getestet wird ausschließlich ein Build vom **aktuellen `main`-Stand** (HEAD nach Merge von PR #482, der Fixes #483 bis #487, der Build-Nummer 30 (PR #495) und aller Folge-Fixes bis zum Freeze). Ist PR #495 noch nicht gemergt, zeigt der Build „1.2.3 (29)“ und RT3-V-02 scheitert; dann zuerst mergen oder den Branch `chore/build-30` dazunehmen. Der Commit steht im Report (RT3-V-01, RT3-V-05). Belege auf Build 29 (13.11.) oder älteren Ständen gelten nicht; die Schritte werden wiederholt. Die Build-Nummer 30 ist mit PR #495 vorbereitet; es ist kein Upload nötig: Simulator, Emulator und lokale Mac-App werden aus dem Arbeitsbaum gebaut (CLAUDE.md: keine Build-Nummer ändern, kein TestFlight-Upload ohne Freigabe). Ein Schritt mit „Soll 1.2.3 (30)“ prüft nur die Anzeige, nicht, dass es ein hochgeladener Build 30 ist.

Plattformkürzel: **iOS** (iPhone), **iPad**, **Mac**, **And** (Android-Telefon), **AndT** (Android-Tablet), **Win**, **Lin** (Flatpak), **Web**.

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | | |
| Gerät oder Simulator/Emulator (Modell, Name) | | |
| Betriebssystem und Version | | |
| Bei Web: Browser und Version | | |
| Installationsquelle (Build aus `main`, TestFlight, APK, Zip, Flatpak …) | | |
| App-Version Soll / Ist (RT3-V-01, RT3-V-02) | 1.2.3 (30) / | 1.2.3 (30) / |
| Gerätesprache, 12-/24-Stunden-Einstellung, Schriftgröße | | |
| Methode für Screenshots | | |
| Tester / Datum / Uhrzeit Beginn | | |

**Mindestabdeckung für die Freigabe** (entspricht den Gerätenachtests T1 bis T7 im Sprintplan):

| Termin | Gerät | Abschnitte |
|---|---|---|
| T1 | iPhone (echt) | V, A, B, C, D, E, F, G, H, I, K (VoiceOver), P-01, P-04 bis P-09, P-13, R |
| T2 | iPad (Hoch, Quer, Split View) | J, G, A, R |
| T3 | Signierter Mac (TestFlight) | V, A, B, F, G, J, L, R |
| T4 | Android-Telefon und -Tablet | C, D, E, F, G, H, I, J, K (TalkBack), P-01, P-04 bis P-09, P-13, R |
| T5 | Windows 11 mit physischer Tastatur | E-06, F, J, K, L, M |
| T6 | Zwei Konten (zwei Geräte, Testserver) | C, D, E (Themen) |
| T7 | Play Console | N, P-10 |
| Dev | Entwicklungsrechner (Docker) | T, L-03, L-05, L-07, P-02, P-03, P-11, P-12 |

Seit v03 laufen T1 bis T4 auf **Simulator (iOS, iPad), gebauter Mac-App und Android-Emulator** (Abschnitt 2a); das echte Gerät ist nur für die dort genannten Restpunkte nötig. Wo weder Gerät noch Simulator/Emulator den Schritt belegt, bleibt er ⏳ mit Grund und das zugehörige Issue offen.

**Screenshots:** Methoden je Plattform wie in `Testplan_FamilyNexus.md`, Abschnitt 2. Dateiname `<Schritt-ID>_<Plattform>.png`, z. B. `RT3-C-03_iOS.png`. **Windows hat den Bildschirmschutz ab Werk an** (Fenster fehlt in Screenshots): vor dem Lauf ausschalten, im Report vermerken, danach wieder anschalten. Notfall-Schlüssel, Passwörter, Einladungslinks und Namen echter Personen auf Screenshots **schwärzen**.

## 2a. Simulatoren, Emulatoren und Abnahmegrenzen (v03)

Verfügbar auf dem Entwicklungsrechner (macOS): iOS-Simulatoren (iOS 26.4/26.5: iPhone 17 Pro, iPhone 17, iPad Pro 13/11, iPad Air, iPad mini), die Mac-App (`flutter run -d macos` bzw. `flutter build macos`), Android-Emulatoren `Pixel8_API35` (Telefon) und `fn_test`. **Für Tablet (Abschnitt J) fehlt ein Android-Tablet-AVD**: vorab anlegen (z. B. Pixel Tablet, API 35) und im Report nennen, sonst bleibt J auf Android ⏳.

| Plattform | Umgebung | Start (Beispiel) | Kennung im Report |
|---|---|---|---|
| iOS | iPhone 17 Pro, iOS 26.5 (Simulator) | `xcrun simctl boot <UDID>`; `flutter run -d <UDID> --release`/`--debug` | Simulator-Name, iOS-Version, Commit |
| iPad | iPad Pro 13-inch (M5) und iPad mini (Simulator) | wie iOS; Hoch/Quer: `Hardware → Rotate`; Split View/Stage Manager im Simulator | wie iOS |
| Mac | Mac-App aus dem Arbeitsbaum (Entwicklungssignatur) | `flutter run -d macos` | macOS-Version, Commit, Signierung (dev) |
| And | `Pixel8_API35` (Emulator, Google-APIs) | `emulator -avd Pixel8_API35 -no-snapshot`, `adb devices`, `flutter run -d emulator-5554` | AVD, API-Level, Commit |
| AndT | Tablet-AVD (anzulegen), Drehen und Multi-Window | wie And | AVD, Commit |

**Testserver für Simulator/Emulator:** lokaler Synapse. Der iOS-Simulator und der Mac erreichen `https://localhost:18448`; der Android-Emulator erreicht den Host über `10.0.2.2:18448` (Zertifikat des lokalen Servers muss in der App/Test-Konfiguration zugelassen sein wie in `tool/e2e.sh`; sonst ⏳ mit Grund). Zwei Konten (G1, G2) heißt: zwei Simulatoren/Emulatoren oder Simulator plus Mac gleichzeitig.

**Was Simulator/Emulator belegen und was nicht** (Restpunkte bleiben als „Rest am Gerät“ im Issue):

| Thema | Simulator/Emulator belegt | Rest am echten Gerät |
|---|---|---|
| Layout, Texte, Logik, Sync, Chat, Kalender, Avatare, Themen, Einführungstour | ja | – |
| #316 Startperformance | nur Ablauf ohne weißen/schwarzen Bildschirm; Zeiten sind nicht aussagekräftig | Messung auf iPhone/Android-Gerät |
| #345 Ladebild | Vorschaubild hell/dunkel im Simulator (`simctl ui appearance`) | – |
| #254, #381 Meldungen, Zähler am Symbol | lokale Meldungen bei offener App, Badge auf iOS-Simulator/Mac/Android-Emulator; App-Hintergrund auf Android ist laut #273 nicht zugesagt | Sperrbildschirm und Zähler am echten iPhone; Push (#273) ist v1.3 |
| #332, #463, #326 Screenreader | Android: TalkBack im Emulator; iOS/Mac: Accessibility Inspector und Semantikbaum (Text des Labels belegt), **keine** Sprachausgabe | VoiceOver-Sprachausgabe |
| #144 Screenshot-Schutz | iOS: nur der Einstellungstext (kein Schutz zugesagt); Android `FLAG_SECURE` im Emulator-Screenshot prüfbar | Windows-Aufnahme (nicht Teil dieser Abnahme) |
| #268, #297, #441 Anmeldung | Eingebettete Ansicht (WebView) auf allen drei Plattformen gegen den **Testserver** bzw. eine **lokale Testseite** (Navigationsregeln, Schließen, Löschen); echte Anbieterseite nur mit Freigabe | matrix.org mit eigenem Konto, Fremdanbieter, Passkeys, Apple-Review |
| #266 Mac-Laufzeit `sqlite3` | Mac-App mit Entwicklungssignatur, Schlüsselbund | Distributions-Signatur (TestFlight/DMG) |
| #350 „App bewerten“, #351 „App teilen“ | Aufruf des Share-Sheets und des Store-Links im Emulator/Simulator (Play Store im Google-APIs-AVD) | Verhalten im echten Store |
| #348, #349, #15 | – (nicht in dieser Abnahme) | Play Console, App Store Connect, Prüfkonto: manuell durch den Nutzer |

## 3. Testserver, Konten, Grenzen

- **Server:** lokaler Synapse (`tool/synapse/up.sh`, danach `curl -fsk https://localhost:18448/_matrix/client/versions` muss 200 liefern) bzw. der eigene Testserver. **Wegwerfkonten**, am Ende löschen (Abschnitt Z).
- **Keine echten Konten oder Registrierungen bei matrix.org.** Schritte mit matrix.org (RT3-G-04, RT3-G-05, RT3-G-06, RT3-G-07, RT3-G-08) laufen nur mit ausdrücklicher Freigabe des Nutzers und eigenem Konto; sonst ⏳. Der Testserver hat keinen OAuth-Anbieter, daher bleibt die System-Sitzung ohne Freigabe ⏳.
- **Keine Geheimnisse in Repository oder Issues:** Passwörter und Notfall-Schlüssel nur in einer von Git ignorierten Datei (`secure/…`).
- **Rollen:** N1 = Moderator und Gründer (G1), I2 = eingeladene Person (G2). Für Themen und Avatare zusätzlich: ein zweiter Moderator M3 (RT3-E-05) und ein später beigetretenes Mitglied I4.
- **Bestehende Familie:** Für RT3-D-07 (Freischaltung der Avatare) wird eine Familie benötigt, die **vor** diesem Build angelegt wurde (Build 1.2.2 (26) oder 1.2.3 (28)).

## 4. Abschnittsübersicht

| Abschnitt | Thema | Issues / Entscheidungen |
|---|---|---|
| 2a | Simulatoren, Emulatoren, Abnahmegrenzen (Voraussetzung, keine Schritte) | alle |
| V | Version und Installation, Build-Identität | – |
| A | Start, Ladebild, Startbild | #316, #345, E-94 |
| B | Heute und Erinnerungen | #317, E-93 |
| C | Chat: Gesprächsliste, Eingabefeld, Screenreader | #423, #410, #332, E-100 |
| D | Avatare | #422, E-101 |
| E | Kalender: Themen, Jahresfortschritt, Abgleich, Speichern, Zeitwähler | #424, #337, #358, #409, #263, E-99, E-95 |
| F | Meldungen und Zahl am App-Symbol | #254, #381, #273, #330, E-88 |
| G | Anmeldung und Anbieterseiten in der App (eingebettete Ansicht) | #268, #297, #441, #412, #430, E-91, E-102 |
| H | Einrichtung und Einführungstour | #411, #347, E-45, E-95 |
| I | Einstellungen: App teilen und bewerten, Screenshot-Schutz, Texte | #350, #351, #144, #326, E-95, E-98 |
| J | Tablet und große Fenster | #274, E-92 |
| K | Screenreader und Bedienhilfen | #332, #326, #423, #422 |
| L | Plattform: Windows, Apple-Laufzeit, Web, Identitätsvermerke | #263, #325, #330, #266, #142, #440 |
| M | Windows-Besonderheiten | #263, #325, #330, #144 |
| N | Store und Apple (manuell; Bildpaket im Repo prüfbar) | #348, #349, #15 |
| P | Fehlerbehebungen und Unterlagen aus dem Release-Review 1.2.3+29 | #444 bis #451, #458 bis #464, #483 bis #487, #442 |
| R | Regression der Umbauten | E-96, E-97 |
| T | Automatische Tests | Pflichtteil |
| Z | Aufräumen | – |

## 5. Testschritte

Spalten: **ID** · **Pl.** (Plattformen, `alle` = alle festgelegten) · **Schritt** · **Erwartetes Ergebnis** · **Vertiefung** · **Screenshot** · **Beob.** · **Erg.** Die letzten drei füllt der Tester.

### V. Version und Installation

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-V-01 | alle | `pubspec.yaml` öffnen, Zeile `version:` notieren, `git rev-parse --short HEAD` mitschreiben | `version: 1.2.3+30` (oder der im Report genannte spätere Stand) | – | `RT3-V-01_pubspec.png` | | |
| RT3-V-02 | alle | App installieren, starten, Einstellungen → „Über die App“ | „Version 1.2.3 (30)“, passt zu RT3-V-01 | – | `RT3-V-02_<Pl>.png` | | |
| RT3-V-03 | alle | Alle lokalen Daten löschen (Einstellungen), App neu starten | Willkommensseite „Willkommen bei FamilyNexus“, keine Reste einer früheren Sitzung | – | `RT3-V-03_<Pl>.png` | | |
| RT3-V-05 | alle | Build vom aktuellen `main` bauen; `git rev-parse --short HEAD`, `git log -1 --format=%cI`, `git status --short` (sauber bis auf Testunterlagen) | Commit enthält PR #482, #489 bis #493 und #495 (`git log --oneline | grep -E '482|489|49[0-3]|495'` bzw. `main` nach dem Merge); der Commit steht im Report; Version in der App „1.2.3 (30)“ | – | `RT3-V-05.txt` | | |
| RT3-V-04 | iOS, Mac, And | **Update über eine Vorversion (1.2.2 (26)):** Familie in 1.2.2 anlegen, mit Termin, Einkauf, Chat; auf 1.2.3 (30) aktualisieren, starten | Anmeldung bleibt, Daten vorhanden, keine Einführungstour (bestehende Einrichtung gilt als gesehen, E-95), keine Fehlermeldung | E-95 | `RT3-V-04_<Pl>.png` | | |

### A. Start, Ladebild, Startbild (#316, #345, E-94)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-A-01 | iOS, iPad | App beenden (im Umschalter wegwischen), System **hell**, App-Thema „Hell“, neu öffnen; Aufnahme der ersten Sekunden (Bildschirmaufnahme) | Erst einfarbiges Startbild (hell, kein Logo), dann „Lädt …“ mit Aurora-Hintergrund, nie ein weißer oder schwarzer Bildschirm | E-94, A-01 | `RT3-A-01_<Pl>.mp4` | | |
| RT3-A-02 | iOS, iPad | Wie A-01 mit System **dunkel**, App „Dunkel“ | Startbild und „Lädt …“ dunkel, kein heller Blitz | E-94 | `RT3-A-02_<Pl>.mp4` | | |
| RT3-A-03 | iOS, iPad, Mac, And | System hell, App-Thema „Dunkel“ (abweichend vom System) | Das Ladebild folgt dem **System** (hell); ein einmaliger Wechsel auf dunkel beim Übergang zur App ist **erwartet** (E-94, #345, Variante A), kein Befund | #345 | `RT3-A-03_<Pl>.mp4` | | |
| RT3-A-04 | iOS | Nach A-03 im App-Umschalter die App ansehen | Notieren, ob iOS kurz das Vorschaubild des letzten Zustands zeigt (vermutlich Systemverhalten, #345, nur festhalten) | #345 | `RT3-A-04_iOS.png` | | |
| RT3-A-05 | iOS (echt) | `flutter run --profile` am Gerät, Kaltstart, Log auswerten | Je Startschritt eine Zeile `schritt=<name> ms=<n>`; Zeit bis „Heute“ notieren; ein einzelner Schritt über 50 % der Gesamtzeit wird als Folge-Issue vermerkt | #316 | `RT3-A-05.txt` | | |
| RT3-A-06 | Mac, And, Win, Lin | Kaltstart hell und dunkel | „Lädt …“ erscheint, danach „Heute“ bzw. Willkommensseite; nie leere Fläche | E-94 | `RT3-A-06_<Pl>.png` | | |
| RT3-A-07 | alle | Start mit unlesbarer Datenbank (Datenbankdatei der App beschädigen, nur Wegwerfkonto) | Fehlerseite „Lokale Daten nicht lesbar“ mit „Erneut versuchen“; nach „Erneut versuchen“ wieder das Ladebild, nicht die alte Fehlerseite | E-94 | `RT3-A-07_<Pl>.png` | | |

### B. Heute und Erinnerungen (#317, E-93)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-B-01 | iOS, Mac | Systemeinstellungen: Benachrichtigungen für FamilyNexus **aus**; App → „Heute“ | Karte „Berechtigung fehlt“ (Hinweis) und die Karte „Erinnerungen“ **genau einmal**; keine zwei Karten mit gleicher Überschrift | B-02 | `RT3-B-01_<Pl>.png` | | |
| RT3-B-02 | iOS, Mac | Hinweiskarte antippen bzw. Erinnerungs-Übersicht öffnen | AppBar „Erinnerungen“, darunter die Hinweiskarte „Berechtigung fehlt“, „Erinnerungen“ steht einmal als AppBar-Titel; in den Einstellungen der Hinweis ohne Kartentitel | E-93 | `RT3-B-02_<Pl>.png` | | |
| RT3-B-03 | iOS, Mac | B-01 und B-02 mit Thema hell, dunkel und Schrift 200 % | Texte vollständig lesbar, kein Überlauf, Kontrast ausreichend | – | `RT3-B-03_<Pl>.png` | | |
| RT3-B-04 | Win, Lin, Mac (Debug) | „Heute“ mit Erinnerungen öffnen | Unter Linux und Windows **keine** Karte „Berechtigung fehlt“ (Berechtigung gilt dort immer als erteilt); „Erinnerungen“ genau einmal | #317 | `RT3-B-04_<Pl>.png` | | |
| RT3-B-05 | alle | Termin mit Erinnerung „10 Minuten vorher“ anlegen; Erinnerungs-Übersicht öffnen | Zeile „Erinnerung: <Uhrzeit>“ (E-98, kein „Erinnerung in“), Titel des Termins | E-98 | `RT3-B-05_<Pl>.png` | | |
| RT3-B-06 | iOS, Mac, And | **#498:** Zwei Termine mit „10 Minuten vorher“ anlegen, deren Erinnerungszeit schon verstrichen ist (z. B. Termin in 5 und 8 Minuten); „Heute“ ansehen; danach alle bestätigen | Karte „Erinnerungen“ zeigt nur „2 Erinnerungen fällig“, **nicht** zugleich „Keine Erinnerung geplant“; nach „Alle bestätigen“ wieder „Keine Erinnerung geplant“ | #498, E-87 | `RT3-B-06_<Pl>.png` | | |

### C. Chat: Gesprächsliste, Eingabefeld, Screenreader (#423, #410, #332, E-100)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-C-01 | alle (G2) | Familie mit einem Einzelchat (N1 ↔ I2); G2: Tab „Chat“ öffnen | Beginnt mit „Gespräche“: zuerst „Familienchat <Name>“, darunter „<Name>“; je Zeile Titel, **eine** Zeile Vorschau (eigene Nachrichten „Du: …“), Zeit; keine Chip-Leiste | E-18c | `RT3-C-01_<Pl>.png` | | |
| RT3-C-02 | alle (G2) | Zeile „Familienchat“ öffnen, `Entwurf Liste` tippen, Pfeil „Zurück zu den Gesprächen“, Einzelchat öffnen | Kopfzeile mit Pfeil, Titel, Online-Status als Punkt **und** Text; der Entwurf bleibt gesprächsübergreifend erhalten (#410) | E-18c | `RT3-C-02_<Pl>.png` | | |
| RT3-C-03 | alle (G1, G2) | G2 steht auf der Liste; G1 sendet `Liste 1` (Familie) und `Liste 2` (Einzel) | Zeile zeigt fetten Titel **und** Zähler; Tab-Zähler stimmt; die Liste markiert nichts als gelesen; Zähler bleiben bis zum Öffnen | E-18c, E-88 | `RT3-C-03_<Pl>.png` | | |
| RT3-C-04 | alle (G2) | Gespräch offen, zu „Heute“ und zurück zu „Chat“ | Das geöffnete Gespräch bleibt offen, Entwurf und Scrollposition erhalten | E-100 | `RT3-C-04_<Pl>.png` | | |
| RT3-C-05 | And | Zurück-Taste bzw. Zurück-Geste: im Gespräch; auf der Liste; im Gespräch mit offenem Menü; im Gespräch auf Tab „Einkauf“ | Im Gespräch → Liste (App bleibt offen); auf der Liste verlässt Zurück die App; bei offenem Menü schließt Zurück nur das Menü; auf „Einkauf“ verlässt Zurück die App | E-18c | `RT3-C-05_And.png` | | |
| RT3-C-06 | iOS, iPad, Mac, Win, Lin | Wie C-05: nur der Pfeil, keine Systemgeste | Pfeil führt zur Liste; kein Absturz bei Wischgeste von links (iOS) | E-100 | `RT3-C-06_<Pl>.png` | | |
| RT3-C-07 | iPad, AndT, Win, Mac | Fenster ≥ 1000 dp, Tab „Kalender“, Gespräch öffnen, Zurück | Liste steht in der Chatspalte, Zurück wirkt auf sie, Kalender bleibt | E-92, E-100 | `RT3-C-07_<Pl>.png` | | |
| RT3-C-08 | alle | Familie ohne Einzelchat (nur Familienchat) | Chat-Tab zeigt direkt den Familienchat ohne Kopfzeile und ohne Liste | E-100 | `RT3-C-08_<Pl>.png` | | |
| RT3-C-09 | alle | Mitglied mit Einzelchat entfernen oder blockieren, während sein Gespräch offen ist | Familienchat erscheint sofort (nicht Liste), Entwurf bleibt | E-100 | `RT3-C-09_<Pl>.png` | | |
| RT3-C-10 | alle | Zwei Nachrichten im Einzelchat; die ältere im Verlauf hinter einer neueren einsortiert (Zickzack) | Vorschau zeigt die Nachricht mit dem **größten Zeitstempel**; Reaktionen zählen nicht als Vorschau | E-100, #295 | `RT3-C-10_<Pl>.png` | | |
| RT3-C-11 | alle | Nachricht mit Zeilenumbruch senden, dann Anhang ohne Text, dann geteilten Termin | Vorschau: Text in **einer** Zeile; „Anhang“; „Termin“ | E-100 | `RT3-C-11_<Pl>.png` | | |
| RT3-C-12 | alle (G2) | Tippen im Eingabefeld, dann senden; bei langsamer Verbindung währenddessen anderes Gespräch öffnen und Text im Feld ändern | Das Feld leert sich nur, wenn Gespräch und Text unverändert sind; geänderter Text bleibt stehen, keine Nachricht geht an das falsche Gespräch | #410 | `RT3-C-12_<Pl>.png` | | |
| RT3-C-13 | alle | Eigene Chatnachricht ansehen und mit Screenreader vorlesen (siehe K-02) | Anzeige unverändert | #332 | `RT3-C-13_<Pl>.png` | | |
| RT3-C-14 | alle | Mit App-Sperre (Sofort): sperren, von G1 Nachricht senden, entsperren | Unter der Sperre erscheint keine Vorschau, nichts wird gelesen markiert; nach dem Entsperren Marke „Neue Nachrichten“ im geöffneten Gespräch | B-17 | `RT3-C-14_<Pl>.png` | | |

### D. Avatare (#422, E-101)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-D-01 | alle (G2) | Menü → „Familie“, an der eigenen Kachel „Avatar ändern“ | Auswahl mit zwölf Avataren und „Initialen (kein Avatar)“; Namen sichtbar, Touch-Ziele ≥ 48 dp | E-19b | `RT3-D-01_<Pl>.png` | | |
| RT3-D-02 | alle (G2) | „Segelboot“ wählen, „Speichern“; höchstens 20 s beobachten, Hinweis „Avatar gespeichert“ abwarten (#506) | Der Avatar-Bildschirm (kein Dialog) schließt von selbst, sobald die Wahl gemeldet ist, spätestens nach 15 s (zwischendurch „Wird übernommen …“); „Avatar gespeichert“ bleibt als Hinweis sichtbar; danach das Segelboot an der eigenen Kachel, ohne „Zurück“ zu tippen (#506, E-101-Nachtrag, PR #522). Bleibt der Bildschirm länger offen, als Fehler festhalten | E-101 | `RT3-D-02_<Pl>.png` | | |
| RT3-D-03 | alle (G1) | Familie, Chat, Kalender, Heute ansehen | Bei I2 Segelboot: Mitgliederliste, links neben jeder Nachricht von I2 (nicht bei eigenen), Gesprächsliste (40 dp mit Online-Punkt **und** Text), Kalender (Ring in der Personenfarbe: Kachel, Terminkarte nur mit Thema, Zusagenliste, Personenfilter), „Heute“ (online) | E-19b | `RT3-D-03_<Pl>.png` | | |
| RT3-D-04 | alle (G2→G1) | G2 wechselt zu „Initialen (kein Avatar)“ | G1 sieht den Anfangsbuchstaben in der Personenfarbe, Name unverändert | E-101 | `RT3-D-04_<Pl>.png` | | |
| RT3-D-05 | alle | Hell, dunkel, Schrift 200 % an Familie und Kalender | Avatar nicht abgeschnitten, Kontrast Buchstabe ≥ 4,5:1, Symbol ≥ 3:1 | E-101 | `RT3-D-05_<Pl>.png` | | |
| RT3-D-06 | alle | Neues Mitglied (I4) tritt bei, wählt Avatar | Auswahl möglich, ohne dass der Moderator etwas tut (Familie neu in 1.2.3) | E-101 | `RT3-D-06_<Pl>.png` | | |
| RT3-D-07 | iOS, Mac, And | **Bestehende Familie** (vor 1.2.3 angelegt): Mitglied öffnet „Avatar ändern“, bevor ein Moderator die App geöffnet hat | Hinweis „Ein Moderator muss die Avatar-Funktion für diese Familie erst freischalten …“, kein Raster; nach Öffnen der App durch den Moderator ist die Auswahl da | E-19b | `RT3-D-07_<Pl>.png` | | |
| RT3-D-08 | alle | G1 (Moderator) entfernt I2 (Wegwerfkonto) | Für I2 nur noch der Buchstabe (Name unverändert); keine Fehlermeldung | E-101 | `RT3-D-08_<Pl>.png` | | |
| RT3-D-09 | alle | Datenschutz: Einstellungen → Datenschutz, Datenübersicht ansehen | Die sichtbare Avatar-Wahl ist als einzige Ausnahme der Ende-zu-Ende-Verschlüsselung genannt; Datenübersicht kennt den Avatar | E-101 | `RT3-D-09_<Pl>.png` | | |

### E. Kalender (#424, #337, #358, #409, #263, E-99, E-95)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-E-01 | alle (G1) | Familie → „Kalender-Themen“ → „Thema anlegen“: `Schule`, „Lila“; `Sport`, „Grün“; Farbdialog ansehen; umbenennen und zurück | Eintrag nur für Moderatoren; sieben Farben mit Namen (Türkis, Rosa, Lila, Gelb, Grün, Orange, Rot), **kein** „Himmelblau“ | B-26 | `RT3-E-01_<Pl>.png` | | |
| RT3-E-02 | alle (G1) | „Neuer Termin“ `Test Thema`: „Privat“ ansehen; „Geteilt“ → Thema „Schule“ → Speichern | Bei „Privat“ keine Farbwahl, „Privat: immer blau“; bei „Geteilt“ Chips „Ohne Thema“, „Schule“, „Sport“ mit Farbpunkt und Name; Termin in Lila, Themenname als Text, Avatar mit Ring „Von dir“, Abzeichen „Geteilt“ | B-26 | `RT3-E-02_<Pl>.png` | | |
| RT3-E-03 | alle (G1) | Termin auf „Privat“ stellen | Termin blau, ohne Thema (Kopie mit neuer ID); alte Termine behalten ihre Farbe, nie umgefärbt | B-26 | `RT3-E-03_<Pl>.png` | | |
| RT3-E-04 | alle (G2) | I2: kein Eintrag „Kalender-Themen“; Termin `Termin I2 Thema` mit Thema „Sport“ anlegen | Auswahl zeigt „Schule“ und „Sport“; G1 sieht den Termin in Grün mit Namen „Sport“ | E-19a | `RT3-E-04_<Pl>.png` | | |
| RT3-E-05 | alle (G1, M3) | G1 legt `Neu` („Gelb“) an; M3 (zweiter Moderator) ändert `Sport` gleichzeitig; G1 löscht „Sport“ | `Neu` erscheint bei G2; Änderungen von zwei Moderatoren an verschiedenen Themen gehen nicht verloren; nach dem Löschen zeigt der Termin die bisherige Farbe ohne Themennamen | E-19a, E-99 | `RT3-E-05_<Pl>.png` | | |
| RT3-E-06 | alle | Thema mit mehr als 30 Zeichen und 13. Thema anlegen | Name wird begrenzt, 13. Thema abgelehnt mit verständlichem Hinweis (Grenzen E-99) | E-99 | `RT3-E-06_<Pl>.png` | | |
| RT3-E-07 | alle | Kalender-Monatsansicht: Karte Jahresfortschritt ansehen | „Tag n von 365/366“, Tage verbleibend, Prozent abgerundet, grafischer Balken; heute mitgezählt (1. Januar 0 %, 31. Dezember 100 %); Screenreader liest einen Satz | E-95 | `RT3-E-07_<Pl>.png` | | |
| RT3-E-08 | alle | Systemdatum auf 31.12. bzw. 29.02. eines Schaltjahres (nur Emulator/Wegwerfgerät) | 100 % bzw. Tag 60 von 366, keine Abweichung | E-95 | `RT3-E-08_<Pl>.png` | | |
| RT3-E-09 | alle (G1, G2) | G1 legt Termin an, G2 öffnet nach mehr als 15 Minuten Betrieb den Kalender, **ohne** App zu beenden | Termin erscheint (15-Minuten-Abgleich, E-95); bei beendeter App kein Abgleich | E-95 | `RT3-E-09_<Pl>.png` | | |
| RT3-E-10 | alle | Terminspeichern mit gestörter Ablage (Testmöglichkeit: Speicher voll bzw. Datenbank gesperrt, nur Wegwerfgerät) | Editor zeigt eine Fehlermeldung, Eingaben bleiben erhalten, kein stilles Scheitern | #409 | `RT3-E-10_<Pl>.png` | | |
| RT3-E-11 | Win, Mac, iPad | Termin-Editor → Beginn → Zeitwähler → Tastatur-Symbol: Stunde `21`, Minuten `30` per **physischer** Tastatur | Stunde wird ersetzt (21), Fokus springt in die Minuten, 21:30; Restfall: Fenster inaktiv, Klick ins Feld, `19` | #263 | `RT3-E-11_<Pl>.png` | | |
| RT3-E-12 | alle (G1, G2) | G1 legt unter Kalender → Symbol „Geburtstage“ eine Person mit Geburtstag (mit Jahr) und Todestag an; G2 öffnet die Liste; G2 ändert den Namen; Einstellungen → Anzeige → „Geburtstage anzeigen“ auf 14 Tage stellen; „Heute“ und Kalender (Monat, Agenda) ansehen | Eintrag erscheint bei G2 verschlüsselt, G1 sieht die Änderung von G2; Kuchen- bzw. Blumen-Symbol und Text („wird n“, „aktuell k Jahre“, „n. Todestag“) auf „Heute“ innerhalb des Vorlaufs, Marker und Semantics im Monatsraster; Schrift 200 % ohne Überlauf; Plattform-Pflichtschritt für die Optik (Schriftgrößen, Symbole) | #539, E-104 | `RT3-E-12_<Pl>.png` | | |
| RT3-E-13 | alle (G1, G2) | G1 und G2 im Familienchat. G1 sendet `Status-Test`; sofort ansehen (Uhr, dann Haken); G2 öffnet den Chat; G1 sieht „Gelesen von 1“ (Tippen zeigt den Namen von G2). Einzelchat G1 ↔ G2 wiederholen: nur Symbol, kein Namensblatt. Danach Einstellungen → Datenschutz → „Lesebestätigung senden“ auf G2 aus, G1 sendet `Status-Test 2`, G2 liest: G1 zeigt nur „Gesendet“; „Lesebestätigung senden“ auf G1 aus: G1 sieht auch bei einer von G2 gelesenen Nachricht nichts. Hell und dunkel, Schrift 200 %, VoiceOver/TalkBack | Haken `Icons.schedule` → `done` → `done_all` in der Akzentfarbe, jeweils mit Beschriftung („Wird gesendet …“, „Gesendet“, „Gelesen“, „Gelesen von 1“); Text „Gelesen von n“ im Familienchat ohne Überlauf bei 200 %; Hinweis im Schalter nennt Sichtbarkeit für den Server und den Anbieter der Gesprächspartner, Gegenseitigkeit und Unwiderruflichkeit; Plattform-Pflichtschritt für Optik und Screenreader | #526, E-106 | `RT3-E-13_<Pl>.png` | | |
| RT3-E-14 | alle (G1, G2) | G2 schreibt G1 im Einzelchat, G1 liest nicht. G1: Chat-Tab, Liste ansehen. Einstellungen → Anzeige → „Letztes Gespräch wieder öffnen“ an (Standard aus). G1 öffnet den Einzelchat mit G2, App ganz beenden und neu starten; Start auf „Heute“, dann Chat-Tab öffnen (einmal sofort nach dem Start, einmal nach einigen Sekunden). Dann „Zurück zu den Gesprächen“, App beenden, neu starten, Chat-Tab. Schalter aus, Gespräch öffnen, App beenden, neu starten. Abmelden und neu anmelden | Liste: Familienchat oben, darunter Gespräche mit Ungelesenem (fett, Zähler), dann die übrigen nach letzter Nachricht. Schalter an: nach dem Neustart steht der Chat-Tab im zuletzt offenen Gespräch, sofern es zum ersten Öffnen des Tabs geladen ist; öffnet man den Tab sehr früh, erscheint die Liste (Einzelchats laden nach einem Kaltstart verzögert) und das Gespräch springt später nicht von selbst auf. Nach „Zurück zu den Gesprächen“ erscheint die Liste. Schalter aus: immer Liste. Nach Abmelden und Anmelden: Liste, Schalter bleibt an. Hinweis im Schalter nennt „nur auf diesem Gerät“ und „beim Abmelden gelöscht“; VoiceOver/TalkBack liest Titel und Hinweis; Plattform-Pflichtschritt | #516, E-107 | `RT3-E-14_<Pl>.png` | | |

### F. Meldungen und Zahl am App-Symbol (#254, #381, #273, #330, E-88)

Vertiefung: `Testplan_Benachrichtigungen_macOS-iOS.md` (TP-FN-NTF-381 v03, 114 Zeilen, davon 49 ⏳). **Die ⏳-Zeilen dieses Plans (46 auf dem Mac) gehören zu diesem Lauf**; das Ergebnis wird in den Report übernommen.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-F-01 | iOS, Mac, And | Berechtigung erteilen; Einstellungen → „Benachrichtigungen“ ansehen | Hinweistext sagt: Meldungen nur bei geöffneter App, im Hintergrund auf Mobilgeräten nicht zugesagt (#273, Variante a); zwei Schalter | E-88 | `RT3-F-01_<Pl>.png` | | |
| RT3-F-02 | iOS, Mac, And | App im Vordergrund, Chat nicht sichtbar; G1 sendet Nachricht | Meldung „Neue Nachrichten“ **ohne** Absender, Gespräch und Inhalt; Einkauf: „Neue Einträge auf dem Einkaufszettel“ | NTF | `RT3-F-02_<Pl>.png` | | |
| RT3-F-03 | iOS, Mac, And | Gespräch offen: Nachricht senden | Keine Meldung bei geöffnetem Gespräch; auf der Gesprächsliste (kein Gespräch offen) kommt die Meldung | E-100 | `RT3-F-03_<Pl>.png` | | |
| RT3-F-04 | iOS (echt), Mac (signiert) | Zahl am App-Symbol (Icon bzw. Dock), Zurücksetzen beim Lesen und beim Abmelden | Zahl stimmt, geht beim Lesen auf 0, beim Abmelden weg; Freigabe „Kennzeichen“ nachträglich erteilen | E-16b | `RT3-F-04_<Pl>.png` | | |
| RT3-F-05 | iOS (echt) | Sperrbildschirm: Meldung „Neue Nachrichten“ ohne Inhalt, auch in der Mitteilungszentrale | Kein Titel, Ort, Notiz, Absender, Gespräch, Inhalt | E-88 | `RT3-F-05_iOS.png` | | |
| RT3-F-06 | iOS, Mac | Erinnerung bei **beendeter** App: Termin in 2 Minuten, App beenden | Meldung pünktlich (Soll = Ist), Text mit Zeit; „Zur Startzeit“ ebenfalls | E-15 | `RT3-F-06_<Pl>.png` | | |
| RT3-F-07 | iOS, And | App im Hintergrund und beendet: Nachricht senden, bis 180 s warten | Ergebnis mit Sekunden festhalten; Ausbleiben ist **kein** Fehler (#273, E-88) | #273 | `RT3-F-07_<Pl>.png` | | |
| RT3-F-08 | Win | Taskleisten-Overlay: 1 bis 9 und mehr als 9 ungelesene | Overlay mit Zahl, „9+“ ab 10; Meldung ohne Inhalt | #254 | `RT3-F-08_Win.png` | | |
| RT3-F-09 | Win | „9+“ bei 100 %, 125 %, 150 %, 200 % Skalierung, heller und dunkler Taskleiste | Schrift berührt den Rand des Kreises nicht und ist lesbar; einstellige Zahlen unverändert. Bei zu kleiner Schrift (-9) Fallback -10 im Issue vermerken | #330 | `RT3-F-09_Win_<Skala>.png` | | |
| RT3-F-10 | Lin, And (Emulator) | Zahl und Meldung auf Linux (Flatpak) und Android | Wie F-02, keine Zahl am Symbol, wo die Plattform keine unterstützt (n/a mit Grund) | E-16b | `RT3-F-10_<Pl>.png` | | |
| RT3-F-11 | alle | Aus-Schalter „Meldungen aus“ | Keine Meldungen mehr, Zahl bleibt konsistent | E-88 | `RT3-F-11_<Pl>.png` | | |

### G. Anmeldung und Anbieterseiten in der App (#268, #297, #441, #412, #430, E-91, E-102)

Seit E-102 (15.11., PR #479) öffnen Anmeldung und Anbieterseiten auf iOS, macOS und Android **in einer eingebetteten Ansicht** der App (`EmbeddedBrowserPage`), nicht mehr in System-Sitzung oder Custom Tab; Linux und Windows bleiben beim externen Browser. Schritte G-04 bis G-08 brauchen einen OAuth-Anbieter (matrix.org, eigenes Konto, Freigabe des Nutzers); ohne Freigabe prüfen G-09 bis G-13 die Ansicht gegen den Testserver bzw. eine lokale Testseite, G-04 bis G-08 und G-14 bleiben ⏳. Der Hinweis zum Schließen aus #297 („iPhone, iPad und Mac“, „Abbrechen“) gilt nur noch für die System-Sitzung und erscheint in der eingebetteten Ansicht als „Abbrechen“/„Fertig“ (J-08 prüft die Beschriftung).

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-G-01 | alle | Anmeldung über den eigenen Testserver (Passwort): Konto anlegen, abmelden, anmelden | Gelingt ohne Browser; Eingabegrund neben dem Hinweis bei Fehleingabe; Hinweis verschwindet beim nächsten Versuch | #430 | `RT3-G-01_<Pl>.png` | | |
| RT3-G-02 | iOS, iPad, Mac, And, Win | Anbieterwahl: Symbol der Schaltfläche je Plattform | Symbol passt zur Plattform (iOS, iPad, Mac, Android: öffnet die eingebettete Ansicht der App; Win, Lin: externer Browser), Text bleibt maßgeblich, nicht nur Symbol | #430, E-102 | `RT3-G-02_<Pl>.png` | | |
| RT3-G-03 | And | Fremdanbieter wählen und in der eingebetteten Ansicht „Abbrechen“ | Ansicht schließt, Hinweis „Anmeldung abgebrochen“ als Hinweis (nicht als Fehler), Versuch beendet | #430, E-102 | `RT3-G-03_And.png` | | |
| RT3-G-04 | iOS, iPad, Mac, And | Anmeldung/Kontoanlage beim Anbieter: Anbieter wählen (Testserver mit OAuth-Testseite oder matrix.org nur mit Freigabe), Captcha | Seite öffnet **in der App** (Titel „Anmeldung beim Anbieter“), Kopfzeile mit Schloss und vollständigem Host samt Pfad; Captcha-Seite mit „Fertig“; kein Safari-/Browserfenster | TP-OAUTH-11, #441 | `RT3-G-04_<Pl>.png` | | |
| RT3-G-05 | iOS, iPad, Mac, And | Anmeldung, Passwort-Seite, Kontolöschung über die eingebettete Ansicht („Seite des Anbieters“, „Fertig“) | Rückkehr in die App, Sitzung gilt; Sichtschutz aktiv; Kontolöschung mit Wegwerfkonto bis zum Ende; Text „Bestätige die Löschung auf der Seite des Anbieters, schließe sie (… über „Fertig“ …)“ | TP-OAUTH-11 | `RT3-G-05_<Pl>.png` | | |
| RT3-G-06 | Mac | Standard-Browser Chrome statt Safari; Start ohne `network.server`-Berechtigung | Anmeldung funktioniert in der eingebetteten Ansicht unabhängig vom Standardbrowser; „Im Browser fortsetzen“ (nur im Fehlerfall) öffnet die Original-URL im Standardbrowser | #430, #441 | `RT3-G-06_Mac.png` | | |
| RT3-G-07 | And | Anmeldung auf frischem Emulator (`Pixel8_API35`) und, wenn verfügbar, einem Gerät/AVD mit anderem oder ohne Standardbrowser | Eingebettete Ansicht öffnet unabhängig vom Standardbrowser; Anmeldung gelingt oder verständlicher Hinweis; kein Absturz; Android-Zurück geht erst eine Seite zurück, dann bricht ab | TP-OAUTH-12 | `RT3-G-07_And.png` | | |
| RT3-G-08 | alle | Anmeldung, bei der nur ein **Folgeschritt** scheitert (z. B. Abgleich nach der Anmeldung, Netz trennen) | Die Sitzung gilt, kein Fehler „Anmeldung fehlgeschlagen“; Abgleich läuft später (#412) | #412 | `RT3-G-08_<Pl>.png` | | |
| RT3-G-09 | iOS, iPad, Mac, And | **#441, Soll-Zustand E-102:** Anmeldung und Anbieterseiten (Bedingungen, Captcha, Konto löschen, Passwort ändern) öffnen in der eingebetteten Ansicht; Linux/Windows bleiben beim Browser | Kein externes Fenster; Titel „Anmeldung beim Anbieter“ bei Anmeldung, „Seite des Anbieters“ bei Kontoseiten; Abbrechen beendet nur bei Anmeldung den Versuch | #441, E-102 | `RT3-G-09_<Pl>.png` | | |
| RT3-G-10 | iOS, iPad, Mac, And | **#441, Navigationsregeln:** auf einer lokalen Testseite Links mit `http://`, `file://`, `intent://`, fremdem Schema und eine Weiterleitung auf `io.github.carpeasrael.familynexus:/oauth…` anstoßen | `http`, `file`, `intent`, fremde Schemata blockiert, SnackBar „Dieser Link wurde nicht geöffnet.“; die App-Rücksprungadresse wird im Hauptframe abgefangen, nicht ausgeführt, und beendet die Seite mit Ergebnis; Schleife (dieselbe URL mehr als dreimal in 5 s) wird angehalten mit Hinweis „Die Seite hat sich immer wieder selbst aufgerufen …“ | #441, E-102 | `RT3-G-10_<Pl>.png` | | |
| RT3-G-11 | iOS, iPad, Mac, And | **#441, Fehlerfall:** Testseite liefert HTTP 500 bzw. Netz trennen und laden | Seite bleibt sichtbar; Hinweiszeile „Die Seite meldet ein Problem …“ mit „Neu laden“, „Im Browser fortsetzen“, „Abbrechen“, schließbar („Hinweis schließen“); „Im Browser fortsetzen“ öffnet dieselbe Original-URL (gleicher `state`); **nur** im Fehlerfall sichtbar, nicht dauerhaft im Menü | #441, E-102 | `RT3-G-11_<Pl>.png` | | |
| RT3-G-12 | iOS, iPad, Mac, And | **#441, Schließen und Löschen:** Anbieterseite mit Cookie/`localStorage` besuchen, über „Fertig“/„Abbrechen“, Android-Zurück bzw. iOS-Wischen, App-Sperre schließen; Seite erneut öffnen | Nach jedem Schließweg Cookies, Cache und `localStorage` gelöscht (Testseite zeigt keinen Zustand); Wechsel in den Hintergrund (z. B. zur Mail-App) schließt die Seite **nicht**; Sperre schließt sie und beendet den Versuch | #441, E-102 | `RT3-G-12_<Pl>.png` | | |
| RT3-G-13 | iOS, Mac, And | **#441, Berechtigungen:** Testseite fordert Kamera, Mikrofon, Standort an | Anfragen verweigert, keine Berechtigungsabfrage des Systems; JavaScript der Seite läuft (Captcha) | #441, E-102 | `RT3-G-13_<Pl>.png` | | |
| RT3-G-14 | iOS, Mac, And | **#441, Fremdanbieter:** Anbieter, dessen Seite eingebettete Ansichten ablehnt (z. B. Google, nur mit Freigabe; sonst Testseite mit `disallowed_useragent`-Antwort) | Hinweiszeile mit „Im Browser fortsetzen“ ist der Ausweg; keine Sackgasse; ohne Freigabe ⏳ (Restpunkt am Gerät) | #441, E-102 | `RT3-G-14_<Pl>.png` | | |

### H. Einrichtung und Einführungstour (#411, #347, E-45, E-95)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-H-01 | alle | Neues Konto, Familie gründen, Einrichtung bis zum Ende | Nach der Einrichtung Dialog Einführungstour: drei Schritte (Kalender, Chat, Einkauf); „Überspringen“ auf Schritt 1 und 2, der letzte Schritt zeigt „Los geht’s“ / „Let’s go“ und beendet die Tour (#502) | E-95 | `RT3-H-01_<Pl>.png` | | |
| RT3-H-02 | alle | Tour überspringen; App neu starten | Tour erscheint nicht erneut (`tourSeen`) | E-95 | `RT3-H-02_<Pl>.png` | | |
| RT3-H-03 | alle | Einstellungen → Einführung wiederholen | Tour startet erneut, mit Tastatur bedienbar (Tab, Enter, Escape) | E-95 | `RT3-H-03_<Pl>.png` | | |
| RT3-H-04 | alle | Einrichtung mit gestörter Ablage am Ende (Speicher voll bzw. Datenbank gesperrt, Wegwerfgerät) | Fehler wird angezeigt, „Erneut versuchen“ möglich, Einrichtung bleibt nicht stehen; bei zweitem Fehlschlag „Später“ und „Jetzt einladen“ erreichbar | #411, E-45 | `RT3-H-04_<Pl>.png` | | |
| RT3-H-05 | alle | Tour in Englisch und mit Schrift 200 % | Texte vollständig, kein Überlauf; Screenreader liest die Titel | – | `RT3-H-05_<Pl>.png` | | |
| RT3-H-06 | alle | Konto A: Tour bis „Los geht’s“ beenden, abmelden, mit demselben Konto wieder anmelden (#507) | Die Tour erscheint **nicht** erneut (`tourSeen` bleibt, Abmelden setzt nur `blockedUsers` und den vorgemerkten Link zurück, #450). Erscheint sie doch: Beobachtung mit Angabe, ob die Tour zuvor mit „Los geht’s“ oder mit „Überspringen“ endete, und ob zwischendurch „Alle lokalen Daten löschen“ lief | E-95 | `RT3-H-06_<Pl>.png` | | |

### I. Einstellungen: App teilen und bewerten, Screenshot-Schutz, Texte (#350, #351, #144, #326, E-95, E-98)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-I-01 | alle | Einstellungen → „App teilen“ | Satz plus Play-Store-Link (`de.inneso.familynexus`) in der Zwischenablage, Hinweis „Link kopiert“; kein System-Teilen-Menü (E-95); keine Familien-, Raum- oder Einladungsdaten | E-95 | `RT3-I-01_<Pl>.png` | | |
| RT3-I-02 | And | Einfügen in eine Notiz | Der Satz und der öffentliche Link, sonst nichts | E-95 | `RT3-I-02_And.png` | | |
| RT3-I-03 | And | Einstellungen → „App bewerten“ | Öffnet den Play-Store-Eintrag; auf einem Gerät ohne Store verständlicher Hinweis statt Absturz | #350 | `RT3-I-03_And.png` | | |
| RT3-I-04 | iOS, iPad, Mac, Win, Lin, Web | Einstellungen ansehen | Kein Eintrag „App bewerten“ (nur Android) | E-95 | `RT3-I-04_<Pl>.png` | | |
| RT3-I-05 | iOS, iPad | Schalter Screenshot-Schutz: Text lesen | „Verdeckt die App im App-Umschalter und bei Bildschirmaufnahmen. Einzelne Screenshots lassen sich unter iOS nicht verhindern.“ (nicht „blockiert Screenshots“) | #144, B-18 | `RT3-I-05_<Pl>.png` | | |
| RT3-I-06 | iOS (echt) | Schalter an: Screenshot, App-Umschalter, Bildschirmaufnahme | Screenshot gelingt; App-Umschalter verdeckt die App; Aufnahme zeigt das Blatt ohne Inhalt | #144 | `RT3-I-06_iOS.png` | | |
| RT3-I-07 | Win | Schalter an: Vollbild-Screenshot, Snipping Tool, Game-Bar-Aufnahme, Bildschirmfreigabe | Hinweistext „… von Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben aus“; Screenshot, Aufnahme und Freigabe zeigen das Fenster nicht; Schalter aus: sichtbar | #144 | `RT3-I-07_Win.png` | | |
| RT3-I-08 | alle | Einstellungen: „Datenübersicht“ (statt „Protokoll“), „Geräteeinstellungen“ | Wortlaut stimmt in der App und in der Datenschutzerklärung; Englisch „Data overview“ | E-98, #326 | `RT3-I-08_<Pl>.png` | | |
| RT3-I-09 | alle | Eigene Zeile „Einkauf zuletzt von dir“, Aufgabe „Zugewiesen an dich“ | Dativ stimmt, nicht „von Du“ | #329 | `RT3-I-09_<Pl>.png` | | |
| RT3-I-10 | alle | Datenschutzerklärung durchlesen (Satzbau Abschnitte 1 und 9) | Verständliche Sätze, keine Rechtschreibfehler; Muttersprachler-Prüfung notieren | E-98 | `RT3-I-10_<Pl>.png` | | |

### J. Tablet und große Fenster (#274, E-92)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-J-01 | iPad | Hoch- und Querformat, alle vier Ausrichtungen | Einspaltig bis 599 dp (Leiste unten), Rail ab 600 dp, Zweispalter Kalender und Chat ab 1000 dp; kein Neustart, keine neue Anmeldung | B-25 | `RT3-J-01_iPad_<Ausr>.png` | | |
| RT3-J-02 | iPad | Split View, Slide Over, Stage Manager: Fenster stufenlos ziehen | Layout wechselt an 599/600/1000 dp ohne Zustandsverlust (Entwurf, Termin, Dialog) | B-25 | `RT3-J-02_iPad.png` | | |
| RT3-J-03 | iPad, AndT | Bildschirmtastatur im Chat | Layout kippt nicht, Eingabefeld bleibt sichtbar | B-25 | `RT3-J-03_<Pl>.png` | | |
| RT3-J-04 | alle | Schrift 200 % an Heute, Kalender, Chat, Einkauf, Aufgaben (mit Abzeichen), Einstellungen | Kein Überlauf nach rechts; Wörter brechen nicht mitten im Wort (Beobachtung Lauf 22, Folgeissue Entscheidung Nutzer) | #274 | `RT3-J-04_<Pl>.png` | | |
| RT3-J-05 | AndT | Drehen mit und ohne Rotationssperre, Multi-Window | Wie J-01; Klasse darf beim Tippen nicht wechseln (`adjustResize`) | B-25 | `RT3-J-05_AndT.png` | | |
| RT3-J-06 | iPad, AndT, Win, Mac | Ab 1000 dp: Heute, Einkauf, Aufgaben | Einspaltig, **kein** senkrechter Strich (#309) | E-92 | `RT3-J-06_<Pl>.png` | | |
| RT3-J-07 | iPad, AndT, Win | Tab-Reihenfolge mit Hardware-Tastatur | Menü → Rail → Inhalt zusammenhängend (eigene Fokusgruppen) | E-92 | `RT3-J-07_<Pl>.png` | | |
| RT3-J-08 | iPad | Anbieterseite (Captcha, Konto löschen) in der eingebetteten Ansicht, dann im Fehlerfall „Im Browser fortsetzen“ (System-Sitzung, Rückfallweg) | Eingebettete Ansicht: Schließen mit „Abbrechen“/„Fertig“; Hinweistext der System-Sitzung nennt „iPhone, iPad und Mac“ (#297) | #297 | `RT3-J-08_iPad.png` | | |

### K. Screenreader und Bedienhilfen (#332, #326, #423, #422)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-K-01 | iOS, iPad, Mac (VoiceOver); And, AndT (TalkBack); Win (NVDA) | Eigene Chatnachricht vorlesen lassen | Deutsche App „Nachricht von dir“; englische „Message from you“; fremde „Nachricht von {Name}“ | #332 | `RT3-K-01_<Pl>.txt` | | |
| RT3-K-02 | wie K-01 | Gesprächsliste vorlesen | „Einzelchat mit <Name>, <Status>, <Vorschau>, <n> ungelesen“; Pfeil „Zurück zu den Gesprächen“ | E-18c | `RT3-K-02_<Pl>.txt` | | |
| RT3-K-03 | wie K-01 | Familie und Chat mit Avatar | Avatar wird **nicht** vorgelesen, nur Namen und Nachrichten | E-19b | `RT3-K-03_<Pl>.txt` | | |
| RT3-K-04 | wie K-01 | Kalender-Termin mit Thema | Label enthält „Thema <Name>“ und „Geteilt/Privat“ als Text | E-99 | `RT3-K-04_<Pl>.txt` | | |
| RT3-K-05 | wie K-01 | Jahresfortschritt | Ein Satz, kein Balken einzeln | E-95 | `RT3-K-05_<Pl>.txt` | | |
| RT3-K-06 | wie K-01 | Geänderte Texte aus #326 (Datenübersicht, Geräteeinstellungen, Erinnerungen) | Aussprache und Schreibung stimmen | #326 | `RT3-K-06_<Pl>.txt` | | |

### L. Plattform: Windows-Tests, Apple-Laufzeit, Web, Identitätsvermerke (#325, #266, #142, #440)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-L-01 | Win | Auf dem Windows-Host mit `core.autocrlf=true` `flutter test` | Keine rot wegen Pfadtrenner oder CRLF (8 Fälle aus #325 grün); bekannte Umgebungsausnahmen im Report | #325 | `RT3-L-01.txt` | | |
| RT3-L-02 | Mac (signiert) | Signierter Build startet mit `sqlite3` 3.8.0, Tresor und Datenbank lesbar, Neustart | App startet, Sitzung wird wiederhergestellt; `log show` ohne „out of bounds“ | #266 | `RT3-L-02_Mac.png` | | |
| RT3-L-03 | Dev | `tool/build_web.sh`, `tool/web_smoke.py` | 5/5 bestanden | #266 | `RT3-L-03.txt` | | |
| RT3-L-04 | Web | Web: Browser-Tresor anlegen, Start, Neuladen, falsches und richtiges Passwort | Start „Willkommen bei FamilyNexus“ nach dem Anlegen; Entsperren funktioniert; kein „Lokale Daten nicht lesbar“ | #266 | `RT3-L-04_Web.png` | | |
| RT3-L-05 | Dev | Gateway-Tests der Identitätsvermerke (`merged(... local:)`, `acceptIdentityChange`), Mutation: `local:` an beiden Stellen entfernen | Tests rot bei Mutation (nach Umsetzung von #440), Suite grün ohne Mutation | #440, #142 | `RT3-L-05.txt` | | |
| RT3-L-06 | iOS, Mac, And | Identitätswechsel eines Mitglieds (Cross-Signing zurücksetzen), Vermerk in den Kontodaten löschen | „Identität geändert“, Geräte gesperrt, auch nach Neustart; „Akzeptieren“ hebt auf und gilt nach Neustart; Datenübersicht zeigt `identityPins` | #142 | `RT3-L-06_<Pl>.png` | | |
| RT3-L-07 | Dev | `tool/synapse/up.sh`, `curl -fsk https://localhost:18448/_matrix/client/versions`; `password_variants.sh` | 200, nie 502; Passwortvarianten bestanden | #281 | `RT3-L-07.txt` | | |

### M. Windows-Besonderheiten (#263, #330, #144, #274)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-M-01 | Win | Zeitwähler per physischer Tastatur `21`, `30` | 21:30, Fokus springt | #263 | `RT3-M-01_Win.png` | | |
| RT3-M-02 | Win | 200 % Schrift: Heute, Kalender, Chat, Einstellungen | Kein Überlauf (offen aus Lauf 24) | #274 | `RT3-M-02_Win.png` | | |
| RT3-M-03 | Win | Windows-Fenster 599/600/999/1000 dp | Leiste, Rail, Zweispalter; Entwurf bleibt | #274 | `RT3-M-03_Win.png` | | |
| RT3-M-04 | Win | Snipping Tool, Game Bar, Teams-Freigabe mit Schutz an und aus | Fenster fehlt bei an, sichtbar bei aus | #144 | `RT3-M-04_Win.png` | | |

### N. Store und Apple (manuell) (#348, #349, #15)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-N-01 | Play Console | Kurzbeschreibung und Langtext DE und EN eintragen (aus `store/metadata/android`) | Kurz ≤ 80 Zeichen, Lang ≤ 4000; Vorschau ohne Abschneiden; keine Keyword-Häufung | #348 | `RT3-N-01.png` | | |
| RT3-N-02 | Play Console | Screenshot-Satz mit Highlights (Kalender, Chat, Einkauf, Datenschutz), DE und EN, Telefon und Tablet | Vorgaben der Play Console erfüllt, **Demodaten**, keine echten Personen, Chat über die Gesprächsliste geöffnet | #349 | `RT3-N-02.png` | | |
| RT3-N-03 | Mac, iOS | Prüfkonto vorbereiten, Prüfanleitung auf dem neuen Build nachtesten (Notfall-Schlüssel, zweites Mitglied, TC-06 bis TC-16) | Alle TC bestanden; Notizen in App Store Connect | #15 | `RT3-N-03.png` | | |
| RT3-N-05 | Dev | **#349, Bildpaket:** `store/screenshots/android/{de-DE,en-US}/phoneScreenshots/` (7 Bilder je Sprache), `flutter test test/store/play_screenshots_test.dart` | 14 Bilder 1080×1920, PNG ohne Alpha, je < 1 MB, nur Demodaten, Überschriften DE/EN passend; Test grün. **Hochladen und Annahme in der Play Console (RT3-N-02) bleiben manuell** und gehören nicht zur Abnahme auf Emulator | #349 | `RT3-N-05.txt` | | |
| RT3-N-04 | iOS, Mac | Store-Datenschutz: Avatar-Wahl als sichtbare Ausnahme genannt | Aussage deckt sich mit App-Datenschutzerklärung (E-101) | E-101 | `RT3-N-04.png` | | |

### P. Fehlerbehebungen und Unterlagen aus dem Release-Review 1.2.3+29 (#444 bis #451, #458 bis #464, #483 bis #487, #442)

**Unbedingt seit v03:** Alle Fixes #444 bis #451, #458 bis #464 und (seit v04) #483 bis #487 sind auf `main` (PRs #466 bis #478, #473, #474, #489 bis #493; Entscheidung E6: alle in 1.2.3). Der Build muss sie enthalten (RT3-V-05); fehlt einer, ist das ein Fehler des Builds, kein n/a. Ausnahme: #431 (nach v1.3) hat keinen Schritt. Beobachtetes Fehlverhalten **vor** dem Fix ist kein Befund dieses Laufs, sondern der bekannte Stand des Issues. Die genauen Soll-Werte (z. B. Zeitschranke) stehen im Lösungskommentar des Issues und werden vor dem Lauf hier eingetragen.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-P-01 | iOS, And | **#458:** Chat-Anhang laden; nach den Antwort-Kopfzeilen den Datenstrom anhalten (iOS-Simulator: Proxy, der nach den Kopfzeilen stoppt; Android-Emulator: Proxy oder `adb emu network delay`/Netz trennen bei offener Verbindung) | Nach der Leerlauf-Schranke (60 s je Datenblock, E-81; Lösung `boundedDownload`) Fehlermeldung „Server nicht erreichbar“, die Knöpfe „Laden“ und „Speichern“ erscheinen wieder; die Ladeanzeige dreht nicht endlos; auch bei Status ≠ 200 und zu großem `contentLength` kein Hängen | #458, E-17, E-28 | `RT3-P-01_<Pl>.png` | | |
| RT3-P-02 | Dev, Testserver | **#464:** Mitglied ohne Zuweisung und ohne Moderatorrecht (Hilfsclient, `matrix-js-sdk`) sendet viele gültige Abhak-Ereignisse mit bestehenden und erfundenen Listen-IDs; zugewiesene Person hakt ab | Echte Erledigung bleibt sichtbar, die Liste springt nicht auf „offen“; auch nach Neustart und auf einem neuen Gerät (Backfill); Grenze 5000 verdrängt keine Erledigung der zugewiesenen Person | #464, E-51 | `RT3-P-02.txt` | | |
| RT3-P-03 | alle (G1, G2) | **#444, #459:** Termin, Einkaufseintrag, Aufgabe und Kalender-Thema bei getrenntem Netz anlegen, Netz wieder an | Alle vier erscheinen bei G2 (Sendedurchlauf läuft nach der Störung weiter); bei einem Datenbankfehler im Testlauf steht ein Eintrag in der Datenübersicht bzw. im App-Protokoll | #444, #459 | `RT3-P-03_<Pl>.png` | | |
| RT3-P-04 | alle (G1, G2) | **#445:** Termin auf G1 öffnen, „Löschen“ bestätigen; vorher denselben Termin auf einem anderen eigenen Gerät löschen | Fehlermeldung „Der Termin konnte nicht gelöscht werden.“ (en: „The event could not be deleted.“), in beiden Zweigen („Nur dieses“ und „Alle“), nicht „konnte nicht gespeichert werden“ | #445 | `RT3-P-04_<Pl>.png` | | |
| RT3-P-05 | alle | **#450:** Konto A: Mitglied blockieren, Einladungslink vormerken, abmelden; Konto B anmelden; Einstellungen → „Blockierte“ | Liste leer, kein vorgemerkter Link von A; auch nach Familienwechsel | #450 | `RT3-P-05_<Pl>.png` | | |
| RT3-P-06 | alle (G1, G2) | **#451:** G2 schaltet „Online-Status teilen“ aus (Sync läuft); G1 sieht G2 in Familie und Heute | G2 erscheint nicht als online; der Text zum Schalter ist wahr („Ausgeschaltet giltst du als offline“); G2 sieht den Status der anderen weiterhin (Familienstatus über Gerätenachrichten, E-38; Entscheidung E8); G1 und G2 sehen sich untereinander weiter als online, solange G2 teilt | #451 | `RT3-P-06_<Pl>.png` | | |
| RT3-P-07 | alle | **#460:** Einzelchat mit letzter Nachricht vom 03.11. (älter als gestern); Gesprächsliste und Aufgaben vergleichen | Datum in der Liste mit führender Null wie bei Aufgaben („03.11.2026“) (E7 entschieden: E-20 gilt, `formatDateNumeric`); Deutsch und Englisch | #460, E-20, E-100 | `RT3-P-07_<Pl>.png` | | |
| RT3-P-08 | alle | **#461:** Familienname aus sechs Familien-Emojis bzw. 59 Buchstaben plus 😀 bei „Familie gründen“ und beim Umbenennen | Eingabefeld und Gateway zählen gleich: entweder nimmt das Feld es nicht mehr an, oder die Familie wird gegründet; **keine** stille Ablehnung beim Absenden | #461 | `RT3-P-08_<Pl>.png` | | |
| RT3-P-09 | iOS, And | **#463:** Englische App, Screenreader: Monatszellen vorlesen (Zelle 3., Zelle 30. Oktober, Zelle 30. November) | Label enthält Monat und englische Form („November 3, 2 events“); Nachbarmonat unterscheidbar vom aktuellen Monat; kein deutscher Ordinalpunkt | #463 | `RT3-P-09_<Pl>.txt` | | |
| RT3-P-10 | Dev, T7 | **#446:** sechs `release_notes.txt` unter `store/metadata` (ios, macos, android; de, en) lesen | Nennen Kalender-Themen, Avatare, Gesprächsliste und den Hinweis „Bitte alle Geräte aktualisieren“ (Themen verschwinden bei alter Version); Länge innerhalb der Store-Grenzen | #446, E-99 | `RT3-P-10.txt` | | |
| RT3-P-11 | Dev | **#447, #462, #449:** `store/privacy/privacy-policy.de.md` und `.en.md`, `privacyBody` in der App, `README.md` Z. 25-26, `docs/ARCHITEKTUR.md` Z. 14 prüfen | Datenschutz nennt Kalender-Themen (Name ≤ 30 Zeichen, Farbe, Ende-zu-Ende-verschlüsselt) in de und en; README nennt die Gesprächsliste statt der Gesprächsleiste; ARCHITEKTUR.md nennt Migration 5 (`event_themes`) | #447, #462, #449 | `RT3-P-11.txt` | | |
| RT3-P-12 | Dev (Lin) | **#448:** `flatpak/de.inneso.familynexus.metainfo.xml`: `appstreamcli validate` | Release-Zeile `1.2.3` vorhanden, Validierung ohne Fehler; Tag `v1.2.3` bleibt unberührt (Entscheidung E10); ohne `appstreamcli` (nicht auf macOS installiert, `brew install appstream`) ⏳ | #448 | `RT3-P-12.txt` | | |
| RT3-P-14 | iOS, Mac, And | **#445 Gegenprobe Editor:** Termin im Editor mit ungültigem Ende speichern | Ende vor Beginn: Inline-Hinweis „Das Ende muss nach dem Beginn liegen.“, der Termin wird nicht gespeichert und der Editor bleibt offen (#508). Der Text „… konnte nicht gespeichert werden“ (`eventSaveError`) erscheint nur bei einem Fehler beim Speichern selbst (z. B. Termin inzwischen gelöscht) und ist in der App nicht auslösbar: nur per Widget-Test (`calendar_flow_test.dart`) | #445 | `RT3-P-14_<Pl>.png` | | |
| RT3-P-13 | iOS, And, Win | **#442 (behoben):** Termin-Editor bei Schrift 200 %: Beginn und Ende | Beschriftung „Beginn“ steht über Datum und Uhrzeit, bricht nicht mitten im Wort | #442 | `RT3-P-13_<Pl>.png` | | |
| RT3-P-15 | iOS, Mac, And | **#483:** Konto mit OAuth-Anmeldung (Testserver mit OAuth-Testseite), Einstellungen → „Passwort ändern“ | Eingebettete Kontoseite öffnet und **bleibt offen** (schließt sich nicht sofort); nach „Fertig“, Zurück-Geste bzw. Android-Zurück kehrt die App zum Dialog zurück und schließt ihn; „Abbrechen“ im Dialog lässt keine Seite stehen; echte Passwortänderung bei matrix.org ⏳ (keine echten Konten) | #483, E-102, TP-PW-10b | `RT3-P-15_<Pl>.png` | | |
| RT3-P-16 | iOS, Mac, And | **#484:** Testseite mit Fehlerfall (HTTP 500), dort „Im Browser fortsetzen“ wählen und währenddessen „Fertig“ drücken (schnell nacheinander, mehrfach) | Kein Absturz, keine Meldung „Future already completed“ im Protokoll, **kein** Fehlerbanner nach „Fertig“; die Seite endet; der Versuch gilt nicht vorzeitig als abgeschlossen | #484, E-102 | `RT3-P-16_<Pl>.png` | | |
| RT3-P-17 | iOS, Mac, And | **#485:** Testseite leitet auf `https://<Anbieterhost>.example.net/login` (Host beginnt wie der Anbieter), danach auf denselben Host mit anderem Pfad und Port | Hinweis „andere Seite“ nennt den **vollen** fremden Host; gleicher Host mit anderem Pfad oder Port: kein Hinweis; `about:blank` zeigt den Hinweis weiterhin; kein Blockieren | #485, E-102 | `RT3-P-17_<Pl>.png` | | |
| RT3-P-18 | iOS, Mac | **#486:** Anmeldeseite mit IndexedDB und Service Worker besuchen (Testseite), Seite schließen, abmelden; danach Zurücksetzen/Kontolöschung; Inhalt von `Library/WebKit/WebsiteData` im App-Container prüfen (Simulator: `xcrun simctl get_app_container`; Mac: Container-Ordner) | Kein IndexedDB-, Service-Worker- oder CacheStorage-Rest der Anbieterseite nach Schließen und Zurücksetzen; Datenschutzerklärung und Einstellungstext nennen nicht mehr „bis zum Prozessende“. **Abnahme nur am Gerät/Simulator (TP-OAUTH-14, `docs/TESTPLAN_ONBOARDING.md`); ohne Ausführung bleibt #486 offen** | #486, E-102 | `RT3-P-18_<Pl>.txt` | | |
| RT3-P-19 | Dev | **#487:** `lib/data/platform/oauth_redirect.dart`, Doku-Kommentar über `_pump` lesen; `flutter test test/data` | Ein Kommentar, der aktuellen Versuch (schließt die Queue) und abgelösten Versuch (schließt sie nicht) unterscheidet; Tests grün; kein Verhaltensunterschied | #487 | `RT3-P-19.txt` | | |
| RT3-P-20 | iOS, Mac, And | **#497:** Moderator-Konto auf einem Server, dessen Name keinen Port hat, der aber nur mit Port erreichbar ist (lokaler Synapse `localhost:18448`); Einladungslink erzeugen, auf einem zweiten Gerät öffnen | Einrichtung ist mit `localhost:18448` vorbelegt (Rückfrage zum Server im Heimnetz), Konto-Anlage und Beitritt gelingen **ohne** Handeingabe des Anbieters; matrix.org-Link unverändert (`matrix.org`) | #497, E-63 | `RT3-P-20_<Pl>.png` | | |

### R. Regression der Umbauten (E-96, E-97)

Alle Bildschirme wurden ohne Verhaltensänderung zerlegt (Gateway in Module, Bildschirme in Widgets, Controller, `JsonRead`). Ein Rauchtest je Bereich auf mindestens einem Apple- und einem Android-Gerät.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-R-01 | alle | Konto anlegen, Notfall-Schlüssel, Familie gründen, Einladen | Wie bisher, keine neue Meldung | E-97 | `RT3-R-01_<Pl>.png` | | |
| RT3-R-02 | alle | Termin anlegen, bearbeiten, löschen, Zusage | Wie bisher; Zeitregeln (Ende nach Beginn) | E-97 | `RT3-R-02_<Pl>.png` | | |
| RT3-R-03 | alle | Einkauf: Eintrag, Gruppe, Erledigt | Wie bisher | E-97 | `RT3-R-03_<Pl>.png` | | |
| RT3-R-04 | alle | Aufgabenliste: anlegen, zuweisen, erledigen | Wie bisher | E-97 | `RT3-R-04_<Pl>.png` | | |
| RT3-R-05 | alle | Chat: senden, Anhang, Reaktion, Antwort, Zitat, melden, blockieren | Wie bisher | E-97 | `RT3-R-05_<Pl>.png` | | |
| RT3-R-06 | alle | Einstellungen: Erinnerungen, Geräte, Speicherorte, Datenübersicht, Passwort ändern, Konto löschen (Wegwerfkonto) | Wie bisher | E-97 | `RT3-R-06_<Pl>.png` | | |
| RT3-R-07 | alle | Theme hell/dunkel umschalten, App-Sperre ein/aus; auf Android und iOS die Statusleiste ansehen (#501) | Farben, Kontrast, Sperre wie bisher; Statusleisten-Symbole (Uhr, Akku) dunkel auf hellem, hell auf dunklem Design, auch auf Seiten mit Titelleiste | E-97 | `RT3-R-07_<Pl>.png` | | |
| RT3-R-08 | alle | Familienwechsel, Abmelden, erneut anmelden | Wie bisher; `event_themes` und Avatare werden mit gelöscht bzw. neu geladen | E-99 | `RT3-R-08_<Pl>.png` | | |

## T. Automatische Tests (Pflichtteil, auf Entwicklungsrechner)

| ID | Schritt | Erwartetes Ergebnis | Beleg |
|---|---|---|---|
| RT3-T-01 | `flutter analyze` | „No issues found!“ | `RT3-T-01.txt` |
| RT3-T-02 | `flutter test` | Alle bestanden, übersprungene nur wegen Plattform bzw. fehlendem Docker (Stand PR-Läufe 14./15.11.: 2437 bis 2448 bestanden; auf dem Build-Stand erneut zählen); bekannter Umgebungsfehler: `test/data/app_badge_test.dart` unter macOS (D-Bus) | `RT3-T-02.txt` |
| RT3-T-03 | `tool/e2e.sh` (Docker, Synapse, `vodozemac`) | Alle E2E-Tests bestanden (Stand: 63 + 111, davon sieben Avatar-Fälle); **neu fällig:** `gateway_family_e2e_test.dart:477` (Anhang-Download, #458) und Präsenz `set_presence=offline` gegen echten Synapse (#451), beide bisher nicht gelaufen (Docker war nicht verfügbar) | `RT3-T-03.txt` |
| RT3-T-04 | `tool/synapse/wait_ready_test.sh` | „Alle Fälle bestanden“ | `RT3-T-04.txt` |
| RT3-T-05 | Release-Review zum endgültigen Stand | `docs/release-reviews/1.2.3+<Build>.md` passt zum Fingerabdruck, bestätigte Observations sind Issues | `RT3-T-05.txt` |
| RT3-T-06 | CI auf dem Stand | Fünf Jobs grün: build, android, apple, linux, windows | `RT3-T-06.txt` |
| RT3-T-08 | `flutter build ios --simulator --debug`, `flutter build macos --debug`, `flutter build apk --debug` | Alle drei Builds gelingen mit `webview_flutter` 4.14.1 (#441) | `RT3-T-08.txt` |
| RT3-T-07 | `git grep -n 'Du' lib/l10n/app_de.arb` mit Prüfung der Fälle „von/an/für Du“ | Keine falschen Dative, Ausnahmen begründet | `RT3-T-07.txt` |

## Z. Aufräumen

| ID | Pl. | Schritt | Erwartetes Ergebnis | Vertiefung | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|---|
| RT3-Z-01 | alle | Konto löschen (Wegwerfkonto) über „Konto löschen“ | Konto weg, Daten lokal gelöscht, Willkommensseite | – | `RT3-Z-01_<Pl>.png` | | |
| RT3-Z-02 | Dev | Lokalen Synapse beenden (`tool/synapse/down.sh`), Testdaten entfernen | Container und Volumes weg | – | `RT3-Z-02.txt` | | |
| RT3-Z-03 | Win | Bildschirmschutz wieder anschalten | Schalter an | – | `RT3-Z-03_Win.png` | | |
| RT3-Z-04 | Mac | `~/Library/Containers/de.inneso.familynexus.e2e` löschen | Ordner weg | – | – | | |

## 13. Regression und Abnahme

1. **Regression:** Vor der Freigabe läuft der Gesamtplan `Testplan_FamilyNexus.md` mindestens auf dem Apple-Paar (G1 = iPhone, G2 = Mac); Ergebnis gehört in den Report.
2. **Report:** Ordner `User E2E Test Report/<JJJJ-MM-TT>_<NN>_Release-1.2.3_Build<NN>/` mit `Testreport.md`, `Ergebnisse.tsv` (Vorlage: `Ergebnisse_Vorlage.tsv` in diesem Ordner), `screenshots/`, `logs/`. Eintrag in `User E2E Test Report/README.md`.
3. **Freigabekriterien:**
   - Kein Schritt ❌ in A bis M, P und R.
   - Alle ⚠️ sind begründet und mit Issue verlinkt (F-07: Ausbleiben im Hintergrund ist laut #273 erwartet, nur Ergebnis festhalten; A-03: einmaliger Wechsel ist erwartet).
   - Abschnitt J auf iPad (J-01 bis J-04) und mindestens einem Android-Tablet bestanden, sonst bleibt #274 offen.
   - Abschnitt D und E-01 bis E-06 mit **zwei Konten** bestanden, sonst bleiben #422 und #424 offen; Abschnitt C mit zwei Konten, sonst bleibt #423 offen.
   - Nicht durchgeführte Schritte (⏳) stehen mit Grund im Report; ⏳ gilt **nicht** als bestanden.
   - Pflichtteil T grün (bis auf die dokumentierte Umgebungsausnahme), einschließlich E2E für #458 und #451.
   - **Build-Identität:** Alle Schritte tragen denselben Commit (RT3-V-05); der Commit ist `main` HEAD nach dem letzten Merge (E11: Freeze 18.11., 12:00).
   - **Abnahme iOS, macOS, Android (v03):** Ein Issue gilt für diese Plattformen als abgenommen, wenn alle ihm in Abschnitt 14 zugeordneten Schritte auf iOS-Simulator (iPhone, bei #274 auch iPad), Mac-App und Android-Emulator (bei #274 Tablet-AVD) ✅ sind. Die Spalte „Rest am Gerät“ benennt, was dann im Issue-Kommentar als nicht getestet stehen bleibt. Seit E-103 hängt das Schließen am Code-Test, die Spalte „Rest am Gerät“ benennt den Plattform-Pflichtschritt, der im Release-Beleg steht.
4. **Nach dem Lauf:** Ergebnisse in den betroffenen Issues vermerken (Abschnitt 14). Ein Issue schließt nach E-103 mit positivem Code-Test (Code-Testplan `Codetestplan_Offene_Issues.md`), nicht erst nach diesen Schritten; die Schritte dieses Plans sind der Plattformbeleg je Build (`docs/release-e2e/<Version>.md`, `tool/check_release_e2e.sh`). Der Merge entscheidet der Nutzer; kein Release ohne Freigabe.

## 14. Zuordnung Issues → Schritte (alle 39 offenen Issues, Stand 15.11. abends)

Spalte „Sim/Emu“: auf iOS-Simulator, Mac-App und Android-Emulator ausführbar (ja, teilweise, nein). Spalte „Rest am Gerät“: was nach Abschnitt 2a nur am echten Gerät oder in Store/Apple belegt wird. **Plattformen dieser Abnahme: iOS, macOS, Android.** Windows und Linux gehören nicht dazu; Schritte dort bleiben im Plan, die Issues #263, #325, #330 sind davon abhängig.

| Issue | Schritte | Sim/Emu | Rest am Gerät |
|---|---|---|---|
| #15 | RT3-N-03 | nein | manuell: Prüfkonto, Prüfanleitung (Apple) |
| #144 | RT3-I-05 bis RT3-I-07, RT3-M-04 | ja (iOS Text, Android `FLAG_SECURE`) | Windows-Aufnahme M-04 |
| #254 | RT3-F-01 bis RT3-F-08, RT3-F-10, RT3-F-11 | teilweise | Sperrbildschirm und Zähler am echten iPhone |
| #263 | RT3-E-11, RT3-M-01 | nein (Windows) | physische Tastatur unter Windows |
| #266 | RT3-L-02 bis RT3-L-04 | ja (Mac-App mit Entwicklungssignatur, Web) | Distributions-Signatur (TestFlight/DMG) |
| #268 | RT3-G-01 bis RT3-G-08, RT3-G-09 | teilweise | echte Anmeldung bei matrix.org (nur mit Freigabe) |
| #274 | RT3-J-01 bis RT3-J-08, RT3-M-02, RT3-M-03 | ja (iPad-Simulator, Tablet-AVD anzulegen) | Windows 200 % (M-02, M-03) |
| #297 | RT3-G-04, RT3-J-08 | teilweise | Hinweistext erscheint nur noch im Rückfallweg „Im Browser fortsetzen“ (System-Sitzung, J-08); Apple-Review |
| #316 | RT3-A-01 bis RT3-A-07 | teilweise (Ablauf, nicht Zeiten) | Startzeit am echten Gerät |
| #317 | RT3-B-01 bis RT3-B-04 | ja | Linux/Windows nicht Teil der Abnahme (Windows bestanden) |
| #498 | RT3-B-06 | ja | – |
| #325 | RT3-L-01 | nein (Windows) | `flutter test` unter Windows |
| #326 | RT3-I-08 bis RT3-I-10, RT3-K-06, RT3-T-07 | ja (Texte DE/EN) | Screenreader-Sprachausgabe, Muttersprachler |
| #330 | RT3-F-09 | nein (Windows) | Overlay 100/125/150/200 % |
| #332 | RT3-C-13, RT3-K-01 | ja (Android TalkBack; iOS/Mac Semantikbaum) | VoiceOver-Sprachausgabe |
| #345 | RT3-A-03, RT3-A-04 | ja | – |
| #348 | RT3-N-01 | nein | Eintrag in der Play Console |
| #349 | RT3-N-05 (Bildpaket), RT3-N-02 | teilweise (Bildpaket im Repo prüfbar) | Hochladen und Annahme in der Play Console |
| #350 | RT3-I-03, RT3-I-04 | ja (Android-Emulator, Google APIs) | Verhalten im echten Store |
| #351 | RT3-I-01, RT3-I-02 | ja | – |
| #381 | RT3-F-01 bis RT3-F-07 (TP-FN-NTF-381 v03) | teilweise | Mac-Zeilen (46) auf der Mac-App ausführbar; Android-Hintergrund bleibt #273 (v1.3, E5 offen); Sperrbildschirm am iPhone |
| #422 | RT3-D-01 bis RT3-D-09, RT3-K-03 | ja (zwei Instanzen) | – |
| #423 | RT3-C-01 bis RT3-C-12, RT3-K-02 | ja (zwei Instanzen) | – |
| #424 | RT3-E-01 bis RT3-E-06, RT3-K-04 | ja (zwei Instanzen) | – |
| #440 | RT3-L-05, RT3-T-02 | ja (Dev) | optional E2E gegen Synapse (RT3-T-03) |
| #441 | RT3-G-09 bis RT3-G-14 (G-04 bis G-08 mit Freigabe) | ja (Testserver bzw. lokale Testseite) | echte Anbieterseite, Fremdanbieter, Passkeys, Apple-Review |
| #445 | RT3-P-04, RT3-P-14 | ja (zwei Instanzen) | – |
| #446 | RT3-P-10 | ja (Dateien) | Veröffentlichung mit der Release-Freigabe |
| #447, #449 | RT3-P-11 | ja (Dateien) | Veröffentlichung mit der Release-Freigabe |
| #448 | RT3-P-12 | teilweise (`appstreamcli` fehlt auf macOS) | Validierung auf Linux/mit installiertem `appstreamcli` |
| #450 | RT3-P-05 | ja (zwei Konten nacheinander) | Randlücke E-48 bekannt |
| #451 | RT3-P-06, RT3-T-03 | ja (zwei Instanzen, Synapse) | – |
| #458 | RT3-P-01, RT3-T-03 | ja (Proxy/Netzbremse im Simulator/Emulator, E2E) | Funkloch am echten Gerät (E-17) |
| #463 | RT3-P-09 | ja (Android TalkBack; iOS/Mac Semantikbaum) | VoiceOver-Sprachausgabe |
| #486 | RT3-P-18, RT3-G-12 | teilweise (Simulator, Mac-App: Containerinhalt prüfbar) | Wirkung von `removeData` auf dem echten Gerät (TP-OAUTH-14) |
| #497 | RT3-P-20 | ja (zwei Instanzen, lokaler Synapse) | – |
| #501 | RT3-R-07 | ja (Android-Emulator, iOS-Simulator) | – |
| #502 | RT3-H-01 | ja | – |
| #503 | RT3-I-01 | ja | – |
| #504 | – (`ui_tour_test.dart`, `store_screenshots_test.dart` laufen auf Simulator/Emulator mit Screenshots, getrennter Lauf) | teilweise | Simulator-Lauf nach Testpflege |
| #505 | – (Dateiprüfung: `test/store/docs_consistency_test.dart`, Pflichtteil T) | ja (Dev) | – |
| #506 | RT3-D-02 | ja (zwei Instanzen) | Bildschirm schließt nach dem Speichern von selbst (Entscheidung des Herausgebers, PR #522) |
| #507 | RT3-H-06 | ja | Ursache ohne Reproduktion nicht belegt |
| #508 | RT3-P-14 | ja | – |
| #453 bis #456 | Sammel-Issues des Release-Reviews, keine Schritte; Schließen nach Entscheidung E9 | – | – |

Bereits geschlossen, Gegenprobe im Plan: #442 (RT3-P-13, RT3-J-04), #444 und #459 (RT3-P-03), #460 (RT3-P-07), #461 (RT3-P-08), #462 (RT3-P-11), #464 (RT3-P-02), #483 (RT3-P-15), #484 (RT3-P-16), #485 (RT3-P-17), #487 (RT3-P-19). #431: nach v1.3 verschoben, kein Schritt.

Hinweis: Das Release-Review legt weitere Issues an (Lauf 3 sieben, Lauf 4 fünf, Lauf 5 keines). Jedes neue Issue im Milestone bekommt vor dem Lauf einen Schritt in Abschnitt P oder eine Begründung, warum nicht; der Plan wird dann auf v05 gehoben.

Weitere Änderungen ohne eigenes offenes Issue (im Plan abgedeckt): #337 (E-07, E-08), #358 (E-09), #347 (H-01 bis H-05), #409 (E-10), #410 (C-12), #411 (H-04), #412 (G-08), #430 (G-01 bis G-03, G-06), #142 (L-06), #329 (I-09), E-96, E-97 (R), E-102 (G-09 bis G-14).

## Versionshistorie

| Version | Datum | Änderung |
|---|---|---|
| v01 | 14.11.2026 | Erste Fassung nach Release Notes 1.2.3, E-93 bis E-101, den 26 offenen Issues des Milestones und `Checkliste_Geraetenachtests.md`; Soll-Version 1.2.3 (29) |
| v02 | 14.11.2026 | Nach erneuter Prüfung von gh (45 statt 26 offene Issues): Abschnitt P (13 Schritte) für die Folge-Issues des Release-Reviews 1.2.3+29 (#444 bis #451, #458 bis #464) und #442; Zuordnung in Abschnitt 14 ergänzt; Stand `main` @ `18e3815` |
| v03 | 15.11.2026 | Nach dritter gh-Prüfung (38 offene Issues) und Sprint-Umsetzung: Build-Regel (nur aktueller `main`, RT3-V-05), Abschnitt 2a (Simulator-/Emulator-Matrix, Abnahmegrenzen), Abschnitt G auf eingebettete Anmeldung (E-102, #441, G-09 bis G-14), Abschnitt P unbedingt und an die Umsetzung angepasst (P-01, P-04, P-07, P-12, neu P-14), N-05 (Bildpaket #349), T-08 (Builds), Abschnitt 14 mit Sim/Emu und Rest am Gerät; #431 nach v1.3; Stand `main` @ `a4594ea` plus PR #482 |
| v04 | 15.11.2026 | Soll-Version auf 1.2.3 (30) (Build-Nummer PR #495, kein Upload); Stand `main` @ `531981a`; neu P-15 bis P-19 für #483 bis #487 (Review-Lauf 4), Abschnitt 14 mit #486 (39 offene Issues); RT3-V-01, V-02, V-04, V-05 auf Build 30; Bezug auf Review-Berichte `+29` (Lauf 5) und `+30` |
| v05 | 16.11.2026 | Folge-Issues #501 bis #508 des Release-Tests (Lauf 31): Zuordnung in Abschnitt 14; neu RT3-H-06 (#507, Abmelden und erneutes Anmelden), RT3-D-02 mit Beobachtung 20 s (#506), RT3-R-07 mit Statusleiste (#501); RT3-H-01, RT3-I-01, RT3-P-14 tragen #502, #503, #508 (Planerwartung korrigiert, App unverändert); Abnahme- und Schließregel auf E-103 umgestellt |
| v06 | 16.11.2026 | RT3-D-02 (#506): Der Avatar-Bildschirm schließt nach dem Speichern von selbst (Entscheidung des Herausgebers, PR #522, E-101-Nachtrag); Erwartung und Abschnitt 14 angepasst |
