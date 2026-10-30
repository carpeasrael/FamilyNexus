# Dienste, Regionen und Berechtigungsnachweise

Stand: 30.10.2026 · Grundlage: Repository `e4180fb`, Version 1.2.1 (21). Diese Übersicht beschreibt die Implementierung; sie bestätigt keine Live-Erreichbarkeit, eingerichteten Store-Konten oder erteilten Genehmigungen.

## 1. Externe Dienste, Tools und Plattformen (Apple-Punkt 4)

| Dienst / Tool | Anbieter bzw. Betreiber | Verwendung und Einordnung |
|---|---|---|
| Matrix-Homeserver, Standard `matrix.org` | Betreiber des ausgewählten Servers; beim Standard der matrix.org-Dienst | Konten, Räume/Mitgliedschaften, verschlüsselte Nachrichten und Medien, Kalender-/Einkaufs-/Aufgabensynchronisation, Schlüsselsicherung und Entgegennahme von Meldungen. Server verarbeitet auch Metadaten. Andere kompatible HTTPS-Server unter „Erweitert“ wählbar |
| Kontodienst `account.matrix.org` | Kontodienst des Standardanbieters matrix.org | Browserbasierte Registrierung/Anmeldung und Kontoverwaltung/Löschung. Die App verwendet vom Server gelieferte Authentifizierungs- und Kontoverwaltungsinformationen; Browserablauf am eingereichten Build prüfen |
| GitHub Pages unter `carpeasrael.github.io/FamilyNexus/` | GitHub Pages; Projektinhalt vom FamilyNexus-Herausgeber | Einladungs-Landingpage `/join/` und öffentliche OAuth-Client-Webseite. Die Landingpage öffnet die App über `familynexus://`; kein eigener Chat-/Datei-Backenddienst |
| Element / `element.io/download` | Element | Optionaler Verweis bzw. Start eines externen Matrix-Clients, wenn ein Anbieter Registrierung in FamilyNexus nicht unterstützt. Für die vorbereiteten matrix.org-Prüfkonten nicht erforderlich |
| Browser, E-Mail-Bestätigung und CAPTCHA nach Anbietervorgaben | Gewählter Kontoanbieter und gegebenenfalls dessen Dienstleister | Bedingte Schritte bei Registrierung/Authentifizierung; kein eigener FamilyNexus-Mail- oder CAPTCHA-Dienst. Tatsächlich im Video verwendete Anbieter/Schritte ergänzen, falls zusätzliche Dienstleister beteiligt sind |
| Flutter und Dart | Flutter-/Dart-Projekt | Lokales UI und Laufzeit; kein entfernter Inhaltsdienst |
| Matrix Dart SDK und vodozemac | jeweilige Open-Source-Projekte | Matrix-Anbindung und lokale Ende-zu-Ende-Verschlüsselung mit Olm/Megolm |
| SQLCipher, `sqflite_sqlcipher` | SQLCipher-Projekt / Paketautoren | Verschlüsselte lokale Datenbanken der Apple-App |
| Apple Keychain, Geräteauthentifizierung, lokale Mitteilungen, Datei-/Mail-/Browseraufrufe | Apple / eingerichtete System-Apps | Lokale Schlüsselablage, App-Sperre, Terminerinnerungen, Dateiauswahl und ausdrückliche externe Aktionen; kein FamilyNexus-Pushbackend |

Im untersuchten App-Code und den direkten Abhängigkeiten ist kein Werbe-, Analyse-, Zahlungs-, KI- oder externer Inhaltsdaten-Dienst integriert. Es gibt keine Remote-Push-Anbindung für Chat. Der geplante Nextcloud-Familienspeicher ist laut [OFFEN.md](../docs/OFFEN.md) noch nicht umgesetzt und gehört deshalb nicht in die Liste aktiver Dienste.

Belege: [Standardanbieter](../lib/domain/app_settings.dart), [Matrix-Gateway](../lib/data/matrix/sdk_matrix_gateway.dart), [Einladungslink](../lib/domain/invite_link.dart), [Element-Verweis](../lib/data/platform/element_launcher.dart), [Abhängigkeiten](../pubspec.yaml) und [lokale Benachrichtigungen](../lib/data/platform/reminder_scheduler.dart).

Die öffentlich erreichbare Datenschutz- und Support-URL aus App Store Connect zusätzlich prüfen. Aus einer Website-Adresse im Code folgt nicht, dass die aktuellen Rechtstexte dort vollständig veröffentlicht sind. Die [Datenschutzvorlage](../store/privacy/privacy-policy.en.md) enthält noch Herausgeber-Platzhalter.

## 2. Regionen und Sprachen (Apple-Punkt 5)

Die untersuchte Implementierung enthält keine nach Land freigeschalteten Familienfunktionen und keinen regional unterschiedlichen Inhaltskatalog. Deutsch und Englisch sind implementiert; die gewählte Sprache, Datumsformatierung und Zeitzone beeinflussen die Darstellung bzw. Terminberechnung. Verfügbarkeit und Registrierungsanforderungen des gewählten Matrix-Anbieters können sich unterscheiden.

**App-Funktion und Store-Verfügbarkeit getrennt angeben:** Aus dem Code lässt sich nicht ableiten, in welchen Ländern die App tatsächlich angeboten wird. Insbesondere die Entscheidung zu Frankreich aus den vorhandenen Exportunterlagen ist nicht als bereits getroffen zu behandeln.

