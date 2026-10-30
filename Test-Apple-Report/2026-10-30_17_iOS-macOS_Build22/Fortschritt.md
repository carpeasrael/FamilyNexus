# Fortschritt Lauf 17 (Build 1.2.1 (22)), 30.10.2026 – G1 = iPhone-17-Simulator, G2 = macOS

| Schritt | Erg. | Beobachtet |
|---|---|---|
| V-04 | ✅ | G1 (iOS): App neu gestartet → „Willkommen“; G2 (Mac): App neu gestartet → „Willkommen“ |
| A-01 | ✅ | Startseite G1 wie erwartet |
| A-02 | ✅ | English/Deutsch wechseln sofort (G1) |
| A-03 | ✅ | Bei matrix.org … / „Dein Konto liegt bei matrix.org.“ (G1) |
| A-04 | ✅ | Adresse nicht-vorhanden.invalid: Fehlermeldung, „Konto erstellen“ nicht nutzbar (G1) |
| A-05 | ✅ | „Dein Konto liegt bei matrix-synapse-3ues…“, Betreiber/Kontakt, Hinweis zu Metadaten, Felder, „Konto erstellen“ ausgegraut (G1) |
| A-06 | ✅ | Name „Joerg Muessig“ (Umlaute per Tastencodes nicht eingebbar → Ersatzschreibung) → Benutzername `joerg.muessig`, „Der Benutzername ist frei.“ |
| A-07 | ✅ | alle sechs Eingaben (ab, Anna, anna mueller, .anna, anna., 33 × a) mit „Bitte 3 bis 32 Zeichen …“ |
| A-08 | ✅ | Benutzername bleibt fnt-1030c-n1; Name Test N1; Passwort 7 Zeichen ausgegraut, ab 8 aktiv; Augen-Symbol; leerer Name zeigt Platzhalter, „Konto erstellen“ ausgegraut. Passwort geschwärzt |
| A-09 | ⚠️ | Beim ersten Antippen von „Konto erstellen“: „Unbekannter Fehler.“, Konto nicht angelegt (`register/available` = frei, A-09err). Zweiter Versuch: N1 angelegt, kein Zusatzschritt, „Dein Notfall-Schlüssel“, „Schritt 2 von 3“ |
| A-10 | ✅ | Schlüssel bleibt nach 20 s stehen (#10); Kopieren (59 Zeichen in der Zwischenablage); „Als Datei speichern“ → Dateiauswahl „Auf meinem iPhone“ → „Gespeichert. …“, Datei mit Konto, Anbieter, Datum, Schlüssel; „Weiter“ erst nach Häkchen aktiv (KN1 abgelegt) |
| A-11 | ✅ | „Fertig! „Testfamilie 1030c“ ist eingerichtet.“ mit „Später“ und „Jetzt einladen“ |
| A-12 | ✅ | „Später“ → Hauptansicht „Heute“ |
| B-01 | ✅ | Kacheln Nächste Termine, Erinnerungen, Wer ist online, Einkaufszettel, Aufgaben, Ungelesene Nachrichten; Navigation unten; Menü; Neuer Termin (+) |
| B-02 | ⏳ | G1 (iOS): kein Hinweis „Benachrichtigungen sind blockiert“ (Berechtigung aus früherem Lauf im Simulator noch erteilt); G2 (Mac): siehe unten |
| B-03 | ✅ | Sichtbarkeit zuerst „Privat“ (G1 sofort auf „Geteilt“ gestellt), „Verschlüsselt an die Familie gesendet. …“; Termin 31.10. 10:00–11:00 „Geteilt“ mit Ort „Küche“ (Eingabe „Kueche“, Autokorrektur), Notiz, andere Farbe |
| B-04 | ✅ | „Bitte einen Titel eingeben.“; „Das Ende muss nach dem Beginn liegen.“ bei Ende vor Beginn und bei Ende = Beginn (#56), direkt unter den Feldern; Zurück ohne Speichern: nichts gespeichert |
| B-05 | ✅ | Tastatureingabe 21 (Zeitwähler-Tastatur) angenommen; Ende steht auf 22:00; Termin „Privat“ |
| B-06 | ✅ | Test Serie ganztägig, wöchentlich, Nach Anzahl 3: drei Vorkommen 1., 8., 15.11. mit Wiederholungs-Symbol |
| B-07 | ✅ | Tag, Woche, Monat, Agenda; Zurück/Weiter/Heute |
| B-08 | ✅ | Detail mit „Von dir“, Sichtbarkeit, Ort, Notiz; nach Speichern sofort „Test geteilt 2“ und 10:30 – 11:30 (#63); „Verlauf (1)“ zeigt „Test geteilt – Version 1“ |
| B-09 | ✅ | Erinnerungen wählbar (30 Minuten/2 Tage in der Aufnahme), „Standard verwenden“ setzt auf „10 Minuten vorher“ zurück |
| B-10 | ✅ | Terminbenachrichtigung „Erinnerung / Termin in 10 Minuten“ (ohne Titel/Ort) um 20:56 bei Termin 21:06 (App im Hintergrund, iOS-Simulator) |
| B-11 | ✅ | Dialog „Alle Vorkommen oder nur dieses löschen?“ → „Nur dieses“: nur 1.11. verschwindet; „Diesen Termin wirklich löschen?“ → „Löschen“, Termin weg |
| B-12 | ✅ | Nachricht „Hallo Testfamilie“ mit Uhrzeit, „Ende-zu-Ende-verschlüsselt“ (Senden-Schaltfläche) |
| B-13 | ✅ | „Im Chat teilen“ → Karte „Termin“ mit dem Termin (Zusagen/Vielleicht/Absagen) im Chat |
| B-14 | ✅ | „Zu besorgen (2)“; Milch abgehakt unter „Erledigt (1)“; Brot → Menü „Bearbeiten“ → „Vollkornbrot“ → „Speichern“; leerer Eintrag: „Hinzufügen“ bewirkt nichts (versehentliches „Erledigte entfernen“ wurde abgebrochen) |
| B-15 | ✅ | Hinweis „Nur Moderatoren legen Listen an. …“; Liste „Bad putzen“ (wöchentlich Montag) unter „Mir zugewiesen“, „0 von 2 erledigt“, „Nächster Neustart: Montag, 2. November 2026“; Abhaken mit Kommentar → „1 von 2 erledigt“, „Erledigt am 30.10.2026 um 21:04“ (Format TT.MM.JJJJ, #38); Verlauf „Waschbecken erledigt · Du · 30.10.2026, 21:04“ |
| B-16 | ✅ | Sprache (Deutsch↔English), Design (Dunkel/Hell), Akzentfarbe (Magenta, zurück Türkis), „Effekte reduzieren“ wirken sofort; nach App-Neustart bleiben English/Hell/Effekte erhalten; danach alles zurückgesetzt |
| B-17 | ⏳ | G1 (iOS-Simulator): App-Sperre einschalten → Gerätecode-Abfrage des Simulators („iPhone-Code für „FamilyNexus“ eingeben“), Code dem Tester unbekannt, nicht geraten → abgebrochen: „Die Bestätigung war nicht erfolgreich.“, Schalter bleibt aus. Manuell nachzuholen (G2 Mac: siehe unten) |
| B-18 | ⚠️ | G1 (iOS): Schalter „Bildschirmschutz“ vorhanden („Blockiert Screenshots und verbirgt die App in der Übersicht.“), standardmäßig an; Aus/An schaltbar. Wirkung (Screenshot blockiert, Inhalt in der App-Übersicht verborgen) im Simulator nicht prüfbar: `simctl`-Screenshot ist davon unabhängig → Prüfung auf echtem iPhone offen |
| B-19 | ✅ | „Online-Status teilen“ aus/an; „Blockierte Mitglieder“: „Du hast niemanden blockiert.“; Datenschutzerklärung vollständig, Abschnitt Speicher: „sicheren Schlüsselspeicher deines Geräts (Android-Keystore bzw. Apple-Schlüsselbund)“ (#78) |
| B-20 | ✅ | Standard-Erinnerung: Mehrfachauswahl, 30 Minuten gewählt, 10 abgewählt; Hinweis „Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.“ |
| B-21 | ✅ | Speicherorte (Datenbankschlüssel: „Schlüsselbund des Geräts (nicht in iCloud)“), lokales Protokoll mit „App-Version 1.2.1 (22)“, Warnhinweis zum Klartext, Kopieren (Zwischenablage), Online-Protokoll mit Konto, Anzeigename „Test N1“, Geräten, Verschlüsselung |
| B-22 | ✅ | Menü unten und Einstellungen „Version 1.2.1 (22)“; Konto: Server = Anbieter-Adresse, Benutzername `@fnt-1030c-n1:matrix.chaostribunal.de` |
| C-01 | ✅ | G2 (Mac): falsches Passwort → „Benutzername oder Passwort stimmen nicht.“, keine Anmeldung |
| C-02 | ✅ | G2 (Mac): „Mit „FamilyNexus iOS“ bestätigen“; G1: „… möchte die Verifizierung starten.“ → Annehmen; gleiche Symbole in gleicher Reihenfolge (Daumen, Feuer, Weihnachtsmann, Erdbeere, Zielflagge, Zylinder, Tulpe); beide „Verifiziert.“; G2 öffnet Hauptansicht mit Terminen aus B |
| C-03 | ✅ | G2 (Mac): „Dieses Gerät ist verifiziert.“; Geräte deines Kontos: „FamilyNexus iOS“ und „FamilyNexus macOS (Dieses Gerät)“ je „Verifiziert“; „Neuen Notfall-Schlüssel erstellen“ vorhanden |
| B-17 | ⏳ | G2 (Mac): App-Sperre einschalten → Systemdialog „Touch ID/Passwort“ (#58) erscheint; nicht eingebbar → „Abbrechen“, Schalter bleibt aus. G1 (iOS-Simulator): Code-Abfrage, Code unbekannt. Manuell nachzuholen |
| C-04 | ✅ | G2 (Mac): Dialog „Abmelden“ → direkt „Anmelden“ (nicht „Willkommen“) |
| C-05 | ✅ | G1 (iOS): Seite „Neuer Notfall-Schlüssel“ („Der alte funktioniert danach nicht mehr …“); neuer Schlüssel (KN1b, vom Bildschirm abgelesen) angezeigt; Zurück-Pfeil und Esc ohne Wirkung; „Weiter“ erst nach Häkchen; danach Einstellungen |
| C-06 | ✅ | G2 (Mac): altes KN1 → „Der Notfall-Schlüssel passt nicht. Bitte prüfe ihn noch einmal.“, Gerät bleibt gesperrt |
| C-07 | ✅ | G2 (Mac): KN1b → freigeschaltet, Hauptansicht mit F1 und Daten aus B |
| C-08 | ✅ | G2 (Mac): Abmelden → „Anmelden“ |
| D-01 | ✅ | G2 (Mac): „Schon vergeben – wie wäre es mit „fnt-1030c-n12“?“, Chip „„fnt-1030c-n12“ verwenden“, „Konto erstellen“ ausgegraut; nach Chip „Der Benutzername ist frei.“; Konto angelegt; Schlüssel bleibt stehen; KN2 abgelegt; Familienschritt „Schritt 3 von 3“ mit Umschalter Gründen/Beitreten |
| D-02 | ❌ | G2 (Mac): `abc` → „Das ist kein gültiger Familien-Code. Er beginnt mit „!“ …“; Code → „Fast geschafft! …“. G1 (iOS): Tab Familie „Beitrittsanfragen“, „Test N2 möchte beitreten“ mit „Anfrage über den Familien-Code (ohne Link) – nur bestätigen, wenn du … kennst“, „Ablehnen“ → Anfrage verschwindet. G2: **die Meldung „Deine Anfrage wurde abgelehnt …“ erscheint nicht**: nach ca. 6 Minuten und auch nach Neustart der App steht weiter „Fast geschafft! …“ (Ziel ≤ 20 s; auf macOS reproduziert, im Simulator in Lauf 16 ca. 5 s). Befund #75-ähnlich auf macOS |
| D-03 | ✅ | G2 (Mac): „Gründen“ → F2 „Loeschtest 1030c“ gegründet, direkt „Heute“ ohne „Fertig!“-Zwischenschritt |
| D-04 | ✅ | G2 (Mac): Abmelden → Konto erstellen → Name `Test`, Benutzername `fnt-1030c-n12` (Vergeben-Hinweis) → „Ich habe schon ein Konto“ → „Anmelden“ mit vorausgefülltem Benutzernamen und erhaltener Anbieter-Adresse |
| D-05 | ✅ | G2 (Mac): „Kein anderes Gerät gefunden. Nutze deinen Notfall-Schlüssel.“; mit KN2 freigeschaltet, F2 erkannt (Hauptansicht, kein Hängen) |
| D-06 | ✅ | G2 (Mac): Zurück-Pfeil ohne „Konto erstellen“ → „Willkommen“; Gegenprobe `register/available?username=fnt-1030c-n9` → `available: true` |
| D-07 | ⏳ | optional, kein Serverzugang (Betreiber-Schritt) |
| E-01 | ✅ | „Testfamilie 1030c“, „Empfehlung: Ernenne einen zweiten Moderator.“, Mitglied nur Test N1 (Moderator), „Jemanden einladen“, „Familien-Code“ (G1 iOS) |
| E-02 | ✅ | „Name geändert.“; „Testfamilie 1030c neu“ im Tab Familie (G1 iOS) |
| E-03 | ✅ | `abc` → „Bitte eine gültige Benutzer-ID eingeben, z. B. @an…“; ID → Rückfrage „… einladen? Eingeladene erhalten bereits vor der Annahme die Nachrichtenschlüssel der Familie …“; „Test N2“ mit „Eingeladen“ in der Liste |
| E-04 | ✅ | Rückfrage „Test N2 wirklich aus der Familie entfernen? Die Raumschlüssel werden erneuert …“; N2 verschwindet aus der Liste („Erledigt.“) |
| E-05 | ✅ | QR-Code, „Gültig für“ (3 Tage), „Erweitert → Konto-Server für Neue“ = Anbieter-Adresse, „Neuen Link erzeugen“; „Per E-Mail senden“ → „Kein Mailprogramm gefunden. Der Link wurde stattdessen kopiert.“; „Link kopieren“ → „Link kopiert.“ im Dialog (#66); Link `https://carpeasrael.github.io/FamilyNexus/join/#v=3&…` (310 Zeichen, `srv` = Anbieter-Adresse) |
| E-06 | ✅ | G2 (Mac): `abc` → „Das ist kein Einladungslink. Ein Einladungslink beginnt mit „https://carpeasrael.github.io/FamilyNexus/join/“ oder „familynexus://join“.“; um 10 Zeichen gekürzter Link → „Der Link ist unvollständig oder beschädigt – oft passiert das beim Weiterleiten. Bitte noch einmal vollständig einfügen …“ |
| E-07 | ✅ | G2 (Mac): `open <Link>` → Safari-Seite „Einladung zu FamilyNexus“ → „App öffnen“ → „Darf diese Website „FamilyNexus.app“ öffnen?“ → Erlauben → Kontoanlage zuerst; nach dem Schlüssel Beitrittskarte „Du trittst der Familie „Testfamilie 1030c neu“ bei. Eingeladen hat dich Test N1 (Konto bei …).“, Details mit Benutzer-ID `@fnt-1030c-n1:…` und Server, „Verwerfen“ |
| E-08 | ✅ | Anbieter aus dem Link: matrix-synapse-3ues.srv1348446.hstgr.cloud (nicht matrix.org) |
| E-09 | ✅ | I2 `fnt-1030c-i2` („Test Nutzer 2“) ohne Zusatzschritt angelegt, weiter zum Notfall-Schlüssel |
| E-10 | ✅ | Schlüssel bleibt stehen (#10), KI2 abgelegt; Häkchen → Weiter → Beitrittskarte „Schritt 4 von 4“ → „Beitritt anfragen“ |
| E-11 | ✅ | I2 automatisch aufgenommen (innerhalb ca. 10 s); G2 zeigt „Heute“ mit „Test geteilt 2“ und „Test N1 – Online“; G1 zeigt keine offene Anfrage |
| E-12 | ✅ | G2 (Mac): verbrauchter Link per `open` → Web-Seite → „App öffnen“ → „Du bist bereits in einer Familie.“ (kurze Meldung unten), nichts ändert sich, kein Absturz |
| E-13 | ✅ | Beide Mitglieder: Test N1 (Moderator), Test Nutzer 2 (Mitglied, „Nicht persönlich geprüft“); Familienname „Testfamilie 1030c neu“ auch bei I2 (G2) |
| E-14 | ✅ | I2 (Mac): Tab Familie „Nur Moderatoren verwalten die Familie.“, kein Umbenennen/Einladen/Code, Menü nur Verifizieren/blockieren; Aufgaben: „Nur Moderatoren legen Listen an. Abhaken kann nur die zugewiesene Person.“, keine Schaltfläche „Neue Aufgabenliste“ |
| E-15 | ✅ | An: G2 „Test N1 – Online“. Aus (G1): G1 „Dein Status wird nicht geteilt“; G2 „Gerade ist sonst niemand online.“ und bei Test N1 „Zuletzt online gerade eben“. Wieder an: G2 zeigt N1 wieder „Online“ |
| E-16 | ✅ | G1 sendet „Hallo von Nutzer 1“; G2 (vor dem Öffnen): „1 ungelesene Nachricht“ auf „Heute“, Chat-Badge 1 (#65); im Chat ein einziger Hinweis „Ältere Nachrichten aus der Zeit vor deinem Beitritt sind nicht lesbar.“ (#35); G2 antwortet über „Antworten“ („Antwort an Test N1“), Antwort mit Bezug bei G1; Reaktion 👍 (langes Drücken) bei beiden |
| E-17 | ✅ | G1 sendet Bild (bild.png), Textdatei FN-ANHANG.txt und Datei `a<b>c"d.txt` (Name beim Senden zu `a_b_c_d.txt`); G2 (Mac): „Anhang laden“ zeigt das Bild, „Speichern“ darunter (#40); Warnung „Die Datei wird entschlüsselt und unverschlüsselt im gewählten Ordner gespeichert. … Sie bleibt dort auch nach dem Abmelden oder Löschen der App-Daten erhalten. Fortfahren?“; Speichern-Dialog; Dateien im gewählten Ordner |
| H-15 | ✅ | SHA-256 der gespeicherten Dateien (FN-ANHANG.txt, a_b_c_d.txt) = Original; Name ohne `< > "` (zu `_`), nie automatisch geöffnet |
| E-18 | ✅ | G1: Tab Familie → „Nachricht schreiben“ bei Test Nutzer 2; vor dem Senden oben „Nur zwischen dir und Test Nutzer 2, Ende-zu-Ende-verschlüsselt“; sendet „Nur fuer dich“ (ue-Ersatz). G2 (Mac): Reiter „Test N1“ mit Badge, Nachricht steht sofort im Einzelchat (#77), nicht im Familienchat; kein Rohtext „Attempting verification request“ |
| E-19 | ✅ | G2 (Mac, I2): Agenda zeigt nur „Test geteilt 2“ („Test privat“/„Test Serie“ nicht sichtbar); Filter nur „Test Nutzer 2“: „Keine Termine“; „Alle“ stellt zurück |
| E-20 | ✅ | G2 (Mac): „Nur der Ersteller kann diesen Termin ändern.“ (kein Bearbeiten), „Keine Antwort“ → „Zusagen“; G1: „Test Nutzer 2 – Zugesagt“; „Im Chat teilen“ nur beim Ersteller |
| E-21 | ✅ | G2 (Mac): „Termin I2“ geteilt angelegt; G1 sieht ihn „Von Test Nutzer 2“; beim Bearbeiten auf „Privat“: „Bereits an die Familie gesendete Inhalte bleiben auf deren Geräten, auch wenn du den Termin später privat machst.“ |
| E-22 | ✅ | G2 (Mac) legt „Kaese“ an (ae-Ersatz); G1 hakt ab; „2 erledigte Einträge für die ganze Familie entfernen?“ → entfernt; G2 löscht „Vollkornbrot“; Einträge mit „zuletzt von …“ auf beiden; Löschen wirkt auf beiden |
| E-23 | ✅ | G1: Titel „Müll rausbringen“ (Umlaut durch Autokorrektur), zugewiesen an Test Nutzer 2, „Montag bis Freitag (ohne Wochenende)“ gewählt (E-23a); Liste zeigt „Mo–Fr“ und „Montag bis Freitag · Startet montags bis freitags neu, nicht am Wochenende“ (#76); G2: Liste unter „Mir zugewiesen“, „Aufgaben für dich: 1 offen“ auf Heute; Abhaken mit Kommentar; Verlauf „Tonne raus erledigt – Du · 30.10.2026, 21:56“ (TT.MM.JJJJ, #38); G1 sieht Verlauf („Test Nutzer 2 · 30.10.2026, 21:56“); Liste „Bad putzen“ gelöscht („Liste „Bad putzen“ löschen?“) |
| E-24 | ✅ | G1 → Aktionen → „Verifizieren“; beide Geräte zeigen dieselben Symbole (Fisch, Schlüssel, Pferd, Kopfhörer, Einhorn, Pizza, Daumen) → „Sie stimmen überein“ → beide „Verifiziert.“; Mitgliederliste zeigt „Verifiziert“ |
| E-25 | ✅ | G1: „Nachricht melden“ mit Hinweis auf den Betreiber und vier Gründen (Spam oder Werbung, Belästigung oder Beleidigung, Unangemessener Inhalt, Anderer Grund); „Meldung gesendet.“ mit „Absender blockieren“; Hinweis verschwindet nach wenigen Sekunden (#45); Lesbarkeit im dunklen Design gut (hell nicht geprüft, #62) |
| E-26 | ✅ | G1: Rückfrage „Test Nutzer 2 blockieren?“ mit Erklärung; „Test Nutzer 2 ist blockiert.“; Nachrichten von I2 bei G1 ausgeblendet; G2 sendet „Noch da?“ ohne Fehlermeldung. Kennzeichnung „Blockiert“ am Mitglied nicht einzeln aufgenommen |
| E-27 | ✅ | Einstellungen → „Blockierte Mitglieder“ listet Test Nutzer 2 → „Blockierung aufheben“ → Nachrichten von I2 wieder sichtbar, auch „Noch da?“ |
| E-28 | ✅ | G1 und G2: Menü unten und Einstellungen → „Über die App“: „Version 1.2.1 (22)“ (G1: B-22) |
| E-29 | ✅ | „Konto löschen?“ mit „Du bist der einzige Moderator der Familie. Ernenne vorher ein anderes Mitglied zum Moderator …“ (#12); „Konto endgültig löschen“ ohne Passwort inaktiv; nach „Abbrechen“ unverändert |
| E-30 | ✅ | Rückfrage „Test Nutzer 2 zum Moderator ernennen? Moderatoren können einladen, ernennen und entfernen.“; beide Geräte zeigen Test Nutzer 2 als Moderator; Empfehlung „zweiter Moderator“ verschwindet |
| E-31 | ✅ | Dialog „Konto löschen?“ ohne Hinweis „einziger Moderator“; Abbrechen |
| H-01 | ✅ | G1 (Mac) und G2 (iOS): „Speicherorte“ mit Datenbank-Ordner, „App-Daten: Termine, Listen, Einstellungen (verschlüsselt)“, „Chat- und Abgleichsdaten: Matrix (verschlüsselt)“, „Datenbankschlüssel: Schlüsselbund des Geräts (nicht in iCloud)“, „Online beim Matrix-Anbieter“ (Mac-Pfad im Container von `de.inneso.familyNexus`) |
| H-16 | ✅ | (a) test.zip, (b) test.sh, (c) test.exe, (d) 26 MiB gross.txt: jeweils „Dieser Anhang ist nicht erlaubt (Typ oder Größe).“, nichts gesendet; (e) fast25.txt (25 MiB − 1 Byte) wird gesendet und kommt bei G2 an |
| H-02 | ⚠️ | G1 (iOS-Simulator, nach Beenden): genau zwei Dateien `familynexus_app.db` (81 920 Byte) und `familynexus_matrix.db` (462 848 Byte), keine weitere Datei mit Termin-/Chat-/Einkaufsdaten (nur bewusst gespeicherte Anhänge in `tmp/`). G2 (Mac): Container durch macOS geschützt („Operation not permitted“) → Dateien nicht prüfbar, ⏳ |
| H-03 | ✅ | G1 (Kopien, App beendet): Kopf beider Dateien Zufallsbytes (kein „SQLite format 3“), `file` = data, `sqlite3`: „file is not a database“. Info: Kopf identisch zu Lauf 16 (Schlüssel des Simulators wird wiederverwendet). G2 siehe H-02 |
| H-04 | ✅ | G1: 0 Treffer aller Suchbegriffe in beiden Datenbanken und im ganzen App-Datenordner (auch FN-ANHANG-… und „Nur fuer dich“); Gegenprobe: das gespeicherte lokale Protokoll findet die Begriffe (>0) |
| H-05 | ✅ | G2 (Mac): Einträge `fn.key.db.app` und `fn.key.db.matrix` (Dienst `flutter_secure_storage_service`) im Bund „login“, ohne Sync-Attribut (nicht in iCloud); Wert nicht gelesen |
| H-06 | ✅ | Apple: Schlüssel nur lokal im Bund „login“, kein iCloud-Eintrag (H-05); Android-Teil n/a |
| H-10 | ⚠️ | G2 (Mac, I2): Online-Protokoll: Familie und „Einzelchat“ je „Ende-zu-Ende-verschlüsselt: ja“, Mitglieder 2 beigetreten, Cross-Signing und Schlüssel-Backup „eingerichtet“, kein „Sonstiger Raum“, kein privater Raum von N1 sichtbar. G1 (iOS): Anzeige geöffnet (H-10-G1), die Zwischenablage-Auswertung gelang im Simulator nicht; privater Raum, Raumarten und Mitglieder stattdessen durch H-11 per curl bestätigt (3 Räume, privater Raum 1 Mitglied) |
| H-11 | ✅ | curl als N1 (neues Gerät „Testwerkzeug“, danach abgemeldet): 3 Räume (Einzelchat, Familie, privat); nur `m.room.encrypted` (`m.megolm.v1.aes-sha2`), 0 Ereignisse `m.room.message`; 0 Treffer aller Suchbegriffe (inkl. FN-ANHANG-…, „Nur fuer dich“, „Noch da“) |
| H-12 | ⚠️ | Im Klartext: Raumname des Familienraums = Familienname „Testfamilie 1030c neu“ und Name des privaten Raums „FamilyNexus“, Mitglieder, join_rule `knock`/`invite`, Zeitpunkte, Größe, Geräteliste. Familienname als Raumname steht nicht in der Datenschutzerklärung → Hinweis (kein Verschlüsselungsfehler); Inhalte nicht lesbar |
| H-13 | ✅ | Privater Raum: 1 Mitglied (N1), join_rule `invite`, nur `m.room.encrypted`; „Test privat“ bei I2 weder im Kalender noch im Chat (E-19) |
| H-14 | ✅ | Parameter nur v, room, via, srv, inv, exp (≈3 Tage), f, by, n (32 Hexzeichen); kein Passwort, Schlüssel, Token, Gerätekennung; Länge 310 ≤ 1024; Web-Link trägt die Angaben hinter `#`. Hinweis: Familien- und Einladername stehen im Klartext im Link |
| H-17 | ✅ | (a) TLS 1.3, `Verify return code: 0 (ok)`, Zertifikat für den Anbieter (Let’s Encrypt); (b) Mac-App: nur Verbindungen zu 76.13.153.15:443 = Anbieter-Adresse; keine Werbe-/Analyse-/Crashdienste |
| H-08 | ⚠️ | (a) Notfall-Schlüssel-Datei auf G1 (iOS) mit Konto, Anbieter, Datum, Schlüssel (A-10), liegt nach „Als Datei speichern“ im Ordner „Auf meinem iPhone“; (b) Protokoll „speichern“ (G2 Mac): Warnhinweis „Das Protokoll zeigt deine Daten im Klartext. Beim Kopieren oder Speichern verlassen sie den verschlüsselten Speicher der App.“, Speichern-Dialog, Datei `familynexus-local-…txt`; (c) Anhang speichern (E-17): Warnung „… unverschlüsselt im gewählten Ordner gespeichert …“. Ein Papierkorb-Leeren für (a)/(b) nicht ausgeführt |
| H-09 | ✅ | Protokoll (G2 Mac, I2): 0 Treffer für Passwort (I2), Notfall-Schlüssel (I2), KN1/KN1b (N1), Token-Muster; Sätze „Außerdem gespeichert, aber aus Sicherheitsgründen nicht angezeigt: …“, „Nie gespeichert, nur im Arbeitsspeicher: Online-Status …“, „Geplante Erinnerungen liegen zusätzlich beim Betriebssystem.“ vorhanden (Titel/Zeit der Erinnerungen liegen beim Betriebssystem im Klartext → Hinweis) |
| H-07 | ✅ | G2 (Mac): „Kopieren“ → 59 Zeichen, nach ca. 65 s 0 Zeichen (geleert). 2. Lauf: Kopieren (59), danach `abc` kopiert: nach 66 s steht `abc` (3 Zeichen) unverändert. G1 (iOS-Simulator): „Kopieren“ schreibt nicht in die Simulator-Ablage → dort nicht prüfbar |
| E-32 | ✅ | G2 (Mac): „Konto löschen?“ ohne Moderator-Hinweis, nach Passwort „Willkommen“ (nicht „Anmelden“); Gegenprobe: Anmeldung I2 → 403 M_FORBIDDEN |
| E-32 | ✅ | G2 (Mac): „Konto löschen?“ ohne Moderator-Hinweis (N1 ebenfalls Moderator), nach Passwort „Willkommen“ (nicht „Anmelden“); Gegenprobe Anmeldung I2 → 403 M_FORBIDDEN. G1: Test Nutzer 2 nicht mehr Mitglied, Empfehlung „zweiter Moderator“ wieder da; frühere Nachrichten als „Ehemaliges Mitglied“, nie mit Matrix-ID (#60) |
| F-01 | ✅ | G2 (Mac): N2 angemeldet + KN2 freigeschaltet; Dialog nennt `@fnt-1030c-n12:matrix.chaostribunal.de` und den Server, kein Moderator-Hinweis; falsches Passwort: „Das Passwort stimmt nicht.“ (#36), Dialog bleibt; richtiges Passwort: „Willkommen“ |
| F-02 | ✅ | Anmeldung N2 → `403 M_FORBIDDEN` („Invalid username or password“) |
| F-03 | ✅ | G1 (iOS): Rückfrage „Alle lokalen Daten löschen?“ („… Dein Konto beim Server bleibt bestehen …“); danach „Willkommen“; Konto besteht weiter |
| F-04 | ✅ | App beendet und neu gestartet → „Willkommen“ (Einstellungen und Daten weg) |
| H-18 | ⚠️ | G1 (iOS-Simulator, nach F-04): alte Datenbanken ersetzt (Prüfsummen geändert), 0 Treffer aller Suchbegriffe im App-Datenordner; die App legt aber sofort neue leere verschlüsselte `familynexus_app.db`/`familynexus_matrix.db` an statt sie nur zu löschen (Info). Bewusst gespeicherte Anhänge in `tmp/` bleiben. G2 (Mac): Container nicht lesbar, Schlüsselbund siehe H-05: `fn.key.db.matrix` mit neuem Datum (18:16 UTC), nicht nachgeprüft ob nach F-04 gelöscht und neu angelegt (⏳) |
| F-05 | ✅ | G1 (iOS, Sprache English): Anmeldung N1 + KN1b → freigeschaltet; Termine (auch private), Chat, Einkauf, Aufgaben vom Server wiederhergestellt (Anbieter nach dem Löschen wieder matrix.org, manuell gesetzt); Termin von I2 mit „By Former member“ statt Matrix-ID (#60) |
| H-19 | ⏳ | optional, nur durch den Besitzer des Geräts (Löschen des Eintrags `fn.key.db.app` per Hand); nicht ausgeführt |
| F-06 | ✅ | G1 (iOS): Dialog „Delete account?“ ohne Moderator-Hinweis (N1 allein); Passwort → „Willkommen“ |
| F-07 | ✅ | N1: 403 `M_FORBIDDEN`, I2: 403 `M_FORBIDDEN` (zusätzlich F-02: N2 403) |
| F-08 | ✅ | Zustand am Ende: fnt-1030c-n1, -n12, -i2 gelöscht (`M_USER_IN_USE`, Anmeldung verweigert); fnt-1030c-n9 nie angelegt (frei). Registrierung offen gelassen. Testgeräte „Testwerkzeug“ entfernt |
| V-01 | ✅ | `main` = `origin/main` @ dddf22d; `pubspec.yaml`: 1.2.1+22 |
| V-02 | ✅ | G1 (iOS-Simulator): `simctl listapps` CFBundleVersion 22; G2 (Mac): 1.2.1, CFBundleVersion 22, Signatur „TestFlight Beta Distribution“ |
| V-03 | ✅ | Keine Nachinstallation nötig |
| V-05 | ✅ | `versions` liefert JSON; `register` liefert `flows` mit `m.login.dummy` (Registrierung offen) |
| V-06 | ✅ | `fnt-1030c-n1/-n12/-i2/-n9` und `fnt-1030d-…` frei (Lauf 16 nutzte `1030b`); Datumsteil `1030c` verwendet |
| V-07 | ✅ | Gerätesprache Deutsch (beide). Mac: Bildschirmsperre vorhanden (Systempasswort/Touch ID), Benachrichtigungen bereits erlaubt. iOS-Simulator: Gerätecode-Abfrage vorhanden (Code unbekannt), Benachrichtigungen vorab bereits erteilt (früherer Lauf). Bildschirmschoner und Ruhezustand per `caffeinate -dimsu` gesperrt (keine Systemeinstellung geändert) |
| G-04 | ⏳ | Optional (lokaler Synapse); nicht ausgeführt |
| G-05 | ✅ | Durch G-02 abgedeckt (786 Tests grün) |
| G-06 | ⏳ | Review-Notizen manuell nicht Schritt für Schritt nachvollzogen (automatisch durch G-03 geprüft) |
| G-07 | ⏳ | Durchlauf mit einer Person ohne Vorwissen: nicht möglich in einem automatisierten Lauf |
| G-08 | n/a | Nur Plattform Web |
| G-01 | ✅ | `flutter analyze`: „No issues found!“ |
| G-02 | ✅ | `flutter test`: 786 bestanden, 49 übersprungen, „All tests passed!“ |
| G-03 | ✅ | `flutter test test/store/review_notes_test.dart`: 4 bestanden |
