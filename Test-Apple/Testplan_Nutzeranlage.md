# Testplan Nutzeranlage (Konto erstellen)

Bezug: E-55 (Kontoanlage in der App), E-70 (Anbietervorschlag), Issue #10 (Notfall-Schlüssel beim neuen Konto), Issue #12 (Konto löschen, zum Aufräumen)
Build: Soll-Version laut `pubspec.yaml` auf `main` (beim Schreiben **1.2.1 (16)**), Prüfung in TV-01 · Stand: 26.10.2026
Gemeinsame Vorprüfung, Stammdaten und Reihenfolge: **`Testdaten_Stammdaten.md`** (zuerst lesen)

## 0. Testserver und Testuser

| Angabe | Wert |
|---|---|
| Anbieter-Adresse (in der App eingeben) | `matrix-synapse-3ues.srv1348446.hstgr.cloud` |
| Servername in den Matrix-IDs | `matrix.chaostribunal.de` → IDs lauten `@<name>:matrix.chaostribunal.de` |
| Anmeldung | Benutzername + Passwort in der App (kein OAuth, kein Browser) |
| Registrierung | muss für TN-01 bis TN-17 **offen** sein (`m.login.dummy`); TN-18 prüft den geschlossenen Zustand |

**Besonderheiten dieses Servers:**
- Die App schlägt immer `matrix.org` vor (E-70). Vor jeder Kontoanlage und Anmeldung unter **„Erweitert“ → „Anderen Anbieter verwenden“** die Anbieter-Adresse eintragen.
- Beim Anmelden **nur den kurzen Benutzernamen** eingeben (`fnt-…`), nie die vollständige ID – `matrix.chaostribunal.de` ist nicht erreichbar.
- Bei matrix.org wird in diesem Test **kein** Konto angelegt (TN-02 bricht vor dem Browser ab).

**Testuser – werden im Test angelegt** (Namensschema mit Datum `MMTT`, z. B. `fnt-1027-n1`):

| Kürzel | Benutzername | Zweck | angelegt in | gelöscht in |
|---|---|---|---|---|
| **N1** | `fnt-MMTT-n1` | Hauptkonto, Familie F1 „Testfamilie MMTT“; wird in den anderen Plänen **wiederverwendet** | TN-09 | Einladung TI-27 |
| **N2** | `fnt-MMTT-n12` (Vorschlag der App) | Konto über den Ausweichvorschlag, Familie F2 „Löschtest MMTT“; wird in Prüfanleitung TC-16 gelöscht | TN-15 | Prüfanleitung TC-16 |

Passwörter erzeugt der Tester beim Anlegen (mind. 8 Zeichen, Passwortmanager) und trägt sie **nicht** in diesen Plan ein; im Report maskiert. Notfall-Schlüssel (KN1, KN2) ebenso nur im Passwortmanager. Die Konten werden **nicht** am Ende dieses Plans gelöscht, sondern von den folgenden Plänen weiterverwendet (Aufräumen: `Testdaten_Stammdaten.md`, Abschnitt 4).

## 1. Ziel

Nachweis, dass ein neuer Nutzer sein Konto vollständig in der App anlegen kann: Anbieter wählen, Name, Benutzername (Vorschlag, Live-Prüfung, Ausweichvorschlag), Passwort, Kontoanlage ohne Zusatzschritt, Notfall-Schlüssel, erste Familie. Dazu die Prüfregeln des Formulars (Schaltfläche nur bei gültigen Angaben aktiv), die Anmeldung mit dem neuen Konto auf einem zweiten Gerät und das Verhalten bei geschlossener Registrierung.

**Abgrenzung:** Zusatzschritte des Anbieters (Bedingungen, E-Mail, Zugangscode, Captcha) bietet der Testserver nicht an; sie sind durch die automatischen Tests abgedeckt (TN-19). Kontoanlage bei matrix.org im Browser gehört zu #15.

## 2. Umgebungen und Nachweisarten

