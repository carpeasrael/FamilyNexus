# Checkliste Gerätenachtests (Stand main c9c300d, 07.11.2026)

**Lauf 22 (07.11.2026, iPhone-Simulator, Mac nur Teilbeleg):** Siehe `User E2E Test Report/2026-11-07_22_iOS-macOS-Simulator_Build26/Testreport.md`. Punkte mit „Sim.“ sind im iPhone-Simulator bestanden, am echten Gerät aber **nicht abgenommen**; macOS-Oberfläche war nicht benutzbar (Schlüsselbund-Abfrage des ad hoc signierten Debug-Builds), dort braucht es den signierten TestFlight-Build 26.

Quelle: letzte Kommentare der offenen Issues. Jeder Punkt schließt nur dann ein Issue, wenn er bestanden ist; Ergebnis jeweils im Issue vermerken. Issues schließen sich beim Merge, nicht von Hand (bei diesen Issues ist der Code bereits gemergt, das Schließen entscheidest du nach dem Nachtest).

## Windows 11 (echte Tastatur)
- [ ] **#263 Zeitwähler:** Termin-Editor, Beginn, Zeitwähler, Tastatur-Symbol. Klick ins Feld „Stunde“, `21` tippen, dann Minuten `30`. Erwartet: Stunde 21, Minuten 30. Zusätzlich beobachten: Klick aktiviert das Fenster direkt im Feld (Restfall).
- [ ] **#144 Screenshot-Hinweis (Testplan B-18):** Hinweis lautet „Nimmt die App von Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben aus.“. Screenshot und Aufnahme müssen leer sein. Alt-Tab beobachten und notieren (nur beobachten, nicht belegt).
- [ ] **#254 E-16b:** Meldungen und Zahl als Overlay-Symbol in der Taskleiste (neuer nativer Code `taskbar_badge.cpp`).
- [ ] **#274 (Desktop-Fenster):** Fenster auf 599/600/1000 dp-Breite ziehen: Leiste ↔ Rail ↔ Zweispalter, kein Zustandsverlust, Tab-Reihenfolge Inhalt vor Rail. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).

## iPhone (echt)
- [ ] **#144 (B-18):** Hinweis lautet „Verdeckt die App im App-Umschalter und bei Bildschirmaufnahmen. Einzelne Screenshots lassen sich unter iOS nicht verhindern.“. Screenshot gelingt, App-Umschalter verdeckt die App. *Lauf 22, Sim.: Hinweistext de und en richtig, Karte im App-Umschalter nur Markenfläche. Offen am echten iPhone: Bildschirmaufnahme (im Simulator nicht belegbar), App-Umschalter am Gerät.*
- [ ] **#268 (TP-OAUTH-11):** Kontoanlage und Anmeldung in der System-Sitzung (ASWebAuthenticationSession), Captcha, Konto-löschen- und Passwort-Seite, Sichtschutz. Gegen matrix.org nur mit deiner Freigabe und eigenem Konto.
- [ ] **#254 E-16b:** Meldung ohne Inhalt („Neue Nachricht“), Zahl am App-Symbol, Berechtigungsabfrage. *Lauf 22, Sim.: Berechtigung, Banner ohne Inhalt (de, en), Abzeichen, Zurücksetzen beim Lesen und Abmelden bestanden. Offen am echten iPhone: Sperrbildschirm, iOS 15, nachträgliche Freigabe „Kennzeichen“; gleichzeitig angezeigte Chat- und Einkaufsmeldung nicht belegt.*

## Mac (macOS)
- [ ] **#268 (TP-OAUTH-11):** Anmeldung in der System-Sitzung, Start ohne `network.server`-Berechtigung, Mac mit Chrome als Standardbrowser.
- [ ] **#254 E-16b:** Meldung, Zahl am Dock-Symbol, Berechtigungsabfrage. *Lauf 22: nicht getestet (App nicht bedienbar, siehe oben).*
- [ ] **#274 (Desktop-Fenster):** wie bei Windows.

## iPad (echt oder Simulator)
- [ ] **#274 (Testplan B-25):** Alle vier Ausrichtungen, Split View, Slide Over, Stage Manager. Rail ab 600 dp, Zweispalter Kalender/Chat ab 1000 dp. Bildschirmtastatur im Chat: Layout kippt nicht. Schrift 200 %. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).
- [ ] **#274 Store:** iPad-Screenshots für den App Store anfertigen (siehe `docs/OFFEN.md`).
- [ ] **Lauf 20 offene Schritte (nur Simulator möglich, soweit nicht G2/Gerät nötig):** B-10, B-12a, B-17 (Geräte-PIN), B-23 (c–e), B-24, A-05a, G-04/06/07.

## Android-Tablet (echt oder Emulator Tablet-Profil)
- [ ] **#274 (B-25):** Drehen mit und ohne Rotationssperre, Multi-Window, Bildschirmtastatur (`adjustResize`: Klasse darf beim Tippen nicht wechseln), 200 % Schrift. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).
- [ ] **#268 (TP-OAUTH-12):** Custom Tab auf frischem AVD oder nach Deinstallation (auf dem vorhandenen AVD ist FamilyNexus mit anderem Zertifikat installiert). Außerdem Geräte mit anderem oder ohne Standardbrowser.
- [ ] **#254 E-16b Hintergrund:** Meldungen im Hintergrund schlagen fehl, siehe **#273** (Entscheidung a/b/c nötig, bevor ein Nachtest sinnvoll ist).

## Eigener Testserver + Gerät
- [ ] **#259 (B-21, B-22, F-01, F-06, H-08):** Konto mit Anbieter-Adresse `matrix-synapse-3ues…` (Matrix-ID-Servername `matrix.chaostribunal.de`): Einstellungen → Konto → „Server“, Speicherorte und Dialog „Konto löschen?“ zeigen die eingegebene Anbieter-Adresse. Beachten: Eine vor dem Update angemeldete Sitzung zeigt bis zur nächsten Anmeldung weiter den aufgelösten Server.
- [ ] **#150 (H-20):** Zwei Geräte, 2 Minuten Leerlauf, Abgleiche zählen. Entscheidung danach: selektives Mappen oder Issue mit jetzigem Stand schließen.

## Browser (Web)
- [ ] **#266:** `tool/web_smoke.py` auf `main` (erwartet 5/5), Windows-Laufzeit von `sqlite3` 3.8.0 gegen `sqlcipher.dll`, iOS-/macOS-Build mit 3.8.0 (Build-Hook; CI-`apple` ist grün, Laufzeit nicht belegt).

## Docker (Entwicklungsrechner)
- [ ] **#281:** Docker Desktop starten, `tool/synapse/up.sh` ausführen, danach `curl -fsk https://localhost:18448/_matrix/client/versions` muss 200 liefern, nie 502. Auch `tool/synapse/password_variants.sh` einmal laufen lassen.

## Rein manuell / Entscheidungen
- [ ] **#15 Prüfkonto und Prüfanleitung** auf neuem Build nachtesten.
- [ ] **#273:** Variante a, b oder c wählen.
- [ ] **#142:** Entscheidung des Herausgebers zu E-37.
- [ ] **#119, #120, #121:** v1.3-Entwürfe; #121 ohne rechtliche Freigabe nicht angehen.
