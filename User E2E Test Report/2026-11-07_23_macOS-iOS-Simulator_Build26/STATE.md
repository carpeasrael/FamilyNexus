# STATE Lauf 2026-11-07_23 (macOS G1 / iPhone-Simulator G2), Plan TP-FN-001 v1.36 @ main 0afeab8

## Abschnitt 2 (Plattform)
| Angabe | G1 | G2 |
|---|---|---|
| Plattform | macOS | iOS (Simulator) |
| Gerät | dieser Mac (Debug-Build, Bundle-ID de.inneso.familynexus.e2e) | iPhone 18 Pro Max, UDID BED4ED87-29CC-47BC-B3CF-6D13B60C7783 |
| OS | macOS 27.2 | iOS 27.2 |
| Installationsquelle | Build aus main (wt/build/macos/.../Debug/FamilyNexus.app), ad-hoc signiert | Build aus main (simctl install) |
| Version Soll/Ist | 1.2.2 (26) / 1.2.2 (26) | 1.2.2 (26) / 1.2.2 (26) |
| Sprache, Sperre | de-DE, Sperre nicht geprüft | de, kein Gerätecode (nicht geprüft) |
| Screenshots | screencapture -R (Fenster fest 445,118, 800x700 pt) | xcrun simctl io <UDID> screenshot |
| Tester / Beginn | Claude (Tester-Agent) / 07.11.2026 07:38 | dito |

## Konten (Datumsteil 1107b; 1107 belegt durch Lauf 22: fnt-1107-n1 belegt)
- N1 `fnt-1107b-n1` (Test N1) – G1, später G2 (C)
- N2 `fnt-1107b-n12` (Test N2) – G2 (D-01, Folgeagent)
- I2 `fnt-1107b-i2` (Test Nutzer 2) – G2 (E-09, Folgeagent)
- n9 `fnt-1107b-n9` – nur Prüfname
Server: matrix-synapse-3ues.srv1348446.hstgr.cloud
## Geheimnisse
`secure/Lauf_1107b_G1.txt` (chmod 600, git-ignoriert): Passwort N1, Notfall-Schlüssel KN1/KN1b (werden dort angehängt). NIE ausgeben.

## Koordinaten/Fenster
- Hilfsfunktionen: /private/tmp/claude-501/-Users-carpeasrael-NextCloud-int-mac-project-2-FamilyNexus/3362d457-81f2-4222-9b7e-54a8f9b84bff/scratchpad/h.sh (s1/s2 Screenshot, c1/c2 Klick, t1/t2 Tippen, row = TSV)
- Bildschirm 1470x956 pt. G1-Fenster per AX auf (445,30) Größe 800x800 gesetzt; Screenshot-Bild 1100 px breit = 1.375 px/pt.
- G2: Device-Hub-Fenster „iPhone 18 Pro Max – iOS 27.2“ (jetzt einziges DeviceHub-Fenster, auf {2,33} gesetzt, 392x859). Simulator-Pixel (1320x2868) -> Bildschirmpunkte: x=30+px*0.2548, y=96+py*0.2548; Hilfsfunktion c2 nimmt Koordinaten des 1100-Pixel-hohen Screenshots (x=30+X*0.664, y=96+Y*0.664). Der iPhone 17 (iOS 26.4) im Fenster 1 wird NICHT bedient.
- Mac-Besonderheit: Löschen lokaler Daten auf G1 verboten (geteilter Schlüsselbund mit Nutzer-App). /Applications/FamilyNexus.app existiert (Nutzer, nicht anfassen).

