# Testplan Verifikation App Review 1.2.1

**Planversion: 1.0** (28.10.2026) · Dokument-ID `TP-FN-VR-121` · Reports nennen Planversion und Git-Commit (z. B. „TP-FN-VR-121 v1.0 @ 0281d70“).

Bezug: Anfrage von App Review (sechs Punkte und „Prevent Common Issues“, Wortlaut in Anhang C), `../Massnahmenplan_App_Store_Review.md` (Maßnahmen 1 bis 11), Gesamtplan `../Testplan_FamilyNexus.md` (TP-FN-001 v1.6), Review-Notizen `store/metadata/ios/review_notes.txt` bzw. `store/metadata/macos/review_notes.txt`, `docs/STORE.md` (Abschnitt 4), `docs/export-compliance/`, Issue #15.
Soll-Version: `version:` in `pubspec.yaml` auf aktuellem `main` (beim Schreiben **1.2.1+19** = „1.2.1 (20)“). Maßgeblich ist der Build, der in App Store Connect zur Prüfung eingereicht ist bzw. wird.

## 1. Ziel und Aufbau

Dieser Plan weist nach, dass die Antwort an App Review **vollständig, zutreffend und zum eingereichten Build passend** ist, bevor sie abgeschickt und in „App Review Information → Notes“ hinterlegt wird. Er ersetzt den Gesamtplan nicht: Die Funktionsprüfung des Builds (Guideline 2.1) läuft weiter nach TP-FN-001; dieser Plan prüft deren Ergebnis nur ab (Abschnitt 5).

| Abschnitt | Inhalt | Apple-Punkt |
|---|---|---|
| 2 | Festlegung von Geräten, Konten und Build (vor Testbeginn ausfüllen) | – |
| 3 | Vorbereitung: Build, Betriebssystem, Prüfkonten, Beispieldaten, Aufnahmegerät | 1, 3 |
| 4 | Bildschirmaufnahme: Drehbuch und Prüfung des Videos | 1 |
| 5 | Funktionsprüfung des Builds auf physischen Geräten | 1, 2.1 |
| 6 | Antworttexte zu den Punkten 2 bis 6 gegen App und Code prüfen | 2–6 |
| 7 | „Prevent Common Issues“ (Guidelines 2.1, 2.3.3, 3.1.1, 3.2) | – |
| 8 | Hinterlegen in App Store Connect und Konsistenzprüfung | alle |
| 9 | Abnahme und Report | – |
| Anhang A | Entwurf der Antwort (Englisch) | 2–6 |
| Anhang B | Zuordnung Apple-Punkte → Schritte | – |
| Anhang C | Wortlaut der Anfrage | – |

Jede Zeile hat die Spalten „Beobachtet“, „Nachweis“ (Screenshot, Videostelle `mm:ss` oder Log) und „Erg.“. Der Tester füllt sie in einer Kopie dieses Plans aus. Diese Kopie ist der Report.

Ergebnisse: ✅ bestanden · ⚠️ bestanden mit Befund · ❌ fehlgeschlagen · ⏳ offen (mit Grund) · n/a (mit Grund)

## 2. Festlegung (Pflicht, vor dem ersten Schritt)

| Angabe | Wert |
|---|---|
| Aufnahmegerät G1: **physisches iPhone** (Modell) | |
| iOS-Version G1 (muss die neueste veröffentlichte sein, V-03) | |
| Gerät G2 für das zweite Mitglied (iPhone, Mac oder anderes Gerät mit FamilyNexus) | |
| Mac G3 (nur wenn die macOS-App eingereicht ist): Modell, macOS-Version | |
| Eingereichte Plattformen in App Store Connect (iOS / macOS) | |
| Soll-Build (aus V-01) und Build in App Store Connect (aus V-02) | |
| Installationsquelle G1 (TestFlight, Build-Nummer) | |
| Prüfkonto Moderator (`R1`, matrix.org): Benutzername (ohne Passwort) | |
| Prüfkonto Mitglied (`R2`, matrix.org): Benutzername (ohne Passwort) | |
| Wegwerfkonto für die Video-Szene Registrierung/Löschung (`W1`, matrix.org) und Test-Postfach dafür | |
| Tester / Datum / Uhrzeit Beginn | |

