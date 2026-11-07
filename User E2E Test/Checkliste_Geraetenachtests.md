# Checkliste Gerätenachtests (Stand main d0bdfa6 + PR #319/#320, Lauf 22 und 23, 07.11.2026)

**Seit dem letzten Stand erledigt:** #150 geschlossen (Entscheidung des Nutzers, Messung H-20 entfällt, E-85); #296 geschlossen (PR #312, Store-Datenschutz nennt Meldungen und Zahl am Symbol). Zum Merge ausstehend: PR #313 (Testreport Lauf 22).

**Neu seit Lauf 22:** Lauf 23 (`User E2E Test Report/2026-11-07_23_macOS-iOS-Simulator_Build26/`, PR #318): vollständiger Plan auf macOS (Debug-Build, ad hoc signiert, Schlüsselbund-Abfrage vom Nutzer bestätigt) und iPhone-Simulator, 106 ✅ / 19 ⚠️ / 0 ❌ / 10 ⏳ / 12 n/a; Teilbelege stehen bei den Punkten unten („Lauf 23“). Fixes **#317** (Hinweiskarte „Berechtigung fehlt“, PR #319, E-93) und **#316** (Ladebild, iOS-Startbild als Farbfläche, Zeitlog je Startschritt, PR #320, E-94) sind auf `main`; beide Issues bleiben bis zur Abnahme am Gerät offen.

**Lauf 22 (07.11.2026, iPhone-Simulator, Mac nur Teilbeleg):** Siehe `User E2E Test Report/2026-11-07_22_iOS-macOS-Simulator_Build26/Testreport.md`. Punkte mit „Sim.“ sind im iPhone-Simulator bestanden, am echten Gerät aber **nicht abgenommen**; macOS-Oberfläche war nicht benutzbar (Schlüsselbund-Abfrage des ad hoc signierten Debug-Builds), dort braucht es den signierten TestFlight-Build 26.

Quelle: letzte Kommentare der offenen Issues. Jeder Punkt schließt nur dann ein Issue, wenn er bestanden ist; Ergebnis jeweils im Issue vermerken. Issues schließen sich beim Merge, nicht von Hand (bei diesen Issues ist der Code bereits gemergt, das Schließen entscheidest du nach dem Nachtest).

## Windows 11 (echte Tastatur)
**Lauf 24** (`User E2E Test Report/2026-11-07_24_Windows-nur-G1_Build26/`): Build aus `main` @ `40863fd`, Eingaben per `SendInput`; Einzelheiten im Testreport.
- [ ] **#263 Zeitwähler:** *(Lauf 24, Windows mit `SendInput`-Tasten bestanden: Klick markiert „22“, `21` ersetzt, Fokus springt in die markierten Minuten, `30` → 21:30–22:30; Restfall „Klick aktiviert das Fenster direkt im Feld“ ebenfalls markiert, `19` ersetzt. Offen nur noch die physische Tastatur.)* *(Lauf 23, macOS bestanden: `21` ersetzt den Wert, Fokus springt zu den Minuten.)* Termin-Editor, Beginn, Zeitwähler, Tastatur-Symbol. Klick ins Feld „Stunde“, `21` tippen, dann Minuten `30`. Erwartet: Stunde 21, Minuten 30. Zusätzlich beobachten: Klick aktiviert das Fenster direkt im Feld (Restfall).
- [ ] **#144 Screenshot-Hinweis (Testplan B-18):** *(Lauf 24, Windows bestanden: Hinweistext richtig, Standard an (Affinität 17), Vollbild-Screenshot ohne App-Fenster, Alt-Tab-Vorschau schwarz; aus: Affinität 0, sichtbar. Offen: Bildschirmaufnahme und -freigabe.)* *(Lauf 23, iPhone-Simulator: Schalter standardmäßig an, Text richtig.)* Hinweis lautet „Nimmt die App von Screenshots, Bildschirmaufnahmen und Bildschirmfreigaben aus.“. Screenshot und Aufnahme müssen leer sein. Alt-Tab beobachten und notieren (nur beobachten, nicht belegt).
- [ ] **#254 E-16b:** *(Lauf 24, Windows bestanden: Meldung „Neue Nachrichten“ ohne Inhalt, Overlay „1“ und „9+“, verschwindet beim Lesen; Klartext-Nachricht wird nicht gezählt. Zweite Person war ein `matrix-js-sdk`-Hilfsclient.)* Meldungen und Zahl als Overlay-Symbol in der Taskleiste (neuer nativer Code `taskbar_badge.cpp`).
- [ ] **#274 (Desktop-Fenster):** *(Lauf 24, Windows bestanden: 599 Leiste, 600/999 Rail, ab 1000 Zweispalter „Kalender und Chat“; Chatentwurf, Terminformular und offener Dialog bleiben; ab 1000 kein Strich auf Heute, Einkauf, Familie. Tab-Folge: Menü → Rail → Inhalt zusammenhängend (E-92: eigene Fokusgruppen); die Formulierung „Inhalt vor Rail“ unten trifft das nicht genau. Offen: 200 % Schrift.)* *(Lauf 23, macOS: Breiten 500/800/1150 pt, Entwurf bleibt erhalten; 599/600/1000 dp offen.)* Fenster auf 599/600/1000 dp-Breite ziehen: Leiste ↔ Rail ↔ Zweispalter, kein Zustandsverlust, Tab-Reihenfolge Inhalt vor Rail. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).

## iPhone (echt)
- [ ] **#144 (B-18):** Hinweis lautet „Verdeckt die App im App-Umschalter und bei Bildschirmaufnahmen. Einzelne Screenshots lassen sich unter iOS nicht verhindern.“. Screenshot gelingt, App-Umschalter verdeckt die App. *Lauf 22, Sim.: Hinweistext de und en richtig, Karte im App-Umschalter nur Markenfläche. Offen am echten iPhone: Bildschirmaufnahme (im Simulator nicht belegbar), App-Umschalter am Gerät.*
- [ ] **#268 (TP-OAUTH-11):** Kontoanlage und Anmeldung in der System-Sitzung (ASWebAuthenticationSession), Captcha, Konto-löschen- und Passwort-Seite, Sichtschutz. Gegen matrix.org nur mit deiner Freigabe und eigenem Konto. *Lauf 22: nicht getestet (kein OAuth-Anbieter auf dem Testserver).*
- [ ] **#297:** In der System-Sitzung (Captcha, Konto löschen) nennt der Hinweis zum Schließen „iPhone, iPad und Mac“ und „Abbrechen“. Braucht einen OAuth-Anbieter (Lauf 22: nicht getestet).
- [ ] **#254 E-16b:** Meldung ohne Inhalt („Neue Nachricht“), Zahl am App-Symbol, Berechtigungsabfrage. *Lauf 22/23, Sim.: Berechtigung, Banner ohne Inhalt (de, en), allgemeine Meldungen für Chat und Einkauf, keine Meldung bei geöffnetem Chat, Abzeichen, Zurücksetzen beim Lesen und Abmelden bestanden. Offen am echten iPhone: Sperrbildschirm, iOS 15, nachträgliche Freigabe „Kennzeichen“; gleichzeitig angezeigte Chat- und Einkaufsmeldung nicht belegt.*

## Mac (macOS)
**Voraussetzung:** der signierte TestFlight-Build 26. Der Debug-Build (ad hoc signiert) fragt beim Start das Login-Passwort für den Schlüsselbund ab und ist nicht bedienbar (Lauf 22). Die Test-Bundle-ID `.e2e` ist nur für Läufe ohne Nutzerdaten gedacht; den Rest `~/Library/Containers/de.inneso.familynexus.e2e` von Hand löschen.

- [ ] **#268 (TP-OAUTH-11):** Anmeldung in der System-Sitzung, Start ohne `network.server`-Berechtigung, Mac mit Chrome als Standardbrowser. *Lauf 22: Teilbeleg, der Release-Build trägt `network.client` und kein `network.server`; Anmeldung nicht getestet.*
- [ ] **#254 E-16b:** Meldung, Zahl am Dock-Symbol, Berechtigungsabfrage. *Lauf 22: nicht getestet (App nicht bedienbar, siehe oben). Lauf 23: Debug-Build mit Bestätigung der Schlüsselbund-Abfrage bedienbar, Dock-Zahl und Berechtigung am signierten Build offen.*
- [ ] **#274 (Desktop-Fenster):** wie bei Windows. *Lauf 22: nicht getestet.*
- [ ] **#266 (Apple-Laufzeit):** App startet mit `sqlite3` 3.8.0, Tresor und Datenbank lesbar. *iOS-Simulator Lauf 22 bestanden; macOS offen.*

## iPad (echt oder Simulator)
- [ ] **#274 (Testplan B-25):** *(iPhone-Simulator Lauf 22: Hoch- und Querformat einspaltig, Tastatur, 200 % Schrift ohne Überlauf; Wortbruch bei 200 % als Beobachtung, Folgeissue Entscheidung des Nutzers; „Entwurf bleibt beim Drehen“ offen.)* Alle vier Ausrichtungen, Split View, Slide Over, Stage Manager. Rail ab 600 dp, Zweispalter Kalender/Chat ab 1000 dp. Bildschirmtastatur im Chat: Layout kippt nicht. Schrift 200 %. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).
- [ ] **#274 Store:** iPad-Screenshots für den App Store anfertigen (siehe `docs/OFFEN.md`).
- [ ] **Lauf 20 offene Schritte (nur Simulator möglich, soweit nicht G2/Gerät nötig):** B-10, B-12a, B-17 (Geräte-PIN), B-23 (c–e), B-24, A-05a, G-04/06/07.

## Android-Tablet (echt oder Emulator Tablet-Profil)
- [ ] **#274 (B-25):** Drehen mit und ohne Rotationssperre, Multi-Window, Bildschirmtastatur (`adjustResize`: Klasse darf beim Tippen nicht wechseln), 200 % Schrift. Ab 1000 dp kein senkrechter Strich auf Heute, Einkauf und Familie (#309).
- [ ] **#268 (TP-OAUTH-12):** Custom Tab auf frischem AVD oder nach Deinstallation (auf dem vorhandenen AVD ist FamilyNexus mit anderem Zertifikat installiert). Außerdem Geräte mit anderem oder ohne Standardbrowser.
- [ ] **#254 E-16b Hintergrund:** Meldungen im Hintergrund schlagen fehl, siehe **#273** (Entscheidung a/b/c nötig, bevor ein Nachtest sinnvoll ist).

## Neue Fixes: Sichtkontrolle am Gerät
- [ ] **#317 (Testplan B-02):** Bei blockierten Benachrichtigungen zeigt „Heute“ die Karte „Berechtigung fehlt“ und „Erinnerungen“ nur einmal; dasselbe in der Erinnerungs-Übersicht (AppBar „Erinnerungen“). iPhone und signierter Mac; hell, dunkel, große Schrift. Linux und Windows: keine Karte (Berechtigung gilt dort immer als erteilt). *Lauf 24, Windows bestanden: keine Karte, „Erinnerungen“ genau einmal.* *Widget-Test und CI grün, PR #319.*
- [ ] **#316 (Testplan A-01):** Kaltstart (App beenden, neu öffnen) hell und dunkel: erst einfarbige Fläche (`#F6F7FB` / `#0B1120`), dann „Lädt …“, nie weiß oder schwarz. Zeit bis „Heute“ notieren. Zusätzlich `flutter run --profile` am echten iPhone, Log `schritt=<name> ms=<n>` je Startschritt auswerten; bei einem dominanten Schritt Folge-Issue. *Build und Tests grün (PR #320); im Simulator ließ sich das Startbild nicht aufnehmen. macOS-Fensterfarbe bewusst verworfen (E-94).* Offen: Antwort des Melders zu „Stadtbild“ = Startbild?
- [ ] **#332 (Screenreader, Chat):** Eigene Chatnachricht mit einem Screenreader vorlesen lassen: iPhone/iPad VoiceOver, Android TalkBack, Windows NVDA, Mac VoiceOver. Erwartet: deutsche App „Nachricht von dir“ (nicht „Nachricht von Du“), englische App „Message from you“; eine Nachricht eines anderen Mitglieds weiter „Nachricht von {Name}“. *Label-Text im Widget-Test belegt, CI grün, PR #333; die Sprachausgabe ist nicht geprüft. Das Issue bleibt bis zu diesem Nachtest offen.*

## Eigener Testserver + Gerät
- [ ] **#259 (B-21, B-22, F-01, F-06, H-08):** Konto mit Anbieter-Adresse `matrix-synapse-3ues…` (Matrix-ID-Servername `matrix.chaostribunal.de`): Einstellungen → Konto → „Server“, Speicherorte und Dialog „Konto löschen?“ zeigen die eingegebene Anbieter-Adresse. Beachten: Eine vor dem Update angemeldete Sitzung zeigt bis zur nächsten Anmeldung weiter den aufgelösten Server.
- [x] **#150 (H-20):** entfällt. Issue am 07.11.2026 mit dem jetzigen Stand geschlossen (E-85); bei später auffallender Last neues Issue mit Messung.

## Browser (Web)
- [ ] **#266:** *(Lauf 24, Windows-Laufzeit bestanden: Release-Build mit `sqlite3` 3.8.0 und `sqlcipher.dll` aus v1.2.2 läuft, übersteht den Neustart, Datei verschlüsselt; 13 SQLCipher-Testdateien grün.)* `tool/web_smoke.py` auf `main` (erwartet 5/5), iOS-/macOS-Build mit 3.8.0 (Build-Hook; CI-`apple` ist grün; iOS-Simulator Lauf 22 bestanden, macOS-Laufzeit nicht belegt).

## Docker (Entwicklungsrechner)
- [ ] **#281:** Docker Desktop starten, `tool/synapse/up.sh` ausführen, danach `curl -fsk https://localhost:18448/_matrix/client/versions` muss 200 liefern, nie 502. Auch `tool/synapse/password_variants.sh` einmal laufen lassen.

## Rein manuell / Entscheidungen
- [ ] **#15 Prüfkonto und Prüfanleitung** auf neuem Build nachtesten.
- [ ] **#273:** Variante a, b oder c wählen.
- [ ] **#142:** Entscheidung des Herausgebers zu E-37.
- [ ] **#119, #120, #121:** v1.3-Entwürfe; #121 ohne rechtliche Freigabe nicht angehen.
