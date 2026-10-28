# Testreport TP-FN-001 v1.6 @ f4c358c – Lauf 12 (Windows 11, nur G1-Schritte, Build 1.2.1 (19))

**Abweichung (erste Seite):** Nur G1 (Windows 11) wurde getestet. G2 ist auf diesem Rechner nicht verfügbar (Android-Emulator startet nicht: „Virtualization extension is not supported“, die Maschine ist eine VM). Alle Schritte, die G2 oder ein zweites Konto brauchen (C-01 bis C-04, C-07, C-08, D, E-04 bis E-28, E-30 bis E-32, F-01, F-02), sind **⏳ nicht ausgeführt**. G-Schritte (automatische Tests, G-06, G-07, G-08) wurden nicht ausgeführt. Der Lauf ersetzt keinen Apple-Lauf.

**Wichtig:** Die App lief nur mit **einer lokalen Korrektur** (Befund 1). Der Build aus `main` startet unter Windows sonst nicht. Die Korrektur wurde nach dem Lauf wieder aus dem Arbeitsverzeichnis entfernt; sie liegt als `logs/windows-startfix.diff` bei (enthält zusätzlich eine Diagnose-Ausgabe, die nur der Fehlersuche diente).

## Abschnitt 2

| Angabe | G1 | G2 |
|---|---|---|
| Plattform | Windows | – (nicht verfügbar) |
| Gerät | Windows 11 Pro, VM (AMD Ryzen 9 6900HX) | – |
| Betriebssystem | Windows 11 10.0.26300 | – |
| Installationsquelle | Eigener Build aus `main` (`f4c358c`): `flutter build windows --release` mit Flutter 3.47.7. Aus dem Release v1.2.1 (Build 16) wurden `sqlcipher.dll` und `libcrypto-3-x64.dll` daneben kopiert (lokaler Build enthält sie nicht, sie kommen im Release-Workflow aus vcpkg). Mit lokaler Korrektur (siehe Befund 1) | – |
| App-Version Soll / Ist | 1.2.1 (19) / 1.2.1 (19) | – |
| Gerätesprache, Bildschirmsperre | Deutsch; **keine** gesicherte Bildschirmsperre (PIN/Windows Hello) eingerichtet | – |
| Methode für Screenshots | PowerShell, `CopyFromScreen` auf das App-Fenster (1280 × 720 bzw. 1057 × 817), Bedienung per Skript (Mausklick, SendKeys) | – |
| Tester / Datum / Beginn | Claude Code (automatisiert) für das Team / 28.10.2026 / ca. 22:10, Fortsetzung ab ca. 22:50 | – |

Konten dieses Laufs: Datumsteil **`1028f`** (`1028` bis `1028e` waren durch frühere Läufe belegt). Angelegt wurde nur N1 `fnt-1028f-n1` (Test N1), Familie „Testfamilie 1028f“.

## Zusammenfassung

| Ergebnis | Anzahl |
|---|---|
| ✅ bestanden | 41 |
| ⚠️ bestanden mit Befund | 7 (V-03, V-06, V-07, B-01, B-19, C-03, E-05) |
| ❌ fehlgeschlagen | 2 (V-04 ohne Korrektur, B-10) |
| ⏳ ausgeführt, aber offen | 3 (B-17, E-03, E-29) |
| ⏳ nicht ausgeführt | siehe Liste „Nicht ausgeführt“ |
| n/a | 2 (B-02, B-18) |

(Gezählt sind die Zeilen der Tabellen unten, also nur die auf G1 ausgeführten bzw. dort erwogenen Schritte.)

## Befunde