| Kürzel | Umgebung | Nachweis |
|---|---|---|
| **G** | Physisches Gerät (iPhone mit aktuellem iOS oder Mac mit aktuellem macOS), Testserver | Bildschirmfoto/Video – **vom Menschen durchzuführen** |
| **G2** | Zweites Gerät (Mac oder iPhone-Simulator) | wie G |
| **T** | Automatische Tests (`flutter test`) | Konsolenausgabe im Report |

Ergebnisse: ✅ bestanden · ❌ fehlgeschlagen · ⏳ offen · ⚠️ bestanden mit Befund

Den Notfall-Schlüssel-Bildschirm mit Bildschirmvideo aufnehmen (Lehre aus B-3).

## 3. Voraussetzungen

- **TV-01:** Auf G und G2 ist die aktuellste Version installiert (Soll = `pubspec.yaml` auf `main`; Ist je Gerät vergleichen, bei Abweichung zuerst neu installieren). App ohne Daten (frische Installation oder Einstellungen → „Alle lokalen Daten löschen“).
- **TV-02:** Registrierung auf dem Testserver offen (TN-00). Für TN-18 muss der Serverbetreiber sie zeitweise schließen.
- **TV-03:** Die Benutzernamen `fnt-MMTT-n1` und `fnt-MMTT-n12` existieren auf dem Server noch nicht (`…/register/available?username=…` liefert `available: true`). Sonst Datumsteil ändern (z. B. `1027b`) und neu prüfen. `n1` wird in TN-15 bewusst als „vergeben“ vorausgesetzt, weil TN-09 es zuvor angelegt hat.
- Die Ergebnisse der Vorprüfung (Soll/Ist-Version je Gerät, Namensprüfung) stehen am Anfang des Reports.

## 4. Testfälle

