# Fortschritt Lauf 14 (Build 1.2.1 (21)), 30.10.2026 – vollständiger Plan TP-FN-001 v1.7

Arbeitsdatei während des Laufs; die Ergebnisse werden danach in `Testreport.md` und das PDF übernommen.

**Konfiguration:** G1 = macOS 27.2 (TestFlight-Build 1.2.1 (21), „TestFlight Beta Distribution“), G2 = iPhone-17-Simulator (iOS 27.0, DeviceHub; der Auftrag nannte „iPhone 127“, gestartet war „iPhone 17“; Build aus `main` @ e4180fb, Simulator-Debug-Build). Datumsteil der Konten: `1030`. Bildschirmschoner und Ruhezustand sind für den Lauf per `caffeinate -dimsu` gesperrt (keine Systemeinstellung geändert). Bedienung per Mausereignis, direkter Tastatureingabe, `simctl`, `curl`.

| Schritt | Erg. | Beobachtet |
|---|---|---|
| V-01 | ✅ | `main` = `origin/main` @ e4180fb, `pubspec.yaml` 1.2.1+21 |
| V-02 G1 | ✅ | 1.2.1 (21), Signatur „TestFlight Beta Distribution“ (Update über TestFlight von Build 20) |
| V-02 G2 | ✅ | `simctl listapps`: 1.2.1, CFBundleVersion 21 |
| V-04 G1 | ⚠️ | „Willkommen“ ist über den Zurück-Pfeil/Esc erreichbar, **nach einem Neustart steht aber „Konto erstellen“** (Server aus dem Link): Der Einladungslink aus meinem Mac-Test zu #59 (`open -a`) ist als „pendingInvite“ gespeichert und lässt sich vor der Kontoanlage nicht verwerfen. Container per Shell nicht zugänglich (macOS-Schutz). Beobachtung: Befund 1 (Einladung nicht verwerfbar). Weiter mit „Neue Familie gründen“ |
| V-04 G2 | ✅ | frisch installiert (deinstalliert, neu installiert): „Willkommen“ mit drei Wegen, Sprachwahl |
| V-05 | ✅ | `versions`; Registrierung liefert `flows` mit `m.login.dummy` |
| V-06 | ✅ | `fnt-1030-n1`, `-n12`, `-i2`, `-n9` frei |
| V-07 | ✅ | Gerätesprache Deutsch (beide); Bildschirmsperre am Mac vorhanden (Systempasswort); Benachrichtigungen der App am Mac schon erlaubt (siehe B-02), iOS-App frisch, nicht erlaubt |

