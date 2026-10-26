# Testplan Einladung und Zusammenspiel zweier Nutzer

Bezug: `Testplan_Pruefanleitung.md` (Abschnitt 0 Testserver; früher TC-09, TC-11, TC-12), Issues #10–#14, Nachtest #15
Build: FamilyNexus **1.2.1 (16)** (Stand `main` nach PR #21) · Stand: 26.10.2026

## 1. Ziel

Nachweis, dass zwei **im Test neu angelegte** Nutzer auf dem Testserver zusammenspielen: Nutzer 1 gründet eine Familie und lädt per Link ein, Nutzer 2 legt sein Konto über den Einladungslink in der App an und wird aufgenommen. Danach Mitgliederliste, Chat, Einzelchat, geteilter Termin, Einkaufsliste, Melden/Blockieren/Aufheben, Moderator-Hinweis bei der Kontolöschung und Löschung beider Konten.

Abgedeckt: Einzelchat (TC-09 alt), Melden/Blockieren/Aufheben (TC-11 alt), Einstiegswege „Neue Familie gründen“ und „Ich wurde eingeladen“ mit Kontoanlage (TC-12 alt), Notfall-Schlüssel beim neuen Konto (#10), Kontolöschung mit Moderator-Hinweis (#12), Versionsanzeige (#14).

Dokumentationsvorgabe: Im Testbericht sind **bei jedem Zusammenspiel-Schritt beide Bildschirme parallel zu sehen** (links Nutzer 1 auf dem iPhone-15-Simulator, rechts Nutzer 2 auf dem Mac), mit eindeutiger Beschriftung je Schritt.

## 2. Testserver, Nutzer und Geräte

Testserver wie in `Testplan_Pruefanleitung.md`, Abschnitt 0: Anbieter-Adresse `matrix-synapse-3ues.srv1348446.hstgr.cloud`, Matrix-IDs `@<name>:matrix.chaostribunal.de`, Anmeldung mit Passwort in der App, Registrierung offen ohne Zusatzschritt.

| Rolle | Benutzername (wird im Test angelegt) | Gerät / Umgebung | angelegt in | gelöscht in |
|---|---|---|---|---|
| **Nutzer 1** (Moderator, lädt ein) | `fnt-MMTT-i1`, Anzeigename „Test Nutzer 1“ | **iPhone-15-Simulator**, App-Build 1.2.1 (16) | TI-03 | TI-27 |
| **Nutzer 2** (wird eingeladen) | `fnt-MMTT-i2`, Anzeigename „Test Nutzer 2“ | **Mac**, App 1.2.1 (16) unter `/Applications/FamilyNexus.app` | TI-10 | TI-26 |

`MMTT` = Testdatum. Passwörter und Notfall-Schlüssel erzeugt der Tester beim Anlegen und legt sie im Passwortmanager ab, **nicht** in diesem Plan; im Report maskiert.

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

- **Simulator:** Xcode mit iOS-Runtime (z. B. 27.1). Simulator „iPhone 15 Test“ anlegen (Anhang). App für den Simulator bauen (`flutter run -d "iPhone 15 Test"`, Stand `main` nach PR #21, Version 1.2.1+16).
- **Mac-App ohne Daten:** Ist auf dem Mac noch ein Konto angemeldet (z. B. das Apple-Prüfkonto), vorher Einstellungen → „Alle lokalen Daten löschen“. Achtung: Das Gerät verliert damit seine Freischaltung; für das Apple-Prüfkonto wird dann der Notfall-Schlüssel gebraucht (#15).
- **Server prüfen:** TC-00 aus `Testplan_Pruefanleitung.md` (Registrierung offen).
- **Anbieter wählen:** Die App schlägt `matrix.org` vor. Bei Nutzer 1 vor der Kontoanlage unter „Erweitert“ → „Anderen Anbieter verwenden“ die Anbieter-Adresse eintragen. Bei Nutzer 2 übernimmt die App den Server aus dem Einladungslink.
- **⚠️ Konto-Server im Link:** Ohne Angabe nennt der Link den Servernamen `matrix.chaostribunal.de`, der nicht erreichbar ist – Nutzer 2 käme nicht weiter. Deshalb in TI-06 „Konto-Server für Neue“ setzen. Die Negativprobe TI-07 zeigt das Verhalten ohne diese Angabe.
- **Zeit:** Der Einladungslink ist zeitlich begrenzt („Gültig für“, notieren) und nur einmal verwendbar. Link unmittelbar vor TI-09 erzeugen.
- **Automatische Aufnahme:** Links aus dem Einladungsdialog nehmen automatisch auf, sobald die App eines Moderators läuft. Nutzer 1 (Simulator) muss während TI-11/TI-12 geöffnet sein.

## 5. Testfälle

| ID | Schritt | Erwartetes Ergebnis | Bildschirme | Umg. |
|---|---|---|---|---|
| **TI-01** | Simulator „iPhone 15 Test“ starten; App 1.2.1 (16) installieren und öffnen. Mac-App öffnen (ohne Daten) | Beide zeigen „Willkommen“ mit „Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“ | **P** | P |
| **TI-02** | U1: „Neue Familie gründen“ → „Erweitert“ → „Anderen Anbieter verwenden“ → `matrix-synapse-3ues.srv1348446.hstgr.cloud` | „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“; „Konto erstellen“, „Schritt 1 von 3“ | U1 | U1 |
| **TI-03** | U1: Name „Test Nutzer 1“, Benutzername `fnt-MMTT-i1`, Passwort → „Konto erstellen“ | Konto angelegt ohne Zusatzschritt; „Schritt 2 von 3“ | U1 | U1 |
| **TI-04** | U1: „Notfall-Schlüssel erstellen“ (Bildschirmvideo) → Häkchen → „Weiter“ | Schlüssel wird angezeigt und **bleibt stehen**, bis „Weiter“ getippt wird (#10); Schlüssel ablegen | U1 | U1 |
| **TI-05** | U1: „Name der Familie“: „Einladungstest MMTT“ → „Familie gründen“ → Tab „Familie“ | „Fertig! … ist eingerichtet.“; Familie zeigt nur Nutzer 1 als Moderator | **P**: U1 Familie; U2 „Willkommen“ | P |
| **TI-06** | U1: Familie → „Jemanden einladen“ → „Erweitert“ → „Konto-Server für Neue“: `matrix-synapse-3ues.srv1348446.hstgr.cloud` → „Neuen Link erzeugen“ | Neuer Link und QR-Code; „Gültig für“ angegeben; Hinweis „… automatisch aufgenommen …“ | U1 (Dialog mit Link, QR, Gültigkeit, Konto-Server) | U1 |
| **TI-07** | Negativprobe (optional): Link **ohne** „Konto-Server für Neue“ auf U2 einfügen („Ich wurde eingeladen“), danach zurück | Die App will den Server `matrix.chaostribunal.de` verwenden und meldet „… ist gerade nicht erreichbar …“ (Grenze des Testservers, kein App-Fehler); nichts angelegt | U2 | U2 |
| **TI-08** | Link aus TI-06 vom Simulator zum Mac übertragen („Link kopieren“, `xcrun simctl pbpaste booted`, auf dem Mac in die Zwischenablage) | Link vollständig, beginnt mit `familynexus://join` | U1 („Link kopiert.“), Terminalausgabe | U1 |
| **TI-09** | U2: „Ich wurde eingeladen“ → zuerst „abc“ einfügen, dann den Link aus TI-08 | „abc“: „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „familynexus://join“.“ Mit Link: „Du wurdest eingeladen“, Familie „Einladungstest MMTT“, eingeladen von Test Nutzer 1 (`@fnt-MMTT-i1:matrix.chaostribunal.de`); „„Einladungstest MMTT“ beitreten“ | **P**: U1 Familie; U2 Beitrittskarte | P |
| **TI-10** | U2: beitreten → Konto erstellen: Anbieter bereits `matrix-synapse-3ues.srv1348446.hstgr.cloud` (nicht matrix.org), Name „Test Nutzer 2“, Benutzername `fnt-MMTT-i2`, Passwort → „Konto erstellen“ | Konto angelegt ohne Zusatzschritt, weiter zum Notfall-Schlüssel | U2 | U2 |
| **TI-11** | U2: „Notfall-Schlüssel erstellen“ (Bildschirmvideo) → Häkchen → „Weiter“ | Schlüssel wird angezeigt und bleibt stehen (#10); danach Beitrittsanfrage wird gesendet („Fast geschafft! …“) | U2 | U2 |
| **TI-12** | Aufnahme abwarten (U1 geöffnet lassen) | Nutzer 2 wird automatisch aufgenommen (Link aus dem Einladungsdialog); U2 landet in der Hauptansicht; Dauer notieren. Falls U1 stattdessen eine Anfrage zeigt („Familie – 1 offene Anfragen“, „Gültiger Einladungslink“): „Bestätigen“ und Verhalten notieren | **P**: U1 Familie; U2 Hauptansicht | P |
| **TI-13** | Beide: Tab „Familie“ | Mitgliederliste zeigt beide (Moderator / Mitglied); „Wer ist online“ zeigt den jeweils anderen | **P** | P |
| **TI-14** | U1 sendet im Familienchat „Hallo von Nutzer 1“; U2 öffnet Chat | Nachricht erscheint bei U2 (Ende-zu-Ende-verschlüsselt) | **P** vor und nach dem Senden | P |
| **TI-15** | U2 antwortet „Hallo zurück von Nutzer 2“ | Antwort erscheint bei U1 | **P** | P |
| **TI-16** | Einzelchat: U1 öffnet über die Mitgliederliste den Chat mit Nutzer 2 und sendet „Nur für dich“ | Einzelchat entsteht; Nachricht erscheint bei U2 im Einzelchat, nicht im Familienchat | **P** | P |
| **TI-17** | U1 legt zwei Termine an: einen **Geteilt**, einen **Privat** | Geteilter Termin erscheint bei U2 (Heute/Kalender), privater nicht | **P** | P |
| **TI-18** | U2 legt Einkaufseintrag „Brot“ an; U1 hakt ihn ab | Eintrag erscheint bei U1; Abhaken erscheint bei U2 | **P** nach jedem Schritt | P |
| **TI-19** | U1: Nachricht von Nutzer 2 lange drücken → „Nachricht melden“ (Grund wählen) | Meldedialog mit Gründen; Meldung bestätigt (geht an den Betreiber des Testservers) | **P** | P |
| **TI-20** | U1: Nachricht von Nutzer 2 lange drücken → „Test Nutzer 2 blockieren“; danach sendet U2 eine weitere Nachricht | Nachrichten von Nutzer 2 bei U1 ausgeblendet; bei U2 keine Fehlermeldung | **P** | P |
| **TI-21** | U1: Einstellungen → „Blockierte Mitglieder“ → Aufheben | Nutzer 2 und seine Nachrichten wieder sichtbar | **P** | P |
| **TI-22** | Negativprobe: U2 (bereits Mitglied) öffnet den verbrauchten Link aus TI-08 erneut (Mac-Terminal: `open '<Link>'`) | Hinweis „Du bist bereits in einer Familie.“; nichts ändert sich, kein Absturz | U2 | U2 |
| **TI-23** | Versionsanzeige: beide öffnen Menü und Einstellungen → „Über die App“ | „Version 1.2.1 (16)“ auf beiden (#14) | **P** | P |
| **TI-24** | U1: Einstellungen → Konto → „Konto löschen“ (nur Dialog prüfen) → „Abbrechen“ | Dialog „Konto löschen?“ mit Hinweis „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“ (#12); „Konto endgültig löschen“ ohne Passwort nicht aktiv; nach „Abbrechen“ unverändert angemeldet | U1 | U1 |
| **TI-25** | U2: Einstellungen → Konto → „Konto löschen“ → zuerst falsches Passwort, dann richtiges → „Konto endgültig löschen“ | Kein Moderator-Hinweis (U2 ist Mitglied); falsches Passwort: Fehlermeldung, Dialog bleibt; richtiges: U2 zeigt „Willkommen“ (alle lokalen Daten gelöscht) | **P**: U1 Familie; U2 Dialog bzw. „Willkommen“ | P |
| **TI-26** | U1: Tab „Familie“ nach TI-25 | Nutzer 2 ist nicht mehr Mitglied (vom Server bei der Löschung ausgetragen); seine früheren Nachrichten im Chat bleiben sichtbar | **P**: U1 Familie; U2 „Willkommen“ | P |
| **TI-27** | Aufräumen U1: Einstellungen → Konto → „Konto löschen“ mit Passwort; Gegenprobe Anmeldung | Kein Moderator-Hinweis mehr (allein); „Willkommen“; Anmeldung mit `fnt-MMTT-i1` bzw. `fnt-MMTT-i2` scheitert | **P**: beide „Willkommen“ | P |

## 6. Abnahme

Bestanden, wenn TI-01 bis TI-27 ✅ sind (TI-07 optional). ⚠️ ist zulässig, wenn der Befund im Report steht. Offene ⏳-Fälle werden im Report mit Grund geführt.

Ergebnisse stehen im Report `Testreport_Einladung_Zweiter_Nutzer.pdf`. Der Report enthält: Testplattform (Mac, Simulator, Xcode/iOS-Version, App-Build), Testserver, beide Nutzer (Passwörter und Schlüssel maskiert), Ergebnistabelle je Testfall, **parallele Bildschirmpaare je Zusammenspiel-Schritt** mit Beschriftung, Befundliste.

## Anhang A: Vorbereitung des Simulators

```sh
# iPhone-15-Simulator anlegen (Runtime anpassen) und starten
xcrun simctl create "iPhone 15 Test" com.apple.CoreSimulator.SimDeviceType.iPhone-15 com.apple.CoreSimulator.SimRuntime.iOS-27-1
xcrun simctl boot "iPhone 15 Test"
open -a Simulator
# App bauen und im Simulator starten (Stand main nach PR #21, Build 1.2.1+16)
flutter run -d "iPhone 15 Test"
# Bildschirmfoto Nutzer 1 (Simulator)
xcrun simctl io booted screenshot TI-xx-yy-U1.png
# Zwischenablage Simulator lesen (Einladungslink)
xcrun simctl pbpaste booted
```

## Anhang B: Früheres matrix.org-Konto Nutzer 2 – nicht Teil dieses Tests

Zugangsdaten stehen nicht im Repository, sondern lokal in `Test-Apple/Zugangsdaten.local.md` bzw. im Passwortmanager.
