# Veröffentlichung in Google Play und App Store

Stand: 2026-10-21. Alles, was sich ohne Konten und Zugangsdaten vorbereiten lässt, ist erledigt. Was der Herausgeber noch
tun muss, steht in Abschnitt 1. Rechtliche Angaben sind Hinweise, keine Rechtsberatung.

## 1. Was der Herausgeber noch beisteuern muss (nicht automatisierbar)

| # | Punkt | Wo |
|---|---|---|
| 1 | **Entwicklerkonten:** Google Play Console, Apple Developer Program (kostenpflichtig; Organisationskonten brauchen u. a. eine D-U-N-S-Nummer) | Play Console / developer.apple.com |
| 2 | **Verantwortlicher, Anschrift, Kontakt** (Impressum) in `store/privacy/privacy-policy.*.md` eintragen (`<NAME UND ANSCHRIFT …>`, `<KONTAKT-E-MAIL>`) | `store/privacy/` |
| 3 | **Datenschutzerklärung öffentlich hosten** (feste URL, de/en); URL in beiden Stores eintragen. Zusätzlich Support-URL und Support-Mail | Hosting des Herausgebers |
| 4 | **Upload-Schlüssel erzeugen**: `tool/create_upload_key.sh` (legt `android/key.properties` an, nicht eingecheckt) und den Schlüssel mehrfach sichern | lokal |
| 5 | **Apple-Team-ID** in `ios/ExportOptions.plist` (`HIER_TEAM_ID_EINTRAGEN`) eintragen; in Xcode mit dem Apple-Konto anmelden; Bundle-ID `de.inneso.familynexus` bei Apple registrieren | lokal / developer.apple.com |
| 6 | **Prüfkonto** für die Review: ein Matrix-Konto (z. B. auf matrix.org) mit eingerichteter Schlüsselsicherung; Zugangsdaten **und Wiederherstellungsschlüssel** in App Store Connect („Anmeldeinformationen“) und in der Play Console („App-Zugriff“) hinterlegen | Stores |
| 7 | **Test auf echten Geräten** (Android und iPhone): Anmeldung, Verifizierung, Chat, Erinnerungen, Deep Link, App-Sperre, Backup-Verhalten. Bisher nur Emulator/Simulator und Ende-zu-Ende-Tests gegen Synapse (siehe OFFEN.md) | Geräte |
| 8 | **Screenshots** (`store/screenshots/`, siehe Abschnitt 5) prüfen bzw. mit eigenen Daten ersetzen | `store/` |
| 9 | **Rechtliche Prüfung AGPL ↔ App-Store-Bedingungen** (Abschnitt 6) | Herausgeber/Rechtsberatung |
| 10 | **Exportnachweis Verschlüsselung** (Apple/US-Ausfuhrrecht) beantworten (Abschnitt 4) | App Store Connect |

## 2. Vorbereitet im Repository

| Bereich | Stand |
|---|---|
| Version | `pubspec.yaml`: `1.1.0+8` (Name+Buildnummer). Jeder Upload braucht eine **höhere Buildnummer** (`+2`, …) |
| Kennungen | Android `de.inneso.familynexus`; iOS/macOS `de.inneso.familynexus` (vereinheitlicht) |
| Symbole | `tool/make_icons.py` erzeugt alle Größen (Android adaptiv + Legacy, iOS ohne Alpha, macOS) sowie `store/graphics/` (Play-Symbol 512, App-Store-Symbol 1024, Funktionsgrafik 1024×500) |
| Android | Release: R8/Shrink, `--obfuscate`, Symbole für native Bibliotheken, unsigniert ohne `key.properties`; **App Bundle:** `tool/build_release.sh aab` (≈ 79 MB) |
| iOS | iPhone-only (`TARGETED_DEVICE_FAMILY=1`, keine iPad-Screenshots nötig), Mindestversion iOS 15, `PrivacyInfo.xcprivacy` (kein Tracking, keine Datenerhebung), Face-ID-Hinweistext, `ios/ExportOptions.plist`, Build `tool/build_ios_release.sh` (`--check` ohne Signatur) |
| Store-Texte | `store/metadata/android/{de-DE,en-US}` (Titel, Kurz-/Langbeschreibung) und `store/metadata/ios/{de-DE,en-US}` (Name, Untertitel, Beschreibung, Schlüsselwörter, Werbetext, Neuerungen) + `review_notes.txt`; Längen sind gegen die Store-Grenzen geprüft |
| Datenschutz | `store/privacy/privacy-policy.{de,en}.md` (identisch zum App-Text) |

