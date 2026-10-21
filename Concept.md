# Konzeptentwurf: Familienterminplaner mit Matrix-Messenger

Oct 20, 2026 · @CarpeAsrael

> **Änderung Oct 21, 2026 (später):** Einstellungen liegen im Burger-Menü rechts oben statt in der Fußleiste; die Neon-Akzentfarbe ist frei wählbar (E-46).
>
> **Änderung Oct 21, 2026:** Erweitert um Online-Status der Familienmitglieder, Einzelchats zwischen Mitgliedern (vorher „optional“) und einen gemeinsamen Einkaufszettel (vorher unter „Später denkbar“). Betroffen sind Funktionsumfang, Rollen, Matrix-Modell, Bedrohungsmodell, Hauptbildschirme und Datenschutz; Begründungen in `docs/ENTSCHEIDUNGEN.md` (E-38 bis E-42).

## Vision & Ziele

Die App (Arbeitstitel „FamilyNexus“) vereint einen Familienkalender, einen Messenger und einen gemeinsamen Einkaufszettel in einer Anwendung, deren Daten ausschließlich auf den Geräten der Familie liegen und nur Ende-zu-Ende-verschlüsselt über das Matrix-Protokoll wandern.

**Zielgruppe:** Familien und Haushalte, die Termine koordinieren wollen, ohne ihre Daten einem zentralen Anbieter anzuvertrauen.

**Leitprinzipien**

- **Local-first:** Alle Daten liegen verschlüsselt auf dem Gerät; die App funktioniert auch offline.
- **E2EE by default:** Kein Klartext verlässt das Gerät, weder Chat noch Termine.
- **Server austauschbar:** Standardmäßig ein öffentlicher Matrix-Server, optional ein eigener Homeserver.
- **Datensparsamkeit:** Keine Telemetrie, keine Werbung, keine Analyse-SDKs.
- **Eine Codebasis:** Android, Windows, Linux, macOS, iOS und iPadOS.
- **Zweisprachig:** Deutsch und Englisch von Anfang an.

## Funktionsumfang

Zwei Rollen steuern die Familie: Mitglieder nutzen Kalender und Chat, Moderatoren verwalten zusätzlich die Gruppe.

### Rollen und Rechte

| Funktion | Mitglied | Moderator |
| --- | --- | --- |
| Eigene Termine anlegen, ändern, löschen | Ja | Ja |
| Private Termine (nur selbst sichtbar) | Ja | Ja |
| Geteilte Termine (für die Familie sichtbar) | Ja | Ja |
| Chat lesen und schreiben (Familienchat und Einzelchats) | Ja | Ja |
| Einkaufszettel ansehen und ändern | Ja | Ja |
| Online-Status der anderen sehen, eigenen Status teilen oder verbergen | Ja | Ja |
| Neue Mitglieder einladen | Nein | Ja |
| Mitglied zum Moderator ernennen | Nein | Ja |
| Mitglied entfernen | Nein | Ja |
| Server und Familienname konfigurieren | Nein | Ja |

### Termine

- **Felder:** Titel, Beginn und Ende, ganztägig, Ort, Notiz, Wiederholung, Teilnehmer, Farbe, Sichtbarkeit.
- **Privat:** Der Termin bleibt nur auf den eigenen Geräten, wird nie an Matrix gesendet und ist für andere nicht sichtbar.
- **Shared:** Der Termin wird verschlüsselt in den Familienraum gesendet; Mitglieder sehen ihn und können antworten (Zusage, Absage, Vielleicht).
- **Wiederholungen:** täglich, wöchentlich, monatlich, jährlich, jeweils mit Ausnahmen.
- **Ansichten:** Tag, Woche, Monat, Agenda; Filter nach Person.

### Erinnerungen

- Pro Termin eine oder mehrere Erinnerungen (z. B. 10 Minuten, 1 Stunde, 1 Tag vorher).
- Erinnerungen sind **lokale Benachrichtigungen** auf dem jeweiligen Gerät. So verrät keine Push-Nachricht Termininhalte an Dritte.
- Standard-Erinnerung pro Person einstellbar; geteilte Termine erlauben persönliche Erinnerungen pro Mitglied.

### Messenger

- Gruppenchat der Familie und **Einzelchats** zwischen beigetretenen Mitgliedern (je Paar ein eigener verschlüsselter Raum; nach dem Entfernen eines Mitglieds entfällt das Gespräch).
- Nachrichten, Bilder, Dateien, Antworten, Reaktionen.
- Termine lassen sich im Chat teilen und direkt zu- oder absagen.

