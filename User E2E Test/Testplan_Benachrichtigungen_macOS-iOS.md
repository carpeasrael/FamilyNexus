# Testplan Benachrichtigungen (macOS und iPhone-Simulator)

**Planversion: v03** (13.11.2026) · Dokument-ID `TP-FN-NTF-381 v03` · Stand: `main` @ `778b949`, Soll-Version der App **1.2.3** · v02 beschränkt den Plan **ausschließlich auf Benachrichtigungen** und berücksichtigt die Befunde aus Lauf 27 (Änderungen siehe Versionshistorie; Schrittnummern bleiben stabil, entfallene Nummern sind nicht neu vergeben) (`pubspec.yaml`, Build-Nummer beim Lauf aus `grep '^version:' pubspec.yaml` eintragen)

Bezug: Issue #381 „Benachrichtigung“ (Entscheidungsvorlage im Issue-Kommentar, Teil 1 „Erinnerung bei beendeter App“ als Gerätetest), `docs/ENTSCHEIDUNGEN.md` E-15 (Erinnerungen), E-88 (Meldungen zu Chat und Einkauf, Zahl am App-Symbol, **Korrektur zu #273 am Ende von E-88**), E-16, Datenschutz `privacy5Body`, Hinweistext `settingsActivityHint`. Gesamtplan `Testplan_FamilyNexus.md` (Schritte E-16a bis E-16d, B-02, B-10, B-20 werden hier wiederverwendet und vertieft), Vorlage für Aufbau und Spalten: `Release-Test_1.2.2_v01.md`.

## 1. Zweck und Abgrenzung

