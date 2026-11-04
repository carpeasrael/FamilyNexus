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
| 2.6 | Familienraum anlegen (verschlüsselt, Power-Levels 0/50, Ersteller 100 – E-61); Privatraum → Phase 3.3 (E-29) |
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

## Phase 8 – Erweiterung: einfache Einrichtung, Kontoanlage, Einladen und Beitreten (2026-10-24)

Auftrag: nutzerfreundlicher, einfacher Ablauf für Registrierung, Einrichtung einer Familie sowie Einladung und Beitritt –
für Menschen ohne Software-Affinität und ohne Wissen über Matrix; mit Testplänen, die nach der Umsetzung durchgeführt werden.
Entscheidungen: E-55, E-56, E-57, SA-8. Testplan: `docs/TESTPLAN_ONBOARDING.md`.

| # | Teilaufgabe |
|---|---|
| 8.1 | Domäne: Link v2 (`f`, `by`), Registrierungsmodell und Ablaufwahl, Benutzernamen-Vorschlag, neue Fehlerarten |
| 8.2 | Daten: Serverprüfung (OAuth/UIA), UIA-Schleife, OAuth (MSC2964/2966), Rücksprung je Plattform, Gerätename, Anzeigename, Fake |
| 8.3 | Oberfläche: drei Wege, Konto erstellen/Anmelden, „Erweitert“, Zusatzschritte, Notfall-Schlüssel, Beitrittskarte, „Jetzt einladen“, Einladungsdialog, Texte de/en |
| 8.4 | Tests: Unit, Widget (Fake), E2E gegen Synapse, Bildschirmfotos, Testplan mit Ergebnissen |
| 8.5 | Doku (README, ARCHITEKTUR, ENTSCHEIDUNGEN, OFFEN), Review durch separaten Agenten, Funde beheben |

Abnahme 8:
- [x] Auf dem normalen Weg erscheinen weder „Matrix“, „Homeserver“ noch IDs der Form `@name:server` (Test TP-L10N-01)
- [x] Konto in der App anlegen inkl. Bedingungen, E-Mail, Einladungscode, Captcha; abgeschaltete Registrierung führt zur Webseite (Tests)
- [x] Anbieter mit Browser-Anmeldung: `prompt=create`, nur passender `state` meldet an (Tests)
- [x] Neuling mit Link: keine Serverfrage, Beitrittskarte mit Namen, ein Tipp zur Anfrage, Link überlebt Neustart (Tests)
- [x] Notfall-Schlüssel bleibt Pflicht; Kopieren leert die Zwischenablage, Datei enthält Anleitung (Tests)
- [x] Kontoanlage, Link v2, Anfrage, Bestätigung und Beitritt gegen echten Synapse (E2E)
- [x] `flutter analyze` sauber, alle Tests grün, Testplan durchgeführt und protokolliert

## Requirement REQ-TABLET-01 – Tablet-Nutzung in Hoch- und Querformat

Erfasst: 2026-11-04. **Status: offen, noch nicht umgesetzt oder abgenommen.**

**Anforderung:** FamilyNexus muss auf Android-Tablets und iPads in Hoch- und Querformat vollständig bedienbar sein.
Die App muss beim Start und bei jeder Änderung der Fenstergröße oder Ausrichtung automatisch die verfügbare
Anzeigefläche erkennen und das Layout daran anpassen. Eine manuelle Auswahl von Tabletgröße oder Darstellungsmodus
darf nicht erforderlich sein.

**Nutzergeschichte:** Als Familienmitglied möchte ich die App auf unterschiedlich großen Tablets halten und drehen
können, damit ich Kalender, Chat und Listen in jeder Ausrichtung bequem nutzen kann, ohne Eingaben zu verlieren.

### Verbindliches Verhalten

- Maßgeblich sind die nutzbare Fensterbreite und -höhe in logischen Pixeln, einschließlich der vom System gemeldeten
  sicheren Randbereiche. Physische Zollgröße, Modellname oder eine feste Geräteliste dürfen keine Voraussetzung sein.
  Auch geteilte oder frei vergrößerbare App-Fenster auf Tablets müssen automatisch berücksichtigt werden.
- Schmale Fenster erhalten eine einspaltige Darstellung. Bei ausreichend Platz werden zusammengehörige Inhalte
  nebeneinander angezeigt, beispielsweise Kalender und Chat gemäß `Concept.md`. Layoutgrenzen und Mindestbreiten
  der Spalten sind bei der Umsetzung zentral festzulegen und zu dokumentieren; die Ausrichtung allein entscheidet
  nicht über die Anzahl der Spalten. Inhalte dürfen nicht lediglich proportional vergrößert werden.
