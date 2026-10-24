# Testplan: Registrierung, Familie einrichten, Einladen und Beitreten

Stand: 2026-10-24 · Phase 8 · Entscheidungen E-55, E-56, E-57, SA-8

## 1. Ziel

Nachweis, dass Menschen **ohne Software-Affinität und ohne Wissen über Matrix** die App einrichten können:

1. ein Konto anlegen (oder sich mit einem bestehenden anmelden),
2. eine Familie gründen und Mitglieder einladen,
3. als Eingeladene mit einem Link oder QR-Code beitreten,

und dass dabei die Sicherheitsregeln der App gelten: nur https, Links und Serverantworten sind nicht vertrauenswürdig,
Passwörter werden nie gespeichert, ein Beitritt braucht immer die Bestätigung durch einen Moderator, der Notfall-Schlüssel
ist Pflicht.

## 2. Testumgebungen

| Kürzel | Umgebung | Zweck | Ausführung |
|---|---|---|---|
| **F** | Fake-Matrix (`test/support/fake_matrix.dart`), Widget-Tests | alle Abläufe der Oberfläche, Fehlerfälle, Texte | `flutter test` |
| **U** | Unit-Tests (Domäne, Daten mit `MockClient`) | Linkformat, Namensvorschlag, Ablaufwahl, Serverprüfung, Rücksprung | `flutter test` |
| **S** | lokaler Synapse in Docker (`tool/synapse/up.sh`), echtes Gateway, echte Kryptografie | Kontoanlage, Einladung, Beitritt gegen einen echten Server | `tool/e2e.sh` |
| **B** | Bildschirmfotos (Fake-Matrix, echte Schriften, 390 × 844 dp) | Verständlichkeit, Layout, Fachbegriffe | `tool/onboarding_screens.sh` → `build/onboarding_tour/` |
| **A** | Android-Emulator (Pixel 8, API 36), Debug-APK | Deep Links (Einladung, OAuth-Rücksprung), echte Anbietererkennung | manuell mit `adb` |
| **M** | echter Anbieter matrix.org mit Browser | Kontoanlage über die Anbieterseite (OAuth) | manuell durch eine Person |

Konventionen: Testnamen in den Testdateien beginnen mit der ID (z. B. `TP-REG-03 …`), damit Plan und Code verknüpft sind.
Ergebnis: ✅ bestanden · ❌ fehlgeschlagen · ⏳ offen (manuell, noch nicht durchgeführt).

## 3. Testfälle

### 3.1 Start und Wege

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-START-01 | frische Installation | App öffnen | „Willkommen“, drei große Wege („Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“), keine Schrittanzeige, keine Fachbegriffe | F `onboarding_test.dart`, B 01, A | ✅ |
| TP-START-02 | Startseite | „English“ tippen | Texte sofort auf Englisch, Einstellung gespeichert | F, B 24 | ✅ |
| TP-START-03 | angemeldet, abgesichert, ohne Familie | App öffnen | direkt „Schritt 3 von 3“ (Gründen/Beitreten) | F | ✅ |
| TP-START-03b | Einrichtung abgeschlossen, dann abgemeldet | App öffnen | direkt „Anmelden“, nicht die Startseite | F, `settings_screen_test.dart` | ✅ |
| TP-START-04 | „Konto erstellen“ | „Ich habe schon ein Konto“, dann „Noch kein Konto? Jetzt erstellen“, dann „Zurück“ | Benutzername wird mitgenommen; „Zurück“ führt zur Startseite | F | ✅ |