**Vorgaben:**
- Das Video entsteht auf **G1 = physisches iPhone** mit dem TestFlight-Build, der eingereicht wird. Ein Simulator ist für das Video nicht zulässig.
- Ist auch die macOS-App eingereicht, wird Abschnitt 4 zusätzlich auf G3 aufgenommen (eigene Datei, Bildschirmaufnahme mit ⇧⌘5).
- Das Video folgt dem Weg, den die Review-Notizen beschreiben: Anbieter **matrix.org** mit Anmeldung und Kontoanlage im Browser (account.matrix.org). Eigene Testserver kommen im Video nicht vor.
- Passwörter, Notfall-Schlüssel und Postfach-Zugänge stehen nur im Passwortmanager bzw. in `../../secure/` (von Git ignoriert), nie in diesem Plan oder im Report.

**Rollen der Prüfkonten:** Die App kennt zwei Rollen in einer Familie, **Moderator** und **Mitglied**. Guideline 2.1 verlangt bei mehreren Kontoarten Zugangsdaten für jede Art. Deshalb gibt es zwei Prüfkonten:

| Kürzel | Rolle | Familie | Zweck |
|---|---|---|---|
| R1 | Moderator | Beispielfamilie | Hauptkonto für App Review („Sign-in information“) |
| R2 | Mitglied | dieselbe Beispielfamilie | zweite Kontoart; schreibt die Nachricht, die im Video gemeldet und blockiert wird |
| W1 | – (wird im Video angelegt und gelöscht) | eigene Familie, nur im Video | Nachweis Registrierung und Kontolöschung |

## 3. Vorbereitung (vor jedem Lauf, Ergebnis im Report)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtet | Nachweis | Erg. |
|---|---|---|---|---|---|---|
| V-01 | – | **Soll-Version:** `git fetch origin && git status -sb`; `grep '^version:' pubspec.yaml`; `grep -n 'appVersion\|appBuild' lib/app/app_version.dart`; Commit notieren | Version und Build stimmen in `pubspec.yaml` und `app_version.dart` überein (z. B. `1.2.1+19`); in Abschnitt 2 eintragen | | – (Ausgabe) | |
| V-02 | – | **Build in App Store Connect:** App → iOS (bzw. macOS) → Version 1.2.1 → „Build“; TestFlight → Builds | Der der Version zugeordnete Build ist der Soll-Build; Status „Bereit zum Testen“ bzw. eingereicht; keine Exportfragen offen. Bei Abweichung: höheren Build bauen (`tool/build_ios_release.sh`), hochladen, V-01 wiederholen | | V-02.png | |
| V-03 | G1 | **Neuestes Betriebssystem:** Einstellungen → Allgemein → Softwareupdate; danach Einstellungen → Allgemein → Info | „iOS ist auf dem neuesten Stand“; Version mit der aktuellen Version auf apple.com/ios vergleichen; Version in Abschnitt 2 eintragen. Beta-Versionen gelten **nicht** als neuestes Betriebssystem | | V-03a-G1, V-03b-G1 | |
| V-04 | G1 | **App aus TestFlight installieren:** TestFlight → FamilyNexus → Soll-Build → „Installieren“. Liegt eine ältere Version vor: erst in der App Einstellungen → „Alle lokalen Daten löschen“, dann aktualisieren | TestFlight zeigt den Soll-Build als installiert | | V-04-G1 | |
| V-05 | G1 | **Lokale Daten leer:** App starten; zeigt sie nicht „Willkommen“: Einstellungen → „Alle lokalen Daten löschen“ → „Endgültig löschen“; App beenden (App-Umschalter, nach oben wischen) | Nach dem Neustart „Willkommen bei FamilyNexus“ mit drei Wegen. Danach App **beenden**, damit die Aufnahme mit dem Start beginnt | | V-05-G1 | |
| V-06 | G1 | **Version in der App:** vor V-05 oder auf G2 mit demselben Build: Menü unten bzw. Einstellungen → „Über die App“ | „Version 1.2.1 (20)“ = Soll | | V-06-G1 | |
| V-07 | G2 | **Prüfkonto R1 funktioniert:** auf G2 „Ich habe schon ein Konto“ → „Bei matrix.org anmelden“ → Browser → R1 → zurück → „Dieses Gerät freischalten“ → Notfall-Schlüssel aus den Review-Notizen (Platzhalter-Ersatz, nur lokal) → „Freischalten“ | Anmeldung ohne Rückfrage; Hauptansicht mit Beispielfamilie; R1 ist Moderator. Schlägt der Schlüssel fehl: neuen Notfall-Schlüssel erstellen (Einstellungen → „Notfall-Schlüssel und Geräte“) und in der Antwort/den Notizen aktualisieren | | V-07-G2 | |
| V-08 | G2 | **Beispieldaten vollständig** (als R1): Tab „Familie“, „Heute“, Kalender, Chat, Einkauf, Menü → „Aufgaben“ | Familie mit R1 (Moderator) und R2 (Mitglied); mindestens: ein geteilter Termin in den nächsten 7 Tagen, ein wiederkehrender Termin, Chatverlauf mit Nachrichten von beiden, Einkaufsliste mit offenen und erledigten Einträgen, eine Aufgabenliste. Fehlendes ergänzen | | V-08a-G2 … V-08e-G2 | |
| V-09 | G2 | **Prüfkonto R2 funktioniert:** auf G2 abmelden, R2 anmelden wie V-07 (eigener Notfall-Schlüssel von R2) → Tab „Familie“ | R2 ist Mitglied (kein „Mitglied einladen“, „Nur Moderatoren verwalten die Familie.“); Familie und Daten sichtbar | | V-09-G2 | |
| V-10 | G2 | **Nachricht für die Melde-Szene:** als R2 im Familienchat `Test message for App Review` senden; R2 angemeldet lassen | Nachricht erscheint; sie wird in Szene S-11 gemeldet und blockiert | | V-10-G2 | |
| V-11 | G2 | Als R1: Einstellungen → „Blockierte Mitglieder“ | „Du hast niemanden blockiert.“ (sonst Blockierung aufheben) | | V-11-G2 | |
| V-12 | – | **Wegwerfkonto W1 vorbereiten:** Test-Postfach erreichbar (E-Mail-Bestätigung bei matrix.org); Benutzername für W1 festlegen (z. B. `fn-review-demo-MMTT`) und im Browser auf account.matrix.org prüfen, dass er frei ist | Postfach empfängt Mails; Name frei. Persönliche Postfächer nicht verwenden, die Adresse ist im Video zu sehen | | – | |
| V-13 | G1 | **Aufnahmegerät einrichten:** Fokus „Nicht stören“ an (keine fremden Mitteilungen im Video); Bildschirmaufnahme im Kontrollzentrum hinzufügen, Mikrofon aus; Safari auf G1 bei matrix.org **abgemeldet** (sonst schlägt die Seite ein anderes Konto vor); Akku > 50 %; Hintergrundbild ohne persönliche Inhalte; Gerätesprache Englisch (Video für App Review) | Alles erfüllt; Gerätesprache notiert | | V-13-G1 | |
| V-14 | G1 | Benachrichtigungen für FamilyNexus **nicht** vorab erlauben (die Freigabe wird im Video gezeigt) | Einstellungen → Mitteilungen: FamilyNexus nicht vorhanden oder „Nicht festgelegt“ | | – | |

