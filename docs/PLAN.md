# Projektplan FamilyNexus (Android, Flutter)

Hauptquelle: `Concept.md`. Entscheidungen: `ENTSCHEIDUNGEN.md`. Stand: 2026-10-21.

## Gate-Regeln (gelten für jede Phase)

1. `flutter analyze` ohne Fehler **und** Warnungen/Hinweise.
2. `flutter test` vollständig grün.
3. Abnahmekriterien der Phase einzeln abgehakt (unten).
4. Separater Review-Agent (frischer Kontext) → Funde in `REVIEW.md`, behoben.
5. Erst dann nächste Phase. Schlägt ein Gate fehl: Ursache beheben, Gate wiederholen.

## Schichten

Präsentation (`lib/features`, `lib/ui`) → Domäne (`lib/domain`, rein Dart, ohne Flutter/Plattform) → Daten (`lib/data`: Datenbank, Matrix). Android-spezifisches nur in `lib/data/platform/` hinter Schnittstellen.

## Phase 1 – Fundament

| # | Teilaufgabe |
|---|---|
| 1.1 | Projektgerüst, Ordnerstruktur, `analysis_options` (streng), gepinnte Abhängigkeiten, Git |
| 1.2 | Android-Härtung: `allowBackup=false`, Datenextraktionsregeln, Network-Security-Config (nur TLS), minimale Berechtigungen, R8/Obfuskierung |
| 1.3 | Design-System: Tokens (AURORA), Glas-/Neon-Widgets, Hell/Dunkel, „Effekte reduzieren“, gebündelte Schriften |
| 1.4 | Lokalisierung: ARB de/en, `gen-l10n`, Sprachumschaltung |
| 1.5 | Verschlüsselte Datenbank: SQLCipher, Schlüssel im Android Keystore, Migrationen, Repositories |
| 1.6 | App-Gerüst: Navigation (Heute/Kalender/Chat/Familie/Einstellungen), Settings-Persistenz |

Abnahme 1:
- [x] App startet, 5 Tabs sichtbar, Dark/Light, Sprache de/en umschaltbar
- [x] DB ist ohne Schlüssel nicht lesbar (Test), Schlüssel nur im Keystore
- [x] Keine festen Texte im Code (Prüfskript), Kontrast der Token-Paare ≥ AA (Test)
- [x] `allowBackup=false`, kein Klartextverkehr, Berechtigungen minimal (Manifest-Test)

## Phase 2 – Matrix und E2EE

| # | Teilaufgabe |
|---|---|
| 2.1 | Bibliotheks-Prototyp (matrix-SDK + vodozemac + SQLCipher) auf Emulator; Entscheidung dokumentieren |
| 2.2 | `MatrixGateway`-Schnittstelle + `FakeMatrixGateway` (Tests) + `SdkMatrixGateway` |
| 2.3 | Serverwahl: URL-Validierung (nur https), Erreichbarkeit/Versionen, Betreiberanzeige |
| 2.4 | Login (bestehendes Konto), Sitzungsspeicherung, Abmelden |
| 2.5 | Ersteinrichtung in vier Schritten |
| 2.6 | Familienraum anlegen (verschlüsselt, Power-Levels 0/50); Privatraum → Phase 3.3 (E-29) |
| 2.7 | Chat: Familienraum, Nachrichten, Antworten, Reaktionen, Anhänge (validiert), Offline-Warteschlange |

Abnahme 2:
- [x] Raum wird nur mit aktivierter Verschlüsselung erzeugt (Spezifikationstest); Senden nur bei nachweislicher Verschlüsselung (E-27); E2EE nicht abschaltbar
- [x] http:// wird abgelehnt; Servercheck zeigt Betreiber/Version
- [x] Chat im Widget-Test über Fake: senden, antworten, reagieren
- [x] Anhänge: Typ-/Größenprüfung (Test), kein Auto-Öffnen

## Phase 3 – Kalender

