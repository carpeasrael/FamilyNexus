# Architektur (Stand Phase 6)

```
lib/
  main.dart            Start: Bootstrap, App starten; Datenlöschung (onFullReset)
  app/                 App-Widget, AppServices/AppScope (InheritedWidget), bootstrap, calendar_factory
  core/                Querschnitt: AppLog (redigiert), Kontrastberechnung
  domain/              Reine Dart-Logik (per Architekturtest erzwungen): Termin, Wiederholung/Occurrence,
                       Event-Codec, Konflikte, Erinnerungsplaner, Kalenderdienst, Rechte, Einladungslink,
                       Familie, Chat (inkl. Gespräche), Online-Status (Format, Auswertung), Einkaufszettel
                       (Modell, Format, Konfliktregel, Dienst), Server/Matrix-IDs, Anhangsrichtlinie,
                       Textbereinigung, Einstellungen
  data/
    db/                SQLCipher-Datenbank, Migrationen (v1 settings, v2 Kalender, v3 Einkaufszettel, v4 Aufgabenlisten), SqlEventStore, SqlShoppingStore, SqlTaskStore, KeyValueStore
    matrix/            MatrixGateway (Schnittstelle) + SdkMatrixGateway (matrix-SDK, vodozemac), HttpsOnlyClient,
                       ServerProbe, ChatMapper, FamilyRoomSpec
    sync/              CalendarSync, ShoppingSync (Signale ↔ Dienst/Gateway, Warteschlange, Resync),
                       PresenceSync (eigene Statusmeldungen nach App-Lebenszyklus und Einstellung)
    platform/          Android-Adapter hinter Schnittstellen: KeyStore, ScreenProtection, FileAccess,
                       DeviceTimeZone, ReminderScheduler, LinkSource (Deep Links), DeviceAuth (App-Sperre)
  features/            Präsentation: onboarding, shell, today, calendar, chat, family, security, lock,
                       settings, reminders, shopping, presence, common
  ui/                  Design-System: Tokens (AURORA), Theme, Glas-Widgets, QR-Anzeige
  l10n/                ARB-Quellen (de, en); generierter Code in l10n/gen
android/               MainActivity (FLAG_SECURE, Kanäle window/links), Manifest-Härtung, R8-Regeln
test/  integration_test/  tool/  docs/
```

## Schichten
`features` → `domain` ← `data`. Die Domäne kennt weder UI noch Datenbank noch Matrix. `features` greifen nie direkt auf
Datenbank, Schlüsselspeicher oder SDKs zu (Architekturtest); Android-spezifische Brücken liegen nur in `data/platform`
und `android/`. Für eine zweite Plattform sind nur die Adapter in `data/platform` und das Manifest zu ersetzen.

## Matrix-Anbindung
Alles geht durch `MatrixGateway`. Zusicherungen: Familienraum immer E2E-verschlüsselt (Raumversion 10, `knock`,
Power-Levels 0/50, Ersteller 100 = Administrator, in der App Moderator, E-61), Senden nur bei nachweisbarer Megolm-Verschlüsselung, Rechte im Gateway **und** serverseitig,
Schlüsselweitergabe nur an cross-signierte Geräte (`ShareKeysWith.crossVerified`), Identitätsvermerke der Mitglieder,
Einladungen mit Zufalls-ID. `FakeMatrixGateway` (test/support) bildet das Verhalten für Widget-/Integrationstests nach;
`test/e2e` prüft das echte Gateway gegen Synapse.

## Kalender-Datenfluss
Termin → `CalendarService` (Regeln, Konflikte, Versionen) → `EventStore` (SQLCipher) → `CalendarSync` →
geteilt: Familienraum, privat: nur privater Raum des eigenen Kontos (Geräte-Sync); eingehend: `EventCodec`
(Format v1, Besitzer = Absender) → Dienst. Erinnerungen: `ReminderPlanner` → `ReminderScheduler` (lokal, ohne Inhalt).