| Vor Einreichung festhalten | Stand |
|---|---|
| Länder/Regionen laut App Store Connect, geprüft am | offen |
| Ausgenommene Länder mit tatsächlichem Grund | offen |
| Frankreich verfügbar: ja/nein; zugehöriger Exportstatus | offen |
| Verhalten bei Deutsch, Englisch und weiterer Gerätesprache | physischer Nachweis offen |
| Abweichungen des tatsächlich gewählten Review-Anbieters | offen |

Formulierung für `STOREFRONTS`: tatsächliche Verfügbarkeit knapp nennen, etwa „All configured storefronts; excluded: …“. „Worldwide“ nur eintragen, wenn das der Store-Konfiguration entspricht. Keine pauschale weltweite Erreichbarkeit fremder Server versprechen.

## 3. Regulierte Dienste und geschütztes Material (Apple-Punkt 6)

Der untersuchte Funktionsumfang ist private Familienorganisation und Kommunikation. Er bietet keine medizinische Behandlung/Diagnose, Finanzdienstleistung oder Glücksspiel-Funktion. Ein privat eingetragener Arzttermin macht die App nicht zu einem Anbieter medizinischer Leistungen. Eine besondere Zulassung für solche Dienstleistungen wird daher nicht als Nachweis vorgegeben.

Es gibt keinen mitgelieferten Musik-, Film- oder sonstigen lizenzierten Unterhaltungskatalog. Nutzer können eigene Inhalte und Anhänge innerhalb ihrer Familie teilen. Dennoch enthält die App geschützte Open-Source-Komponenten und Schriftdateien; „keinerlei Material Dritter“ wäre deshalb unzutreffend.

| Gegenstand | Vorhandene Grundlage | Noch zu bestätigen |
|---|---|---|
| FamilyNexus-Quellcode | [LICENSE](../LICENSE), AGPL-3.0-or-later | Herausgeberberechtigung und Erfüllung der Lizenzpflichten für die konkrete Distribution |
| Drittbibliotheken, u. a. Matrix/vodozemac | [Abhängigkeitsübersicht](../docs/ABHAENGIGKEITEN.md), [pubspec.lock](../pubspec.lock) | Lizenzinventar des tatsächlichen Builds einschließlich nativer/transitiver Bestandteile; veraltete oder unbekannte Angaben klären |
| Space Grotesk | [OFL-Lizenz](../assets/fonts/OFL-spacegrotesk.txt) | Zuordnung zu den ausgelieferten Schriftdateien |
| IBM Plex Sans / Mono | [Sans-Lizenz](../assets/fonts/OFL-ibmplexsans.txt), [Mono-Lizenz](../assets/fonts/OFL-ibmplexmono.txt) | Zuordnung zu den ausgelieferten Schriftdateien |
| AGPL und App-Store-Distribution | Offener Punkt in [STORE.md](../docs/STORE.md) und [OFFEN.md](../docs/OFFEN.md) | Dokumentierte Klärung durch den Herausgeber; hier keine Kompatibilitätsfreigabe behauptet |
| Verschlüsselungsdokumentation | [Englischer technischer Entwurf](../docs/export-compliance/encryption-description-en.md), [französischer Entwurf](../docs/export-compliance/description-chiffrement-fr.md), [Ablauf/Status](../docs/export-compliance/README.md) | Auf aktuellen Build bringen, Herausgeberangaben ergänzen; tatsächlich erforderliche Unterlagen und vorhandene Bestätigungen in ASC zuordnen |
| Sonstige Marken/Bilder/Inhalte | App-Assets und Store-Materialien | Eigene Rechte bzw. Nutzungsbefugnisse bestätigen; erforderliche zusätzliche Belege beifügen |

Die technischen Exportbeschreibungen sind **keine** Genehmigung oder Registrierungsbescheinigung. Auch ein vorhandenes PDF beweist keine erfolgte Einreichung. Für `RIGHTS_AND_EXPORT_STATUS` ausschließlich bestätigte Fakten verwenden: abgeschlossene Lizenzklärung, Titel/Datum der tatsächlich beigefügten Unterlagen und gegebenenfalls Referenz des Apple-Vorgangs. Keine Zertifikate, CCATS-/ANSSI-Referenzen oder Freigaben erfinden.

## 4. Zuordnung zu Apples sechs Fragen

| Apple-Punkt | Antwort und ergänzender Nachweis |
|---|---|
| 1 Video / Sonderabläufe | Abschnitt 1 im Antworttext; Dokument 03 und tatsächliche Aufnahme einschließlich Registrierung, Anmeldung, Löschung, Nutzerinhalt, Melden/Blockieren |
| 2 Zweck, Zielgruppe, Problem und Nutzen | Abschnitt 2 im Antworttext; Einleitung des Review Guide |
| 3 Einrichtung, Hauptfunktionen, Konten/Dateien | Abschnitt 3 im Antworttext; Review Guide, geprüfte R1/R2-Zugänge und optionale Beispieldatei |
| 4 Dienste/Tools/Plattformen | Abschnitt 4 im Antworttext; Dienstetabelle dieses Dokuments |
| 5 Regionen | Abschnitt 5 im Antworttext; tatsächliche Store-Länderliste und Angaben dieses Dokuments |
| 6 Regulierung / Berechtigungen | Abschnitt 6 im Antworttext; tatsächlich bestätigte Lizenz-/Exportunterlagen und gegebenenfalls weitere Nutzungsnachweise |
