# Testplan Prüfanleitung (Maßnahme 6)

Bezug: `Massnahmenplan_App_Store_Review.md`, Punkt 6 „Prüfanleitung schreiben“; Issues #10–#14 (umgesetzt), Nachtest #15
Build: Soll-Version laut `pubspec.yaml` auf `main` (beim Schreiben **1.2.1 (16)**), Prüfung in TV-01 · Stand: 26.10.2026
Gemeinsame Vorprüfung, Stammdaten und Reihenfolge: **`Testdaten_Stammdaten.md`** (zuerst lesen). Läuft **nach** `Testplan_Nutzeranlage.md` und verwendet dessen Konten weiter.

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

**Testuser – kommen aus den Stammdaten** (`Testdaten_Stammdaten.md`; Namensschema mit Datum `MMTT`, z. B. `fnt-1027-n1`). Dieser Plan legt **keine** neuen Konten an:

| Kürzel | Benutzername | Zweck hier | angelegt in | gelöscht in |
|---|---|---|---|---|
| **N1** | `fnt-MMTT-n1` | Hauptkonto, Moderator der Familie F1 „Testfamilie MMTT“ (Konto + Familie aus TN-09/TN-11); angemeldet auf G | Nutzeranlage TN-09 | Einladung TI-27 |
| **N2** | `fnt-MMTT-n12` | Konto mit Familie F2 „Löschtest MMTT“ für die Kontolöschung | Nutzeranlage TN-15 | TC-16 | **Kontolöschung mit N2 (Konto aus TN-15 wiederverwenden, nichts neu anlegen):** TV-03: `fnt-MMTT-n12` besteht. G2 ist nach der Nutzeranlage abgemeldet („Willkommen“/„Anmelden“) → „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter-Adresse → Benutzername `fnt-MMTT-n12` (kurz), Passwort → „Anmelden“ → „Dieses Gerät freischalten“ mit **KN2** → Einstellungen → Konto → „Konto löschen“ → zuerst falsches Passwort, dann richtiges → „Konto endgültig löschen“ | Dialog „Konto löschen?“ nennt `@fnt-MMTT-n12:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, Nachrichten bleiben bei anderen sichtbar; kein Moderator-Hinweis (N2 ist allein in F2); „Konto endgültig löschen“ erst mit Passwort aktiv; falsches Passwort: Fehlermeldung, Dialog bleibt, nichts gelöscht; richtiges Passwort: App löscht alle lokalen Daten und zeigt „Willkommen“. Gegenprobe: Anmeldung mit `fnt-MMTT-n12` scheitert | – | G2 | #12 |

Fehlt eines der Konten (Nutzeranlage nicht gelaufen), wird es vorher nach `Testplan_Nutzeranlage.md` (TN-09 bis TN-11 bzw. TN-15) angelegt, ins Register eingetragen und im Report als nachgeholt geführt. Vor dem Anlegen immer TV-03 (Name noch frei?).

Passwörter erzeugt der Tester beim Anlegen (mind. 8 Zeichen, Passwortmanager) und trägt sie **nicht** in diesen Plan ein; im Report maskiert. Notfall-Schlüssel ebenso nur im Passwortmanager (KN1 = erster Schlüssel von N1 aus TN-10, KN1b = neuer Schlüssel nach TC-12).

## 1. Ziel

Nachweis, dass die Prüfanleitung (Review-Notizen `store/metadata/{ios,macos}/review_notes.txt`) und die Korrekturen aus dem Testreport Build 15 in der App so funktionieren: Notfall-Schlüssel wird beim neuen Konto angezeigt (#10), lässt sich neu erstellen (#11), Konto lässt sich in der App löschen (#12), Review-Notizen stimmen mit der App überein (#13), Versionsanzeige mit Build-Nummer (#14).

Getestet wird zweierlei: (a) jeder Schritt ist in der App tatsächlich so vorhanden (Texte, Reihenfolge), (b) alle Voraussetzungen (Konten, Rollen, Beispieldaten, Einstellungen) stammen nachvollziehbar aus den Stammdaten und werden wiederverwendet. Was bereits in `Testplan_Nutzeranlage.md` geprüft wurde (Willkommen, Sprache, Anbieter wählen, Kontoanlage, Notfall-Schlüssel beim neuen Konto, Familie gründen), wird hier **nicht erneut** angelegt.

**Abgrenzung:** Die Review-Notizen beschreiben für Apple die Anmeldung bei matrix.org im Browser. Auf dem Testserver läuft die Anmeldung mit Passwort in der App; diese Abweichung ist erwartet. Der matrix.org-Weg (Browser-Anmeldung, Löschseite des Anbieters) bleibt Teil von #15 mit dem Apple-Prüfkonto (Anhang).

## 2. Umgebungen und Nachweisarten

| Kürzel | Umgebung | Nachweis |
|---|---|---|
| **G** | Physisches Gerät (iPhone mit aktuellem iOS, Mac mit aktuellem macOS), Testserver | Bildschirmfoto/Video vom Gerät – **vom Menschen durchzuführen** |
| **G2** | Zweites Gerät (Mac oder iPhone-Simulator) für N1 und N2 | wie G |
| **R** | Gerenderte Oberfläche (`tool/onboarding_screens.sh`, Fake-Matrix, 390 × 844 dp) | Bildschirmfotos in `screenshots/onboarding` |
| **T** | Automatische Tests (`flutter test`) | Konsolenausgabe im Report |

Ergebnisse: ✅ bestanden · ❌ fehlgeschlagen · ⏳ offen · ⚠️ bestanden mit Befund

**Flüchtige Bildschirme** (Notfall-Schlüssel) direkt bei Erscheinen aufnehmen (Bildschirmvideo), damit nichts übersprungen wird (Lehre aus B-3).

## 3. Voraussetzungen für die Durchführung

- **TV-01:** Aktuellste Version installiert: Soll = `pubspec.yaml` auf `main`; Ist je Gerät (G, G2) vergleichen (Mac: `defaults read …`, TestFlight: neuester Build, App: Menü/„Über die App“). Bei Abweichung zuerst neu installieren. Der Vergleich steht am Anfang des Reports; TC-11 prüft dasselbe in der App.
- **TV-02:** Testserver erreichbar und Registrierung offen: TC-00.
- **TV-03:** Es wird kein neues Konto angelegt; die Stammdaten N1/N2 müssen aus der Nutzeranlage vorhanden sein (N1 angemeldet auf G, F1 gegründet; N2 mit F2, G2 abgemeldet). Prüfen: `…/register/available?username=fnt-MMTT-n1` liefert `M_USER_IN_USE` (Konto besteht). Sonst Nutzeranlage nachholen.
- Auf G ist N1 angemeldet (kein „Alle lokalen Daten löschen“ vor TC-04).
- Zweites Gerät (G2) für TC-13; dort ist nach der Nutzeranlage niemand angemeldet („Willkommen“).
- Testperson ohne Vorwissen für TC-17.
- Für Melden/Blockieren/Einzelchat wird ein zweites Mitglied gebraucht: `Testplan_Einladung_Zweiter_Nutzer.md` (TI-Fälle) – dort entstehen beide Konten ebenfalls im Test.

## 4. Testfälle

| ID | Schritt | Erwartetes Ergebnis | Screenshot | Umg. | Issue |
|---|---|---|---|---|---|
| TC-00 | Server prüfen (entspricht TV-02, Ergebnis übernehmen): im Browser `https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/versions` öffnen | JSON mit `"versions"`; (optional Terminal: `curl -s -X POST -d '{}' …/_matrix/client/v3/register` liefert `flows` mit `m.login.dummy`, **nicht** „Registration has been disabled“) | – | G | – |
| TC-01 | **Entfällt hier – abgedeckt durch Nutzeranlage TN-01** (Ergebnis dort übernehmen). Inhalt: Frische Installation, App starten | „Willkommen“ mit drei Wegen: „Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“; Sprache unten auf der Seite; kein eigener Sprach- oder Server-Schritt | `onboarding/01-start.png` | R, G | #13 |
| TC-02 | **Entfällt hier – abgedeckt durch Nutzeranlage TN-01.** „English“ antippen, danach zurück auf Deutsch | Texte wechseln sofort | `onboarding/24-start-englisch.png` | R, G | – |
| TC-03 | **Entfällt hier – abgedeckt durch Nutzeranlage TN-04.** „Neue Familie gründen“ → „Erweitert“ → „Anderen Anbieter verwenden“ → „Adresse des Anbieters“: `matrix-synapse-3ues.srv1348446.hstgr.cloud` | Maske „Konto erstellen“, „Schritt 1 von 3“; Status „Verbinde mit …“, danach „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“; Felder „Wie heißt du?“, „Dein Benutzername“, Passwort | `onboarding/02-…`, `05-erweitert-anbieter.png` | R, G | – |
| TC-04 | **N1 prüfen statt anlegen:** Anlage ist durch Nutzeranlage TN-09 abgedeckt. Hier: auf G ist N1 (`fnt-MMTT-n1`, „Test N1“) angemeldet; Einstellungen → „Konto“ | Konto zeigt `@fnt-MMTT-n1:matrix.chaostribunal.de` und den Anbieter; Familie F1 „Testfamilie MMTT“ besteht. Kein neues Konto, kein Anlegen eines weiteren Benutzers | – | G | – |
| TC-05 | **Entfällt hier – abgedeckt durch Nutzeranlage TN-10** (Schlüssel bleibt stehen, Häkchen vor „Weiter“; Schlüssel **KN1**). Hier nur: KN1 liegt im Passwortmanager bereit | – | `onboarding/08-…`, `09-…` | R | #10 |
| TC-06 | **Entfällt hier – abgedeckt durch Nutzeranlage TN-11** (Familie F1 „Testfamilie MMTT“ gegründet, nicht erneut anlegen) | – | `onboarding/10-…`, `11-…` | R | – |
| TC-07 | Hauptansicht „Heute“ | Nächste Termine, Erinnerungen, Einkaufszettel; Navigation Heute/Kalender/Chat/Einkauf/Familie. Falls „Benachrichtigungen sind blockiert. …“: „Erlauben“ → Systemdialog → erlauben, Hinweis verschwindet | `hauptfunktionen/1-heute.png` | G | #13 (B-7) |
| TC-08 | Kalender (Beispieldaten für die Folgepläne, im Register eintragen): geteilten Termin „Test geteilt“ morgen 10:00 und privaten Termin „Test privat“ anlegen | Tages-/Wochen-/Monatsansicht; beide Termine sichtbar, Kennzeichnung geteilt/privat; „Heute“ zeigt den nächsten Termin | `hauptfunktionen/2-kalender.png` | G | – |
| TC-09 | Chat: Nachricht „Hallo Testfamilie“ senden | Verschlüsselter Familienchat; Nachricht erscheint | `hauptfunktionen/3-chat.png` | G | – |
| TC-10 | Einkauf: „Milch“ anlegen, abhaken | Eintrag erscheint, abhakbar | `hauptfunktionen/5-einkauf.png` | G | – |
| TC-11 | Menü (oben rechts, „Menü öffnen“) unten ablesen; Einstellungen → „Über die App“; dort „Protokoll: alle lokal gespeicherten Daten zeigen“ | Menü: „Version 1.2.1 (16)“; Einstellungen: Eintrag „Version 1.2.1 (16)“; Protokoll: „App-Version 1.2.1 (16)“ – identisch mit TestFlight/App Store Connect | – | G | #14 |
| TC-12 | Einstellungen → „Notfall-Schlüssel und Geräte“ → „Neuen Notfall-Schlüssel erstellen“ (Bildschirmvideo) | Seite „Neuer Notfall-Schlüssel“ mit Erklärung („Der alte funktioniert danach nicht mehr …“) → „Neuen Notfall-Schlüssel erstellen“ → neuer Schlüssel angezeigt; **„Zurück“ (Pfeil/Wischgeste) ist gesperrt**, bis Häkchen gesetzt und „Weiter“ getippt; danach zurück in den Einstellungen; Schlüssel als **KN1b** ablegen (KN1 ist danach ungültig) | – | G | #11 |
| TC-13 | **G2:** App installieren/öffnen → „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter-Adresse → Benutzername `fnt-MMTT-n1` (kurz) + Passwort → „Anmelden“ → „Dieses Gerät freischalten“: zuerst **KN1** eingeben → „Freischalten“, dann **KN1b** | KN1: „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“, Gerät bleibt gesperrt. KN1b: Gerät freigeschaltet, Familie „Testfamilie MMTT“ erkannt, Hauptansicht; Termine aus TC-08 und Nachricht aus TC-09 lesbar | `onboarding/20-anmelden.png`, `21-geraet-freischalten.png` | G2 | #11 |
| TC-14 | G2: Einstellungen → „Notfall-Schlüssel und Geräte“ | Status „verifiziert“; Geräteliste zeigt beide Geräte als verifiziert; Eintrag „Neuen Notfall-Schlüssel erstellen“ vorhanden | – | G2 | #11 |
| TC-15 | Konsistenz der Review-Notizen (`store/metadata/{ios,macos}/review_notes.txt`, englisch und deutsch) gegen die App | Automatisch: `test/store/review_notes_test.dart` grün (jede zitierte Beschriftung steht so in der App). Manuell: Einstieg, „Dieses Gerät freischalten“, Kontoanlage über „Neue Familie gründen“, „Konto löschen“, „Erlauben“ in der App so gefunden. Abweichung Browser-Anmeldung (matrix.org) ist erwartet (Abgrenzung, #15) | – | R, T, G | #13 |
| TC-16 | **Kontolöschung mit UX:** G2 abmelden (Einstellungen → „Abmelden“ → im Dialog „Abmelden“ bestätigen; die App zeigt danach direkt „Anmelden“) → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse prüfen bzw. eintragen → `fnt-MMTT-del` anlegen → Schlüssel → Familie „Löschtest“ → Einstellungen → Konto → „Konto löschen“ → zuerst falsches Passwort, dann richtiges → „Konto endgültig löschen“ | Dialog „Konto löschen?“ nennt `@fnt-MMTT-del:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, Nachrichten bleiben bei anderen sichtbar; kein Moderator-Hinweis (allein in der Familie); „Konto endgültig löschen“ erst mit Passwort aktiv; falsches Passwort: Fehlermeldung, Dialog bleibt, nichts gelöscht; richtiges Passwort: App löscht alle lokalen Daten und zeigt „Willkommen“. Gegenprobe: Anmeldung mit `fnt-MMTT-del` scheitert | – | G2 | #12 |
| TC-17 | Anleitung vollständig durch Person ohne Vorwissen nachvollziehen lassen (Ablauf TC-04, TC-07 bis TC-12 nach dieser Tabelle, davor die Nutzeranlage TN-01 bis TN-11) | Alle Schritte ohne Rückfrage ausführbar; Rückfragen notieren | – | G | #13 |
| TC-18 | Automatische Testsuite für den Build (`flutter analyze`, `flutter test`, optional `tool/e2e.sh`) | Alle Tests bestehen | – | T | – |
| TC-19 | **Zustand festhalten (kein Löschen von N1):** N1 wird noch für den Einladungstest gebraucht. Register in `Testdaten_Stammdaten.md` aktualisieren: N1 besteht (Schlüssel KN1b, F1 mit Beispieldaten aus TC-08 bis TC-10), N2 gelöscht | N1 für `Testplan_Einladung_Zweiter_Nutzer.md` nutzbar; N1 wird dort in TI-27 gelöscht | – | G | #12 |

Melden, Blockieren, Aufheben, Einzelchat und der Einstiegsweg „Ich wurde eingeladen“ (früher TC-09/TC-11/TC-12) laufen im Einladungstest (`Testplan_Einladung_Zweiter_Nutzer.md`, TI-Fälle); er verwendet N1, F1 und die Beispieldaten aus TC-08 bis TC-10 weiter.

## 5. Abnahme

Bestanden, wenn TC-00 bis TC-19 ✅ sind (entfallene Fälle TC-01 bis TC-03, TC-05, TC-06 zählen mit dem Ergebnis der Nutzeranlage) und der Einladungstest bestanden ist. Offene ⏳-Fälle müssen vor der Antwort an Apple nachgeholt werden; der matrix.org-Weg mit dem Apple-Prüfkonto wird in #15 getestet.
Ergebnisse stehen im Report `Testreport_Pruefanleitung.md`.

## Anhang: Apple-Prüfkonto (matrix.org) – nicht Teil dieses Tests

Nur für die Einreichung bei Apple und den matrix.org-Nachtest in #15. Zugangsdaten stehen nicht im Repository, sondern lokal in `../secure/Zugangsdaten.local.md` bzw. im Passwortmanager.