| Nr. | Schwere | Schritt | Beschreibung |
|---|---|---|---|
| 1 | **hoch** | V-04 | **Windows-Build startet nicht.** In `LocalReminderScheduler.initialize` (`lib/data/platform/reminder_scheduler.dart`, ca. Zeile 93) fehlt in `InitializationSettings` die Angabe `windows: WindowsInitializationSettings(...)`. Das Plugin wirft beim Start `Invalid argument(s): Windows settings must be set when targeting Windows platform.` (aufgerufen aus `bootstrap.dart:79`). Die App zeigt dazu die irreführende Seite „Lokale Daten nicht lesbar“; „Lokale Daten zurücksetzen“ hilft nicht. Belegt für den lokalen Build 1.2.1 (19) aus `f4c358c`. Der frühere Lauf (Release Build 16) zeigte dasselbe Bild; ob dort dieselbe Ursache vorliegt, wurde nicht geprüft. Mit `windows: WindowsInitializationSettings(appName: 'FamilyNexus', appUserModelId: 'de.inneso.FamilyNexus', guid: '<feste GUID>')` startet die App (Diff in `logs/windows-startfix.diff`). Die Meldung „Lokale Daten nicht lesbar“ sollte außerdem zwischen Datenbankfehler und anderen Startfehlern unterscheiden. Es besteht kein Zusammenhang mit VM/Datenbank, entgegen der Vermutung im Lauf vom Vormittag. |
| 2 | mittel | B-10 | **Erinnerung kam nicht an.** Termin „Test Erinnerung“ 23:21, Standard-Erinnerung 10 Min., App minimiert, Bildschirm von 23:10:57 bis 23:13:49 alle 20 s aufgenommen: keine Benachrichtigung zu sehen (erwartet ab ca. 23:11). Ursache offen. Naheliegend: `appUserModelId` ist ohne Installation/Verknüpfung nicht registriert (der Code beschreibt das selbst: „Planung braucht eine registrierte App-Kennung“), oder Fokus-Assistent unterdrückt Toasts; beides nicht geprüft |
| 3 | niedrig | E-05 | „Per E-Mail senden“ öffnet auf diesem Rechner nichts und zeigt keine Meldung („Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.“ erwartet). Es ist unklar, ob kein Mailprogramm eingerichtet ist (dann fehlt die Meldung) oder ob die Aktion nicht auslöst |
| 4 | niedrig | B-01 | Schaltfläche „Neuer Termin“ ist nur ein „+“-Symbol (kein Text); der Plan nennt „Neuer Termin“ |
| 5 | Hinweis | V-03 | Lokaler Windows-Build braucht Entwicklermodus (Symlinks) und die Visual-Studio-Komponente „C++ ATL“ (`atlstr.h`); beides musste nachgerüstet werden. `sqlcipher.dll` und `libcrypto-3-x64.dll` fehlen im lokalen Build und wurden aus dem Release kopiert (ohne sie startet die App nicht) |
| 6 | Hinweis | B-17 | Ohne eingerichtete Bildschirmsperre zeigt die App „Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.“ (erwartet). Das Entsperren selbst konnte nicht geprüft werden |

## Vorbereitung

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| V-01 | `main` = `f4c358c`, `version: 1.2.1+19` | – | ✅ |
| V-02 | `familynexus.exe` ProductVersion `1.2.1+19`; App zeigt „Version 1.2.1 (19)“ | B-22a-G1 | ✅ |
| V-03 | Neuer lokaler Build, Release-Dateien v1.2.1 sind Build 16 und nicht Soll. Zusatzschritte siehe Befund 5; mit Korrektur aus Befund 1 | – | ⚠️ |
| V-04 | Ohne Korrektur: „Lokale Daten nicht lesbar“ auch mit frischen Datenordnern (Befund 1). Mit Korrektur: nach Neustart „Willkommen“ mit drei Wegen. Datenordner vor dem Lauf umbenannt (`de.inneso.familynexus.bak<hhmmss>`, `inneso.bak<hhmmss>`), nicht gelöscht | V-04-G1a, V-04-G1b, V-04-G1c (Fehlerseite), V-04-G1d (Willkommen) | ❌ (ohne Korrektur) |
| V-05 | `versions` vorhanden, Registrierung `m.login.dummy` | – | ✅ |
| V-06 | `1028` bis `1028e` belegt (n1, n12, i2); `1028f` für alle vier Namen frei | – | ⚠️ |
| V-07 | Sprache Deutsch; **keine** Bildschirmsperre eingerichtet (B-17); Benachrichtigungen nicht vorab erlaubt | – | ⚠️ |

