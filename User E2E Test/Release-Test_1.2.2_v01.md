# Release-Test FamilyNexus 1.2.2 (neue Funktionen)

**Planversion: v01** (05.11.2026) · Dokument-ID `TP-FN-REL-122` · Stand: `main` @ `079faa1` (Tag `v1.2.2`), Soll-Version der App **1.2.2 (24)** (`pubspec.yaml`: `1.2.2+24`)

Bezug: Release Notes 1.2.2 (`store/metadata/*/release_notes.txt`), Meilenstein „Release v1.2.2“, `docs/ENTSCHEIDUNGEN.md` (E-78 bis E-92), Gesamtplan `Testplan_FamilyNexus.md` (TP-FN-001 v1.33).

## 1. Ziel und Abgrenzung

Dieser Plan prüft **nur, was in 1.2.2 neu oder geändert ist**, auf **echten Geräten und Emulatoren/Simulatoren**. Jeder Schritt hat ein **Erwartetes Ergebnis** und einen **Screenshot als Beleg**. Er ergänzt den Gesamtplan, ersetzt ihn aber nicht: Vor einem Release läuft zusätzlich der Gesamtplan (Regression, Abschnitt 13).

**Bekannte offene Funde aus dem Release-Review 1.2.2+24** (nicht behoben, für 1.2.3 vorgesehen; beim Lauf als Befund mit Verweis eintragen, nicht als neuer Fehler): #294 (Chat markiert bei aktiver App-Sperre als gelesen, berührt RT-D-03 bis RT-D-05), #295 (Datumszeilen mit doppeltem Schlüssel bei Zickzack-Zeiten, RT-C-01), #296 (Store-Datenschutzerklärung nennt nur Terminerinnerungen, RT-J-06), #297 (Hinweise nennen „iPhone und Mac“, nicht das iPad, RT-F-10, RT-F-13), #298 (App-Sperre blockiert den Tastaturfokus nicht), #273 (Android-Hintergrund, RT-D-08).

Nicht Inhalt dieses Plans (kein UI-Test möglich, abgedeckt durch automatische Tests, Abschnitt 12): Wettläufe und Zeitschranken im Gateway, Verwerfen unverschlüsselter Ereignisse, Verschlüsselung der Reaktionen auf dem Draht, Backoff beim Senden.

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ nicht durchgeführt (mit Grund) · n/a (auf der Plattform nicht vorhanden, mit Grund).
**Ein Schritt gilt nur als ✅, wenn das erwartete Ergebnis am Screenshot (oder an der genannten Ausgabe) nachweisbar ist.** Was nicht ausgeführt wurde, ist ⏳, nie ✅.

## 2. Festlegung von Plattform und System (vor dem ersten Schritt ausfüllen)

Die Zielsysteme decken alle Plattformen ab, auf denen 1.2.2 neu ist. Pro Lauf werden mindestens G1 und G2 festgelegt (zwei Geräte für Chat, Beitritt, Meldungen). Plattformkürzel in den Schritten: **iOS** (iPhone), **iPad**, **Mac**, **And** (Android-Telefon), **AndT** (Android-Tablet), **Win**, **Lin** (Flatpak), **Web**.

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | | |
| Gerät oder Simulator/Emulator (Modell, Name) | | |
| Betriebssystem und Version | | |
| Bei Web: Browser und Version | | |
| Installationsquelle (Build aus `main`, TestFlight, APK, Zip, Flatpak …) | | |
| App-Version Soll / Ist (RT-V-01, RT-V-02) | 1.2.2 (24) / | 1.2.2 (24) / |
| Gerätesprache, 12-/24-Stunden-Einstellung | | |
| Methode für Screenshots | | |
| Tester / Datum / Uhrzeit Beginn | | |