### Online-Status

- Die Familie sieht, wer gerade online ist: **Online** (App im Vordergrund, Lebenszeichen alle 2 Minuten), **Offline** (mit „zuletzt online vor …“) oder **Status unbekannt**. Angezeigt in der Mitgliederliste, im Chat (Gesprächsleiste, Einzelchat) und auf „Heute“; immer als Text und Form, nie nur als Farbe.
- Der Status wird nur als Ende-zu-Ende-verschlüsselte Gerätenachricht an Geräte beigetretener Familienmitglieder gesendet und nie gespeichert. Er ist in den Einstellungen abschaltbar („Online-Status teilen“); dann gilt man für andere als offline.

### Einkaufszettel

- Eine gemeinsame Liste je Familie: Eintrag (Text, Menge), abhaken, bearbeiten, löschen, „Erledigte entfernen“. Jedes Mitglied darf jeden Eintrag ändern; gleichzeitige Änderungen werden deterministisch zusammengeführt (höhere Version, dann spätere Zeit, dann Absender-ID).
- Die Liste wird wie geteilte Termine verschlüsselt im Familienraum übertragen, liegt verschlüsselt auf dem Gerät und funktioniert offline (Warteschlange). Obergrenzen: 300 aktive Einträge, 1000 Datensätze.

### Einladungen

- Moderator erzeugt einen zeitlich begrenzten Einladungslink oder QR-Code.
- Beitritt nur nach Bestätigung durch einen Moderator; zusätzlich Geräteverifizierung per Emoji-Vergleich oder QR-Scan.

## Architektur

Jede Familie ist ein verschlüsselter Matrix-Raum: Die Geräte halten die Daten, der Server vermittelt nur.

&#91;embedded content: Architektur · zwei Geräte und ein Homeserver\]

Lokale Datenbank und Matrix-Schicht liegen auf jedem Gerät; der Homeserver leitet verschlüsselte Ereignisse weiter und kann sie nicht lesen.

### Matrix-Modell

| Element | Umsetzung |
| --- | --- |
| Familie | Ein privater, verschlüsselter Matrix-Raum; Beitritt nur per Einladung |
| Chat | Reguläre Matrix-Nachrichten im Familienraum, Einzelchats als eigene verschlüsselte Räume je Mitgliederpaar (`is_direct`, nur mit aktuellen Mitgliedern; Einladungen Fremder werden ignoriert) |
| Online-Status | Verschlüsselte Gerätenachricht (Olm) `de.inneso.familynexus.presence` an die Geräte beigetretener Mitglieder; nur im Arbeitsspeicher, 5 Minuten gültig, abschaltbar |
| Einkaufszettel | Eigener verschlüsselter Ereignistyp `de.inneso.familynexus.shopping` im Familienraum mit Eintrags-ID, Version, Zeitstempel und Löschmarke; lokal verschlüsselt gespeichert |
| Geteilter Termin | Eigener verschlüsselter Ereignistyp im Raum mit Termin-ID, Version und Zusagestatus |
| Privater Termin | Nur lokal gespeichert; Abgleich zwischen eigenen Geräten über einen privaten Raum, den nur das eigene Konto kennt |
| Rollen | Matrix-Power-Levels: Mitglied 0, Moderator 50; das Recht, Rollen zu ändern, liegt ebenfalls auf 50 |
| Einladungen | Matrix-Einladung, zusätzlich Link oder QR-Code mit Ablaufzeit |
| Konflikte | Versionszähler pro Termin; bei gleichzeitiger Änderung gewinnt die neuere Version, die ältere bleibt im Verlauf |
| Offline | Lokale Warteschlange, Versand sobald eine Verbindung besteht |

### Serverwahl

- Bei der Ersteinrichtung ist ein öffentlicher Matrix-Server voreingestellt; die URL lässt sich durch einen eigenen Homeserver ersetzen.
- Die App prüft Erreichbarkeit und Protokollversion des Servers und zeigt dessen Betreiber an.
- Ein späterer Serverwechsel erfordert eine Migration der Familie (neuer Raum, neue Einladungen); dieser Ablauf ist einzuplanen.

## Sicherheit & Datenschutz

Sicherheit hat Vorrang vor Komfort: Verschlüsselung ist nicht abschaltbar, und Klartext existiert nur im Arbeitsspeicher der laufenden App.

### Speicherung auf dem Gerät

