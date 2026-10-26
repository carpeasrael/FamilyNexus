# Maßnahmenplan zur Apple App Review

Stand: 25.10.2026  
Grundlage: Die bereitgestellte Apple-Rückmeldung zum Entwicklerkonto mit begrenzter App-Review-Historie.

## Ziel

Die von Apple angeforderten Informationen vollständig bereitstellen und die Prüfbarkeit der App sicherstellen. Vor der Rückmeldung muss der eingereichte Build auf unterstützten physischen Geräten getestet sein.

Die vollständigen Informationen müssen anschließend sowohl als Antwort in App Store Connect als auch im Feld **„Notizen“ unter „App Review Information“** hinterlegt werden.

## Prioritäten

- **P1:** Vor der Antwort an Apple abschließen.
- **P2:** Unterlagen zusammenstellen; falls zutreffend ebenfalls vor der Antwort abschließen.

## Maßnahmen und To-dos

### 1. Eingereichten Build testen — P1

- [ ] Version und Buildnummer dokumentieren.
- [ ] Installation, App-Start und Hauptfunktionen auf unterstützten physischen Geräten prüfen.
- [ ] Mindestens das Aufnahmegerät mit der neuesten verfügbaren Betriebssystemversion verwenden.
- [ ] Fehler beheben und betroffene Abläufe erneut testen.
- [ ] Testergebnisse und bekannte Einschränkungen dokumentieren.

**Abschlusskriterium:** Der für die Prüfung vorgesehene Build funktioniert zuverlässig; Testergebnisse und bekannte Einschränkungen sind dokumentiert.

### 2. Review-Zugang vorbereiten — P1

- [ ] Falls erforderlich ein dauerhaft nutzbares Testkonto anlegen.
- [ ] Passende Berechtigungen und Beispieldaten bereitstellen.
- [ ] Anmeldung, Serverzugriff und Erreichbarkeit aller relevanten Funktionen prüfen.
- [ ] Erforderliche Einrichtungsschritte dokumentieren.

**Abschlusskriterium:** Apple kann die Hauptfunktionen mit den bereitgestellten Angaben eigenständig prüfen.

### 3. Bildschirmaufnahme erstellen — P1

- [ ] Aufnahme auf einem physischen Gerät mit aktueller Betriebssystemversion erstellen.
- [ ] Aufnahme mit dem Start der App beginnen.
- [ ] Typischen Nutzerablauf einschließlich der Hauptfunktionen vollständig zeigen.
- [ ] Gerät, Betriebssystem, App-Version und Buildnummer dokumentieren.
- [ ] Sicherstellen, dass das Video den tatsächlich zur Prüfung vorgesehenen Build zeigt.

**Abschlusskriterium:** Das Video zeigt den vorgesehenen Build und einen vollständigen, nachvollziehbaren Nutzerablauf.

### 4. Bedingte Abläufe im Video ergänzen — P1

- [ ] Falls vorhanden: Registrierung demonstrieren.
- [ ] Falls vorhanden: Anmeldung demonstrieren.
- [ ] Bei Unterstützung der Kontoerstellung: Kontolöschung demonstrieren. Apple fordert für solche Apps eine Kontolöschung.
- [ ] Bei nutzergenerierten Inhalten: Erstellung beziehungsweise Nutzung sowie Melden und Blockieren demonstrieren.
- [ ] Bei kostenpflichtigen Inhalten oder Funktionen: deren Zugang demonstrieren.
- [ ] Fehlende erforderliche Funktionen zuvor umsetzen und testen.
- [ ] Nicht zutreffende Punkte in der Antwort ausdrücklich benennen.

**Abschlusskriterium:** Alle zutreffenden Abläufe sind im Video enthalten; nicht zutreffende Punkte sind ausdrücklich gekennzeichnet.

### 5. Zweck und Zielgruppe beschreiben — P1

- [ ] Beschreiben, für wen die App gedacht ist.
- [ ] Das konkrete Problem erläutern, das die App löst.
- [ ] Nutzen und wichtigste Funktionen erklären.
- [ ] Beschreibung mit dem Funktionsumfang des eingereichten Builds abgleichen.

**Abschlusskriterium:** Eine kurze, konkrete Beschreibung liegt vor und stimmt mit dem eingereichten Build überein.

### 6. Prüfanleitung schreiben — P1

- [ ] Eine nummerierte Anleitung vom ersten App-Start bis zu den Hauptfunktionen erstellen.
- [ ] Erforderliche Anmeldedaten und Rollen ergänzen.
- [ ] Voraussetzungen und notwendige Einstellungen beschreiben.
- [ ] Gegebenenfalls Beispieldateien bereitstellen und deren Verwendung erklären.
- [ ] Anleitung durch eine Person ohne Vorwissen nachvollziehen lassen.

**Abschlusskriterium:** Eine Person ohne Vorwissen kann die beschriebenen Abläufe vollständig nachvollziehen.

### 7. Externe Dienste auflisten — P1