## 4. Bildschirmaufnahme (Apple-Punkt 1)

### 4.1 Drehbuch

Eine **zusammenhängende** Aufnahme auf G1, ohne Schnitt. Sie beginnt auf dem Home-Bildschirm mit dem Antippen des App-Symbols. Die Szenen laufen in dieser Reihenfolge. Pausen über 10 s (z. B. beim Warten auf die E-Mail) sind erlaubt, die Aufnahme läuft dabei weiter. Für jede Szene trägt der Tester die Videostelle (`mm:ss`) ein.

| ID | Szene | Bedienung auf G1 | Im Video sichtbar | Videostelle | Erg. |
|---|---|---|---|---|---|
| S-01 | **App-Start** | Aufnahme starten (Kontrollzentrum) → Home-Bildschirm → FamilyNexus-Symbol antippen | Kaltstart; „Welcome to FamilyNexus“ mit drei Wegen, Hinweise zu Datenschutz und Verschlüsselung | | |
| S-02 | **Registrierung (W1)** | „Start a new family“ → „What is your name?“: `Review Demo` → „Create account at matrix.org“ → Browser: Konto W1 mit Test-Postfach anlegen (Bedingungen, Captcha und E-Mail-Bestätigung des Anbieters) → zurück zur App | Kontoanlage beim Anbieter; App übernimmt automatisch („Step 2 of 3“) | | |
| S-03 | **Notfall-Schlüssel** | „Create emergency key“ → Häkchen „I have stored the emergency key safely.“ → „Next“ | Schlüssel wird angezeigt (Wegwerfkonto, darf sichtbar sein); „Next“ erst nach dem Häkchen aktiv | | |
| S-04 | **Familie gründen** | Name `Demo family` → „Create family“ → „Later“ | „Done! …“; Hauptansicht „Today“ | | |
| S-05 | **Benachrichtigungen** | Hinweis „Notifications are blocked“ → „Allow“ → Systemdialog → „Allow“ | Systemdialog, danach Hinweis weg | | |
| S-06 | **Typischer Ablauf (W1)** | Kalender → „New event“ → `Dentist`, morgen 10:00, „Shared“ → „Save“; Chat → `Hello family` → „Send“; Einkauf → `Milk` → „Add“ → abhaken; Menü → „Tasks“ (nur ansehen) | Termin mit „Shared“, Nachricht mit Uhrzeit, Eintrag unter „Done“ | | |
| S-07 | **Version** | Menü öffnen → unten „Version …“ ablesen | „Version 1.2.1 (20)“ = eingereichter Build | | |
| S-08 | **Kontolöschung (W1)** | Menü → Settings → Account → „Delete account“ → Dialog lesen → weiter zur Löschseite von matrix.org → Löschung bestätigen → zurück zur App | Dialog „Delete account?“; Löschseite des Anbieters; danach „Welcome“ (lokale Daten gelöscht) | | |
| S-09 | **Anmeldung (R1)** | „I already have an account“ → „Sign in at matrix.org“ → Browser: R1 (Passwort tippen, es erscheint als Punkte) → „Continue“ → „Unlock this device“ → Notfall-Schlüssel R1 einfügen → „Unlock“ | Anmeldung wie in den Review-Notizen; Hauptansicht mit Beispielfamilie und Beispieldaten | | |
| S-10 | **Beispielfamilie (R1)** | „Today“ ansehen; Tab „Family“ (R1 Moderator, R2 Mitglied); Kalender „Week“; Chat | Daten aus V-08; Rollen sichtbar | | |
| S-11 | **Nutzerinhalte: melden** | Chat → Nachricht von R2 aus V-10 lange drücken → „Report message“ → Grund „Spam or advertising“, Text `Review demo, please ignore` → „Report“ | Dialog mit Hinweis auf den Serverbetreiber und vier Gründen; „Report sent.“ mit „Block sender“ | | |
| S-12 | **Nutzerinhalte: blockieren** | „Block sender“ (oder Nachricht lange drücken → „Block <R2>“) → „Block“ | „<R2> is blocked.“; Nachrichten von R2 ausgeblendet; im Tab „Family“ Status „Blocked“ | | |
| S-13 | **Blockierung aufheben** | Settings → „Blocked members“ → „Unblock“ | Nachrichten von R2 wieder sichtbar (Prüfkonto bleibt nutzbar) | | |
| S-14 | **Moderation (nur zeigen)** | Tab „Family“ → Menü bei R2 öffnen → Einträge zeigen („Remove“, „Make moderator“, „Block“) → schließen, **nichts ausführen** | Moderator kann Mitglieder entfernen | | |
| S-15 | **Ende** | Aufnahme im Kontrollzentrum beenden | – | | |

