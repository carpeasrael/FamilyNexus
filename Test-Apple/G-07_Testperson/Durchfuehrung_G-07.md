# G-07 Durchlauf mit einer Person ohne Vorwissen – Vorbereitung

Bezug: Testplan TP-FN-001 v1.5, Schritt G-07 („A-01 bis A-12 und B-01 bis B-03 nach Anleitung; ohne Rückfrage ausführbar; Rückfragen notieren“) und Issue #15 (TC-14).

## Ziel

Prüfen, ob eine Person, die FamilyNexus nicht kennt, mit der Anleitung `Anleitung_Testperson.md` ein Konto anlegt, eine Familie gründet, die Hauptansicht erreicht und einen geteilten Termin anlegt – **ohne Hilfe der Beobachterin bzw. des Beobachters**. Gemessen werden Rückfragen, Fehlversuche und Dauer.

## Rollen

| Rolle | Aufgabe |
|---|---|
| Testperson | kennt FamilyNexus nicht, hat keine Entwicklungs-/Testplan-Erfahrung mit der App, liest nur `Anleitung_Testperson.md` |
| Beobachter/in | sitzt daneben, **hilft nicht**, schreibt in `Beobachtungsbogen_G-07.md`; greift nur ein bei Absturz, Blockade über 3 Minuten oder wenn die Testperson abbrechen will |

## Vorbereitung (vorher, ca. 15 Minuten)

| Nr. | Aufgabe | erledigt |
|---|---|---|
| 1 | Gerät festlegen: iPhone (empfohlen, echtes Gerät) oder Simulator; Mac optional. Plattform, Modell und iOS-Version im Beobachtungsbogen eintragen | ☐ |
| 2 | Build prüfen: `Version 1.2.1 (17)` (Soll aus `pubspec.yaml` auf `main`, Commit im Bogen notieren). Für ein echtes iPhone: TestFlight-Build 17 installieren (siehe Issue #15, Build 17 ist noch nicht hochgeladen) | ☐ |
| 3 | Lokale Daten löschen: App zeigt „Willkommen“ (Einstellungen → „Alle lokalen Daten löschen“, danach Neustart). Beim iOS-Simulator bei Hängern `xcrun simctl uninstall booted de.inneso.familynexus` und `xcrun simctl keychain booted reset` | ☐ |
| 4 | Server prüfen: `curl -s -X POST -H 'Content-Type: application/json' -d '{}' https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/v3/register` liefert `m.login.dummy` | ☐ |
| 5 | Benutzername frei: `curl -s "https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/v3/register/available?username=fnt-1028-g7"` → `available: true` (am 28.10.2026 geprüft; sonst Datumsteil/Suffix ändern, fremde Konten nie benutzen) | ☐ |
| 6 | Benachrichtigungen der App sind nicht vorab erlaubt (System → Mitteilungen) | ☐ |
| 7 | Bildschirmaufnahme (nur mit Einwilligung der Testperson) oder Notizen; Screenshots von Stolperstellen. Passwort und Notfall-Schlüssel **nicht** fotografieren oder schwärzen | ☐ |
| 8 | Ausgedruckte oder geöffnete `Anleitung_Testperson.md` bereitlegen; **Passwort** und **Notfall-Schlüssel** legt die Testperson selbst fest bzw. erzeugt die App (nicht vorgeben) | ☐ |
| 9 | Einwilligung: Die Testperson weiß, dass **die App getestet wird, nicht sie**, dass sie jederzeit abbrechen darf und dass das Konto danach gelöscht wird | ☐ |

## Vorgaben für die Beobachtung

- Vorher **nichts erklären** außer dem Satz auf Blatt 1 der Anleitung.
- Rückfragen der Testperson **nicht beantworten**, nur sagen „Was würden Sie jetzt tun?“. Jede Rückfrage mit Uhrzeit und Schritt im Bogen notieren.
- Erst nach Schritt 12 und B-03 oder nach Abbruch sprechen.
- Zeit je Abschnitt notieren (Start/Ende).
- Bei einem Hänger der App (z. B. „Schritt 1 von 3“ über 30 s, Issue #27) nicht helfen, sondern notieren und nach 30 s die App neu starten lassen.

## Auswertung

| Ergebnis | Kriterium |
|---|---|
| ✅ bestanden | Alle Schritte 1–15 der Anleitung ohne Rückfrage an die Beobachtung geschafft |
| ⚠️ bestanden mit Befund | geschafft, aber mit Rückfragen (je Rückfrage ein Befund mit Schritt und Wortlaut) oder erst nach Fehlversuchen |
| ❌ fehlgeschlagen | Testperson kommt an einem Schritt nicht weiter oder bricht ab |

Rückfragen und Stolperstellen werden als Issues erfasst (Titel „G-07: … (Schritt …)“) und im Report als G-07 eingetragen; danach Konto der Testperson löschen (siehe unten).

## Nachbereitung

1. Konto löschen: Testperson oder Beobachtung in der App → Einstellungen → „Konto löschen“ (Passwort der Testperson); Kontrolle per `curl` auf dem Server (`403 M_FORBIDDEN`).
2. Lokale Daten auf dem Gerät löschen (Zustand „Willkommen“).
3. Zettel mit dem Passwort und dem Notfall-Schlüssel vernichten, nichts davon in Git.
4. Ergebnis in `Test-Apple-Report/<Lauf-Ordner>/` ablegen (Bogen als `G-07_Beobachtungsbogen.md`, Bilder in `screenshots/`), Report und PDF ergänzen, Issue #15 (TC-14) aktualisieren.

## Datenschutz

Es werden keine personenbezogenen Daten der Testperson gespeichert. Im Bogen steht nur „Testperson 1“, Alter in Gruppen (z. B. 30–45) und die Selbsteinschätzung zur Technik. Anzeigenamen und Benutzername sind Testdaten (`Testperson`, `fnt-1028-g7`).
