# Bildschirmaufnahme und Geräteprüfung

Stand: 30.10.2026 · **Protokollvorlage, noch nicht durchgeführt.**

Bezug: Apple-Punkt 1 und „Prevent Common Issues“. Der [bestehende Verifikationsplan TP-FN-VR-121](../Test-Apple/verification_1.2.1/Testplan_Verifikation_App_Review.md) enthält die ausführlichen Prüfschritte; der [Gesamtplan TP-FN-001](../Test-Apple/Testplan_FamilyNexus.md) deckt die Funktionsprüfung ab. Die folgende Vorlage bündelt die für die Antwort benötigten Nachweise.

## Geräte, Build und Aufnahme festhalten

| Angabe | Ergebnis / Nachweis |
|---|---|
| Tester und Datum | offen |
| Eingereichte Plattform(en) | offen |
| App-Version und Build laut App Store Connect | offen; Repository derzeit 1.2.1 (21) |
| Version laut App-Menü | offen |
| Installationsquelle / TestFlight-Build | offen |
| Physisches Aufnahmegerät: Hersteller/Modell | offen |
| Betriebssystemversion einschließlich Build | offen |
| Neueste öffentliche OS-Version am Aufnahmetag geprüft | offen; System-Softwareupdate und aktuelle Apple-Veröffentlichung abgleichen |
| Zweites Gerät für R2: Modell, OS, App-Build | offen |
| Physischer Mac, falls macOS eingereicht: Modell/OS/Build | offen |
| Video-Dateiname, Dauer, Dateigröße, SHA-256 | offen |
| Video-Link bzw. App-Review-Anhang | offen |
| Link ohne Anmeldung/Freigabeanfrage geprüft: Datum/Ergebnis | offen |
| Geräte-Testreport und Ergebnis | offen |
| Verbleibende Befunde / Nachtests | offen |

Die Aufnahme muss den tatsächlich eingereichten Build auf einem physischen Gerät zeigen. Simulatoraufnahmen und Bilder des Repository-Vorschaumodus ersetzen diesen Nachweis nicht. Eine Beta-Version des Betriebssystems nicht als neueste öffentliche Version ausgeben. Ist zusätzlich macOS eingereicht, entsprechend dem vorhandenen Projekt-Testplan einen eigenen Durchlauf und eine Aufnahme auf einem physischen Mac ergänzen.

## Vorbereitung

1. **R1** als Moderator und **R2** als Mitglied derselben Beispielfamilie auf matrix.org einrichten. Beide Konten und ihre individuellen Notfall-Schlüssel auf einem frischen Gerät prüfen. Kein Ablauf darf vom Zugriff auf ein privates Entwicklergerät abhängig sein.
2. Beispieldaten gemäß [Review Guide](02_Review_Guide_EN.md) anlegen. Als R2 eine Nachricht `Test message for App Review` für Melden/Blockieren vorbereiten. Danach R1 auf dem zweiten Gerät anmelden und verifizieren, damit es in Szene 09 die Freischaltung bestätigen kann. Vor Szene 11 auf dem zweiten Gerät wieder R2 anmelden.
3. Ein separates **W1-Wegwerfkonto** zur Registrierung und späteren Löschung vorsehen, einschließlich erreichbarem Test-Postfach. W1 erst während der Aufnahme anlegen. R1/R2 nicht löschen.
4. Aufnahmegerät auf Englisch stellen, private Benachrichtigungen unterdrücken, ausreichend Speicher/Akku sicherstellen. Browser bei matrix.org aus einer anderen Sitzung abmelden. App auf den Willkommenszustand bringen und beenden; dazu ausschließlich Testdaten verwenden.
5. Passwörter und Notfall-Schlüssel nicht in öffentlich zugänglichen Videos zeigen. **Das Notfall-Schlüssel-Feld ist im aktuellen Code nicht verdeckt.** Deshalb R1 in Szene 09 über ein bereits verifiziertes zweites Gerät freischalten (Emoji-Vergleich), ohne seinen Schlüssel einzublenden. Den für Apple dokumentierten Zugang mit Notfall-Schlüssel separat ohne Aufnahme prüfen. Vor Veröffentlichung die gesamte Aufnahme ansehen. W1-Schlüssel gehören nur zu dem anschließend gelöschten Wegwerfkonto.
6. Die nachstehende Aufnahme ist als zusammenhängender, ungeschnittener Ablauf vorgesehen, entsprechend dem vorhandenen Projekt-Testplan. Das ist die gewählte Nachweisform; die bereitgestellte Apple-Anfrage selbst schreibt keine bestimmte Videolänge vor.