### 3.2 Konto erstellen (klassischer Anbieter)

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-REG-01 | Anbieter mit offener Registrierung | Name, Passwort, „Konto erstellen“ → Notfall-Schlüssel → Familienname → „Jetzt einladen“ | Konto angelegt, „Schritt 1/2/3 von 3“, Erfolgsansicht, Einladungsdialog, danach Hauptansicht als Moderator | F, B 02–13 | ✅ |
| TP-REG-02 | – | „Carla Groß“ eingeben | Benutzername `carla.gross` vorgeschlagen, „Der Benutzername ist frei.“ | F, U `username_suggestion_test.dart`, B 04 | ✅ |
| TP-REG-03 | `anna` vergeben | Name „Anna“ | „Schon vergeben – wie wäre es mit „anna2“?“, Knopf übernimmt den Vorschlag, „Konto erstellen“ bis dahin gesperrt | F, U, B 03 | ✅ |
| TP-REG-03b | Name wird zwischen Prüfung und Absenden vergeben | absenden | „Dieser Benutzername ist schon vergeben.“, nicht angemeldet | F `registration_test.dart`, S TP-E2E-01 | ✅ |
| TP-REG-04 | – | Passwort mit 4 Zeichen | „Konto erstellen“ gesperrt, Hinweis „Mindestens 8 Zeichen“, keine Anfrage an den Server | F, S TP-E2E-02 | ✅ |
| TP-REG-04b | – | Passwortfeld prüfen, Auge antippen | verdeckt, ohne Tastatur-Lernen; Auge zeigt es an | F | ✅ |
| TP-REG-05 | Anbieter verlangt Bedingungen | absenden | „Noch ein kurzer Schritt“, Link öffnet die Bedingungen im Browser (nur https), „Weiter“ erst nach Häkchen | F, U `registration_flows_test.dart`, B 06 | ✅ |
| TP-REG-06 | Anbieter verlangt E-Mail | ungültige, dann gültige Adresse; „Ich habe bestätigt“ vor/nach Bestätigung; erneut senden | Fehlermeldung bei ungültiger Adresse; „Noch nicht bestätigt“; nach Bestätigung angelegt; Hinweis „geht nur an den Anbieter“ | F | ✅ |
| TP-REG-06b | Adresse bereits vergeben | senden | verständliche Meldung, Schritt bleibt offen | F | ✅ |
| TP-REG-07 | Anbieter verlangt Einladungscode | falschen, dann richtigen Code | „Der Code passt nicht“, dann angelegt | F | ✅ |
| TP-REG-08 | Anbieter verlangt „kein Roboter“ | „Ich bin fertig“ zu früh; „Im Browser öffnen“, lösen, zur App zurück | Hinweis „Noch nicht abgeschlossen“; nach Rückkehr automatisch angelegt | F, B 07 | ✅ |
| TP-REG-08b | Bedingungen **und** Captcha | beide nacheinander | beide Schritte, dann angelegt | F | ✅ |
| TP-REG-09 | Registrierung abgeschaltet bzw. nur Telefon | „Neue Familie gründen“ | „kann die App kein Konto anlegen“, „Webseite öffnen“ (Hilfeseite), „Ich habe ein Konto – anmelden“ | F, U `server_probe_test.dart` | ✅ |
| TP-REG-10 | Zusatzschritt offen | „Abbrechen“ | Registrierung samt Passwort verworfen, Passwort nirgends gespeichert | F, S TP-E2E-05 | ✅ |
| TP-REG-11 | – | Konto anlegen | Anzeigename beim Anbieter gesetzt | F, S TP-E2E-01 | ✅ |
| TP-REG-12 | – | Abläufe des Servers lesen | `POST /register` ohne Benutzername/Passwort, mit `inhibit_login`; einfachster unterstützter Ablauf; Telefon/SSO nie; 429/5xx → „Erneut versuchen“ statt „kein Konto möglich“ | U | ✅ |
| TP-REG-13 | echtes Gateway | Bedingungen → Captcha, Zugangscode, Dummy-Schleife, Fehlercodes | Sitzung und erledigte Schritte werden weitergegeben; Passwort in jeder Anfrage; Captcha-Seite des Servers; falscher Code erkannt; Endlosschleife abgebrochen; M_USER_IN_USE/M_WEAK_PASSWORD/M_FORBIDDEN … richtig zugeordnet | U `sdk_registration_test.dart` | ✅ |
| TP-REG-14 | Registrierung offen | Anmelden bzw. Fehler „endgültig“ | Registrierung samt Passwort verworfen | U, F | ✅ |

### 3.3 Anbieter (Homeserver) – „Erweitert“

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-SRV-01 | – | „Neue Familie gründen“ | Anbieter automatisch geprüft („Dein Konto liegt bei …“), kein „Server prüfen“ | F, B 04 | ✅ |
| TP-SRV-02 | – | „Erweitert“ → anderer Anbieter, Adresse tippen | Prüfung nach kurzer Pause, Betreiber und Kontakt nur hier | F, B 05 | ✅ |
| TP-SRV-03 | – | `http://…` eingeben | „Bitte eine gültige https-Adresse eingeben.“ | F | ✅ |
| TP-SRV-04 | Anbieter offline | Seite öffnen, dann „Erneut versuchen“ | „… ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ ohne Rohtext; danach erreichbar | F | ✅ |