**Nicht enthalten, weil nicht vorhanden:** kostenpflichtige Inhalte oder Funktionen (keine In-App-Käufe, kein Abo). In der Antwort ausdrücklich nennen (Anhang A, Punkt 1).

**Hinweis zu S-11:** Die Meldung geht an den Betreiber von matrix.org. Der Text `Review demo, please ignore` kennzeichnet sie als Test.

### 4.2 Prüfung des Videos

| ID | Prüfung | Erwartetes Ergebnis | Beobachtet | Erg. |
|---|---|---|---|---|
| K-01 | Beginn | Erste Sekunden: Home-Bildschirm, Antippen des App-Symbols (S-01), kein Schnitt davor | | |
| K-02 | Vollständigkeit | S-01 bis S-14 enthalten; Registrierung, Anmeldung, Kontolöschung, Melden, Blockieren erkennbar | | |
| K-03 | Build | S-07 zeigt die Build-Nummer aus V-02 lesbar | | |
| K-04 | Physisches Gerät | Statusleiste des echten Geräts (Uhrzeit, Netz, Akku), keine Simulator-Rahmen; Gerät und iOS-Version aus V-03 im Report | | |
| K-05 | Datenschutz | Keine Passwörter im Klartext, kein Notfall-Schlüssel von R1 lesbar (falls doch: Szene neu aufnehmen, nicht schwärzen, damit das Video ungeschnitten bleibt), keine fremden Mitteilungen, keine persönlichen Daten außer Test-Postfach | | |
| K-06 | Lesbarkeit | Hochformat, Text lesbar, kein Ruckeln; Länge notieren | Länge: ____ | |
| K-07 | Übertragung | Datei als Anhang in der Antwort in App Store Connect hochladbar (Format `.mov`/`.mp4`, Größe notieren). Geht das nicht: Upload an einen Ort, der **ohne Anmeldung und ohne Freigabeanfrage** abrufbar ist; Link in einem privaten Browserfenster testen | | |
| K-08 | Nachher | W1 gelöscht: Anmeldung mit W1 bei account.matrix.org scheitert. R1 und R2 weiter nutzbar (V-07, V-09 kurz wiederholen); R2 nicht blockiert | | |
| K-09 | macOS (nur falls eingereicht) | Gleiche Prüfungen für die Aufnahme auf G3; „click and hold“ statt lange drücken | | |

