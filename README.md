# FamilyNexus

Familienkalender und Messenger für Android, iOS und macOS – **local-first**, Ende-zu-Ende-verschlüsselt über das
[Matrix](https://matrix.org)-Protokoll. Gebaut mit Flutter (Android; iOS seit Phase 6 im Simulator geprüft; die Codebasis ist
plattformneutral, Plattformcode liegt in klar getrennten Adaptern unter `lib/data/platform/`, `android/` und `ios/`).

Hauptquelle der Anforderungen: [`Concept.md`](Concept.md). Entscheidungen und ihre Begründung:
[`docs/ENTSCHEIDUNGEN.md`](docs/ENTSCHEIDUNGEN.md).

## Funktionen (Stand: Phasen 1–6 umgesetzt)

- **Einrichtung** in vier Schritten: Sprache → Server (öffentlicher Standard voreingestellt, eigener Server
  möglich) → Anmeldung mit bestehendem Konto + Pflicht-Schlüsselsicherung → Familie gründen oder beitreten.
- **Familienchat und Einzelchats** (verschlüsselt): Nachrichten, Antworten, Reaktionen, Anhänge (validiert, nie
  automatisch geöffnet), Offline-Warteschlange. Einzelchats gibt es je Paar beigetretener Mitglieder („Nachricht
  schreiben“ in der Familie oder über die Gesprächsleiste im Chat); Einladungen Fremder werden ignoriert.
- **Online-Status:** Wer aus der Familie online ist, steht in der Mitgliederliste, im Chat und auf „Heute“ (Text und
  Punkt, „zuletzt online vor …“). Der Status wird nur Ende-zu-Ende-verschlüsselt an Geräte von Familienmitgliedern
  gesendet, nie gespeichert und ist unter *Einstellungen → Datenschutz → Online-Status teilen* abschaltbar.
- **Einkaufszettel:** gemeinsame Liste der Familie (Eintrag, Menge, abhaken, bearbeiten, löschen, „Erledigte
  entfernen“), verschlüsselt übertragen und gespeichert, offlinefähig, deterministische Zusammenführung bei
  gleichzeitigen Änderungen.
- **Kalender** mit Tag-/Wochen-/Monats-/Agenda-Ansicht, Personenfilter, Wiederholungen (inkl. Ausnahmen,
  Sommerzeit), Zeitzonen, **privaten** (nur eigene Geräte) und **geteilten** Terminen (verschlüsselt im
  Familienraum), Zu-/Absage, Termine als Karte im Chat teilen.
- **Lokale Erinnerungen** ohne Terminnamen in der Benachrichtigung.
- **Familie und Rollen:** Mitglied/Moderator; Einladen per Link/QR (einmalig, zeitlich begrenzt) oder Matrix-ID,
  Beitrittsanfragen bestätigen, Ernennen, Entfernen (Schlüsselrotation).
- **Sicherheit:** verschlüsselte lokale Datenbank (SQLCipher, Schlüssel im Android Keystore), App-Sperre über die
  Geräteanmeldung, Bildschirmschutz, Geräteverifizierung per Emoji-Vergleich, Identitätsprüfung der Mitglieder.
- Deutsch/Englisch, Hell/Dunkel (Glas-/Neon-Optik auf Basis der AURORA-Farben) mit **wählbarer Neon-Akzentfarbe**
  (Einstellungen im Burger-Menü rechts oben), Option „Effekte reduzieren“,
  WCAG-AA-Kontraste.

Nicht enthalten bzw. bekannte Einschränkungen: siehe [`docs/OFFEN.md`](docs/OFFEN.md).

## Voraussetzungen

| Werkzeug | Zweck |
|---|---|
| Flutter 3.47.x (Dart 3.13) | Build und Tests |
| JDK 17, Android SDK (Plattform 35/36, Build-Tools, NDK über Gradle) | Android-Build |
| Rust (`rustup`, Android-Targets) | `vodozemac` (Kryptografie) wird beim Android-Build aus dem Quelltext gebaut |
| Docker (optional) | lokaler Test-Homeserver für die Ende-zu-Ende-Tests |