## Aufnahmedrehbuch

Videostellen erst nach der Aufnahme eintragen. Alle Ergebnisse beginnen mit „offen“.

| Szene | Auf dem Aufnahmegerät zeigen | Erwarteter Nachweis | Videostelle / Ergebnis |
|---|---|---|---|
| 01 App-Start | Bildschirmaufnahme starten, Home-Bildschirm zeigen, App-Symbol antippen | Aufnahme beginnt mit dem tatsächlichen App-Start | offen |
| 02 Registrierung W1 | Start a new family → Name → Create account at matrix.org; Anbieter-Registrierung vollständig abschließen | Kontoanlage einschließlich tatsächlich verlangter E-Mail-/CAPTCHA-Schritte und Rückkehr zur App | offen |
| 03 Schlüsselsicherung | Create emergency key → sicher aufbewahren und bestätigen → Next | Verpflichtende Sicherung und Fortsetzung | offen |
| 04 Familie | Demo family → Create family → Later | Hauptansicht einer neu angelegten Familie | offen |
| 05 Kalender | Gemeinsamen Termin morgen anlegen, speichern, öffnen; Ansichten wechseln | Tatsächlicher Kalenderinhalt und Bearbeitung | offen |
| 06 Chat und Einkauf | Nachricht senden, Einkaufsartikel hinzufügen und abhaken | Nutzerinhalte und typischer Familienablauf | offen |
| 07 Build | App-Menü mit Versions-/Buildanzeige zeigen | Übereinstimmung mit App Store Connect | offen |
| 08 W1 löschen | Settings → Account → Delete account → Open deletion page → Löschung beim Anbieter bestätigen → zurück → gegebenenfalls Check deletion | Vollständiger Löschablauf und Rückkehr zu Welcome | offen |
| 09 R1 anmelden | I already have an account → Sign in at matrix.org → Browser-Anmeldung → Unlock this device → Bestätigung mit zweitem R1-Gerät / Emoji-Vergleich | Anmeldung und Entschlüsselung; R1-Schlüssel bleibt außerhalb des Videos | offen |
| 10 Beispieldaten / Rollen | Today, Family, Kalender und Chat zeigen | R1 Moderator, R2 Mitglied; gemeinsame Inhalte vorhanden | offen |
| 11 Aufgaben | Menü → Tasks; als R1 Liste R2 zuweisen, auf G2 als R2 abhaken; Synchronisation/Verlauf auf Aufnahmegerät zeigen | Rollenabhängige Hauptfunktion praktisch demonstriert | offen |
| 12 Nachricht melden | R2-Nachricht lange drücken → Report message → Grund → Text `Review demo, please ignore` → Report | Erfolgsanzeige; tatsächliche Meldung an Serverbetreiber als Test gekennzeichnet | offen |
| 13 Blockieren | Block sender oder Mitglied-Menü → Block | R2-Nachrichten/Einzelchat werden auf diesem Gerät ausgeblendet | offen |
| 14 Entsperren / Moderation | Settings → Blocked members → Unblock; in Family Verwaltungsmenü zeigen, R2 nicht entfernen | Blockierung aufgehoben; Moderator-Steuerung sichtbar | offen |
| 15 Ende | Zur Hauptansicht zurück, Aufnahme beenden | Lesbarer Abschluss | offen |

**Kostenpflichtige Funktionen:** Im untersuchten Quellstand nicht vorhanden. Deshalb kein Kaufablauf im Video; im Antworttext ausdrücklich als nicht zutreffend genannt. Ein möglicher Downloadpreis im Store ist separat von In-App-Funktionen zu prüfen.