Ablage: `Test-Apple-Report/<Lauf-Ordner>/video/FamilyNexus_1.2.1_<Build>_iPhone.mov` (nicht in Git, falls größer als 50 MB: nur Prüfsumme und Ablageort im Report).

## 5. Funktionsprüfung des Builds auf physischen Geräten (Guideline 2.1)

| ID | Gerät | Schritt | Erwartetes Ergebnis | Beobachtet | Nachweis | Erg. |
|---|---|---|---|---|---|---|
| F-01 | G1 (+ G3) | **Gesamtplan TP-FN-001 v1.7** mit dem Soll-Build: G1 = physisches iPhone (TestFlight), G2 = Mac (falls eingereicht, sonst zweites Gerät) | Report mit Ergebnis „bestanden“ liegt vor (Ordner nennen); offene ⚠️ als Issues; kein ❌, kein ⏳ | | Report-Ordner | |
| F-02 | G1 | **Review-Notizen am Gerät** (= TP-FN-001 G-06) mit dem Text aus App Store Connect, nicht aus dem Repository | Jeder Schritt der Notizen ist auffindbar und funktioniert mit R1 | | F-02-G1 | |
| F-03 | – | `flutter test test/store/review_notes_test.dart` | Grün | | Log | |
| F-04 | – | TestFlight → Soll-Build → „Abstürze“ bzw. Xcode Organizer → Crashes | Keine Absturzberichte aus den Läufen F-01, F-02 und Abschnitt 4 | | Screenshot | |
| F-05 | G1 | **Kaltstart ohne Netz:** Flugmodus an → App starten → wieder online | Kein Absturz; Daten lokal sichtbar; nach dem Wiederverbinden Synchronisation | | F-05-G1 | |
| F-06 | G1 | **Gerätesprache Deutsch, Englisch und eine dritte (z. B. Französisch):** App starten | Deutsch bzw. Englisch; bei nicht unterstützter Sprache Englisch, keine leeren Texte (Grundlage für Punkt 5) | | F-06a … c-G1 | |

## 6. Antworttexte zu den Punkten 2 bis 6

Der Entwurf steht in Anhang A. Jede Aussage wird gegen App, Code oder Unterlagen geprüft. Stimmt eine Aussage nicht, wird der **Entwurf** korrigiert, nicht die Prüfung.