- Lokale Datenbank (SQLite) mit vollständiger Verschlüsselung, z. B. SQLCipher mit AES-256.
- Der Datenbankschlüssel liegt im Schlüsselspeicher des Betriebssystems: Keychain (macOS, iOS, iPadOS), Keystore (Android), Credential Manager bzw. DPAPI (Windows), Secret Service (Linux).
- Optionale App-Sperre per PIN, Passwort oder Biometrie; automatische Sperre nach Inaktivität.
- Anhänge und Medien werden im Dateisystem separat verschlüsselt abgelegt.
- Keine Klartext-Vorschauen in Benachrichtigungen, Task-Switcher oder Backups (Screenshot-Schutz auf Wunsch).

### Ende-zu-Ende-Verschlüsselung

- Matrix-E2EE mit Olm (1:1) und Megolm (Räume) für Chat **und** Termine; der Server sieht nur verschlüsselte Ereignisse.
- Termine werden als verschlüsselte Raum-Ereignisse im Familienraum übertragen.
- Geräteverifizierung per Cross-Signing; unverifizierte Geräte erhalten keine Schlüssel.
- Beim Entfernen eines Mitglieds werden die Raumschlüssel rotiert, damit ausgeschiedene Personen keine neuen Inhalte lesen können.
- Schlüssel-Backup nur mit eigener Wiederherstellungsphrase; der Server speichert nur verschlüsselte Sicherungen.

### Bedrohungsmodell und Grenzen

| Risiko | Gegenmaßnahme | Restrisiko |
| --- | --- | --- |
| Mitlesen auf dem Server | E2EE, Server sieht nur Chiffretext | Metadaten (wer, wann, Raumgröße, Takt der Statusmeldungen) bleiben sichtbar |
| Gefälschter Online-Status | Nur verschlüsselt eingegangene Meldungen aktueller Familienmitglieder zählen; Format streng geprüft | Ein Mitglied kann nur seinen eigenen Status falsch melden |
| Verlust oder Diebstahl des Geräts | Datenbankverschlüsselung, App-Sperre, Fernabmeldung der Sitzung | Schwache PIN schwächt den Schutz |
| Fremdes Gerät in der Familie | Verifizierung, Moderator kann Geräte sperren | Nutzer überspringen die Verifizierung |
| Kompromittierter öffentlicher Server | Eigener Homeserver möglich; E2EE schützt Inhalte | Server kann Dienst verweigern |
| Schadcode über Anhänge | Keine automatische Ausführung, Typprüfung, Größenlimit | Zero-Day im Betriebssystem |
| Lieferkette (Abhängigkeiten) | Gepinnte Versionen, SBOM, regelmäßige Audits | Neue Schwachstellen in Bibliotheken |

### Datenschutz (DSGVO)

- Datenminimierung: Es wird nur gespeichert und übertragen, was die Funktion braucht. Der Online-Status verlässt das Gerät nur verschlüsselt, wird nie gespeichert und lässt sich abschalten.
- Löschfunktion: Ein Mitglied kann sein Konto, seine Termine und lokale Daten vollständig löschen; Nachrichten auf anderen Geräten lassen sich technisch nicht erzwingen zu löschen und werden entsprechend ausgewiesen.
- Kinder: Konten Minderjähriger laufen über Einladung und Freigabe eines Moderators; Hinweis auf Einwilligung der Sorgeberechtigten ist einzuplanen.
- Transparenz: Datenschutzerklärung in beiden Sprachen, Hinweis auf den gewählten Server und dessen Betreiber bei der Einrichtung.
- Vor der Veröffentlichung: unabhängiger Sicherheits-Review und Penetrationstest.

## Technologie-Stack & Plattformen

Empfehlung: Flutter mit der Matrix-Bibliothek des Matrix-Dart-SDK, weil eine Codebasis alle sechs Zielplattformen abdeckt und die Glas-/Neon-Optik sich mit eigener Rendering-Engine pixelgenau umsetzen lässt. Die Einschätzung zu Reifegrad und Funktionsumfang der Bibliotheken ist vor Projektstart zu prüfen.

### Framework-Optionen

| Option | Plattformen | Stärken | Schwächen |
| --- | --- | --- | --- |
| Flutter (Dart) + Matrix-Dart-SDK | Android, iOS, iPadOS, Windows, Linux, macOS | Eine Codebasis, eigene Rendering-Engine für Glas-/Neon-Effekte, vorhandenes Matrix-SDK mit E2EE | Native Besonderheiten (Benachrichtigungen, Hintergrundbetrieb) brauchen Plugins |
| Kotlin Multiplatform + Compose | Android, iOS, Desktop | Native Anbindung, Matrix Rust SDK nutzbar | Desktop-Reife und Linux-Support geringer, Glas-Effekte aufwändiger |
| Tauri + Web-UI + Matrix Rust SDK | Desktop gut, Mobile jünger | Rust-Kern mit bewährter E2EE, leichtgewichtig | Mobile-Support weniger ausgereift |
| Native je Plattform | alle | Beste Systemintegration | Sechs Codebasen, hoher Pflegeaufwand |