## 3. Google Play

1. **Schlüssel:** `tool/create_upload_key.sh`. Play App Signing aktivieren (Google verwaltet den App-Signaturschlüssel, du lädst mit dem Upload-Schlüssel hoch).
2. **Bauen:** `tool/build_release.sh aab` → `build/app/outputs/bundle/release/app-release.aab`. Obfuskierungs-Symbole aus `debug-info/` aufbewahren und in der Play Console hochladen (Deobfuskierungsdatei: `build/app/outputs/mapping/release/mapping.txt`).
3. **Store-Eintrag:** Texte aus `store/metadata/android/`, Symbol/Funktionsgrafik aus `store/graphics/`, Screenshots (mind. 2, Telefon, 16:9–9:16).
4. **App-Inhalt (Fragebögen):**
   - *Datenschutzerklärung:* URL aus Punkt 1.3.
   - *Werbung:* enthält keine Werbung.
   - *Zielgruppe:* **18+ (Erwachsene)** – empfohlen, um die Families-Richtlinien zu vermeiden. Kinder können nur über Einladung eines Moderators Mitglied sein (Hinweis in der App). Entscheidung E-47; bei anderer Wahl gelten zusätzliche Anforderungen.
   - *App-Zugriff:* eingeschränkt → Prüfkonto angeben (Punkt 1.6).
   - *Inhaltseinstufung (IARC):* Kommunikations-App ohne Gewalt/Sexualität/Glücksspiel; Nutzer können Nachrichten austauschen.
   - *Berechtigungen:* `USE_EXACT_ALARM` – **Begründung:** Kalender-App, Erinnerungen an Termine müssen zur eingestellten Zeit erscheinen (zulässiger Kernzweck laut Richtlinie); `POST_NOTIFICATIONS` für diese Erinnerungen; `RECEIVE_BOOT_COMPLETED` zum Neuplanen nach Neustart; `INTERNET` für die Matrix-Verbindung.
   - *Datensicherheit:* siehe Tabelle unten.
5. **Test:** Neue private Entwicklerkonten müssen laut Google zunächst einen **geschlossenen Test mit einer Mindestzahl an Testern über mehrere Wochen** durchlaufen, bevor die Produktion freigegeben wird (aktuelle Zahlen in der Play Console prüfen).

### Datensicherheit (Vorschlag – Verantwortung für die endgültigen Angaben liegt beim Herausgeber)

Der Herausgeber betreibt keinen Server und erhält keine Daten. Die App sendet Daten ausschließlich an den **vom Nutzer gewählten Matrix-Server**; Inhalte sind Ende-zu-Ende-verschlüsselt, Metadaten (Konto-ID, Zeitpunkte, Raumgröße, Geräte) sieht der Serverbetreiber.

| Datentyp | Erfasst? | Geteilt? | Hinweis |
|---|---|---|---|
| Nachrichten, Dateien, Kalenderereignisse, Einkaufsliste, Aufgabenlisten | ja, auf Wunsch des Nutzers an den gewählten Matrix-Server | nein (an Familienmitglieder, vom Nutzer gesteuert) | Ende-zu-Ende-verschlüsselt, „Daten werden bei der Übertragung verschlüsselt“: ja |
| Nutzer-ID (Matrix-ID), Anzeigename | ja (Anmeldung am gewählten Server) | nein | nötig für die App-Funktion, nicht optional |
| Standort, Kontakte, Fotos (automatisch), Gesundheit, Finanzen | nein | – | |
| Kennungen für Werbung / Analyse / Absturzberichte | nein | – | keine Telemetrie, keine SDKs |
| Löschung | Nutzer löscht lokale Daten in der App („Alle lokalen Daten löschen“); Serverdaten beim Betreiber des Matrix-Servers | | Konto-Löschung beim Serverbetreiber |

## 4. App Store (iOS)