- Alle bestehenden Ansichten und Abläufe sind eingeschlossen: Einrichtung und Anmeldung, Heute, Kalender und
  Terminbearbeitung, Familien- und Einzelchat, Einkauf, Aufgabenlisten, Familienverwaltung, Einstellungen sowie
  Dialoge, Einladungen und Geräteverifizierung.
- Ein Wechsel zwischen Hoch- und Querformat passt die Darstellung ohne App-Neustart oder erneute Anmeldung an.
  Geöffnete Ansicht, ausgewählter Termin bzw. Chat, Kalenderdatum, ungespeicherte Formulareingaben,
  Nachrichtenentwürfe und die inhaltliche Scrollposition bleiben erhalten. Die Anpassung löst keine zusätzliche
  Speicher- oder Sendeaktion aus.
- Texte, Bedienelemente und Dialoge dürfen sich nicht überlagern oder unzugänglich abgeschnitten werden.
  Navigation und Formulare benötigen kein horizontales Scrollen; fachlich vorgesehene horizontale Navigation
  im Kalender bleibt zulässig. Bei eingeblendeter Bildschirmtastatur sind aktives Eingabefeld und zugehörige
  Aktionen sichtbar oder durch Scrollen erreichbar.
- Deutsche und englische Texte, helles und dunkles Design sowie Systemschriftgrößen bis 200 % bleiben nutzbar.
  Touch-Ziele sind mindestens 48 × 48 logische Pixel groß. Eine systemseitige Rotationssperre wird respektiert;
  die App erzwingt selbst keine einzelne Ausrichtung.
- Die Plattformkonfiguration muss Android-Tablets und native iPad-Nutzung einschließlich beider Ausrichtungen
  unterstützen. Aktuell ist iOS über `TARGETED_DEVICE_FAMILY = 1` auf iPhones beschränkt; diese Einschränkung ist
  bei der Umsetzung aufzuheben. Die bestehende Smartphone-Bedienung muss erhalten bleiben.

### Abnahmekriterien

- [ ] Automatisierte Layoutprüfungen decken mindestens 600 × 960, 800 × 1280 und 1024 × 1366 logische Pixel sowie
  jeweils die vertauschten Maße ab. Jede oben genannte Ansicht bleibt ohne Layoutüberlauf bedienbar.
- [ ] Direkt unter, auf und über jeder dokumentierten Layoutgrenze wird das vorgesehene Layout angezeigt.
  Eine Verkleinerung des Tablet-Fensters bis auf 360 logische Pixel Breite schaltet ohne manuellen Eingriff auf
  eine bedienbare einspaltige Ansicht um; beim Vergrößern wird wieder zusätzlicher Platz genutzt.
- [ ] Während eines ungespeicherten Terminformulars, eines Chatentwurfs und eines geöffneten Dialogs wird jeweils
  von Hoch- nach Querformat und zurück gewechselt. Eingaben, Auswahl und Navigationszustand bleiben erhalten;
  es entsteht weder Datenverlust noch eine doppelte Speicher- oder Sendeaktion.
- [ ] Beide Sprachen und Designs werden in beiden Ausrichtungen geprüft, zusätzlich mit 200 % Schriftgröße
  und geöffneter Bildschirmtastatur. Eingabefelder, Navigation und Bestätigungsaktionen bleiben erreichbar.
- [ ] Auf mindestens einem echten Android-Tablet und einem echten iPad werden Start in beiden Ausrichtungen,
  wiederholtes Drehen, Rotationssperre und Fenstergrößenänderungen soweit vom System unterstützt geprüft.
  Gerät, Betriebssystem, App-Version und Ergebnis werden im Testbericht festgehalten; nicht ausgeführte
  Geräteprüfungen bleiben ausdrücklich offen.
- [ ] Eine Smartphone-Regressionsprüfung bestätigt die Bedienbarkeit bei 360 und 390 logischen Pixeln Breite.

## Risiken

| Risiko | Gegenmaßnahme |
|---|---|
| Kein echter Homeserver für Tests verfügbar | `MatrixGateway`-Abstraktion + Fake; SDK-Anteile klein halten; Lücken in OFFEN.md |
| Rust-Toolchain für vodozemac im Build | Prototyp bestätigt Build aus Quellcode; Toolchain-Voraussetzung in README |
| AGPL des SDKs | App unter AGPL-3.0 (E-02) |
| Erinnerungen auf Android unzuverlässig (Hersteller-Akku) | Neuplanung bei Start/Boot, Hinweis bei fehlender Berechtigung |
| Neue Mitglieder können alte Megolm-Sitzungen nicht lesen | Resync der eigenen geteilten Termine bei Beitritt (E-13) |
| Knock-Endpunkt nicht im SDK | Schmaler Rohaufruf im Gateway, isoliert, in OFFEN als „nicht gegen echten Server geprüft“ |
