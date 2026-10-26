# Testplan Einladung und Zusammenspiel zweier Nutzer

Bezug: `Testplan_Pruefanleitung.md` (Abschnitt 0 Testserver; früher TC-09, TC-11, TC-12), Issues #10–#14, Nachtest #15
Build: Soll-Version laut `pubspec.yaml` auf `main` (beim Schreiben **1.2.1 (16)**), Prüfung in TV-01 · Stand: 26.10.2026
Gemeinsame Vorprüfung, Stammdaten und Reihenfolge: **`Testdaten_Stammdaten.md`** (zuerst lesen). Läuft als **letzter** Plan nach Nutzeranlage und Prüfanleitung und verwendet deren Konten und Beispieldaten weiter.

## 1. Ziel

Nachweis, dass zwei Nutzer auf dem Testserver zusammenspielen: Nutzer 1 (= N1 aus den Stammdaten, Familie F1 besteht bereits) lädt per Link ein, Nutzer 2 (= I2, **neu**) legt sein Konto über den Einladungslink in der App an und wird aufgenommen. Konto und Familie von Nutzer 1 werden nicht erneut angelegt; neu getestet wird nur der Weg „Konto über Einladungslink“. Danach Mitgliederliste, Chat, Einzelchat, geteilter Termin, Einkaufsliste, Melden/Blockieren/Aufheben, Moderator-Hinweis bei der Kontolöschung und Löschung beider Konten.