## Stand (Ende Agent V/A/B/C, ca. 08:55)
- V, A, B, C vollständig durchlaufen; Ergebnisse in Ergebnisse.tsv (64 Zeilen: 46 ✅, 9 ⚠️, 4 ⏳, 5 n/a, 0 ❌).
- Konten/Familien: N1 fnt-1107b-n1 ("Test N1", Passwort in secure/Lauf_1107b_G1.txt, gilt wieder das ALTE Passwort nach B-23). Familie F1 "Testfamilie 1107b" (N1 Moderator, 1 Mitglied). N2 fnt-1107b-n12, I2 fnt-1107b-i2, n9 fnt-1107b-n9 sind NOCH FREI (noch nicht angelegt).
- Notfall-Schlüssel: KN1 (A-10, ungültig) und KN1b (C-05, gültig) in secure/Lauf_1107b_G1.txt; Datei FamilyNexus-Notfall-Schluessel_1107b_N1_KN1.txt (KN1) in secure/.
- G1 (Mac): App läuft, angemeldet als N1, Fenster 800x800 (front1 setzt es), Einstellungen wie Standard (Deutsch, Dunkel, Türkis, Effekte aus, Standard-Erinnerung 10 min, Online-Status an). Test-Daten in F1: Termine "Test geteilt 2" (8.11. 10:30-11:30, geteilt), "Test privat" (8.11. 21-22), "Test Serie" (Mo 9.11. und 23.11., ganztägig, wöchentlich; Vorkommen 16.11. gelöscht), Chat: "Hallo Testfamilie", 2x Terminkarte, 1x Nachricht mit 4001 Smileys (unlöschbar); Einkauf: Eier/Mehl/Salz (Gruppe Aldi), Vollkornbrot, Milch erledigt; Aufgabenliste "Bad putzen" (wöchentlich Mo, Waschbecken erledigt).
- G2 (iPhone-Sim): angemeldet als N1 (zweite Anmeldung nach C-08, freigeschaltet mit KN1b), Einstellungen geöffnet (Datenschutz-Abschnitt). Bildschirmschutz an (Standard), Benachrichtigungen erlaubt. Simulator-Gerätecode gesetzt, unbekannt (B-17 ⏳). Nicht abgemeldet: Folge-Schritt D beginnt mit Abmelden bzw. D-01 nach C-08-Zustand ("Anmelden"); G2 ist jetzt angemeldet (N1) – vor D-01 abmelden (Einstellungen > Abmelden).
- Beachte: auf G2 Klicks auf Schaltflächen brauchen langen Klick (l2), Scrollen per Wischen (up2) nur teilweise zuverlässig (mehrfach wiederholen, dazwischen sleep 1.2). Text auf G2: cliclick t: (Großbuchstaben kommen an); Einfügen per Simulator-Zwischenablage ging nicht. Bei Änderung des Layouts (Fehlermeldungen) verschiebt sich die Position der Schaltflächen – vor dem Klick Screenshot prüfen.
- Server-Rate-Limit: wiederholte Login-Gegenproben (B-23) lösten 429 M_LIMIT_EXCEEDED aus (~5 Min Sperre) – sparsam sein.
- Mac-Besonderheit: ad-hoc-signierter Build: Systemdialog für Benachrichtigungen erscheint nicht, Hinweis bleibt (B-02, B-10 ⚠️). macOS-Passwort/Touch-ID (B-17) nicht bedienbar.
- Gespeicherte Notfall-Datei vom Mac: ~/Library/Containers/de.inneso.familynexus.e2e/Data (Container der Test-App, Datei nach secure/ verschoben).
- Offene Nachtests (⏳): B-12a (Offline-Senden, Netz trennen), B-17 (App-Sperre, G1+G2), B-18 App-Umschalter (G2), B-25 Tablet/iPad-Teile, B-10 Systembenachrichtigung mit signiertem Build, Bedienhilfe-Namen der Symbole (C-02).