| ID | Punkt | Prüfung | Erwartetes Ergebnis | Beobachtet | Erg. |
|---|---|---|---|---|---|
| T-01 | 2 Zweck | Entwurf gegen `store/metadata/ios/en-US/description.txt` und den Funktionsumfang des Builds (Abschnitt 4/5) | Jede genannte Funktion ist im Build vorhanden; keine angekündigte, aber nicht umgesetzte Funktion (z. B. **kein** Familienspeicher/Nextcloud, E-74 ist nicht umgesetzt) | | |
| T-02 | 2 Zielgruppe | Zielgruppe gegen Altersfreigabe in App Store Connect und den Hinweis zu Kindern in der App (Familie gründen) | Konsistent: Konten legen Erwachsene an; Kinder nur über Einladung eines Moderators; Altersfreigabe aus App Store Connect übernommen | | |
| T-03 | 3 Einrichtung | Anleitung in Anhang A gegen F-02 und S-09 | Schritte und Beschriftungen stimmen wörtlich mit der App (englische Oberfläche) | | |
| T-04 | 3 Zugangsdaten | R1 in „Sign-in information“; R2 (Benutzername, Passwort, Notfall-Schlüssel) in den Notizen; Notfall-Schlüssel R1 ersetzt den Platzhalter | Beide Konten in V-07/V-09 erfolgreich; Daten im Report **nicht** wiedergegeben, nur „geprüft am …“ | | |
| T-05 | 3 Beispieldateien | Werden Dateien gebraucht? | Nein; Anhänge im Chat sind optional (beliebiges Foto). Aussage im Entwurf | | |
| T-06 | 4 Externe Dienste | `sed -n '/^dependencies:/,/^dev_dependencies:/p' pubspec.yaml`; `grep -rhoE 'https?://[a-zA-Z0-9./_-]+' lib \| sort -u`; `grep -rniE 'pusher\|apns\|analytics\|firebase\|sentry\|purchase' lib pubspec.yaml` | Liste in Anhang A vollständig: Matrix-Server (Standard matrix.org) inkl. Kontodienst account.matrix.org, GitHub Pages (Einladungsseite, Datenschutzerklärung), Element-Downloadseite (nur Verweis), Systemdienste von Apple (lokale Mitteilungen, Schlüsselbund, Face ID/Touch ID, Mail). **Keine** Push-, Analyse-, Werbe-, Zahlungs- oder KI-Dienste; Treffer der letzten Suche = 0 | | |
| T-07 | 4 Gegenprobe | Netzwerkverbindungen während S-01 bis S-14 (optional: Mac mit Proxy/„Little Snitch“ oder iPhone-Datenschutzbericht „App-Netzwerkaktivität“, Einstellungen → Datenschutz → App-Datenschutzbericht) | Nur Domains aus T-06 (matrix.org-Domains, carpeasrael.github.io) | | |
| T-08 | 5 Regionen | F-06; App Store Connect → Preise und Verfügbarkeit (Länderliste); `docs/export-compliance/README.md` (Frankreich) | Funktionen in allen Regionen gleich; Sprachen DE/EN, sonst Englisch; Länder, in denen die App **nicht** angeboten wird (z. B. Frankreich ohne Verschlüsselungserklärung), stehen im Entwurf | | |
| T-09 | 6 Regulierung | Prüfen: Gesundheit, Finanzen, Glücksspiel, Kinder-Kategorie, Behörden, geschütztes Material Dritter (Musik, Videos, Marken) | Trifft nicht zu; Entwurf sagt das ausdrücklich. Verschlüsselung: Verweis auf die Exportunterlagen in App Store Connect; Open-Source-Lizenzen (AGPL-3.0) genannt | | |
| T-10 | 6 Lizenz | `docs/OFFEN.md` Punkt AGPL ↔ App-Store-Bedingungen | Entscheidung des Herausgebers dokumentiert; Aussage im Entwurf passt dazu | | |

## 7. Prevent Common Issues

| ID | Guideline | Prüfung | Erwartetes Ergebnis | Beobachtet | Erg. |
|---|---|---|---|---|---|
| P-01 | 2.1 Fehler und Abstürze | F-01 bis F-05 auf **jeder eingereichten Plattform** auf echter Hardware über TestFlight | Alle ✅; macOS-Build über TestFlight für Mac auf einem echten Mac geprüft (falls eingereicht) | | |
| P-02 | 2.1 Zugang | „Sign-in information“ in App Store Connect enthält R1; „Sign-in required“ angehakt; R2 in den Notizen; Prüfung am Tag der Einreichung (V-07, V-09) | Zugangsdaten aktuell, beide Rollen abgedeckt | | |
| P-03 | 2.3.3 Screenshots | Jeden Screenshot der App-Store-Seite (6,9″ und 6,3″, de-DE und en-US; `store/screenshots/ios/`) ansehen und mit dem Build vergleichen | Jeder zeigt die App im Gebrauch (Heute, Kalender, Chat, Einkauf, Familie …), **kein** Titelbild, Startbildschirm oder Anmeldeseite; Oberfläche entspricht dem Build (Beschriftungen, Tabs) | | |
| P-04 | 3.1.1 In-App-Kauf | App Store Connect → „In-App-Käufe“ und „Abonnements“; `grep -rni 'in_app_purchase\|StoreKit' lib ios macos pubspec.yaml` | Keine Produkte, keine Treffer; App ist kostenlos (Preis in App Store Connect notieren) | | |
| P-05 | 3.2 Geschäftsmodelle | Vertriebsweg in App Store Connect | Öffentlicher App Store; Zielgruppe sind Familien allgemein, nicht ein bestimmtes Unternehmen oder dessen Beschäftigte → kein Custom-App-/Unlisted-Vertrieb nötig | | |