1. **Vorbereiten:** Bundle-ID registrieren, in Xcode anmelden, Team-ID eintragen (Punkt 1.5). App in App Store Connect anlegen (Name `FamilyNexus`, Primärsprache Deutsch, SKU frei).
2. **Bauen:** `tool/build_ios_release.sh` (erzeugt eine signierte IPA in `build/ios/ipa/`). Zum Hochladen: Xcode-Werkzeug **Transporter** oder `xcrun altool --upload-app`. Obfuskierungssymbole (`debug-info/`) aufbewahren.
3. **Eintrag:** Texte aus `store/metadata/ios/`, Symbol `store/graphics/app-store-icon-1024.png`, Screenshots für 6,9″ (1320×2868) und 6,1″/6,3″ (1179×2556 oder 1206×2622) – nur iPhone; App-Vorschauvideos (optional) 1920×886 bzw. 886×1920.
4. **App-Datenschutz (Nährwertkennzeichen):** „Daten werden nicht erhoben“ ist zutreffend, weil der Herausgeber keine Daten erhält; Inhalte gehen verschlüsselt an den vom Nutzer gewählten Server. Beim Ausfüllen die Abschnitte 3 (Tabelle) und die `PrivacyInfo.xcprivacy` zugrunde legen; Bibliotheken bringen eigene Manifeste mit (im Xcode-Datenschutzbericht des Archivs prüfen).
5. **Altersfreigabe:** Fragebogen: keine anstößigen Inhalte; Nachrichtenaustausch ja; kein freier Webzugang.
6. **Verschlüsselung (Exportnachweis):** Die App verwendet Ende-zu-Ende-Verschlüsselung (Standardverfahren, keine proprietäre Kryptografie). Bei „Verwendet Ihre App Verschlüsselung?“ → *Ja*, Standardalgorithmen → die Ausnahme für Massenmarkt-/Standardverschlüsselung ist typisch, kann aber eine jährliche Selbstklassifizierung gegenüber der US-Behörde verlangen. Bewusst **nicht** in der `Info.plist` hinterlegt (`ITSAppUsesNonExemptEncryption`), damit der Herausgeber die Antwort bei jedem Upload ausdrücklich gibt.
7. **Richtlinien:** *Konto-Löschung* (5.1.1 v): Die App legt keine Konten an → nicht anwendbar; lokale Datenlöschung ist vorhanden. *Anmeldung mit Apple:* nur bei Drittanbieter-Anmeldung nötig → nicht anwendbar. *Nutzerinhalte* (1.2): Nachrichten gehen nur zwischen eingeladenen Familienmitgliedern; Moderatoren können Mitglieder entfernen; Nutzer können Nachrichten **melden** (Langdruck auf die Nachricht → „Nachricht melden“, Meldung an den Serverbetreiber) und Absender **blockieren** (Nachricht oder Mitgliederliste; Aufheben unter Einstellungen → Blockierte Mitglieder), siehe E-48. Die Review-Hinweise nennen den Weg dorthin.
8. **Review-Hinweise:** `store/metadata/ios/review_notes.txt` einfügen und Prüfkonto (Punkt 1.6) angeben.

### 4a. In Xcode zum Hochladen vorbereiten (iOS und macOS)

Einmalig je Plattform (Team-ID: developer.apple.com → Membership):

1. App-ID `de.inneso.familynexus` registrieren (Developer-Portal → Identifiers) und in App Store Connect je Plattform einen App-Eintrag anlegen (iOS und macOS können unter einem Eintrag mit derselben Bundle-ID laufen).
2. Team-ID in `ios/ExportOptions.plist` **und** `macos/ExportOptions.plist` eintragen (`HIER_TEAM_ID_EINTRAGEN` ersetzen).
3. Versionen kommen aus `pubspec.yaml` (`1.1.0+8` → Version 1.1.0, Build 8) und gelten für beide Plattformen; vor jedem Upload die Buildnummer erhöhen.

Archiv bauen (die Skripte setzen Obfuskierung und Debug-Symbole, ein reines „Product → Archive“ in Xcode ohne vorherigen Flutter-Build tut das nicht):

| Plattform | Befehl | Ergebnis |
|---|---|---|
| iOS | `tool/build_ios_release.sh` | signierte IPA in `build/ios/ipa/` |
| macOS | `tool/build_macos_release.sh` | signiertes Paket in `build/macos/export/` |
| macOS | `tool/build_macos_release.sh --xcode` | Archiv, das sich im Xcode-Organizer öffnet (Distribute App → App Store Connect → Upload) |
| beide | `… --check` | nur Übersetzbarkeit, ohne Signatur (kein Upload möglich) |
| macOS (Download) | `tool/build_macos_dmg.sh` | Developer-ID-signierte, notarisierte DMG in `build/macos/dmg/` |

