# Testreport Lauf 24: Windows-Nachtests (nur G1, Build 1.2.2 (26))

**Plan:** Windows-Abschnitt aus `User E2E Test/Checkliste_Geraetenachtests.md` @ `40863fd` (#263, #144, #254, #274) plus die Windows-Anteile von #317 (B-02) und #266 (Laufzeit von `sqlite3` 3.8.0 gegen `sqlcipher.dll`) sowie die Pflichttests `flutter analyze` und `flutter test` auf einem Windows-Host.

**Abweichungen (erste Seite):**
- **Keine echte Tastatur, keine echte Maus.** Klicks und Tastendrücke kamen per Win32-`SendInput` (Ziffern als virtuelle Tasten `VK_0`…`VK_9`, kein `SendKeys`-Text). Das ist der Eingabeweg, über den auch Tastatur- und Maustreiber Ereignisse einspeisen, aber kein physisches Gerät. Die Abnahme „echte Tastatur“ (#263) bleibt deshalb formal beim Nutzer.
- **Bedienung blind, solange der Bildschirmschutz an war.** Texte, Rollen und Positionen kamen über die MSAA-Schnittstelle (`IAccessible`) der Flutter-Ansicht, nicht über OCR. UI Automation lieferte unter Windows nur den leeren Knoten `FLUTTERVIEW`. Nach der Kontoanlage wurde der Schutz nach der Regel aus Abschnitt 2 des Testplans ausgeschaltet; die Bilder davor gibt es nur für B-18.
- **SQLCipher-DLLs aus dem Release v1.2.2:** Der lokale Build bringt `sqlcipher.dll` und `libcrypto-3-x64.dll` nicht mit (die baut nur `release.yml` mit vcpkg). Beide stammen aus `FamilyNexus-v1.2.2-windows-x64.zip` (SHA-256 des Zips gegen die `.sha256` des Release geprüft; `sqlcipher.dll` SHA-256 `ea600893…cbd6e3`) und wurden neben die exe gelegt. Für `flutter test` und die Integrationstests lagen sie im `PATH`.
- **#254 mit einem Hilfsclient:** Die zweite Person (N2) war kein zweites App-Gerät, sondern `matrix-js-sdk` 37.13.0 mit Rust-Krypto in Node (Skript außerhalb des Repos). N2 wurde per Matrix-API von N1 in den Familienraum eingeladen und ist beigetreten, nicht über den Einladungsablauf der App (E-78). Das reicht für den Test der Zahl, nicht als Test des Beitrittsablaufs.
- Vor dem Lauf lag ein Datenrest aus Lauf 18 vor (Konto damals gelöscht). Gesichert nach `C:\fn-test\backup-appdata-1107`, nicht zurückgespielt.

## Abschnitt 2

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | Windows | – (N2 als Hilfsclient, siehe oben) |
| Gerät | Windows 11 Pro, VM | – |
| Betriebssystem | Windows 11 10.0.26300, 96 dpi (100 %) | – |
| Installationsquelle | Eigener Build aus `main` @ `40863fd`: `flutter build windows --release` (Flutter 3.47.7, VS Build Tools 2022 17.14), SQLCipher-DLLs aus v1.2.2 | – |
| App-Version Soll / Ist | 1.2.2+26 / „Version 1.2.2 (26)“ im Menü | – |
| Gerätesprache | Deutsch (de-DE) | – |
| Methode für Screenshots | `CopyFromScreen` (Fenster bzw. Vollbild), Bedienung per Skript | – |
| Tester / Datum | Claude Code (automatisiert) / 07.11.2026, ca. 20:20–21:35 | – |

Konten: `fnt-1107w-n1` (Test N1, Familie „Testfamilie 1107w“, in der App angelegt) und `fnt-1107w-n2` (Test N2, per API angelegt). Beide am Ende gelöscht: N1 in der App über „Konto löschen“, N2 per `/account/deactivate` mit `erase`. Gegenprobe: Anmeldung für beide `M_FORBIDDEN`. Passwörter und Notfall-Schlüssel lagen nur unter `C:\fn-test\secure`, nicht im Repository.

## Zusammenfassung

| Issue / Schritt | Ergebnis unter Windows |
|---|---|
| #263 Zeitwähler (B-05) | ✅ mit `SendInput`; echte Tastatur offen (siehe Abweichungen) |
| #144 Bildschirmschutz (B-18) | ✅ Screenshot und Alt-Tab; Bildschirmaufnahme ⏳ |
| #254 Zahl in der Taskleiste (E-16b) | ✅ Overlay 1, 9+, verschwindet beim Lesen; Meldung ohne Inhalt |
| #274 Desktop-Fenster (B-25) | ✅ 599/600/999/1000 dp, Zustand bleibt, kein Strich ab 1000 dp; 200 % Schrift ⏳ |
| #317 Hinweiskarte (B-02) | ✅ Windows zeigt keine Karte, „Erinnerungen“ genau einmal |
| #266 `sqlite3` 3.8.0 gegen `sqlcipher.dll` | ✅ App-Laufzeit, Neustart, Dateikopf verschlüsselt; 13 SQLCipher-Testdateien grün |
| `flutter analyze` | ✅ No issues found |
| `flutter test` (Windows-Host) | ⚠️ 1657 grün, 108 übersprungen, 22 rot, alle Umgebung bzw. Testannahmen (siehe unten), keiner ein App-Fehler |

## Ergebnisse je Punkt

### #263 Zeitwähler (Testplan B-05)
Termin-Editor → Beginn (Vorschlag 22:00) → Tastatur-Symbol „Zum Texteingabemodus wechseln“.
- Mausklick ins Feld „Stunde“: Wert „22“ ist markiert (B-05c). Tasten `2`, `1`: Stunde = 21, der Fokus springt ins Feld „Minute“, das ebenfalls markiert ist (B-05d). Tasten `3`, `0`: Minute = 30 (B-05e). OK: Beginn 21:30, Ende wandert auf 22:30 (B-05f). Gespeichert als „Test privat W, 21:30 – 22:30, Privat“ (B-05i). ✅
- **Restfall** (Klick aktiviert das Fenster direkt im Feld): Wähler erneut geöffnet, Explorer in den Vordergrund (`GetForegroundWindow` ≠ App), dann Klick ins Stundenfeld. Das Fenster wurde aktiv, „21“ war markiert (B-05g), `1`, `9` ergab 19 (B-05h). Kein Restfehler beobachtet. Danach „Abbrechen“, der Termin blieb bei 21:30. ✅
- Der Verdacht aus Lauf 18 (SendKeys-Artefakt) ist damit ausgeräumt: Mit virtuellen Tasten verhält sich der Build wie in #263 gefordert.

### #144 Bildschirmschutz (Testplan B-18)
- Nach der Kontoanlage war der Schutz an (Fensteraffinität 17 = `WDA_EXCLUDEFROMCAPTURE`). Hinweis unter dem Schalter: „Nimmt die App von Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben aus.“ ✅
- Schutz an: Im Vollbild-Screenshot fehlt das App-Fenster, obwohl es im Vordergrund lag; an seiner Stelle ist das Fenster dahinter zu sehen (B-18a). In Alt-Tab ist die Vorschau von FamilyNexus schwarz (B-18b). ✅
- Schutz aus: Affinität 0, Fenster im Screenshot sichtbar (B-18c), Alt-Tab zeigt den Inhalt (B-18d). Danach aus gelassen (Regel Abschnitt 2). ✅
- Nicht getestet: Bildschirmaufnahme mit einem Aufnahmewerkzeug (Snipping Tool, Game Bar) und Bildschirmfreigabe. ⏳

### #254 Meldungen und Zahl in der Taskleiste (E-16b)
- App auf „Heute“, anderes Fenster im Vordergrund. Eine **Klartext**-Nachricht von N2 per API wurde wie vorgesehen **nicht** gezählt (`ChatMapper.unreadReadable` zählt nur verschlüsselt angekommene Nachrichten).
- Verschlüsselte Nachricht von N2 (`matrix-js-sdk`): Chat-Reiter „1“, auf „Heute“ „1 ungelesene Nachricht“, Overlay am Taskleistensymbol (roter Punkt, weiße „1“; vorher keins: E16b-W1, E16b-W2). ✅
- Windows-Meldung um 21:21:04 (Registry `LastNotificationAddedTime`), in der Mitteilungszentrale „FamilyNexus – Neue Nachrichten“ **ohne Inhalt** (E16b-W3). ✅
- Chat geöffnet: Nachricht „Hallo von N2 …“ mit Marke „Neue Nachrichten“ (E16b-W4), Overlay danach weg (E16b-W5). ✅
- Zehn verschlüsselte Nachrichten: Chat-Reiter „10“, Overlay „9+“ (E16b-W6). ✅ Beobachtung: Die „9“ reicht bis an den Rand des 16-px-Kreises (kosmetisch).
- Nebenbei: Die Terminerinnerung für „Test privat W“ (10 Minuten vorher, 21:20) kam als Windows-Meldung an, auf „Heute“ stand „1 Erinnerung fällig“.

### #274 Desktop-Fenster (Testplan B-25)
Client-Breite per `SetWindowPos` gesetzt und nachgemessen (96 dpi, 1 dp = 1 px).
- 599 dp: Leiste unten (B-25-…_Heute_599dp). 600 dp und 999 dp: Rail links, einspaltig. 1000 dp und 1280 dp auf „Kalender“: Zweispalter, Titel „Kalender und Chat“, Kalender 479 dp, Chat 440 dp, dazwischen der Trenner (B-25-…_Kalender_1000dp). 999 dp: Titel „Kalender“, kein Chatfeld. ✅
- Ab 1000 dp bleiben Heute, Einkauf und Familie einspaltig, ohne senkrechten Strich (#309). ✅
- Zustand über 999 → 599 → 600 → 1000 → 800 → 599 dp: Chatentwurf „Entwurf Tablet“ und gewählter Reiter bleiben; Terminformular „Tablettest“ über 600/1000/599/1280/600 dp; offener Dialog „Eintrag bearbeiten“ mit ungespeicherter Eingabe „Milch W 2l“ über dieselben Breiten. „Zurück“ bzw. „Abbrechen“ speichert nichts. ✅
- Tab-Reihenfolge auf „Heute“ (800 dp): Menü → Rail (5 Reiter) → Inhalt (Alle Termine, Termin, Übersicht, Einkauf, Aufgaben, Chat öffnen, Neuer Termin) → Menü … Der Inhalt wird zusammenhängend durchlaufen, ohne Sprung zur Rail; das entspricht E-92 (eigene Fokusgruppen). Hinweis: Die Checkliste formuliert „Inhalt vor Rail“, tatsächlich kommt die Rail-Gruppe nach der Lage zuerst. ✅ (Formulierung der Checkliste prüfen)
- Nicht getestet: Windows-Textgröße 200 %. ⏳

### #317 Hinweiskarte (Testplan B-02, Windows-Anteil)
Auf „Heute“ keine Karte „Berechtigung fehlt“, „Erinnerungen“ genau einmal (B-02). In der Erinnerungs-Übersicht „Erinnerungen“ nur als Titel, keine Hinweiskarte (B-02b). Entspricht E-93 (Linux/Windows: Berechtigung gilt als erteilt). ✅

### #266 Windows-Laufzeit `sqlite3` 3.8.0 gegen `sqlcipher.dll`
- Release-Build mit `sqlite3` 3.8.0 (`pubspec.lock`) und `sqlcipher.dll` aus v1.2.2: Kontoanlage, Termin, Einkauf, Chat, Einstellungen laufen. Nach Beenden und Neustart: angemeldet, Termin und Einkauf da, Einstellung „Bildschirmschutz aus“ erhalten (H-266). ✅
- `familynexus_app.db` beginnt nicht mit `SQLite format 3` (Kopf zufällige Bytes, also verschlüsselt). ✅ Eine Klartextsuche nach den Testinhalten in den App-Dateien ist **nicht belegt**: Das Suchkommando war fehlerhaft (`Select-String -SimpleMatch` mit `A|B|C` sucht wörtlich), und die Daten waren beim Bemerken schon gelöscht. Den Klartextausschluss deckt der Integrationstest „Termindaten liegen nur verschlüsselt auf dem Gerät“ (grün, siehe unten) für Termine ab.
- Fehlender Geräteschlüssel (vom Integrationstest gelöscht): Die App meldet „Lokale Daten nicht lesbar“ und ändert nichts; „Lokale Daten zurücksetzen“ → „Willkommen“. ✅
- `flutter test` der 13 SQLCipher-Testdateien mit der DLL im `PATH`: 223 grün, 19 übersprungen, 0 rot. ✅
- Integrationstests auf `-d windows` (`tool/device_tests.sh` ist für Android gedacht): `db_security_test` 4 von 6 grün (Schlüssel stabil und getrennt; DB ohne bzw. mit falschem Schlüssel unlesbar; kein stiller Neuschlüssel; parallele Anforderungen). `event_store_test` 7 von 10 grün (u. a. „Termindaten liegen nur verschlüsselt auf dem Gerät“, Einkaufszettel verschlüsselt). Die 5 roten Fälle setzen Android voraus: Durchsuchen des Ordners über „Dokumente“ (unter Windows das ganze Benutzerprofil, `WinSAT` verweigert den Zugriff) bzw. `getDatabasesPath`/`openDatabase` des mobilen Plugins `sqflite_sqlcipher` (`MissingPluginException`). Keine App-Fehler.

### Bonus (nicht im Windows-Plan): #259
Einstellungen → Konto → „Server“ und der Dialog „Konto löschen?“ zeigen die Anbieter-Adresse `matrix-synapse-3ues.srv1348446.hstgr.cloud` (in Lauf 18 noch den Servernamen). ✅ Der Dialog nennt zusätzlich den Hinweis „Du bist der einzige Moderator …“, weil N2 Mitglied war.

## `flutter test` auf dem Windows-Host: die 22 roten Fälle

| Anzahl | Test | Ursache | Beleg |
|---|---|---|---|
| 13 Dateien (`setUpAll`) | u. a. `family_owner_test`, `logout_wipe_test`, `sql_*_store_test`, `chat_mapper_test` | `sqlcipher.dll` fehlt im Testprozess (`error code 126`); Linux nutzt die System-Bibliothek | Nachlauf mit DLL im `PATH`: 223 grün, 0 rot |
| 6 | `test/store/description_test.dart` | Git für Windows checkt mit `core.autocrlf=true` aus, der Test sucht `\nAUFGABEN\n` | LF-Checkout (`-c core.autocrlf=false`): grün |
| 1 | `test/store/release_notes_test.dart` (android de-DE) | dasselbe: 506 Zeichen mit CRLF, 496 mit LF | LF-Checkout: grün |
| 1 | `test/architecture_test.dart:62` | prüft `f.path.contains('lib/data/platform/')`; unter Windows enthält der Pfad `\` | auch im LF-Checkout rot |
| 1 | `test/data/app_badge_test.dart` (Linux-D-Bus) | braucht den Linux-Session-Bus (Zeitüberschreitung); schlägt auch auf macOS fehl (#317-Kommentar) | – |

## Befunde

| Nr. | Schwere | Punkt | Beschreibung |
|---|---|---|---|
| 1 | niedrig (Tests) | `flutter test` | 8 Tests sind nicht Windows-fest: `architecture_test.dart:62` (Pfadtrenner) und `description_test`/`release_notes_test` (CRLF). Abhilfe wäre `p.split`/`p.posix` bzw. `.replaceAll('\r\n', '\n')` im Test oder eine `.gitattributes` mit `eol=lf`. Kein App-Fehler |
| 2 | niedrig (Text) | Einkauf | Unter dem eigenen Eintrag steht „zuletzt von **Du**“ (`shoppingLastBy` mit `chatYou`); richtig wäre „zuletzt von dir“. Nicht Windows-spezifisch |
| 3 | kosmetisch | #254 | Overlay „9+“: Die Ziffer stößt an den Rand des 16-px-Kreises (`taskbar_badge.cpp`, Schrift −11 px) |
| 4 | Hinweis | #274 | Checkliste „Tab-Reihenfolge Inhalt vor Rail“ widerspricht dem Verhalten nach E-92 (Rail-Gruppe zuerst, Inhalt zusammenhängend); Formulierung anpassen |
| 5 | Hinweis | Werkzeuge | UI Automation sieht in Flutter unter Windows nur `FLUTTERVIEW`; MSAA (`AccessibleObjectFromWindow` + `IAccessible`) liefert den vollen Baum, auch bei aktivem Bildschirmschutz |

## Offen nach diesem Lauf
- #263: Nachtest mit physischer Tastatur (die Logik ist mit `SendInput` belegt).
- #144: Bildschirmaufnahme und Bildschirmfreigabe unter Windows.
- #274: Windows-Textgröße 200 %.

## Ablage
Screenshots in `screenshots/` (Dateinamen nach Schritt; Vollbilder B-18a/b und E16b-W3 zeigen auch den Desktop des Testrechners). Konsolenausgaben in `logs/`: `flutter_analyze.txt`, `flutter_test_windows_rot.txt` (rote Fälle und Summe), `flutter_test_sqlcipher_nachlauf.txt`, `integration_db_security_windows.txt`, `integration_event_store_windows.txt`. Notfall-Schlüssel und Passwörter sind nicht im Report.