Der Plan prüft die **Benachrichtigungsfunktion** der App auf genau zwei Zielen und hält **genau fest, was kommt und was nicht** (Ausbleiben im Hintergrund ist laut E-88/#273 kein Fehler, aber das Ergebnis wird mit Sekunden dokumentiert):

1. Erinnerung zu einem Termin: bei laufender App im Vordergrund, im Hintergrund und bei **beendeter App** (OS-geplant, E-15; auf iOS und macOS wird erwartet, dass sie auch bei beendeter App erscheint).
2. Meldung „Neue Nachrichten“ und „Neue Einträge auf dem Einkaufszettel“ **ohne Inhalt**, wenn die App läuft, aber der Chat nicht sichtbar ist; keine Meldung bei sichtbarem Chat (bei mehreren Gesprächen heißt „sichtbar“: ein **Gespräch** ist geöffnet; die Gesprächsliste allein gilt nicht als sichtbarer Chat, dort kommen Meldungen und nichts wird als gelesen markiert, E-100, #423); neue Meldung **ersetzt** die alte.
3. Verhalten im Hintergrund und bei beendeter App (E-88/#273: nicht zugesagt).
4. Zahl am App-Symbol (iOS: Zahl am Icon, Freigabe „Kennzeichen“; macOS: Dock-Zahl), Zurücksetzen beim Lesen und beim Abmelden.
5. Einstellungen → „Benachrichtigungen“ (Hinweistext, zwei Schalter, Aus-Schalter wirkt, Berechtigungsabfrage und Karte „Berechtigung fehlt“).
6. Datenschutz: nie Titel, Ort, Notiz, Absender, Gespräch oder Inhalt in der Meldung, auch nicht in der Mitteilungszentrale.

| Ziel | Plattform | System |
|---|---|---|
| **G1** | iOS-Simulator **iPhone 18 Pro** (iOS 27.x), Bedienung und Screenshots über `xcrun simctl` | Simulator im Device Hub |
| **G2** | **macOS** (dieser Mac, Test-Bundle-ID `de.inneso.familynexus.e2e`) | macOS 27.x |

**Nicht Gegenstand:** alles, was keine Benachrichtigung ist (Erinnerungsübersicht und Terminverwaltung als eigene Funktion, Datenschutzerklärung als Ganzes, App-Sperre, Familienwechsel, Reaktionen und Antworten im Chat), Push-Dienst (APNs/FCM/UnifiedPush, laut #381 Option A zurückgestellt; kein Pusher, kein Gateway), Android, Linux, Windows, Web, echte Geräte, Meldungen für Aufgaben, Reaktionen, Kalender und Beitrittsanfragen (E-88 verworfen), Öffnen eines bestimmten Gesprächs per Tipp auf die Meldung (E-88 verworfen; Tipp öffnet nur die App). Die Erinnerungsübersicht dient nur als Mittel, um Erinnerungen zu bestätigen und das Verschwinden der Meldung zu prüfen.

**Grenzen des Simulators (offen benannt, nie als bestanden werten):**
- Kein Sperrbildschirm mit Gerätecode, daher **`private`-Sichtbarkeit auf dem Sperrbildschirm nicht prüfbar** (nur Mitteilungszentrale und Banner, Abschnitt 11).
- Der Simulator friert Apps im Hintergrund nicht wie ein echtes iPhone ein (kein Suspend nach wenigen Sekunden, kein Energiesparen). Eine Meldung, die im Simulator im Hintergrund kommt, belegt **nichts** für das Gerät; ein Ausbleiben dort ist aussagekräftiger als ein Eintreffen. Das Gerät-Verhalten bleibt ⏳ (Abschnitt 12).
- Der Mac-Build ist ad hoc signiert (`codesign -dvv`: `Signature=adhoc`); Systemdialog und Eintrag unter „Mitteilungen“ erscheinen dort teils nicht (Befund 16 aus Lauf 26, B-02 im Gesamtplan). Fehlt der Dialog, ist der Weg über „Einstellungen öffnen“ der Normalfall; das ist im Bericht zu vermerken, nicht als App-Fehler zu werten.
- Simulator-Benachrichtigungen werden über den Simulator-Dienst zugestellt; Banner sind in `simctl io screenshot` sichtbar, das Zahlzeichen am Icon nur auf dem Home-Bildschirm.

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ nicht durchgeführt (mit Grund) · n/a (auf der Plattform nicht vorhanden, mit Grund). **Ein Schritt gilt nur als ✅, wenn das Erwartete am Screenshot oder an der genannten Ausgabe nachweisbar ist.** Was nicht ausgeführt wurde, ist ⏳, nie ✅.

## 2. Festlegung von Plattform und System (vor dem ersten Schritt ausfüllen)

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | iOS (Simulator) | macOS |
| Gerät | iPhone 18 Pro, UDID aus `xcrun simctl list devices` (`iPhone 18 Pro`, Status Booted) | dieser Mac |
| Betriebssystem und Version | iOS 27.x | macOS 27.x |
| Installationsquelle | `flutter build ios --simulator --debug` aus `main`, `xcrun simctl install <UDID> build/ios/iphonesimulator/Runner.app` | `flutter build macos --debug` mit Test-Bundle-ID `de.inneso.familynexus.e2e` (nur `macos/Runner/Configs/AppInfo.xcconfig` im Worktree geändert, nicht auf `main`), Bau am besten in einem Worktree |
| App-Version Soll / Ist | 1.2.3 (NN) / | 1.2.3 (NN) / |
| Signatur | Simulator | `codesign -dvv` (erwartet ad hoc) |
| Gerätesprache, Darstellung | | |
| Uhrzeit-Quelle | Mac-Uhr (Simulator teilt sie); Zeitzone notieren | |
| Methode für Screenshots | `xcrun simctl io <UDID> screenshot` | `screencapture -x -R<x>,<y>,<b>,<h>` (Fenster fest platzieren) und `screencapture -x` für Mitteilungszentrale und Dock |
| Tester / Datum / Uhrzeit Beginn | | |

**Regeln (aus den Läufen 25 und 26):**
- **Fenster des Nutzers nie bedienen** (WebStorm, Transporter, weitere Device-Hub-Fenster). Nur das Fenster der Test-App und das Device-Hub-Fenster von `iPhone 18 Pro` bedienen.
- **Schlüsselbund der Nutzer-App `/Applications/FamilyNexus.app` nicht anfassen.** Auf dem Mac keine „Alle lokalen Daten löschen“-Schritte; Abmelden (Abschnitt 9) ist erlaubt, löscht aber nur die Sitzung der Test-App. Zeigt die Test-App Restdaten („Anmelden“ statt „Willkommen“), im Bericht vermerken (Befund 2 Lauf 26).
- Die Nutzer-App darf beim Test **nicht laufen** (sonst zwei Prozesse, Dock-Zahl und Meldungen verwechselbar; Links öffnen sonst die falsche App, #61). Vorher `pgrep -fl FamilyNexus` prüfen; läuft die Nutzer-App, nicht beenden, sondern Lauf auf ⏳ verschieben und den Nutzer fragen.
- Keine Geheimnisse in Bericht oder Screenshots: Passwörter, Notfall-Schlüssel, Einladungslinks schwärzen.
- Mac-Bildschirm darf in Wartezeiten nicht schlafen: `caffeinate -d -t 14400` im Hintergrund, vor Fensterzugriffen `caffeinate -u -t 2` (Befund 7 Lauf 26). Bei schwarzen Screenshots wiederholen.
- **Schlüsselbund-Abfrage der Mac-Test-App (Voraussetzung für G2):** Die ad hoc signierte Test-App fragt beim Start das Schlüsselbund-Passwort des Nutzers ab (Lauf 27, Befund 1). Der Tester gibt das Passwort **nie** ein und rät es nicht. Der Nutzer bestätigt die Abfrage einmal (z. B. „Immer erlauben“) oder begleitet den Lauf am Mac; ohne das sind alle G2-Schritte ⏳ mit Grund, Teil I läuft mit G1 weiter.
- **Fokus/Nicht stören** am Mac und im Simulator aus (sonst werden Banner unterdrückt); vor dem Lauf prüfen und notieren.

## 3. Voraussetzungen und Vorbereitung

1. **Build 1.2.3 aus `main`:** `git fetch origin && git status -sb` (main = origin/main, Commit mit `git rev-parse --short origin/main` notieren), `grep '^version:' pubspec.yaml`; `/home/carpeasrael/tools/flutter/bin/flutter` gilt nur für den Linux-Host, hier das Flutter des Macs (`which flutter`). Bau: `flutter build ios --simulator --debug` und `flutter build macos --debug` (Test-Bundle-ID siehe Abschnitt 2). Der Arbeitsbaum des Nutzers kann fremde Änderungen enthalten: im Worktree bauen, nichts stagen, nichts committen.
2. **Simulator:** `xcrun simctl list devices | grep "iPhone 18 Pro"` (nicht „Pro Max“), UDID notieren, `xcrun simctl boot <UDID>` falls nötig, `open -a Simulator` bzw. Device Hub. App-Daten frisch: `xcrun simctl uninstall <UDID> de.inneso.familynexus`, `xcrun simctl keychain <UDID> reset`, App neu installieren (nur auf dem Simulator erlaubt). **Achtung (Lauf 27, Befund 3):** Auf dem Simulator (iOS 27.2) bleibt die Mitteilungsfreigabe nach Deinstallieren, `privacy reset all` und `keychain reset` erhalten. Für den Erstlauf (N-09, N-10) und die Verweigerungsfälle (N-63, N-64) deshalb **einen frisch angelegten Wegwerf-Simulator** verwenden (`xcrun simctl create "FNT-Berechtigung" <Gerätetyp> <Runtime>`, nach dem Lauf `xcrun simctl delete`) oder die Freigabe in iOS → Einstellungen → Mitteilungen → FamilyNexus von Hand ausschalten. Ist die Freigabe auf G1 schon erteilt, sind N-09 und N-10 dort n/a mit Grund.
3. **Testserver und Konten** nach Gesamtplan, Abschnitt 3 und `Tester_Guide_EN.md`: eigener Testserver bzw. lokaler Synapse (`tool/synapse/up.sh`, `curl -fsk https://localhost:18448/_matrix/client/versions` liefert 200). **Keine Konten bei matrix.org, keine Registrierung dort.** Der Projekt-Testserver delegiert per `.well-known` auf einen anderen Homeserver-Namen (Lauf 27, Befund 11); Namensprüfung über `/register/available` der Provider-Adresse, Einladungslinks tragen den delegierten Namen. Nur eigene Wegwerfkonten `fnt-MMTT-n1` (N1, G1) und `fnt-MMTT-i2` (I2, G2), vorher `/register/available` prüfen, Datumsteil mit Buchstaben, wenn belegt. Familie `Testfamilie MMTT` (N1 gründet, I2 tritt per Einladung bei, Gesamtplan E-01 bis E-11). **Zugangsdaten und Notfall-Schlüssel nur in einer Datei außerhalb des Repos oder in `secure/` (von Git ignoriert), Rechte 600, nie in Plan, Bericht, Logs oder Screenshots.**
4. **Ausgangszustand der Systemfreigaben** (Erstlauf): iOS-Simulator: App frisch installiert, Mitteilungen noch nicht entschieden; macOS: Systemeinstellungen → Mitteilungen → Eintrag der Test-App fehlt oder steht auf Standard, Eintrag notieren. Für Grenzfälle (Abschnitt 8) werden Freigaben bewusst verweigert und zurückgesetzt: iOS-Simulator: Deinstallieren und `privacy reset` setzen die Frage **nicht** zuverlässig zurück (siehe Punkt 2): neuen Wegwerf-Simulator anlegen; macOS: Eintrag in Systemeinstellungen → Mitteilungen umschalten, `tccutil reset` gilt nicht für Mitteilungen.
5. **Rollen:** Eine Meldung entsteht nur durch ein **anderes Mitglied** (eigene Nachrichten und Einträge melden nichts). Deshalb sendet immer das **andere** Ziel (App-Konto), kein Skript: Einkaufseinträge sind verschlüsselte App-Ereignisse und lassen sich nicht per `curl` erzeugen. Der Plan hat daher zwei Hälften mit getauschten Rollen: **Teil I**: G1 (iPhone, N1) beobachtet, G2 (Mac, I2) sendet; **Teil II**: G2 (Mac) beobachtet, G1 sendet. Der sendende Client bleibt im Vordergrund und im Chat bzw. Tab „Einkauf“. Wer nichts beobachtet, wird nur bedient, nie bewertet. **Ersatzsender:** Fällt der Mac aus (Schlüsselbund-Abfrage), darf Teil I mit einem **zweiten, eigens angelegten Wegwerf-Simulator** als Gegenstelle laufen (anderes Mitglied, anderes Gerät); die betroffenen Schritte werden ⚠️ mit Hinweis „Ersatzsender“ gewertet und belegen nichts für macOS als Sender.
6. **Zeitvorgaben für Erinnerungen:** Vorlauf-Werte der App sind `kReminderChoices = 0, 5, 10, 15, 30, 60, 120, 1440, 2880` Minuten (`lib/features/calendar/widgets/event_editor_support.dart:4`); „0“ erscheint als **„Zur Startzeit“** (`reminderAtStart`), die Meldung lautet dann **„Der Termin beginnt jetzt“** (`reminderBodyNow`), sonst **„Termin in 5 Minuten“** (`reminderBody` mit `durationMinutes`). Der kürzeste Vorlauf ist 0, der kürzeste Vorlauf mit Dauer ist 5. Der Planer plant nur Termine mit Zeit in der Zukunft; die Minute wird abgerundet (`reminder_coordinator.dart:149`), Toleranz **±60 s** einplanen. **Praxis (Lauf 27, Befund 10):** Die Uhrzeit im Zifferblatt ist nicht beliebig genau einstellbar; ein Beginn „in 7 Minuten“ ist oft nicht erreichbar. Beginn und Vorlauf deshalb **vor dem Speichern** notieren und die Soll-Zeit der Meldung (Beginn minus Vorlauf) aus den gespeicherten Werten rechnen. Neue Termine übernehmen die Standard-Erinnerung (meist „10 Minuten“); im Formular auf genau die geplante Auswahl umstellen, sonst lautet die Meldung „Termin in 10 Minuten“. Standard: Termin **Beginn in 7 Minuten, Vorlauf 5 Minuten** (Meldung in ca. 2 Minuten), bzw. **Beginn in 3 Minuten, Vorlauf Zur Startzeit** (Meldung in ca. 3 Minuten). Termine privat anlegen, eindeutig benennen (z. B. `Ntf Geheim Zahnarzt`, Ort `Ntf Geheimort`, Notiz `Ntf Geheimnotiz`), damit ein Durchsickern von Titel, Ort oder Notiz sofort auffällt.
7. **Beobachtungsprotokoll:** Je Meldungsschritt wird notiert: Uhrzeit der Aktion (aus `date +%T`), Uhrzeit des Eintreffens (am Banner oder Mitteilungszentrale), Differenz in Sekunden, genauer Wortlaut, Anzahl der Meldungen. Konsolenausgaben nach `logs/<Schritt>.txt`.
8. **Berichtsordner** nach `User E2E Test Report/README.md`: `User E2E Test Report/<JJJJ-MM-TT>_<NN>_iOS-macOS-Simulator_Build<NN>/` mit `Ergebnisse.tsv`, `Befunde.md`, `Testreport.md`, `screenshots/`, `logs/` (Vorlagen Abschnitt 13); Nummer `NN` = nächste laufende Nummer aus der Tabelle in `User E2E Test Report/README.md`.

## 4. Zitierte Nutzertexte (aus `lib/l10n/app_de.arb` / `app_en.arb`)

| Schlüssel | Deutsch | Englisch |
|---|---|---|
| `reminderTitle` | Erinnerung | Reminder |
| `reminderBody` | Termin in {duration} (z. B. „Termin in 5 Minuten“) | Event in {duration} |
| `reminderBodyNow` | Der Termin beginnt jetzt | The event starts now |
| `activityChatBody` (Titel der Meldung: „FamilyNexus“) | Neue Nachrichten | New messages |
| `activityShoppingBody` | Neue Einträge auf dem Einkaufszettel | New items on the shopping list |
| `settingsActivity` | Benachrichtigungen | Notifications |
| `settingsNotifyChat` | Neue Chat-Nachrichten | New chat messages |
| `settingsNotifyShopping` | Neue Einträge auf dem Einkaufszettel | New items on the shopping list |
| `settingsActivityHint` | Meldungen ohne Inhalt, nur solange die App geöffnet ist. Auf Mobilgeräten können sie im Hintergrund und bei beendeter App ausbleiben (es gibt keinen Push-Dienst). | Notifications without content, only while the app is open. On mobile devices they may not arrive while the app is in the background or closed (there is no push service). |
| `settingsActivityBadgeApple` | Die Zahl am App-Symbol erlaubst du in den Geräteeinstellungen unter Mitteilungen → FamilyNexus → Kennzeichen. | Allow the number on the app icon in device settings under Notifications → FamilyNexus → Badges. |
| `settingsReminders` / `remindersDefault` | Erinnerungen / Standard-Erinnerung | Reminders / Default reminder |
| `remindersPermissionTitle` | Berechtigung fehlt | Permission missing |
| `remindersPermissionNotifications` | Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen. | Notifications are blocked. Without them no reminders appear. |
| `remindersPermissionSystem` | Benachrichtigungen sind in den Geräteeinstellungen ausgeschaltet. Erlaube sie dort für FamilyNexus, sonst erscheinen keine Erinnerungen. | Notifications are switched off in the device settings. Allow them there for FamilyNexus, otherwise no reminders appear. |
| `remindersAllow` / `remindersOpenSettings` | Erlauben / Einstellungen öffnen | Allow / Open settings |
| `remindersAcknowledge` | Erinnerung an {title} bestätigen | |
| `chatNewMessages` (Linie im Chat) | Neue Nachrichten | New messages |
| `logout` | Abmelden | Sign out |
| `privacy5Body` | Erinnerungen sind lokale Benachrichtigungen. Sie zeigen nie Titel, Ort oder Notiz, nur „Termin in …“ oder „Der Termin beginnt jetzt“. Bei neuen Nachrichten und Einkaufseinträgen meldet die App nur „Neue Nachrichten“ bzw. „Neue Einträge auf dem Einkaufszettel“, ohne Absender oder Inhalt und nur, solange sie geöffnet ist (auf Mobilgeräten können sie im Hintergrund ausbleiben); die Zahl ungelesener Nachrichten kann am App-Symbol erscheinen. Es gibt keinen Push-Dienst eines Dritten. | Reminders are local notifications. They never show title, location or note, only “Event in …” or “The event starts now”. For new messages and shopping items the app only shows “New messages” or “New items on the shopping list”, … (vollständig in `app_en.arb`) |
| `privacy6DesktopNote` | Erinnerungen und Meldungen zu neuen Nachrichten und Einkaufseinträgen erscheinen nur, solange die App läuft; dafür fragt die App keine Berechtigung an. | |

Hinweis zu `privacy6DesktopNote`: Er gilt laut Text für Linux und Windows; auf macOS wird laut E-15 beim Betriebssystem geplant. Weicht die Anzeige auf dem Mac vom Text ab, als Befund notieren (Konsistenz Text/Verhalten), nicht als Fehler der Funktion.

## 5. Abschnittsübersicht

| Abschnitt | Thema | Schritte |
|---|---|---|
| A | Version, Konten, Ausgangslage | N-01 bis N-05 |
| B | Einstellungen und Berechtigung | N-06 bis N-12 |
| C | Erinnerung bei laufender App (Vordergrund) | N-13 bis N-16 |
| D | Erinnerung im Hintergrund und bei beendeter App | N-17 bis N-19, N-21 bis N-24 (N-20 entfallen) |
| E | Meldung Chat, Teil I (G1 beobachtet) | N-25 bis N-34 |
| F | Meldung Einkauf, Teil I (G1 beobachtet) | N-35 bis N-39 |
| G | Zahl am App-Symbol | N-40 bis N-45 (N-46 entfallen) |
| H | Hintergrund und beendete App (Meldungen) | N-47 bis N-52 |
| I | Teil II (G2 beobachtet, G1 sendet) | N-53 bis N-60, N-62 (N-61 entfallen) |
| J | Grenzfälle Schalter und Berechtigung | N-63 bis N-69 (N-70 entfallen) |
| K | Abmelden räumt auf | N-71 bis N-74 |
| L | Datenschutz der Meldungen und Texte | N-75, N-76, N-78 (N-77 entfallen) |
| M | Aufräumen | N-79 bis N-81 |

## 6. Testschritte

Spalten: **ID** · **Pl.** (G1, G2, G1+G2) · **Schritt** · **Erwartetes Ergebnis** · **Screenshot** · **Beob.** · **Erg.** Die letzten beiden Spalten füllt der Tester. Screenshot-Dateinamen: `N-xx-G1.png` (iPhone-Simulator), `N-xx-G2.png` (Mac), bei mehreren Bildern `N-xx-G1_a.png`, `_b`. Konsolenschritte: `logs/N-xx.txt`.

### A. Version, Konten, Ausgangslage

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-01 | – | `git fetch origin`, `git rev-parse --short origin/main`, `grep '^version:' pubspec.yaml`; Ausgabe nach `logs/N-01.txt` | Soll-Version 1.2.3 und Commit stehen fest (Plan: `778b949`; weicht `origin/main` ab, Abweichung im Bericht nennen) | Konsole `logs/N-01.txt` | | |
| N-02 | G1+G2 | Ist-Version: `xcrun simctl listapps <UDID> \| grep -A12 -i familynexus` (CFBundleShortVersionString, CFBundleVersion); Mac: `defaults read <Test-App>/Contents/Info CFBundleShortVersionString`, `… CFBundleVersion`, `codesign -dvv <Test-App> 2>&1 \| grep -E "Signature\|Identifier"`; `pgrep -fl FamilyNexus` (Nutzer-App läuft nicht) | Ist = Soll auf beiden; Mac-Bundle-ID `de.inneso.familynexus.e2e`; Signatur ad hoc; keine Nutzer-App läuft | `N-02-G1.png`, `N-02-G2.png` (Konsole), `logs/N-02.txt` | | |
| N-03 | – | Server prüfen (`curl -fsk …/_matrix/client/versions`), Benutzernamen `fnt-MMTT-n1`, `fnt-MMTT-i2` mit `/register/available` prüfen, Zugangsdatei außerhalb des Repos anlegen (Rechte 600) | JSON mit `"versions"`, beide Namen frei (sonst Datumsteil ändern), Datei nur lokal; **kein** matrix.org | `logs/N-03.txt` (ohne Geheimnisse) | | |
| N-04 | G1+G2 | Konten und Familie nach Gesamtplan E-01 bis E-11 herstellen (G1 = N1 gründet, G2 = I2 tritt bei); beide in „Heute“; Fokus/Nicht stören aus; Mitteilungsstatus des Ausgangszustands notieren (Mac: Systemeinstellungen → Mitteilungen, iOS: Einstellungen → Mitteilungen → FamilyNexus bzw. kein Eintrag) | Beide Geräte zeigen „Heute“ derselben Familie; Ausgangsfreigabe notiert | `N-04-G1.png`, `N-04-G2.png` | | |
| N-05 | G1+G2 | Gegenstellen-Probe ohne Meldungen: G2 sendet im Chat `Ntf Probe`, G1 sieht sie im offenen Chat; Einkauf `Ntf Probe-Brot` anlegen, G1 sieht ihn im Tab „Einkauf“ | Chat und Einkauf synchronisieren in beide Richtungen (Voraussetzung für alle weiteren Schritte); sonst Lauf abbrechen und eskalieren | `N-05-G1.png`, `N-05-G2.png` | | |

### B. Einstellungen und Berechtigung

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-06 | G1, G2 | Einstellungen öffnen, zu Abschnitt **„Benachrichtigungen“** scrollen | Überschrift „Benachrichtigungen“, zwei Schalter **„Neue Chat-Nachrichten“** und **„Neue Einträge auf dem Einkaufszettel“**, beide **an** (Standard), darunter der Hinweistext | `N-06-G1.png`, `N-06-G2.png` | | |
| N-07 | G1, G2 | Wortlaut des Hinweistexts mit Abschnitt 4 vergleichen (Gerätesprache Deutsch; danach Englisch kurz prüfen) | Genau: „Meldungen ohne Inhalt, nur solange die App geöffnet ist. Auf Mobilgeräten können sie im Hintergrund und bei beendeter App ausbleiben (es gibt keinen Push-Dienst).“ (en: „Notifications without content, only while the app is open. On mobile devices they may not arrive while the app is in the background or closed (there is no push service).“). Kein Text verspricht Push oder Meldungen bei beendeter App | `N-07-G1.png`, `N-07-G2.png` | | |
| N-08 | G1 | Nur iPhone: Hinweis zur Zahl am Symbol suchen (`settingsActivityBadgeApple`), solange „Kennzeichen“ nicht freigegeben ist. Mac: derselbe Abschnitt | **Soll nach Code (Lauf 27, Befund 4):** Die Zeile „Die Zahl am App-Symbol erlaubst du in den Geräteeinstellungen unter Mitteilungen → FamilyNexus → Kennzeichen.“ steht auf **iOS und macOS immer**, unabhängig von der Systemfreigabe (`settings_notify_parts.dart:82-86`, Bedingung nur `PlatformInfo.isIOS || PlatformInfo.isMacOS`). Wortlaut und Anzeige notieren; dass der Hinweis bei erlaubtem Kennzeichen weiter steht, ist ein **Hinweis auf einen offenen Verbesserungsvorschlag** (nur bei fehlender Freigabe zeigen), kein Fehler | `N-08-G1.png`, `N-08-G2.png` | | |
| N-09 | G1, G2 | Auf „Heute“ bzw. in Einstellungen → „Erinnerungen“: Zustand der Karte **„Berechtigung fehlt“** vor jeder Freigabe ansehen (B-02, #317, E-93) | Solange nichts erlaubt: Karte „Berechtigung fehlt“ mit „Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.“ und Knopf **„Erlauben“**; „Erinnerungen“ steht auf „Heute“ nur einmal. Ist schon erlaubt (Wiederholungslauf): n/a mit Grund | `N-09-G1.png`, `N-09-G2.png` | | |
| N-10 | G1, G2 | **„Erlauben“** antippen bzw. anklicken | Systemdialog „… möchte dir Mitteilungen senden“ erscheint, **Erlauben** wählen; danach ist die Karte weg. **Mac ad hoc:** erscheint kein Dialog, wechselt der Text zu „Benachrichtigungen sind in den Geräteeinstellungen ausgeschaltet. Erlaube sie dort für FamilyNexus, sonst erscheinen keine Erinnerungen.“ mit „Einstellungen öffnen“ → in den Systemeinstellungen erlauben (Bildschirmfoto des Dialogs bzw. der Einstellung), zurück in die App: Karte weg → ⚠️ nur mit Befund-Verweis auf Signatur, nicht ❌ | `N-10-G1_a.png` (Dialog), `N-10-G1_b.png` (danach), `N-10-G2_a.png`, `N-10-G2_b.png` | | |
| N-11 | G1 | iOS: Freigabe „Kennzeichen“ prüfen: Einstellungen (iOS) → Mitteilungen → FamilyNexus. Falls die Freigabe nicht mit „Erlauben“ in N-10 erteilt wurde, hier einschalten (simctl kann das nicht, im Simulator-Gerät bedienen) | Schalter „Kennzeichen“ an; der Hinweis `settingsActivityBadgeApple` steht laut Code weiterhin (N-08); Zustand vor und nach der Freigabe festhalten, keine Wertung ❌ für das Fortbestehen | `N-11-G1_a.png`, `N-11-G1_b.png` | | |
| N-12 | G2 | Mac: Systemeinstellungen → Mitteilungen → Eintrag der Test-App ansehen (Banner/Hinweise, „Kennzeichen“, Vorschau, „Auf dem Sperrbildschirm“) | Eintrag vorhanden, Mitteilungen erlaubt, **Kennzeichen an** (für die Dock-Zahl, N-41); Stil „Banner“ oder „Hinweise“ (nicht „Ohne“), sonst Banner nicht sichtbar → Stil auf „Banner“ stellen und notieren | `N-12-G2.png` | | |

### C. Erinnerung bei laufender App (Vordergrund)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-13 | G1, G2 | Termin anlegen (privat): Titel `Ntf Geheim Zahnarzt`, Ort `Ntf Geheimort`, Notiz `Ntf Geheimnotiz`, Beginn **in 7 Minuten**, Erinnerung **5 Minuten** (Mehrfachauswahl: nur „5 Minuten“, andere abwählen); Speichern, auf „Heute“ bleiben. Beginn und Uhrzeit notieren (`date +%T`) | Termin steht auf „Heute“; Karte „Erinnerungen“ zeigt „1 Erinnerung geplant“ (`remindersPlanned`) bzw. Übersicht „Geplant (1)“ mit „5 Minuten vorher“ | `N-13-G1.png`, `N-13-G2.png` | | |
| N-14 | G1, G2 | App im **Vordergrund** auf „Heute“ lassen und bis 5 Minuten vor Beginn warten (Banner im Screenshot, danach Mitteilungszentrale öffnen) | Zur Zeit (±60 s) kommt eine Systemmeldung **„Erinnerung“ / „Termin in 5 Minuten“**, **ohne** `Ntf Geheim Zahnarzt`, `Ntf Geheimort`, `Ntf Geheimnotiz`; kein Absender, keine Nutzlast. Genaue Sekunden der Abweichung notieren (iOS zeigt Banner auch im Vordergrund, wenn die App es anfordert; zeigt der Simulator im Vordergrund keinen Banner, aber die Mitteilungszentrale den Eintrag, ⚠️ mit Hinweis) | `N-14-G1_a.png` (Banner), `N-14-G1_b.png` (Zentrale), `N-14-G2_a.png`, `N-14-G2_b.png` | | |
| N-15 | G1, G2 | Danach (Übersicht nur als Mittel) auf „Heute“ die Karte „Erinnerungen“ → **„Übersicht“** öffnen; bei dem Termin das Häkchen **„Erinnerung an Ntf Geheim Zahnarzt bestätigen“** (der Titel steht nur in der App, `remindersAcknowledge`) antippen (B-10, #218, E-87) | Die Erinnerung steht als fällig in der Übersicht; nach dem Bestätigen verschwindet die **Meldung aus der Mitteilungszentrale** (Screenshot der Zentrale; nur das ist hier das Prüfziel) | `N-15-G1_a.png`, `N-15-G1_b.png`, `N-15-G2_a.png`, `N-15-G2_b.png` | | |
| N-16 | G1, G2 | Zweiter Termin mit Vorlauf **Zur Startzeit**: Titel `Ntf Start`, Beginn in 3 Minuten; App im Vordergrund warten | Meldung **„Erinnerung“ / „Der Termin beginnt jetzt“** (`reminderBodyNow`), ohne Titel; erscheint nach ca. 3 Minuten (±60 s) | `N-16-G1.png`, `N-16-G2.png` | | |

### D. Erinnerung im Hintergrund und bei beendeter App

Je Variante einen **eigenen neuen Termin** anlegen, vor dem Beobachten die App in den geplanten Zustand bringen und **nicht** wieder öffnen, bis die Meldung eingetroffen oder 3 Minuten nach der Soll-Zeit verstrichen sind. Wichtig: Erst **nach dem Speichern des Termins** in den Zustand wechseln (Planung beim Speichern, E-15).

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-17 | G1 | Termin `Ntf Hintergrund` (Beginn in 7 Minuten, Vorlauf 5), speichern; **Home** (Simulator: Home-Schaltfläche bzw. Cmd+Shift+H) → App läuft im Hintergrund; warten, Banner und Mitteilungszentrale fotografieren | Meldung „Erinnerung“ / „Termin in 5 Minuten“ erscheint zur Zeit (±60 s), ohne Titel; Uhrzeit des Eintreffens und Abweichung notieren; **Simulator-Grenze** im Bericht nennen (kein Einfrieren) | `N-17-G1_a.png`, `N-17-G1_b.png` | | |
| N-18 | G2 | Termin `Ntf Hintergrund` (Beginn in 7 Minuten, Vorlauf 5), speichern; Fenster **minimieren** (Cmd+M, App läuft weiter, Dock-Symbol mit Punkt) | Meldung zur Zeit (±60 s) als Banner und in der Mitteilungszentrale, ohne Titel; Dock-Symbol zeigt keine Zahl durch die Erinnerung (Zahl nur für ungelesene Chat-Nachrichten, E-88) | `N-18-G2_a.png`, `N-18-G2_b.png` | | |
| N-19 | G1 | Termin `Ntf Beendet` (Beginn in 7 Minuten, Vorlauf 5), speichern; App **beenden**: `xcrun simctl terminate <UDID> de.inneso.familynexus`; Zustand prüfen: `xcrun simctl spawn <UDID> launchctl list \| grep -i familynexus` (kein Prozess, Ausgabe nach `logs/N-19.txt`); **App nicht öffnen**, Home-Bildschirm zeigen, warten | **Erwartet bei iOS (E-15, OS-geplant): Meldung „Erinnerung“ / „Termin in 5 Minuten“ erscheint trotz beendeter App** zur Zeit (±60 s), ohne Titel. Bleibt sie aus, ist das ein **Befund gegen E-15** (❌ mit Beleg, nicht still ⚠️) | `N-19-G1_a.png` (Prozess beendet), `N-19-G1_b.png` (Meldung), `logs/N-19.txt` | | |
| N-21 | G2 | Termin `Ntf Beendet` (Beginn in 7 Minuten, Vorlauf 5), speichern; App mit **Cmd+Q** beenden (`pgrep -fl "FamilyNexus"` leer, Ausgabe `logs/N-21.txt`), warten | **Erwartet auf macOS (E-15): Meldung erscheint auch bei beendeter App**, ohne Titel. Bleibt sie aus (z. B. wegen ad hoc Signatur), als Befund mit Beleg; Ursache (Signatur) im Befund trennen von Funktion | `N-21-G2_a.png` (kein Prozess), `N-21-G2_b.png` (Meldung), `logs/N-21.txt` | | |
| N-22 | G2 | Variante Fenster **schließen** (roter Punkt, App läuft weiter, Dock-Punkt) mit eigenem Termin `Ntf Fenster zu` (Beginn in 7 Minuten, Vorlauf 5); `pgrep` zeigt Prozess; warten | Meldung kommt zur Zeit (±60 s); im Bericht festhalten, ob die App beim Schließen des Fensters beendet oder nur versteckt ist (`pgrep`) | `N-22-G2.png`, `logs/N-22.txt` | | |
| N-23 | G1, G2 | **Vorlauf Zur Startzeit bei beendeter App:** je ein Termin `Ntf Start beendet` (Beginn in 4 Minuten, „Zur Startzeit“), App beenden (G1 `simctl terminate`, G2 Cmd+Q), warten | Meldung **„Der Termin beginnt jetzt“** (`reminderBodyNow`), ohne Titel, zur Startzeit (±60 s) | `N-23-G1.png`, `N-23-G2.png` | | |
| N-24 | G1, G2 | Danach beide Apps starten; „Heute“ → Karte „Erinnerungen“ → „Übersicht“; Erinnerungen aus N-17 bis N-23 **bestätigen** („Alle bestätigen“) | Bestätigte Erinnerungen verschwinden samt Meldung aus der Mitteilungszentrale; es kommt **keine** zweite Meldung beim Start für bereits angezeigte Erinnerungen | `N-24-G1.png`, `N-24-G2.png` | | |

### E. Meldung „Neue Nachrichten“ (Teil I: G1 beobachtet, G2 sendet)

Voraussetzung: N-10 (Mitteilungen erlaubt), beide Schalter an. Jeweils vorher Mitteilungszentrale leeren. Die Grundlinie `liveSince` (E-88) verlangt, dass G1 nach dem Start **einen echten Sync** hatte: App 60 s laufen lassen, bevor der Sender sendet.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-25 | G1 | G1 im Vordergrund, aber **nicht im Chat** (Tab „Heute“); G2 sendet im Chat `Ntf Chat 1` | **Eine** Meldung, Titel **„FamilyNexus“**, Text **„Neue Nachrichten“**; **kein** `Ntf Chat 1`, kein Absender („Test N1“/„Test Nutzer 2“), kein Gesprächsname; Sekunden bis zur Meldung notieren (Soll: wenige Sekunden nach Sync) | `N-25-G1.png` | | |
| N-26 | G1 | G2 sendet `Ntf Chat 2`; Mitteilungszentrale von G1 ansehen | **Weiterhin eine einzige Meldung „Neue Nachrichten“** (ersetzt, nicht zwei gestapelt, feste ID 1); höchstens alle 30 s ein neuer Ton, dazwischen still ersetzt | `N-26-G1.png` | | |
| N-27 | G1 | Tab **„Chat“** öffnen (Gespräch der Familie sichtbar; bei bestehenden Einzelchats beginnt der Tab mit der Gesprächsliste: zuerst die Zeile „Familienchat …“ öffnen, die Liste allein zählt nicht als sichtbarer Chat, E-100) | Die Chat-Meldung verschwindet aus der Mitteilungszentrale; die Linie „Neue Nachrichten“ steht über `Ntf Chat 1` (E-42); Zahl am Tab-Symbol 0 | `N-27-G1.png` | | |
| N-28 | G1 | **Gespräch bleibt offen und sichtbar** (nicht nur die Gesprächsliste, E-100); G2 sendet `Ntf Chat 3` | **Keine** Meldung (Gespräch sichtbar = gelesen); Nachricht erscheint im Chat; Mitteilungszentrale ohne Eintrag (Screenshot nach 15 s) | `N-28-G1.png` | | |
| N-29 | G1 | Von Chat auf „Heute“ wechseln; G2 sendet `Ntf Chat 4` | Meldung „Neue Nachrichten“ erscheint wieder (Chat nicht mehr sichtbar) | `N-29-G1.png` | | |
| N-30 | G1 | G1 selbst sendet im Chat `Ntf Eigen` (zuerst Chat und bei Einzelchats das Gespräch öffnen, senden, zurück zu „Heute“) | Eigene Nachricht erzeugt **keine** Meldung (nach dem Öffnen des Chats in N-30 ist die Meldung aus N-29 weg) | `N-30-G1.png` | | |
| N-31 | G1 | Schalter in Einstellungen: **„Neue Chat-Nachrichten“ aus**; auf „Heute“; G2 sendet `Ntf Chat Aus` | **Keine** Meldung; die Zahl am App-Symbol/Chat-Tab bleibt (Zahl hängt nicht vom Schalter ab, E-88 „Zahl in der App bleibt“; Ergebnis genau notieren) | `N-31-G1.png` | | |
| N-32 | G1 | Schalter wieder **an**; G2 sendet `Ntf Chat An` | Meldung kommt wieder (nur Neues nach dem Einschalten; `Ntf Chat Aus` löst nachträglich keine Meldung aus) | `N-32-G1.png` | | |
| N-33 | G1 | Gesperrte Variante entfällt (kein Gerätecode im Simulator); stattdessen Datenschutzprüfung der Meldung: Mitteilungszentrale öffnen, Meldung antippen (Tipp öffnet nur die App, kein bestimmtes Gespräch) | Tipp öffnet die App auf dem zuletzt genutzten Tab, **kein** Sprung in ein Gespräch; die Meldung verschwindet nicht durch den Tipp allein, sondern erst beim Öffnen des Chats (so festhalten, was geschieht) | `N-33-G1_a.png`, `N-33-G1_b.png` | | |
| N-34 | G1 | Meldungs-Eigenschaften im System: iOS Einstellungen → Mitteilungen → FamilyNexus: Anzeigen, Kennzeichen, Vorschau-Einstellung („Vorschauen“ – bei iOS `private` greift nur bei gesperrtem Gerät) | Eintrag vorhanden; Hinweis im Bericht: `private` auf dem Sperrbildschirm im Simulator nicht prüfbar (⏳ siehe N-76) | `N-34-G1.png` | | |
| N-82 | G1, G2 | **Gesprächsliste, Zurück und Meldungen (#423, E-100; nur mit bestehendem Einzelchat, sonst n/a):** G1 im Chat-Tab, Liste „Gespräche“ stehen lassen; G2 sendet im Familienchat `Ntf Liste 1`. Danach G1 öffnet die Zeile „Familienchat …“, Pfeil „Zurück zu den Gesprächen“ antippen, Liste wieder stehen lassen; G2 sendet `Ntf Liste 2`. **macOS (G2)/Fenster ≥ 1000 pt:** Tab „Kalender“ mit Liste in der Chatspalte, G1 sendet `Ntf Liste 3`. Android-Zurückgeste entfällt hier (Plan nur macOS und iOS-Simulator; siehe Testplan_FamilyNexus E-18c) | Auf der Liste gilt kein Gespräch als sichtbar: bei `Ntf Liste 1`, `Ntf Liste 2` und `Ntf Liste 3` kommt **eine** Meldung „Neue Nachrichten“ ohne Inhalt, die Zeile „Familienchat …“ zeigt die Nachricht als Vorschau und den Zähler, die Zahl am Tab/Symbol steigt, nichts wird als gelesen markiert; im geöffneten Familienchat kommt keine Meldung, und nach dem Öffnen geht die Zahl der Zeile auf 0; nach dem Pfeil zurück zur Liste gilt der Chat wieder als nicht sichtbar | `N-82-G1_a.png` (Liste), `N-82-G1_b.png` (Gespräch), `N-82-G2.png` | | |

### F. Meldung Einkauf (Teil I)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-35 | G1 | G1 auf „Heute“ (nicht im Tab „Einkauf“); G2 legt den Einkaufseintrag `Ntf Milch` an | **Eine** Meldung „FamilyNexus“ / **„Neue Einträge auf dem Einkaufszettel“**, ohne `Ntf Milch`, ohne Absender; Sekunden notieren | `N-35-G1.png` | | |
| N-36 | G1 | G2 legt `Ntf Brot` an; G2 **hakt** danach `Ntf Milch` ab, ändert den Text von `Ntf Brot` auf `Ntf Brot2`, löscht einen Eintrag | Weiterhin **eine** Meldung (ersetzt, feste ID 2); **Abhaken, Ändern, Löschen erzeugen keine** neue Meldung (E-88); Chat- und Einkaufsmeldung sind **zwei getrennte** Einträge, wenn beide Arten anstehen (Reihenfolge Chat nach Einkauf notieren) | `N-36-G1.png` | | |
| N-37 | G1 | Tab **„Einkauf“** öffnen | Einkaufsmeldung verschwindet beim Wechsel auf den Tab | `N-37-G1.png` | | |
| N-38 | G1 | **Tab „Einkauf“ bleibt offen**; G2 legt `Ntf Eier` an | Einkaufsmeldung kommt **trotzdem** (so festgelegt, E-88, keine Sichtbarkeitsprüfung beim Einkauf) und bleibt bis zum nächsten Wechsel auf „Einkauf“ stehen; Abweichung (keine Meldung) = ❌ | `N-38-G1_a.png`, `N-38-G1_b.png` | | |
| N-39 | G1 | Schalter **„Neue Einträge auf dem Einkaufszettel“ aus**, Tab „Heute“; G2 legt `Ntf Aus` an; danach wieder an | Bei aus **keine** Meldung (Eintrag erscheint im Tab); nach dem Einschalten kommt bei Neuem wieder eine | `N-39-G1.png` | | |

### G. Zahl am App-Symbol

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-40 | G1 | **iOS:** G1 mit Freigabe „Kennzeichen“ (N-11); G1 auf „Heute“, G2 sendet nacheinander `Ntf Zahl 1`, `Ntf Zahl 2`; **Home-Bildschirm** fotografieren (Home: `xcrun simctl` kann nicht; Home-Taste im Device Hub) | Am Icon „FamilyNexus“ steht **2** (= ungelesene lesbare Nachrichten, wie am Chat-Tab); Zahl am Chat-Tab in der App identisch | `N-40-G1_a.png` (Home), `N-40-G1_b.png` (Tab) | | |
| N-41 | G2 | **macOS:** G2 mit Fenster minimiert oder auf „Heute“; G1 sendet `Ntf Zahl 1`, `Ntf Zahl 2`; Dock fotografieren (`screencapture -x -R` auf den Dock-Bereich bzw. ganzer Bildschirm) | Am Dock-Symbol der Test-App die Zahl **2** (rot, ohne Berechtigung nutzbar, E-88; bei fehlender Mitteilungsfreigabe dennoch Dock-Zahl, Ergebnis genau notieren) | `N-41-G2.png` | | |
| N-42 | G1, G2 | Chat öffnen und sichtbar lassen (Nachrichten gelesen; bei Einzelchats jedes Gespräch mit Ungelesenem öffnen, die Liste allein markiert nichts) | Die Zahl am Symbol geht auf **0** (Zahl verschwindet), Tab-Zahl ebenfalls 0 | `N-42-G1.png`, `N-42-G2.png` | | |
| N-43 | G1 | Zahl **ohne** Freigabe „Kennzeichen“: Freigabe in iOS-Einstellungen ausschalten, G2 sendet `Ntf Zahl 3` bei Chat nicht sichtbar | Keine Zahl am Icon; in der App Zahl am Chat-Tab sichtbar; Hinweis `settingsActivityBadgeApple` in den Einstellungen sichtbar (er steht auch bei erteilter Freigabe, N-08); Freigabe danach wieder an | `N-43-G1_a.png`, `N-43-G1_b.png` | | |
| N-44 | G1, G2 | Zahl bei Mehrfach: G2 bzw. G1 sendet 12 Nachrichten (`Ntf Z01` … `Ntf Z12`) bei nicht sichtbarem Chat, Zahl am Symbol ansehen | Zahl entspricht der Anzahl ungelesener lesbarer Nachrichten (Tab und Symbol gleich; bei ≥ 10 Darstellung des Systems, keine Abschneidung in der App) | `N-44-G1.png`, `N-44-G2.png` | | |
| N-45 | G1, G2 | Zahl und Meldung nach Lesen auf **dem anderen Gerät** (kein Ziel-Test: anderes Konto liest nicht für dasselbe Konto); stattdessen: Zahl ändert sich nicht, wenn die **Einkaufs**-Meldung eintrifft | Einkaufseintrag erhöht die Zahl am Symbol **nicht** (Zahl = nur ungelesene Chat-Nachrichten); Meldung „Neue Einträge auf dem Einkaufszettel“ ändert die Zahl nicht | `N-45-G1.png`, `N-45-G2.png` | | |

### H. Hintergrund und beendete App (Meldungen für Chat und Einkauf)

E-88/#273: Eine Meldung im Hintergrund ist **nicht zugesagt**, bei beendeter App kommt **keine**. Ausbleiben ist **kein Fehler**; der Schritt wird ✅ gewertet, wenn **beobachtet und genau festgehalten** ist, ob und nach wie vielen Sekunden etwas kam, und die App keine Zusage verletzt. Ein Eintreffen ist ebenfalls kein Fehler (Bonus), aber nur ohne Inhalt.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-47 | G1 | G1 in den **Hintergrund** (Home), 20 s warten; G2 sendet `Ntf Hg 1`, `Ntf Hg 2` und legt `Ntf Hg Milch` an; **Messreihe** nach 10 s, 30 s, 60 s und 180 s je ein Bild von Banner/Mitteilungszentrale; Uhrzeit der Sendung und des Eintreffens notieren | **Keine Zusage.** Festhalten: kam eine Meldung (ja/nein), nach wie vielen Sekunden, Wortlaut (nur „Neue Nachrichten“ bzw. „Neue Einträge …“, **eine** je Art, ersetzt). **Simulator friert nicht ein:** Eintreffen belegt nichts für das echte iPhone (⏳ in Abschnitt 12) | `N-47-G1_10s.png`, `_30s`, `_60s`, `_180s` | | |
| N-48 | G1 | Danach App in den Vordergrund holen, Chat öffnen | Nachrichten stehen im Chat; Linie „Neue Nachrichten“ über `Ntf Hg 1`; Chat-Meldung weg. **Beim Zurückholen kann je eine Meldung (Chat, Einkauf) nachträglich kommen**, weil die App nach der Rückkehr synchronisiert und Neues erkennt, solange sie geöffnet ist (Lauf 27, Befund 6; Erwartung gegenüber v01 geändert). Festhalten: ob und nach wie vielen Sekunden, Wortlaut, **eine je Art**, ohne Inhalt. ❌ nur bei Inhalt, Absender oder gestapelten Meldungen; ob das Nachliefern gewollt ist, bleibt gegen E-88/`liveSince` offen (Befund, kein Testfehler) | `N-48-G1.png` | | |
| N-49 | G1 | App **beenden** (`xcrun simctl terminate`), 20 s warten; G2 sendet `Ntf Aus 1` und legt `Ntf Aus Milch` an; 60 s und 180 s fotografieren; danach App starten | **Bei beendeter App keine Meldung** (kein Hintergrundprozess, kein Push); nach dem Start **keine** nachträgliche Meldung für das Verpasste (E-88: „wird nach dem Start nicht gemeldet“); Zahl am Symbol zeigt nach dem Start den Stand (N-40-Regel: ungelesene Nachrichten) | `N-49-G1_a.png` (60 s), `_b` (180 s), `_c` (nach Start) | | |
| N-50 | G2 | Mac: Fenster **minimiert** (App läuft), G1 sendet `Ntf Min 1`, `Ntf Min 2` und legt `Ntf Min Milch` an; Messreihe 10 s, 30 s, 60 s | Auf dem Desktop läuft die App weiter: **eine** Meldung „Neue Nachrichten“ (ersetzt) und **eine** „Neue Einträge auf dem Einkaufszettel“, ohne Inhalt; Sekunden notieren (Soll: wenige Sekunden). Bleiben sie aus, Befund (Desktop läuft Sync weiter, E-88) | `N-50-G2_10s.png`, `_30s`, `_60s` | | |
| N-51 | G2 | Mac: App **ausgeblendet** (Cmd+H) statt minimiert, G1 sendet `Ntf Hide 1`; 30 s | Wie N-50 (App läuft, Meldung kommt); Unterschied minimiert/ausgeblendet im Beobachtungsfeld notieren | `N-51-G2.png` | | |
| N-52 | G2 | Mac: App mit **Cmd+Q beenden**, G1 sendet `Ntf Q 1` und legt `Ntf Q Milch` an; 60 s und 180 s fotografieren; danach App starten | **Keine Meldung bei beendeter App**; nach dem Start keine nachträgliche Meldung; Dock-Zahl zeigt nach dem Start den Stand der ungelesenen Nachrichten. Kommt dennoch eine Meldung bei beendeter App: **Befund** (widerspräche E-88 und dem Hinweistext), mit Beleg | `N-52-G2_a.png`, `_b`, `_c` | | |

### I. Teil II: G2 (Mac) beobachtet, G1 (iPhone) sendet

Rollen getauscht, Voraussetzung N-10 für G2. Wiederholung der Kernschritte mit Mac als Beobachter.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-53 | G2 | G2 im Vordergrund, Fenster im Tab „Heute“ (nicht im Chat), Fensterbreite unter 1000 pt (Chat nicht neben dem Kalender); G1 sendet `Ntf M-Chat 1` | **Eine** Meldung „FamilyNexus“ / „Neue Nachrichten“, ohne Inhalt und Absender | `N-53-G2.png` | | |
| N-54 | G2 | G1 sendet `Ntf M-Chat 2` | Weiterhin **eine** Meldung (ersetzt) | `N-54-G2.png` | | |
| N-55 | G2 | Chat auf G2 öffnen | Meldung verschwindet, Dock-Zahl 0 | `N-55-G2.png` | | |
| N-56 | G2 | **Chat offen** (Tab Chat bzw. Fenster ≥ 1000 pt, wo Kalender und Chat zugleich sichtbar sind, E-88 „expanded“; bei Einzelchats mit **geöffnetem Gespräch**, nicht nur der Liste); G1 sendet `Ntf M-Chat 3` | Bei Tab Chat bzw. expanded **keine** Meldung; bei Fenster 600 bis 1000 pt auf Tab „Heute“ kommt eine (Breite im Beobachtungsfeld notieren) | `N-56-G2_a.png` (Chat sichtbar), `N-56-G2_b.png` | | |
| N-57 | G2 | G1 legt `Ntf M-Milch` an | **Eine** Meldung „Neue Einträge auf dem Einkaufszettel“, ohne `Ntf M-Milch` | `N-57-G2.png` | | |
| N-58 | G2 | Tab **„Einkauf“** offen (Navigation links bei ≥ 600 pt), G1 legt `Ntf M-Eier` an | Meldung kommt trotzdem (E-88), bleibt bis zum nächsten Wechsel auf „Einkauf“ | `N-58-G2.png` | | |
| N-59 | G2 | G2 **minimiert**, G1 sendet `Ntf M-Min`; Dock-Zahl und Meldung ansehen | Wie N-50, Dock-Zahl = ungelesene Nachrichten | `N-59-G2.png` | | |
| N-60 | G2 | Erinnerung auf G2 bei Meldungen gleichzeitig: Termin `Ntf M-Termin` (Beginn in 7 Minuten, Vorlauf 5) anlegen, bis zur Fälligkeit warten, währenddessen G1 senden | Erinnerung („Erinnerung“ / „Termin in 5 Minuten“) und „Neue Nachrichten“ sind **getrennte** Meldungen; die Erinnerung ersetzt die Chat-Meldung nicht und umgekehrt (IDs 1 und 2 reserviert, E-15 Nachtrag) | `N-60-G2.png` | | |
| N-62 | G2 | Mitteilungszentrale (Mac) komplett ansehen: alle Meldungen des Laufs | Alle Texte sind generisch („Erinnerung“, „Termin in …“, „Der Termin beginnt jetzt“, „Neue Nachrichten“, „Neue Einträge auf dem Einkaufszettel“); **keine** Titel, Orte, Notizen, Absender, Gespräche, `Ntf …`-Texte | `N-62-G2.png` | | |

### J. Grenzfälle: Schalter und Berechtigung

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-63 | G1 | **Berechtigung verweigert:** iOS-App neu installieren (Freigaben zurücksetzen), App starten, bei „Erlauben“ im Systemdialog **„Nicht erlauben“** wählen | Karte „Berechtigung fehlt“ mit „Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.“ bzw. Text der Geräteeinstellungen; keine Meldung bei Test `Ntf Verweigert` (G2 sendet bei Chat nicht sichtbar); Termin-Erinnerung kommt nicht; die App bleibt benutzbar, Zahl in der App bleibt | `N-63-G1_a.png` (Dialog), `_b` (Karte), `_c` (keine Meldung) | | |
| N-64 | G1 | Nach N-63 „**Einstellungen öffnen**“ antippen (`remindersOpenSettings`), in den iOS-Einstellungen Mitteilungen erlauben, zurück in die App | Karte verschwindet nach der Rückkehr (kein Neustart nötig, #57); danach kommen Meldungen wieder | `N-64-G1_a.png`, `_b` | | |
| N-65 | G2 | **Mac verweigert:** Systemeinstellungen → Mitteilungen → Test-App **ausschalten**; App neu starten; G1 sendet `Ntf Verweigert M`, Termin-Erinnerung in 7 Minuten | Karte „Berechtigung fehlt“ mit „Benachrichtigungen sind in den Geräteeinstellungen ausgeschaltet. Erlaube sie dort für FamilyNexus, sonst erscheinen keine Erinnerungen.“ und „Einstellungen öffnen“; keine Meldung, keine Erinnerung; Dock-Zahl für ungelesene Nachrichten: Ergebnis genau notieren (E-88: „Zahl in der App bleibt“, Dock ohne Berechtigung); danach wieder erlauben | `N-65-G2_a.png`, `_b`, `_c` | | |
| N-66 | G1, G2 | **Schalter Chat aus**, Schalter Einkauf an: G2 bzw. G1 sendet Chat und Einkauf | Nur die Einkaufsmeldung kommt, Chat nicht; der Zustand bleibt nach App-Neustart erhalten | `N-66-G1.png`, `N-66-G2.png` | | |
| N-67 | G1, G2 | **Beide Schalter aus**: Chat und Einkauf senden; **Termin-Erinnerung** (7/5) anlegen | Weder Chat- noch Einkaufsmeldung; die **Erinnerung kommt trotzdem** (die beiden Schalter betreffen nur Meldungen zu Chat und Einkauf, nicht Erinnerungen; Ergebnis notieren); danach beide Schalter wieder an | `N-67-G1.png`, `N-67-G2.png` | | |
| N-68 | G1, G2 | **Einschalten fragt nur die Benachrichtigungsberechtigung an** (E-88: `requestNotifications`): bei verweigerter Freigabe (N-63) einen Schalter aus und wieder an | Es erscheint nur der Systemdialog bzw. Hinweis auf Geräteeinstellungen, **keine** Frage nach genauen Alarmen (nicht iOS/macOS) | `N-68-G1.png`, `N-68-G2.png` | | |
| N-69 | G1, G2 | **Sprache:** Gerätesprache auf Englisch stellen (iOS: `xcrun simctl spawn <UDID> defaults write …` bzw. Einstellungen; Mac: Test-App mit `-AppleLanguages '(en)'` starten), Chat-, Einkaufs- und Erinnerungsmeldung auslösen | Texte englisch: „Reminder“ / „Event in 5 minutes“, „The event starts now“, „New messages“, „New items on the shopping list“, **keine** deutschen Reste | `N-69-G1.png`, `N-69-G2.png` | | |

### K. Abmelden räumt auf

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-71 | G1, G2 | Vor dem Abmelden: Chat-Meldung, Einkaufsmeldung (beide stehen in der Mitteilungszentrale), geplante Erinnerung (Termin in 20 Minuten, Vorlauf 5) und Zahl am Symbol ≥ 1 herstellen, Zustand fotografieren | Zustand dokumentiert: zwei Meldungen, Zahl ≥ 1, eine geplante Erinnerung | `N-71-G1.png`, `N-71-G2.png` | | |
| N-72 | G1, G2 | Einstellungen → **„Abmelden“** (`logout`, bestätigen) | Anmeldeseite; **alle** Meldungen der App sind aus der Mitteilungszentrale entfernt, die **Zahl am Symbol ist 0**; geplante Erinnerungen sind gelöscht (E-15, `closeCalendar(cancelReminders: true)`) | `N-72-G1_a.png`, `_b` (Mitteilungen, Icon), `N-72-G2_a.png`, `_b` | | |
| N-73 | G1, G2 | Zeit bis nach der Fälligkeit der Erinnerung aus N-71 warten (Termin in 20 Minuten, Vorlauf 5 → 15 Minuten) | **Keine** Erinnerung nach dem Abmelden (nichts geplant, keine Geisterbenachrichtigung); Beleg per Screenshot der Mitteilungszentrale | `N-73-G1.png`, `N-73-G2.png` | | |
| N-74 | G1, G2 | Wieder anmelden (gleiches Konto); G2/G1 sendet eine Nachricht bei nicht sichtbarem Chat | Es kommen **keine** Meldungen für Vergangenes aus der Zeit vor der Anmeldung (Grundlinie `liveSince` setzt zurück, E-88 Regel 1); Neues nach dem ersten echten Sync wird gemeldet; die geplanten Erinnerungen sind neu geplant (Übersicht „Geplant (n)“) | `N-74-G1.png`, `N-74-G2.png` | | |

### L. Datenschutz und Texte

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-75 | G1, G2 | Alle in den Teilen C bis K erzeugten Meldungstexte aus den Screenshots der Mitteilungszentrale zusammenstellen (Tabelle im Bericht), je Meldung Titel und Text; Suche in `logs/` und Screenshot-Beschreibungen nach `Ntf Geheim`, `Ntf Geheimort`, `Ntf Geheimnotiz`, Absendernamen, Gesprächsname | Kein Meldungstext enthält Titel, Ort, Notiz, Absender, Gespräch oder Inhalt; nur die Texte aus Abschnitt 4 | `N-75-G1.png`, `N-75-G2.png` (Zentrale, gesamt) | | |
| N-76 | G1 | **Sperrbildschirm** (iOS `private`): im Simulator nicht prüfbar (kein Gerätecode, Sperre mit Cmd+L zeigt Vorschau möglicherweise ohne Schutzlogik) | **⏳ nicht prüfbar**, mit Grund und Verweis auf Abschnitt 12; ein Eindruck vom Sperrbildschirm (Cmd+L im Simulator) wird als Screenshot beigelegt, aber **nicht** als Beleg gewertet; im Code belegt: Sichtbarkeit `private` bei Erinnerungen und Meldungen (E-15, E-88) | `N-76-G1.png` (Eindruck) | | |
| N-78 | G1, G2 | Verhalten gegen Aussage der Texte abgleichen: Alle Beobachtungen aus N-19, N-21, N-22 (Erinnerung bei beendeter App) und N-47 bis N-52 (Meldungen) in einer Tabelle gegen `settingsActivityHint` und `privacy5Body` (nur die Aussagen zu Meldungen; auf macOS zusätzlich `privacy6DesktopNote`) | Kein Text sagt mehr zu, als beobachtet wurde: Meldungen zu Chat und Einkauf nur bei geöffneter App; Erinnerungen bei beendeter App kommen auf iOS und macOS (Text nennt nur „Termin in …“, sagt zu beendeten Apps nichts) → Übereinstimmung oder Befund mit Beleg | Tabelle im Bericht (`Testreport.md`) | | |

### M. Aufräumen

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| N-79 | G1 | Eigene Testtermine (`Ntf …`) und Einkaufseinträge löschen, App abmelden; Simulator zurücksetzen: `xcrun simctl uninstall <UDID> de.inneso.familynexus`, `xcrun simctl privacy <UDID> reset all de.inneso.familynexus`, `xcrun simctl keychain <UDID> reset` (nur Simulator), Spracheinstellung zurück | Simulator ohne Reste; Mitteilungszentrale leer | `N-79-G1.png` | | |
| N-80 | G2 | Mac: Testtermine löschen, abmelden; **keine** Löschung lokaler Daten, **kein** Eingriff in den Schlüsselbund der Nutzer-App; Mitteilungsfreigabe der Test-App auf den Ausgangszustand (N-04) zurück; Test-App beenden; `caffeinate`-Prozesse beenden (`pkill caffeinate`) | Test-App beendet, Nutzer-App unverändert (`/Applications/FamilyNexus.app` nicht gestartet, Version unverändert) | `N-80-G2.png`, `logs/N-80.txt` | | |
| N-81 | – | Testkonten `fnt-MMTT-n1`, `fnt-MMTT-i2`: in der App löschen (Einstellungen → Konto löschen, mit Passwort), Zugangsdatei außerhalb des Repos löschen, Arbeitsbaum prüfen (`git status`: nur fremde Änderungen des Nutzers, keine Testartefakte); **nichts vom Nutzer löschen** (Ordner `Apple-Feedback/`, `Sprint/`, andere Berichte unberührt) | Konten gelöscht (Server meldet `M_USER_IN_USE` für die Namen bleibt), keine Geheimnisse im Repo (`grep -r` im Berichtsordner nach Passwort/Notfall-Schlüssel leer), Berichtsordner enthält nur geschwärzte Belege | `logs/N-81.txt` | | |

## 7. Abdeckungsmatrix

| Funktion | Schritte |
|---|---|
| Erinnerung bei laufender App (Vordergrund) | N-13, N-14, N-15, N-16 |
| Erinnerung im Hintergrund | N-17, N-18 |
| Erinnerung bei beendeter App (E-15, #381 Teil 1) | N-19, N-21, N-22, N-23, N-24 |
| Erinnerung und Meldung gleichzeitig getrennt | N-60 |
| Meldung „Neue Nachrichten“ ohne Inhalt | N-25, N-26, N-53, N-54, N-62 |
| Keine Meldung bei sichtbarem Chat | N-28, N-30, N-56 |
| Gesprächsliste gilt nicht als sichtbarer Chat (E-100) | N-82 |
| Ersetzt statt gestapelt | N-26, N-36, N-54 |
| Meldung „Neue Einträge auf dem Einkaufszettel“ | N-35, N-36, N-57 |
| Tab „Einkauf“ offen (Meldung trotzdem) | N-38, N-58 |
| Abhaken, Ändern, Löschen melden nichts | N-36 |
| Hintergrund und beendete App (E-88/#273, Sekunden) | N-47 bis N-52, N-59 |
| Zahl am App-Symbol iOS (Kennzeichen) | N-11, N-40, N-43, N-44, N-45 |
| Dock-Zahl macOS | N-12, N-41, N-44, N-55 |
| Zurücksetzen beim Lesen | N-27, N-42, N-55 |
| Zurücksetzen beim Abmelden | N-72, N-73, N-74 |
| Einstellungen „Benachrichtigungen“, Hinweistext, Schalter | N-06, N-07, N-08, N-31, N-32, N-39, N-66, N-67 |
| Berechtigungsabfrage und Karte „Berechtigung fehlt“ | N-09, N-10, N-63, N-64, N-65, N-68 |
| Datenschutz Meldungstexte (kein Titel, Ort, Notiz, Absender, Inhalt) | N-14, N-25, N-35, N-62, N-75, N-76 (⏳) |
| Aussage der Hinweistexte gegen Verhalten (`settingsActivityHint`, `privacy5Body`) | N-07, N-78 |
| Sprache (en) | N-07, N-69 |

## 8. Grenzfälle (Übersicht)

Berechtigung verweigert (N-63, N-65), Berechtigung nachträglich erteilen (N-64), Schalter aus (N-31, N-39, N-66, N-67), App im Vordergrund im Chat (N-28, N-56), zweite Meldung ersetzt die erste (N-26, N-36, N-54), Tab „Einkauf“ offen (N-38, N-58), App beendet (N-19, N-21, N-49, N-52), Abmelden räumt Meldungen, Zahl und Erinnerungen (N-72 bis N-74), **Mac: Fenster minimiert (N-18, N-50, N-59) gegenüber ausgeblendet (N-51), Fenster geschlossen (N-22) und App beendet (N-21, N-52)**, Fensterbreite und Layout (N-56), eigene Nachricht (N-30), Sprache en (N-69), Zahl ≥ 10 (N-44), Einkaufsmeldung ohne Zahländerung (N-45).

## 9. Abnahmekriterien

Der Lauf gilt als **bestanden**, wenn:
1. Alle Pflichtschritte `N-01` bis `N-05`, `N-06` bis `N-10`, `N-13` bis `N-16`, `N-19`, `N-21`, `N-25` bis `N-28`, `N-35` bis `N-38`, `N-41`, `N-42`, `N-47`, `N-49`, `N-50`, `N-52`, `N-72` bis `N-75`, `N-78` ✅ oder ⚠️ mit eingetragenem Befund sind; ❌ in diesen Schritten nur dann, wenn der Befund mit Beleg als Befund (nicht als Testfehler) eingetragen ist und der Verantwortliche entscheidet.
2. **Datenschutz hart:** In keinem Screenshot einer Meldung steht Titel, Ort, Notiz, Absender, Gespräch oder Inhalt (N-14, N-25, N-35, N-62, N-75). Jede Abweichung ist ❌ und blockiert die Abnahme.
3. **Ersetzen:** Chat- und Einkaufsmeldung stapeln sich nie (N-26, N-36, N-54).
4. **Erinnerung bei beendeter App** auf iOS-Simulator und macOS ist mit Ja/Nein und Sekunden belegt (N-19, N-21). Ist die Antwort „Nein“, ist das ein Befund gegen E-15 und #381 Teil 1 (mit Belegen, Signatur trennen).
5. **Hintergrund und beendete App** (N-47 bis N-52): Ergebnis mit Sekunden dokumentiert; das Ausbleiben im Hintergrund oder bei beendeter App ist ausdrücklich **kein Fehler** (E-88/#273); eine Meldung bei beendeter App wäre ein Befund.
6. Zahl am App-Symbol erreicht 0 beim Lesen (N-42) und beim Abmelden (N-72).
7. Meldungs- und Hinweistexte stimmen mit `app_de.arb`/`app_en.arb` wörtlich überein (N-07, N-69, N-75).
8. Nicht ausführbare Schritte sind ⏳ mit Grund, nie ✅. Der Bericht nennt die Grenzen des Simulators (Abschnitt 1) und führt N-76 als ⏳.
9. Nach CLAUDE.md gilt: Ein Issue wird nur geschlossen, wenn der Test die Abnahme wirklich belegt. Der Simulator belegt **nicht** das Verhalten auf einem echten iPhone; #381 bleibt offen bzw. der PR nutzt `Refs #381`, bis der Gerätenachtest (Abschnitt 12) erledigt ist.

## 10. Hinweise zur Bedienung (Technik)

- **iOS-Simulator (G1):** Screenshots `xcrun simctl io <UDID> screenshot <Datei>`; Beenden `xcrun simctl terminate <UDID> de.inneso.familynexus`; Start `xcrun simctl launch <UDID> de.inneso.familynexus`; Bedienung im Device Hub per `osascript`/`cliclick` auf die Fensterkoordinaten (Fenster fest platzieren, Skalierung des Bildes beachten); Texte per Zwischenablage `xcrun simctl pbcopy <UDID>`; Home per Cmd+Shift+H im Simulator-Fenster. Bannern Zeit geben: Banner bleiben ca. 5 s sichtbar, Screenshot sofort nach `date +%T`; Mitteilungszentrale: im Device Hub von oben wischen. **Hinweis zu Tippfehlern:** Großbuchstaben gehen beim Tippen per Tastenereignis teils verloren, Namen per Zwischenablage einfügen; die Texte der Plantermine bewusst einfach halten.
- **macOS (G2):** Fenster der Test-App fest auf 800 × 800 bei {445,30} stellen (aus Lauf 26); breitere Fenster für N-56 (≥ 1000 pt) gesondert; Screenshots `screencapture -x -R445,30,800,800 <Datei>`; Mitteilungszentrale: Klick auf die Uhr oben rechts bzw. Bildschirm komplett `screencapture -x`; Dock: `screencapture -x` (ganzer Bildschirm, Dock sichtbar oder per `defaults` nicht ausblenden). Test-App starten `open -a <Pfad zur Test-App>`; beenden `osascript -e 'tell application id "de.inneso.familynexus.e2e" to quit'`; Prozess prüfen `pgrep -fl "FamilyNexus"`. Bedienung nur im Fenster der Test-App, **nie** in Fenstern des Nutzers.
- **Zeitmessung:** Vor jeder Sendung `date +%T` ausgeben und festhalten, danach beim Eintreffen der Meldung wieder; beides in `logs/N-xx.txt`.
- **Vorlauf-Werte:** Vorgegeben `0, 5, 10, 15, 30, 60, 120, 1440, 2880` Minuten; Standard der App `defaultReminderMinutes` (Einstellungen → „Erinnerungen“ → „Standard-Erinnerung“); neue Termine übernehmen sie, im Termin-Formular für den Test auf genau eine Auswahl umstellen.

## 11. Aufbau der Wartezeiten (Zeitplan)

Erinnerungsschritte parallel laufen lassen: N-13/N-17/N-19/N-21/N-22/N-23 werden hintereinander angelegt (Terminzeiten gestaffelt um je 1 bis 2 Minuten, jede mit eigenem Titel), dann G1 und G2 gleichzeitig beobachten. Gesamtdauer des Laufs: 2 bis 3 Stunden. Wartezeiten ≥ 3 Minuten mit `caffeinate` absichern (Abschnitt 2).

## 12. Nicht testbar und offen

| Punkt | Grund | Nachtest |
|---|---|---|
| Echtes iPhone: Meldung im Hintergrund, nach Einfrieren, bei beendeter App (Chat, Einkauf, Erinnerung) | Simulator friert die App nicht wie iOS ein; kein Energiesparen | Gerätetest auf echtem iPhone (iOS 15 und 16+); Checkliste `Checkliste_Geraetenachtests.md` (#254, #381) |
| Sperrbildschirm: Sichtbarkeit `private`, Vorschau | Simulator ohne Gerätecode | iPhone mit Gerätecode; Meldung bei gesperrtem Gerät fotografieren (Foto, Schwärzung) |
| Kennzeichen/Zahl am Icon auf Gerät, iOS 15 (`applicationIconBadgeNumber`) | Simulator iOS 27 | iPhone mit iOS 15 bzw. 16, nachträgliche Freigabe |
| macOS signiert (Distribution/TestFlight): Systemdialog „Mitteilungen erlauben“ | Test-Build ist ad hoc signiert | TestFlight-Build auf dem Mac (Gesamtplan B-02) |
| Mac im Ruhezustand/Bildschirm gesperrt: Erinnerung | nicht automatisierbar | manueller Test am Mac (Bildschirm sperren, Erinnerung abwarten) |
| Android (alle Punkte, #273), Linux, Windows | nicht Gegenstand dieses Plans | eigener Plan bzw. Checkliste |
| Push (APNs/FCM/UnifiedPush) | nicht umgesetzt, #381 Option B/B1/C offen | erst nach Entscheidung des Eigentümers |
| Meldung nach Neustart des Mac/iPhone (OS-geplante Erinnerung) | Simulator-Neustart nicht gleichwertig | Gerät: Neustart nach Terminanlage, Erinnerung abwarten |

## 13. Vorlagen für den Bericht

Ordner: `User E2E Test Report/<JJJJ-MM-TT>_<NN>_iOS-macOS-Simulator_Build<NN>/` mit `Ergebnisse.tsv`, `Befunde.md`, `Testreport.md`, `screenshots/`, `logs/`, optional `STATE.md` (Fortschritt, Konten ohne Geheimnisse, Hilfsskripte wie in Lauf 26). Nach dem Lauf Zeile in `User E2E Test Report/README.md` ergänzen.

**`Ergebnisse.tsv`** (Tabulatoren, eine Zeile je Schritt und Gerät, Kopfzeile wie in Lauf 26):

```
ID	Gerät	Schritt	Erwartet	Beobachtet	Screenshot	Wertung
N-01	-	Soll-Version ermitteln	Soll-Version und Commit stehen fest	main = origin/main = <Commit>, pubspec 1.2.3+<NN>	logs/N-01.txt	✅
N-14	G1	Erinnerung bei laufender App (Vordergrund)	Meldung "Erinnerung" / "Termin in 5 Minuten" ohne Titel	Banner um hh:mm:ss (Soll hh:mm:ss, +NN s), Text "Termin in 5 Minuten", kein Titel/Ort/Notiz	N-14-G1_a.png, N-14-G1_b.png	✅
N-19	G1	Erinnerung bei beendeter App	Meldung erscheint trotz beendeter App	Prozess beendet (logs/N-19.txt), Meldung um hh:mm:ss (+NN s) / Meldung blieb aus bis hh:mm:ss	N-19-G1_a.png, N-19-G1_b.png	✅/❌
N-47	G1	Hintergrund, Meldungen	nicht zugesagt; Ergebnis mit Sekunden	Chat: Meldung nach NN s / keine bis 180 s; Einkauf: nach NN s / keine	N-47-G1_10s.png ...	✅
N-76	G1	Sperrbildschirm (private)	nicht prüfbar im Simulator	Simulator ohne Gerätecode	N-76-G1.png (Eindruck)	⏳
```

**`Befunde.md`** (Tabelle, Nummern ab 1, Schwere: hoch/mittel/niedrig/Hinweis/Hinweis Testumgebung/Hinweis Werkzeug):

```
# Befunde Lauf <JJJJ-MM-TT>_<NN> (G1 = iPhone-18-Pro-Simulator, G2 = macOS), Plan TP-FN-NTF-381 v01 @ <Commit>

| Nr. | Schwere | Schritt | Befund | Issue |
|---|---|---|---|---|
| 1 | Hinweis (Testumgebung) | N-10 | Mac-Test-App ad hoc signiert: Systemdialog erschien nicht, Weg über „Einstellungen öffnen“ | #381 / B-02 |
| 2 | mittel | N-21 | Erinnerung bei beendeter App kam auf macOS nicht (Beleg N-21-G2_*.png) | #381 |
```

**`Testreport.md`**: Kopf (Plan, Commit, Build, Geräte, Datum), Zusammenfassung mit Zählung ✅/⚠️/❌/⏳/n/a, **Tabelle „Erinnerung bei beendeter App“** (iOS, macOS: Ja/Nein, Sekunden), **Tabelle „Meldungen im Hintergrund und bei beendeter App“** (Gerät, Zustand, Chat ja/nein und Sekunden, Einkauf ja/nein und Sekunden), Zusammenstellung der Meldungstexte (N-75), Befundliste, Grenzen des Simulators, offene Nachtests (Abschnitt 12), Aufräumstand. Keine Geheimnisse, Zugangsdaten und Schlüssel geschwärzt.

## Versionshistorie

| Version | Datum | Änderung |
|---|---|---|
| v03 | 13.11.2026 | Gesprächsliste im Chat-Tab (#423, E-100): „sichtbarer Chat“ heißt bei mehreren Gesprächen „Gespräch geöffnet“, die Liste allein ist nicht sichtbar und markiert nichts als gelesen; Hinweise in N-27, N-28, N-30, N-42, N-56; neuer Schritt N-82 |
| v02 | 12.11.2026 | Beschränkung auf Benachrichtigungen: entfallen N-20 (Neustart-Gegenprobe Übersicht), N-46 (App-Sperre), N-61 (Reaktionen), N-70 (Familienwechsel), N-77 (Datenschutzerklärung als Ganzes); N-15 und N-24 auf das Verschwinden der Meldung reduziert. Korrekturen aus Lauf 27: N-48 (nachträgliche Meldung nach Rückkehr erlaubt, festhalten), N-08/N-11/N-43 (Badge-Hinweis steht immer), 3.2/3.4/N-09/N-10/N-63 (Simulator behält Freigabe, neuer Wegwerf-Simulator), Ersatzsender, Schlüsselbund-Abfrage am Mac als Voraussetzung, Terminzeiten per Zifferblatt, Servername. Schrittnummern unverändert |
| v01 | 12.11.2026 | Erstfassung; Bezug #381, E-15, E-88 (mit Korrektur #273), `privacy5Body`, `settingsActivityHint`; Basis `main` @ `778b949` |