### Architekturbausteine

- **Präsentation:** Flutter-UI mit zentralem Design-System (Farben, Glas, Neon als Tokens).
- **Domäne:** Kalender-Logik (Wiederholungen, Zeitzonen, Erinnerungen), unabhängig von der UI testbar.
- **Daten:** Verschlüsselte lokale Datenbank als einzige Quelle der Wahrheit; Synchronisation über Matrix.
- **Matrix-Schicht:** Anmeldung, Räume, E2EE, Ereignisse; Server-URL konfigurierbar.
- **Lokalisierung:** ARB-Dateien für Deutsch und Englisch, Datums- und Zeitformate nach Gerätesprache.
- **Benachrichtigungen:** Lokal geplante Erinnerungen; Push für neue Chat-Nachrichten über UnifiedPush bzw. APNs mit inhaltsleerem Payload.

### Plattformhinweise

- **iOS/iPadOS/macOS:** Veröffentlichung über App Store; Hintergrundlimits beachten.
- **Android:** Zuverlässige Erinnerungen über exakte Alarme; Akku-Optimierung der Hersteller berücksichtigen.
- **Windows/Linux:** Paketierung als MSIX bzw. Flatpak/AppImage; Tray-Symbol für Erinnerungen.
- **iPad und große Displays:** Adaptive Zwei-Spalten-Ansicht (Kalender plus Chat).

## UX & Design