## A. Start und Kontoanlage (G1, N1)

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| A-01 | „Willkommen bei FamilyNexus“, drei Wege, drei Hinweise, Sprache „Gerätesprache / Deutsch / English“ | A-01-G1 | ✅ |
| A-02 | English: alle Texte englisch ohne Neustart („Welcome to FamilyNexus“); danach Deutsch | A-02a-G1, A-02b-G1 | ✅ |
| A-03 | „Konto erstellen“, „Schritt 1 von 3“, Text zu matrix.org, „Wie heißt du?“, Schaltfläche „Konto bei matrix.org erstellen“ ausgegraut (nicht angetippt), „Dein Konto liegt bei matrix.org.“ | A-03-G1 | ✅ |
| A-04 | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“, „Konto erstellen“ ausgegraut | A-04-G1 | ✅ |
| A-05 | „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“, Betreiber, „Kontakt: nicht angegeben“, Hinweis zu Metadaten, Felder mit Hinweisen, „Konto erstellen“ ausgegraut | A-05-G1 | ✅ |
| A-06 | `Jörg Müßig` → Benutzername `joerg.muessig`, „Der Benutzername ist frei.“ mit Häkchen | A-06-G1 | ✅ |
| A-07 | Alle sechs Eingaben (`ab`, `Anna`, `anna müller`, `.anna`, `anna.`, 33 × `a`): „Bitte 3 bis 32 Zeichen: …“ in Rot, „Konto erstellen“ ausgegraut | A-07a-G1 … A-07f-G1 | ✅ |
| A-08 | Benutzername `fnt-1028f-n1` bleibt nach Namensänderung; „frei“; 7 Zeichen: ausgegraut, ab 8: aktiv; Augen-Symbol zeigt/verbirgt das Passwort; leerer Name: ausgegraut. Passwort in den Bildern geschwärzt | A-08a-G1 … A-08d-G1 | ✅ |
| A-09 | „Konto erstellen“ → ohne Zusatzschritt direkt „Dein Notfall-Schlüssel“, „Schritt 2 von 3“ | A-09a-G1, A-09b-G1 | ✅ |
| A-10 | Schlüssel erscheint und bleibt nach 20 s stehen; „Kopiert. … Die Zwischenablage wird nach einer Minute geleert.“; „Gespeichert. Bewahre die Datei sicher auf …“ (Datei `C:\fn-test\secure\FamilyNexus-Notfall-Schluessel.txt` mit Konto, Anbieter, Datum, Schlüssel, Anleitung); „Weiter“ erst nach Häkchen aktiv. Schlüssel (KN1) in den Bildern geschwärzt | A-10a … A-10e-G1 | ✅ |
| A-11 | „Fertig! „Testfamilie 1028f“ ist eingerichtet.“ mit „Später“ und „Jetzt einladen“ | A-11-G1 | ✅ |
| A-12 | Hauptansicht „Heute“ | A-12-G1 | ✅ |

