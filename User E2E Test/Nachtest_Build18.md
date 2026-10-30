# Nachtest Build 1.2.1 (18)

**Ziel:** Prüfen, ob die Fixes aus PR #52 im Build wirken (#44, #45, #46) und ob #43 auftritt. Bezug: Testplan TP-FN-001 v1.5 (Schritte A-07, E-21, E-25, D-02), Testreport `User E2E Test Report/2026-10-27_06_iOS-macOS_Build17/`, Issue #15.

**Dauer:** etwa 45 Minuten. **Konten:** zwei, `fnt-1028-n1` (N1) und `fnt-1028-i2` (I2); Namen am 28.10.2026 frei, sonst Datumsteil/Suffix ändern (fremde Konten nie benutzen). Registrierung am 28.10.2026 offen. Passwörter erzeugt die Testperson und hält sie nur im Passwortmanager.

## 1. Voraussetzungen

| Nr. | Prüfung | Erwartung | Erg. |
|---|---|---|---|
| N-01 | Soll-Version: `grep '^version:' pubspec.yaml` auf `main` | `1.2.1+18` | |
| N-02 | Build 18 signiert gebaut und hochgeladen (`tool/build_ios_release.sh`, `tool/build_macos_dmg.sh`), in TestFlight verfügbar | Build 18 sichtbar | |
| N-03 | G1 = iPhone (TestFlight Build 18), G2 = Mac (Build 18 aus DMG/TestFlight). **Nicht** die ältere App aus `/Applications` (Build 16) starten; sie fragt beim Öffnen von Links nach dem Schlüsselbund-Passwort | beide „Version 1.2.1 (18)“ in Menü und Einstellungen | |
| N-04 | Lokale Daten auf beiden Geräten leer (Willkommen). Server: `curl -s -X POST -H 'Content-Type: application/json' -d '{}' https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/v3/register` liefert `m.login.dummy` | wie links | |
| N-05 | Benutzernamen frei: `…/register/available?username=fnt-1028-n1` und `…-i2` | beide `available: true` | |

## 2. Nachtest der Fixes

Eingabe auf einem **echten iPhone mit Bildschirmtastatur**. Im Simulator gingen Großbuchstaben verloren (Befund I-1); dort sind A-07 (Anna) und Texteingaben nicht aussagekräftig.

| ID | Issue | Gerät | Schritt | Erwartung | Beobachtet | Bild | Erg. |
|---|---|---|---|---|---|---|---|
| A-07 | #44 | G1 | Kontoanlage → „Erweitert“ → Anbieter `matrix-synapse-3ues.srv1348446.hstgr.cloud`. Benutzername nacheinander: `ab`, `Anna` (mit großem A, Tastatur prüfen), `anna müller`, `.anna`, `anna.`, 33 × `a` | Jede Eingabe zeigt „Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.“ **vollständig lesbar (bis 3 Zeilen), ohne „…“**; „Konto erstellen“ ausgegraut. Bei `Anna` ebenfalls der Fehler, nicht stilles `anna` | | A-07a…f-G1 | |
| E-21 | #46 | G1 | N1 anlegen (A-08 bis A-12) und Familie gründen. Termin `Test geteilt`, „Geteilt“, morgen 10:00 anlegen, in der Liste öffnen → „Termin bearbeiten“ → „Privat“ → „Speichern“ | Hinweis „Bereits an die Familie gesendete Inhalte bleiben …“; danach zeigt die **Detailseite den Termin** (Titel, Zeit, Sichtbarkeit „Privat“), **nicht** „Gelöscht“; Zurück zur Liste: ein privater Termin, kein Duplikat | | E-21a/b-G1 | |
| E-21b | #46 | G1 | Zweite Prüfung wie E-21 im Kalender statt in „Heute“ (Tag-Ansicht) | wie oben | | E-21c-G1 | |
| E-25 | #45 | G1, G2 | Einladungslink erzeugen (Konto-Server für Neue = Anbieter-Adresse, „Link kopieren“), auf G2 I2 über den Link anlegen und beitreten (E-06 bis E-11); I2 schreibt im Chat `Test`. G1: Nachricht von I2 lange drücken → „Nachricht melden“ → „Spam oder Werbung“ → „Melden“ | „Meldung gesendet.“ mit „Absender blockieren“; Hinweis **verschwindet nach etwa 8 Sekunden von selbst**; Navigation und Einstellungen sind danach ohne App-Neustart bedienbar | Dauer: ____ s | E-25a/b-G1 | |
| E-25b | #45 | G1 | Gleiche Meldung nochmal, „Absender blockieren“ antippen | „… ist blockiert.“, Hinweis schließt; danach Blockierung unter Einstellungen aufheben | | E-25c-G1 | |