### 3.4 Anmeldung und Kontoanlage im Browser (OAuth, z. B. matrix.org)

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-OAUTH-01 | Anbieter mit Anmeldedienst | Serverprüfung | als OAuth erkannt, kein Registrierungsversuch | U, A (echtes matrix.org) | ✅ |
| TP-OAUTH-02 | OAuth-Anbieter | Name, „Konto bei … erstellen“, Rücksprung | Browser öffnet https-Seite mit `prompt=create`; Rücksprung meldet an; Name gesetzt; weiter zum Notfall-Schlüssel | F `invite_onboarding_test.dart`, B 22–23 | ✅ |
| TP-OAUTH-03 | Anmeldung läuft | Rücksprung mit fremdem `state`, danach der echte | fremder wird verworfen, es wird weiter gewartet; der echte meldet an | F, U `sdk_registration_test.dart` | ✅ |
| TP-OAUTH-08 | Anmeldung läuft | „Zurück“, dann neuer Versuch | Versuch beendet; neuer Versuch funktioniert; ein alter Versuch stört den neuen nicht | F, U `oauth_redirect_test.dart` | ✅ |
| TP-OAUTH-09 | Anbieter mit `http`-Token-Endpunkt | „Konto erstellen“ | Abbruch, bevor sich die App beim Anbieter anmeldet | U `sdk_registration_test.dart` | ✅ |
| TP-OAUTH-10 | echtes Gateway | Start und Abschluss | PKCE S256, `state`, `prompt=create`, Rücksprung nur an eigene Adresse; Token-Anfrage mit Code, Verifier, Rücksprungadresse | U `sdk_registration_test.dart` (mit vodozemac, läuft in `tool/e2e.sh`) | ✅ |
| TP-OAUTH-04 | Anmeldung läuft | „Abbrechen“ bzw. Ablehnung beim Anbieter; kein Browser vorhanden | verständliche Meldung, erneuter Versuch möglich, kein Hängen | F | ✅ |
| TP-OAUTH-05 | Konto existiert | „Ich habe schon ein Konto“ → „Bei … anmelden“ | ohne `prompt=create`, angemeldet | F | ✅ |
| TP-OAUTH-06 | Desktop | Rücksprung-Empfänger | nur `127.0.0.1`, zufälliger Port, nur `GET /oauth`, Seite enthält keinen Code, danach geschlossen | U `oauth_redirect_test.dart` | ✅ |
| TP-OAUTH-07 | Android | `io.github.carpeasrael.familynexus:/oauth?…` per Intent | erreicht die App; kein Hinweis „ungültiger Link“; andere Pfade erreichen Dart nicht | A, U `manifest_test.dart` | ✅ |
| TP-OAUTH-M1 | echtes matrix.org, Android-Gerät | Konto über „Konto bei matrix.org erstellen“ anlegen, zurück in die App, Notfall-Schlüssel, Familie gründen | Konto angelegt und angemeldet; Schlüsselsicherung gelingt | M | ⏳ (legt ein echtes Konto an – nur durch eine Person) |