## 8. Hinterlegen in App Store Connect

| ID | Schritt | Erwartetes Ergebnis | Beobachtet | Erg. |
|---|---|---|---|---|
| H-01 | **Länge der Notizen:** Notizen = Antwort aus Anhang A + englischer Teil von `review_notes.txt` (Platzhalter ersetzt) + Zugangsdaten R2. Zeichen zählen (`wc -m`) | ≤ 4000 Zeichen (Grenze des Felds). Die bisherigen Notizen haben allein schon 3519 Zeichen (DE + EN); deshalb in den Notizen **nur den englischen Teil** verwenden und Anhang A dort in der Kurzfassung. Die vollständige Fassung geht in die Antwort | Zeichen: ____ | |
| H-02 | Antwort an App Review (Resolution Center): Anhang A vollständig, Video als Anhang bzw. Link (K-07) | Alle sechs Punkte beantwortet, Punkt 1 mit Video, nicht zutreffende Teile ausdrücklich benannt | | |
| H-03 | Notizen in „App Review Information“ speichern | Gespeichert; nach dem Neuladen der Seite noch vorhanden | | |
| H-04 | **Konsistenz:** Build in V-02 = S-07 = Notizen = Antwort; Zugangsdaten in Notizen = V-07/V-09; Beschriftungen in Notizen = App (F-02) | Alles gleich. Wurde nach dem Video ein neuer Build nötig: Abschnitt 4 und F-02 mit dem neuen Build wiederholen | | |
| H-05 | `store/metadata/ios/review_notes.txt` (bzw. `macos/`) im Repository auf den eingereichten Stand bringen (ohne Geheimnisse), `flutter test test/store/review_notes_test.dart` | Grün; Platzhalter `<EMERGENCY KEY OF THE REVIEW ACCOUNT>` bleibt im Repository | | |
| H-06 | Checkliste aus `../Massnahmenplan_App_Store_Review.md` („Checkliste vor dem Absenden“) abhaken | Alle Punkte erfüllt | | |

## 9. Abnahme und Report

**Bestanden**, wenn Abschnitt 2 vollständig ist, V-01 bis V-14, alle Szenen S-01 bis S-14, K-01 bis K-08, F-01 bis F-06, T-01 bis T-10, P-01 bis P-05 und H-01 bis H-06 ✅ oder begründet „n/a“ sind. ⚠️ nur mit Issue und nur, wenn der Befund weder im Video noch beim Weg aus den Review-Notizen auftritt. Erst danach wird die Antwort abgeschickt (H-02).

**Report:** Kopie dieses Plans mit ausgefüllten Spalten als `Test-Apple-Report/<JJJJ-MM-TT>_<NN>_Verifikation_iPhone_Build<NN>/Testreport.md` (Benennung nach `Test-Apple-Report/README.md`), dazu `screenshots/`, `logs/`, Videoablage (K-07) und die tatsächlich abgeschickte Antwort als `Antwort_App_Review.md` (ohne Passwörter und Schlüssel). Eintrag in der Tabelle von `Test-Apple-Report/README.md`.

## Anhang A: Entwurf der Antwort an App Review (Englisch)

Platzhalter in `<…>` beim Ausfüllen ersetzen; Aussagen sind in Abschnitt 6 zu prüfen.

