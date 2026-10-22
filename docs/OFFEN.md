# Offene Punkte und Einschränkungen

Stand: 2026-10-21. Alles, was nicht (oder nur eingeschränkt) umgesetzt ist, mit Begründung und Weg dorthin.

## Nicht umgesetzt (bewusst)

| Punkt | Grund / Hinweis |
|---|---|
| Push-Benachrichtigungen für Chat (UnifiedPush/FCM) | Würde Dritt-Infrastruktur oder Telemetrie-SDKs verlangen; „Später denkbar“ im Konzept. Chat wird beim Öffnen/Sync aktualisiert, Erinnerungen laufen lokal. |
| In-App-QR-Scanner | `mobile_scanner`/ML Kit kann Daten an Google senden (E-34). Scan mit der Kamera-App öffnet den Deep Link. Alternative auf ZXing-Basis ohne Google-Dienste prüfen. |
| ICS-/Archiv-Export | Ein Export wäre unverschlüsselt gespeichert – verstößt gegen „nie unverschlüsselt speichern“. Möglich nur als verschlüsseltes Archiv. |
| Geräte sperren / fremde Sitzungen abmelden | Benötigt Server-Passwortbestätigung (UIA) für Geräteverwaltung; Verifizierungsstatus wird angezeigt. |
| Konto beim Server löschen | Nur lokale Löschung („Alle lokalen Daten löschen“) und Abmelden; Kontolöschung beim Betreiber selbst. |
| Serverwechsel mit Migration | Serverwechsel = neu anmelden; Daten migrieren nicht. |
| Verifizierung per QR-Code | Nur Emoji-Vergleich (SAS). |
| Lokalisierte Emoji-Namen bei der Verifizierung | Emojis werden mit englischen Namen angezeigt (Symbole sind maßgeblich). |
| EXIF-Entfernung bei Bildern | Anhänge werden unverändert (verschlüsselt) gesendet. |
| Mehrere Familien je Konto | Eine Familie je Konto. |
| Gruppenchats außer dem Familienchat | Einzelchats gibt es nur zwischen zwei Mitgliedern (E-39). |
| Mehrere Einkaufslisten, Kategorien, Preise | Eine gemeinsame Liste je Familie (E-40). |
| Familie selbst verlassen | Mitglieder werden nur durch Moderatoren entfernt; Austritt (`leave`) fehlt in der Oberfläche. Das Recht auf Löschung wird über die lokale Löschung und die Kontolöschung beim Betreiber wahrgenommen. |
| Server durch Moderator ändern | Der Server ist in den Einstellungen nur lesbar; Wechsel = neue Familie/neue Anmeldung. |
| Löschmarken beim „Alle lokalen Daten löschen“ | Geteilte Termine bleiben bei den anderen Geräten bestehen; vor dem Löschen sollten sie einzeln gelöscht werden. |
| Chat-Benachrichtigungen (auch lokal) | Keine; siehe E-16. |

## Bekannte Einschränkungen

- **Online-Status (E-38):** Mehrere Geräte desselben Kontos werden einzeln geführt; die Person gilt als online, solange irgendein
  Gerät online meldet. Im Hintergrund oder bei beendeter App gilt man nach 5 Minuten als offline (kein Push, keine
  Hintergrunddienste). „Zuletzt online“ ist nur seit dem letzten App-Start bekannt (nicht gespeichert). Der Server
  sieht den Takt der Gerätenachrichten (Metadaten).
- **Einzelchats (E-39):** Entfernt man ein Mitglied, bleibt der gemeinsame Raum bestehen (er wird ausgeblendet, nichts wird
  mehr gesendet); das automatische Verlassen fehlt. Entsteht durch gleichzeitiges Anlegen ein zweiter Raum für dasselbe
  Paar, gilt auf beiden Seiten der mit der kleinsten Raum-ID; Nachrichten im anderen Raum sind dann unsichtbar.
  Einzelchats werden nur nach vollständig geladener Mitgliederliste angezeigt; Einladungen Fremder bleiben unbeantwortet
  liegen (nicht abgelehnt).