### 3.5 Einladen und Beitreten

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-INV-01 | Moderatorin | Link erzeugen | `v=2` mit Familienname und Name der Einladenden; Roundtrip | U `invite_link_test.dart`, S TP-E2E-03 | ✅ |
| TP-INV-02 | alter Link `v=1` | einfügen | weiterhin gültig | U | ✅ |
| TP-INV-03 | manipulierte Links | unbekannte/doppelte Felder, `v=1` mit `f`, `v=3`, fremder Server, CRLF, Überlänge | abgelehnt | U, `penetration_test.dart` | ✅ |
| TP-INV-04 | – | Namen mit Steuer-/Bidi-Zeichen, Überlänge, leer | bereinigt, auf 40 Zeichen begrenzt, leere Namen entfallen | U | ✅ |
| TP-INV-06 | lange IDs und Namen, auch viele Emoji | Link erzeugen | passt in die Längengrenze (Namen werden notfalls gekürzt), bleibt lesbar | U | ✅ |
| TP-INV-09 | Link in anderer Schreibweise (`FamilyNexus://…`) | öffnen, Neustart | einheitlich vorgemerkt, nach Neustart weiter da | U | ✅ |
| TP-INV-07 | Moderatorin | „Jemanden einladen“ | ein Dialog mit QR-Code, „Per E-Mail senden“, „Link kopieren“; Benutzer-ID nur unter „Erweitert“ | F `family_screen_test.dart`, B 12–13 | ✅ |
| TP-INV-08 | – | „Per E-Mail senden“ | Entwurf mit Schritt-für-Schritt-Anleitung („Ich wurde eingeladen“), ohne „Matrix“; ohne Mailprogramm wird kopiert | F | ✅ |
| TP-JOIN-01 | frisches Gerät, Link geöffnet | Konto erstellen → Notfall-Schlüssel → „Beitritt anfragen“ → Bestätigung | keine Startseite, keine Serverfrage (Anbieter aus der Einladung); Beitrittskarte „Du trittst der Familie „…“ bei. Eingeladen hat dich Anna.“; Anfrage erst nach Tipp; Moderatorin sieht den Namen; nach Bestätigung automatisch Mitglied | F, S TP-E2E-03, B 14–18, A (Link-Kaltstart mit echtem matrix.org) | ✅ |
| TP-JOIN-02 | Link vorgemerkt | App neu starten | Link weiter da, direkt „Konto erstellen“; abgelaufener Link wird verworfen | F | ✅ |
| TP-JOIN-03 | bereits in einer Familie | Link öffnen | „Du bist bereits in einer Familie.“, nichts vorgemerkt | F | ✅ |
| TP-JOIN-04 | Anfrage gesendet | „Anfrage zurückziehen“ | Anfrage weg, Link-Feld wieder da | F | ✅ |
| TP-JOIN-05 | per ID eingeladen | App öffnen | Karte mit Namen; Warnung bei unerwarteter Einladung nennt die vollständige ID | F, S TP-E2E-04 | ✅ |
| TP-JOIN-06 | „Ich wurde eingeladen“ ohne Link | Link einfügen (ungültig, dann gültig), „Zurück“ | Fehlermeldung; „Schritt 2 von 4“; Zurück zum Link-Schritt | F, B 19 | ✅ |
| TP-JOIN-07 | Eingeladene mit Konto | Link öffnen, „Ich habe schon ein Konto“ | nach Anmeldung und Schlüssel die Beitrittskarte | F | ✅ |
| TP-JOIN-08 | – | Beitrittskarte „Details“, „Verwerfen“ | IDs nur unter „Details“; Verwerfen sendet nichts und vergisst den Link | F, B 16 | ✅ |
| TP-JOIN-09 | Link, dessen Einladende bei einem anderen Anbieter als die Familie liegt | Beitrittskarte | Anbieter der Einladenden immer genannt („Konto bei …“); deutliche Warnung bei Abweichung | F (Text), Code-Review | ✅ |
| TP-JOIN-M1 | zwei Android-Geräte | QR-Code mit der Kamera-App scannen | App öffnet sich bei „Konto erstellen“ | M | ⏳ (zwei echte Geräte nötig) |

### 3.5a Einladungslinks prüfen (Issue #6, E-59)

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-LINK-01 | – | abgelaufener Link | „Dieser Einladungslink ist abgelaufen. Bitte … um einen neuen Link.“ | U `invite_link_check_test.dart`, F `join_and_security_test.dart` | ✅ |
| TP-LINK-02 | – | Text ohne Link, https-Link | „Das ist kein Einladungslink …“ | U, F | ✅ |
| TP-LINK-03 | – | unvollständiger/manipulierter Link | „Der Link ist unvollständig oder beschädigt … erneut kopieren oder QR-Code scannen“ | U, F | ✅ |
| TP-LINK-04 | – | Link mit `v=3` | „… neueren Version … bitte aktualisiere die App“ | U, F | ✅ |
| TP-LINK-05 | – | `&amp;`, `<…>`, „…“, Text davor/danach, Satzzeichen, Umbruch im Link, Quoted-Printable | angenommen, bereinigt vorgemerkt; Text nach dem Link wird nicht angehängt | U, F `invite_onboarding_test.dart` | ✅ |
| TP-LINK-06 | Familie auf Server im Heimnetz (IP, localhost, Name ohne Punkt) | Link vor der Anmeldung öffnen, Konto anlegen | angenommen; Beitrittskarte warnt „Server im Heimnetz“; Anfrage erst nach Tipp | U, F, S (Synapse auf `localhost`) | ✅ |
| TP-LINK-07 | – | `via` im Heimnetz, aber nicht der Server des Raums | abgelehnt (beschädigt) | U | ✅ |
| TP-LINK-08 | Moderatorin | „Jemanden einladen“ → 1/3/7 Tage | Standard 3 Tage; andere Wahl = neuer Link; Hinweis und E-Mail nennen die Dauer | F `family_screen_test.dart`, S | ✅ |