**Abweichung zu S-09 des bestehenden Verifikationsplans:** Dieser schlägt die Eingabe des dauerhaften R1-Schlüssels im Video vor, fordert zugleich dessen Unsichtbarkeit. Wegen des unmaskierten Eingabefelds verwendet dieses Drehbuch die vorhandene Geräteverifizierung. Im Report diese Abweichung und den erfolgreichen separaten Test der Schlüsselanmeldung dokumentieren. Apples eigenständiger Review-Zugang bleibt die Schlüsselanmeldung aus den Notizen; Apple benötigt kein zweites Entwicklergerät.

Nach Szene 08 zusätzlich mit W1 eine erneute Anmeldung beim Anbieter versuchen und deren Ablehnung dokumentieren. Der Willkommensbildschirm allein beweist nur die beendete App-Sitzung. Nach dem Video R1/R2 erneut prüfen und sämtliche Testblockierungen aufheben.

## Geräte-QA und Abgleich vor der Rückmeldung

| Prüfung | Erwartetes Ergebnis | Ergebnis / Beleg |
|---|---|---|
| Vollständiger TP-FN-001 auf den eingereichten Geräteplattformen | Tatsächlich eingereichter Build geprüft; offene Schritte und Fehler nachvollziehbar geklärt | offen |
| Frische Installation, Start, Browser-Rückkehr, Entschlüsselung | Keine Abstürze oder Sackgassen; ohne manuelle Entwicklerhilfe nutzbar | offen |
| Registrierung und Löschung bei matrix.org | Beide vollständig erfolgreich, einschließlich Anmeldung nach Löschung abgelehnt | offen |
| Beide Rollen und Beispieldaten | R1/R2 mit bereitgestellten Zugangsdaten und Schlüsseln unabhängig nutzbar | offen |
| Kalender, Chat/Anhänge, Einkauf, Aufgaben, Familie | Erstellung/Änderung und Synchronisation zwischen zwei Konten funktionieren | offen |
| Melden/Blockieren/Entsperren | Erfolgreiche Meldung; gerätelokale Blockierung und Rücknahme sichtbar | offen |
| Offline/erneut online | Vorhandene lokale Daten sichtbar, kein Absturz, spätere Synchronisation | offen |
| Erinnerungen, Berechtigungen, App-Sperre | Auf echtem Gerät geprüft, Hinweisdialoge vollständig bedienbar | offen |
| Sprache und Zeitzone | Deutsch/Englisch; zusätzliche Gerätesprache und Datums-/Zeitdarstellung geprüft | offen |
| Videoqualität und Zugang | Start und alle relevanten Schritte lesbar; keine Geheimnisse; Link erreichbar | offen |
| Screenshots (2.3.3) | Tatsächliche App im Gebrauch; passen zu Build und eingereichter Plattform | offen |
| In-App Purchase (3.1.1) | Keine kostenpflichtigen App-Funktionen im eingereichten Build; ASC-Konfiguration konsistent | offen |
| Geschäftsmodell (3.2) | Öffentlich nutzbare Familien-App; keine Beschränkung auf bestimmte Unternehmen/Angestellte | offen |
| Antwort und Notes | Alle sechs Punkte enthalten, gleiche Angaben, kein Platzhalter, höchstens 4.000 UTF-8-Bytes in Notes | offen |

Ein automatisierter Testlauf oder ein älterer Simulatorbericht ersetzt keine dieser Geräteprüfungen. Insbesondere die Befunde des [Build-20-Reports](../Test-Apple-Report/2026-10-29_13_macOS-iOS_Build20/Testreport.md) auf dem neuen Build nachprüfen; aus einer erhöhten Buildnummer folgt kein bestätigter Fix.

## Abschlussprotokoll

| Angabe | Wert |
|---|---|
| Gesamturteil / verbleibende Einschränkungen | offen |
| Geprüft durch / Datum | offen |
| Endfassung der Antwort (geschützte Ablage) | offen |
| Antwort in App Store Connect gesendet am | offen |
| Identische Angaben in Notes gespeichert und erneut geprüft am | offen |
| R1/R2 zuletzt erfolgreich geprüft am | offen |
| Video und zusätzliche Anlagen zugeordnet am | offen |

Video und ausgefüllte Unterlagen mit vertraulichen Daten in `secure/` bzw. geeigneter geschützter Ablage aufbewahren. Im Repository nur anonymisierte Nachweise, Prüfsummen und Statusangaben hinterlegen.