- **Einkaufszettel (E-40):** Ein Mitglied mit manipuliertem Gerät kann Einträge ändern oder löschen wie jedes Mitglied
  (Versionssprünge sind begrenzt); Schaden begrenzt auf die Liste. Sind 300 aktive Einträge erreicht, muss man
  erledigte entfernen. Der Resync für neue Mitglieder sendet nur Einträge, die man zuletzt selbst bearbeitet hat; Einträge
  eines ausgeschiedenen letzten Bearbeiters erreichen neue Mitglieder nur, soweit sie im nachgeladenen Verlauf liegen. Ein Gerät, das lange offline war und alte Bearbeitungen
  erneut sendet, kann neuere nicht überschreiben (Version), aber ein gleichzeitig gelöschter Eintrag kann bei gleicher
  Version wieder erscheinen (Zeitstempel entscheidet).

- **SA-2:** Eingeladene (noch nicht beigetretene) Personen erhalten Nachrichtenschlüssel (SDK-Verhalten); Mitigation siehe
  `docs/ENTSCHEIDUNGEN.md`.
- Ablehnung einer Beitrittsanfrage ist für den Anfragenden nicht sichtbar (SDK liefert `knock`-Sync nicht); die
  Anfrage läuft nach 7 Tagen ab oder wird zurückgezogen.
- Moderatoren können Chat- **und** Kalendernachrichten anderer redigieren (`redact` = 50, E-37).
- Nachladen alter Ereignisse ist begrenzt (≈ 600 Chatereignisse, 5000 Kalendersignale); bei sehr langer Offlinezeit
  oder sehr großen Familien können Termine fehlen, bis ihr Besitzer sie erneut veröffentlicht (Resync).
- Zwei Geräte desselben Kontos, die gleichzeitig den privaten Raum anlegen, können zwei Privaträume erzeugen
  (selten; Raum-ID wird gemerkt, bis Kontodaten eintreffen).
- Wenn der Server ein Passwort für die Cross-Signing-Einrichtung verlangt, wird es einmalig abgefragt und nicht gespeichert.
- Identitätsvermerke (Pinning) sind TOFU: ein bereits beim ersten Kontakt untergeschobener Schlüssel fällt nur durch
  persönliche Verifizierung auf – die Mitgliederliste zeigt „nicht persönlich geprüft“.
- Verifizierungsstatus-Hinweis nach dem Beitritt („jetzt persönlich prüfen“) ist nicht automatisch; Nutzung über Mitgliedermenü.
- Pflicht-Schlüsselsicherung wird von der Oberfläche erzwungen (Tor in `AppRoot`), nicht vom Gateway.
- Sackgassen bei Sonderfällen der Schlüsselsicherung (Zustand „unbekannt“ nach Netzwerkfehler, Neuversuch nach Teil-Einrichtung →
  „bereits vorhanden“) lösen sich über Neustart/Abmelden; kein eigener Reparaturdialog.
- Wird die App beim Anzeigen des Wiederherstellungsschlüssels beendet, ist der Schlüssel verloren (er wird nie gespeichert);
  die Einrichtung kann nur nach Zurücksetzen der Sicherung wiederholt werden.
- Einladungslink-Deep-Link: Der Intent bleibt bis zur Bestätigung erhalten; es wird nie automatisch gehandelt.
- Nicht automatisiert getestet: Deep-Link-/Kamera-Pfad (nur Verhalten des Parsers und der Oberfläche), Akku-Optimierungen
  einzelner Hersteller für Erinnerungen, Identitätswechsel gegen echten Server, Prozess-Tod bei Schlüsselanzeige.

- „Anhang speichern“ schreibt bewusst unverschlüsselt (SA-3).
- `USE_EXACT_ALARM` ist bei Verteilung über den Play Store richtlinienkritisch; für APK-Verteilung (E-02) vertretbar.
- Der Sichtbarkeitswechsel mit gleichzeitiger Textänderung läuft in zwei Schritten; zwischen ihnen kann die noch nicht
  überarbeitete Fassung veröffentlicht werden (Kalenderdienst-Funktion mit gemeinsamer Sperre fehlt).
- Beim Familienwechsel werden alle lokalen Termine (auch private, noch unveröffentlichte) gelöscht (E-37).
- `person_colors`/`setPersonColor` und `CalendarSync.resyncOwnShared` sind ungenutzt (Personenfarbe wird aus der ID abgeleitet).
- „Effekte reduzieren“ ist eine eigene Einstellung und folgt nicht automatisch der Systemeinstellung.

