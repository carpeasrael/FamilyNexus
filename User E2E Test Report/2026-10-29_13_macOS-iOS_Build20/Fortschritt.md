# Fortschritt Lauf 13 (Build 1.2.1 (20)), Stand 29.10.2026, ca. 00:10 – Etappen A und B (Mac) abgeschlossen

Arbeitsdatei während des Laufs; die Ergebnisse werden danach in `Testreport.md` übernommen.

**Konfiguration:** G1 = macOS (TestFlight-Build 1.2.1 (20), Distribution-Signatur), G2 = iPhone-15-Simulator (Build aus `main` @ a6993a0, noch nicht installiert). Datumsteil der Konten: `1029` (Namen frei geprüft). Bedienung per Mausereignis (CoreGraphics), Eingabe per Zwischenablage, Aufnahmen mit `screencapture` je Fenster.

**Vorbereitung am Mac:** Die App fragte nach dem Passwort des Anmelde-Schlüsselbunds (Altlast aus früheren Builds, #61). Auf Anweisung des Nutzers wurden die beiden Einträge `flutter_secure_storage_service` / `fn.key.db.app` und `fn.key.db.matrix` per `security` gelöscht (der Eintrag „FamilyNexus upload key backup“ blieb unberührt). Danach „Lokale Daten nicht lesbar“ → „Lokale Daten zurücksetzen“ → „Willkommen“.

| Schritt | Erg. | Beobachtet |
|---|---|---|
| V-01 | ✅ | `main` @ 5469f8d, 1.2.1+20 |
| V-02 G1 | ✅ | 1.2.1 (20), „TestFlight Beta Distribution“ |
| V-04 G1 | ✅ | nach Zurücksetzen „Willkommen“ mit drei Wegen und Sprachwahl |
| V-05 | ✅ | Server liefert `versions` und `m.login.dummy` |
| V-06 | ✅ | `fnt-1029-n1`, `-n12`, `-i2`, `-n9` frei |
| A-01 | ✅ | Startseite wie erwartet (Screenshot A-01-G1) |
| A-03 | ✅ | „Konto erstellen“, Schritt 1 von 3, „Dein Konto liegt bei matrix.org.“ |
| A-04 | ✅ | „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ |
| A-05 | ✅ | „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“, Betreiber, Kontakt „nicht angegeben“ |
| A-06 | ✅ | `Jörg Müßig` → `joerg.muessig`, „Der Benutzername ist frei.“ |
| A-07 | ✅ | alle sechs Eingaben (`ab`, `Anna`, `anna müller`, `.anna`, `anna.`, 33 × `a`) zeigen die vollständige Meldung, „Konto erstellen“ ausgegraut (#44 bestätigt) |
| A-02 | ✅ | „English“ und „Deutsch“ wechseln die Texte sofort |
| A-08 | ✅ | Benutzername bleibt `fnt-1029-n1`, „Der Benutzername ist frei.“; 7 Zeichen: „Konto erstellen“ ausgegraut, ab 8 aktiv; Augen-Symbol zeigt/verbirgt. Nicht geprüft: leerer Name. Die Aufnahme mit sichtbarem Passwort wurde nicht abgelegt (Passwort geschwärzt) |
| A-09 | ✅ | N1 angelegt in ca. 8 s, „Dein Notfall-Schlüssel“, Schritt 2 von 3, kein Zusatzschritt |
| A-10 | ✅ | Schlüssel bleibt nach 20 s stehen (#10); „Kopiert. … Die Zwischenablage wird nach einer Minute geleert.“; „Als Datei speichern“ meldet „Gespeichert. …“, Datei mit Konto, Anbieter, Datum, Schlüssel. „Weiter“ erst nach dem Häkchen. Schlüssel (KN1) lokal abgelegt, Aufnahmen ohne Schlüsselzeile |
| A-11 | ✅ | „Fertig! „Testfamilie 1029“ ist eingerichtet.“ mit „Später“ und „Jetzt einladen“ |
| A-12 | ✅ | Hauptansicht „Heute“ |
| B-01 (Teil) | ✅ | Kacheln „Nächste Termine“, „Erinnerungen“, „Wer ist online“, „Einkaufszettel“, „Aufgaben“, „Ungelesene Nachrichten“; fünf Reiter; Menü; Plus-Schaltfläche |

**Beobachtung für B-02:** Auf „Heute“ erscheint **kein** Hinweis „Benachrichtigungen sind blockiert“. Vermutlich ist die Berechtigung für diese Bundle-ID bereits erteilt; in den Systemeinstellungen prüfen, bevor B-02 bewertet wird.

## Etappe B (Mac, G1 = N1)

| Schritt | Erg. | Beobachtet |
|---|---|---|
| B-01 | ✅ | Kacheln, fünf Reiter, Menü, Plus-Schaltfläche; Sortierung der Termine in B-07 |
| B-02 | ⏳ | Auf „Heute“ erscheint **kein** Hinweis „Benachrichtigungen sind blockiert“: Die Berechtigung für die Bundle-ID war schon erteilt (Transporter-Meldungen zeigen, dass Benachrichtigungen für Apps funktionieren; die Erinnerung aus B-10 kam an). Der Zweig „kein Systemdialog / Einstellungen öffnen“ (#57) wurde damit nicht ausgelöst und ist am Mac nicht prüfbar, ohne die Berechtigung in den Systemeinstellungen zurückzusetzen |
| B-03 | ✅ | Geteilter Termin mit Ort „Küche“ und Notiz; Hinweis „Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.“ |
| B-04 | ✅ | „Bitte einen Titel eingeben.“; Ende 09:00 vor Beginn 10:00 und Ende = Beginn: „Das Ende muss nach dem Beginn liegen.“ direkt unter den Feldern (#34, #56 bestätigt). Beim ersten Anlegen wurde die Endzeit 09:00 nicht übernommen (Termin wurde mit 11:00 gespeichert); beim Bearbeiten wirkte sie. Nicht eindeutig geklärt, vermutlich Bedienartefakt |
| B-05 | ✅ | Tastatureingabe `21` im Zeitwähler angenommen (#64), Ende wandert auf 22:00; Termin „Privat“ |
| B-06 | ✅ | `Test Serie` ganztägig, wöchentlich, nach Anzahl 3: Vorkommen am 31.10., 7.11., 14.11.; „Privat“, Wiederholungssymbol |
| B-07 | ✅ | Tag, Woche, Monat, Agenda, Zurück/Weiter/Heute funktionieren |
| B-08 | ✅ | Nach dem Speichern sofort „Test geteilt 2“ und „10:30 – 11:30“ (#63 bestätigt); Verlauf (3) statt (1), weil vorher zusätzlich bearbeitet wurde |
| B-09 | ✅ | „30 Minuten vorher“ zusätzlich gewählt, „Standard verwenden“ setzt zurück |
| B-10 | ✅ | `Test Erinnerung` 23:59, Erinnerung 10 Minuten: um ca. 23:49 erscheint in der Mitteilungszentrale „Erinnerung – Termin in 10 Minuten“ (Vor 1 Min.), ohne Titel und Ort. Das Banner selbst wurde bei der Bildfolge nicht erfasst, die Mitteilungszentrale zeigt den Eintrag (#57: Erinnerung kommt an) |
| B-11 | ✅ | „Alle Vorkommen oder nur dieses löschen?“: „Nur dieses“ entfernt nur den 31.10.; „Diesen Termin wirklich löschen?“ → „Löschen“ |
| B-12 | ✅ | Umschalt+Enter macht Zeilenumbruch, Enter sendet; Nachricht mit Uhrzeit (#37) |
| B-13 | ✅ | Im Chat Karte „Test geteilt 2“ mit „Zusagen/Vielleicht/Absagen“ |
| B-14 | ⚠️ | Milch (2 l) und Brot (Enter) hinzugefügt, Milch abgehakt („Zu besorgen (1)“, „Erledigt (1)“), Brot → `Vollkornbrot` mit Enter gespeichert (#68). Leerer Eintrag: keine Meldung erkennbar (Aufnahme evtl. zu spät), es wurde nichts hinzugefügt |
| B-15 | ✅ | Hinweis „Nur Moderatoren legen Listen an …“; Liste „Mir zugewiesen“, „0 von 2 erledigt“, „Nächster Neustart: Montag, 2. November 2026“; Abhaken mit Kommentar; Verlauf „Waschbecken erledigt, Du · 29.10.2026, 23:54“ (`TT.MM.JJJJ`, #38) |
| B-16 | ✅ | Akzentfarbe Magenta/Türkis, „Effekte reduzieren“ an/aus, Design „Hell“ und zurück „Dunkel“ wirken sofort. Neustart-Persistenz nicht geprüft |
| B-17 | ⏳ | App-Sperre verlangt das Systempasswort am Mac (#58), nicht automatisierbar; manuell prüfen |
| B-18 | n/a | macOS hat keinen Schalter „Bildschirmschutz“ (Plan P-50) |
| B-19 | ✅ | „Datenschutzerklärung“ zeigt „sicheren Schlüsselspeicher deines Geräts (Android-Keystore bzw. Apple-Schlüsselbund)“ (#78 bestätigt); „Blockierte Mitglieder“ vorhanden, „Online-Status teilen“ an |
| B-20 | ✅ | Standard-Erinnerung: 30 Minuten gewählt, 10 abgewählt (Mehrfachauswahl) |
| B-21 | ⚠️ | Speicherorte mit „Schlüsselbund des Geräts (nicht in iCloud)“; lokales Protokoll mit „App-Version 1.2.1 (20)“ und Warnhinweis. „Kopieren“ und das Online-Protokoll nicht ausgeführt |
| B-22 | ✅ | Menü und Einstellungen: „Version 1.2.1 (20)“; Konto: Server = Anbieter-Adresse, Benutzername `@fnt-1029-n1:matrix.chaostribunal.de` |

**Befunde Etappe B:** keine neuen App-Fehler. Offen: B-02 (Berechtigung schon erteilt), B-17 (Systempasswort), B-14/B-21 (Teilpunkte nicht geprüft).

## Etappe C (G1 = Mac, G2 = iPhone 17 Simulator, iOS 27.0, über DeviceHub)

Abweichung zum Auftrag: G2 ist die laufende Emulation „iPhone 17“ (iOS 27.0, UDID B79C8B8B…), nicht „iPhone 15 Test“. Grund: Auf diesem Mac fehlt Simulator.app (Xcode 27.1 bringt nur DeviceHub mit); nur dessen Fenster ist per Mausklick bedienbar. Zwischenablage im Simulator: `simctl pbcopy` + ⌘V; iOS fragt bei jedem Einfügen „„FamilyNexus“ möchte von „dtpasteboardd“ einsetzen“ (Bedienartefakt, kein App-Fehler). G2-Installation: Simulator-Build aus main (Runner.app), Version 1.2.1 (20) laut Menü.

- C-01 ✅ falsches Passwort → „Benutzername oder Passwort stimmen nicht.“ (Anbieter-Auswahl „Anderen Anbieter verwenden“ → Adresse eingegeben)
- C-02 ✅ „Dieses Gerät freischalten“ → „Mit „FamilyNexus macOS“ bestätigen“; G1 „@fnt-1029-n1:… möchte die Verifizierung starten.“ → Annehmen; beide zeigen Fisch, Pokal, Glocke, Zylinder, Schloss, Panda, Huhn → „Sie stimmen überein“ → „Verifiziert.“; G2 zeigt Hauptansicht mit Terminen aus B (Test geteilt 2, Test privat, Test Serie ×2, „4 Erinnerungen geplant“)
- C-03 ✅ „Dieses Gerät ist verifiziert.“; Geräte: „FamilyNexus macOS – Verifiziert“, „FamilyNexus iOS (Dieses Gerät) – Verifiziert“; „Neuen Notfall-Schlüssel erstellen“ vorhanden. Beobachtung: Die Geräteliste auf G1 zeigte zu diesem Zeitpunkt nur „FamilyNexus macOS (Dieses Gerät)“, das iOS-Gerät fehlte dort (Liste evtl. nicht aktualisiert, später prüfen)
- C-04 ✅ Abmelden → Dialog „Abmelden“ → Seite „Anmelden“ (nicht „Willkommen“). Beobachtung: Anbieter-Auswahl steht wieder auf „matrix.org“, die eigene Adresse muss neu eingegeben werden
- C-05 ✅ (G1) Seite „Neuer Notfall-Schlüssel“, Erklärung vorhanden; Schlüssel angezeigt (KN1b, nur in Scratchpad); „Kopiert … Zwischenablage nach einer Minute geleert“; Zurück-Pfeil, Esc, ⌘[ ohne Wirkung; Häkchen + „Weiter“ → zurück in den Einstellungen. Schlüsselzeile in den Aufnahmen geschwärzt
- C-06 ✅ alter Schlüssel KN1 → „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“; Gerät bleibt gesperrt
- C-07 ✅ KN1b → Hauptansicht mit Daten aus B
- C-08 ✅ Abmelden → „Anmelden“
- B-02 (iOS-Zweig, Zusatz): Auf „Heute“ zeigt G2 „Erinnerungen – Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.“ mit „Erlauben“ (iOS-Berechtigung nicht erteilt). Noch nicht angetippt.
- Keine neuen App-Fehler in Etappe C.

## Etappe D (G1 = Mac N1, G2 = iPhone 17 Simulator, N2 = `fnt-1029-n12`)

- D-01 ✅ Name `Test N2`, Benutzername `fnt-1029-n1` → „Schon vergeben – wie wäre es mit „fnt-1029-n12“?“ + Chip „„fnt-1029-n12“ verwenden“, „Konto erstellen“ ausgegraut; nach dem Chip „Der Benutzername ist frei.“ + Haken; Konto angelegt (ohne Zusatzschritt), Notfall-Schlüssel (KN2) erzeugt und gesichert, Familienschritt „Schritt 3 von 3“ mit Umschalter „Gründen | Beitreten“
- D-02 ✅ **#75-Messung:** G1 „Code kopiert“ (Code beginnt mit `!`, endet auf `:matrix.chaostribunal.de`). G2 „Beitreten“ → „Ohne Link beitreten (Familien-Code)“: `abc` → „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ und enthält einen Server, z. B. !abc:matrix.org.“; echter Code → „Fast geschafft! Deine Anfrage ist unterwegs. Sobald sie bestätigt ist, bist du dabei.“ mit „Anfrage zurückziehen“. G1: „Beitrittsanfragen – Test N2 möchte beitreten“, „Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du @fnt-1029-n12:… kennst und erwartest“, Badge „1“ am Tab; „Ablehnen“ geklickt um ca. 01:33:56 → G2 zeigte „Deine Anfrage wurde abgelehnt. Frag bei der Familie nach, ob sie dich einladen möchte, und versuche es dann mit einem neuen Link.“ + „Verstanden“ spätestens um 01:34:05,8 (Abfrage alle 2 s) → **ca. 10 s**, Ziel ≤ 20 s erfüllt. Einschränkung: G2 ist ein Simulator, kein echtes iPhone; Build 19 hatte 3,5 bis 4,5 min (#75), das Problem ist hier nicht aufgetreten. Debug-Logzeilen nicht gelesen (Simulator-Build, kein `flutter run`)
- D-03 ✅ „Verstanden“ → „Gründen“ → `Löschtest 1029` → „Familie gründen“ → Hauptansicht „Heute“ ohne Zwischenschritt; Tab „Familie“ zeigt „Löschtest 1029“, Test N2 als Moderator
- D-04 ✅ Abmelden → „Jetzt erstellen“ → Name, `fnt-1029-n12` → „Ich habe schon ein Konto“ → „Anmelden“ mit vorausgefülltem Benutzernamen (Anbieter-Adresse bleibt erhalten)
- D-05 ✅ Passwort N2 → „Dieses Gerät freischalten“: „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“ (kein „Mit … bestätigen“); KN2 → „Freischalten“ → innerhalb 25 s Hauptansicht, F2 erkannt (kein „Synchronisiere …“-Hänger, #24 nicht aufgetreten)
- D-06 ✅ Formular mit `fnt-1029-n9` ausgefüllt („Der Benutzername ist frei.“), Zurück-Pfeil ohne „Konto erstellen“ → „Willkommen bei FamilyNexus“; Gegenprobe `…/register/available?username=fnt-1029-n9` → `{"available":true}`
- D-07 ⏳ optional (Serverzugang nötig), nicht ausgeführt
- Keine neuen App-Fehler in Etappe D. Bedienartefakt: Seite „Konto erstellen“ ist auf dem iPhone-Format länger als der Bildschirm; das Anbieter-Feld liegt unterhalb des sichtbaren Bereichs (Erreichbarkeit nur per Wischen/Tabulator, per Mausziehen im Simulator nicht scrollbar)
- Zustand nach D: G2 = „Willkommen“ (N2 abgemeldet), Familie F2 „Löschtest 1029“ (N2) existiert noch und wird in F gelöscht

## Etappe E (Teil 1; G1 = Mac N1, G2 = iPhone 17 Simulator, I2 = `fnt-1029-i2`)

- E-01 ✅ Familie „Testfamilie 1029“, „Empfehlung: Ernenne einen zweiten Moderator.“, nur Test N1 (Moderator), „Jemanden einladen“, Familien-Code
- E-02 ✅ „Familienname ändern“ → `Testfamilie 1029 neu` mit Enter gespeichert (#68) → „Name geändert.“
- E-03 ✅ `abc` → „Bitte eine gültige Benutzer-ID eingeben, z. B. @anna:beispiel.de.“; `@fnt-1029-n12:matrix.chaostribunal.de` → Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie – lade nur Personen ein, die du sicher kennst.“ → N2 „Eingeladen“
- E-04 ✅ „Entfernen“ → „Test N2 wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert; neue Inhalte kann Test N2 nicht mehr lesen.“ → N2 verschwindet
- E-05 ✅ „Jemanden einladen“: QR-Code, „Gültig für 1/3/7 Tage“ (3 Tage), „Erweitert“ → „Konto-Server für Neue“ (Server eingetragen) → „Neuen Link erzeugen“; „Link kopieren“ → „Link kopiert.“ erscheint im Dialog (#66); „Per E-Mail senden“ öffnet Thunderbird mit Entwurf „Einladung zu FamilyNexus“ und Link (Entwurf nicht gesendet, geschlossen). Link `https://carpeasrael.github.io/FamilyNexus/join/#v=3&room=…&via=…&srv=matrix-synapse-3ues…&inv=…&exp=…&f=Testfamilie+1029+neu&by=Test+N1&n=…`; Linktext (308 Zeichen) nur im Scratchpad
- E-06 ✅ `abc` → „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.“ (#26); um 10 Zeichen gekürzt → „Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. Bitte kopiere ihn noch einmal vollständig oder scanne den QR-Code.“
- E-07 ✅ (#59) `xcrun simctl openurl` → Safari „Einladung zu FamilyNexus“ („App öffnen“, „Link kopieren“) → „In „FamilyNexus“ öffnen?“ → „Öffnen“ → Konto-Anlage (E-08); später Beitrittskarte „Du trittst der Familie „Testfamilie 1029 neu“ bei. Eingeladen hat dich Test N1 (Konto bei matrix.chaostribunal.de).“, Details: `@fnt-1029-n1:matrix.chaostribunal.de`, Server `matrix.chaostribunal.de`, „Verwerfen“. **`familynexus://join#<Fragment>` per `simctl openurl` → „In „FamilyNexus“ öffnen?“ → „Öffnen“ → Beitrittskarte erscheint, kein Fehler** (Hash-Variante angenommen). Der Mac-Zweig (`open -a`, Swift-Teil) wurde nicht geprüft
- E-08 ✅ Anbieter „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“ (nicht matrix.org), „Schritt 2 von 4“
- E-09 ✅ `Test Nutzer 2` / `fnt-1029-i2` (Namensvorschlag `test.nutzer.2` wurde per Einfügen ergänzt statt ersetzt, dann korrigiert) → „Konto erstellen“ ohne Zusatzschritt → Notfall-Schlüssel
- E-10 ✅ Schlüssel (KI2, Scratchpad) bleibt stehen, Häkchen, „Weiter“ → Beitrittskarte „Schritt 4 von 4“ → „Beitritt anfragen“
- E-11 ✅ I2 wurde automatisch aufgenommen: G2 zeigte nach ca. 4 s die Hauptansicht „Heute“ mit „Test geteilt 2“ (Moderator-App G1 war online); G1 zeigt keine offene Anfrage
- E-12 ✅ Verbrauchter Link per `simctl openurl` → „App öffnen“ → „Öffnen“ → Hinweis „Du bist bereits in einer Familie.“ am unteren Rand, nichts ändert sich, kein Absturz (#59/E-12)
- E-13 ✅ G1: Test N1 (Moderator), Test Nutzer 2 (Mitglied, „Nicht persönlich geprüft“); G2: Test N1 „Nicht persönlich geprüft“, Familienname „Testfamilie 1029 neu“ auch bei I2
- E-14 ✅ G2: „Nur Moderatoren verwalten die Familie.“; Menü der Mitglieder nur „Verifizieren“ und „Test N1 blockieren“; Aufgaben: „Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.“, keine Schaltfläche „Neue Aufgabenliste“; Liste „Bad putzen“ sichtbar (Wöchentlich, Zugewiesen an Test N1, 1 von 2 erledigt)
- E-15 ✅ Beide „Online“ (Heute: „Test N1 – Online“ bei G2); G1 „Online-Status teilen“ aus → G2 „Gerade ist sonst niemand online.“, Familie: bei Test N1 „Zuletzt online gerade eben“; wieder an → „Online“
- E-28 (G1) ✅ „Version 1.2.1 (20)“ im Menü; G2 noch offen
- E-29 ✅ „Konto löschen?“: „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator, sonst kann niemand mehr die Familie verwalten.“ (#12); „Konto endgültig löschen“ ohne Passwort inaktiv; „Abbrechen“ → unverändert
- C-03-Nachtrag: Die Geräteliste in G1-Einstellungen zeigt weiter nur „FamilyNexus macOS (Dieses Gerät)“, auch jetzt nach mehreren Anmeldungen von G2 (N1) – Beobachtung, siehe unten

## Etappe E (Teil 2)

- E-16 ⚠️ G1 sendet `Hallo von Nutzer 1`; G2 zeigt einen einzigen Hinweis „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ (#35 ok) und die Nachricht; Antworten per langem Druck (Menü: Antworten, 👍 ❤️ 😂 🎉 😮 🙏, Nachricht melden, Test N1 blockieren) → „Antwort an Test N1“ → bei G1 erscheint die Antwort mit Bezug. Reaktion (👍) und „Ungelesene Nachrichten“-Zähler vor dem Öffnen nicht geprüft
- E-17 ⏳ Anhänge nicht geprüft (Dateiauswahl im Simulator/Mac nicht automatisiert)
- E-18 ✅ **(#77)** G1: Familie → „Nachricht schreiben“ bei Test Nutzer 2 → Reiter „Test Nutzer 2“: „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“; `Nur für dich` um 01:51:41. G2: Reiter „Test N1“ mit Badge „1“ erscheint innerhalb ca. 5 s; nach dem Antippen steht die Nachricht **sofort** (≤ 1 s) im Einzelchat, kein Reiterwechsel nötig, kein Rohtext „Attempting verification request“ (#29). Beim ersten Öffnen bei G2 lag der Reiter „Testfamilie“ vorn (Familienchat ohne die Einzelnachricht, korrekt getrennt)
- E-19 bis E-22 ⏳ nicht ausgeführt (Termin-Filter, Zu-/Absage, Termin I2, Einkauf gemeinsam)
- E-23 ✅ **(#76)** Auswahl vor dem Speichern: „Täglich“ → „Montag bis Freitag (ohne Wochenende)“, Hinweis „Startet montags bis freitags neu, nicht am Wochenende“ (Aufnahme E-23a); nach dem Speichern bei G1 und G2 Kürzel „Mo–Fr“, Detail „Montag bis Freitag · Startet montags bis freitags neu, nicht am Wochenende · Nächster Neustart: Montag, 2. November 2026“ (nicht „Täglich“); G2: Liste unter „Mir zugewiesen“, abhaken mit Kommentar `Erledigt, Tonne steht draußen`; G1 Verlauf „Tonne vor die Tür erledigt – Test Nutzer 2 · 30.10.2026, 01:53“ (`TT.MM.JJJJ`, #38); G1 löscht „Bad putzen“ („Liste „Bad putzen“ löschen?“ → weg). Nicht geprüft: „Aufgaben für dich: 1 offen“ auf Heute, G1 kann den Punkt nicht abhaken
- E-24 ✅ G1 „Verifizieren“ → „Warte auf die Gegenseite …“; G2 „@fnt-1029-n1:… (UUBTUFDVOP) möchte die Verifizierung starten.“ → Annehmen; beide zeigen 📎 ☂️ 👓 ❤️ 🎩 ⚽ 🔑 → „Sie stimmen überein“ → „Verifiziert.“; Mitgliederliste: „Verifiziert“
- E-25 bis E-27 ⏳ nicht ausgeführt (Melden, Blockieren, Aufheben)
- E-28 ✅ Menü auf G1 und G2: „Version 1.2.1 (20)“
- E-29 ✅ siehe Teil 1
- E-30 ✅ „Zum Moderator ernennen“ → Rückfrage „Test Nutzer 2 zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“ → beide zeigen Test Nutzer 2 als Moderator; G2 hat jetzt Verwaltungsaktionen und „+“ bei Aufgaben. Hinweis: Die Empfehlung „Ernenne einen zweiten Moderator.“ blieb auf G1 stehen, auch nach der Ernennung (zum Zeitpunkt der Aufnahme bei G1 noch sichtbar; Kandidat für ⚠️, später prüfen)
- E-31 ✅ G1 „Konto löschen?“ ohne Hinweis „einziger Moderator“
- E-32 ✅ G2 (I2): „Konto löschen?“ ohne Moderator-Hinweis, Passwort → „Willkommen“ (nicht „Anmelden“); G1: Test Nutzer 2 nicht mehr in der Mitgliederliste, Chatnachricht „Hallo zurück von Nutzer 2“ bleibt sichtbar mit dem Namen „Test Nutzer 2“ (nie mit Matrix-ID, #60)
- B-02 (iOS-Zweig, #57) ⚠️ G2: „Heute“ und Einstellungen zeigen „Benachrichtigungen sind blockiert …“ mit „Erlauben“ → iOS-Dialog „„FamilyNexus“ möchte dir Mitteilungen senden“ → „Nicht erlauben“ → Hinweis wechselt zu „Benachrichtigungen sind in den Systemeinstellungen ausgeschaltet. …“; **Darstellungsfehler:** der Text steht in einer sehr schmalen Spalte (ca. 12 Zeichen pro Zeile) und ist unten abgeschnitten, die Seite lässt sich nicht weiter scrollen (Aufnahme B-02d-G2); die Schaltfläche zu den Systemeinstellungen ist dadurch nicht sichtbar. Bildschirm iPhone 17, Sprache Deutsch (Gerätesprache), Dunkel

Zustand nach E: G1 = Mac, N1 angemeldet, Familie „Testfamilie 1029 neu“ (allein, I2 gelöscht). G2 = „Willkommen“. N2 (`fnt-1029-n12`) ist in „Löschtest 1029“ Moderator und noch nicht gelöscht (F-01).

## Etappe F (30.10.2026, früh)
- F-01 ✅ G2 (N2): Anmeldung mit Anbieter-Adresse, direkt „Dieses Gerät freischalten“ (kein „Unbekannter Fehler.“, #28 nicht aufgetreten), KN2 → freigeschaltet. „Konto löschen?“ nennt `@fnt-1029-n12:matrix.chaostribunal.de` und den Server, „dauerhaft gelöscht“, Nachrichten bleiben sichtbar, kein Moderator-Hinweis. Falsches Passwort → „Das Passwort stimmt nicht.“ (#36), Dialog bleibt; richtiges Passwort → „Willkommen“ (nicht „Anmelden“). Aufnahmen F-01pre…F-01c.
  - Hinweis Bedienung: Zwischenablage-Einfügen (simctl pbcopy + ⌘V) griff in dieser Sitzung nicht; direkte Tastatureingabe funktionierte. Scrollen per Ziehen hing mehrfach (Einstellungen), nach Neuöffnen ging es; vermutlich Werkzeugeffekt, nicht App.
  - Beobachtung: „Geräte deines Kontos“ zeigt auf G2 nur das iOS-Gerät (wie G1 nur das Mac-Gerät) – nach Neuanmeldung nur ein Gerät sichtbar.
- F-02 ✅ curl-Login `fnt-1029-n12`: 403 M_FORBIDDEN.
- F-07 (Teil I2) ✅ curl-Login `fnt-1029-i2`: 403 M_FORBIDDEN.
- F-03 ✅ G1 „Alle lokalen Daten löschen“: Rückfrage („Alle lokalen Daten löschen?“, Konto beim Server bleibt), danach „Willkommen“. Aufnahmen F-03-G1, F-03b-G1.
- F-04 ✅ App beendet (`pkill`; `osascript quit` wurde abgebrochen, -128) und neu gestartet → „Willkommen“; Fenster hat nach Neustart Standardgröße 800×632. Aufnahme F-04-G1.
- F-05 ✅ („Ich habe schon ein Konto“; Anbieter steht wieder auf matrix.org, #61/P-51 → unter „Erweitert“ Test-Server eingetragen; Anmeldung ohne Fehler; „Dieses Gerät freischalten“ mit KN1b → freigeschaltet). Wiederhergestellt: Termine (geteilt „Test geteilt 2“, privat „Test privat“, Serie „Test Serie“), Chat (inkl. Termin-Karte, Antwort), Einkauf (Vollkornbrot offen, Milch 2 l erledigt), Aufgabenliste „Müll rausbringen“ (Mo–Fr, 1/1). Chat-Nachricht des gelöschten Kontos I2: „Ehemaliges Mitglied“ (nicht Matrix-ID, #60 ✅). Aufnahmen F-05a…F-05i-G1.
  - ⚠️ **Neuer Befund:** Aufgabenliste zeigt nach Wiederherstellung „Zugewiesen an @fnt-1029-i2:matrix.chaostribunal.de“ – Matrix-ID des gelöschten Kontos statt Name/„Ehemaliges Mitglied“ (Aufnahme F-05i-G1). Vermutlich nur in der Aufgabenliste (Chat korrekt).
- F-06 ✅ G1 (N1): „Konto löschen?“ ohne Moderator-Hinweis, Passwort → „Willkommen“. Aufnahmen F-06pre/F-06a/F-06a2/F-06b-G1.
- F-07 ✅ curl-Login `fnt-1029-n1`, `fnt-1029-n12`, `fnt-1029-i2` (jeweils mit dem richtigen Passwort): 403 M_FORBIDDEN.
- F-08 ✅ Zustand am Ende: alle drei angelegten Wegwerf-Konten des Laufs (n1, n12, i2) gelöscht; `fnt-1029-n9` nie angelegt (`register/available` → true). Familie „Löschtest 1029“ und „Testfamilie 1029 neu“ bestehen ohne Mitglieder weiter auf dem Server (kein Konto mehr). Registrierung nicht verändert.

## Etappe G (30.10.2026)
- G-01 ✅ `flutter analyze`: No issues found.
- G-02 ✅ `flutter test`: 782 bestanden, 49 übersprungen, 0 fehlgeschlagen (inkl. `test/store/review_notes_test.dart`, Review-Notizen ios/macos).
- G-04/G-06/G-07/G-08: nicht ausgeführt (optional bzw. n. a.: keine Testperson, kein echtes iPhone).
