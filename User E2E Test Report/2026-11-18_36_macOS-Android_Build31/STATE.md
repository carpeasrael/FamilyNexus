# STATE Lauf 36 (macOS G1 / Android-Emulator G2), Plan TP-FN-001 v1.55 @ c6d2ef0 (= origin/main b85ce9d + #546 + Plan 1.55)

## Abschnitt 2 (Plattform)
| Angabe | G1 | G2 |
|---|---|---|
| Plattform | macOS 27.3 | Android 15 (API 35), Emulator |
| Gerät | dieser Mac, Debug-Build, Bundle-ID de.inneso.familynexus.e2e (nur im Worktree geändert), ad hoc | eigenes AVD FN_E2E_L36 (Pixel 8, arm64, 4 GB, Datenpartition 6 GB wegen 11 GB freiem Platz), emulator-5570, -wipe-data |
| Installationsquelle | flutter build macos --debug im Worktree wt-l36 | flutter build apk --debug (arm64), adb install |
| Version Soll/Ist | 1.2.3 (31) / 1.2.3 (31, CFBundleShortVersionString 1.2.3) | 1.2.3 (31) / versionCode 31, versionName 1.2.3 |
| Sprache | de-DE | en-US (Emulator-Standard) |
| Tester / Beginn | Claude (Tester-Agent) / 18.11.2026 ca. 11:20 | dito |

## Pfade
- Repo: /Users/carpeasrael/NextCloud_int/mac_project_2/FamilyNexus
- Worktree (Builds, nicht ändern): /private/tmp/claude-501/-Users-carpeasrael-NextCloud-int-mac-project-2-FamilyNexus/597a9302-f278-415f-853b-8e7356bc67c1/scratchpad/wt-l36
- macOS-App: <Worktree>/build/macos/Build/Products/Debug/FamilyNexus.app (läuft, "Willkommen" sichtbar; Schlüsselbund-Abfrage wurde vom Nutzer beantwortet)
- Lauf-Ordner: User E2E Test Report/2026-11-18_36_macOS-Android_Build31/ (screenshots/, logs/)
- Android: adb -s emulator-5570; Hilfsskript User E2E Test/Default_test_G1-G2/sandbox/ui.py (Portnummer anpassen)

## Konten (Datumsteil 1118, alle vier Namen am 18.11. vor dem Lauf frei)
- N1 fnt-1118-n1, N2 fnt-1118-n12, I2 fnt-1118-i2, n9 fnt-1118-n9 (nur Prüfname)
- Server: matrix-synapse-3ues.srv1348446.hstgr.cloud
- Geheimnisse nur in secure/Lauf_1118_G1.txt (chmod 600), nie ausgeben

## Mac-Besonderheit
- Lokale Daten auf dem Mac NICHT über Schlüsselbund löschen (geteilter Schlüsselbund mit Nutzer-App /Applications/FamilyNexus.app, nicht anfassen). V-04 auf G1 nicht nötig (frische .e2e-Installation zeigt Willkommen).
- Server-Rate-Limit (429) bei vielen Logins: sparsam.

## Stand