## Bauen und starten

```sh
flutter pub get
flutter run                      # Debug auf Gerät/Emulator
flutter build apk --debug        # Debug-APK
flutter build macos --debug       # macOS (Apple Silicon), Start: open build/macos/Build/Products/Debug/FamilyNexus.app
flutter build ios --simulator --debug   # iOS (Simulator); braucht Xcode, CocoaPods, Rust-Ziele für iOS (siehe docs/OFFEN.md)
tool/build_release.sh            # Release mit --obfuscate (ohne android/key.properties unsigniert)
```

Release-Signatur: `android/key.properties` (nicht eingecheckt) mit `storeFile`, `storePassword`, `keyAlias`,
`keyPassword`. Ohne diese Datei bleibt das Release-APK absichtlich unsigniert (kein Fallback auf den Debug-Schlüssel).
Debug-Symbole der Obfuskierung liegen in `debug-info/` (nicht eingecheckt) – aufbewahren, um Stacktraces zu lesen.

## Tests

```sh
flutter analyze                  # muss ohne Meldungen durchlaufen
flutter test                     # Unit-, Widget-, Sicherheits- und Architekturtests (Matrix-Fake)
tool/e2e.sh                      # Ende-zu-Ende gegen lokalen Synapse (Docker, TLS) mit echter vodozemac-Bibliothek
tool/device_tests.sh             # Integrationstests auf Emulator/Gerät (DB-Verschlüsselung, Keystore, Migration, Erinnerungen)
tool/check_permissions.sh        # prüft die zusammengeführten Manifest-Berechtigungen gegen die Positivliste
```

Handlauf-Tests mit Screenshots bzw. zugestellter Erinnerung: `integration_test/manual/`.

Abdeckung (Zeilen, Stand Ende Phase 5; Phase 6 nicht neu gemessen): Domäne 96,6 %, Oberfläche (`features`) 86,3 %, Design-System 98,3 %;
`SdkMatrixGateway` wird durch die Ende-zu-Ende-Tests gegen Synapse zu 69,9 % abgedeckt (in `flutter test` ohne
`FN_E2E` übersprungen).

## Veröffentlichung

Vorbereitung für Google Play und App Store (Versionen, Symbole, Store-Texte, Datenschutz, Bauskripte, Checklisten):
[`docs/STORE.md`](docs/STORE.md); Inhalte der Einträge unter `store/`. Release-Bundles: `tool/build_release.sh aab`,
`tool/build_ios_release.sh`.

## Eigener Server, Datenschutz

- Eigenen Homeserver betreiben: [`docs/EIGENER_SERVER.md`](docs/EIGENER_SERVER.md).
- Datenschutztext: in der App unter *Einstellungen → Datenschutz*; dort auch „Alle lokalen Daten löschen“.
- Abhängigkeiten, Lizenzen, SBOM: [`docs/ABHAENGIGKEITEN.md`](docs/ABHAENGIGKEITEN.md) (`python3 tool/sbom.py`).
- Architektur: [`docs/ARCHITEKTUR.md`](docs/ARCHITEKTUR.md); Planung und Abnahme: [`docs/PLAN.md`](docs/PLAN.md);
  Reviews: [`docs/REVIEW.md`](docs/REVIEW.md).

## Sicherheitsprinzipien (nicht verhandelbar)

Keine Telemetrie, keine Werbe-/Analyse-SDKs; keine eigene Kryptografie (Matrix-SDK + vodozemac); E2EE nicht
abschaltbar; keine Klartextinhalte in Benachrichtigungen, Logs oder Backups (`allowBackup=false`); nur TLS;
Eingaben und Importe gelten als nicht vertrauenswürdig; Abhängigkeiten sind exakt gepinnt. Abweichungen sind in
`docs/ENTSCHEIDUNGEN.md` als „Sicherheitsabweichung“ gekennzeichnet.

## Lizenz

AGPL-3.0-or-later (siehe [`LICENSE`](LICENSE)); die Matrix-SDK- und vodozemac-Abhängigkeiten stehen unter AGPL
(Entscheidung E-02).