Die Oberfläche kombiniert Glas (Glassmorphism) mit Neon-Akzenten auf dunklem Grund; als Farbbasis dient die AURORA-Palette (Teal #0f766e und #2dd4bf), ergänzt um Neon-Signalfarben.

### Designsprache

- **Glas:** Halbtransparente Flächen mit Hintergrundunschärfe, feine helle Kanten, weiche Schatten.
- **Neon:** Leuchtende Akzente für Auswahl, Fokus, aktuelle Zeit und Erinnerungen; Teal als Primärfarbe, Magenta und Violett als Sekundärakzente.
- **Typografie:** Space Grotesk für Überschriften, IBM Plex Sans für Text, IBM Plex Mono für Uhrzeiten und Codes.
- **Wählbare Akzentfarbe:** In den Einstellungen wählt jeder Nutzer seine Neon-Kontrastfarbe (Türkis als Standard, außerdem Magenta, Violett, Himmelblau, Limette, Orange, Rosé, Grün); sie färbt Schaltflächen, Auswahl und Hervorhebungen im hellen und dunklen Design und erfüllt überall WCAG AA (je Farbe eine leuchtende und eine abgedunkelte Variante).
- **Farbe pro Person:** Jedes Familienmitglied erhält eine Neonfarbe für seine Termine.
- **Modi:** Dunkel als Standard, helle Variante mit gedämpften Glasflächen.

### Hauptbildschirme

| Bildschirm | Inhalt |
| --- | --- |
| Heute | Nächste Termine, anstehende Erinnerungen, wer online ist, offene Einkaufseinträge, ungelesene Nachrichten |
| Kalender | Tag-, Wochen-, Monats- und Agenda-Ansicht, Filter nach Person |
| Termin | Anlegen und Bearbeiten, Schalter Privat/Shared, Erinnerungen, Teilnehmer |
| Chat | Familienraum und Einzelchats (Gesprächsleiste mit Online-Status und Ungelesenem), Termine als Karten im Verlauf |
| Einkauf | Gemeinsamer Einkaufszettel: offene und erledigte Einträge, Menge, Bearbeiten, „Erledigte entfernen“ |
| Familie | Mitgliederliste mit Online-Status und „Nachricht schreiben“, Rollen, Einladungen, Geräteverifizierung (Moderator) |
| Einstellungen | Sprache, Server, Sperre, Online-Status teilen, Benachrichtigungen, Backup, Design inkl. Akzentfarbe; erreichbar über das Burger-Menü rechts oben (nicht in der unteren Navigationsleiste) |

### Barrierefreiheit und Sprache

- Kontrast nach WCAG 2.2 AA: Glasflächen erhalten einen Mindestkontrast zum Text, Neon dient nie als alleiniger Informationsträger.
- Option „Effekte reduzieren“ (weniger Unschärfe und Leuchten), Unterstützung für Bildschirmleser und dynamische Schriftgrößen.
- Deutsch und Englisch umschaltbar; Standard folgt der Gerätesprache, Texte liegen vollständig in Übersetzungsdateien.
- Ersteinrichtung in vier Schritten: Sprache, Server (Standard oder eigener), Konto, Familie gründen oder beitreten.

## Roadmap, Risiken und offene Fragen

Die Umsetzung läuft in vier Phasen; jede endet an einem Freigabe-Kriterium, das Sicherheit vor Funktionsumfang stellt.

&#91;embedded content: Roadmap · 4 Phasen, 4 Freigabe-Kriterien\]

Der Zeitplan hängt von Teamgröße und Framework-Entscheidung ab und wird nach Abstimmung ergänzt.

### Verbesserungsvorschläge

- **Dritte Sichtbarkeitsstufe „Beschäftigt“:** Private Termine können ohne Titel und Details als belegte Zeit erscheinen, damit sich Termine besser koordinieren lassen.
- **Mindestens zwei Moderatoren:** Die App empfiehlt beim Einrichten einen zweiten Moderator, damit die Familie bei Geräteverlust handlungsfähig bleibt.
- **Verschlüsseltes Backup und Export:** Export von Terminen als ICS-Datei und eines vollständigen Sicherungsarchivs, geschützt mit einem eigenen Passwort. ICS-Importe werden als nicht vertrauenswürdig behandelt und geprüft.
- **Vorlage für den eigenen Server:** Eine kurze Anleitung samt Konfigurationsvorlage für einen eigenen Matrix-Homeserver, damit die Option wirklich nutzbar ist.
- **Sicherheitsstatus sichtbar machen:** Eine Anzeige in den Einstellungen zeigt, welche Geräte verifiziert sind und ob das Schlüssel-Backup eingerichtet ist.
- **Später denkbar:** Weitere geteilte Listen (Aufgaben) und ein eingeschränkter Modus für Kinder. Der Einkaufszettel ist umgesetzt (Oct 21, 2026).

### Risiken

| Risiko | Auswirkung | Gegenmaßnahme |
| --- | --- | --- |
| Reife der Matrix-Bibliothek je Plattform | E2EE-Funktionen fehlen oder verhalten sich unterschiedlich | Früher Prototyp in Phase 1, Alternative Rust-SDK offen halten |
| Zuverlässigkeit lokaler Erinnerungen | Termine werden ohne Warnung verpasst, besonders auf Android und iOS | Systemspezifische Tests, Neuplanung nach Neustart, Hinweis bei fehlender Berechtigung |
| Öffentlicher Standardserver | Ausfall, Regeln für Registrierung oder Ratenbegrenzung | Hinweis bei der Einrichtung, einfacher Wechsel auf eigenen Server |
| Verlust aller Geräte eines Mitglieds | Schlüssel und private Termine weg | Schlüssel-Backup mit Wiederherstellungsphrase, verschlüsseltes Export-Archiv |
| Metadaten auf dem Server | Rückschlüsse auf Familienstruktur und Aktivität | Transparenz in der Datenschutzerklärung, eigener Server als Option |
| Aufwand für sechs Plattformen | Verzögerungen, uneinheitliche Qualität | Eine Codebasis, gemeinsame Tests, Plattformen nacheinander freigeben |

### Offene Fragen

- [ ] **Design:** Ich habe die AURORA-Farbwelt mit Glas und Neon kombiniert. Soll die App das inneso-Branding (Name, Logo) tragen oder neutral bleiben?
- [ ] **Private Termine:** Sollen sie zwischen den eigenen Geräten eines Mitglieds synchronisiert werden (Annahme: ja, über einen privaten Raum)?
- [ ] **Moderatorenrechte:** Dürfen Moderatoren geteilte Termine anderer ändern oder löschen, oder nur Mitglieder entfernen?
- [ ] **Konten:** Legt die App neue Matrix-Konten an, oder melden sich Nutzer mit bestehenden Konten an?
- [ ] **Minderjährige:** Sollen Kinder Mitglieder sein können, und braucht es dafür eine eigene Einschränkung?
- [ ] **Verbreitung:** Open Source oder geschlossen, Veröffentlichung über die App Stores oder auch direkter Download?
- [ ] **Matrix-Standardserver:** Welcher öffentliche Server soll voreingestellt sein?