### 3.6 Notfall-Schlüssel

| ID | Vorbedingung | Schritte | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|---|
| TP-KEY-01 | angemeldet, nicht abgesichert | App öffnen | Notfall-Schlüssel zuerst, kein Überspringen, keine Hauptansicht | F | ✅ |
| TP-KEY-02 | Schlüssel sichtbar | „Kopieren“, 61 s warten | Android: als vertraulich kopiert; Zwischenablage danach leer (im Hintergrund: beim Zurückkehren); Inhalt, den die Person inzwischen kopiert hat, bleibt | F | ✅ |
| TP-KEY-03 | Schlüssel sichtbar | „Als Datei speichern“ | Datei mit Schlüssel, Konto, Anbieter, Datum und Anleitung | F | ✅ |
| TP-KEY-04 | Schlüssel sichtbar | – | Bildschirmschutz erzwungen | F, A (Bildschirmfoto bleibt schwarz) | ✅ |
| TP-KEY-05 | zweites Gerät | falscher, dann richtiger Schlüssel; Bilder vergleichen | Fehlermeldung, dann freigeschaltet und weiter; Emoji-Vergleich über beide Geräte | F `join_and_security_test.dart`, `second_device_test.dart`, B 21 | ✅ |
| TP-KEY-06 | Anbieter verlangt Passwort | Notfall-Schlüssel erstellen | Passwortdialog; falsches Passwort scheitert | F | ✅ |

### 3.7 Querschnitt

| ID | Prüfung | Erwartet | Automatisiert in | Ergebnis |
|---|---|---|---|---|
| TP-LOGIN-01 | `@anna:anbieter` als Benutzername | Anbieter wird daraus gewählt | F | ✅ |
| TP-LOGIN-03 | `@anna:anderer.anbieter` + sofort Absenden | „Anmelden“ gesperrt, bis der Anbieter zur ID passt; Passwort nie an den bisherigen Anbieter | F | ✅ |
| TP-LOGIN-02 | falsches, dann richtiges Passwort | Meldung, dann weiter zum Notfall-Schlüssel | F | ✅ |
| TP-L10N-01 | Fachbegriffe auf dem normalen Weg | weder „Matrix“, „Homeserver“ noch `@name:server` auf Start, Konto erstellen, Notfall-Schlüssel | F `_expectNoJargon`, B | ✅ |
| TP-L10N-02 | de/en | identische Schlüssel, keine festen Texte im Code | `l10n_test.dart` | ✅ |
| TP-A11Y-01 | Statusmeldungen | Prüfergebnisse, Fehler, Warten sind Live-Regionen; Wege sind Schaltflächen | Code-Review, A (Bedienungshilfen-Baum enthält alle Texte der Wege) | ✅ |
| TP-DEV-01 | Gerätename | „FamilyNexus Linux“ usw. statt fest „Android“ | S TP-E2E-01 | ✅ |
| TP-E2E-01…05 | echter Synapse | Registrierungsweg, Name frei/vergeben, lokale Prüfungen, Link v2 → Anfrage → Bestätigung → Mitglied, Name der Einladenden, Abbruch | S `gateway_registration_e2e_test.dart` | ✅ |
| TP-REG-M1 | echte Registrierung mit Bedingungen/Captcha | Server mit `m.login.terms`/reCAPTCHA | M (lokaler Synapse verlangt beides nicht) | ⏳ |

## 4. Ergebnisprotokoll

Durchlauf am 2026-10-24 auf Branch `feature/onboarding-simple` (Manjaro Linux, Flutter 3.47.7, Dart 3.13.5).