| # | Teilaufgabe |
|---|---|
| 3.1 | Domäne: Termin, Wiederholung (täglich/wöchentlich/monatlich/jährlich, Ausnahmen), Zeitzonen |
| 3.2 | Sichtbarkeit privat/shared, Ereigniscodec (`de.inneso.familynexus.event`), Konfliktauflösung, Autorenprüfung |
| 3.3 | Sync: shared → Familienraum, privat → Privatraum, Zusagen (Zusage/Absage/Vielleicht), Resync für neue Mitglieder |
| 3.4 | UI: Tag/Woche/Monat/Agenda, Personenfilter, Terminformular, Heute-Bildschirm |
| 3.5 | Erinnerungen: Planer, lokale Benachrichtigungen ohne Klartext, Neuplanung nach Neustart, Berechtigungshinweis |
| 3.6 | Termine im Chat teilen (Karte, direkt zu-/absagen) |

Abnahme 3:
- [x] Private Termine werden nie gesendet (Test am Gateway)
- [x] Wiederholungen inkl. Ausnahmen und Sommerzeit korrekt (Tests)
- [x] Fremde Änderungen an fremden Terminen werden verworfen (Test)
- [x] Erinnerungstext enthält keinen Terminnamen (Test)

## Phase 4 – Familie und Rollen

| # | Teilaufgabe |
|---|---|
| 4.1 | Rechte-Modell (`Permissions`) auf Power-Levels |
| 4.2 | Einladungen: Link/QR mit Ablauf, Beitrittsanfrage (knock), Bestätigung, Einladen per Matrix-ID |
| 4.3 | Ernennen zum Moderator, Entfernen (Schlüsselrotation durch SDK), Familienname/Server ändern |
| 4.4 | Geräteverifizierung (Emoji-SAS), Cross-Signing-Bootstrap, Schlüssel-Backup mit Wiederherstellungsschlüssel (E-35) |
| 4.5 | Sicherheitsstatus in Einstellungen, App-Sperre, Screenshot-Schutz |

Abnahme 4:
- [x] Mitglied sieht keine Moderatoraktionen; Rechteprüfung zusätzlich im Gateway (Test)
- [x] Abgelaufene/manipulierte Einladungslinks werden abgelehnt (Test)
- [x] Integrationstest Einladung + Rollenwechsel (Fake)

## Phase 5 – Härtung

| # | Teilaufgabe |
|---|---|
| 5.1 | Sicherheitstests: private Termine, DB ohne Schlüssel, keine Klartext-Logs |
| 5.2 | Abhängigkeits-Audit (Version, Pflege, Lizenz), SBOM, `flutter pub outdated` |
| 5.3 | Release-Konfiguration (Obfuskierung, Signatur über `key.properties`), Debug-Build |
| 5.4 | Doku: README, ARCHITEKTUR, OFFEN, Datenschutztext, Server-Vorlage |
| 5.5 | Gesamtreview, Abdeckungsbericht |

Abnahme 5:
- [x] `flutter build apk --debug` erfolgreich; Release-Build mit `--obfuscate` gebaut (`tool/build_release.sh`, Symbole in `debug-info/`, R8-Mapping vorhanden)
- [x] Abdeckung Domäne gemessen und genannt (96,6 %; README)
- [x] Alle Dokumente aktuell

## Phase 6 – Erweiterung: Online-Status, Einzelchats, Einkaufszettel (2026-10-21)

Auftrag nach Abschluss von Phase 5: (1) Statusanzeige, wer aus der Familie online ist; (2) Chat nicht nur im Familienraum,
sondern auch zwischen einzelnen Mitgliedern; (3) Einkaufszettel. Entscheidungen: E-38 bis E-42.