## B. Hauptfunktionen mit einem Nutzer (G1, N1)

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| B-01 | Alle sechs Kacheln (Nächste Termine, Erinnerungen, Wer ist online, Einkaufszettel, Aufgaben, Ungelesene Nachrichten), unten fünf Tabs, „Menü öffnen“. Nach B-06 chronologisch: Test Erinnerung (28.10.), Test geteilt 2, Test privat, Test Serie, Test Serie. „Neuer Termin“ nur als „+“ (Befund 4) | A-12-G1, B-01-G1 | ⚠️ |
| B-02 | Windows: kein Hinweis „Benachrichtigungen sind blockiert“, keine Berechtigung; Schritt gehört zu G2 (iOS/Android) | – | n/a |
| B-03 | „Neuer Termin“, Standard „Privat“; bei „Geteilt“: „Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.“; Ort, Notiz, Farbe Himmelblau; Termin „Geteilt“ | B-03a-G1, B-03b-G1 | ✅ |
| B-04 | Ohne Titel: „Bitte einen Titel eingeben.“; Ende vor Beginn und Ende = Beginn: jeweils „Das Ende muss nach dem Beginn liegen.“ direkt unter den Feldern (#34, #56 behoben); nichts gespeichert | B-04a-G1 … B-04c-G1 | ✅ |
| B-05 | Tastatureingabe `21` angenommen (24-Stunden-Format); Ende wandert auf 22:00 am selben Tag; „Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.“; Termin 21:00–22:00 „Privat“ | B-05a-G1, B-05-G1 | ✅ |
| B-06 | „Test Serie“ ganztägig, wöchentlich, endet nach 3: drei Vorkommen im Abstand einer Woche (31.10., 7.11., 14.11.), „Wiederholt“ | B-06a-G1, B-06-G1 | ✅ |
| B-07 | Tag, Woche, Monat, Agenda zeigen die Termine; Navigation und „Heute“ wirken. In der Monatsansicht lag der sichtbare Ausschnitt oberhalb der Termine (nur bis 25.10. sichtbar) | B-07a … B-07e-G1 | ✅ |
| B-08 | Detail mit „Von dir“, Sichtbarkeit, Ort, Notiz; nach dem Speichern sofort „Test geteilt 2“ **und** „10:30 – 11:30“ (#63 behoben); „Verlauf (1)“ zeigt „Test geteilt“ | B-08pre-G1, B-08a-G1, B-08b-G1 | ✅ |
| B-09 | Zusätzlich „30 Minuten vorher“ neben „10 Minuten“ gewählt, „Standard verwenden“ setzt zurück | B-09a-G1, B-09-G1 | ✅ |
| B-10 | Keine Systembenachrichtigung beobachtet (Befund 2) | B-10pre-G1, B-10-G1 | ❌ |
| B-11 | Serie: „Alle Vorkommen oder nur dieses löschen?“ → „Nur dieses“: nur ein Vorkommen weg (Erinnerungen 5 → 4); „Test Erinnerung“: „Diesen Termin wirklich löschen?“ → „Löschen“ | B-11a … B-11c, B-11-G1 | ✅ |
| B-12 | „Ende-zu-Ende-verschlüsselt“; Umschalt+Enter = Zeilenumbruch, Enter sendet; Nachricht „Hallo Testfamilie“ mit Uhrzeit 23:15 | B-12a-G1, B-12-G1 | ✅ |
| B-13 | „Im Chat geteilt“; Karte „Test geteilt 2“ mit Datum und Zusagen/Vielleicht/Absagen im Chat | B-13a-G1, B-13-G1 | ✅ |
| B-14 | „Zu besorgen (2)“; Milch abgehakt → „Erledigt (1)“; „Brot“ per Enter hinzugefügt; Bearbeiten → `Vollkornbrot`, Enter speichert und schließt den Dialog (#68); leerer Eintrag: „Hinzufügen“ ohne Wirkung (versehentlich geöffnetes „Erledigte entfernen“ wurde abgebrochen) | B-14a … B-14c-G1 | ✅ |
| B-15 | „Nur Moderatoren legen Listen an. …“; Liste „Bad putzen“ unter „Mir zugewiesen“, „Wöchentlich“ (Montag), „Nächster Neustart: Montag, 2. November 2026“; Punkt abgehakt mit Kommentar: „1 von 2 erledigt“, „Erledigt am 28.10.2026 um 23:19“, Verlauf „Du · 28.10.2026, 23:19“ (Format TT.MM.JJJJ, #38); leeres Speichern: „Bitte Titel, Person und mindestens einen Punkt angeben.“. Kachel „Aufgaben für dich: 1 offen“ auf „Heute“ wurde nicht ausgewertet (Bild zeigt sie nicht) | B-15a … B-15d-G1 | ✅ |
| B-16 | Sprache, Design (Hell/Dunkel/Wie Gerät), Akzentfarbe (Magenta), „Effekte reduzieren“ wirken sofort; nach Neustart bleiben Design, Akzentfarbe, Konto und Daten erhalten. Danach zurückgesetzt (Design „Wie Gerät“, Türkis, Effekte aus) | B-16a … B-16e-G1 | ✅ |
| B-17 | Schalter „App-Sperre“ lässt sich nicht einschalten: „Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.“ (Befund 6). Sperren und Entsperren **nicht geprüft** | B-17-G1 | ⏳ |
| B-18 | Windows: kein Schalter „Bildschirmschutz“ in „Datenschutz“ (nur „App-Sperre“, „Online-Status teilen“, „Blockierte Mitglieder“) | B-19a-G1 | n/a |
| B-19 | „Online-Status teilen“ an/aus bedient; „Du hast niemanden blockiert.“; Datenschutzerklärung vollständig lesbar. Wirkung des Online-Status (E-15) nicht prüfbar. Die Datenschutzerklärung nennt den „Android-Schlüsselspeicher“ auch unter Windows | B-19a … B-19c-G1 | ⚠️ |
| B-20 | Standard-Erinnerung auf 30 Minuten (10 abgewählt); Text „Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.“ | C-03-G1 | ✅ |
| B-21 | Speicherorte (Windows-Anmeldeinformationsverwaltung); lokales Protokoll mit „App-Version 1.2.1 (19)“, Einstellungen, Warnhinweis Klartext; „Protokoll kopiert.“; Online-Protokoll mit Server, Konto, „Anzeigename: Test N1“, Gerät „FamilyNexus Windows“ | B-21a … B-21d-G1 | ✅ |
| B-22 | Menü und Einstellungen: „Version 1.2.1 (19)“; „Konto“: Server = Anbieter-Adresse, Benutzername `@fnt-1028f-n1:matrix.chaostribunal.de` | B-22a … B-22c-G1 | ✅ |

## C. Geräteprüfung und Notfall-Schlüssel (nur G1-Teile)

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| C-03 | „Dieses Gerät ist verifiziert.“; „Geräte deines Kontos“: „FamilyNexus Windows (Dieses Gerät)“ verifiziert; „Neuen Notfall-Schlüssel erstellen“ vorhanden (nur ein Gerät, G2-Teil offen) | C-03-G1 | ⚠️ |
| C-05 | Seite „Neuer Notfall-Schlüssel“ („Der alte funktioniert danach nicht mehr …“); neuer Schlüssel; Zurück-Pfeil, Esc und Alt+Pfeil links ohne Wirkung; mit Häkchen und „Weiter“ zurück in die Einstellungen. Schlüssel als KN1b abgelegt (`C:\fn-test\secure\KN1b-…`), im Bild geschwärzt | C-05a … C-05f-G1 | ✅ |
| C-06 | (auf G1 statt G2 nach „Alle lokalen Daten löschen“, siehe F-05): alter Schlüssel KN1 → „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“, Gerät bleibt gesperrt | C-06-G1 | ✅ |

## E. Einladung, Familie (nur ohne zweites Konto prüfbar)

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| E-01 | „Testfamilie 1028f“, „Empfehlung: Ernenne einen zweiten Moderator.“, Mitglieder: Test N1 (Moderator, „Du bist online“); „Jemanden einladen“, Familien-Code | E-01-G1 | ✅ |
| E-02 | „Familienname ändern“ → `Testfamilie 1028f neu`, Enter speichert; neuer Name im Tab. (Chat zeigt den Namen erst bei mehreren Gesprächen) | E-02-G1 | ✅ |
| E-03 | Nur `abc`: „Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.“. Einladung selbst nicht ausgeführt (kein N2) | E-03-G1 | ⏳ |
| E-05 | QR-Code, „Gültig für“ 1/3/7 Tage, „Erweitert“ → „Konto-Server für Neue“ mit Anbieter-Adresse, „Neuen Link erzeugen“; „Link kopiert.“ als Häkchen am Knopf im Dialog (#66); kopierter Link: `https://carpeasrael.github.io/FamilyNexus/join/#v=3&room=…&srv=matrix-synapse-3ues.srv1348446.hstgr.cloud&inv=@fnt-1028f-n1:…&exp=…&f=Testfamilie+1028f+neu&by=Test+N1&n=…`. „Per E-Mail senden“: keine sichtbare Reaktion (Befund 3). Link nicht auf G2 geprüft | E-05a … E-05d-G1 | ⚠️ |
| E-29 | Dialog „Konto löschen?“ mit Passwortfeld, „Konto endgültig löschen“ inaktiv ohne Passwort. Hinweis „einziger Moderator“ fehlt, weil N1 **allein** in der Familie ist (vgl. F-06) | E-29-G1 | ⏳ |

## F. Lokale Daten, Löschen, Aufräumen

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| F-03 | „Alle lokalen Daten löschen?“ → „Endgültig löschen“ → sofort „Willkommen“ (nicht „Anmelden“) | F-03a-G1, F-03-G1 | ✅ |
| F-04 | Nach Beenden und Neustart „Willkommen“ (Sprache wieder „Gerätesprache“) | F-04-G1 | ✅ |
| F-05 | „Ich habe schon ein Konto“, Anbieter-Adresse neu eingetragen (nach dem Löschen steht wieder matrix.org), N1 angemeldet, „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; KN1 abgelehnt (C-06), KN1b akzeptiert; Termine (auch private), Chat (Nachricht und Termin-Karte), Einkauf, Aufgabe „Bad putzen“ (1 von 2 erledigt) vom Server wiederhergestellt | F-05a … F-05d-G1 | ✅ |
| F-06 | „Konto löschen?“ nennt `@fnt-1028f-n1:…` und den Server; kein Moderator-Hinweis (allein); mit Passwort → „Willkommen“ | F-06a-G1, F-06b-G1 | ✅ |
| F-07 | Anmeldung `fnt-1028f-n1` per API: HTTP 403 | – (Konsole) | ✅ |
| F-08 | N1 gelöscht (`M_USER_IN_USE`, wie vorgesehen); `n12`, `i2`, `n9` mit Datumsteil `1028f` nie angelegt (frei). Registrierung unverändert offen | – | ✅ |

## Nicht ausgeführt (⏳, Grund: G2 bzw. zweites Konto fehlt)

C-01, C-02, C-04, C-07, C-08 · D-01 bis D-07 · E-04, E-06 bis E-28, E-30 bis E-32 · F-01, F-02 · B-17 (Entsperren), B-10 (Windows-Toast nicht beobachtet, siehe oben) · G-01 bis G-08 (keine automatischen Tests, Review-Notizen, Person ohne Vorwissen, Web).

## Zustand am Ende

- Server: Konto `fnt-1028f-n1` gelöscht. Es existieren keine weiteren Konten dieses Laufs.
- Gerät: App ist beendet und zeigt beim nächsten Start „Willkommen“; lokale Daten sind leer. Alte Datenordner des früheren Laufs liegen unter `%LOCALAPPDATA%\de.inneso.familynexus.bak*` und `%APPDATA%\inneso.bak*`.
- Arbeitsverzeichnis: die temporären Änderungen an `lib/main.dart` und `lib/data/platform/reminder_scheduler.dart` sind zurückgesetzt (`git checkout`); Diff in `logs/windows-startfix.diff`.
- Werkzeuge in `C:\fn-test` (Flutter, Android-SDK, Release-Entpackung); Notfall-Schlüssel-Dateien in `C:\fn-test\secure` (Schlüssel sind ungültig, Konto gelöscht). Build-Ausgabe in `build\windows\x64\runner\Release`.
- System: Windows-Entwicklermodus eingeschaltet und Visual-Studio-Build-Tools um „C++ ATL“ erweitert (auf Wunsch).
- Schwärzung: Passwort (A-08b bis A-08d) und Notfall-Schlüssel (A-10a bis A-10e, C-05b bis C-05e, C-06) in den Bildern geschwärzt. Der kopierte Einladungslink steht hier ohne den Einmal-Code `n=`.