## Einzelchats, Online-Status, Einkaufszettel (Phase 6)
- **Gespräche:** `MatrixGateway.threads` liefert den Familienchat (`ChatThread.familyId`) und je beigetretenem
  Mitglied höchstens einen verschlüsselten Einzelchat-Raum (`is_direct`, Megolm). Chatmethoden nehmen `threadId`
  (Standard Familienchat). Einladungen in Einzelchats werden nur von beigetretenen Familienmitgliedern automatisch
  angenommen und danach auf Megolm geprüft; andere werden ignoriert. Räume entfernter Mitglieder werden ausgeblendet
  und nicht mehr beschrieben.
- **Online-Status:** `PresenceSync` (Lebenszyklus, Einstellung) → `MatrixGateway.announcePresence` → Olm-verschlüsselte
  Gerätenachricht `de.inneso.familynexus.presence` an `encryptToDevice`-Geräte beigetretener Mitglieder. Empfang nur,
  wenn verschlüsselt angekommen und vom beigetretenen Mitglied; Auswertung in `PresenceBoard` (5 min gültig). Nur
  Arbeitsspeicher.
- **Einkaufszettel:** `ShoppingService` (Regeln, Versionen, Grenzen) → `ShoppingStore` (SQLCipher) → `ShoppingSync`
  → Familienraum (`de.inneso.familynexus.shopping`, E2EE); eingehend: `ShoppingCodec` (Format v1, `by` = Absender)
  → `ShoppingMerge`. Resync: der letzte Bearbeiter sendet seine aktiven Einträge bei neuen Mitgliedern erneut.
- **Reaktionen (E-86):** `MatrixGateway.sendReaction` → Familien- oder Einzelchat-Raum
  (`de.inneso.familynexus.reaction`, E2EE, ohne `m.relates_to`); eingehend: `ReactionCodec` (Format v1, `sender` = Absender)
  → `ChatMapper`, zusammen mit lesbaren alten `m.reaction`.
- **Aufgabenlisten (E-51):** `TaskService` (Rechte, Versionen, Grenzen) → `TaskStore` (SQLCipher: Listen + anfügendes Protokoll) → `TaskSync` → Familienraum (`tasklist`, `taskdone`). Der Reset ist abgeleitet: `TaskPeriod` bildet Periodenschlüssel in der Zeitzone der Liste, `TaskProgress` wertet das Protokoll für die laufende Periode aus. Oberfläche: `TasksController`, `TasksScreen`.

## Einrichtung und Kontoanlage (E-55–E-57)
- `features/onboarding/onboarding_screen.dart` ist der Rahmen mit drei Wegen (`OnboardingPath`) und der Schrittanzeige je Weg;
  die Schritte sind eigene Widgets: `WelcomeStep`, `InviteLinkStep`, `AccountCreateStep` (mit `RegistrationStageView` für
  Zusatzschritte), `LoginStep`, `SecurityPanel` (Notfall-Schlüssel, meldet `onReady`), `FamilyStep` (`FamilyStepMode`).
- `ProviderController` (ChangeNotifier) hält den gewählten Anbieter und prüft ihn automatisch (sofort bzw. nach 800 ms
  Pause bei eigener Eingabe): `MatrixGateway.probeServer` + `registrationOptions`. `ProviderSection` zeigt das Ergebnis und
  „Erweitert“.
- Domäne: `domain/registration.dart` (Modus, Zusatzschritte als `sealed`-Typen, Auswahl des Ablaufs, Bedingungen),
  `domain/username_suggestion.dart`.
- Daten: `ServerProbe.registrationOptions`/`oauthIssuer`/`checkUsername`; `SdkMatrixGateway.register`/`continueRegistration`
  (eigene UIA-Schleife, Passwort nur in `_RegistrationSession`), `startOAuth`/`completeOAuth` (SDK-Erweiterungen MSC2964/2966),
  `setDisplayName`. Plattform: `BrowserLauncher` (nur https), `OAuthRedirect` (Mobil: App-Schema über `LinkSource`, Desktop:
  Empfänger auf `127.0.0.1`), `features/onboarding/browser_sign_in.dart` verbindet beides.