| # | Teilaufgabe |
|---|---|
| 6.1 | Online-Status: Ereignisformat und Auswertung (Domäne), Senden/Empfangen als verschlüsselte Gerätenachricht (Gateway), Lebenszyklus-Steuerung, Schalter in den Einstellungen, Anzeige (Familie, Chat, Heute) |
| 6.2 | Einzelchats: Gesprächsmodell, Raum je Mitgliederpaar (verschlüsselt), automatische Annahme nur von Familienmitgliedern, Gesprächsliste, Chat je Gespräch, ungelesene Nachrichten je Gespräch |
| 6.3 | Einkaufszettel: Datenmodell und Konfliktregel, Ereignisformat, lokale Ablage (Migration 3), Synchronisation inkl. Resync neuer Mitglieder, Oberfläche (Tab) |
| 6.4 | Fake-Gateway, Unit-/Widget-Tests, E2E-Tests gegen Synapse (Status, Einzelchat, Einkaufszettel) |
| 6.5 | Texte de/en, Datenschutztext, Review durch separaten Agenten, Funde beheben |
| 6.6 | Doku: Concept.md, README, ARCHITEKTUR, OFFEN, ENTSCHEIDUNGEN, REVIEW |

Abnahme 6:
- [x] Online-Status verlässt das Gerät nur als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte von Familienmitgliedern; abschaltbar (Test)
- [x] Ohne gültigen, jüngeren „online“-Eintrag gilt ein Mitglied als offline; unverschlüsselte/fremde Absender werden verworfen (Tests)
- [x] Einzelchats nur mit aktuellen Familienmitgliedern; fremde Einladungen werden nicht automatisch angenommen; unverschlüsselte Räume nie genutzt (Tests, E2E)
- [x] Einkaufszettel: gleichzeitige Änderungen konvergieren deterministisch; Fremdformate/Überlängen werden verworfen (Tests, E2E)
- [x] `flutter analyze` sauber, alle Tests grün, `flutter build apk --debug` erfolgreich, Doku aktuell

## Phase 7 – Erweiterung: Aufgabenlisten (2026-10-22)

Auftrag: Aufgabenlisten, die einem Familienmitglied zugewiesen werden, täglich/wöchentlich/monatlich neu starten, vom
Mitglied mit optionalem Kommentar abgehakt werden (Datum wird protokolliert) und einen Verlauf haben. Entscheidung: E-51.

| # | Teilaufgabe |
|---|---|
| 7.1 | Datenmodell (Liste + anfügendes Protokoll), Periodenschlüssel, Ereignisformat, Konfliktregel, Rechte |
| 7.2 | Lokale Ablage (Migration 4), Synchronisation inkl. Resync, Gateway-Signale und -Senden |
| 7.3 | Oberfläche: Menüeintrag, Übersicht, Detail mit Abhaken/Kommentar/Verlauf, Editor (Moderatoren), Karte auf „Heute“ |
| 7.4 | Fake-Gateway, Unit-/Sync-/Widget-/Pentests, E2E gegen Synapse |
| 7.5 | Texte de/en, Datenschutztext, Doku |

Abnahme 7:
- [x] Nur Moderatoren legen Listen an; nur die zugewiesene Person hakt ab; Verstöße werden beim Empfang verworfen (Tests)
- [x] Reset zu Mitternacht/Wochen-/Monatswechsel in der Listenzone, auch über Sommerzeit und Jahresgrenzen; Verlauf bleibt (Tests)
- [x] Fremdformate, gefälschte Absender, Zeit- und Periodenmanipulation werden verworfen (Pentests)
- [x] Ende-zu-Ende verschlüsselt im Familienraum; Server sieht keinen Klartext (E2E)

## Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| Kein echter Homeserver für Tests verfügbar | `MatrixGateway`-Abstraktion + Fake; SDK-Anteile klein halten; Lücken in OFFEN.md |
| Rust-Toolchain für vodozemac im Build | Prototyp bestätigt Build aus Quellcode; Toolchain-Voraussetzung in README |
| AGPL des SDKs | App unter AGPL-3.0 (E-02) |
| Erinnerungen auf Android unzuverlässig (Hersteller-Akku) | Neuplanung bei Start/Boot, Hinweis bei fehlender Berechtigung |
| Neue Mitglieder können alte Megolm-Sitzungen nicht lesen | Resync der eigenen geteilten Termine bei Beitritt (E-13) |
| Knock-Endpunkt nicht im SDK | Schmaler Rohaufruf im Gateway, isoliert, in OFFEN als „nicht gegen echten Server geprüft“ |
