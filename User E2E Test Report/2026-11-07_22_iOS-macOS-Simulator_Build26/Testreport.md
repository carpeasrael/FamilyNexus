# Testreport: Lauf 22, Apple-Nachtests (iPhone-Simulator, macOS nur Teilbeleg), Build 26

Nachtest der offenen Apple-Punkte aus `User E2E Test/Checkliste_Geraetenachtests.md` (#144, #254, #266, #268, #274, #297) auf Stand `main` @ `c9c300d`. Einzelergebnisse: `Ergebnisse.tsv` (37 Zeilen, Gruppen wie `A-41..A-45` stehen in einer Zeile), Belege: `screenshots/` (42 Bilder, auf höchstens 1100 Pixel Höhe verkleinert), `logs/`. Plan: `Testplan-Agent` (getrennt), Ausführung: `Tester-Agent` (getrennt, ohne Codeänderung), Auswertung durch den Auftraggeber.

**Kurzfassung:** Auf dem **iPhone-Simulator** laufen Meldungen, Abzeichen und Sichtschutz-Hinweis wie in E-88 beschrieben. Die **macOS-App ließ sich in diesem Lauf nicht benutzen** (Schlüsselbund-Abfrage beim ad hoc signierten Debug-Build); alle macOS-Oberflächenschritte sind **nicht getestet**. **Kein Issue ist damit abgenommen**: Es fehlt jeweils das echte Gerät (iPhone) bzw. ein signierter Mac-Build.

## 1. Festlegung

| Angabe | iPhone-Simulator (G1) | macOS |
|---|---|---|
| Gerät | iPhone 17, Simulator-ID `DE6993AE-FDD8-4E34-BA06-F72462B51ACB` | dieser Mac (Host macOS 27.2, Xcode 27.2) |
| Betriebssystem | iOS **26.4** (laut Tester; nicht 27.x wie im Plan) | macOS 27.2 |
| Installationsquelle | `flutter build ios --simulator --debug` auf `c9c300d` (1.2.2 (26)) | `flutter build macos --debug` auf `c9c300d`, **Bundle-ID `de.inneso.familynexus.e2e`** (siehe Abweichung 1) |
| App-Version Soll / Ist | 1.2.2 (26) / 1.2.2 (26) | 1.2.2 (26) / 1.2.2 (26) |
| Server | Testserver `matrix-synapse-3ues.srv1348446.hstgr.cloud` (Matrix-ID-Servername `matrix.chaostribunal.de`), Wegwerfkonten vom Nutzer freigegeben, **kein matrix.org** | – |
| Konten | `fnt-1107-n1` (App), `fnt-1107-n2` (Zweitgerät als Test-Daemon, siehe Abweichung 3); beide am Ende gelöscht | – |
| Bedienung / Belege | `cliclick`, AppleScript, `xcrun simctl io … screenshot`, `log show` | `screencapture` |
| Datum | 07.11.2026 | |

Passwörter und Notfall-Schlüssel nur in `secure/Lauf_1107_G1.txt` (von Git ignoriert, geprüft mit `git check-ignore`). Im Ergebnisordner stehen sie nicht (Textsuche leer, Stichproben der Bilder ohne Schlüssel).

## 2. Ergebnis (nach `Ergebnisse.tsv`)

| Wertung | Zeilen |
|---|---|
| bestanden (Mac-Werkzeuge V-01..06, A-60) | 2 |
| bestanden, Teilbeleg (A-40) | 1 |
| **Simulator bestanden** | 21 (davon eingeschränkt: A-21, A-32, A-38) |
| teilweise (A-47, A-61) | 2 |
| Beobachtung, nicht als Pass (A-39) | 1 |
| fehlgeschlagen, Umgebung (A-02) | 1 |
| nicht getestet | 9 |

„Simulator bestanden“ ist **nicht** „bestanden“: Der Simulator belegt lokales Verhalten der App, nicht das Gerät (App-Umschalter, Sperrbildschirm, iOS 15).

## 3. Ergebnis je Issue

| Issue | Was belegt ist | Was offen bleibt |
|---|---|---|
| **#254** (E-88, Meldungen und Zahl) | iPhone-Simulator: ohne Berechtigung keine Meldung (A-30); nach „Erlauben“ Banner „FamilyNexus / Neue Nachrichten“ und „Neue Einträge auf dem Einkaufszettel“ ohne Inhalt, Absender und Zahl (A-32, `A-32a`); englisch „New messages“ (A-37); Abzeichen 1 am Symbol, gleich dem Chat-Tab (A-33); nach Lesen weg (A-34); Abhaken, offener Chat, Chat-Schalter aus und beendete App melden nichts (A-35, A-36, A-3B, A-3A); Abmelden setzt Abzeichen auf 0 und entfernt Meldungen (A-3C) | **macOS-Dock** (A-3D, A-3E nicht getestet); **echtes iPhone** (Sperrbildschirm, iOS 15, Freigabe „Kennzeichen“); Hintergrund und Sperre melden nichts (A-38, A-39), das ist #273; gleichzeitige Anzeige je einer Chat- und einer Einkaufsmeldung nicht belegt (Auffälligkeit 1) |
| **#144** (Bildschirmschutz-Text, B-18) | iPhone-Simulator: Hinweis lautet de „Verdeckt die App im App-Umschalter und bei Bildschirmaufnahmen. Einzelne Screenshots lassen sich unter iOS nicht verhindern.“, en „Hides the app in the app switcher and during screen recordings. Individual screenshots cannot be prevented on iOS.“ (A-13, `A-13_iPhone-Sim.png`); Sichtschutz an: Karte im App-Umschalter nur Markenfläche, aus: Inhalt sichtbar (A-15a/b) | **Echtes iPhone**: Bildschirmaufnahme (A-16, nicht belegbar, die Aufnahme im Simulator war 0 Byte); **Windows**; macOS-Schalter nicht geprüft (A-22) |
| **#266** (Apple-Build mit `sqlite3` 3.8.0) | Der iOS-Simulator-Build mit 3.8.0 startet, legt Konto und Familie an, stellt die Sitzung nach Neustart wieder her; `log show` ohne „out of bounds“ (A-01, A-10, A-11) | macOS-Laufzeit (A-02, Umgebung); **Windows** (`sqlcipher.dll`) |
| **#274** (Tablet/Fenster) | nur iPhone: Hochformat und Querformat einspaltig, Leiste unten, Eingabefeld bei Bildschirmtastatur sichtbar (A-46); 200 % Schrift ohne Überlauf nach rechts, aber Wortbruch (Auffälligkeit 2) | macOS-Fenstergrößen 599/600/1000 (A-41..A-45 nicht getestet); iPad (Split View, Slide Over, Stage Manager), Android-Tablet |
| **#268** (In-App-Anmeldung) | Teilbeleg: Der macOS-Release-Build trägt `network.client` und **kein** `network.server` (A-40, `logs/A-40.txt`) | TP-OAUTH-11: Anmeldung und Kontoseiten in der System-Sitzung brauchen einen OAuth-Anbieter; auf dem Testserver nicht möglich, matrix.org ist ohne Freigabe verboten (A-50 nicht getestet) |
| **#297** (iPad-Hinweis) | – | A-51 nicht getestet (gleiche OAuth-Voraussetzung, iPad) |

## 4. Abweichungen vom Plan

1. **macOS-Bundle-ID:** Auf diesem Mac liegen echte Daten (`~/Library/Containers/de.inneso.familynexus`) und `/Applications/FamilyNexus.app`. Der Mac-Build lief deshalb mit `de.inneso.familynexus.e2e` (gleicher Code, eine Zeile in `AppInfo.xcconfig`, nur in einem temporären Worktree). Die echten Daten und die installierte App wurden nicht gestartet, gelesen oder geändert.
2. **macOS nicht benutzbar:** Beim Start fragt der Schlüsselbund nach dem Login-Passwort des Mac-Nutzers (Dienst `flutter_secure_storage_service`). Es wurde nichts erraten; nach „Nicht erlauben“ erscheint „Lokale Daten nicht lesbar“. „Lokale Daten zurücksetzen“ wurde bewusst **nicht** geklickt, weil der Dienstname bei Flutter-Apps gleich ist. Das ist ein Umgebungsproblem des ad hoc signierten Debug-Builds, **kein Befund zur App**. Der Nachtest braucht den signierten TestFlight-Build 26.
3. **Zweitkonto ohne zweites Gerät:** `fnt-1107-n2` lief als Test-Daemon über das echte App-Gateway (`SdkMatrixGateway`, mit Verschlüsselung) und sendete Chat und Einkaufseinträge. Der Beitritt erfolgte per Matrix-API (Einladung, Beitritt), nicht per Einladungslink in der App (A-21 daher nur teilweise). Das ist kein UI-Test eines zweiten Geräts.
4. **Simulator:** Die App heißt auf diesem Mac „Device Hub“; iPhone 17 läuft mit iOS 26.4.

## 5. Auffälligkeiten

| Nr. | Schritt | Befund | Bewertung |
|---|---|---|---|
| 1 | A-32 | Im ersten Anlauf zeigte das Log zwei Chat-Requests mit gleicher ID und einen Einkaufs-Request; sichtbar war nur die Einkaufsmeldung auf dem Sperrbildschirm, ein Chat-Banner nicht. Das Abzeichen war richtig (1, dann 2). Im zweiten Anlauf kam der Banner. | Möglicherweise Timing des Testers (Banner nicht abgefangen). Die Plan-Erwartung „je eine Chat- und eine Einkaufsmeldung nebeneinander“ ist **nicht belegt**. Beim Gerätenachtest gezielt prüfen. |
| 2 | A-47c | Bei 200 % Schrift brechen Wörter mitten im Wort um („Recommendati/on“ in der Familienansicht), Titel werden sehr groß; kein Überlauf nach rechts, Inhalt scrollbar. | Beobachtung zu Barrierefreiheit und #274, kein Fehlschlag. Als Folgeissue erwägen (Entscheidung des Nutzers). |
| 3 | A-39, A-38 | Im Hintergrund (Home, 30 s) und bei gesperrtem Gerät keine Meldung; erst beim Öffnen wird das Abzeichen aktualisiert. | Erwartetes Verhalten laut E-88 (nur bei laufender App), nicht als bestanden gewertet; Hintergrund siehe #273. |
| 4 | A-47 | „Entwurf bleibt beim Drehen“ nicht belegt. | Offen für den Gerätenachtest. |
| 5 | A-10, A-11 | Die Bilder `A-10_iPhone-Sim.png` und `A-11_iPhone-Sim.png` zeigen beide „Heute“ um 00:57; die Kontoanlage ist nur durch das Ergebnis, nicht durch ein eigenes Bild belegt. | Schwacher Beleg, kein Widerspruch. |
| 6 | Werkzeug | Texteingabe per `cliclick` brauchte Umwege (deutsches Mac-Layout: „z“ kam als „y“); Hardware-Tastatur und „Keyboard Capture“ im Simulator waren zeitweise umgeschaltet und sind zurückgesetzt. | Testwerkzeug, kein App-Fehler. |
| 7 | A-13 | `A-13_iPhone-Sim.png` zeigt den lokalen Simulator-Pfad mit Benutzernamen des Mac. | Kein Geheimnis; vor Weitergabe an Dritte schwärzen. |

## 6. Aufräumen

- Konten `fnt-1107-n1` (in der App gelöscht, Dialog zeigt die Anbieter-Adresse, Warnung „einziger Moderator“) und `fnt-1107-n2` (per Matrix-Deactivate-API): Anmeldung beider scheitert mit `M_FORBIDDEN` (`logs/A-60.txt`).
- iPhone-17-Simulator: App deinstalliert, Schriftgröße zurückgesetzt, Gerät noch gebootet. Der bereits laufende iPhone-18-Pro-Max-Simulator wurde nicht angefasst.
- Mac: Test-App beendet. **Rest:** `~/Library/Containers/de.inneso.familynexus.e2e` (entstand in diesem Lauf) lässt sich wegen des Container-Schutzes nicht per `rm` löschen und liegt noch dort; er kann bei Bedarf von Hand entfernt werden (Finder oder `Library/Containers`). Keine Schlüsselbund-Einträge angelegt oder gelöscht.
- Temporärer Worktree und Hilfstest des Testers sind entfernt; im Repo ist nur dieser Ergebnisordner neu.

## 7. Nicht getestet (Nachtest nötig)

- **Echtes iPhone:** App-Umschalter-Sichtschutz am Gerät, Bildschirmaufnahme (`isCaptured`), echter Sperrbildschirm, iOS 15, Freigabe „Kennzeichen“ nachträglich (#144, #254).
- **macOS, signierter Build (TestFlight 26):** Anmeldung ohne Schlüsselbund-Abfrage, Dock-Zahl, Meldungen, Fenstergrößen 599/600/1000 dp, kein Trenner ab 1000 dp (#254, #274, #268, #266).
- **OAuth-Anmeldung** in der System-Sitzung (TP-OAUTH-11, #268, #297): braucht einen OAuth-Anbieter; matrix.org nur mit Freigabe und eigenem Konto.
- iPad (#274), Android-Tablet, Windows, Linux, Web.

Es wurde kein Issue geschlossen; die Ergebnisse stehen als Kommentare in den Issues.