Abgedeckt: Einzelchat (TC-09 alt), Melden/Blockieren/Aufheben (TC-11 alt), Einstiegsweg „Ich wurde eingeladen“ mit Kontoanlage (TC-12 alt; „Neue Familie gründen“ ist in der Nutzeranlage abgedeckt), Notfall-Schlüssel beim über Einladung angelegten Konto (#10), Kontolöschung mit Moderator-Hinweis (#12), Versionsanzeige (#14).

Dokumentationsvorgabe: Im Testbericht sind **bei jedem Zusammenspiel-Schritt beide Bildschirme parallel zu sehen** (links Nutzer 1 auf dem iPhone-15-Simulator, rechts Nutzer 2 auf dem Mac), mit eindeutiger Beschriftung je Schritt.

## 2. Testserver, Nutzer und Geräte

Testserver wie in `Testplan_Pruefanleitung.md`, Abschnitt 0: Anbieter-Adresse `matrix-synapse-3ues.srv1348446.hstgr.cloud`, Matrix-IDs `@<name>:matrix.chaostribunal.de`, Anmeldung mit Passwort in der App, Registrierung offen ohne Zusatzschritt.

| Rolle | Benutzername (wird im Test angelegt) | Gerät / Umgebung | angelegt in | gelöscht in |
|---|---|---|---|---|
| **Nutzer 1** = **N1** (Moderator, lädt ein) | `fnt-MMTT-n1`, Anzeigename „Test N1“, Familie F1 „Testfamilie MMTT“ | **iPhone-15-Simulator**, aktuellster Build (Soll aus TV-01); Anmeldung auf dem Simulator in TI-03 | Nutzeranlage TN-09 | TI-27 |
| **Nutzer 2** = **I2** (wird eingeladen) | `fnt-MMTT-i2`, Anzeigename „Test Nutzer 2“ | **Mac**, aktuellster Build unter `/Applications/FamilyNexus.app` | TI-10 | TI-25 |

`MMTT` = Testdatum. Für N1 gilt der aktuell gültige Notfall-Schlüssel (KN1b, falls Prüfanleitung TC-12 gelaufen ist, sonst KN1). Passwörter und Notfall-Schlüssel erzeugt der Tester beim Anlegen und legt sie im Passwortmanager ab, **nicht** in diesem Plan; im Report maskiert.

## 3. Umgebungen und Nachweisarten

| Kürzel | Umgebung | Nachweis |
|---|---|---|
| **U1** | iPhone-15-Simulator, Nutzer 1 | Bildschirmfoto (`xcrun simctl io booted screenshot`) |
| **U2** | Mac-App, Nutzer 2 | Fensteraufnahme (`screencapture -R`) |
| **P** | Paarbild: U1 und U2 **gleichzeitig** | Beide Aufnahmen innerhalb von höchstens 2 Sekunden, im Report nebeneinander |

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ offen

### Dokumentation der Bildschirme (Pflicht)

- **Dateinamen:** `TI-<Testfall>-<Schritt>-U1.jpg`, `…-U2.jpg` und `…-P.jpg` (Paarbild), abgelegt unter `screenshots/einladung`. Beispiel: `TI-14-02-U1.jpg`.
- **Paarbild:** Links U1 (iPhone 15, 393 × 852 pt), rechts U2 (Mac-Fenster). Jede Hälfte trägt oben „Nutzer 1 · iPhone 15 Simulator“ bzw. „Nutzer 2 · Mac“ und die Uhrzeit der Aufnahme.
- **Bildunterschrift im Report:** Abbildungsnummer · Testfall · Schritt · was zu sehen ist · Dateiname.
- **Schritte ohne Zusammenspiel** dürfen als Einzelbild U1 oder U2 dokumentiert werden.
- **Flüchtige Bildschirme** (Notfall-Schlüssel) direkt bei Erscheinen aufnehmen (Bildschirmvideo), damit nichts übersprungen wird (Lehre aus B-3).

## 4. Voraussetzungen und Risiken

- **TV-01 (Version):** Soll = `version:` in `pubspec.yaml` auf aktuellem `main`. Ist vergleichen: Mac `defaults read /Applications/FamilyNexus.app/Contents/Info CFBundleShortVersionString CFBundleVersion`, Simulator `xcrun simctl listapps booted`, jeweils auch in der App (TI-23). Bei Abweichung zuerst `git pull --ff-only`, neu bauen und installieren (Simulator: `flutter run -d "iPhone 15 Test"`; Mac: Release-Build nach `/Applications`). Soll/Ist beider Geräte stehen am Anfang des Reports.
- **TV-03 (Namen/Stammdaten):** `fnt-MMTT-i2` ist auf dem Server **frei** (`…/_matrix/client/v3/register/available?username=fnt-MMTT-i2` → `available: true`); sonst Datumsteil ändern. N1 besteht (`M_USER_IN_USE`) mit Familie F1 und den Beispieldaten aus Prüfanleitung TC-08 bis TC-10. Ist das nicht der Fall (Vorpläne nicht gelaufen), N1/F1 vorher nach Nutzeranlage TN-09 bis TN-11 anlegen und im Register eintragen.
- **Simulator:** Xcode mit iOS-Runtime (z. B. 27.1). Simulator „iPhone 15 Test“ anlegen (Anhang).
- **Mac-App ohne Daten:** Ist auf dem Mac noch ein Konto angemeldet (z. B. das Apple-Prüfkonto), vorher Einstellungen → „Alle lokalen Daten löschen“. Achtung: Das Gerät verliert damit seine Freischaltung; für das Apple-Prüfkonto wird dann der Notfall-Schlüssel gebraucht (#15).
- **Server prüfen:** TV-02 (Registrierung offen; TC-00 aus `Testplan_Pruefanleitung.md`). Wurde in TN-18 die Registrierung geschlossen, vorher wieder öffnen.
- **Anbieter wählen:** Die App schlägt `matrix.org` vor. Bei Nutzer 1 (Anmeldung, TI-02) unter „Erweitert“ → „Anderen Anbieter verwenden“ die Anbieter-Adresse eintragen. Bei Nutzer 2 übernimmt die App den Server aus dem Einladungslink.
- **⚠️ Konto-Server im Link:** Ohne Angabe nennt der Link den Servernamen `matrix.chaostribunal.de`, der nicht erreichbar ist – Nutzer 2 käme nicht weiter. Deshalb in TI-06 „Konto-Server für Neue“ setzen. Die Negativprobe TI-07 zeigt das Verhalten ohne diese Angabe.
- **Zeit:** Der Einladungslink ist zeitlich begrenzt („Gültig für“, notieren) und nur einmal verwendbar. Link unmittelbar vor TI-09 erzeugen.
- **Automatische Aufnahme:** Links aus dem Einladungsdialog nehmen automatisch auf, sobald die App eines Moderators läuft. Nutzer 1 (Simulator) muss während TI-11/TI-12 geöffnet sein.

## 5. Testfälle

| ID | Schritt | Erwartetes Ergebnis | Bildschirme | Umg. |
|---|---|---|---|---|
| **TI-01** | Simulator „iPhone 15 Test“ starten; aktuellste App-Version (TV-01) installieren und öffnen. Mac-App öffnen (ohne Daten) | Beide zeigen „Willkommen“ mit „Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“ | **P** | P |
| **TI-02** | U1: **Anmelden mit N1 statt neu anlegen:** „Ich habe schon ein Konto“ → „Erweitert“ → „Anderen Anbieter verwenden“ → `matrix-synapse-3ues.srv1348446.hstgr.cloud` → Benutzername `fnt-MMTT-n1` (kurz) | „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“; Maske „Anmelden“; Konto N1 besteht (TV-03), es wird **kein** Konto angelegt (Kontoanlage: Nutzeranlage TN-09) | U1 | U1 |
| **TI-03** | U1: Passwort von N1 → „Anmelden“ → „Dieses Gerät freischalten“ mit dem aktuell gültigen Notfall-Schlüssel von N1 (KN1b bzw. KN1) | Gerät freigeschaltet, Familie F1 „Testfamilie MMTT“ erkannt, Hauptansicht; Termine/Nachricht aus Prüfanleitung TC-08/TC-09 lesbar (falls dort angelegt) | U1 | U1 |
| **TI-04** | **Entfällt hier – abgedeckt durch Nutzeranlage TN-10** (Notfall-Schlüssel beim neuen Konto, #10). Die Anzeige beim über Einladung angelegten Konto prüft TI-11 | – | – | – |
| **TI-05** | U1: Tab „Familie“ (Familie **nicht** neu gründen, F1 besteht aus TN-11) | Familie „Testfamilie MMTT“ zeigt nur Nutzer 1 als Moderator | **P**: U1 Familie; U2 „Willkommen“ | P |
| **TI-06** | U1: Familie → „Jemanden einladen“ → „Erweitert“ → „Konto-Server für Neue“: `matrix-synapse-3ues.srv1348446.hstgr.cloud` → „Neuen Link erzeugen“ | Neuer Link und QR-Code; „Gültig für“ angegeben; Hinweis „… automatisch aufgenommen …“ | U1 (Dialog mit Link, QR, Gültigkeit, Konto-Server) | U1 |
| **TI-07** | Negativprobe (optional): Link **ohne** „Konto-Server für Neue“ auf U2 einfügen („Ich wurde eingeladen“), danach zurück | Die App will den Server `matrix.chaostribunal.de` verwenden und meldet „… ist gerade nicht erreichbar …“ (Grenze des Testservers, kein App-Fehler); nichts angelegt | U2 | U2 |
| **TI-08** | Link aus TI-06 vom Simulator zum Mac übertragen („Link kopieren“, `xcrun simctl pbpaste booted`, auf dem Mac in die Zwischenablage) | Link vollständig, beginnt mit `familynexus://join` | U1 („Link kopiert.“), Terminalausgabe | U1 |
| **TI-09** | U2: „Ich wurde eingeladen“ → zuerst „abc“ einfügen, dann den Link aus TI-08 | „abc“: „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „familynexus://join“.“ Mit Link: „Du wurdest eingeladen“, Familie „Testfamilie MMTT“, eingeladen von Test N1 (`@fnt-MMTT-n1:matrix.chaostribunal.de`); „„Testfamilie MMTT“ beitreten“ | **P**: U1 Familie; U2 Beitrittskarte | P |
| **TI-10** | U2: Vorher TV-03 für `fnt-MMTT-i2` (muss frei sein). Beitreten → Konto erstellen: Anbieter bereits `matrix-synapse-3ues.srv1348446.hstgr.cloud` (nicht matrix.org), Name „Test Nutzer 2“, Benutzername `fnt-MMTT-i2`, Passwort → „Konto erstellen“ | Konto angelegt ohne Zusatzschritt, weiter zum Notfall-Schlüssel | U2 | U2 |
| **TI-11** | U2: „Notfall-Schlüssel erstellen“ (Bildschirmvideo) → Häkchen → „Weiter“ | Schlüssel wird angezeigt und bleibt stehen (#10); danach Beitrittsanfrage wird gesendet („Fast geschafft! …“) | U2 | U2 |
| **TI-12** | Aufnahme abwarten (U1 geöffnet lassen) | Nutzer 2 wird automatisch aufgenommen (Link aus dem Einladungsdialog); U2 landet in der Hauptansicht; Dauer notieren. Falls U1 stattdessen eine Anfrage zeigt („Familie – 1 offene Anfragen“, „Gültiger Einladungslink“): „Bestätigen“ und Verhalten notieren | **P**: U1 Familie; U2 Hauptansicht | P |
| **TI-13** | Beide: Tab „Familie“, danach Tab „Heute“ | „Familie“: Mitgliederliste zeigt beide (Moderator / Mitglied). „Heute“: „Wer ist online“ zeigt den jeweils anderen | **P** | P |
| **TI-14** | U1 sendet im Familienchat „Hallo von Nutzer 1“; U2 öffnet Chat | Nachricht erscheint bei U2 (Ende-zu-Ende-verschlüsselt) | **P** vor und nach dem Senden | P |
| **TI-15** | U2 antwortet „Hallo zurück von Nutzer 2“ | Antwort erscheint bei U1 | **P** | P |
| **TI-16** | Einzelchat: U1 öffnet über die Mitgliederliste den Chat mit Nutzer 2 und sendet „Nur für dich“ | Einzelchat entsteht; Nachricht erscheint bei U2 im Einzelchat, nicht im Familienchat | **P** | P |
| **TI-17** | **Vorhandene Termine wiederverwenden:** „Test geteilt“ (geteilt) und „Test privat“ (privat) aus Prüfanleitung TC-08 bei U1 ansehen und bei U2 den Kalender öffnen. Nur wenn TC-08 nicht gelaufen ist, U1 die beiden Termine jetzt anlegen und im Register eintragen | „Test geteilt“ erscheint bei U2 (Heute/Kalender), „Test privat“ nicht | **P** | P |
| **TI-18** | U2 legt Einkaufseintrag „Brot“ an (neuer Eintrag von U2; „Milch“ aus Prüfanleitung TC-10 ist bei U2 sichtbar); U1 hakt „Brot“ ab | Eintrag erscheint bei U1; Abhaken erscheint bei U2 | **P** nach jedem Schritt | P |
| **TI-19** | U1: Nachricht von Nutzer 2 lange drücken → „Nachricht melden“ (Grund wählen) | Meldedialog mit Gründen; Meldung bestätigt (geht an den Betreiber des Testservers) | **P** | P |
| **TI-20** | U1: Nachricht von Nutzer 2 lange drücken → „Test Nutzer 2 blockieren“; danach sendet U2 eine weitere Nachricht | Nachrichten von Nutzer 2 bei U1 ausgeblendet; bei U2 keine Fehlermeldung | **P** | P |
| **TI-21** | U1: Einstellungen → „Blockierte Mitglieder“ → „Blockierung aufheben“ | Nutzer 2 und seine Nachrichten wieder sichtbar | **P** | P |
| **TI-22** | Negativprobe: U2 (bereits Mitglied) öffnet den verbrauchten Link aus TI-08 erneut (Mac-Terminal: `open '<Link>'`) | Hinweis „Du bist bereits in einer Familie.“; nichts ändert sich, kein Absturz | U2 | U2 |
| **TI-23** | Versionsanzeige: beide öffnen Menü und Einstellungen → „Über die App“ | Angezeigte Version/Build entspricht dem Soll aus TV-01 (derzeit „Version 1.2.1 (16)“) auf beiden (#14) | **P** | P |
| **TI-24** | U1: Einstellungen → Konto → „Konto löschen“ (nur Dialog prüfen) → „Abbrechen“ | Dialog „Konto löschen?“ mit Hinweis „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“ (#12); „Konto endgültig löschen“ ohne Passwort nicht aktiv; nach „Abbrechen“ unverändert angemeldet | U1 | U1 |
| **TI-25** | U2: Einstellungen → Konto → „Konto löschen“ → Passwort → „Konto endgültig löschen“ (falsches Passwort ist in Prüfanleitung TC-16 abgedeckt, hier nicht wiederholen) | Kein Moderator-Hinweis (U2 ist Mitglied); richtiges Passwort: U2 zeigt „Willkommen“ (alle lokalen Daten gelöscht) | **P**: U1 Familie; U2 Dialog bzw. „Willkommen“ | P |
| **TI-26** | U1: Tab „Familie“ nach TI-25 | Nutzer 2 ist nicht mehr Mitglied (vom Server bei der Löschung ausgetragen); seine früheren Nachrichten im Chat bleiben sichtbar | **P**: U1 Familie; U2 „Willkommen“ | P |
| **TI-27** | **Schlussaufräumen:** N1 (U1) Einstellungen → Konto → „Konto löschen“ mit Passwort; Gegenprobe Anmeldung. Danach `Testdaten_Stammdaten.md`, Abschnitt 4: alle Konten N1, N2, I2 gelöscht? Verbliebene löschen | Kein Moderator-Hinweis mehr (allein); „Willkommen“; Anmeldung mit `fnt-MMTT-n1` bzw. `fnt-MMTT-i2` scheitert | **P**: beide „Willkommen“ | P |

## 6. Abnahme

Bestanden, wenn TI-01 bis TI-27 ✅ sind (TI-04 entfällt, TI-07 optional). ⚠️ ist zulässig, wenn der Befund im Report steht. Offene ⏳-Fälle werden im Report mit Grund geführt.

Ergebnisse stehen im Report `Testreport_Einladung_Zweiter_Nutzer.pdf`. Der Report enthält: Testplattform (Mac, Simulator, Xcode/iOS-Version, App-Build), Testserver, beide Nutzer (Passwörter und Schlüssel maskiert), Ergebnistabelle je Testfall, **parallele Bildschirmpaare je Zusammenspiel-Schritt** mit Beschriftung, Befundliste.

## Anhang A: Vorbereitung des Simulators

```sh
# iPhone-15-Simulator anlegen (Runtime anpassen) und starten
xcrun simctl create "iPhone 15 Test" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-27-1
xcrun simctl boot "iPhone 15 Test"
open -a Simulator
# App bauen und im Simulator starten (aktueller main, Version laut pubspec.yaml)
flutter run -d "iPhone 15 Test"
# Bildschirmfoto Nutzer 1 (Simulator)
xcrun simctl io booted screenshot TI-xx-yy-U1.png
# Zwischenablage Simulator lesen (Einladungslink)
xcrun simctl pbpaste booted
```

## Anhang B: Früheres matrix.org-Konto Nutzer 2 – nicht Teil dieses Tests

Zugangsdaten stehen nicht im Repository, sondern lokal in `../secure/Zugangsdaten.local.md` bzw. im Passwortmanager.