**In der CI** (Job `apple` in `.github/workflows/release.yml`, läuft bei jedem Versions-Tag oder manuell mit `build=apple`): baut DMG, macOS-Paket und IPA auf einem macOS-Runner. Die DMG hängt am GitHub-Release, IPA und Paket liegen als Workflow-Artefakt `appstore-<tag>-run<n>` (zum Hochladen mit Transporter). Signiert wird cloudverwaltet über einen App-Store-Connect-API-Schlüssel, der zugleich die DMG notarisiert. Einmalig einrichten:

1. App Store Connect → Benutzer und Zugriff → Integrationen → App-Store-Connect-API: Schlüssel mit Rolle **Admin** anlegen (nötig, damit Xcode Distribution- und Developer-ID-Zertifikate cloudverwaltet anlegen darf), `.p8` herunterladen.
2. Repository-Secrets: `APPLE_API_KEY_BASE64` (`base64 -i AuthKey_XXXX.p8`), `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`.

Ohne diese Secrets baut der Job nur eine unsignierte DMG zum Testen (Artefakt `macos-unsigned-…`, nicht am Release).

Alternativ in Xcode: `ios/Runner.xcworkspace` bzw. `macos/Runner.xcworkspace` öffnen → Target *Runner* → *Signing & Capabilities* → Team wählen (*Automatically manage signing*) → *Product → Archive* → Organizer → *Distribute App*. Vorher einmal `tool/build_*_release.sh --check` laufen lassen.

Stand der Vorbereitung (ohne Signatur geprüft, 2026-10-22): iOS-Release 30 MB, macOS-Release 67 MB (arm64 + x86_64); Version 1.0.4 (5); macOS: App-Sandbox mit `network.client` und `files.user-selected.read-write`, Kategorie *Produktivität* (`LSApplicationCategoryType`), Mindestversion macOS 12; iOS: iPhone, Mindestversion iOS 15, `PrivacyInfo.xcprivacy` ohne Tracking. Offen bleiben Signatur, Team-ID und App-Store-Connect-Einträge, die ein Apple-Entwicklerkonto brauchen.

## 5. Screenshots

`store/screenshots/ios/` ist das **fertige Bilderpaket** für den App Store (de-DE und en-US, 1206×2622 und 1320×2868, mit kurzen Bildunterschriften nach den Asset-Best-Practices von Apple); die Rohaufnahmen liegen daneben. `store/screenshots/` enthält je sechs Aufnahmen für iPhone (6,9″ `ios-6.9/`, 6,3″ `ios-6.3/`) und Android-Telefon (`android-phone/`) mit **erfundenen Beispieldaten** (Fake-Server, kein Netzwerk), erzeugt mit `tool/preview/` (siehe `store/screenshots/README.md`). Tablet-Aufnahmen (nicht nötig, solange iPad nicht unterstützt wird; Play verlangt sie nur optional). Für die Veröffentlichung prüfen oder durch eigene ersetzen; Pflichtgrößen siehe oben.

## 6. Rechtlicher Hinweis zur Lizenz (AGPL-3.0)

FamilyNexus steht unter AGPL-3.0 (E-02), weil die Matrix-Bibliothek und `vodozemac` AGPL-lizenziert sind. Die **Nutzungsbedingungen des App Stores** (zusätzliche Einschränkungen für Nutzer) gelten in der Open-Source-Gemeinschaft als schwer vereinbar mit GPL-Lizenzen, bei denen man nicht Urheber ist. Google Play ist weniger problematisch. Vor einer Veröffentlichung im App Store sollte der Herausgeber klären, ob (a) eine Ausnahme/kommerzielle Lizenz der Rechteinhaber der AGPL-Bibliotheken eingeholt wird oder (b) auf eine andere Verteilung (Google Play, F-Droid, direkter Download) beschränkt wird. Diese Frage kann hier nicht entschieden werden und ist in `docs/OFFEN.md` geführt.

## 7. Ablauf pro Release

1. `flutter analyze`, `flutter test`, `tool/e2e.sh`, `tool/device_tests.sh`, `tool/check_permissions.sh`.
2. Version in `pubspec.yaml` erhöhen (`1.1.0+8` …); Neuerungen in `store/metadata/*/*/release_notes.txt` (App Store höchstens 4000 Zeichen, Google Play höchstens 500 je Sprache) eintragen.
3. Android: `tool/build_release.sh aab`; iOS: `tool/build_ios_release.sh`.
4. Hochladen, interne Tests/TestFlight, danach freigeben.