## Stand nach Agent V/A/B (Ende ca. 12:30)
- V-01 bis V-07, A-01 bis A-12, B-01 bis B-27 durchlaufen; Ergebnisse in Ergebnisse.tsv (55 Zeilen). Offen/⏳: A-05a, B-12a, B-12b, B-17 (G1); Teile von B-07, B-10, B-12, B-14, B-25, B-26 (Screenreader, Systembenachrichtigung, Tastatur/Tablet).
- Konten: N1 fnt-1118-n1 ("Test N1") angelegt auf matrix-synapse-3ues.srv1348446.hstgr.cloud (ID @fnt-1118-n1:matrix.chaostribunal.de). N2 fnt-1118-n12, I2 fnt-1118-i2, n9 fnt-1118-n9 sind NOCH FREI. Passwort N1 = PW_N1 (gilt wieder das ALTE Passwort, B-23 zurueckgestellt, Gegenprobe 200), PW_N2, PW_I2 (fuer D/E vorbereitet, 20 Zeichen), KN1 (Notfall-Schluessel A-10), PW_N1_NEU = Hilfswert aus B-23; alles in secure/Lauf_1118_G1.txt (chmod 600, git-ignoriert). Notfall-Datei KN1: secure/FamilyNexus-Notfall-Schluessel_1118_N1_KN1.txt. Hilfsskript login.py fuer Passwort-Gegenproben (liest nur aus der Geheimnisdatei).
- Familie F1 "Testfamilie 1118" (N1 Moderator, einziges Mitglied; Empfehlung "zweiten Moderator ernennen" sichtbar). Familien-Code steht in Menue > Familie (nicht notiert).
- Beispieldaten in F1: Termine "Test geteilt 2" (19.11. 10:30-11:30, geteilt, Kueche, Notiz Testnotiz, Verlauf 1), "Test privat" (19.11. 21-22 privat), "Test Serie" (Fr 20.11. und 4.12., ganztaegig, woechentlich; Vorkommen 27.11. geloescht), "Test Thema" (18.11. 13-14, auf PRIVAT gestellt, Kopie mit neuer ID, blau); "Test Erinnerung" geloescht. Themen: Schule (Lila), Sport (Gruen). Chat: "Hallo Testfamilie / zweite Zeile" (12:01, Tester-Missgeschick, siehe B-12), "Hallo Testfamilie" (12:02), Karte "Test geteilt 2", Nachricht mit 4000/4001 Smileys (12:18, nicht loeschbar). Einkauf: Eier, Mehl, Salz (Gruppe Aldi), Vollkornbrot (ohne Gruppe), Milch erledigt (2 l). Aufgabenliste "Bad putzen" (woechentlich Mo, Du, Waschbecken erledigt mit Kommentar "erledigt", Spiegel offen). Geburtstage: Oma Test (21.11.1950), Opa Test (10.05.1948, Todestag 20.11.2020), Schalt Test (29.02. ohne Jahr); "Loesch Test" geloescht. Standard-Erinnerung wieder 10 Minuten; Einstellungen = Standard (Deutsch, Dunkel, Tuerkis, Effekte aus, Geburtstage 7 Tage, Online-Status an, Lesebestaetigung an, App-Sperre aus).
- G1 (Mac): App laeuft (Bundle .e2e, Worktree-Build), angemeldet als N1, Kalender in Agenda, Fenster 800x800 an Position (445,33) (front1 setzt es; Menueleiste verhindert y=30). Benachrichtigungen: Systemdialog erscheint nicht (ad hoc); Hinweis "Benachrichtigungen sind blockiert" bleibt (B-02/B-10 ⚠️). Es erschien KEINE Schluesselbund-Abfrage.
- G2 (Android emulator-5570, en-US): App FamilyNexus gestartet, steht auf "Welcome to FamilyNexus" (unberuehrt, keine Anmeldung, keine Bildschirmsperre, Benachrichtigungen nicht erlaubt). Wie im Plan nach B. C beginnt mit Anmeldung N1 auf G2 (Anbieter-Schritt "Anderer Anbieter oder eigener Server").
- Hilfsfunktionen: logs/helfer/h.sh (front1 Fenster setzen, s1/s2 Screenshot G1/G2 + 900-px-Vorschau in $SP/v1.png bzw. v2.png, p1 X Y = Klick mit Koordinaten aus der 900-px-Vorschau, c1 relativ, t1 Text tippen (Umlaute gehen auf dem Mac), clr1 Feld leeren (Cmd+A, Entf), ent1/esc1/bs1 Tasten per System Events, sc1 N = Scrollen (negativ = nach unten), cb = Text per Zwischenablage einfuegen, pw1 KEY/pwp KEY n = Geheimnis aus Datei einfuegen, rd = Schwaerzen, row = Zeile in Ergebnisse.tsv, sval KEY). $SP muss auf ein Scratch-Verzeichnis zeigen (ui.py, scroll.js dort ablegen); adb-Wrapper u2 = python3 ui.py G2 ... (Port 5570 in ui.py gesetzt; ANDROID_SDK_ROOT=/opt/homebrew/share/android-commandlinetools).
- Bedienhinweise Mac: cliclick 'kp:return' loest onSubmitted nicht aus, System-Events-Tastencode 36 schon; Papierkorb-/Stift-Symbole brauchen teils zwei Klicks (Tooltip zuerst); Scrollen ueber CGEvent-Skript scroll.js; Layout verschiebt sich bei Fehlermeldungen (vor Klick Screenshot pruefen). Android-Emulator-Screenshot nur in Pfad ohne Leerzeichen schreiben, dann kopieren.
- Wichtige Befunde fuer den Abschlussbericht: siehe Zwischenbericht (A-01 schwarzes Fenster beim Kaltstart macOS, A-09 Plantext "Schritt 2 von 3" veraltet = "Schritt 3 von 4", A-12 Einfuehrungstour im Plan nicht beschrieben, B-02/B-10 ad-hoc keine Benachrichtigungen, B-27 Listenreihenfolge, Button-Beschriftung "Person anlegen" statt "Person hinzufuegen").