| ID | Schritt | Erwartetes Ergebnis | Umg. | Bezug |
|---|---|---|---|---|
| TN-00 | Server prüfen (entspricht TV-02, Ergebnis dort übernehmen): `https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/versions` im Browser; optional `curl -s -X POST -H 'Content-Type: application/json' -d '{}' https://matrix-synapse-3ues.srv1348446.hstgr.cloud/_matrix/client/v3/register` | JSON mit `"versions"`; Registrierung liefert `flows` mit `m.login.dummy`, **nicht** „Registration has been disabled“ | G | – |
| TN-01 | Frische Installation, App starten (Versionsstand aus TV-01 bestätigt). Start: „Willkommen“; unten „English“ antippen, danach zurück auf Deutsch; dann „Neue Familie gründen“ | „Willkommen“ mit drei Wegen („Neue Familie gründen“, „Ich wurde eingeladen“, „Ich habe schon ein Konto“), Sprache unten, kein eigener Sprach- oder Server-Schritt; Texte wechseln beim Sprachwechsel sofort (**deckt Prüfanleitung TC-01/TC-02 ab, dort nicht wiederholen**). Danach Maske „Konto erstellen“, „Schritt 1 von 3“; unten Abschnitt „Erweitert“ | G | E-55, #13 |
| TN-02 | Ohne Änderung des Anbieters ansehen (Vorschlag matrix.org) | „Bei matrix.org legst du dein Konto auf der Seite des Anbieters an. …“, Feld „Wie heißt du?“, Schaltfläche „Konto bei matrix.org erstellen“. **Nicht antippen** (kein Konto bei matrix.org) | G | E-70 |
| TN-03 | „Erweitert“ → „Anderen Anbieter verwenden“ → „Adresse des Anbieters“: `nicht-vorhanden.invalid` | Meldung „nicht-vorhanden.invalid ist gerade nicht erreichbar. Prüfe deine Internetverbindung.“ (oder sinngleiche Fehlermeldung); kein Formular zur Kontoanlage, „Konto erstellen“ nicht verfügbar | G | – |
| TN-04 | (**deckt Prüfanleitung TC-03 ab**) Adresse ändern auf `matrix-synapse-3ues.srv1348446.hstgr.cloud` | „Verbinde mit …“, danach „Dein Konto liegt bei matrix-synapse-3ues.srv1348446.hstgr.cloud.“; Felder „Wie heißt du?“, „Dein Benutzername“ (Hinweis „Damit meldest du dich an. 3 bis 32 Zeichen: …“), „Passwort“ (Hinweis „Mindestens 8 Zeichen. …“); „Konto erstellen“ ausgegraut | G | E-55 |
| TN-05 | **Namensvorschlag:** „Wie heißt du?“: `Jörg Müßig` | „Dein Benutzername“ füllt sich mit `joerg.muessig`; nach kurzer Pause „Der Benutzername ist frei.“ mit Häkchen (oder Vergeben-Hinweis, falls schon belegt) | G | E-55 |
| TN-06 | **Ungültige Benutzernamen** nacheinander eintragen: `ab`, `Anna`, `anna müller`, `.anna`, `anna.`, 33 × `a` | Jeweils Fehler „Bitte 3 bis 32 Zeichen: Kleinbuchstaben, Ziffern, Punkt, Unterstrich oder Bindestrich.“; „Konto erstellen“ bleibt ausgegraut | G | E-55 |
| TN-07 | Vorher TV-03 für `fnt-MMTT-n1` wiederholen (Name noch frei?). Benutzername von Hand `fnt-MMTT-n1`, danach den Namen auf `Test N1` ändern | Benutzername bleibt `fnt-MMTT-n1` (wird nach eigener Eingabe nicht mehr überschrieben); „Der Benutzername ist frei.“ | G | E-55 |
| TN-08 | **Pflichtangaben:** Passwort mit 7 Zeichen → dann 8 Zeichen; Augen-Symbol „Passwort anzeigen“/„Passwort verbergen“; Namen kurz leeren und wieder `Test N1` eintragen | 7 Zeichen: „Konto erstellen“ ausgegraut; ab 8 Zeichen aktiv. Augen-Symbol zeigt/verbirgt das Passwort. Leerer Name: Schaltfläche wieder ausgegraut | G | E-55 |
| TN-09 | **N1 anlegen:** „Konto erstellen“ antippen | „Erstelle Konto …“; **kein** Zusatzschritt („Noch ein kurzer Schritt“ erscheint nicht); weiter zu „Schritt 2 von 3“, Passwortfeld ist geleert | G | E-55 |
| TN-10 | (**deckt Prüfanleitung TC-05 ab**) „Notfall-Schlüssel erstellen“ (Video läuft) | Schlüssel wird angezeigt und **bleibt stehen**; „Kopieren“, „Als Datei speichern“; „Weiter“ erst nach Häkchen „Ich habe den Notfall-Schlüssel sicher aufbewahrt.“; Schlüssel als **KN1** ablegen | G | #10 |
| TN-11 | (**deckt Prüfanleitung TC-06 ab**) „Weiter“ → „Name der Familie“: `Testfamilie MMTT` → „Familie gründen“ | „Fertig! „Testfamilie MMTT“ ist eingerichtet.“, danach Hauptansicht „Heute“ | G | – |
| TN-12 | **Kontodaten prüfen:** Einstellungen → „Konto“; Einstellungen → „Über die App“ → „Protokoll: alle lokal gespeicherten Daten zeigen“ | Konto zeigt `@fnt-MMTT-n1:matrix.chaostribunal.de` und den Anbieter; Protokoll nennt den Anzeigenamen „Test N1“ | G | – |
| TN-13 | **Anmeldung auf zweitem Gerät:** G2 → „Ich habe schon ein Konto“ → „Erweitert“ → Anbieter-Adresse → `fnt-MMTT-n1` + **falsches** Passwort → „Anmelden“ | „Benutzername oder Passwort stimmen nicht.“; keine Anmeldung | G2 | – |
| TN-14 | G2: richtiges Passwort → „Anmelden“ → „Dieses Gerät freischalten“ mit **KN1** | Gerät freigeschaltet, Familie „Testfamilie MMTT“ erkannt, Hauptansicht; danach G2 abmelden (Einstellungen → „Abmelden“ → im Dialog „Abmelden“ bestätigen): die App zeigt direkt „Anmelden“ (nicht die Startseite) | G2 | – |
| TN-15 | **Vergebener Name + Ausweichvorschlag:** G2 (nach dem Abmelden auf „Anmelden“) → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse prüfen bzw. eintragen → Vorher TV-03 für `fnt-MMTT-n12` (muss frei sein). Name `Test N2`, Benutzername `fnt-MMTT-n1` (bewusst vergeben, da N1 aus TN-09 besteht) | Fehler „Schon vergeben – wie wäre es mit „fnt-MMTT-n12“?“, Chip „„fnt-MMTT-n12“ verwenden“; „Konto erstellen“ ausgegraut. Chip antippen → Benutzername `fnt-MMTT-n12`, „Der Benutzername ist frei.“ → Passwort → „Konto erstellen“ → Schlüssel (**KN2**) → Familie „Löschtest MMTT“ → Hauptansicht | G2 | E-55 |
| TN-16 | **Übergang zur Anmeldung:** G2 abmelden → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse prüfen → Name `Test`, Benutzername `fnt-MMTT-n12` eintippen → unten „Ich habe schon ein Konto“ | „Anmelden“ öffnet sich mit vorausgefülltem Benutzernamen `fnt-MMTT-n12`; Anmeldung mit Passwort und KN2 möglich | G2 | E-55 |
| TN-17 | **Abbruch ohne Kontoanlage:** G2 abmelden → „Noch kein Konto? Jetzt erstellen“ → Anbieter-Adresse prüfen → Name, Benutzername `fnt-MMTT-n9`, Passwort eintragen → Zurück-Pfeil oben links, ohne „Konto erstellen“ | Startseite „Willkommen“; kein Konto entsteht. Gegenprobe: „Neue Familie gründen“ → Anbieter-Adresse → `fnt-MMTT-n9` → „Der Benutzername ist frei.“ | G2 | – |
| TN-18 | **Registrierung geschlossen** (optional, Serverbetreiber setzt `enable_registration: false` und startet Synapse neu; TN-00-curl liefert „Registration has been disabled“): „Neue Familie gründen“ → Anbieter-Adresse | „Bei matrix-synapse-3ues.srv1348446.hstgr.cloud kann die App kein Konto anlegen. Erstelle es auf der Webseite des Anbieters und melde dich danach hier an.“; Schaltflächen „Element starten“ und „Ich habe ein Konto – anmelden“ (ggf. „Webseite öffnen“); kein Formular. Danach Registrierung **wieder öffnen** (die Folgepläne legen Konten an, z. B. I2 in Einladung TI-10) und TN-00 wiederholen | G | E-55 |
| TN-19 | Automatische Tests: `flutter test test/domain/username_suggestion_test.dart test/features/registration_test.dart test/features/onboarding_test.dart test/data/sdk_registration_test.dart`; optional E2E `test/e2e/gateway_registration_e2e_test.dart` gegen lokales Synapse (`tool/synapse/up.sh`) | Alle Tests bestehen (inkl. Zusatzschritte Bedingungen, E-Mail, Zugangscode, Captcha) | T | E-55 |
| TN-20 | **Zustand festhalten (kein Löschen):** Register in `Testdaten_Stammdaten.md` ausfüllen: N1 (angemeldet auf G, Schlüssel KN1, Familie F1), N2 (G2, Schlüssel KN2, Familie F2) | N1 und N2 bestehen und sind für die Folgepläne nutzbar; Anmeldung mit beiden Konten wurde in TN-14 bzw. TN-16 gezeigt. Gelöscht werden die Konten in Prüfanleitung TC-16 (N2) und Einladung TI-27 (N1) | G, G2 | – |

## 5. Abnahme

Bestanden, wenn TN-00 bis TN-17, TN-19 und TN-20 ✅ sind (Löschen der Konten gehört zu den Folgeplänen, siehe `Testdaten_Stammdaten.md`). TN-18 ist optional (nur mit Serverzugang); wird er nicht ausgeführt, im Report als ⏳ mit Begründung führen.
Ergebnisse stehen im Report `Testreport_Nutzeranlage.md` (Passwörter und Schlüssel maskiert).