## Etappe A (G1 = Mac, N1 = `fnt-1030-n1`)
| Schritt | Erg. | Beobachtet |
|---|---|---|
| A-01 | ✅ | Startseite wie erwartet (nach Zurück-Pfeil) |
| A-02 | ✅ | „English“ und „Deutsch“ wechseln sofort |
| A-03 | ⚠️ | Nach „Neue Familie gründen“ stand der Anbieter nicht auf matrix.org, sondern auf dem Testserver (gemerkter Einladungslink aus dem #59-Test, Befund 1). Nach Auswahl „matrix.org (empfohlen)“: „Bei matrix.org legst du dein Konto auf der Seite des Anbieters an. …“, Feld „Wie heißt du?“, „Konto bei matrix.org erstellen“ (nicht angetippt), „Dein Konto liegt bei matrix.org.“ |
| A-04 | ✅ | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ mit „Erneut versuchen“ |
| A-05 | ✅ | „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“, Betreiber/Kontakt |
| A-06 | ✅ | `Jörg Müßig` → `joerg.muessig`, „Der Benutzername ist frei.“ |
| A-07 | ✅ | alle sechs Eingaben mit vollständiger Meldung, „Konto erstellen“ ausgegraut (A-07a bis f) |
| A-08 | ✅ | Benutzername bleibt `fnt-1030-n1`; 7 Zeichen ausgegraut, ab 8 aktiv; Augen-Symbol; **leerer Name: ausgegraut** (gestern nicht geprüft). Aufnahme mit sichtbarem Passwort nicht abgelegt |
| A-09 | ✅ | N1 angelegt, kein Zusatzschritt, „Dein Notfall-Schlüssel“, „Schritt 2 von 3“ |
| A-10 | ✅ | Schlüssel bleibt nach 20 s stehen (#10); „Kopieren“; „Als Datei speichern“: „Gespeichert. Bewahre die Datei sicher auf – am besten ausgedruckt.“, Datei mit Konto, Anbieter, Datum, Schlüssel (nach Scratchpad verschoben); „Weiter“ erst nach Häkchen. Schlüsselzeile in allen Aufnahmen geschwärzt. Die Meldung „Kopiert. …“ wurde nicht erfasst (verschwand vor der Aufnahme) |
| A-11 | ✅ | Zuerst Beitrittskarte „Du trittst der Familie „Testfamilie 1029 neu“ bei“ (gemerkter Link, Befund 1); nach „Verwerfen“ Gründungsschritt mit Hinweisen zu Moderator und Einwilligung; „Fertig! „Testfamilie 1030“ ist eingerichtet.“ mit „Später“/„Jetzt einladen“ (Anlegen dauerte ca. 30 bis 45 s) |
| A-12 | ✅ | „Später“ → „Heute“ |

**Befund 1 (neu, Info/Niedrig):** Ein per `open -a`/Link geöffneter Einladungslink bleibt als „pendingInvite“ gespeichert, auch nach Zurück und Neustart; er überschreibt den Anbieter des Weges „Neue Familie gründen“ und zeigt im Familienschritt die Beitrittskarte statt der Gründung. Verwerfen geht erst im Familienschritt (nach der Kontoanlage).
- B-02 ✅ (Mac): Berechtigung in den Systemeinstellungen zurückgesetzt, Hinweis „Benachrichtigungen sind blockiert“ + „Erlauben“; kein Systemdialog (Berechtigung vorher abgelehnt), Hinweis wechselt zu „Benachrichtigungen sind in den Systemeinstellungen ausgeschaltet. Erlaube sie dort für FamilyNexus, sonst erscheinen keine Erinnerungen.“ in voller Breite mit „Einstellungen öffnen“ → öffnet direkt die Seite von FamilyNexus; nach Erlauben und Rückkehr ist der Hinweis weg (#57 am Mac bestätigt, Signatur TestFlight Beta Distribution)

## Etappe B (G1 = Mac, N1)
| Schritt | Erg. | Beobachtet |
|---|---|---|
| B-01 | ✅ | „Heute“ mit Kacheln Nächste Termine, Erinnerungen, Wer ist online, Einkaufszettel, Aufgaben; fünf Reiter, Menü, Plus-Schaltfläche |
| B-02 | ✅ | siehe oben (Mac, #57) |
| B-03 | ✅ | `Test geteilt`, 31.10. 10:00–11:00, „Geteilt“, Ort `Küche`, Notiz `Testnotiz`, Farbe Blau; Sichtbarkeit zuerst „Privat“, bei „Geteilt“ „Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.“; Agenda zeigt den Termin mit „Geteilt“ |
| B-04 | ✅ | „Bitte einen Titel eingeben.“; Ende 10:00 vor Beginn 11:00 und Ende = Beginn: „Das Ende muss nach dem Beginn liegen.“ direkt unter den Feldern (#34, #56); Zurück ohne Speichern |
| B-05 | ✅ | Tastatureingabe `21` im Zeitwähler angenommen (#64); Ende steht eine Stunde später (22:00 am selben Tag); „Privat“, Hinweis „Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.“. Bedienartefakt: Das Datumsfeld des Endes wanderte beim Datumswechsel mit (Ende stand zeitweise am 1.11./28.11.) und wurde von Hand auf den 31.10. gesetzt |
| B-06 | ✅ | `Test Serie` ganztägig 1.11., wöchentlich, nach Anzahl 3; Agenda: 1.11., 8.11., … mit „Privat“ und Wiederholungssymbol |
| B-07 | ✅ | Tag, Woche, Monat, Agenda; Zurück/Weiter/Heute funktionieren. Im verkleinerten Fenster (800×632) sind im Monatsraster die Termine der aufgenommenen Wochen nicht sichtbar (Aufnahme zeigt nur die ersten drei Zeilen) |
| B-08 | ✅ | Detail „Von dir“, Ort, Notiz; nach dem Speichern sofort „Test geteilt 2“ und „10:30 – 11:30“ (#63); „Verlauf (1)“ zeigt „Test geteilt – Version 1“ |
| B-09 | ✅ | „30 Minuten vorher“ zusätzlich gewählt, „Standard verwenden“ setzt zurück |
| B-10 | ✅ | `Test Erinnerung` 10:39 (in 12 Minuten, privat), Standard 10 Minuten, App im Hintergrund: um 10:29 liegt „Erinnerung – Termin in 10 Minuten“ (Vor 1 Min.) in der Mitteilungszentrale, ohne Titel und Ort (#57). Das Banner selbst wurde bei der Bildfolge nicht erfasst |
| B-11 | ✅ | „Alle Vorkommen oder nur dieses löschen?“: „Nur dieses“ entfernt nur den 8.11.; „Diesen Termin wirklich löschen?“ → „Löschen“ |
| B-13 | ✅ | „Im Chat teilen“ → „Im Chat geteilt“ (Karte im Chat siehe B-12) |
| B-12 | ✅ | Umschalt+Enter macht Zeilenumbruch, Enter sendet; „Ende-zu-Ende-verschlüsselt“; Nachricht mit Uhrzeit (10:32); Karte „Test geteilt 2“ aus B-13 mit Zusagen/Vielleicht/Absagen |
| B-14 | ✅ | Milch (`2 l`) und Brot (Enter) → „Zu besorgen (2)“; Milch abgehakt → „Erledigt (1)“; Brot → `Vollkornbrot` mit Enter gespeichert (#68); leerer Eintrag: nichts entsteht. Hinweis: Ein Klick traf versehentlich „Erledigte entfernen“ (Dialog „1 erledigte Einträge für die ganze Familie entfernen?“), mit „Abbrechen“ geschlossen |
| B-15 | ✅ | Hinweis „Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.“; leeres Speichern: „Bitte Titel, Person und mindestens einen Punkt angeben.“; Liste `Bad putzen` (Du, Wöchentlich/Montag, Waschbecken/Spiegel) unter „Mir zugewiesen“, „0 von 2 erledigt“, „Nächster Neustart: Montag, 2. November 2026“; Abhaken mit Kommentar `erledigt` → „1 von 2 erledigt“, „Erledigt am 30.10.2026 um 10:36“, Verlauf „Waschbecken erledigt · Du · 30.10.2026, 10:36“ (TT.MM.JJJJ, #38); „Heute“: „Aufgaben für dich: 1 offen“ |
| B-16 | ✅ | Sprache English↔Deutsch, Design „Hell“ und „Dunkel“, Akzent Magenta und zurück zu Türkis, „Effekte reduzieren“ an/aus: jede Änderung wirkt sofort (B-16a bis e). Persistenz nach Neustart siehe unten (C-Beginn) |
| B-17 | ⏳ | App-Sperre verlangt am Mac das Systempasswort/Touch ID (#58); in einem automatisierten Lauf nicht eingebbar, das Passwort des Nutzers wird nie eingegeben. Manuell oder auf echtem iPhone prüfen |
| B-18 | n/a | macOS hat keinen Schalter „Bildschirmschutz“ (Plan P-50); auf G2 (iOS) siehe Etappe C/E |
| B-19 | ✅ | „Online-Status teilen“ an; „Blockierte Mitglieder“: „Du hast niemanden blockiert.“; Datenschutzerklärung nennt „sicheren Schlüsselspeicher deines Geräts (Android-Keystore bzw. Apple-Schlüsselbund)“ (#78) |
| B-20 | ✅ | Standard-Erinnerung: 30 Minuten gewählt, 10 abgewählt (Mehrfachauswahl); Hinweis „Erinnerungen sind lokale Benachrichtigungen … Sie zeigen nie Titel oder Ort.“ |
| B-21 | ✅ | Speicherorte mit „Schlüsselbund des Geräts (nicht in iCloud)“; lokales Protokoll mit „App-Version 1.2.1 (21)“, Warnhinweis zum Klartext, „Protokoll kopiert.“ (Inhalt in der Zwischenablage mit Anzeigename, Einkauf, Aufgaben); Online-Protokoll mit Konto, Anzeigename „Test N1“, Gerät „FamilyNexus macOS … Verifiziert – Dieses Gerät“, Verschlüsselung |
| B-22 | ✅ | Menü und „Über die App“: „Version 1.2.1 (21)“; Konto: Server = Anbieter-Adresse, Benutzername `@fnt-1030-n1:matrix.chaostribunal.de` |
- B-02 (iOS-Zweig, G2, **#97 Nachtest**) ✅: „Erinnerungen – Benachrichtigungen sind blockiert. …“ + „Erlauben“ → iOS-Dialog „„FamilyNexus“ möchte dir Mitteilungen senden“ → „Nicht erlauben“ → Hinweis „Benachrichtigungen sind in den Systemeinstellungen ausgeschaltet. Erlaube sie dort für FamilyNexus, sonst erscheinen keine Erinnerungen.“ **in voller Breite** mit „Einstellungen öffnen“ auf „Heute“ (Aufnahme B-02c-G2). In den Einstellungen wegen nicht scrollbarer Ansicht (Ziehen greift nicht) nicht geprüft.

## Etappe C (G2 = iPhone-17-Simulator, N1)
| Schritt | Erg. | Beobachtet |
|---|---|---|
| C-01 | ✅ | Anbieter eingetragen, falsches Passwort → „Benutzername oder Passwort stimmen nicht.“ |
| C-02 | ✅ | Richtiges Passwort → „Dieses Gerät freischalten“ → „Mit „FamilyNexus macOS“ bestätigen“; G1 „… möchte die Verifizierung starten.“ → Annehmen; beide zeigen dieselben sieben Symbole (Geschenk, Hund, Schwein, Anker, Mais, Wolke, Katze) → „Sie stimmen überein“ → „Verifiziert.“; G2 zeigt „Heute“ mit Daten aus B (4 Termine, „4 Erinnerungen geplant“) |
| C-03 | ✅ | G2: „Dieses Gerät ist verifiziert.“; „FamilyNexus macOS – Verifiziert“, „FamilyNexus iOS (Dieses Gerät) – Verifiziert“; G1 zeigt beide Geräte ebenfalls („FamilyNexus macOS (Dieses Gerät)“, „FamilyNexus iOS“) – die Beobachtung aus Lauf 13 (iOS-Gerät fehlt auf G1) ist hier **nicht** aufgetreten |
| C-04 | ✅ | Abmelden → Dialog → „Anmelden“; Anbieter wieder matrix.org (#61, bekannt). Danach zeigt G1 nur „FamilyNexus macOS (Dieses Gerät)“ (Gerät von G2 beim Abmelden entfernt) |
| C-05 | ✅ | G1: Seite „Neuer Notfall-Schlüssel“ mit Erklärung („Der alte funktioniert danach nicht mehr …“); neuer Schlüssel (KN1b); Zurück-Pfeil, Esc, ⌘[ ohne Wirkung; Häkchen + „Weiter“ → Einstellungen. Schlüsselzeile geschwärzt. Hinweis: ein Klick traf versehentlich „Konto löschen“ (Dialog, mit „Abbrechen“ geschlossen, nichts gelöscht) |
| C-06 | ✅ | KN1 (alt) → „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“ (Feld in der Aufnahme geschwärzt) |
| C-07 | ✅ | KN1b → freigeschaltet, Hauptansicht mit Daten aus B |

## Etappe D (G2 = N2 `fnt-1030-n12`, G1 = N1)
- D-01 ✅ Name `Test N2`, Benutzername `fnt-1030-n1` → „Schon vergeben – wie wäre es mit „fnt-1030-n12“?“ + Chip, „Konto erstellen“ ausgegraut; nach dem Chip „Der Benutzername ist frei.“ + Haken; Konto ohne Zusatzschritt angelegt; Notfall-Schlüssel (KN2, Scratchpad) erzeugt und gesichert; Familienschritt „Schritt 3 von 3“ mit Umschalter „Gründen | Beitreten“. Bedienartefakte: ⌘→ im Simulator dreht das Gerät (zurückgedreht); Anbieter-Feld nur per Tab-Taste erreichbar (Seite scrollt nicht per Ziehen)
- E-01 ✅ (G1, vorgezogen) Familie „Testfamilie 1030“, „Empfehlung: Ernenne einen zweiten Moderator.“, nur Test N1 (Moderator), „Jemanden einladen“, Familien-Code (in der Aufnahme geschwärzt)
- D-02 ✅ **#75-Messung:** G2 `abc` → „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ und enthält einen Server, z. B. !abc:matrix.org.“; echter Code (43 Zeichen, `!…:matrix.chaostribunal.de`) → „Fast geschafft! Deine Anfrage ist unterwegs. Sobald sie bestätigt ist, bist du dabei.“ mit „Anfrage zurückziehen“. G1: Tab „Familie“ mit Badge „1“, „Test N2 möchte beitreten“, „Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du @fnt-1030-n12:… kennst und erwartest“. „Ablehnen“ geklickt um 10:55:04 → G2 zeigt „Deine Anfrage wurde abgelehnt. Frag bei der Familie nach, ob sie dich einladen möchte, und versuche es dann mit einem neuen Link.“ + „Verstanden“ um 10:55:14, **ca. 10 s** (Ziel ≤ 20 s; Abfrage alle 2 s per `simctl io screenshot`). Nur Simulator, Debug-Log nicht gelesen
- D-03 ✅ „Verstanden“ → „Gründen“ → `Löschtest 1030` → direkt „Heute“ (ohne Zwischenschritt „Fertig!“)
- B-18 (G2, iOS) ⏳ Schalter „Bildschirmschutz“ vorhanden („Blockiert Screenshots und verbirgt die App in der Übersicht.“), an/aus schaltbar; im Simulator liefert `simctl io screenshot` in beiden Zuständen ein normales Bild (mittlere Helligkeit 33,3 / 33,2), die Wirkung (Screenshot blockiert, App-Übersicht verborgen) ist nur auf einem echten iPhone prüfbar. Aufnahmen B-18a/b/c-G2
- D-04 ✅ (⚠️ Teil) Abmelden → „Jetzt erstellen“ → Anbieter, Name `Test`, `fnt-1030-n12` → „Ich habe schon ein Konto“ → „Anmelden“ mit vorausgefülltem Benutzernamen `fnt-1030-n12`; die **Anbieter-Adresse stand dort wieder leer** („Bitte gib die Adresse des Anbieters ein.“; in Lauf 13 blieb sie erhalten) und musste neu eingetragen werden (Beobachtung, vermutlich eine Folge von „Anderen Anbieter verwenden“ bei leerem Feld; #61)
- D-05 ✅ Passwort N2 → „Dieses Gerät freischalten“: „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“ (kein „Mit … bestätigen“); KN2 → „Freischalten“ → in **ca. 3 s** „Heute“ der Familie F2 (kein „Synchronisiere …“-Hänger, #24 nicht aufgetreten)
- D-06 ✅ Formular mit `fnt-1030-n9` begonnen, Zurück-Pfeil ohne „Konto erstellen“ → „Willkommen bei FamilyNexus“; Gegenprobe `…/register/available?username=fnt-1030-n9` → `{"available":true}`
- D-07 ⏳ optional (Serverzugang nötig), nicht ausgeführt
- Zustand nach D: G2 = „Willkommen“ (N2 abgemeldet), Familie F2 „Löschtest 1030“ (N2) besteht; G1 = N1 angemeldet in F1 „Testfamilie 1030“

## Etappe E (G1 = N1, G2 = I2 `fnt-1030-i2`)
- E-02 ✅ „Familienname ändern“ → `Testfamilie 1030 neu` mit Enter gespeichert (#68) → „Name geändert.“
- E-05 ✅ „Jemanden einladen“: QR-Code, „Gültig für 1 Tag | 3 Tage | 7 Tage“ (3 Tage), „Erweitert“ → „Konto-Server für Neue“ (Server eingetragen) → „Neuen Link erzeugen“; „Link kopieren“ → „Link kopiert.“ im Dialog (#66); Link (308 Zeichen, Einmal-Code `n=`) nur im Scratchpad. „Per E-Mail senden“ (Thunderbird) in diesem Lauf nicht ausgeführt
- E-03 ✅ `abc` → „Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.“; `@fnt-1030-n12:matrix.chaostribunal.de` → Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie – lade nur Personen ein, die du sicher kennst.“ → N2 „Eingeladen“
- E-04 ✅ „Entfernen“ → „Test N2 wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert; neue Inhalte kann Test N2 nicht mehr lesen.“ → N2 verschwindet aus der Liste
- E-06 ✅ `abc` → „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.“ (#26); um 10 Zeichen gekürzt → „Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. Bitte kopiere ihn noch einmal vollständig oder scanne den QR-Code.“
- E-07 ✅ (#59) `xcrun simctl openurl` mit dem https-Link → Safari „Einladung zu FamilyNexus“ („App öffnen“, „Link kopieren“, „Die App ist noch nicht installiert?“) → „In „FamilyNexus“ öffnen?“ → „Öffnen“ → Kontoanlage
- E-08 ✅ „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“ (nicht matrix.org), „Schritt 2 von 4“
- E-09 ✅ `Test Nutzer 2` / `fnt-1030-i2` (alle Felder stimmten diesmal, kein Überschreiben des Namensvorschlags) → „Konto erstellen“ ohne Zusatzschritt → Notfall-Schlüssel
- E-10 ✅ Schlüssel (KI2, Scratchpad), Häkchen, „Weiter“ → Beitrittskarte „Familie beitreten“ („Schritt 4 von 4“): „Du trittst der Familie „Testfamilie 1030 neu“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.chaostribunal.de).“ mit „Details“, „Verwerfen“, „Beitritt anfragen“
- E-11 ✅ Beitritt angefragt 11:07:28 → I2 wurde nach **ca. 3 s** automatisch aufgenommen: G2 „Heute“ mit „Test geteilt 2 – Von Test N1“, „Test N1 – Online“
- E-12 ✅ (#59) Verbrauchter Link per `simctl openurl` → „App öffnen“ → „Öffnen“ → „Du bist bereits in einer Familie.“ am unteren Rand, nichts ändert sich, kein Absturz
- E-13 ✅ G1: Test N1 (Moderator), Test Nutzer 2 (Mitglied, „Nicht persönlich geprüft“, Online); G2: Familienname „Testfamilie 1030 neu“, Test N1 „Zuletzt online gerade eben“ (G1 lag zu dem Zeitpunkt im Hintergrund), Test Nutzer 2 „Du bist online“
- E-14 ✅ G2: „Nur Moderatoren verwalten die Familie.“, keine Verwaltungsaktionen (kein „Familienname ändern“, kein „Jemanden einladen“, kein Familien-Code); Aufgaben: „Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.“, keine Schaltfläche „Neue Aufgabenliste“; Liste „Bad putzen – Zugewiesen an Test N1, 1 von 2 erledigt“
- E-15 ✅ An: „Test N1 – Online“ (G2 „Heute“); G1 „Online-Status teilen“ aus → G2 „Gerade ist sonst niemand online.“; wieder an → „Test N1 – Online“
- E-28 (G2) ✅ Menü „Version 1.2.1 (21)“
- E-16 ✅ G1 sendet `Hallo von Nutzer 1`; G2 zeigt einen einzigen Hinweis „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ (#35) und die Nachricht; langer Druck → Menü „Antworten“, Reaktionen 👍 ❤️ 😂 🎉 😮 🙏, „Nachricht melden“, „Test N1 blockieren“; „Antwort an Test N1“ → `Hallo zurück von Nutzer 2`; G1 zeigt die Antwort mit Bezug; **Reaktion 👍 bei beiden Geräten (👍 1)**
- E-16 (Zähler) ✅ Nach einer weiteren Nachricht von G1 zeigt G2 vor dem Öffnen das Badge „1“ am Chat-Tab und auf „Heute“ „Ungelesene Nachrichten – 1 ungelesene Nachricht“ (#65; nur lesbare Nachrichten)
- E-17 ✅ (diesmal bedienbar) G1: „Datei anhängen“ → Systemdialog (Pfad per ⇧⌘G) → Bild `e17_bild.png` und Textdatei `e17_text.txt` gesendet; G2: beide erscheinen; Bild: „Anhang laden“ → sichtbar, „Speichern“ unter dem Bild (#40); beim Speichern Warnung „Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. Sie bleibt dort auch nach dem Abmelden oder Löschen der App-Daten erhalten. Fortfahren?“; iOS-Dialog „Sichern unter e17_text“ → „Sichern“ → Datei im Ordner „Auf meinem iPhone“
- E-19 ✅ (Teil) G2 Kalender: Monatsansicht mit „Alle | Test N1 | Test Nutzer 2“; am 31.10. ein Punkt (Test geteilt 2), die privaten Termine „Test privat“ und die Serie nicht sichtbar
- E-18 ✅ **(#77)** G1: Familie → „Nachricht schreiben“ bei Test Nutzer 2 → Reiter „Test Nutzer 2“: „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“ (#31); `Nur für dich` gesendet 11:15:18. G2: Reiter „Test N1“ mit Badge „1“ nach ca. 6 s; die Nachricht steht nicht im Familienchat; nach dem Antippen des Reiters steht sie **sofort** (≤ 1 s) im Einzelchat „Nur zwischen dir und Test N1“, kein Reiterwechsel nötig, kein Rohtext „Attempting verification request“ (#29)
- E-19 ✅ G2: Filter „Test Nutzer 2“ → „Keine Termine“; „Test N1“ → „1 Termin“ (Test geteilt 2); „Test privat“ und „Test Serie“ nicht sichtbar (Mehrfachauswahl der Chips)
- E-20 ✅ G2 öffnet „Test geteilt 2“: „Nur der Ersteller kann diesen Termin ändern.“, „Antwort“ mit Zusagen/Vielleicht/Absagen („Keine Antwort“), kein „Im Chat teilen“; nach „Zusagen“ zeigt G1 unter „Antwort“ „Test Nutzer 2 – Zugesagt“; „Im Chat teilen“ nur bei G1
- E-21 ✅ G2 legt `Termin I2` (31.10. 12:00–13:00) „Geteilt“ an; G1 zeigt ihn in der Agenda „Von Test Nutzer 2“ mit „Geteilt“; beim Wechsel auf „Privat“ erscheint „Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.“ (nicht gespeichert, Termin bleibt geteilt)
- E-22 ✅ G2 sieht „Vollkornbrot“ und „Milch“ (zuletzt von Test N1), legt `Käse` an → G1 zeigt „Käse – zuletzt von Test Nutzer 2“; G1 hakt „Käse“ ab → „Erledigt (2)“; „Erledigte entfernen“ → „2 erledigte Einträge für die ganze Familie entfernen?“ → beide zeigen nur noch „Vollkornbrot“; G2 löscht „Vollkornbrot“ → bei beiden „Der Einkaufszettel ist leer. Füge oben etwas hinzu.“. Zwischenfall: Ein Fehlklick setzte am Termin I2 „2 Stunden vorher“, wieder zurückgesetzt
- E-23 ✅ **(#76)** G1 „Neue Aufgabenliste“: `Müll rausbringen`, Zugewiesen an Test Nutzer 2, „Täglich“ → „Montag bis Freitag (ohne Wochenende)“ mit Hinweis „Startet montags bis freitags neu, nicht am Wochenende“ (Auswahl vor dem Speichern aufgenommen: E-23a), Punkt `Tonne raus`. Nach dem Speichern bei G1 und G2 Kürzel „Mo–Fr“, Detail „Montag bis Freitag · Startet montags bis freitags neu, nicht am Wochenende · Nächster Neustart: Montag, 2. November 2026“ (nicht „Täglich“). G1 kann den Punkt nicht abhaken; G2: Liste unter „Mir zugewiesen“, Abhaken mit Kommentar `Erledigt, Tonne steht draußen` → „Erledigt am 30.10.2026 um 11:22“, Verlauf bei G2 „Du · 30.10.2026, 11:22“ und bei G1 „Test Nutzer 2 · 30.10.2026, 11:22“ (TT.MM.JJJJ, #38); G1 löscht „Bad putzen“ („Liste „Bad putzen“ löschen?“ → weg). Nicht geprüft: „Aufgaben für dich: 1 offen“ vor dem Abhaken auf „Heute“ (nur nachher „0 offen“)
- E-24 ✅ G1 „Verifizieren“ → „Warte auf die Gegenseite …“; G2 „@fnt-1030-n1:… möchte die Verifizierung starten.“ → Annehmen; beide zeigen 🚂 ❤️ 🦄 ✏️ 🤖 🐶 🍌 → „Sie stimmen überein“ → „Verifiziert.“; Mitgliederliste „Verifiziert“
- E-25 ✅ G2 sendet `Spam-Test von Nutzer 2`; G1 langer Druck → Menü (Antworten, Reaktionen, „Nachricht melden“, „Test Nutzer 2 blockieren“) → Dialog „Nachricht melden“ („Die Meldung geht an den Betreiber deines Servers (matrix-synapse-3ues.srv1348446.hstgr.cloud). Er kann den verschlüsselten Inhalt nicht lesen. …“, vier Gründe: Spam oder Werbung, Belästigung oder Beleidigung, Unangemessener Inhalt, Anderer Grund; Textfeld 0/300) → „Spam oder Werbung“ + `Testmeldung aus Lauf 14` → „Melden“ → „Meldung gesendet.“ mit „Absender blockieren“ (gut lesbar, #62), verschwindet nach ca. 8 s (#45)
- E-26 ✅ „Test Nutzer 2 blockieren?“ („Nachrichten und der Einzelchat von Test Nutzer 2 werden auf diesem Gerät ausgeblendet. Test Nutzer 2 erfährt davon nichts und bleibt Mitglied der Familie. …“) → „Blockieren“: Nachrichten und der Reiter von I2 bei G1 ausgeblendet; G2 sendet `Noch da?`, keine Fehlermeldung, die Nachricht steht bei G2
- E-27 ✅ Einstellungen: „Blockierte Mitglieder 1“ → „Test Nutzer 2 @fnt-1030-i2:…“ → „Blockierung aufheben“ → „Blockierung von Test Nutzer 2 aufgehoben.“, „Du hast niemanden blockiert.“; im Chat wieder `Spam-Test von Nutzer 2` und `Noch da?` sichtbar, Reiter „Test Nutzer 2“ wieder da
- E-28 ✅ Menü auf G1 und G2: „Version 1.2.1 (21)“
- E-29 ✅ (#12) „Konto löschen?“: „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator, sonst kann niemand mehr die Familie verwalten.“; „Konto endgültig löschen“ ohne Passwort inaktiv; „Abbrechen“ → unverändert
- E-30 ✅ „Zum Moderator ernennen“ → Rückfrage „Test Nutzer 2 zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“ → beide zeigen Test Nutzer 2 als Moderator; G2 hat Verwaltungsaktionen. **Die Empfehlung „Ernenne einen zweiten Moderator.“ ist nach der Ernennung verschwunden** – Beobachtung aus Lauf 13 (Befund 3) trat nicht auf; G1 zeigt auch keine Empfehlung mehr beim Neuöffnen
- E-31 ✅ G1 „Konto löschen?“ ohne Hinweis „einziger Moderator“ (Dialog nur angesehen, „Abbrechen“)
- E-32 ✅ G2 (I2): „Konto löschen?“ nennt `@fnt-1030-i2:matrix.chaostribunal.de` und den Server, ohne Moderator-Hinweis (N1 ist Moderator), Passwort → „Willkommen“ (nicht „Anmelden“); G1: Test Nutzer 2 nicht mehr in der Mitgliederliste und der Einzelchat-Reiter weg; die Chatnachrichten `Spam-Test von Nutzer 2` und `Noch da?` bleiben mit dem Namen „Test Nutzer 2“ sichtbar (nie mit Matrix-ID, #60)
- E-01 (Nachtrag) und E-13/E-30b: In diesen Aufnahmen steht der Familien-Code der Wegwerf-Familie; soweit lesbar geschwärzt.

Zustand nach E: G1 = N1 in F1 „Testfamilie 1030 neu“ (allein, I2 gelöscht); G2 = „Willkommen“; N2 (`fnt-1030-n12`) ist in „Löschtest 1030“ Moderator und noch nicht gelöscht.
- E-32a-G2: Aufnahme des Löschdialogs von I2 ging beim Schwärzen verloren (Zeile mit Benutzer-ID irrtümlich verdeckt); Dialog identisch zu F-01a-G2 (N2)

## Etappe F
- F-01 ✅ G2 (N2): Anmeldung (Anbieter-Adresse neu eingetragen), direkt „Dieses Gerät freischalten“ (kein „Unbekannter Fehler.“, #28), KN2 → freigeschaltet; „Konto löschen?“ nennt `@fnt-1030-n12:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, „Nachrichten … bleiben … sichtbar“, kein Moderator-Hinweis; falsches Passwort → „Das Passwort stimmt nicht.“ (#36), Dialog bleibt; richtiges Passwort → „Willkommen“
- F-02 ✅ curl-Login `fnt-1030-n12`: 403 M_FORBIDDEN
- F-07 (Teil I2) ✅ curl-Login `fnt-1030-i2`: 403 M_FORBIDDEN
- F-03 ✅ G1 „Alle lokalen Daten löschen“: Rückfrage „Alle lokalen Daten löschen?“ (Konto beim Server bleibt), „Endgültig löschen“ → „Willkommen“. Aufnahmen F-03-G1, F-03b-G1
- F-04 ✅ App beendet und neu gestartet → „Willkommen“ (F-04-G1)
- F-05 ✅ „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter (stand wieder auf matrix.org, #61) → N1 → „Dieses Gerät freischalten“ mit KN1b → freigeschaltet. Wiederhergestellt: Termine (geteilt „Test geteilt 2“, „Termin I2“ **„Von Ehemaliges Mitglied“**, privat „Test privat“, Serie „Test Serie“), Chat (Nachrichten von I2 als „Ehemaliges Mitglied“, nicht Matrix-ID, #60), Aufgabenliste „Müll rausbringen“ mit **„Zugewiesen an Ehemaliges Mitglied“** (**#98 behoben**, in Lauf 13 stand dort die Matrix-ID von I2). Aufnahmen F-05e bis F-05i-G1
- F-06 ✅ G1 (N1): „Konto löschen?“ ohne Moderator-Hinweis, Passwort → „Willkommen“ (F-06a/b-G1)
- F-07 ✅ curl-Login `fnt-1030-n1`, `fnt-1030-n12`, `fnt-1030-i2` (richtiges Passwort): jeweils 403 M_FORBIDDEN
- F-08 ✅ Zustand am Ende: alle drei Konten des Laufs (n1, n12, i2) gelöscht; `fnt-1030-n9` nie angelegt (`register/available` → true). Die Familien „Löschtest 1030“ und „Testfamilie 1030 neu“ bestehen ohne Mitglieder auf dem Server weiter. Registrierung unverändert. G1 und G2 zeigen „Willkommen“.

## Etappe G
- G-01 ✅ `flutter analyze`: No issues found
- G-02 ✅ `flutter test`: 784 bestanden, 49 übersprungen, 0 fehlgeschlagen (inkl. `test/store/review_notes_test.dart`)
- G-04/G-06/G-07/G-08: nicht ausgeführt (optional bzw. keine Testperson, kein echtes iPhone)

## Bildschirmschoner
`caffeinate -dimsu` lief für die Dauer des Laufs; keine Systemeinstellung wurde geändert.