## Stand nach Agent C/D (laufend, 13:27)
- C-01 bis C-08 durchlaufen (alle OK). KN1b (neuer Notfall-Schlüssel N1, gilt jetzt) in secure/Lauf_1118_G1.txt; KN1 ungültig.
- B-02/B-10/B-12a/B-14/B-17/B-18/B-25/B-07 auf G2 nachgeholt (siehe Ergebnisse.tsv).
- N2 fnt-1118-n12 ("Test N2") ANGELEGT in D-01 auf G2, KN2 in secure/ (Schlüssel nach 20 s unverändert, Datei gespeichert und gelöscht). G2 steht danach im Familienschritt (Schritt 3 von 3, Umschalter Create|Join).
- Emulator wurde um 12:36 neu gestartet (Absturz), Daten erhalten; Emulator-Eigenheiten: Stift-Tutorial abgeschaltet, Tastatur zeigt bei Hardware-Eingabe.
- Android: BACK nach geschlossener Tastatur beendet die App (Formularzustand bleibt erhalten); Koordinaten u2 tapxy sind Vollauflösung (1080x2400), Vorschaubild 405x900 => Faktor 2,667.

## ENDSTAND Agent C/D (13:37) fuer Folgeagent (E, H, F)
- Fertig: C-01..C-08, D-01..D-07 (D-07 n/a), dazu auf G2 B-02, B-07, B-10, B-12a, B-14, B-17, B-18, B-25 (Smartphone). Ergebnisse.tsv bis Zeile 80.
- Konten (alle auf matrix-synapse-3ues, IDs @...:matrix.chaostribunal.de): N1 fnt-1118-n1 (PW_N1, KN1b gueltig; KN1 ungueltig), N2 fnt-1118-n12 "Test N2" (PW_N2, KN2, Moderator von F2). I2 fnt-1118-i2 und n9 fnt-1118-n9 sind FREI (D-06 Gegenprobe). Alles in secure/Lauf_1118_G1.txt (KN1b, KN2 neu).
- Familien: F1 "Testfamilie 1118" (N1, einziges Mitglied; Familien-Code auf G1 unter Menue > Familie; Beitrittsanfrage von N2 abgelehnt), F2 "Loeschtest 1118" (N2, einziges Mitglied; wird erst in F geloescht).
- Geraete: N1 hat zwei Geraete (FamilyNexus macOS, FamilyNexus Android); G2-Android-Eintrag von N1 wurde bei C-08 durch Abmelden entfernt (Server). N2 nur ein Geraet (Android, abgemeldet am Ende, D-06). 
- G1 (Mac): angemeldet als N1, Kalender/Heute. Mac-Bildschirm war zwischenzeitlich gesperrt (Nutzer hat entsperrt; caffeinate -d -i laeuft 2 h). Die App kann zwischendurch Fenster verloren haben (kill + open des Worktree-Builds noetig war). Einstellungen G1 Standard.
- G2 (Android emulator-5570, en-US): steht auf "Welcome to FamilyNexus" (abgemeldet), PIN entfernt (locksettings clear), Flugmodus aus, Dichte/Schrift/Rotation Standard, Bildschirmschutz AUS, App-Sperre aus, Benachrichtigungen erlaubt (Android-Dialog bestaetigt), Schalter 'Reopen last conversation' AUS. Emulator-Eigenheiten: Stift-Tutorial per settings abgeschaltet, show_ime_with_hard_keyboard=1.
- Beispieldaten F1 jetzt ohne 'Test Erinnerung' (G2 hat ihn angelegt und wieder geloescht; 'Offline Test' (gesendet) und 'Offline Test 2' (Nicht gesendet) stehen im Familienchat F1 von N1).
- Offen aus C/D: B-12b, B-17 (macOS), B-26/B-14 Tablet-Teile; Teil B-17 mit zweitem Geraet (Nachricht von G1 an G2 unter Sperre) nicht gemacht.
- Befunde C/D: B-25 Chat Querformat+Tastatur Ueberlauf 31 px (Android); D-02a Diagnosedialog deutsche Schluessel in englischer App; Schalter Bildschirmschutz stand ab Werk AN (Plan Abschn. 2 erwartet aus); Anmeldeseite waehlt nach Abmelden immer wieder matrix.org (Anbieter muss neu gewaehlt werden); Emulator-Absturz 12:36. Hinweis D-05a-Bild versehentlich geloescht, Beleg im Text.
- Bedienhinweise Android: u2 tapxy Vollaufloesung (Vorschaubild 405x900 => Faktor 2,667); redact.py nimmt 900-px-Raster-Koordinaten (Bild breit 900); Android-Eingabe: Feld leeren mit keyevent 123 (MOVE_END) + viele keyevent 67; bei Namensfeld setzt die App den Benutzernamen automatisch (vorher leeren).