- [ ] Alle für die Kernfunktionen verwendeten externen Dienste, Tools und Plattformen erfassen.
- [ ] Backend und Hosting berücksichtigen.
- [ ] Authentifizierungsdienste berücksichtigen.
- [ ] Datenanbieter berücksichtigen.
- [ ] Zahlungsdienste berücksichtigen.
- [ ] KI-Dienste berücksichtigen.
- [ ] Für jeden verwendeten Dienst Anbieter und Verwendungszweck nennen.
- [ ] Falls keine entsprechenden externen Dienste verwendet werden, dies ausdrücklich bestätigen.

**Abschlusskriterium:** Eine vollständige Liste der tatsächlich verwendeten Dienste liegt vor.

### 8. Regionale Unterschiede klären — P1

- [ ] Prüfen, ob Funktionen, Inhalte oder Verfügbarkeit vom Land beziehungsweise von der Region abhängen.
- [ ] Bestehende Unterschiede und deren Auswirkungen beschreiben.
- [ ] Alternativ ausdrücklich bestätigen, dass die App über alle Regionen hinweg einheitlich funktioniert.

**Abschlusskriterium:** Eine eindeutige Aussage zur regionalen Funktionsweise liegt vor.

### 9. Nachweise prüfen und zusammenstellen — P2

- [ ] Prüfen, ob die App in einer stark regulierten Branche eingesetzt wird.
- [ ] Prüfen, ob geschütztes Material Dritter enthalten ist.
- [ ] Falls zutreffend: relevante Berechtigungen, Lizenzen oder sonstige Nachweise zusammenstellen.
- [ ] Andernfalls nachvollziehbar angeben, dass dieser Punkt nicht zutrifft.

**Abschlusskriterium:** Erforderliche Nachweise liegen vor oder die Nichtanwendbarkeit ist erklärt.

### 10. Review-Paket vervollständigen — P1

- [ ] Video bereitstellen und Zugriff testen.
- [ ] Beschreibung zu Zweck und Zielgruppe ergänzen.
- [ ] Prüfanleitung einschließlich erforderlicher Zugangsdaten und Beispieldateien ergänzen.
- [ ] Liste externer Dienste ergänzen.
- [ ] Angaben zu regionalen Unterschieden ergänzen.
- [ ] Gegebenenfalls Berechtigungsnachweise ergänzen.
- [ ] Alle Links und Beispieldateien überprüfen.

**Abschlusskriterium:** Alle sechs Apple-Fragen sind vollständig beantwortet und sämtliche Materialien sind erreichbar.

### 11. In App Store Connect hinterlegen — P1

- [ ] Vollständige Antwort an App Review senden.
- [ ] Dieselben Informationen zusätzlich in den Review-Notizen speichern.
- [ ] Falls Fehlerkorrekturen einen neuen Build erfordern: Angaben und Video auf diesen Build abstimmen.
- [ ] Abschließend Konsistenz von Buildnummer, Video, Anleitung und Zugangsdaten prüfen.

**Abschlusskriterium:** Antwort und Review-Notizen sind vollständig, konsistent und beziehen sich auf den richtigen Build.

## Zuordnung zu den sechs Apple-Anforderungen

| Apple-Anforderung | Maßnahmen |
| --- | --- |
| 1. Bildschirmaufnahme auf physischem Gerät einschließlich zutreffender Sonderabläufe | 1, 3, 4 |
| 2. Zweck, Zielgruppe, gelöstes Problem und Nutzen | 5 |
| 3. Einrichtung und Zugang zu Hauptfunktionen, Zugangsdaten und Beispieldateien | 2, 6 |
| 4. Externe Dienste, Tools und Plattformen | 7 |
| 5. Regionale Unterschiede oder einheitliche Funktionsweise | 8 |
| 6. Nachweise bei regulierten Branchen oder geschütztem Material Dritter | 9 |

Die Maßnahmen 10 und 11 führen die Ergebnisse zusammen und stellen die vollständige Rückmeldung sicher.

## Checkliste vor dem Absenden

- [ ] Physisches Gerät, aktuelle Betriebssystemversion und getesteter Build dokumentiert.
- [ ] Video beginnt mit dem App-Start und zeigt alle zutreffenden Abläufe.
- [ ] Testkonto, Berechtigungen und Beispieldaten funktionieren.
- [ ] Zweck, Zielgruppe, Problem und Nutzen beschrieben.
- [ ] Einrichtung und Hauptfunktionen Schritt für Schritt erklärt.
- [ ] Externe Dienste vollständig aufgeführt.
- [ ] Regionale Unterschiede beschrieben oder ausgeschlossen.
- [ ] Berechtigungsnachweise beigefügt oder „nicht zutreffend“ begründet.
- [ ] Video und Links ohne zusätzliche Freigabe erreichbar.
- [ ] Vollständige Informationen in Antwort und Review-Notizen hinterlegt.

## Umgang mit Zugangsdaten

Nur ein vorgesehenes Review-Testkonto bereitstellen. Produktive Benutzerkonten, API-Schlüssel und administrative Zugangsdaten gehören nicht in die Unterlagen.