**Empfohlene Mindestabdeckung für die Freigabe:** iPhone-Simulator, iPad-Simulator (Air 13", Hoch- und Querformat), Mac, Android-Telefon-Emulator (API 36), Android-Tablet-Emulator (z. B. Pixel Tablet), Windows 11, Linux-Flatpak, Web (Chrome oder Firefox aktuell). Wo kein Gerät verfügbar ist, bleibt der Schritt ⏳ mit Grund.

**Screenshots:** Methoden je Plattform wie in `Testplan_FamilyNexus.md`, Abschnitt 2 (iOS-Simulator `xcrun simctl io booted screenshot`, Android-Emulator `adb emu screenrecord screenshot`, Windows und Linux mit Systemwerkzeug, macOS `screencapture`). Dateiname: `<Schritt-ID>_<Plattform>.png`, z. B. `RT-A-03_iOS.png`. **Windows hat den Bildschirmschutz ab Werk an** (Fenster fehlt in Screenshots): vor dem Lauf unter Einstellungen ausschalten, dies im Report vermerken und nach „Alle lokalen Daten löschen“ erneut ausschalten. Notfall-Schlüssel, Passwörter und Einladungslinks auf Screenshots **schwärzen**.

## 3. Testserver, Konten, Grenzen

- **Server:** der eigene Testserver bzw. der lokale Synapse (`tool/synapse/up.sh`, danach `curl -fsk https://localhost:18448/_matrix/client/versions` muss 200 liefern). Konten, Familie und Beispieldaten wie im Gesamtplan, Abschnitt 3: **Wegwerfkonten**, am Ende löschen (RT-L-xx).
- **Keine echten Konten oder Registrierungen bei matrix.org.** Schritte mit matrix.org (RT-F-xx) laufen nur mit ausdrücklicher Freigabe und eigenem Konto; sonst ⏳.
- **Keine Geheimnisse in Repository oder Issues:** Passwörter und Notfall-Schlüssel nur in einer von Git ignorierten Datei (`secure/…`).
- Bedienung per Skript: Hinweise in `Testplan_FamilyNexus.md`, Anhang D.
- **Rollen:** N1 = Moderator und Gründer (G1), I2 = eingeladene Person (G2). Zusätzlich ein zweites Konto N3 für den Familienwechsel (RT-K-xx).

## 4. Abschnittsübersicht

| Abschnitt | Thema | Issues / Entscheidungen |
|---|---|---|
| V | Version und Installation | #241 |
| A | Einkauf: Gruppen | #211, #217 |
| B | Heute und Erinnerungen | #218, #220, #223, #234, #196, #184 |
| C | Chat: Datum, Marke, Zitat, Reaktionen, Anhänge, Senden | #254 Teil A, #139, #173, #224, #231, #132, #236, #239 |
| D | Meldungen und Zahl am App-Symbol | #254 Teil B, E-88 |
| E | Beitritt durch Moderator, Einladungslink v4 | #118, #115, E-78, E-79 |
| F | Passwort und Anmeldung in der App | #117, #268, E-80, E-91 |
| G | Anbieter-Adresse, Protokoll, Löschen | #259, #261, #271, #272 |
| H | Datum, Uhrzeit, Termin-Editor, Zeitwähler | #260, #162, #163, #264, #263 |
| I | Familie: Wechsel, Mitgliederliste, Fehleransicht, Start | #140, #135, #198, #175, #154 |
| J | Texte und Datenschutz je Plattform | #143, #144, #146, #160, #169, #237, #225 |
| K | Web | #137, #266, #154, #227, #240, #249 |
| L | Tablet und große Fenster | #274, REQ-TABLET-01, E-92 |
| M | Emojis und Eingabefelder | #161, #202, #221, #242 |
| N | Dateien und iOS-Temp | #141 |
| O | Aufräumen | – |
| 12 | Automatische Tests | Pflichtteil |
| 13 | Regression und Abnahme | – |

## 5. Testschritte

Spalten: **ID** · **Pl.** (Plattformen, `alle` = alle festgelegten) · **Schritt** · **Erwartetes Ergebnis** · **Screenshot** (Dateiname) · **Beobachtet** · **Erg.** Die letzten drei Spalten füllt der Tester.

### V. Version und Installation

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-V-01 | alle | `pubspec.yaml` auf dem getesteten Stand öffnen, Zeile `version:` notieren (`git rev-parse --short HEAD` mitschreiben) | `version: 1.2.2+24` (oder der im Report genannte spätere Stand) | `RT-V-01_pubspec.png` | | |
| RT-V-02 | alle | App installieren (Build aus `main` bzw. Release-Artefakt), starten, Einstellungen → „Über die App“ öffnen | Version „1.2.2 (24)“ wird angezeigt, passt zu RT-V-01 | `RT-V-02_<Pl>.png` | | |
| RT-V-03 | alle | Alle lokalen Daten löschen (Einstellungen), App neu starten | Willkommensseite („Willkommen bei FamilyNexus“), keine Reste einer früheren Sitzung | `RT-V-03_<Pl>.png` | | |

### A. Einkauf: Gruppen (#211, #217)

Vorbedingung: Konto N1, Familie eingerichtet (Gesamtplan A-09 bis A-12).

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-A-01 | alle | Tab „Einkauf“ öffnen. Neuen Eintrag „Milch“ mit Gruppe „Supermarkt“ anlegen (Feld mit Hinweis „Gruppe (optional)“) | Eintrag erscheint unter der Überschrift „Supermarkt“ | `RT-A-01_<Pl>.png` | | |
| RT-A-02 | alle | Zweiten Eintrag „Brot“ mit Gruppe „Supermarkt“, dritten „Schrauben“ mit Gruppe „Baumarkt“, vierten „Zahnpasta“ ohne Gruppe anlegen | Drei Abschnitte „Supermarkt“ (2), „Baumarkt“ (1) und am Ende „Ohne Gruppe (1)“ | `RT-A-02_<Pl>.png` | | |
| RT-A-03 | alle | Beim Anlegen eines weiteren Eintrags die Gruppen-Vorschläge öffnen | Vorschläge „Gruppe Supermarkt übernehmen“ und „Gruppe Baumarkt übernehmen“ erscheinen; Antippen übernimmt den Namen ins Feld | `RT-A-03_<Pl>.png` | | |
| RT-A-04 | alle | „Brot“ abhaken | „Brot“ verschwindet aus den offenen Einträgen oder erscheint als erledigt (je nach Ansicht), „Supermarkt“ zeigt nur noch „Milch“ als offen | `RT-A-04_<Pl>.png` | | |
| RT-A-05 | alle | Gruppe eines Eintrags ändern („Schrauben“ → „Supermarkt“) | „Schrauben“ steht unter „Supermarkt“, Abschnitt „Baumarkt“ entfällt | `RT-A-05_<Pl>.png` | | |
| RT-A-06 | alle (G2 als I2) | Auf G2 den Einkauf öffnen | Gleiche Gruppen und Einträge wie auf G1 (nach Abgleich) | `RT-A-06_G2_<Pl>.png` | | |

### B. Heute und Erinnerungen (#218, #220, #223, #234, #196)

Vorbedingung: mindestens vier Termine heute oder in den nächsten Tagen, davon einer mit Erinnerung in wenigen Minuten (Termin-Editor → Erinnerung „Zur Startzeit“ oder „5 Minuten vorher“). Auf Android: Benachrichtigungen und „genaue Alarme“ erlaubt.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-B-01 | alle | Tab „Heute“ öffnen | Höchstens **drei** Termine in der Karte der anstehenden Termine; daneben die Schaltfläche „Alle Termine“ | `RT-B-01_<Pl>.png` | | |
| RT-B-02 | alle | „Alle Termine“ antippen | Kalender öffnet sich mit allen Terminen; Zurück führt auf „Heute“ | `RT-B-02_<Pl>.png` | | |
| RT-B-03 | iOS, Mac, And, AndT, Win, Lin | Auf „Heute“ die Karte „Erinnerungen“ ansehen und antippen | Übersicht „Erinnerungen“ öffnet sich mit den Abschnitten „Fällig (n)“ und „Geplant (n)“; Hinweis „Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.“ | `RT-B-03_<Pl>.png` | | |
| RT-B-04 | iOS, Mac, And, AndT, Win, Lin | Den Termin mit der Erinnerung abwarten, bis sie fällig ist (Gerät entsperrt, App im Vordergrund oder Hintergrund) | Systemmeldung „Erinnerung“ / „Termin in …“ ohne Titel und Ort; auf „Heute“ zeigt die Karte „1 Erinnerung fällig“ | `RT-B-04_<Pl>.png` (Meldung), `RT-B-04b_<Pl>.png` (Karte) | | |
| RT-B-05 | iOS, Mac, And, AndT, Win, Lin | In der Übersicht die fällige Erinnerung bestätigen (Aktion „Erinnerung an … bestätigen“) | Eintrag wandert aus „Fällig“ heraus, Karte zeigt „Keine Erinnerung fällig“ bzw. eine geringere Zahl; „Alle bestätigen“ leert „Fällig“ | `RT-B-05_<Pl>.png` | | |
| RT-B-06 | iOS, Mac, And, AndT, Win, Lin | Zwei weitere Erinnerungen fällig werden lassen, App beenden und neu starten | Fällige Erinnerungen bleiben fällig (nicht verloren); „Geplant (n)“ stimmt mit der Anzahl der künftigen Erinnerungen überein | `RT-B-06_<Pl>.png` | | |
| RT-B-07 | Win, Lin | Erinnerung neu planen (Termin bearbeiten, Startzeit in die nahe Zukunft) nachdem eine fällig war | Die zuvor fällige Erinnerung wird nicht erneut als neu fällig gemeldet (#196); neue Zeit wird unter „Geplant“ geführt | `RT-B-07_<Pl>.png` | | |
| RT-B-08 | Web | „Heute“ und Einstellungen im Browser ansehen | Keine Karte „Erinnerungen“, keine Erinnerungs-Einstellungen, Datenschutz nennt keine Erinnerungen auf diesem Gerät | `RT-B-08_Web.png` | | |

### C. Chat (#254 Teil A, #139, #173, #224, #231, #132, #236, #239)

Vorbedingung: G1 = N1, G2 = I2 (Familie, Beitritt abgeschlossen, siehe Abschnitt E). Chat-Tab auf G1 geöffnet.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-C-01 | alle | G2 sendet „Hallo“; auf G1 im Chat ansehen | Nachricht mit **Datum und Uhrzeit** (Datumstrennzeile „Heute“, Uhrzeit an der Nachricht); Maus bzw. Langdruck auf die Uhrzeit zeigt das volle Datum | `RT-C-01_<Pl>.png` | | |
| RT-C-02 | alle | G1 wechselt auf den Tab „Heute“. G2 sendet zwei Nachrichten. G1 öffnet den Chat | Marke **„Neue Nachrichten“** über der ersten ungelesenen Nachricht, darüber die zuvor gelesene | `RT-C-02_<Pl>.png` | | |
| RT-C-03 | alle | G1 wechselt auf einen anderen Tab und wieder zurück zum Chat | Marke ist verschwunden (alles gelesen) | `RT-C-03_<Pl>.png` | | |
| RT-C-04 | alle | G2 sendet eine Nachricht mit mehr als vier Zeilen. G1 antwortet darauf (Antworten auf diese Nachricht) | Antwortleiste „Antwort an …“ zeigt die Vorschau einzeilig; gesendete Antwort enthält ein **Zitat** mit Absender, auf **vier Zeilen** eingekürzt, mit „Mehr anzeigen“ | `RT-C-04_<Pl>.png` | | |
| RT-C-05 | alle | „Mehr anzeigen“ antippen, danach „Weniger anzeigen“ | Aufgeklappt alle Zeilen, danach wieder vier Zeilen; Fokus im Eingabefeld bleibt erhalten | `RT-C-05_<Pl>.png` | | |
| RT-C-06 | alle | An einer gesendeten Nachricht reagieren („Reagieren“, 👍) | Reaktion erscheint bei der Nachricht; auf G2 nach Abgleich ebenfalls | `RT-C-06_<Pl>.png`, `RT-C-06_G2_<Pl>.png` | | |
| RT-C-07 | alle | Auf eine noch nicht gesendete Nachricht (Netz aus, Nachricht wartet) reagieren versuchen | Die Aktion „Reagieren“ wird für nicht gesendete Nachrichten **nicht angeboten** | `RT-C-07_<Pl>.png` | | |
| RT-C-08 | alle | Foto an eine Nachricht anhängen und senden; mehrere Nachrichten schicken, nach oben und unten scrollen | Das Bild bleibt an **seiner** Nachricht (verrutscht nicht auf eine andere) | `RT-C-08_<Pl>.png` | | |
| RT-C-09 | And, AndT, iOS | Netz trennen (Flugmodus), Nachricht senden, Netz nach etwa einer Minute wieder verbinden | Nachricht zeigt „wird gesendet/fehlgeschlagen“ und wird nach Pause erneut gesendet; nach Verbindung ist sie auf G2 vorhanden, nicht doppelt | `RT-C-09_<Pl>.png`, `RT-C-09b_<Pl>.png` | | |
| RT-C-10 | alle | Im Chat 4000 Zeichen einfügen (Text mit 👨‍👩‍👧 als zusammengesetztem Emoji am Ende) | Zähler und Begrenzung zählen Emojis richtig; Senden gelingt bis zur erlaubten Länge, darüber wird die Eingabe begrenzt (keine Fehlermeldung nach dem Senden) | `RT-C-10_<Pl>.png` | | |

### D. Meldungen und Zahl am App-Symbol (#254 Teil B, E-88)

Vorbedingung: Einstellungen → Benachrichtigungen: „Neue Chat-Nachrichten“ und „Neue Einträge auf dem Einkaufszettel“ an. G1 meldet sich so, dass die App **nicht** im sichtbaren Chat ist (anderer Tab oder Hintergrund). G2 sendet. Hinweis in den Einstellungen: „Meldungen ohne Inhalt, nur solange die App läuft. Ist die App beendet, kommt keine Meldung (es gibt keinen Push-Dienst).“

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-D-01 | iOS, Mac, And, AndT, Win, Lin | Einstellungen → Benachrichtigungen öffnen | Schalter „Neue Chat-Nachrichten“ und „Neue Einträge auf dem Einkaufszettel“, Hinweis zur laufenden App | `RT-D-01_<Pl>.png` | | |
| RT-D-02 | iOS, Mac | Beim ersten Einschalten die Berechtigungsabfrage des Systems | Systemdialog fragt nach Benachrichtigungen und Kennzeichen am App-Symbol; nach „Erlauben“ bleibt der Schalter an | `RT-D-02_<Pl>.png` | | |
| RT-D-03 | iOS, Mac, And, AndT, Win, Lin | G2 sendet „Test“ in den Chat | Systemmeldung „FamilyNexus – Neue Nachrichten“ **ohne** Absender und Text | `RT-D-03_<Pl>.png` | | |
| RT-D-04 | iOS, Mac, Win, Lin | Zahl am App-Symbol nach RT-D-03 ansehen (iOS/Mac: Kennzeichen am Symbol; Win: Overlay in der Taskleiste; Lin: Dock/Launcher, sofern angezeigt) | Zahl entspricht der Anzahl ungelesener Nachrichten (1); nach zweiter Nachricht 2 | `RT-D-04_<Pl>.png` | | |
| RT-D-05 | iOS, Mac, Win, Lin | Chat öffnen | Zahl am Symbol geht auf 0, Meldung wird zurückgezogen | `RT-D-05_<Pl>.png` | | |
| RT-D-06 | iOS, Mac, And, AndT, Win, Lin | G2 trägt einen Artikel in den Einkauf ein, G1 steht auf dem Tab „Heute“ | Systemmeldung „Neue Einträge auf dem Einkaufszettel“ ohne Artikelnamen | `RT-D-06_<Pl>.png` | | |
| RT-D-07 | iOS, Mac, And, AndT, Win, Lin | Schalter „Neue Chat-Nachrichten“ ausschalten, G2 sendet erneut | Keine Meldung, Zahl am Symbol bleibt 0 bzw. steigt nicht (je nach Plattform dokumentieren) | `RT-D-07_<Pl>.png` | | |
| RT-D-08 | And, AndT | **App im Hintergrund** lassen (Home-Taste), G2 sendet | Meldung erscheint im Hintergrund. **Bekannter Befund #273** (Netz nach 5 s gesperrt, Meldungen im Hintergrund fehlen): Ergebnis genau festhalten, Abweichung als ⚠️/❌ mit Verweis auf #273 | `RT-D-08_<Pl>.png` | | |
| RT-D-09 | Web | Einstellungen im Browser | Keine Benachrichtigungsschalter bzw. kein Hinweis auf Systemmeldungen | `RT-D-09_Web.png` | | |

### E. Beitritt durch Moderator, Einladungslink v4 (#118, #115, E-78, E-79)

Vorbedingung: N1 Moderator auf G1, I2 neues Konto auf G2.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-E-01 | alle (G1) | Familie → Einladen: Einladungslink erzeugen und in eine Textdatei kopieren (Link schwärzen für den Beleg) | Link wird angezeigt; Link enthält den **Familiennamen nicht** im Klartext und Namen und Server nicht lesbar (kodiert) | `RT-E-01_<Pl>.png` | | |
| RT-E-02 | alle (G2) | Link auf G2 öffnen bzw. einfügen, Konto anlegen und beitreten | Karte: „Fast geschafft! … muss dich noch bestätigen. Sag kurz Bescheid – du kannst die App so lange schließen.“ | `RT-E-02_G2_<Pl>.png` | | |
| RT-E-03 | alle (G1) | Familie → „Beitrittsanfragen“ ansehen | Eintrag „… möchte beitreten“ mit Prüfung („Gültiger Einladungslink“) und Schaltflächen „Bestätigen“ und „Ablehnen“. **Jeder** Beitritt per Link verlangt Bestätigung | `RT-E-03_<Pl>.png` | | |
| RT-E-04 | alle (G1) | „Bestätigen“ antippen | Rückfrage „… in die Familie aufnehmen? Der Einladungslink wird dabei verbraucht.“ → bestätigen | `RT-E-04_<Pl>.png` | | |
| RT-E-05 | alle (G2) | Nach Abgleich Familie auf G2 ansehen | G2 ist in der Familie, Mitgliederliste zeigt beide | `RT-E-05_G2_<Pl>.png` | | |
| RT-E-06 | alle | Zweiten Link erzeugen, mit einem weiteren Konto N3 öffnen, Moderator wählt „Ablehnen“ | Anfrage verschwindet, N3 sieht eine Ablehnung bzw. bleibt ohne Zugang | `RT-E-06_<Pl>.png` | | |
| RT-E-07 | alle | Link, der bereits verwendet wurde, erneut verwenden | Anfrage zeigt „Unbekannter oder bereits verwendeter Link“ bzw. „Link abgelaufen …“, Bestätigen nicht ohne Warnung möglich | `RT-E-07_<Pl>.png` | | |

### F. Passwort und Anmeldung in der App (#117, #268, E-80, E-91)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-F-01 | alle | Neues Konto anlegen: Passwort und „Passwort wiederholen“ mit **unterschiedlichen** Werten eingeben | Meldung „Die Passwörter stimmen nicht überein.“, Weiter nicht möglich | `RT-F-01_<Pl>.png` | | |
| RT-F-02 | alle | Passwort kürzer als 8 Zeichen eingeben | Meldung „Das Passwort braucht mindestens 8 Zeichen.“ | `RT-F-02_<Pl>.png` | | |
| RT-F-03 | alle | Mit gleichen Passwörtern fortfahren, Augensymbol „Passwort anzeigen“ testen | Konto wird angelegt, Passwortfeld lässt sich anzeigen/verbergen | `RT-F-03_<Pl>.png` | | |
| RT-F-04 | alle | Einstellungen → Konto → „Passwort ändern“ öffnen | Dialog mit „Aktuelles Passwort“, „Neues Passwort“, Wiederholung, Schalter „Andere Geräte abmelden“ | `RT-F-04_<Pl>.png` | | |
| RT-F-05 | alle | Falsches aktuelles Passwort eingeben | Meldung „Das aktuelle Passwort stimmt nicht.“ | `RT-F-05_<Pl>.png` | | |
| RT-F-06 | alle | Neues Passwort gleich dem alten eingeben | Meldung „Das neue Passwort muss sich vom aktuellen unterscheiden.“ | `RT-F-06_<Pl>.png` | | |
| RT-F-07 | alle | Gültige Änderung mit „Andere Geräte abmelden“ an | „Passwort geändert.“; auf G2 muss danach mit dem neuen Passwort neu angemeldet werden | `RT-F-07_<Pl>.png`, `RT-F-07_G2_<Pl>.png` | | |
| RT-F-08 | alle | Abmelden (bzw. Daten löschen) und mit **neuem** Passwort anmelden | Anmeldung gelingt mit dem neuen, scheitert mit dem alten („Benutzername oder Passwort stimmen nicht.“) | `RT-F-08_<Pl>.png` | | |
| RT-F-09 | alle | Anmeldung am eigenen Testserver (Passwort-Anmeldung) | Anmeldung erfolgt **in der App**, es öffnet sich kein externer Browser | `RT-F-09_<Pl>.png` | | |
| RT-F-10 | iOS, Mac | Anbieter mit Browser-Anmeldung (matrix.org, **nur mit Freigabe** und eigenem Konto): „Anmelden“ | System-Sitzung (ASWebAuthenticationSession) öffnet sich als Fenster der App, Hinweis „Bitte auf der Seite von … fortfahren …“; nach Abschluss kehrt die App automatisch zurück. Auf dem Mac ohne Loopback (`network.server` nicht nötig) | `RT-F-10_<Pl>.png` | | |
| RT-F-11 | And, AndT | wie RT-F-10 (matrix.org, nur mit Freigabe) | Custom Tab im Standardbrowser, danach Rückkehr in die App; auf einem Gerät ohne Custom-Tab-Browser Rückfall auf den externen Browser | `RT-F-11_<Pl>.png` | | |
| RT-F-12 | Win, Lin, Web | wie RT-F-10 (nur mit Freigabe) | Externer Browser (kein In-App-Fenster), Rückkehr über Loopback bzw. Weiterleitung | `RT-F-12_<Pl>.png` | | |
| RT-F-13 | iOS, Mac, And, AndT | Konto löschen bei einem Anbieter mit Browser-Seite (nur mit Freigabe): „Konto löschen“ | Hinweis „Bestätige die Löschung auf der Seite des Anbieters, schließe sie … und kehre dann hierher zurück“; Seite öffnet in der App-Sitzung | `RT-F-13_<Pl>.png` | | |

### G. Anbieter-Adresse, Protokoll, Löschen (#259, #261, #271, #272)

Vorbedingung: Testserver, bei dem die eingegebene Anbieter-Adresse vom Matrix-ID-Servernamen abweicht (`.well-known`-Umleitung), z. B. Caddy 18449 → Synapse 18448 (Aufbau siehe Issue #259) oder der Testserver `matrix-synapse-3ues…` / `matrix.chaostribunal.de`. Konto frisch angemeldet **nach** dem Update (eine vorher angemeldete Sitzung zeigt bis zur nächsten Anmeldung den alten Server).

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-G-01 | alle | Einstellungen → Konto → „Server“ | Zeigt die **eingegebene Anbieter-Adresse**, nicht den Servernamen der Matrix-ID | `RT-G-01_<Pl>.png` | | |
| RT-G-02 | alle | Einstellungen → Über die App → Speicherorte | „Online beim Matrix-Anbieter …“ nennt die eingegebene Adresse | `RT-G-02_<Pl>.png` | | |
| RT-G-03 | alle | „Konto löschen“ antippen (Dialog nur ansehen, abbrechen) | Dialogtext nennt die eingegebene Adresse, nicht den aufgelösten Homeserver | `RT-G-03_<Pl>.png` | | |
| RT-G-04 | alle | Einstellungen → Datenprotokoll anzeigen | Protokoll enthält den **eigenen Anzeigenamen** (nicht nur die Matrix-ID); der aufgelöste Homeserver steht nur hier | `RT-G-04_<Pl>.png` | | |
| RT-G-05 | Web | Anbieter-Prüfung mit einem Server, dessen `/.well-known/matrix/support` **ohne CORS** antwortet | Meldung „nicht erreichbar“ erscheint **nicht**; die Prüfung geht weiter, Konto kann angelegt werden | `RT-G-05_Web.png` | | |
| RT-G-06 | alle | Einstellungen → „Alle lokalen Daten löschen“ bestätigen und dabei den Netzverkehr beobachten (z. B. Proxy oder `tcpdump`; ohne Werkzeug nur Anzeige prüfen) | Danach **direkt** die Willkommensseite, **keine** kurz aufblitzende Anmeldeseite, keine Anfrage an matrix.org | `RT-G-06_<Pl>.png`, Verkehrsprotokoll `RT-G-06_<Pl>.txt` | | |

### H. Datum, Uhrzeit, Termin-Editor, Zeitwähler (#260, #162, #163, #264, #263)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-H-01 | alle | Kalender → Termin am 3. November anlegen, Datum im Editor und in der Detailansicht ansehen | Datum mit **führender Null**: „03.11.2026“ (nicht „3.11.2026“) | `RT-H-01_<Pl>.png` | | |
| RT-H-02 | alle | Gerät auf 24-Stunden-Anzeige stellen, Uhrzeiten in Kalender, Chat, Aufgaben (Erledigt-Zeit) und Schlüsseldatei-Datum ansehen | Alle Uhrzeiten im 24-Stunden-Format, Datumsformat folgt der App-Sprache | `RT-H-02_<Pl>.png` | | |
| RT-H-03 | alle | Gerät auf 12-Stunden-Anzeige umstellen (App neu starten) | Alle Uhrzeiten im 12-Stunden-Format mit AM/PM | `RT-H-03_<Pl>.png` | | |
| RT-H-04 | alle | Aufgabe in einer Liste mit anderer Zeitzone abhaken (Liste mit Zeitzone „Pacific/Auckland“) | Erledigt-Uhrzeit steht in der **Zeitzone der Liste**, nicht des Geräts | `RT-H-04_<Pl>.png` | | |
| RT-H-05 | alle | Termin-Editor, Beginn nach 22:00 Uhr wählen, „Ganztägig“ einschalten | Der Termin endet am **selben Tag** (keine Spanne von zwei Tagen) | `RT-H-05_<Pl>.png` | | |
| RT-H-06 | Win, Mac, Lin | Termin-Editor → Beginn → Zeitwähler → Tastatur-Symbol. Mit der Maus in das Feld „Stunde“ klicken, `2`, `1` tippen, dann `3`, `0` | Stunde **21**, Fokus springt in die Minuten, Minuten **30**; der markierte Wert wird ersetzt (kein „12“/„22“) | `RT-H-06_<Pl>.png` | | |
| RT-H-07 | Win, Mac, Lin | Zeitwähler zweimal öffnen, jeweils in „Stunde“ und „Minute“ klicken | Beim Klick ist der ganze Wert markiert; Titelfeld bleibt unberührt | `RT-H-07_<Pl>.png` | | |
| RT-H-08 | iOS, And, AndT | Zeitwähler auf dem Touchgerät bedienen (Tastatur-Symbol, Ziffern) | Verhalten unverändert wie vor 1.2.2 (Eingabe nimmt die Ziffern an); keine Markierung beim Antippen | `RT-H-08_<Pl>.png` | | |

### I. Familie: Wechsel, Mitgliederliste, Fehleransicht, Start (#140, #135, #198, #175, #154)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-I-01 | alle | Konto N1 in Familie A mit Terminen, Chat und Einkauf; Familie wechseln (Familie verlassen und der Familie B beitreten) ohne die App zu beenden | Nach dem Wechsel zeigt die App **nur** Daten der neuen Familie; keine Termine, Nachrichten oder Einkaufseinträge der alten | `RT-I-01a_<Pl>.png` (alt), `RT-I-01b_<Pl>.png` (neu) | | |
| RT-I-02 | alle | Netz trennen, App starten, Familie → Mitgliederliste öffnen | Abruf scheitert (Hinweis); nach Netz ein und kurzer Wartezeit lädt die Liste **von selbst nach**, ohne App-Neustart | `RT-I-02_<Pl>.png`, `RT-I-02b_<Pl>.png` | | |
| RT-I-03 | alle | Server stoppen (`tool/synapse/down.sh`) und App im Hauptfenster öffnen | Statt leerer Ansicht erscheint eine **Fehleransicht mit „Erneut versuchen“** | `RT-I-03_<Pl>.png` | | |
| RT-I-04 | alle | Server wieder starten, „Erneut versuchen“ antippen | Hauptansicht lädt und zeigt die Familie | `RT-I-04_<Pl>.png` | | |
| RT-I-05 | alle | App beim Start gegen einen nicht erreichbaren Server öffnen (Netz aus) | App zeigt Hinweis, **löscht keine Familiendaten**; nach Netz ein sind Termine, Chat, Einkauf unverändert da | `RT-I-05_<Pl>.png`, `RT-I-05b_<Pl>.png` | | |
| RT-I-06 | alle | Einladen per ID: gültige ID eingeben, Einladung senden | Eingabefeld wird **nur nach Erfolg** geleert; bei Fehler (falsche ID) bleibt der Text stehen | `RT-I-06_<Pl>.png` | | |

### J. Texte und Datenschutz je Plattform (#143, #144, #146, #160, #169, #237, #225, #159, #162)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-J-01 | alle | Willkommensseite lesen | Text sagt **nicht**, private Termine verließen nie die eigenen Geräte; er beschreibt, dass sie verschlüsselt zwischen den eigenen Geräten laufen | `RT-J-01_<Pl>.png` | | |
| RT-J-02 | iOS, iPad | Einstellungen → Bildschirmschutz | Hinweis: „Verdeckt die App im App-Umschalter und bei Bildschirmaufnahmen. Einzelne Screenshots lassen sich unter iOS nicht verhindern.“ Screenshot per Seitentaste gelingt; App-Umschalter zeigt die App verdeckt | `RT-J-02_<Pl>.png`, `RT-J-02b_<Pl>.png` | | |
| RT-J-03 | And, AndT | Bildschirmschutz an: Hinweis „Blockiert Screenshots und verbirgt die App in der Übersicht.“ Systemscreenshot mit Gerätetaste versuchen | Screenshot wird blockiert oder schwarz; App-Übersicht verdeckt die App | `RT-J-03_<Pl>.png` | | |
| RT-J-04 | Win | Bildschirmschutz an: Hinweis „Nimmt die App von Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben aus.“ Screenshot/Aufnahme versuchen; mit Alt-Tab beobachten | Fenster fehlt im Screenshot und in der Aufnahme (oder ist schwarz); Verhalten bei Alt-Tab notieren | `RT-J-04_<Pl>.png` | | |
| RT-J-05 | Mac, Lin, Web | Einstellungen ansehen | **Kein** Schalter „Bildschirmschutz“ (nicht angeboten) | `RT-J-05_<Pl>.png` | | |
| RT-J-06 | alle | Einstellungen → Datenschutzerklärung | Abschnitt 6 (Berechtigungen) und Abschnitt zur Schlüsselablage nennen die Angaben **dieser** Plattform (Android: Benachrichtigungen, genaue Alarme, Neustart-Meldung; Apple: Benachrichtigungen und Kennzeichen am Symbol; Linux/Flatpak: Secret-Portal) | `RT-J-06_<Pl>.png` | | |
| RT-J-07 | Lin | Einstellungen → Über die App → Speicherorte | Nennt die Ablage im **Secret-Portal** | `RT-J-07_Lin.png` | | |
| RT-J-08 | Web | Datenschutzerklärung und Einstellungen → Löschen | Datenschutz nennt SQLite3MultipleCiphers und keine Erinnerungen; Hinweis beim Löschen nennt keine Erinnerungen auf diesem Gerät | `RT-J-08_Web.png` | | |
| RT-J-09 | alle | Einstellungen → Metadaten/eigener Server (Abschnitte zu Metadaten und eigenem Server) | Aussagen stimmen mit der Datenschutzerklärung überein; keine Zusage, die der Text der Erklärung widerspricht | `RT-J-09_<Pl>.png` | | |
| RT-J-10 | alle | Datenprotokoll kopieren | Hinweis „Protokoll kopiert. Die App versucht, die Zwischenablage nach einer Minute zu leeren. Lösche sie im Zweifel selbst.“ | `RT-J-10_<Pl>.png` | | |

### K. Web (#137, #266, #154, #227, #240, #249)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-K-01 | Web | Frischen Browserprofil, App öffnen, Tresor-Passwort anlegen, App neu laden | Nach dem Anlegen erscheint **„Willkommen bei FamilyNexus“**, nicht „Lokale Daten nicht lesbar“ | `RT-K-01_Web.png` | | |
| RT-K-02 | Web | Neu laden und Tresor mit richtigem Passwort entsperren | Entsperren gelingt, Anmeldung bleibt erhalten | `RT-K-02_Web.png` | | |
| RT-K-03 | Web | Falsches Tresor-Passwort eingeben | „Falsches Passwort.“ | `RT-K-03_Web.png` | | |
| RT-K-04 | Web | Einstellungen → „Alle lokalen Daten löschen“, Knopf ansehen | Knopf zeigt während des Löschens **„Wird gelöscht …“** | `RT-K-04_Web.png` | | |
| RT-K-05 | Web | Nach dem Löschen im selben Tab die App erneut starten | Tab meldet **nicht** „schon geöffnet“ (eigene Tab-Sperre wird erkannt), Start gelingt | `RT-K-05_Web.png` | | |
| RT-K-06 | Web | Tresor-Passwort vergessen: „Passwort vergessen? Alle lokalen Daten löschen“ | Löschen läuft durch, danach Willkommensseite | `RT-K-06_Web.png` | | |
| RT-K-07 | Web | Tresorfehler provozieren (Browserspeicher des Tresors manuell beschädigen oder Speicher blockieren) | Eine **Meldung** erscheint, kein stiller Abbruch | `RT-K-07_Web.png` | | |
| RT-K-08 | Web | `python3 tool/web_smoke.py` (Rauchtest) gegen den Web-Build | 5 von 5 Prüfungen bestanden | `RT-K-08_Web.txt` (Ausgabe) | | |

### L. Tablet und große Fenster (#274, REQ-TABLET-01, E-92)

Für jeden Schritt gilt: Fenstergröße/Gerät notieren. Klassen: **compact** (Breite < 600 oder Höhe < 480) mit unterer Leiste; **medium** (600 bis < 1000) mit seitlicher Rail; **expanded** (≥ 1000) mit Rail und Zweispalter Kalender/Chat.

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-L-01 | iPad | App auf dem iPad-Air 13" im Hochformat (ca. 1032 × 1376) starten, anmelden | App füllt den Bildschirm (kein schmaler Streifen), seitliche Rail links, Inhalt höchstens 720 breit | `RT-L-01_iPad-hoch.png` | | |
| RT-L-02 | iPad | Querformat (Drehen) | Rail plus Zweispalter: Kalender links, Chat rechts mit Trenner; Heute/Einkauf/Familie einspaltig | `RT-L-02_iPad-quer.png` | | |
| RT-L-03 | iPad | Alle vier Ausrichtungen nacheinander | Layout folgt jeder Ausrichtung; Kalender- und Chat-Zustand bleiben beim Drehen erhalten (Entwurf im Chat, gewählter Tag) | `RT-L-03_<Ausrichtung>.png` | | |
| RT-L-04 | iPad | Split View: App mit einer zweiten App nebeneinander (Slide Over und Stage Manager sofern verfügbar) | Fenster wird so breit/schmal wie zugewiesen; bei < 600 Breite untere Leiste, bei ≥ 600 Rail; kein Layoutüberlauf | `RT-L-04_<Modus>.png` | | |
| RT-L-05 | AndT | Android-Tablet (Hoch- und Querformat) | Wie iPad: Rail ab 600 dp, Zweispalter ab 1000 dp | `RT-L-05_AndT-hoch.png`, `RT-L-05_AndT-quer.png` | | |
| RT-L-06 | AndT | Rotationssperre des Systems einschalten und drehen | Die App folgt der Sperre (keine eigene Erzwingung) | `RT-L-06_AndT.png` | | |
| RT-L-07 | AndT | Multi-Window: App im geteilten Bildschirm, Trennlinie verschieben | Layout wechselt zwischen compact und medium je nach Breite, ohne Absturz oder Zustandsverlust | `RT-L-07_AndT.png` | | |
| RT-L-08 | Mac, Win, Lin | Fenster auf 599, 600, 999 und 1000 Pixel Breite ziehen | 599: untere Leiste; 600: Rail; 999: Rail einspaltig; 1000: Zweispalter | `RT-L-08_<Breite>_<Pl>.png` (4 Dateien) | | |
| RT-L-09 | iPad, AndT, Mac, Win, Lin | Im Zweispalter im Chat eine Nachricht schreiben, Bildschirmtastatur (iPad/AndT) eingeblendet | Das Layout **kippt nicht** (bleibt Zweispalter), Eingabezeile sichtbar über der Tastatur | `RT-L-09_<Pl>.png` | | |
| RT-L-10 | iPad, AndT | Systemschrift auf 200 % stellen, Heute, Kalender, Einstellungen und Sperrbildschirm ansehen | Kein Layoutüberlauf (gelb-schwarze Streifen); Kartenkopf-Aktion rutscht unter den Titel; Einstellungs-Auswahlfelder stehen unter dem Titel | `RT-L-10_<Ansicht>_<Pl>.png` | | |
| RT-L-11 | iOS, And | Telefon mit 390 dp Breite (Hochformat) | Unverändert wie vor 1.2.2: untere Leiste, einspaltig; Kartenkopf „Alle Termine“ steht **rechts** am Rand | `RT-L-11_<Pl>.png` | | |
| RT-L-12 | iOS, And | Telefon im Querformat | Compact (Höhe < 480): untere Leiste, einspaltig | `RT-L-12_<Pl>.png` | | |
| RT-L-13 | Mac, Win, Lin | Nur mit Tastatur: Tab durch Heute | Tab geht erst durch den Inhalt der Seite, danach erst in die Rail; verdeckte Seiten sind nicht fokussierbar | `RT-L-13_<Pl>.png` | | |
| RT-L-14 | iPad | **App-Store-Screenshots** für iPad (Hoch- und Querformat) anfertigen | Sechs Screenshots je Format in der geforderten Größe, sauber, ohne Testdaten mit echten Namen | `RT-L-14_<Nr>_<Format>.png` | | |

### M. Emojis und Eingabefelder (#161, #202, #221, #242)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-M-01 | alle | Einkauf: Eintrag „Familie 👨‍👩‍👧“ anlegen | Eintrag wird gespeichert und angezeigt; Emoji vollständig | `RT-M-01_<Pl>.png` | | |
| RT-M-02 | alle | Aufgaben: Aufgabe „Putzen 👩‍👩‍👦“ anlegen | Wird gespeichert | `RT-M-02_<Pl>.png` | | |
| RT-M-03 | alle | Termin-Editor: Titel „Feier 👨‍👩‍👧“ speichern | Wird **abgelehnt** mit Hinweis (zusammengesetzte Emojis sind in Terminen nicht erlaubt) | `RT-M-03_<Pl>.png` | | |
| RT-M-04 | alle | Eingabefeld mit Zeichenbegrenzung: viele Emojis tippen bis zur Grenze | Zähler und Begrenzung zählen Emojis wie die Prüfung beim Speichern; kein Fehler nach „Speichern“ | `RT-M-04_<Pl>.png` | | |
| RT-M-05 | alle | Abbrechen im Speichern-Dialog (z. B. Datenbericht/Notfall-Schlüssel speichern, Dialog abbrechen) | Meldet **nicht** „Gespeichert“ | `RT-M-05_<Pl>.png` | | |

### N. Dateien und iOS-Temp (#141)

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-N-01 | iOS (Simulator) | Notfall-Schlüssel speichern/teilen, Dialog schließen, dann `xcrun simctl get_app_container booted de.inneso.familynexus data` und Temp-Ordner (`tmp/`) auflisten | Keine Klartext-Datei mit dem Schlüssel im Temp-Ordner | `RT-N-01_iOS.txt` (Auflistung) | | |
| RT-N-02 | iOS (Simulator) | Anhang in den Chat senden, anschließend Temp-Ordner auflisten | Keine temporäre Klartext-Kopie des Anhangs | `RT-N-02_iOS.txt` | | |
| RT-N-03 | And | Notfall-Schlüssel speichern; mit `adb shell run-as <Paket> ls cache files` prüfen (Debug-Build) | Keine Klartext-Kopie im Cache | `RT-N-03_And.txt` | | |

### O. Aufräumen

| ID | Pl. | Schritt | Erwartetes Ergebnis | Screenshot | Beob. | Erg. |
|---|---|---|---|---|---|---|
| RT-O-01 | alle | Einstellungen → Konto löschen (Wegwerfkonten) | Dialog ohne unnötige Hinweise; danach Willkommensseite | `RT-O-01_<Pl>.png` | | |
| RT-O-02 | alle | Anmeldung mit dem gelöschten Konto versuchen | `403 M_FORBIDDEN` bzw. „Benutzername oder Passwort stimmen nicht.“ | `RT-O-02_<Pl>.png` | | |
| RT-O-03 | alle | Alle lokalen Daten löschen, App beenden | Willkommensseite beim nächsten Start | `RT-O-03_<Pl>.png` | | |

## 12. Automatische Tests (Pflichtteil, auf Entwicklungsrechner)

| ID | Schritt | Erwartetes Ergebnis | Beleg |
|---|---|---|---|
| RT-T-01 | `flutter analyze` | „No issues found!“ | Ausgabe `RT-T-01.txt` |
| RT-T-02 | `flutter test` | Alle bestanden, übersprungene nur wegen Plattform; bekannter Umgebungsfehler: `test/data/app_badge_test.dart` unter macOS (D-Bus-Socket), auf einem Linux-Host muss er bestehen | Ausgabe `RT-T-02.txt` |
| RT-T-03 | `tool/synapse/up.sh`, dann `curl -fsk https://localhost:18448/_matrix/client/versions` | Meldung „Synapse bereit“, `curl` liefert 200, nie 502 | Ausgabe `RT-T-03.txt` |
| RT-T-04 | `tool/e2e.sh` (Docker, Synapse) | Alle E2E-Tests bestanden | Ausgabe `RT-T-04.txt` |
| RT-T-05 | `tool/synapse/wait_ready_test.sh` | „Alle Fälle bestanden“ | Ausgabe `RT-T-05.txt` |
| RT-T-06 | Release-Review vorhanden (`docs/release-reviews/1.2.2+23.md` zum aktuellen Stand) | Bericht liegt vor, bestätigte Observations sind Issues | `RT-T-06.txt` |

## 13. Regression und Abnahme

1. **Regression:** Vor der Freigabe läuft der Gesamtplan `Testplan_FamilyNexus.md` (TP-FN-001) mindestens auf dem Apple-Paar (G1 = iPhone, G2 = Mac); Ergebnis gehört in den Report.
2. **Report:** Ordner `User E2E Test Report/<JJJJ-MM-TT>_<NN>_Release-1.2.2_Build<NN>/` mit `Testreport.md`, `Ergebnisse.tsv` (Schritt-ID, Ergebnis, Beobachtung), `screenshots/`, `logs/`. Eintrag in `User E2E Test Report/README.md`.
3. **Freigabekriterien:**
   - Kein Schritt ❌ in A bis K und M, N.
   - Alle ⚠️ sind begründet und mit Issue verlinkt (RT-D-08 verweist auf #273).
   - Abschnitt L auf iPad (RT-L-01 bis RT-L-04) und mindestens einem Android-Tablet bestanden, sonst bleibt #274 offen.
   - Nicht durchgeführte Schritte (⏳) stehen mit Grund im Report; was ⏳ ist, gilt **nicht** als bestanden.
   - Pflichtteil (Abschnitt 12) grün (bis auf die dokumentierte Umgebungsausnahme).
4. **Nach dem Lauf:** Ergebnisse in den betroffenen Issues vermerken (#144, #150, #254, #259, #263, #266, #268, #274). Ein Issue schließt, wenn die Abnahme der jeweiligen Schritte bestanden ist, nicht vorher.

## 14. Zuordnung Schritte → Issues

| Issue | Schritte |
|---|---|
| #115, #118 | RT-E-01 bis RT-E-07 |
| #117 | RT-F-01 bis RT-F-08 |
| #131, #132 | RT-C-09 |
| #135, #154, #175, #198 | RT-I-02 bis RT-I-05 |
| #137, #227, #240, #249 | RT-K-04 bis RT-K-06 |
| #139, #224, #231 | RT-C-06, RT-C-07 |
| #140 | RT-I-01 |
| #141 | RT-N-01 bis RT-N-03 |
| #143 | RT-J-01 |
| #144 | RT-J-02 bis RT-J-05 |
| #146, #160, #169, #225, #237 | RT-J-06 bis RT-J-09 |
| #150 | RT-T-02 (automatisch); Messung H-20 im Gesamtplan |
| #156 | RT-I-06 |
| #161, #202, #221, #242 | RT-M-01 bis RT-M-04 |
| #162, #163 | RT-H-02 bis RT-H-04 |
| #173 | RT-C-08 |
| #174 | RT-M-05 |
| #196, #218, #220, #223, #234, #184 | RT-B-01 bis RT-B-08 |
| #211, #217 | RT-A-01 bis RT-A-06 |
| #236, #239 | RT-C-10 |
| #254 | RT-C-01 bis RT-C-05, RT-D-01 bis RT-D-09 |
| #259, #261, #271, #272 | RT-G-01 bis RT-G-06 |
| #260, #264 | RT-H-01, RT-H-05 |
| #263 | RT-H-06 bis RT-H-08 |
| #266 | RT-K-01 bis RT-K-03, RT-K-08 |
| #268 | RT-F-09 bis RT-F-13 |
| #274 | RT-L-01 bis RT-L-14 |
| #281 | RT-T-03, RT-T-05 |

## Versionshistorie

| Version | Datum | Änderung |
|---|---|---|
| v01 | 05.11.2026 | Erste Fassung nach den Release Notes 1.2.2, E-78 bis E-92 und den gemergten Issues des Meilensteins; Soll-Version 1.2.2 (24) |
