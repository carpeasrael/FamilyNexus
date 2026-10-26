# Testplan Prüfanleitung (Maßnahme 6)

Bezug: `Massnahmenplan_App_Store_Review.md`, Punkt 6 „Prüfanleitung schreiben“; Issues #10–#14 (umgesetzt), Nachtest #15
Build: FamilyNexus **1.2.1 (16)** (Stand `main` nach PR #21) · Stand: 26.10.2026

## 0. Testserver und Testuser

| Angabe | Wert |
|---|---|
| Anbieter-Adresse (in der App eingeben) | `matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| Servername in den Matrix-IDs | `matrix.chaostribunal.de` → IDs lauten `@<name>:matrix.chaostribunal.de` |
| Anmeldung | Benutzername + Passwort in der App (kein OAuth, kein Browser) |
| Registrierung | offen, ohne Zusatzschritt (`m.login.dummy`): kein Zugangscode, keine E-Mail, kein Captcha |
| Kontolöschung | in der App mit Passwortbestätigung (`/account/deactivate`, `erase`) |

Vorab geprüft am 26.10.2026 mit dem echten App-Gateway: Kontoanlage, Notfall-Schlüssel erstellen und erneuern, Familie gründen, Einladungslink, Beitritt eines zweiten neuen Kontos, verschlüsselter Chat, Löschung beider Konten – alles erfolgreich.

**Besonderheiten dieses Servers (beim Test beachten):**
- Die App schlägt immer `matrix.org` vor (E-70). Bei jeder Kontoanlage und Anmeldung zuerst unter **„Erweitert“ → „Anderen Anbieter verwenden“** die Anbieter-Adresse eintragen; erst weiter, wenn „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“ steht.
- Der Servername `matrix.chaostribunal.de` ist im Internet nicht erreichbar. Deshalb beim Anmelden **nur den kurzen Benutzernamen** eingeben (`fnt-…`), nie die vollständige ID `@…:matrix.chaostribunal.de` (die App würde sonst zu diesem Server wechseln wollen).
- Einladungslinks nennen als Konto-Server standardmäßig den Servernamen. Für Einladungen im Einladungsdialog unter „Erweitert“ → „Konto-Server für Neue“ die Anbieter-Adresse eintragen und „Neuen Link erzeugen“ (siehe `Testplan_Einladung_Zweiter_Nutzer.md`).

**Testuser – werden im Test angelegt** (Namensschema mit Datum `MMTT`, z. B. `fnt-1027-u1`):

| Kürzel | Benutzername | Zweck | angelegt in | gelöscht in |
|---|---|---|---|---|
| **U1** | `fnt-MMTT-u1` | Hauptkonto, Moderator der Familie „Testfamilie MMTT“ | TC-04 | TC-19 |
| **UX** | `fnt-MMTT-del` | Wegwerf-Konto für die Kontolöschung | TC-16 | TC-16 |

Passwörter erzeugt der Tester beim Anlegen (mind. 8 Zeichen, Passwortmanager) und trägt sie **nicht** in diesen Plan ein; im Report maskiert. Notfall-Schlüssel ebenso nur im Passwortmanager (K1 = erster, K2 = neuer Schlüssel von U1).

## 1. Ziel

Nachweis, dass die Prüfanleitung (Review-Notizen `store/metadata/{ios,macos}/review_notes.txt`) und die Korrekturen aus dem Testreport Build 15 in der App so funktionieren: Notfall-Schlüssel wird beim neuen Konto angezeigt (#10), lässt sich neu erstellen (#11), Konto lässt sich in der App löschen (#12), Review-Notizen stimmen mit der App überein (#13), Versionsanzeige mit Build-Nummer (#14).

Getestet wird zweierlei: (a) jeder Schritt ist in der App tatsächlich so vorhanden (Texte, Reihenfolge), (b) alle Voraussetzungen (Konten, Rollen, Beispieldaten, Einstellungen) entstehen nachvollziehbar im Test selbst.

**Abgrenzung:** Die Review-Notizen beschreiben für Apple die Anmeldung bei matrix.org im Browser. Auf dem Testserver läuft die Anmeldung mit Passwort in der App; diese Abweichung ist erwartet. Der matrix.org-Weg (Browser-Anmeldung, Löschseite des Anbieters) bleibt Teil von #15 mit dem Apple-Prüfkonto (Anhang).

## 2. Umgebungen und Nachweisarten

| Kürzel | Umgebung | Nachweis |
|---|---|---|
| **G** | Physisches Gerät (iPhone mit aktuellem iOS, Mac mit aktuellem macOS), Testserver | Bildschirmfoto/Video vom Gerät – **vom Menschen durchzuführen** |
| **G2** | Zweites Gerät (Mac oder iPhone-Simulator) für U1 | wie G |
| **R** | Gerenderte Oberfläche (`tool/onboarding_screens.sh`, Fake-Matrix, 390 × 844 dp) | Bildschirmfotos in `screenshots/onboarding` |
| **T** | Automatische Tests (`flutter test`) | Konsolenausgabe im Report |

Ergebnisse: ✅ bestanden · ❌ fehlgeschlagen · ⏳ offen · ⚠️ bestanden mit Befund

**Flüchtige Bildschirme** (Notfall-Schlüssel) direkt bei Erscheinen aufnehmen (Bildschirmvideo), damit nichts übersprungen wird (Lehre aus B-3).

## 3. Voraussetzungen für die Durchführung

- Build **1.2.1 (16)** installiert (TestFlight/Gerät); Version/Build unter Menü bzw. Einstellungen → Über die App ablesbar (TC-11).
- Testserver erreichbar und Registrierung offen: TC-00.
- App vor dem Test ohne Daten (frische Installation oder Einstellungen → „Alle lokalen Daten löschen“).
- Zweites Gerät (G2) für TC-13.
- Testperson ohne Vorwissen für TC-17.
- Für Melden/Blockieren/Einzelchat wird ein zweites Mitglied gebraucht: `Testplan_Einladung_Zweiter_Nutzer.md` (TI-Fälle) – dort entstehen beide Konten ebenfalls im Test.

## 4. Testfälle

| ID | Schritt | Erwartetes Ergebnis | Screenshot | Umg. | Issue |
|---|---|---|---|---|---|
| TC-00 | Server prüfen: im Browser `https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/versions` öffnen | JSON mit `"versions"`; (optional Terminal: `curl -s -X POST -d '{}' …/_matrix/client/v3/register` liefert `flows` mit `m.login.dummy`, **nicht** „Registration has been disabled“) | – | G | – |
| TC-01 | Frische Installation, App starten | „Willkommen“ mit drei Wegen: „Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“; Sprache unten auf der Seite; kein eigener Sprach- oder Server-Schritt | `onboarding/01-start.png` | R, G | #13 |
| TC-02 | „English“ antippen, danach zurück auf Deutsch | Texte wechseln sofort | `onboarding/24-start-englisch.png` | R, G | – |
| TC-03 | „Neue Familie gründen“ → „Erweitert“ → „Anderen Anbieter verwenden“ → „Adresse des Anbieters“: `matrix-synapse-3ues.srv1348446.hstgr.cloud` | Maske „Konto erstellen“, „Schritt 1 von 3“; Status „Verbinde mit …“, danach „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“; Felder „Wie heißt du?“, „Dein Benutzername“, Passwort | `onboarding/02-…`, `05-erweitert-anbieter.png` | R, G | – |
| TC-04 | **U1 anlegen:** Name „Test U1“, Benutzername `fnt-MMTT-u1` (Hinweis „Der Benutzername ist frei.“), Passwort → „Konto erstellen“ | „Erstelle Konto …“, kein Zusatzschritt (kein Code, keine E-Mail, kein Captcha); weiter zu „Schritt 2 von 3“ | `onboarding/04-…` | G | – |
| TC-05 | „Notfall-Schlüssel erstellen“ (Bildschirmvideo läuft) | **Schlüssel wird angezeigt und bleibt stehen** – die App springt nicht von selbst zum Familienschritt; „Kopieren“, „Als Datei speichern“; „Weiter“ erst nach Häkchen „Ich habe den Notfall-Schlüssel sicher aufbewahrt.“; Schlüssel als **K1** im Passwortmanager ablegen | `onboarding/08-…`, `09-…` | R, G | #10 |
| TC-06 | „Weiter“ → „Name der Familie“: „Testfamilie MMTT“ → „Familie gründen“ | „Fertig! „Testfamilie MMTT“ ist eingerichtet.“, danach Hauptansicht | `onboarding/10-…`, `11-…` | R, G | – |
| TC-07 | Hauptansicht „Heute“ | Nächste Termine, Erinnerungen, Einkaufszettel; Navigation Heute/Kalender/Chat/Einkauf/Familie. Falls „Benachrichtigungen sind blockiert. …“: „Erlauben“ → Systemdialog → erlauben, Hinweis verschwindet | `hauptfunktionen/1-heute.png` | G | #13 (B-7) |
| TC-08 | Kalender: geteilten Termin „Test geteilt“ morgen 10:00 und privaten Termin „Test privat“ anlegen | Tages-/Wochen-/Monatsansicht; beide Termine sichtbar, Kennzeichnung geteilt/privat; „Heute“ zeigt den nächsten Termin | `hauptfunktionen/2-kalender.png` | G | – |
| TC-09 | Chat: Nachricht „Hallo Testfamilie“ senden | Verschlüsselter Familienchat; Nachricht erscheint | `hauptfunktionen/3-chat.png` | G | – |
| TC-10 | Einkauf: „Milch“ anlegen, abhaken | Eintrag erscheint, abhakbar | `hauptfunktionen/5-einkauf.png` | G | – |
| TC-11 | Menü (oben rechts, „Menü öffnen“) unten ablesen; Einstellungen → „Über die App“; dort „Protokoll: alle lokal gespeicherten Daten zeigen“ | Menü: „Version 1.2.1 (16)“; Einstellungen: Eintrag „Version 1.2.1 (16)“; Protokoll: „App-Version 1.2.1 (16)“ – identisch mit TestFlight/App Store Connect | – | G | #14 |
| TC-12 | Einstellungen → „Notfall-Schlüssel und Geräte“ → „Neuen Notfall-Schlüssel erstellen“ (Bildschirmvideo) | Seite „Neuer Notfall-Schlüssel“ mit Erklärung („Der alte funktioniert danach nicht mehr …“) → „Neuen Notfall-Schlüssel erstellen“ → neuer Schlüssel angezeigt; **„Zurück“ (Pfeil/Wischgeste) ist gesperrt**, bis Häkchen gesetzt und „Weiter“ getippt; danach zurück in den Einstellungen; Schlüssel als **K2** ablegen | – | G | #11 |
| TC-13 | **G2:** App installieren/öffnen → „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter-Adresse → Benutzername `fnt-MMTT-u1` (kurz) + Passwort → „Anmelden“ → „Dieses Gerät freischalten“: zuerst **K1** eingeben → „Freischalten“, dann **K2** | K1: „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“, Gerät bleibt gesperrt. K2: Gerät freigeschaltet, Familie „Testfamilie MMTT“ erkannt, Hauptansicht; Termine aus TC-08 und Nachricht aus TC-09 lesbar | `onboarding/20-anmelden.png`, `21-geraet-freischalten.png` | G2 | #11 |
| TC-14 | G2: Einstellungen → „Notfall-Schlüssel und Geräte“ | Status „verifiziert“; Geräteliste zeigt beide Geräte als verifiziert; Eintrag „Neuen Notfall-Schlüssel erstellen“ vorhanden | – | G2 | #11 |
| TC-15 | Konsistenz der Review-Notizen (`store/metadata/{ios,macos}/review_notes.txt`, englisch und deutsch) gegen die App | Automatisch: `test/store/review_notes_test.dart` grün (jede zitierte Beschriftung steht so in der App). Manuell: Einstieg, „Dieses Gerät freischalten“, Kontoanlage über „Neue Familie gründen“, „Konto löschen“, „Erlauben“ in der App so gefunden. Abweichung Browser-Anmeldung (matrix.org) ist erwartet (Abgrenzung, #15) | – | R, T, G | #13 |
| TC-16 | **Kontolöschung mit UX:** G2 abmelden (Einstellungen → „Abmelden“ → im Dialog „Abmelden“ bestätigen; die App zeigt danach direkt „Anmelden“) → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse prüfen bzw. eintragen → `fnt-MMTT-del` anlegen → Schlüssel → Familie „Löschtest“ → Einstellungen → Konto → „Konto löschen“ → zuerst falsches Passwort, dann richtiges → „Konto endgültig löschen“ | Dialog „Konto löschen?“ nennt `@fnt-MMTT-del:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, Nachrichten bleiben bei anderen sichtbar; kein Moderator-Hinweis (allein in der Familie); „Konto endgültig löschen“ erst mit Passwort aktiv; falsches Passwort: Fehlermeldung, Dialog bleibt, nichts gelöscht; richtiges Passwort: App löscht alle lokalen Daten und zeigt „Willkommen“. Gegenprobe: Anmeldung mit `fnt-MMTT-del` scheitert | – | G2 | #12 |
| TC-17 | Anleitung vollständig durch Person ohne Vorwissen nachvollziehen lassen (TC-01 bis TC-12 nach dieser Tabelle) | Alle Schritte ohne Rückfrage ausführbar; Rückfragen notieren | – | G | #13 |
| TC-18 | Automatische Testsuite für den Build (`flutter analyze`, `flutter test`, optional `tool/e2e.sh`) | Alle Tests bestehen | – | T | – |
| TC-19 | **Aufräumen U1:** G: Einstellungen → Konto → „Konto löschen“ mit Passwort von U1 | Wie TC-16 (kein Moderator-Hinweis, U1 ist allein in der Familie): App löscht alle lokalen Daten, „Willkommen“; Anmeldung mit `fnt-MMTT-u1` scheitert danach. Auf dem Server bleiben keine aktiven Testkonten zurück | – | G | #12 |

Melden, Blockieren, Aufheben, Einzelchat und der Einstiegsweg „Ich wurde eingeladen“ (früher TC-09/TC-11/TC-12) laufen im Einladungstest (`Testplan_Einladung_Zweiter_Nutzer.md`, TI-Fälle).

## 5. Abnahme

Bestanden, wenn TC-00 bis TC-19 ✅ sind und der Einladungstest bestanden ist. Offene ⏳-Fälle müssen vor der Antwort an Apple nachgeholt werden; der matrix.org-Weg mit dem Apple-Prüfkonto wird in #15 getestet.
Ergebnisse stehen im Report `Testreport_Pruefanleitung.md`.

## Anhang: Apple-Prüfkonto (matrix.org) – nicht Teil dieses Tests

Nur für die Einreichung bei Apple und den matrix.org-Nachtest in #15. Zugangsdaten stehen nicht im Repository, sondern lokal in `../secure/Zugangsdaten.local.md` bzw. im Passwortmanager.