## ENDSTAND Agent E/H (ca. 15:12) fuer den F-Agenten
- Fertig: E-01..E-31 (E-32 zuletzt, siehe unten), E-02a, E-16a/b, E-18c/d, E-19a/b/c, dazu B-12b, B-17b (Zweitgeraet), H-01..H-17, H-20. Ergebnisse.tsv ab Zeile 81. NICHT ausgefuehrt/offen: E-18c Rest (Zurueck bei offenem Menue, Tab Einkauf, Tablet/Querformat, TalkBack, Datum gestern/aelter), E-19b Rest (Wechsel auf 'Initialen', Freischaltung in bestehender Familie, Entfernen von I2, TalkBack), E-26 Snackbar-Text 'ist blockiert', E-32 Anfuehrungszeichen-/#272-Pruefung, H-08c auf macOS, H-18/H-19 (F-Agent).
- Reihenfolge-Abweichung: E-32 (Loeschung I2) wurde NACH H gemacht, weil H-10/H-11/H-16/H-20 I2 brauchen (Plan Abschn. 3: nur E-01..E-31 und H-01..H-17 muessen vor F-01 durch sein).
- KONTEN: N1 fnt-1118-n1 besteht (PW_N1). Notfall-Schluessel: KN1b ist UNGUELTIG (H-07 hat bei G1 einen NEUEN Schluessel erzeugt), GUELTIG ist KN1c (secure/Lauf_1118_G1.txt, Eintrag KN1c=; Datei secure/FamilyNexus-Notfall-Schluessel_1118_N1_KN1c.txt). Validitaet von KN1c noch nicht beim Freischalten belegt (F-05 erstmals). N2 fnt-1118-n12 besteht (PW_N2, KN2, Moderator von F2 'Loeschtest 1118', einziges Mitglied, abgemeldet). I2 fnt-1118-i2 wurde in E-32 geloescht (M_USER_IN_USE, KI2 hinfaellig). n9 fnt-1118-n9 frei.
- FAMILIEN: F1 'Testfamilie 1118 neu' (N1 einziger Moderator und Mitglied; Empfehlung zweiter Moderator wieder sichtbar), F2 'Loeschtest 1118' (N2). Beispieldaten F1 zusaetzlich: Termine 'Termin I2 Thema', 'Termin Leerlauf' (von I2, Raum bleibt), Aufgabenliste 'Muell rausbringen' (zugewiesen I2/zurueck; 'Bad putzen' geloescht), Geburtstage 'Oma Test 2', 'Tante Test' neu, Einkauf nur Mehl, Salz (Aldi), Melde-Milch; Chat mit vielen Testnachrichten, 3 Anhaenge (fn-bild.png, FN-ANHANG.txt, a_b_c_d.txt) und fast25.txt (25 MiB-1); Kalender-Thema 'Neu' (Gelb); Thema 'Sport' geloescht. Einzelchat N1<->I2 bleibt (Raum), I2 nicht mehr Mitglied.
- GERAETE: G1 (Mac) angemeldet als N1, Einstellungen: Lesebestaetigung an, Online-Status an, 'Letztes Gespraech wieder oeffnen' aus, App-Sperre aus (nie an), Benachrichtigungen blockiert (ad hoc). N1 hat nur das Geraet 'FamilyNexus macOS' (Testwerkzeug abgemeldet). G2 (Android emulator-5570): 'Welcome to FamilyNexus', abgemeldet, kein Konto, keine Geraetesperre (PIN wieder entfernt, locksettings get-disabled true), App lock aus (nach Abmeldung/Loeschen Einstellungen ohnehin zurueckgesetzt); Datenbank von I2 durch Kontoloeschung geloescht (Beleg Welcome).
- Dateien ausserhalb der App (aufraeumen/F-Agent): Emulator /sdcard/Download/ (fn-bild.png, FN-ANHANG.txt, a_b_c_d.txt = bewusst gespeicherte Anhaenge, H-15/H-18 Referenz); Scratchpad work/ (FN-ANHANG.txt, a<b>c"d.txt, fn-bild.png, test.*); secure/link_1118.txt (verbrauchter Einladungslink, geheim halten); secure/FamilyNexus-Notfall-Schluessel_1118_N1_KN1c.txt.
- Befunde E/H: E-16 Offline-Teil auf G2 statt G1; E-18c Rest offen; E-18d Uhr-Zustand nicht erfasst; E-19 Avatar-Ring in Terminkarte vor Avatarwahl nicht erkennbar; E-26 Bestaetigungs-Snackbar nicht erfasst; E-32 Avatar '?' statt Buchstabe nach Kontoloeschung (Plan E-101); B-17b App-Sperre laesst sich nach entfernter Geraetesperre nicht abschalten ('The confirmation was not successful.'; Workaround PIN neu setzen); H-07 erzeugt neuen Notfall-Schluessel (Plan-Hinweis: Kopieren geht nur ueber den Erstell-Dialog, daher wird KN gewechselt); H-10 Einzelchat in der Online-Uebersicht nur mit Raum-ID statt Namen; H-06 Datenschutz-Abschnitt 7 nicht geprueft.
- Bedienhinweise: Mac Datei-Dialog per Cmd+Shift+G + Pfad per Zwischenablage (cb) + Return, Return; lange Druecken per cliclick dd:/du: mit 1,2 s; Android 'u2 tap Back' trifft nach Wechseln oft den falschen Zurueck-Pfeil, besser u2 tapxy 74 206; App-Neustart Mac: pkill -f "wt-l36.*MacOS/FamilyNexus"; open <Worktree>.app; front1.

## ENDSTAND Agent F (Lauf 36)
- F-01, F-02, F-05 (G2, KN1c gueltig), F-06 (G2), F-07, F-08 durchlaufen; F-03, F-04, F-05a, H-18, H-19 auf G1 bewusst nicht (geteilter Schluesselbund). Alle drei Konten geloescht (M_USER_IN_USE). G2 Welcome, Download leer. Mac-App per Cmd+Q beendet, Container de.inneso.familynexus.e2e bleibt.
