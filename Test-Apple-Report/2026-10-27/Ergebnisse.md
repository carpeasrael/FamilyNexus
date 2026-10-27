# Ergebnisse Lauf 2026-10-27 (TP-FN-001 v1.5 @ 7159ddc) – laufend

Bedienung: Klick/Tipp per CGEvent-Skript (Tastaturlayout des Simulators: Deutsch, Umlaute über echte Tasten). G1 = iOS-Simulator iPhone 15 Test (iOS 27.0), Build 1.2.1 (17). Konto N1 = fnt-1027-n1, Familie „Testfamilie 1027“.

| ID | Beobachtet | Screenshot | Erg. |
|---|---|---|---|
| V-01..V-03, V-05, V-06 | siehe Vorbereitung.md; Mac-App in /Applications war Build 16, Build 17 aus `main` gebaut und von build/ gestartet | V-04-G1 | ✅ |
| V-04 | G1 und G2 zeigten nach frischem Start „Willkommen“ (kein Löschen nötig, Daten leer) | – | ✅ |
| A-01 | Willkommen mit drei Wegen, Hinweise, Sprachwahl | A-01-G1 | ✅ |
| A-02 | English/Deutsch wechseln sofort. (A-02b-Bild zeigt Deutsch erst nach 2. Klick; ein erster Klick traf das verschobene Layout) | A-02a/b-G1 | ✅ |
| A-03 | wie erwartet | A-03-G1 | ✅ |
| A-04 | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“, „Erneut versuchen“ | A-04-G1 | ✅ |
| A-05 | „Dein Konto liegt bei matrix-synapse-3ues…“ (Betreiber/Kontakt-Zeilen nicht gescrollt geprüft) | A-05-G1 | ✅ |
| A-06 | `Jörg Müßig` → `joerg.muessig`, „Der Benutzername ist frei.“ | A-06a/A-06-G1 | ✅ |
| A-07 | `ab`, `.anna`, `anna.`, `anna müller`, 33×a: Fehlerzeile „Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, …“ (Text mit „…“ abgeschnitten, nicht vollständig lesbar). `Anna`: kein Fehler, App wandelt in `anna` um, Name frei | A-07a..f-G1 | ⚠️ (Anna wird kleingeschrieben statt abgelehnt; Hinweistext abgeschnitten) |
| A-08 | Benutzername blieb `fnt-1027-n1`; 7 Zeichen ausgegraut, 14 aktiv; Augen-Symbol wirkt; leerer Name: ausgegraut, Platzhalter „z. B. Anna Müller“ | A-08a/A-08-G1 | ✅ |
| A-09 | „Konto erstellen“ → in unter 10 s „Dein Notfall-Schlüssel“, Schritt 2 von 3, kein Zusatzschritt | A-09a/b-G1 | ✅ |
| A-10 | Schlüssel bleibt nach 20 s stehen; „Kopiert. … nach einer Minute geleert“; „Gespeichert. …“ (Ablage im Dateiauswahldialog „Auf meinem iPhone“); Schlüssel geschwärzt; Weiter erst nach Häkchen | A-10a/b/c-G1 | ✅ |
| A-11 | „Fertig! „Testfamilie 1027“ ist eingerichtet.“ mit Später / Jetzt einladen | A-11-G1 | ✅ |
| A-12 | Hauptansicht „Heute“ | A-12-G1 | ✅ |
| B-01 | Kacheln wie erwartet; Hinweis „Benachrichtigungen sind blockiert“ (A-12-G1). Wiederholung nach B-06 nicht gemacht | A-12-G1 | ⏳ (Teil „Nächste Termine chronologisch“, #33) |
| B-02 | Hinweis → „Erlauben“ → Systemdialog „FamilyNexus möchte dir Mitteilungen senden“ → Erlauben | B-02a/b-G1 | ✅ |
| B-03 | Sichtbarkeit zuerst „Privat“; „Geteilt“: „Verschlüsselt an die Familie gesendet. …“; Termin in Kalender mit „Geteilt“, Farbe Lila, Ort „Küche“. Notiz: Eingabe „Testnotiz“ per Skript, in der Detailansicht steht „Restitution“ (Eingabeartefakt der Skripttastatur/Autokorrektur, kein App-Fehler bestätigt) | B-03a/b-G1 | ⚠️ |
| B-04 | „Bitte einen Titel eingeben.“ unter dem Titelfeld; „Das Ende liegt vor dem Beginn.“ direkt unter Beginn/Ende, ohne Scrollen (#34 behoben) | B-04-G1 | ✅ |
| B-05 | Beginn 21:00 -> Ende wandert automatisch auf 22:00 am selben Tag; Termin „Test privat“ 21:00–22:00 mit „Privat“ | B-05-G1 | ✅ |
| B-06 | „Test serie“ (App macht Titel klein), ganztägig, wöchentlich, 3 Vorkommen: 29.10., 5.11., 12.11., Kennzeichnung Wiederholung | B-06-G1 | ✅ |
| B-07 | Tag, Woche, Monat, Agenda, Navigation, „Heute“ geprüft | B-07a..d-G1 | ✅ |
| B-08 | Detailansicht „Von dir“, Ort; nach Titelwechsel „Verlauf (1)“ zeigt „Test geteilt – Version 1“ | B-08a/b/c-G1 | ✅ |
| B-09 | zusätzliche Erinnerungen (30 Min, 2 Tage) wählbar; „Standard verwenden“ setzt auf 10 Min zurück | B-09-G1 | ✅ |
| B-12 | Nachricht „Hallo Testfamilie“ gesendet (Anzeige „Hallo testfamilie“: Skript-Tastenfehler beim 2. Großbuchstaben); „Ende-zu-Ende-verschlüsselt“; Enter/Umschalt+Enter nicht prüfbar (mobil) | B-12-G1 | ✅ (n/a Desktop-Teil) |
| B-13 | „Im Chat geteilt“; Karte „Termin“ mit Zusagen/Vielleicht/Absagen im Chat | B-13a/b-G1 | ✅ |
| B-14 | Milch 2 l, Brot; Milch abgehakt unter „Erledigt (1)“; Brot → `Vollkornbrot` (angezeigt „vol…“, klein geschrieben, Skriptartefakt); leerer Eintrag ohne Wirkung. Versehentlich öffnete sich „Erledigte entfernen?“, abgebrochen | B-14a/b-G1 | ✅ |


| B-15 | Leeres Speichern: Fehlermeldung; Liste „Bad putzen“ (Du, wöchentlich, Punkte Waschbecken/Spiegel) angelegt; Punkt abgehakt, Kommentar „erledigt“, „Erledigt“; „Heute“ zeigt „Aufgaben für dich“. Verlaufsdatum-Format nicht im Bild geprüft | B-15a/b/c-G1 | ✅ (Datumsformat #38 ⏳) |
| B-16 | Einstellungen Darstellung geöffnet; Design/Akzentfarbe/Effekte umgeschaltet; Neustart-Persistenz nicht geprüft | B-16a/b/c-G1 | ⚠️ (Persistenz ⏳) |
| B-17 | Simulator ohne Gerätesperre/Biometrie | – | ⏳ |
| B-18 | Bildschirmschutz im Simulator nicht prüfbar | – | ⏳ |
| B-19..B-21 | Einstellungen ab „Datenschutz“ bis „Über die App“ gesichtet (Protokoll „Online gespeicherte Daten“: App-Version 1.2.1 (17), Benutzername @fnt-1027-n1, Anzeigename Test N1, Gerät „FamilyNexus iOS“ verifiziert); weitere Unterpunkte nicht einzeln ausgeführt | B-19-G1, B-21a/b-G1 | ⚠️ (teilweise) |
| B-22 | Menü unten „Version 1.2.1 (17)“ (Mac-Menü); „Konto“: Server = Anbieter-Adresse, Benutzername `@fnt-1027-n1:matrix.chaostribunal.de` | B-22b-G1 | ✅ |
| C-01 | falsches Passwort: „Benutzername oder Passwort stimmen nicht.“ (Mac, FamilyNexus macOS) | C-01-G2 | ✅ |
| C-02 | „Mit FamilyNexus iOS bestätigen“; G1: „@fnt-1027-n1 … möchte die Verifizierung starten.“; beide zeigen dieselben 7 Symbole in gleicher Reihenfolge (Buch, Ball, Schere, Brille, Buch, Erde, Telefon); beide „Verifiziert.“; G2 zeigt Hauptansicht mit Terminen aus B. Bedienungshilfe-Namen nicht geprüft (#39) | C-02a-G2, C-02-G1, C-02c-G2 | ✅ |
| C-03 | „Dieses Gerät ist verifiziert.“; Geräte: FamilyNexus iOS, FamilyNexus macOS (Dieses Gerät), beide Verifiziert; „Neuen Notfall-Schlüssel erstellen“ vorhanden | C-03-G2 | ✅ |
| C-04 | Abmelden → Dialog → direkt „Anmelden“ | C-04-G2 | ✅ |
| C-05 | Seite „Neuer Notfall-Schlüssel“, neuer Schlüssel (KN1b, geschwärzt), Zurück-Pfeil ohne Wirkung; Häkchen → Weiter → zurück in Einstellungen. System-Zurück nicht getestet | C-05a..d-G1 | ✅ |
| B-10 | Termin 22:20 (privat, Standard 10 Min), App im Hintergrund; um 22:11 Systemmitteilung „Erinnerung / Termin in 10 Minuten“ ohne Titel/Ort (Mitteilungszentrale; Banner war bereits weg) | B-10-G1 | ✅ |
| B-11 | „Test serie“: „Alle Vorkommen oder nur dieses löschen?“ → „Nur dieses“ (29.10.); „Test erinnerung“: „Diesen Termin wirklich löschen?“ → gelöscht | B-11a/b/c-G1 | ✅ |
| C-06 | Mac-Anmeldung zeitweise durch Server-Ratenlimit blockiert (Testskript-Fehler, siehe oben; ca. 1 h). Danach alter Schlüssel KN1: „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“ (Bild geschwärzt) | C-06-G2 | ✅ |
| C-07 | KN1b → Gerät freigeschaltet, Hauptansicht mit Terminen aus B | C-07-G2 | ✅ |
| C-08 | Abmelden → „Anmelden“ | C-08-G2 | ✅ |

**Abschnitt C abgeschlossen.**

| D-01 | „Schon vergeben – wie wäre es mit „fnt-1027-n12“?“, Chip, „Der Benutzername ist frei.“; Konto N2 angelegt, Schlüssel bleibt stehen (KN2, geschwärzt), Familienschritt erscheint | D-01a/b-G2 | ✅ |
| D-02 | `abc`: „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ …“; echter Code: „Fast geschafft! …“. G1: „Beitrittsanfragen – Test N2 möchte beitreten“ mit „Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du @fnt-1027-n12… kennst“; nach „Ablehnen“ verschwindet sie. **G2 zeigt auch nach über 1 Minute weiter „Fast geschafft!“, keine Meldung „Deine Anfrage wurde abgelehnt“ (Issue #30 weiterhin offen)** | D-02a..f | ⚠️ (#30) |
| D-03 | Anfrage zurückgezogen, „Gründen“ → Familie „Loeschtest 1027“ (Ersatzschreibung) → Hauptansicht „Heute“ | D-03-G2 | ✅ |
| D-04 | Abmelden; Umschalten auf „Ich habe schon ein Konto“: Benutzername aus der Kontoanlage vorausgefüllt (Eingabe enthielt Tippfehler „testfnt-…“ aus Skript) | D-04-G2 | ✅ |
| D-05 | „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; KN2 → freigeschaltet, F2 erkannt, kein Hänger | D-05a/-G2 | ✅ |
| D-06 | Zurück-Pfeil: „Willkommen“; Gegenprobe `fnt-1027-n9`: available true (zweiter Name `testfnt-1027-n9` ebenfalls frei) | D-06a/-G2 | ✅ |
| D-07 | optional, ohne Serverzugang | – | n/a |

| E-01 | Tab „Familie“: Name, „Empfehlung: Ernenne einen zweiten Moderator.“, Mitglied Test N1 (Moderator), „Mitglied einladen“, Familien-Code | D-02c-G1 | ✅ |
| E-02 | Name geändert („Name geändert.“; Anzeige kleingeschrieben durch Skripteingabe) | E-02-G1 | ✅ |
| E-03 | `abc`: „Bitte eine gültige Benutzer-ID eingeben, z. B. @a…“; gültige ID: Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel …“; N2 „Eingeladen“ in der Liste | E-03a/b/-G1 | ✅ |
| E-04 | Rückfrage „Test N2 wirklich aus der Familie entfernen? …“; „Erledigt.“, N2 weg | E-04a/E-04-G1 | ✅ |
| E-05 | QR-Code, „Gültig für 1/3/7 Tage“, „Erweitert → Konto-Server für Neue“ (zuerst mit falscher Eingabe „aaaa…“ durch Skriptfehler: „Bitte Eingabe prüfen.“), Link mit `srv=matrix-synapse-3ues…`, „Link kopiert“; „Der Link ist 3 Tage gültig und nur einmal verwendbar …“. „Per E-Mail senden“ nicht ausgeführt | E-05a/b-G1 | ✅ (E-Mail ⏳) |
| E-06 | `abc`: „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.“; gekürzter Link: „Der Link ist unvollständig oder beschädigt …“ | E-06a/b-G2 | ✅ |
| E-07 | Beitrittskarte „Du trittst der Familie „Testfamilie 1027aaaa“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.chaostribunal.de).“ (Familienname aus dem Link, der vor der Umbenennung erzeugt wurde) | E-10b-G2 | ✅ (über Link-Feld statt System-Öffnen) |
| E-08 | Anbieter `matrix-synapse-3ues…` aus dem Link vorbelegt | E-08-G2 | ✅ |
| E-09 | I2 angelegt ohne Zusatzschritt, weiter zum Notfall-Schlüssel | E-09-G2 | ✅ |
| E-10 | Schlüssel bleibt stehen, Kopieren, Weiter; Karte „Schritt 4 von 4“ → „Beitritt anfragen“ | E-10a/b/-G2 | ✅ |
| E-11 | I2 wurde in weniger als 10 s automatisch aufgenommen; G2 zeigt „Heute“ mit „Test geteilt 2 – Von Test N1“ | E-10-G2 | ✅ |
| E-13 | G2 „Familie“: Test N1 (Moderator, „Nicht persönlich geprüft“), Test Nutzer 2 (Mitglied); Familienname „testfamilie 1027 neu“ auch bei I2; G1: Empfehlung „Ernenne einen zweiten Moderator“ | E-13-G1, E-13-G2 | ✅ |
| E-14 | G2: „Nur Moderatoren verwalten die Familie.“, keine Verwaltungsaktionen; Menü/Aufgaben nicht geprüft | E-14-G2 | ⚠️ (Aufgaben-Teil ⏳) |
| E-16 | G1 sendet, G2 sieht „Hallo von Nutzer 1“ und den Hinweis „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ (#35 ✅); G2 antwortet über „Antworten“, Antwort mit Bezug auf G2. Reaktion (G1) und Bezug bei G1 nicht geprüft | E-16a-G1, E-16b/c-G2 | ⚠️ (Reaktion ⏳) |
| E-19 | G2 Agenda: nur „Test geteilt 2“, „Test privat“/„Test serie“ nicht sichtbar | E-19-G2 | ✅ |
| E-20 | G2: „Nur der Ersteller kann diesen Termin ändern.“, Zusagen/Vielleicht/Absagen; G1 sieht „Test Nutzer 2 – Zugesagt“, „Im Chat teilen“ nur bei G1 | E-20a-G2, E-20b-G1 | ✅ |
| E-21 | „Termin I2“ geteilt: G1 zeigt „Von Test Nutzer 2“ (Wechsel auf „Privat“ ⏳) | E-21a-G2, E-21b-G1 | ⚠️ |

Offen in E: E-15, E-17, E-18, E-21 (Privat), E-22 bis E-32, E-12, E-14 (Aufgaben). Konten bleiben bis F bestehen. Aktueller Zustand: G1 = N1 (Agenda), G2 = I2 (Kalender-Agenda).
| E-21 (Privat) | Wechsel auf „Privat“: Hinweis „Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.“; danach zeigte die noch geöffnete Detailseite „Gelöscht“ (Auffälligkeit, kein Plan-Verstoß) | E-21c/d-G2 | ✅ |
| E-15 | An: G1 „Test Nutzer 2 – Online“, G2 „Du bist online“; Aus (G1): G2 „Test N1 – Zuletzt online gerade eben“; wieder an. Teil „Gerade ist sonst niemand online“ nicht geprüft | E-15a-G1, E-15b-G2 | ✅ |
| E-22 | G2 legt „Kaese“ an; G1 sieht „zuletzt von Test Nutzer 2“, hakt ab; „2 erledigte Einträge für die ganze Familie entfernen?“ → entfernt (G2 aktualisiert); G2 löscht „vollkornbrot“, Liste leer auf beiden | E-22a..e | ✅ |

**Abschnitt E, Fortsetzung (Lauf 23:00 bis 23:05):**

| E-14 (Aufgaben) | I2 sieht unter „Aufgaben“ keine Schaltfläche „Neue Aufgabenliste“ | E-14b-G2 | ✅ |
| E-16 | Reaktion 👍 von G1 auf die Antwort von I2: bei beiden sichtbar; Bezug „Hallo von Nutzer 1“ bei G1 | E-16d/e-G1 | ✅ |
| E-18 | Einzelchat: Kopf „Nur zwischen dir und Test Nutzer 2“ vor dem Senden; bei G2 eigener Reiter „Test N1“ mit „Nur für dich“, nicht im Familienchat, kein Rohtext | E-18a-G1, E-18b-G2 | ✅ |
| E-23 | G1 legt „Müll rausbringen“ (Test Nutzer 2, Montag bis Freitag, Punkt „Tonne“) an; G2 hakt ab mit Kommentar; Verlauf „Tonne erledigt – Du · 27.10.2026, 22:54“ (Datum TT.MM.JJJJ, #38 ✅); „Bad putzen“ gelöscht. Der Verlaufseintrag zeigt „Du“ statt des Namens (aus Sicht von G2). G1-Abhaken-Sperre nicht geprüft | E-23a..e | ✅ |
| E-24 | Verifizierung: G2 „… möchte die Verifizierung starten“, 7 gleiche Symbole (Pizza, Schlüssel, Fahrrad, Erdbeere, Erde, Daumen, Schildkröte), beide „Verifiziert.“; Mitglied „Verifiziert“ | E-24a/b/c | ✅ |
| E-25 | „Nachricht melden“ mit Hinweis auf Betreiber, vier Gründen; „Meldung gesendet.“, Angebot „Absender blockieren“. Das Hinweis-Banner blieb danach lange stehen und verdeckte die Bedienung, bis zum App-Neustart | E-25a/E-25-G1 | ⚠️ (Toast bleibt hängen) |
| E-26 | „Test Nutzer 2 blockieren?“ mit Erklärung; G2 sendet „Noch da?“ ohne Fehler; bei G1 Nachrichten und Reiter von I2 ausgeblendet | E-26a-G1, E-26b-G2 | ✅ |
| E-27 | „Blockierung aufheben“ → „Du hast niemanden blockiert.“; „Noch da?“ wieder sichtbar | E-27a/E-27-G1 | ✅ |
| E-28 | Beide „Version 1.2.1 (17)“ | E-28-G1, E-28-G2 | ✅ |
| E-29 | „Konto löschen?“ mit „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“, Löschen ohne Passwort inaktiv; Abbrechen | E-29-G1 | ✅ |
| E-30 | Rückfrage „Test Nutzer 2 zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“; danach Abzeichen „Moderator“ bei I2, Empfehlung „zweiter Moderator“ verschwindet | E-30a/E-30-G1 | ✅ |
| E-31 | Dialog ohne Hinweis „einziger Moderator“ | E-31-G1 | ✅ |
| E-32 | G2: kein Moderator-Hinweis, nach Löschen „Willkommen“; G1: I2 nicht mehr in der Mitgliederliste, frühere Nachrichten bleiben sichtbar (als Benutzer-ID); `register/available` für `fnt-1027-i2`: M_USER_IN_USE | E-32a-G2, E-32b/c-G1 | ✅ |
| B-16 (Neustart) | App nach `terminate`/`launch`: dunkles Design bleibt | – | ✅ |

**Nicht ausgeführt in E (⏳):** E-12 (verbrauchter Link über das System öffnen; I2 existiert nicht mehr), E-17 (Anhang; Dateiauswahl im Simulator/auf dem Mac nicht automatisiert), E-05 „Per E-Mail senden“. **E-15 „Gerade ist sonst niemand online“** nicht im Bild.
Konten jetzt: N1 (G1, Moderator), N2 (abgemeldet, Familie F2 „Loeschtest“), I2 gelöscht. Abschnitt F steht aus.

**Abschnitt F (23:07 bis 23:22):**

| F-01 | N2 am Mac angemeldet (KN2, kein „Unbekannter Fehler“, #28 nicht aufgetreten); „Konto löschen“ nennt `@fnt-1027-n12:…`, Server, „dauerhaft gelöscht“, kein Moderator-Hinweis; falsches Passwort: „Das Passwort stimmt nicht.“, Dialog bleibt (#36 ✅); richtiges Passwort: „Willkommen“ | F-01a/c-G2 | ✅ |
| F-02 | Anmeldung N2 per curl: `403 M_FORBIDDEN` | – | ✅ |
| F-03 | „Alle lokalen Daten löschen?“ (Konto bleibt auf dem Server) → „Willkommen“ | F-03a/F-03-G1 | ✅ |
| F-04 | Nach App-Neustart „Willkommen“ | F-04-G1 | ✅ |
| F-05 | N1 angemeldet, mit KN1b freigeschaltet (Eingabe nur per Zwischenablage; Tippen im Simulator verlor Großbuchstaben, erste Versuche „Der Notfall-Schlüssel passt nicht“ waren Eingabefehler). Termine inkl. privater, Chat, Einkauf, Aufgaben wiederhergestellt (Heute: Test geteilt 2, Test privat, Test serie ×2) | F-05-G1 | ✅ |
| F-06 | N1 gelöscht (kein Moderator-Hinweis, Passwort-Fehleingabe zuerst „Das Passwort stimmt nicht.“), danach „Willkommen“ | F-06a/b-G1 | ✅ |
| F-07 | curl-Anmeldung N1, I2 und N2: alle `403 M_FORBIDDEN` | – | ✅ |
| F-08 | Konten des Laufs: `fnt-1027-n1`, `-n12`, `-i2` gelöscht (Anmeldung scheitert), `fnt-1027-n9` nie angelegt; Registrierung unverändert offen. Zusatzgerät „curltest“ ging mit der Kontolöschung unter. Geheimnisdateien (Passwörter, Schlüssel) aus dem Scratchpad entfernt | – | ✅ |

Zustand am Ende: Mac (G2) und Simulator (G1) zeigen „Willkommen“; keine Konten des Laufs mehr aktiv. G (automatische Tests) und H stehen aus.
