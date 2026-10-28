# Lauf 1 (G1 = iPhone-Simulator, G2 = MacBook) – 28.10.2026 – TP-FN-001 v1.5 @ bb7f347, Build 1.2.1 (18)

Bedienung per CGEvent-Werkzeug (deutsches Tastaturlayout im Simulator). Passwörter nur lokal (Scratchpad, 600). Datumsteil `1028`.

| ID | Erg. | Beobachtet |
|---|---|---|
| V-01..V-03 | ✅ | Soll 1.2.1+18 = Ist 1.2.1 (18) auf iOS-Simulator (iOS 27.0, iPhone 15 Test) und macOS-Release-Build aus main (bb7f347) |
| V-05/V-06 | ✅ | Registrierung offen (m.login.dummy); Namen 1028 und 1028b frei |
| A-01 | ✅ | Willkommen mit drei Wegen, Hinweisen, Sprachwahl |
| A-02 | ✅ | English/Deutsch wechseln sofort |
| A-03 | ✅ | Konto erstellen, Schritt 1 von 3, matrix.org-Vorschlag |
| A-04 | ✅ | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ |
| A-05 | ✅ | „Dein Konto liegt bei matrix-synapse-3ues…“, Felder, Button ausgegraut |
| A-06 | ✅ | `joerg.muessig`, „Der Benutzername ist frei.“ |
| A-07 | ⚠️ | ab, anna müller, .anna, anna., 33×a: Fehlertext vollständig (2 Zeilen, ohne „…“) → #44 behoben. **`Anna`: Feld zeigt stillschweigend `anna` + „frei“ statt Fehler** (Eingabe wird klein gemacht) → Abweichung zur Erwartung des Nachtests |
| A-08 | ✅ | Benutzername bleibt fnt-1028-n1; 7 Zeichen ausgegraut, 8 aktiv; Auge wirkt. Hinweis: im Passwortfeld gingen im Simulator Großbuchstaben verloren (Passwort daher klein) |
| A-09 | ✅ | Konto ohne Zusatzschritt, Schritt 2 von 3 |
| A-10 | ✅ | Schlüssel bleibt nach 20 s stehen, Kopieren (59 Zeichen), Datei gespeichert („Gespeichert. …“, Dateien-App „Auf meinem iPhone“, Ersetzen bestätigt), Häkchen → Weiter |
| A-11 | ✅ | „Fertig! „Testfamilie 1028“ ist eingerichtet.“ mit Später / Jetzt einladen |
| B-01 | ✅ | Kacheln, Navigation; „Nächste Termine“ chronologisch (#33 ok) |
| B-02 | ✅ | Systemdialog Benachrichtigungen erlaubt |
| B-03 | ✅ | Geteilt-Termin mit Ort/Notiz; Hinweis „Verschlüsselt an die Familie …“ |
| B-04 | ✅ | „Bitte einen Titel eingeben.“; „Das Ende liegt vor dem Beginn.“ direkt bei den Zeitfeldern |
| B-05 | ⚠️ | Privater Termin 21:00–22:00, Ende wandert mit. Beim Neuanlegen von „Test Erinnerung“ blieb Ende = Beginn (01:47–01:47) und wurde gespeichert (Eingabe per Stunden-/Minutenfeld) |
| B-06 | ✅ | Serie ganztägig, wöchentlich, 3 Vorkommen (Kennzeichnung „Wiederholt/Wöchentlich“) |
| B-07 | ✅ | Tag/Woche/Monat/Agenda, Navigation, Heute |
| B-08 | ✅ | Bearbeiten, Verlauf mit früherer Fassung |
| B-09 | ✅ | Erinnerung je Termin, „Standard verwenden“ |
| B-10 | ✅ | Systembenachrichtigung „Erinnerung – Termin in 10 Minuten“ ohne Titel/Ort (Sperrbildschirm, Mi. 28. Okt. 01:38) |
| B-11 | ✅ | „Termin löschen“ → Rückfrage; Serie: „Alle Vorkommen oder nur dieses löschen?“ |
| B-12 | ✅ | Chat-Nachricht gesendet (Simulator: Großbuchstaben in Textfeldern gehen teils verloren, „testfamilie“) |
| B-13 | ✅ | Termin-Karte im Chat |
| B-14 | ✅ | Milch 2 l, Brot, abhaken, bearbeiten → „Vollkornbrot“, Erledigte entfernen mit Rückfrage; leerer Eintrag erzeugt nichts |
| B-15 | ✅ | Liste, Prüfregel „Bitte Titel, Person und mindestens einen Punkt angeben.“, Verlauf mit 28.10.2026, 01:28 (#38 ok) |
| B-16 | ✅ | Sprache (Deutsch/English), Design Hell/Dunkel, Akzentfarbe Magenta/Türkis, Effekte reduzieren |
| B-17 | ✅ | App-Sperre „Sofort“: Face-ID-Abfrage beim Öffnen, Entsperren mit „Authorized with Face ID“ |
| B-18 | ✅ | Bildschirmschutz an: App-Übersicht verbirgt Inhalt; aus: sichtbar |
| B-19 | ✅ | Online-Status-Schalter, „Du hast niemanden blockiert.“ |
| B-20 | ✅ | Standard-Erinnerung wählbar (Mehrfachauswahl) |
| B-21 | ✅ | Speicherorte, lokales Protokoll (Version 1.2.1 (18), Warnhinweis), Kopieren, Online-Protokoll |
| B-22 | ✅ | „Version 1.2.1 (18)“ in Menü und Einstellungen; Server und `@fnt-1028-n1:matrix.chaostribunal.de` |
| G-01 | ✅ | No issues found |
| G-02 | ✅ | 749 bestanden, 44 übersprungen |
| G-03 | ✅ | review_notes_test: All tests passed |

## C. Zweites Gerät (G1 = iPhone-Simulator, G2 = Mac) – nach Freigabe des Schlüsselbunds
| ID | Erg. | Beobachtung |
|---|---|---|
| C-01 | ✅ | Falsches Passwort: „Benutzername oder Passwort stimmen nicht.“ Nach Abmelden steht die Anbieter-Auswahl wieder auf matrix.org (Server wird nicht gemerkt, nur Hinweis) |
| C-02 | ✅ | G1: „@fnt-1028-n1 … möchte die Verifizierung starten.“; Symbole gleich (Büroklammer, Kuchen, Herz, Brille, Brille, Hahn, Herz); beide „Verifiziert.“; Mac zeigt Termine, Einkauf, Chat wie G1 |
| C-03 | ✅ | „Dieses Gerät ist verifiziert.“; Geräte: FamilyNexus iOS und FamilyNexus macOS (Dieses Gerät), beide „Verifiziert“. Auf dem iOS-Gerät stand die Liste kurz nur mit sich selbst (nicht nachgeladen) |
| C-04 | ✅ | Abmelden → direkt „Anmelden“ |
| C-05 | ✅ | Seite „Neuer Notfall-Schlüssel“; Zurück-Pfeil und Wischgeste ohne Wirkung; nach Häkchen und „Weiter“ zurück in den Einstellungen. KN1b in kn1b.txt (600) |
| C-06 | ✅ | Mit KN1: „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“ |
| C-07 | ✅ | Mit KN1b: freigeschaltet, Hauptansicht mit Terminen |
| C-08 | ✅ | Abmelden → „Anmelden“ |

## D. Weitere Wege der Kontoanlage (G2 = Mac, N2; G1 = iPhone-Simulator, N1)
| ID | Erg. | Beobachtung |
|---|---|---|
| D-01 | ✅ | „Schon vergeben – wie wäre es mit „fnt-1028-n12“?“, Chip, danach „Der Benutzername ist frei.“; Konto N2 angelegt, Schlüssel KN2 (kn2.txt, 600); Familienschritt mit Umschalter „Gründen \| Beitreten“. Hinweis: Das Namensfeld füllt den Benutzernamen automatisch („test.n2“); Eingaben werden angehängt |
| D-02 | ✅ | „Code kopiert“; `abc` → „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ …“; echter Code → „Fast geschafft! …“ (kein „Unbekannter Fehler“); G1: „Test N2 möchte beitreten – Anfrage über den Familien-Code (ohne Link) …“, Ablehnen entfernt sie; G2 zeigte „Deine Anfrage wurde abgelehnt. …“ nach unter 2 Minuten (Anfrage 06:22:25, Ablehnen 06:22:48, Meldung vor 06:24:56) |
| D-03 | ✅ | Familie „Löschtest 1028“ gegründet, Hauptansicht „Heute“ |
| D-04 | ✅ | Abmelden; Benutzername `fnt-1028-n12` führt zu „Schon vergeben“, „Ich habe schon ein Konto“ übernimmt ihn in die Anmeldung |
| D-05 | ✅ | „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; mit KN2 freigeschaltet in unter 15 s, Familie „Löschtest 1028“ erkannt |
| D-06 | ✅ | Zurück ohne „Konto erstellen“ → „Willkommen“; `register/available` für `fnt-1028-n9`: `{"available":true}` (logs/D-06_available.txt) |
| D-07 | n/a | Optional, kein Serverzugang für `enable_registration: false` |

## E. Einladung und Zusammenspiel (G1 = iPhone-Simulator, N1; G2 = Mac, I2) – Zwischenstand
| ID | Erg. | Beobachtung |
|---|---|---|
| E-01 | ✅ | „Testfamilie 1028“, Empfehlung zweiter Moderator, nur Test N1 (Moderator), Familien-Code |
| E-02 | ✅ | „Name geändert.“, „Testfamilie 1028 neu“ |
| E-03 | ✅ | `abc` → „Bitte eine gültige Benutzer-ID eingeben, z. B. @a…“; Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel …“; N2 „Eingeladen“. Einfügen im Simulator: Menü-Einträge von Bearbeiten wirken nicht; „Send Clipboard“ + Tippen auf das iOS-Kontextmenü „Einsetzen“ funktioniert |
| E-04 | ✅ | Rückfrage „Test N2 wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert …“; N2 verschwindet |
| E-05 | ✅ | QR-Code direkt, „Gültig für“ 1/3/7 Tage, Konto-Server für Neue, „Neuen Link erzeugen“, Link `https://carpeasrael.github.io/FamilyNexus/join/#v=3&…&srv=matrix-synapse-3ues…`, „Link kopiert.“ (Hinweistext „Der Link ist 3 Tage gültig und nur einmal verwendbar …“). „Per E-Mail senden“ nicht ausgeführt (⏳ Mailprogramm) |
| E-06 | ✅ | `abc` → „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.“; gekürzt → „Der Link ist unvollständig oder beschädigt …“ |
| E-07 | ✅ | Beitrittskarte „Du trittst der Familie „Testfamilie 1028 neu“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.chaostribunal.de).“, Details mit `@fnt-1028-n1:matrix.chaostribunal.de` und Server der Familie, „Verwerfen“. Mac: Web-Seite „Einladung zu FamilyNexus“ → „App öffnen“ öffnete dabei die Release-App aus /Applications (alte Fassung, ohne Schlüsselbund-Freigabe), nicht den Testbuild → zu Gunsten von Einfügen umgangen |
| E-08 | ✅ | Anbieter `matrix-synapse-3ues.srv1348446.hstgr.cloud` aus dem Link |
| E-09 | ✅ | I2 `fnt-1028-i2` angelegt, weiter zum Notfall-Schlüssel |
| E-10 | ✅ | Schlüssel bleibt stehen, KI2 (ki2.txt, 600), danach Beitrittskarte „Schritt 4 von 4“ |
| E-11 | ✅ | Aufnahme automatisch, Dauer ca. 5–10 s nach „Beitritt anfragen“ (06:36:27), G2 zeigt „Heute“ |
| E-12 | ✅ | Verbrauchter Link über `familynexus://join?…` an die Test-App: „Du bist bereits in einer Familie.“; (die Schreibweise `familynexus://join#…` ergibt „unvollständig oder beschädigt“, der https-Link über `open -a` wird von der App nicht verarbeitet) |
| E-13 | ✅ | N1 (Moderator), Test Nutzer 2 (Mitglied, „Nicht persönlich geprüft“), Name „Testfamilie 1028 neu“ auch bei I2 |
| E-14 | ✅ | „Nur Moderatoren verwalten die Familie.“; Menü nur „Verifizieren“ und „Test N1 blockieren“; Aufgaben ohne „Neue Aufgabenliste“ („Nur Moderatoren legen Listen an …“) |
| E-15 | ✅ | An: „Test N1 – Online“; aus: G2 „Gerade ist sonst niemand online.“ und „Zuletzt online gerade eben“, G1 „Dein Status wird nicht geteilt“; wieder an: „Test N1 – Online“ |

### E (Fortsetzung)
| ID | Erg. | Beobachtung |
|---|---|---|
| E-16 | ✅ | Nachricht bei G2; „Antworten“ → Antwort mit Bezug bei G1; Reaktion 👍 bei beiden; nur der eine Hinweis „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ (#35), keine „kann nicht entschlüsselt werden“. Auf dem Mac: Kontextmenü mit Antworten, Emoji, Melden, Blockieren (Lange drücken per Maus) |
| E-17 | ✅ | Bild und Textdatei von G2 an G1: „Anhang laden“ zeigt das Bild, „Speichern“ erst nach Warnung „Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. …“, Dateien in der Dateien-App gesichert (`test.png`, `test.txt`) |
| E-18 | ✅ | Einzelchat „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“; bei G2 Reiter „Test N1“ mit „Nur für dich“; kein Rohtext |
| E-19 | ✅ | G2 sieht nur „Test geteilt 2“; Filter Test N1 → Termin, Test Nutzer 2 → „Keine Termine“ |
| E-20 | ✅ | G2: „Nur der Ersteller kann diesen Termin ändern.“, Zusagen → „Du – Zugesagt“; G1: „Test Nutzer 2 – Zugesagt“, „Im Chat teilen“ nur bei G1 |
| E-21 | ✅ | „Termin I2“ geteilt → bei G1 „Von Test Nutzer 2“; Wechsel auf Privat: Hinweis „Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.“ |
| E-22 | ✅ | „Käse“ auf beiden („zuletzt von …“), „2 erledigte Einträge für die ganze Familie entfernen?“, Löschen von „vollkornbrot“ wirkt auf beiden („Der Einkaufszettel ist leer“). Mac: Menü der Einträge hat „Bearbeiten“, „Löschen“ |
| E-23 | ✅ | Liste „Müll rausbringen“ (Mo–Fr, Test Nutzer 2) bei G2 unter „Mir zugewiesen“; G1 kann nicht abhaken; G2 Kommentar „Erledigt am Abend“, Verlauf „Tonne rausstellen erledigt – Du · 28.10.2026, 06:51“; „Liste „Bad putzen“ löschen?“ → weg. Hinweis „Aufgaben für dich: 1 offen“ auf „Heute“ nicht gesondert geprüft |
| E-24 | ✅ | Symbole gleich (Banane, Schmetterling, Fisch, Hahn, Zug, Büroklammer, Herz), beide „Verifiziert.“, Mitglied „Verifiziert“ |
| E-25 | ✅ | Dialog „Nachricht melden“ mit Hinweis auf den Betreiber (matrix-synapse-3ues…), vier Gründe, „Melden“ → „Meldung gesendet.“ mit „Absender blockieren“ |
| E-26 | ✅ | „Test Nutzer 2 blockieren?“ mit Erklärung, Mitglied „Blockiert“; G2 sendet „Noch da?“ ohne Fehler |
| E-27 | ✅ | Blockierte Mitglieder: Eintrag mit „Blockierung aufheben“; danach alle Nachrichten sichtbar, auch „Noch da?“ (die Meldung „Blockierung … aufgehoben“ nicht erfasst) |

### E (Schluss)
| ID | Erg. | Beobachtung |
|---|---|---|
| E-28 | ✅ | Menü und Einstellungen beider Geräte „Version 1.2.1 (18)“ |
| E-29 | ✅ | „Konto löschen?“ mit „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“; „Konto endgültig löschen“ inaktiv; Abbrechen unverändert |
| E-30 | ✅ | Rückfrage „Test Nutzer 2 zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“; beide Moderatoren |
| E-31 | ✅ | Dialog ohne Moderator-Hinweis |
| E-32 | ✅ | G2: Dialog ohne Moderator-Hinweis, danach „Willkommen“ (nicht „Anmelden“); G1: Familie nur noch Test N1, frühere Nachrichten sichtbar (Absender jetzt als `@fnt-1028-i2:matrix.chaostribunal.de` statt „Test Nutzer 2“) |

## F. Lokale Daten, Löschen und Aufräumen (Lauf 1)
| ID | Erg. | Beobachtung |
|---|---|---|
| F-01 | ✅ | Mac: N2 angemeldet, mit KN2 freigeschaltet; „Konto löschen?“ nennt `@fnt-1028-n12:matrix.chaostribunal.de` und den Server; kein Moderator-Hinweis; falsches Passwort → „Das Passwort stimmt nicht.“ (#36), Dialog bleibt; richtiges → „Willkommen“ |
| F-02 | ✅ | `403 M_FORBIDDEN` für `fnt-1028-n12` (logs/F-02_login_n12.txt) |
| F-03 | ✅ | „Alle lokalen Daten löschen?“ (Hinweis: Konto beim Server bleibt) → „Willkommen“ |
| F-04 | ✅ | App beenden und neu starten (`simctl terminate/launch`) → „Willkommen“ |
| F-05 | ✅ | N1 + KN1b: Termine inkl. privater („Test privat“, „Test serie“), Chat (Absender-ID statt Name für I2), Aufgaben wiederhergestellt; Einkaufszettel leer wie erwartet |
| F-06 | ✅ | Kein Moderator-Hinweis, „Willkommen“ |
| F-07 | ✅ | N1, I2, N2: je `403 M_FORBIDDEN` (logs/F-07_login.txt) |
| F-08 | ✅ | Alle Konten des Laufs 1 gelöscht (`register/available`: `M_USER_IN_USE`; `fnt-1028-n9` nie angelegt: `available:true`); Registrierung unverändert offen |

## G (Rest, Lauf 1)
| ID | Erg. | Beobachtung |
|---|---|---|
| G-04 | n/a | Optional, kein lokaler Synapse |
| G-05 | ✅ | In G-02 enthalten |
| G-06 | ⚠️ | Review-Notizen nur automatisch (G-03) und durch A–F inhaltlich abgedeckt, nicht Zeile für Zeile nachvollzogen |
| G-07 | n/a | Keine Person ohne Vorwissen verfügbar |
| G-08 | n/a | Plattform Web nicht Teil des Laufs |

## Lauf 1 abgeschlossen (28.10.2026 ca. 07:10)
Lauf 2 (G1 = Mac, G2 = iPhone-Simulator, Datumsteil `1028b`) folgt unten.

---

# Lauf 2 (G1 = MacBook, G2 = iPhone-Simulator) – 28.10.2026 ab ca. 07:10 – Build 1.2.1 (18) @ bb7f347
Datumsteil `1028c` (`fnt-1028b-n1` war bereits belegt, nicht von diesem Lauf; `fnt-1028c-*` frei, logs/Lauf2_V-05_V-06.txt). Screenshots: `screenshots-lauf2/`. V-01 bis V-03 gelten unverändert aus Lauf 1 (gleiche Builds). V-04: Mac-App zeigt „Willkommen“ nach F-06/D-Zyklus; iPhone-Simulator „Willkommen“ (F-06).

## A (G1 = Mac)
| ID | Erg. | Beobachtung |
|---|---|---|
| A-01 | ✅ | Startseite mit drei Wegen, Sprache |
| A-02 | ✅ | Sprachwechsel English/Deutsch sofort |
| A-03 | ✅ | „Konto erstellen“, Schritt 1 von 3, matrix.org-Hinweis, „Konto bei matrix.org erstellen“ nicht angetippt |
| A-04 | ✅ | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ + „Erneut versuchen“; „Konto erstellen“ ausgegraut |
| A-05 | ✅ | „Dein Konto liegt bei matrix-synapse-3ues….“, Betreiber, Kontakt „nicht angegeben“, Felder |
| A-06 | ✅ | `Joerg Muessig` / `Jörg Müßig` → `joerg.muessig`, „Der Benutzername ist frei.“ |
| A-07 | ✅ | Alle sechs Eingaben (`ab`, `Anna`, `anna müller`, `.anna`, `anna.`, 33 × a) zeigen die Fehlermeldung. **Auf dem Mac wird `Anna` korrekt abgelehnt** – der Befund aus Lauf 1 (stilles `anna`) tritt nur im iOS-Simulator auf |
| A-08 | ✅ | `fnt-1028c-n1` bleibt, 7 Zeichen ausgegraut, ab 8 aktiv, Augen-Symbol |
| A-09 | ✅ | „Dein Notfall-Schlüssel“, Schritt 2 von 3, kein Zusatzschritt |
| A-10 | ✅ | Schlüssel bleibt stehen (20 s), „Kopieren“, „Als Datei speichern“ → `keyfile/FamilyNexus-Notfall-Schluessel.txt` (600; Konto, Anbieter, Datum, Schlüssel), „Gespeichert. Bewahre die Datei sicher auf – am besten ausgedruckt.“ KN1c in kn1c.txt |
| A-11 | ✅ | Hinweise zu Moderator und Kindern; „Fertig! „Testfamilie 1028c“ ist eingerichtet.“ |
| A-12 | ✅ | „Heute“ |

## B (G1 = Mac)
| ID | Erg. | Beobachtung |
|---|---|---|
| B-01 | ✅ | Kacheln Erinnerungen, Nächste Termine, Wer ist online, Einkaufszettel, Aufgaben, Navigation unten |
| B-02 | ⚠️ | „Erlauben“ löst auf dem Mac keinen Systemdialog aus; Hinweis „Benachrichtigungen sind blockiert. …“ bleibt (App ist ad-hoc signiert / Berechtigung nicht erteilt). Nicht prüfbar ohne Eingriff in die Systemeinstellungen |
| B-03 | ✅ | „Test geteilt“ 29.10. 10:00–11:00, Geteilt, Ort Küche, Notiz, Farbe; Hinweis „Verschlüsselt an die Familie gesendet. …“ |
| B-04 | ✅ | „Bitte einen Titel eingeben.“; „Das Ende liegt vor dem Beginn.“ direkt unter Beginn/Ende (#34) |
| B-05 | ✅ | Beginn 21:00 → Ende wandert auf 22:00 am selben Tag (Mac). Der iOS-Befund (Ende = Beginn bei neuem Termin) tritt hier nicht auf |
| B-06 | ✅ | Serie ganztägig, wöchentlich, 3 Vorkommen (30.10., 6.11., 13.11.), „Wöchentlich“-Kennzeichnung; Standard „Nach Anzahl“ steht auf 10 |
| B-07 | ✅ | Tag/Woche/Monat/Agenda, Navigation, „Heute“ |
| B-08 | ✅ | Bearbeiten, Titel „Test geteilt 2“, „Verlauf (1)“ zeigt „Test geteilt – Version 1“ |
| B-09 | ✅ | Erinnerung je Termin, „Standard verwenden“ |
| B-10 | ⚠️ | Termin 07:35, Erinnerung 10 Minuten (07:25): auf dem Mac keine Systembenachrichtigung, da Benachrichtigungen blockiert (B-02); in 20 s-Abständen bis 07:26 beobachtet |
| B-11 | ✅ | Serie: „Alle Vorkommen oder nur dieses löschen?“ → „Nur dieses“ entfernt nur 30.10.; „Diesen Termin wirklich löschen?“ → weg |
| B-12 | ✅ | Umschalt+Enter = Zeilenumbruch, Enter sendet; „Ende-zu-Ende-verschlüsselt“; Uhrzeit 07:20. (Erster Versuch mit dem Eingabewerkzeug sendete wegen Tastaturereignis, kein App-Fehler) |
| B-13 | ✅ | „Im Chat teilen“ → Karte „Test geteilt 2“ mit Zusagen/Vielleicht/Absagen |
| B-14 | ✅ | Milch 2 l, Brot (Enter), abhaken → „Erledigt (1)“, „Erledigte entfernen“ mit Rückfrage „1 erledigte Einträge für die ganze Familie entfernen?“, Bearbeiten → Vollkornbrot; leerer Eintrag erzeugt nichts |
| B-15 | ✅ | Leeres Speichern „Bitte Titel, Person und mindestens einen Punkt angeben.“; Liste „Bad putzen“ (Du, wöchentlich Montag, Waschbecken/Spiegel), „1 von 2 erledigt“, Verlauf „Waschbecken erledigt – Du · 28.10.2026, 07:23“ (#38), „Nächster Neustart: Montag, 2. November 2026“ |
| B-16 | ✅ | Sprache Deutsch/English, Design Hell/Dunkel, Akzentfarbe Magenta/Türkis, Effekte reduzieren – wirken sofort; Ausgangszustand wiederhergestellt |
| B-17 | ⚠️ | App-Sperre einschalten verlangt Touch ID/Passwort des Macs („FamilyNexus möchte FamilyNexus entsperren“); nach Abbruch „Die Bestätigung war nicht erfolgreich.“, Schalter bleibt aus. Passwort kann der Lauf nicht eingeben, Sperre und Entsperren nicht geprüft |
| B-18 | n/a | Kein Schalter „Bildschirmschutz“ auf macOS |
| B-19 | ✅ | „Online-Status teilen“ an, „Blockierte Mitglieder“: „Du hast niemanden blockiert.“ (Datenschutzerklärung nicht erneut geöffnet) |
| B-20 | ✅ | Standard-Erinnerung wählbar (30 Min.), wieder 10 Min. |
| B-21 | ✅ | Speicherorte inkl. „Schlüsselbund des Geräts (nicht in iCloud)“; lokales Protokoll (App-Version 1.2.1 (18), Warnhinweis, settings, Anzeigename), Online-Protokoll (Konto, Gerät „FamilyNexus macOS … Verifiziert – Dieses Gerät“, Cross-Signing, Schlüssel-Backup) |
| B-22 | ✅ | Menü unten und Einstellungen „Version 1.2.1 (18)“; Konto: Server, `@fnt-1028c-n1:matrix.chaostribunal.de` |

## C (G1 = Mac, G2 = iPhone-Simulator)
| ID | Erg. | Beobachtung |
|---|---|---|
| C-01 | ✅ | „Benutzername oder Passwort stimmen nicht.“ |
| C-02 | ✅ | iPhone: „Mit „FamilyNexus macOS“ bestätigen“; Mac: „@fnt-1028c-n1:… (EZWPHPGPWV) möchte die Verifizierung starten.“; Symbole gleich (🚀 🎩 ✏️ 🦁 🦁 🍕 🌙); beide „Verifiziert.“; Hauptansicht mit Terminen aus B |
| C-03 | ✅ | „Dieses Gerät ist verifiziert.“; macOS und iOS (Dieses Gerät) „Verifiziert“; „Neuen Notfall-Schlüssel erstellen“ |
| C-04 | ✅ | „Abmelden“ → „Anmelden“ |
| C-05 | ✅ | Mac: Seite „Neuer Notfall-Schlüssel“; Zurück-Pfeil/Escape ohne Wirkung; mit Häkchen + „Weiter“ zurück in Einstellungen. KN1d |
| C-06 | ✅ | iPhone mit altem Schlüssel KN1c: „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“ |
| C-07 | ✅ | Mit KN1d freigeschaltet, Hauptansicht mit Terminen (auch privaten) |
| C-08 | ✅ | „Abmelden“ → „Anmelden“ |

## D (G2 = iPhone-Simulator, N2; G1 = Mac, N1)
| ID | Erg. | Beobachtung |
|---|---|---|
| D-01 | ✅ | „Schon vergeben – wie wäre es mit „fnt-1028c-n12“?“, Chip, „Der Benutzername ist frei.“, Konto N2 angelegt, Schlüssel bleibt stehen (KN2c, kn2c.txt 600), Familienschritt mit Umschalter „Gründen | Beitreten“ |
| D-02 | ✅ | `abc` → „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ und enthält einen Server, z. B. !abc:matrix.org.“; echter Code → „Fast geschafft!“ (kein „Unbekannter Fehler“); Mac: „Test N2 möchte beitreten – Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du @fnt-1028c-n12:… kennst und erwartest“; „Ablehnen“ 07:41:39, Anfrage verschwindet; iPhone: „Deine Anfrage wurde abgelehnt. Frag bei der Familie nach …“ + „Verstanden“ nach **zwischen 2 und 4 Minuten** (07:43:26 noch „Fast geschafft!“, 07:45:28 abgelehnt) – innerhalb der 3-Minuten-Grenze nicht eindeutig; ⚠️ Dauer notieren |
| D-03 | ✅ | Familie „Löschtest 1028c“, Hauptansicht „Heute“ |
| D-04 | ✅ | Abmelden; Name `fnt-1028c-n12` → „Schon vergeben – … „fnt-1028c-n122“?“; „Ich habe schon ein Konto“ übernimmt Benutzernamen |
| D-05 | ✅ | „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; mit KN2c freigeschaltet in unter 25 s (KN2d entstand erst danach) |
| D-06 | ✅ | Zurück ohne „Konto erstellen“ → „Willkommen“; `register/available` für `fnt-1028c-n9`: `{"available":true}` |
| D-07 | n/a | optional, kein Serverzugang |
Hinweis: Beim D-06-Durchlauf wurde versehentlich ein weiterer Notfall-Schlüssel für N2 erzeugt (KN2d, kn2d.txt; Navigationsfehler im Test); maßgeblich für N2 ist daher KN2d.

## E (G1 = Mac, N1; G2 = iPhone-Simulator, I2) – Zwischenstand
| ID | Erg. | Beobachtung |
|---|---|---|
| E-01/E-02 | ✅ | Familie „Testfamilie 1028c“ mit Empfehlung zweiter Moderator; „Testfamilie 1028c neu“ |
| E-03 | ✅ | `abc` → „Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.“; ID → Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie …“; N2 „Eingeladen“ |
| E-04 | ✅ | „Test N2 wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert …“; N2 weg |
| E-05 | ✅ | QR direkt, Gültig für 1/3/7 Tage, Konto-Server für Neue, neuer Link mit `srv=matrix-synapse-3ues…`; „Per E-Mail senden“ öffnete auf dem Mac Thunderbird mit Entwurf „Einladung zu FamilyNexus“ und Link (nicht gesendet, Fenster geschlossen); „Link kopiert.“ |
| E-06 | ✅ | `abc` → „Das ist kein Einladungslink. Ein Einladungslink beginnt mit …“; gekürzt → „Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. …“ |
| E-07 | ✅ | Beitrittskarte „Du trittst der Familie „Testfamilie 1028c neu“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.chaostribunal.de).“, Details mit `@fnt-1028c-n1:…` und Server, „Verwerfen“; zusätzlich Web-Seite „Einladung zu FamilyNexus“ → „App öffnen“ → „In „FamilyNexus“ öffnen?“ |
| E-08 | ✅ | Konto-Server `matrix-synapse-3ues…` aus dem Link |
| E-09 | ✅ | I2 `fnt-1028c-i2`; Hinweis: nach dem Passwort verschob sich das Layout, zwei Folgetipps trafen daneben (Testwerkzeug) |
| E-10 | ✅ | Schlüssel bleibt stehen, KI2c (ki2c.txt, 600), danach Beitrittskarte „Schritt 4 von 4“ |
| E-11 | ✅ | „Beitritt anfragen“ 07:57:47 → Hauptansicht ca. 20–30 s später, „Test geteilt 2“ sichtbar |
| E-12 | ✅ | Verbrauchter Link über Safari → „App öffnen“ → „Öffnen“: „Du bist bereits in einer Familie.“ |
| E-13 | ✅ | N1 Moderator, Test Nutzer 2 Mitglied, „Nicht persönlich geprüft“, Name „Testfamilie 1028c neu“ bei I2 |
| E-14 | ✅ | „Nur Moderatoren verwalten die Familie.“, Menü nur „Verifizieren“ und „Test N1 blockieren“; Aufgaben ohne „Neue Aufgabenliste“ |
| E-15 | ✅ | Aus: G2 „Zuletzt online gerade eben“, G1 „Dein Status wird nicht geteilt“; wieder an |
| E-16 | ✅ | Nachricht, Antwort mit Bezug, Reaktion 👍 bei beiden; „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ |

### E (Lauf 2, Fortsetzung)
| ID | Erg. | Beobachtung |
|---|---|---|
| E-17 | ✅ | Mac sendet Bild + Textdatei; iPhone: „Anhang laden“ zeigt das Bild, „Speichern“ erst nach Warnung „Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. …“, Dateien in „Auf meinem iPhone“ (beide behalten) |
| E-18 | ✅ | Mac: „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“; iPhone: Reiter „Test N1“ mit Zähler, Familienchat getrennt |
| E-19 | ✅ | iPhone sieht nur den geteilten Termin (nur 29.10. mit Punkt); Filter „Test N1/Test Nutzer 2“ vorhanden |
| E-20 | ✅ | iPhone: „Nur der Ersteller kann diesen Termin ändern.“, Zusagen; Mac: „Test Nutzer 2 – Zugesagt“, Im Chat teilen nur beim Ersteller |
| E-21 | ✅ | „Termin i2“ geteilt → Mac „Von Test Nutzer 2“; Wechsel auf Privat zeigt Hinweis „Bereits an die Familie gesendete Inhalte bleiben …“ |
| E-22 | ✅ | „Käse“ von G2 auf beiden; „2 erledigte Einträge für die ganze Familie entfernen?“; Löschen von „Vollkornbrot“ wirkt, „Der Einkaufszettel ist leer“ |
| E-23 | ✅ | Liste „Müll rausbringen“ (Mo–Fr) bei I2 unter „Mir zugewiesen“; Mac kann nicht abhaken; Kommentar, Verlauf „Tonne rausstellen erledigt – Du · 28.10.2026, 08:10“; „Liste „Bad putzen“ löschen?“ → weg |
| E-24 | ✅ | Anfrage vom Mac, iPhone „Annehmen“, Symbole gleich (🎧 ☁️ 🏁 🐢 🐰 ❤️ ✂️), „Verifiziert.“, Mitglied „Verifiziert“ |
| E-25 | ✅ | Dialog „Nachricht melden“ mit Betreiberhinweis, vier Gründe, „Meldung gesendet.“ mit „Absender blockieren“ |
| E-26 | ✅ | „Test Nutzer 2 blockieren?“ mit Erklärung; Mitglied „Blockiert“; G2 sendet ohne Fehler (Text im Simulator „Noch daß“, Tastaturartefakt) |
| E-27 | ✅ | Blockierte Mitglieder (1) → „Blockierung aufheben“; Nachrichten wieder sichtbar |
| E-28 | ✅ | Beide „Version 1.2.1 (18)“ |
| E-29 | ✅ | Mac: „Du bist der einzige Moderator der Familie. Ernenne vorher …“; „Konto endgültig löschen“ inaktiv; abgebrochen |
| E-30 | ✅ | Rückfrage „… zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“ |
| E-31 | ✅ | Dialog ohne Moderator-Hinweis |
| E-32 | ✅ | iPhone: Konto von I2 löschen → „Willkommen“; Mac: nur noch Test N1, Empfehlung „Ernenne einen zweiten Moderator“ wieder da |

## F (Lauf 2) und G
| ID | Erg. | Beobachtung |
|---|---|---|
| F-01 | ✅ | iPhone: N2 mit KN2d freigeschaltet; falsches Passwort „Das Passwort stimmt nicht.“, Dialog bleibt; richtig → „Willkommen“ |
| F-02 | ✅ | `403 M_FORBIDDEN` (logs/Lauf2_F-02_login_n12.txt) |
| F-03 | ✅ | Mac: „Alle lokalen Daten löschen?“ → „Willkommen“ |
| F-04 | ✅ | App beendet/neu gestartet → „Willkommen“ |
| F-05 | ✅ | N1 + KN1d: Termine inkl. privater, Serie, Erinnerungen („4 Erinnerungen geplant“) wiederhergestellt. Hinweis: Anmeldeassistent stand nach dem Neustart wieder auf matrix.org (Server nicht gemerkt) |
| F-06 | ✅ | Kein Moderator-Hinweis, „Willkommen“ |
| F-07 | ✅ | N1, I2, N2 je `403 M_FORBIDDEN` (logs/Lauf2_F-07_login.txt) |
| F-08 | ✅ | Alle Konten `fnt-1028c-*` gelöscht; Registrierung unverändert offen |
| G-01..G-03 | ✅ | gelten aus Lauf 1 (derselbe Commit) |
| G-04, G-06..G-08 | n/a / ⚠️ | wie Lauf 1 |

## Lauf 2 abgeschlossen (28.10.2026 ca. 08:35)