```text
1. Screen recording
Attached: FamilyNexus_1.2.1_<BUILD>_iPhone.mov – recorded on an <IPHONE MODEL> running iOS <VERSION> with build 1.2.1 (<BUILD>) from TestFlight. It starts with launching the app and shows: account registration (at the default provider matrix.org, in the browser), emergency key, creating a family, calendar, chat and shopping list, account deletion, sign-in with the review account, reporting a message, blocking and unblocking a member, and the moderator's member menu.
The app has no paid content, no in-app purchases and no subscriptions.

2. Purpose and target audience
FamilyNexus is a private family organizer for households: a shared family calendar, family and direct chat, a shared shopping list and recurring task lists. Families today coordinate across several apps and hand their schedules and messages to large central providers. FamilyNexus brings these functions together in one app and keeps the content end-to-end encrypted on the open Matrix protocol, so neither we nor the server operator can read it. Private events stay on the user's own devices. There are no ads, no tracking and no analytics.
Target audience: families and households. Accounts are created by adults; children can only join a family when a moderator invites them.

3. Setup and access
See "Sign-in information" for the review account (role: moderator of a sample family with sample data). A second account with the role "member" is listed below.
Steps: Welcome → "I already have an account" → "Sign in at matrix.org" (browser) → enter user name and password → "Continue" → back in the app "Unlock this device" → enter the emergency key → "Unlock". Main view: Today, Calendar, Chat, Shopping, Family.
Member account: user <R2 USER NAME>, password <R2 PASSWORD>, emergency key <R2 KEY>.
No sample files are needed. Any photo can be used to try attachments in the chat.

4. External services
- Matrix homeserver chosen by the user (default: matrix.org, operated by The Matrix.org Foundation): accounts, sign-in and account deletion (account.matrix.org in the browser), end-to-end encrypted messaging and synchronisation. Users can choose any other Matrix server.
- GitHub Pages (carpeasrael.github.io): web page that opens invitation links in the app; privacy policy.
- element.io/download: link only (download page of a Matrix client, shown as a hint).
- Apple system services on the device: local notifications for reminders, Keychain, Face ID/Touch ID for the optional app lock, Mail for sending invitations.
We do not use push, analytics, advertising, payment or AI services, and we operate no server of our own.

5. Regional differences
The app works the same in all regions. The user interface is available in English and German (English for all other device languages). <IF APPLICABLE: The app is not offered in <COUNTRIES> (<REASON>).>

6. Regulated industries and third-party material
Not applicable: the app does not operate in a regulated industry and contains no protected third-party content. It uses standard encryption (Olm/Megolm via vodozemac, SQLCipher, TLS); the export compliance documentation is provided in App Store Connect. The app is free software under AGPL-3.0; third-party libraries are used under their open-source licences.
```

## Anhang B: Zuordnung Apple-Punkte → Schritte

| Apple-Punkt | Schritte |
|---|---|
| 1 Video auf physischem Gerät, neuestes OS, beginnt mit App-Start | V-03 bis V-05, V-13, S-01 bis S-15, K-01 bis K-09 |
| 1 Registrierung, Anmeldung, Kontolöschung | S-02, S-08, S-09, K-08 |
| 1 Nutzerinhalte mit Melden und Blockieren | V-10, V-11, S-11 bis S-14 |
| 1 Kostenpflichtige Inhalte | entfällt (P-04), in der Antwort genannt |
| 2 Zweck und Zielgruppe | T-01, T-02 |
| 3 Einrichtung, Zugangsdaten, Beispieldateien | V-07 bis V-09, F-02, T-03 bis T-05 |
| 4 Externe Dienste | T-06, T-07 |
| 5 Regionale Unterschiede | F-06, T-08 |
| 6 Regulierung, geschütztes Material | T-09, T-10 |
| Antwort und Notizen | H-01 bis H-06 |
| Guideline 2.1 Fehler/Abstürze, Zugang | F-01 bis F-05, P-01, P-02 |
| Guideline 2.3.3, 3.1.1, 3.2 | P-03, P-04, P-05 |

## Anhang C: Wortlaut der Anfrage (Auszug)

> Reply in App Store Connect with all of the following information and also add this information to the Notes field of the App Review Information section in App Store Connect, for reference on future submissions:
> 1. A screen recording captured on a physical device, running the latest operating system, demonstrating the app's functionality. The recording must begin with launching the app and show the typical user flow. If the app has any of the following, include them in the recording: account registration, login, and account deletion flows (account deletion is required in apps that support account creation); any user-generated content, including the required content reporting and blocking mechanisms; accessing paid content or features within the app.
> 2. A description of the app's purpose and target audience, including the problem it solves and the value it provides
> 3. Instructions for setting up and accessing the app's main features, including any required login credentials or sample files
> 4. A list of the external services, tools, or platforms the app uses to deliver its core functionality
> 5. Describe any regional differences in the app's features or content, or confirm that the app functions consistently across all regions
> 6. If the app operates in a highly regulated industry or includes protected third-party material, provide any relevant documentation or credentials
>
> Prevent Common Issues: Guideline 2.1 (bugs and crashes; accessing the app, credentials for each account type), 2.3.3 (screenshots), 3.1.1 (In-App Purchase), 3.2 (other business models).

## Versionshistorie

| Version | Datum | Commit | Änderung |
|---|---|---|---|
| 1.0 | 28.10.2026 | – | Erstfassung für die Antwort auf die Anfrage von App Review zu Version 1.2.1 |