- Einladung vor der Anmeldung: `AppRoot` merkt geprüfte Links in `AppSettings.pendingInvite` vor und stellt sie beim Start
  wieder her; OAuth-Rücksprünge (`AppLinkOAuthRedirect.isCallback`) werden dort nicht als Einladung behandelt.

## Einladungen (E-49, E-56, E-79)
- Link: `InviteLink` (Format v4 mit kodierten Feldern, ohne Familienname; liest v1 bis v3) + Vermerk `InviteTicket` als verschlüsseltes Raumereignis; `SdkMatrixGateway` führt die
  Vermerke der Moderatoren (`_roomTickets`, `_usedTickets`) zusätzlich zu den eigenen Kontodaten und prüft damit
  Beitrittsanfragen (`RequestCheck`). Jede Anfrage bestätigt ein Moderator (`approveRequest`, E-78). Teilen: QR, Kopieren,
  `MailLauncher` (`data/platform/mail_launcher.dart`, `url_launcher`).
- Teilen über `features/family/invite_dialog.dart` (`showInviteDialog`: QR, E-Mail, Kopieren), genutzt von der
  Familienansicht und von „Jetzt einladen“ nach der Gründung.
- Einrichtung: `FamilyStep` zeigt bei vorhandener Einladung die Einladungskarte statt der Auswahl Gründen/Beitreten, bei einem
  vorgemerkten Link die Beitrittskarte; eigene, bestätigte Beitrittsanfragen werden automatisch angenommen.

## Melden und Blockieren (E-48)
- `domain/moderation.dart`: `ReportRequest` (Kategorie + bereinigter Freitext → Grundtext), `BlockedUsers` (defensives Lesen,
  Obergrenze 200), `visibleMessages`/`visibleThreads` (Filter). Die Blockierliste liegt als `blockedUsers` in `AppSettings`
  (verschlüsselte Datenbank, nur lokal).
- `MatrixGateway.reportMessage` → Matrix `report`-Endpunkt; `features/moderation` enthält Meldedialog, Blockieren/Aufheben
  und die Liste der Blockierten. Chat und Familie filtern bei der Anzeige; der Raum selbst bleibt unverändert.

## Sicherheitsgrundlagen
- SQLCipher-Datenbank; 256-Bit-Zufallsschlüssel im Android Keystore (`flutter_secure_storage`), nie im Code/Dateien.
- `allowBackup=false`, Extraktionsregeln, TLS-Pflicht (Network-Security-Config **und** `HttpsOnlyClient` in Dart),
  minimale Berechtigungen (Manifest-Test, `tool/check_permissions.sh`).
- `FLAG_SECURE` standardmäßig; App-Sperre über die Geräteanmeldung; Pflicht-Schlüsselsicherung.
- `AppLog` redigiert Matrix-IDs/Token; kein `print` (Architekturtest).
- Release: R8 + `--obfuscate`; Signatur nur aus `key.properties`.

## Tests
- `flutter test`: Domäne, Widgets, Sicherheits-, Manifest-, l10n- und Architekturtests (Fake-Gateway).
- `tool/e2e.sh`: Ende-zu-Ende gegen lokalen Synapse (echtes Gateway, echte Kryptografie), u. a. Kontoanlage und Beitritt
  eines Neulings (`gateway_registration_e2e_test.dart`).
- `tool/onboarding_screens.sh`: Bildschirmfotos aller Einrichtungsschritte (`test/manual/`, nur mit `FN_SCREENSHOTS=1`).
- Testplan für Einrichtung, Einladung und Beitritt: `docs/TESTPLAN_ONBOARDING.md`.
- `tool/device_tests.sh`: Emulator/Gerät (DB-Verschlüsselung, Keystore, Migration, SDK-Rauchtest, Erinnerungen).