| Stufe | Befehl | Ergebnis |
|---|---|---|
| Analyse | `flutter analyze` | ✅ keine Befunde |
| Unit/Widget (F, U) | `flutter test` | ✅ siehe Abschnitt 6 (Endstand) |
| E2E (S) | `tool/e2e.sh` | ✅ 29 von 29, davon 5 neu (TP-E2E-01…05) |
| Bildschirmfotos (B) | `tool/onboarding_screens.sh` | ✅ 24 Bilder in `build/onboarding_tour/` |
| Android (A) | Debug-APK auf Pixel 8 API 36 | ✅ Startseite, Einladungs-Deep-Link (Kaltstart) → „Create account … at matrix.org“ mit echter OAuth-Erkennung, OAuth-Rücksprung erreicht die App |
| Manuell (M) | – | ⏳ TP-OAUTH-M1, TP-JOIN-M1, TP-REG-M1 |

Bildschirmfotos (B), Zuordnung: 01 Start · 02–04 Konto erstellen (leer, vergeben, ausgefüllt) · 05 Erweitert ·
06 Bedingungen · 07 „kein Roboter“ · 08–09 Notfall-Schlüssel · 10–11 Familie benennen/fertig · 12 Einladungsdialog ·
13 Familienansicht · 14–17 Eingeladen (Konto, Beitrittskarte, Details, wartet) · 18 Moderatorin sieht die Anfrage ·
19 Link einfügen · 20 Anmelden · 21 Gerät freischalten · 22–23 OAuth · 24 Start auf Englisch.

## 5. Befunde aus der Durchführung

| Nr. | Befund | Behoben |
|---|---|---|
| D1 | Desktop-Rücksprung: Empfänger schloss, bevor der Browser die Seite „Fertig“ erhalten hatte | ✅ Seite wird erst vollständig gesendet (`oauth_redirect_test.dart`) |
| D2 | Eigener Anbieter ohne Eingabe zeigte eine endlose Ladeanzeige | ✅ Zustand „Bitte gib die Adresse ein“ |
| D3 | Einladung beim Kaltstart: Anbieterprüfung startete nicht (Ladeanzeige blieb) | ✅ `ProviderController.useStandard` startet immer beim ersten Aufruf |
| D4 | Verworfener gespeicherter Link: Einstellung wurde während des Aufbaus geändert (Framework-Fehler) | ✅ nach dem Aufbau |
| D5 | Titel doppelt (Titelleiste und Karte) bei Notfall-Schlüssel und Beitrittskarte; „Abmelden“ mitten in der Einrichtung missverständlich | ✅ Titel nur in der Titelleiste; „Anderes Konto verwenden“ |
| D6 | Captcha/E-Mail: Hauptaktion stand unter der Nebenaktion | ✅ Hauptaktion zuerst, volle Breite |
| D7 | `tool/synapse/up.sh`/`down.sh`: neue Synapse-Images legen Dateien als Container-Nutzer an (Berechtigungsfehler) | ✅ Rechte und Aufräumen über den Container |
| D8 | Android wertet `android:path` ohne Host nicht aus | dokumentiert; Pfadprüfung in `MainActivity.linkFrom` |

## 6. Review und Endstand

Separater Review-Agent (Phase 8, `docs/REVIEW.md`): 20 Funde (7 mittel, 13 niedrig, keiner hoch), alle behoben bzw.
begründet dokumentiert; neue Tests TP-OAUTH-08…10, TP-REG-13/14, TP-LOGIN-03, TP-JOIN-09, TP-INV-09.

Letzter Gesamtlauf 2026-10-24 nach den Korrekturen:

| Stufe | Ergebnis |
|---|---|
| `flutter analyze` | ✅ keine Befunde |
| `flutter test` | ✅ 600 bestanden, 33 übersprungen (E2E- und Bildschirmfoto-Gruppen ohne `FN_E2E`/`FN_SCREENSHOTS`), 0 fehlgeschlagen |
| `tool/e2e.sh` | ✅ OAuth-Gateway-Tests 12/12 (mit vodozemac), E2E 29/29 gegen Synapse |
| `tool/onboarding_screens.sh` | ✅ 24 Bildschirmfotos |
| `flutter build apk --debug` + Emulator | ✅ gebaut (inkl. neuem Kotlin-Code); Einladungs-Deep-Link führt erneut direkt zu „Create account … at matrix.org“ |

Offen (manuell, braucht echte Personen/Geräte): TP-OAUTH-M1 (Konto bei matrix.org), TP-JOIN-M1 (QR-Code mit der Kamera eines
zweiten Geräts), TP-REG-M1 (Server mit Bedingungen/reCAPTCHA).