## Agent D/E (Start 09:00)
- D-01 erledigt: N2 fnt-1107b-n12 angelegt (Passwort PW_N2, KN2 in secure/Lauf_1107b_G1.txt). G2 = N2, Familienschritt (Schritt 3 von 3), G1 = N1.
- G2-Bedienung: Schaltflächen oft erst beim 2. langen Klick (l2); Scrollen zuverlässig per dr2 a b (a<b = nach oben scrollen, a>b = nach unten). Löschen im Feld: cliclick w:40 kp:delete x25. Temp-Dateien: $SP/pw_n2.txt, kn2.txt.
- D-01..D-06 erledigt (D-02a ⚠️ Kopieren nicht belegt, D-07 noch offen = Server-Admin n/a). G2 steht auf 'Willkommen' (abgemeldet; N2 mit F2 'Löschtest 1107b' existiert, Moderator). Alte Hinweise: G2 Klicks mit l2 (2x probieren), Eingabe langer Texte per pc (Send Clipboard + Cmd+V + Einsetzen-Popup antippen).
- Stand 10:25: D-01..D-07, E-01..E-23 erledigt (E-16 ⚠️/⏳ Offline, E-16b ⚠️ teilweise). G1=N1 (Aufgaben-Seite), G2=I2 in F1 (Aufgaben-Detail). Neue Daten in F1: Familienname 'Testfamilie 1107b neu', I2 (Test Nutzer 2) Mitglied; Chat-Nachrichten (Hallo von Nutzer 1 / zurueck, Neu 1/2, Zeile 1-6, Zitat-Test, Melde-Test 1-4, testbild.png, testdatei.txt), Einzelchat N1<->I2 ('Nur fuer dich'); Einkauf: Eier/Mehl/Salz (Aldi), Melde-Milch (Vollkornbrot, Kaese, Milch entfernt); Aufgabenliste 'Müll rausbringen' (Mo-Fr, I2, erledigt); Termin I2 (privat, nur bei I2); 'Bad putzen' gelöscht. Einladungslink aus E-05 ist verbraucht ($SP/link_full.txt). N2 hat F2 'Löschtest 1107b', abgemeldet auf G2? (G2 ist jetzt I2, N2 auf Server).
- G2-Tipp: k2 X Y (Hover+Klick) ist zuverlaessiger als l2; Einsetzen-Popup antippen nach Send Clipboard + Cmd+V.
- Stand 10:40: E-01..E-31 erledigt. E-32 (Konto I2 löschen) bewusst NICHT ausgeführt: H-Schritte (H-10, H-13, H-15, H-20 u. a.) brauchen I2 und Einzelchat; Plan sagt 'H-01..H-17 nach E, Konten und F1 bestehen noch'. Agent 3: erst H-01..H-17, dann E-32 (G2 = I2, Passwort PW_I2 in secure/Lauf_1107b_G1.txt), dann F. I2 ist jetzt Moderator in F1 (nach E-30), N1 auch. N1 in F1 ist Moderator, I2 verifiziert (E-24).

## Agent 3 (Start 10:36, Ende 11:55): H-01..H-20, E-32, F, G
- H-01..H-17 erledigt (H-06, H-10, H-14 ⚠️), H-20 ⚠️ (Termin nicht gesendet). E-32 ✅ (I2 auf G2 gelöscht). F-01/F-02 (N2 gelöscht), F-05 (⚠️, auf G2), F-06 (N1 auf G2 gelöscht), F-07, F-08 ✅. F-03/F-04/H-18 ⏳ und H-19/F-05a n/a (Mac-Schlüsselbund geteilt). G-01 ✅, G-02 ⚠️ (1898 bestanden, 108 übersprungen, 1 fehlgeschlagen: Linux-D-Bus-Test app_badge_test auf macOS), G-03 ✅, G-04 ⏳ (kein Docker), G-05/G-07/G-08 n/a, G-06 ⏳.
- Endzustand: Konten fnt-1107b-n1, -n12, -i2 auf dem Server gelöscht (Login 403, register/available M_USER_IN_USE); fnt-1107b-n9 nie angelegt (frei). G1 (Mac): Sitzung ungültig, App zeigt 'Anmelden'; Test-Datenbanken und Schlüsselbund-Einträge fn.key.db.app/.matrix unverändert vorhanden (nichts gelöscht). G2: 'Willkommen' (abgemeldet, lokale Daten gelöscht).
- Notfall-Schlüssel KN1c (H-07) in secure/Lauf_1107b_G1.txt und secure/FamilyNexus-Notfall-Schluessel_1107b_N1_KN1c.txt.
- Beobachtung G2: Einstellungen im Simulator per Mausgeste nach ca. einer Seite nicht weiter scrollbar (Über die App/Alle lokalen Daten löschen unerreichbar); Testartefakt oder Bedienbarkeitsproblem, Nachtest auf Gerät.
- Geheimnis-Suche im Lauf-Ordner: keine Passwörter/Schlüssel gefunden (nur Konto-ID fnt-1107b-n1, kein Geheimnis).