## 3. Beobachtung zu #43 (Ablehnung einer Familien-Code-Anfrage)

#43 ließ sich lokal nicht reproduzieren. Hier wird nur beobachtet. Dafür **keine** Konten wiederverwenden, die schon in einer Familie sind.

| ID | Gerät | Schritt | Erwartung | Beobachtet | Erg. |
|---|---|---|---|---|---|
| D-02a | G2 | Frisches Konto `fnt-1028-n3` anlegen (Kontoanlage → Familienschritt), „Beitreten“ → „Ohne Link beitreten (Familien-Code)“. G1 (N1): Tab „Familie“ → „Familien-Code“ → „Code kopieren“, auf G2 einfügen → „Beitritt anfragen“. **Uhrzeit der Anfrage notieren:** ____ | „Fast geschafft! …“ | | |
| D-02b | G1 | Anfrage in „Familie – 1 offene Anfragen“ ansehen → „Ablehnen“. **Uhrzeit notieren:** ____ | Anfrage verschwindet | | |
| D-02c | G2 | App im Vordergrund lassen, bis zu 2 Minuten warten. **Uhrzeit, zu der „Deine Anfrage wurde abgelehnt“ erscheint:** ____ | „Deine Anfrage wurde abgelehnt. …“ mit „Verstanden“, spätestens nach etwa 10 bis 20 Sekunden (die App fragt alle 10 s) | | |
| D-02d | G2 | Erscheint nichts: App beenden und neu starten, erneut 1 Minute warten | Meldung nach Neustart? (ja/nein) | | |

**Protokoll bei Ausbleiben der Meldung:** Das neue Log („Ablehnung der Beitrittsanfrage: Abfrage lieferte HTTP …“) ist in TestFlight-Builds nicht sichtbar (`developer.log` schreibt nur in Debug-Läufen). Deshalb zusätzlich auf dem Mac einen Debug-Lauf starten: `flutter run -d macos` (Build aus `main`), die Konsole mitlesen und nach der Zeile mit `Ablehnung der Beitrittsanfrage` suchen. Notieren: Zeitpunkte, Gerätezeit gegen Serverzeit (`date -u` und `curl -sI https://matrix-synapse-3ues.srv1348446.hstgr.cloud | grep -i '^date'`), HTTP-Status.

## 4. Aufräumen und Auswertung

| Nr. | Schritt | Erwartung | Erg. |
|---|---|---|---|
| N-10 | I2 und N3 (falls angelegt): Einstellungen → „Konto löschen“ (Passwort), dann N1 (allein in der Familie) | „Willkommen“; curl-Anmeldung aller Konten `403 M_FORBIDDEN` | |
| N-11 | Lokale Daten auf beiden Geräten löschen | „Willkommen“ | |
| N-12 | Passwörter und Schlüssel aus dem Passwortmanager entfernen; Bilder mit Schlüsseln schwärzen | – | |

**Ergebnis je Issue** (nach der Durchführung eintragen):

| Issue | Ergebnis | Aktion |
|---|---|---|
| #44 | ☐ behoben ☐ nicht behoben | bei ✅ schließen, sonst Befund ergänzen |
| #45 | ☐ behoben ☐ nicht behoben | bei ✅ schließen |
| #46 | ☐ behoben ☐ nicht behoben | bei ✅ schließen |
| #43 | ☐ aufgetreten (Zeiten, HTTP-Status) ☐ nicht aufgetreten | bei „nicht aufgetreten“ als „nicht reproduzierbar“ begründen, sonst Debug-Protokoll anhängen |

Ergebnisse als `User E2E Test Report/<Lauf-Ordner>/Nachtest_Build18.md` ablegen, Bilder in `screenshots/`, Issue #15 aktualisieren.