- Nicht als Unit-Test mit SDK-Fake abgedeckt (nur Synapse-E2E): `_acceptDirectInvites`, `_eligibleDirectRooms`, `_onToDevice`.

## Veröffentlichung (E-47, `docs/STORE.md`)

- **Nicht ohne den Herausgeber möglich:** Entwicklerkonten, Upload-Schlüssel (`tool/create_upload_key.sh`), Apple-Team-ID, Impressum/Kontakt und gehostete Datenschutzseite, Prüfkonto mit Wiederherstellungsschlüssel, Exportnachweis.
- **Lizenz:** AGPL-3.0 (E-02) und App-Store-Nutzungsbedingungen sind rechtlich zu klären (STORE.md, Abschnitt 6) – ggf. Ausnahme der Rechteinhaber der AGPL-Bibliotheken oder Verteilung nur über Google Play/F-Droid/Direktdownload.
- **Melden/Blockieren (E-48):** Melden geht an den Betreiber des Homeservers (nicht an Moderatoren der Familie); Blockieren gilt nur lokal auf diesem Gerät und wirkt auf Chatnachrichten und Einzelchats. Geteilte Termine, Einkaufszettel-Einträge, Reaktionen und der Online-Status blockierter Mitglieder bleiben sichtbar; die Zähler für Ungelesenes zählen ihre Nachrichten weiter mit. Eine Meldung an die Moderatoren der Familie gibt es nicht.
- Echtgerät-Tests (Android und iPhone) stehen aus; Store-Screenshots stammen von Emulator/Simulator mit Beispieldaten.

## iOS (E-43)

- Nur im **Simulator** gebaut und gestartet (`flutter build ios --simulator`); nicht auf echtem iPhone getestet (Schlüsselbund, Face ID, Benachrichtigungen, Deep Link per Kamera, Backup-Ausschluss, Verhalten im Hintergrund). Ein Gerätebuild braucht ein Apple-Entwicklerkonto und Signierung.
- Voraussetzungen: Xcode, CocoaPods, Rust-Ziele `aarch64-apple-ios`, `aarch64-apple-ios-sim` (`rustup target add …`).
- SA-5: kein Screenshot-Schutz. Erinnerungen: höchstens 60 geplant. Die Ende-zu-Ende- und Gerätetests laufen nur für Android/Host; auf iOS fehlen automatisierte Integrationstests.
- Exportnachweis (`ITSAppUsesNonExemptEncryption`) und App-Store-Angaben (Datenschutz-„Nährwertkennzeichen“) sind vor einer Veröffentlichung vom Herausgeber zu klären. Ohne Hintergrunddienst gilt der Online-Status im Hintergrund nach 5 Minuten als offline (iOS beendet Apps schneller).

## macOS (E-44)

- Gebaut (`flutter build macos --debug`) und gestartet; nicht ausführlich bedient oder getestet (Anmeldung gegen echten Server, Schlüsselbund bei signierter Verteilung, Benachrichtigungen, Deep Link, Touch ID, Time-Machine-Ausschluss). Keine Notarisierung/Signierung; Verteilung außerhalb des Entwicklerrechners braucht ein Apple-Entwicklerkonto.
- Adaptive Zwei-Spalten-Ansicht (Kalender + Chat, Concept) für große Fenster ist nicht umgesetzt; die Oberfläche ist für Telefonbreite entworfen.
- Rust-Ziel `aarch64-apple-darwin` (Apple Silicon) wird für die Krypto-Bibliothek gebraucht.

## Betrieb / Build

- Ende-zu-Ende-Tests laufen nur lokal gegen einen eigenen Synapse (`tool/e2e.sh`), nicht gegen Produktivserver.
- Obfuskierung wird nur durch `tool/build_release.sh` erzwungen (ein direktes `flutter build apk --release` ist nicht obfuskiert); Release stets über das Skript bauen.
- Release-Signierung braucht `android/key.properties` (nicht eingecheckt); ohne bleibt das APK unsigniert.
- Rust-Toolchain ist Build-Voraussetzung (vodozemac wird aus Quelltext gebaut).
- Dart-AOT-Symbole: `flutter build --obfuscate` warnt vor unobfuskierten DWARF-Informationen in der ELF-Bibliothek;
  Android-Release verwendet `--split-debug-info`, Code ist per R8 minimiert.
