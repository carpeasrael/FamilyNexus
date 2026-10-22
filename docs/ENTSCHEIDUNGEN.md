# Entscheidungsprotokoll

Format: Frage · gewählt · verworfen · Begründung. „**schwer rückholbar**“ = später nur mit hohem Aufwand änderbar. Änderungen werden unter dem Eintrag mit Datum ergänzt, nie stillschweigend überschrieben. Regel: Sicherheit vor Komfort; bei Gleichwertigkeit die leichter rückholbare Variante.

## E-01 Framework und Matrix-Bibliothek — **schwer rückholbar**
- **Frage:** Welches Framework, welche Matrix-Bibliothek?
- **Gewählt:** Flutter/Dart mit `matrix` 14.2.0 (Famedly) und `flutter_vodozemac` 0.9.0 (Olm/Megolm-Nachfolger vodozemac in Rust, per FFI).
- **Verworfen:** Kotlin Multiplatform + Matrix Rust SDK (kein ausgereifter Desktop-/iOS-Pfad für spätere Plattformen, Glas-Effekte aufwändiger); Tauri (Mobile unreif); eigene Matrix-Implementierung (verboten: keine eigene Kryptografie).
- **Begründung:** Prototyp (2026-10-21) auf Emulator: Build aus Quellcode (kein vorkompiliertes Binary), SQLCipher lädt, `vodozemac` initialisiert, `matrix`-Client mit SQLCipher-Datenbank startet. Ein Codebestand für alle späteren Plattformen. Rückfallebene laut Concept (Rust-SDK) bleibt über die Schnittstelle `MatrixGateway` (E-04) austauschbar.

## E-02 Lizenz und Verbreitung (offene Frage „Verbreitung“)
- **Gewählt:** Open Source unter **AGPL-3.0-or-later**; Verteilung als Quellcode und signierte APK, App-Store-Veröffentlichung optional später.
- **Verworfen:** Geschlossene Verbreitung.
- **Begründung:** `matrix` und `vodozemac` stehen unter AGPL-3.0; ein geschlossenes Produkt wäre lizenzwidrig. Offener Quellcode erhöht zudem die Prüfbarkeit der Sicherheitsversprechen.

## E-03 Branding (offene Frage „Design“)
- **Gewählt:** Neutral („FamilyNexus“), kein inneso-Logo. AURORA-Farben (Teal #0f766e / #2dd4bf) als Basis, Magenta/Violett als Sekundärakzente.
- **Verworfen:** inneso-Branding.
- **Begründung:** Datensparsam und leicht umstellbar; ein Logo lässt sich später ergänzen, ein Markenbezug nur schwer zurücknehmen. Der AURORA-Skill erlaubt hier die Farbpalette; die Schriften (Space Grotesk, IBM Plex) sind OFL-lizenziert und werden gebündelt.

## E-04 Matrix-Abstraktion (`MatrixGateway`) — **schwer rückholbar**
- **Gewählt:** Domäne und UI kennen nur die Schnittstelle `MatrixGateway` mit eigenen Modellen (`ChatMessage`, `FamilyMember`, …). `SdkMatrixGateway` kapselt das SDK; `FakeMatrixGateway` dient Tests.
- **Verworfen:** SDK-Typen direkt in UI/Domäne.
- **Begründung:** Testbarkeit ohne Netz (Vorgabe), Austauschbarkeit der Bibliothek, Durchsetzung der Sicherheitsregeln (privat nie senden) an einer Stelle.

## E-05 Lokale Datenbank und Schlüssel — **schwer rückholbar**
- **Gewählt:** `sqflite_sqlcipher` 3.4.1 (SQLCipher, AES-256). Zwei Dateien: App-Datenbank und Matrix-SDK-Datenbank (`MatrixSdkDatabase`), jeweils mit eigenem zufälligem 256-Bit-Schlüssel. Schlüssel werden beim ersten Start mit `Random.secure()` erzeugt und in `flutter_secure_storage` 11.2.0 abgelegt (Android Keystore-gestützt, AES). Nie im Code, nie in Dateien.
- **Verworfen:** drift + `sqlcipher_flutter_libs` (Paket seit 2026-02 „eol“); Klartext-SQLite; Schlüsselableitung aus PIN (schwächt Schutz bei schwacher PIN, E-14 deckt Sperre separat ab).
- **Begründung:** Direkt vom matrix-SDK unterstützt (sqflite_common-Schnittstelle), gepflegt, wenig Abhängigkeiten. Eigene Roh-SQL-Schicht mit Repositories hält die Codebasis klein.

## E-06 Zustandsverwaltung und Navigation
- **Gewählt:** Kein State-Management-Paket: `ChangeNotifier`-Controller, bereitgestellt über einen `InheritedNotifier`; Navigator 1.0 mit Bottom-Navigation.
- **Verworfen:** Riverpod, Bloc, go_router.
- **Begründung:** Weniger Lieferkettenrisiko und Paket-API-Risiko; für den Umfang ausreichend; leicht ersetzbar.

## E-07 Matrix-Server (offene Frage „Standardserver“)
- **Gewählt:** Voreingestellt `https://matrix.org`; frei änderbar. Nur `https://` zulässig. Betreiberanzeige aus `/.well-known/matrix/support`, sonst „nicht angegeben“.
- **Verworfen:** Anderer öffentlicher Server; http (auch für lokale Tests).
- **Begründung:** Bekanntester Server mit voller Unterstützung für E2EE. Hinweis in der Einrichtung auf Ratenbegrenzung und Metadaten. TLS-Pflicht ist Sicherheitsvorgabe.

## E-08 Konten (offene Frage „Konten“)
- **Gewählt:** Anmeldung mit bestehendem Matrix-Konto (Benutzername + Passwort). Keine Registrierung in der App; Hinweis, wo man ein Konto anlegt.
- **Verworfen:** In-App-Registrierung (Captcha-/E-Mail-Flows der Server, großer Missbrauchs- und Fehlerraum).
- **Begründung:** Einfacher und sicherer. Nachrüstbar. SSO/OIDC → `OFFEN.md`.

## E-09 Private Termine und Geräte-Sync (offene Frage „Private Termine“)
- **Gewählt:** Ja, Synchronisation zwischen eigenen Geräten über einen privaten, verschlüsselten Raum, in dem nur das eigene Konto ist (Auffindung per Account-Data-Schlüssel `de.inneso.familynexus.private_room`). Der Familienraum erhält private Termine nie.
- **Verworfen:** Nur lokal ohne Sync (Datenverlust bei Gerätewechsel).
- **Begründung:** Wie vom Konzept angenommen. Durchsetzung: Typ `SharedEventPayload` lässt sich nur aus Terminen mit Sichtbarkeit „shared“ erzeugen; Gateway hat getrennte Sendewege; Test belegt es.

## E-10 Moderatorenrechte (offene Frage „Moderatorenrechte“)
- **Gewählt:** Moderatoren dürfen Mitglieder einladen/entfernen, zum Moderator ernennen, Familienname ändern. Sie dürfen **keine** geteilten Termine anderer ändern oder löschen. Termine gehören ihrem Ersteller; Änderungen anderer Absender werden verworfen. Moderatoren können andere Moderatoren nicht herabstufen oder entfernen (Matrix-Regel: gleiche Stufe).
- **Verworfen:** Moderator darf fremde Termine ändern.
- **Begründung:** Geringste Rechte, keine Fälschung in fremdem Namen. Abwärtskompatibel erweiterbar.

## E-11 Minderjährige (offene Frage „Minderjährige“)
- **Gewählt:** Kinder können Mitglieder sein (Einladung durch Moderator). Keine technische Sondereinschränkung in dieser Phase; Hinweistext zur Einwilligung der Sorgeberechtigten in Einrichtung und Datenschutztext. Eingeschränkter Modus bleibt „später denkbar“.
- **Begründung:** Concept ordnet den eingeschränkten Modus ausdrücklich später ein.

## E-12 Raumkonfiguration — **schwer rückholbar**
- **Gewählt:** Raumversion 10, `private_chat`, nicht im Verzeichnis, `join_rules: knock`, Verschlüsselung Megolm im Anfangszustand, Verschlüsselungs-Zustandsereignis (siehe Änderung 2026-10-21), History-Sichtbarkeit `shared`. Power-Levels: `users_default` 0, Ersteller 50 (Moderator), `invite/kick/ban/redact` 50, `state_default` 50, `events.m.room.power_levels` 50, `events.m.room.encryption` 50.
- **Änderung 2026-10-21:** Stufe 100 für `m.room.encryption` ist nicht umsetzbar: Der Server wendet die Power-Levels vor den Anfangszuständen an, der Ersteller (50) könnte die Verschlüsselung dann beim Anlegen nicht mehr setzen. Stattdessen Stufe 50, und das Gateway sendet nie in einen Raum ohne `encrypted` (`encryptionUnavailable`). Matrix erlaubt ohnehin kein Abschalten der Verschlüsselung; die App bietet keinen Weg dazu.
- **Verworfen:** Raumversion 12 (Ersteller mit unendlicher Macht, passt nicht zu zwei Rollen); Ersteller auf 100.
- **Begründung:** Nur zwei Rollen laut Concept. Kicken rotiert die Megolm-Sitzung im SDK (Schlüsselrotation beim Entfernen).

## E-13 Ereignisformat geteilter Termine — **schwer rückholbar**
- **Gewählt:** Zeitleisten-Ereignisse im verschlüsselten Familienraum: `de.inneso.familynexus.event` (v1: `v`, `id`, `owner`, `version`, `deleted`, `title`, `start`, `end` (ISO-8601 UTC), `tz`, `all_day`, `location`, `note`, `color`, `rec` (`freq`, `interval`, `weekdays`, `count`, `until`, `ex`), `attendees`, `updated_at`) und `de.inneso.familynexus.rsvp` (`event_id`, `status`). Löschen = Ereignis mit `deleted:true` und höherer Version. Konflikt: höhere Version gewinnt, bei Gleichstand späteres `updated_at`, dann größere kanonische Darstellung (deterministisch auf allen Geräten); ältere Fassungen bleiben im Verlauf. Beim Beitritt neuer Mitglieder sendet jedes Mitglied seine eigenen aktuellen Termine erneut (Resync, gleiche Version).
- **Verworfen:** Zustandsereignisse (im Matrix-Standard unverschlüsselt!); Termine als Klartext-Nachrichten.
- **Begründung:** Nur Zeitleisten-Ereignisse werden Ende-zu-Ende verschlüsselt. Neue Mitglieder erhalten sonst keine alten Megolm-Schlüssel, daher der Resync.

## E-14 Einladungen (Link/QR) — **schwer rückholbar**
- **Gewählt:** Link `familynexus://join?v=1&room=<id>&via=<server>&inv=<mxid>&exp=<unix>`; Moderator zeigt ihn auch als QR. Der Eingeladene (bereits angemeldet) sendet eine Beitrittsanfrage (Matrix „knock“); der Moderator bestätigt (→ Matrix-Einladung) oder lehnt ab. Ablauf wird in der App geprüft (abgelaufen → abgelehnt), die eigentliche Sperre ist die Bestätigung. Alternativ Einladen per Matrix-ID.
- **Verworfen:** Selbst signierte Token (eigene Kryptografie); Beitritt ohne Bestätigung.
- **Begründung:** Concept verlangt Bestätigung durch Moderator. Das SDK hat keinen Knock-Aufruf; er wird als schmaler Rohaufruf (`POST /_matrix/client/v3/knock/{room}`) im Gateway implementiert und ist nur gegen die Spezifikation, nicht gegen einen echten Server geprüft (→ OFFEN).

## E-15 Erinnerungen und Benachrichtigungen
- **Gewählt:** `flutter_local_notifications` 22.3.2 + `timezone` 0.11.2 + `flutter_timezone` 5.1.1. Erinnerungstext **generisch** („Termin in 10 Minuten“, ohne Titel/Ort/Notiz); keine Nutzlast; Sperrbildschirm-Sichtbarkeit „private“. Neuplanung bei App-Start, Termin-Änderung und nach Neustart. Berechtigungen: `POST_NOTIFICATIONS`, `USE_EXACT_ALARM` (Kalender-App), `RECEIVE_BOOT_COMPLETED`; ohne Alarmrecht Rückfall auf ungenaue Alarme mit Hinweis.
- **Verworfen:** Titel in Benachrichtigung (auch als Option); Push-Dienst für Termine.
- **Begründung:** Vorgabe „keine Klartextinhalte in Benachrichtigungen“. Die Plattform legt geplante Benachrichtigungen unverschlüsselt ab; generischer Text vermeidet Inhalte dort.

## E-16 Chat-Benachrichtigungen und Hintergrundbetrieb
- **Gewählt:** In dieser Phase nur Synchronisation, solange die App läuft; **keine** Chat-Benachrichtigung (auch keine lokale generische); lokale Erinnerungen für Termine bestehen. Push (UnifiedPush) → `OFFEN.md`. *Korrigiert 2026-10-21:* frühere Fassung versprach eine generische Benachrichtigung, die nie umgesetzt wurde.
- **Verworfen:** Foreground-Service mit Dauer-Sync; FCM (Google-SDK, Metadaten an Dritte).
- **Begründung:** Nicht im Pflichtumfang; Telemetrie-/SDK-Verbot; Aufwand und Akkurisiko.

## E-17 App-Sperre
- **Gewählt:** `local_auth` 3.0.2 mit Geräteanmeldedaten (PIN/Muster/Passwort/Biometrie des Betriebssystems); automatische Sperre nach einstellbarer Inaktivität (Standard 1 Minute im Hintergrund). Keine eigene PIN-Speicherung.
- **Verworfen:** Eigene PIN mit selbst gebauter Ableitung/Speicherung (eigene Kryptografie).
- **Begründung:** Deckt „PIN, Passwort oder Biometrie“ ab, ohne eigene Geheimnisse zu verwalten. Ohne gesicherte Gerätesperre ist die Funktion deaktiviert und wird erklärt.

## E-18 Bildschirmschutz
- **Gewählt:** `FLAG_SECURE` (Android-Adapter, MethodChannel) standardmäßig **an**, in den Einstellungen abschaltbar.
- **Begründung:** Concept: „auf Wunsch“; sichere Voreinstellung verdeckt zugleich den Task-Switcher.

## E-19 Anhänge
- **Gewählt:** Senden/Empfangen über Matrix (Medien werden vom SDK verschlüsselt hochgeladen); Cache liegt in der verschlüsselten Matrix-Datenbank. Limit 25 MB, Typ-Allowlist (Bilder, PDF, Text, Office), keine automatische Ausführung/Öffnung, Dateiname bereinigt.
- **Begründung:** Concept: separat verschlüsselte Ablage; durch SQLCipher-Cache erfüllt, kein Klartext im Dateisystem – mit einer Ausnahme: dem bewussten „Anhang speichern“ durch den Nutzer (siehe SA-3). Die Dateiauswahl beim Senden löscht ihren Cache-Eintrag sofort nach dem Einlesen (`clearTemporaryFiles`).

## E-20 Zeitmodell — **schwer rückholbar**
- **Gewählt:** Beginn/Ende als UTC-Instant plus IANA-Zeitzone des Termins; Wiederholungen werden in der Zeitzone des Termins auf Wanduhrzeit berechnet (Sommerzeit-korrekt). Ganztägig: Datum ohne Zeit (zeitzonenfrei).
- **Verworfen:** Nur UTC (Wiederholungen driften über Sommerzeit); RRULE-Bibliothek (Abhängigkeit, wir brauchen nur ein Teilset).
- **Begründung:** Korrekte Wanduhrsemantik, voll testbar. Eigener Code nur für Kalenderlogik, nicht für Kryptografie.

## E-21 Schriften und Netzwerk
- **Gewählt:** Schriften (Space Grotesk, IBM Plex Sans/Mono, OFL) im App-Paket gebündelt.
- **Verworfen:** `google_fonts` (Laufzeit-Download = Verbindung zu Google).
- **Begründung:** Keine Drittverbindungen.

## E-22 Release, Logging
- **Gewählt:** Release nur mit `--obfuscate --split-debug-info`, R8-Minify; Signatur über nicht eingechecktes `key.properties`. Logging über eigenen `AppLog` mit Redaktion (keine Klartextinhalte, MXIDs/Tokens maskiert); `print`/`debugPrint` per Architekturtest verboten (`test/architecture_test.dart`); Dart-Obfuskierung über `tool/build_release.sh`. Debug-APK nur für Entwicklung.
- **Begründung:** Vorgabe.

## E-23 Schlüsselverlust und Keystore-Fehler
- **Gewählt:** Existiert die DB-Datei, wird nie ein neuer Schlüssel erzeugt (`KeyLostException`); Startfehler-Bildschirm mit „Erneut versuchen“ und bestätigtem „Lokale Daten zurücksetzen“. `flutter_secure_storage` mit `resetOnError:false`.
- **Verworfen:** Stilles Neuanlegen (Datenverlust ohne Hinweis).

## E-24 SDK-Verhalten abgesichert
- Nachrichten ohne Markdown-Parsing und ohne Slash-Befehle (`parseCommands:false`, sonst könnte Text wie `/ban` Befehle auslösen). Lesebestätigungen privat. SDK-Logs auf `Level.wtf`, Ausgabe über `AppLog` (nur Fehlertyp), Puffer wird geleert.
- Homeserver-Antworten sind nicht vertrauenswürdig: `.well-known` darf nur auf https-Ziele verweisen, Antworten ≤ 64 KB, Betreiberangaben bereinigt; nach `checkHomeserver` wird https erneut geprüft.
- Offline-Warteschlange: das SDK hält gesendete Ereignisse mit Status „Fehler“; das Gateway wiederholt nach jedem Sync bis zu 5-mal, die UI bietet manuelles Wiederholen.
- Familienraum wird über Kontodaten `de.inneso.familynexus.family` gefunden (gilt für alle eigenen Geräte).

## E-25 Betreiberanzeige
- **Gewählt:** „Betreiber“ = Host des Servers; Kontakt aus `/.well-known/matrix/support` getrennt (Admin bevorzugt). Grund: Der erste Eintrag ist bei matrix.org die Abuse-Adresse und wäre als „Betreiber“ irreführend.

## E-26 TLS-Pflicht in Dart durchgesetzt
- Die Android-Netzwerkkonfiguration (`cleartextTrafficPermitted=false`) gilt nur für den Java-Stack, **nicht** für `dart:io`. Daher laufen SDK, Serverprüfung und Anhang-Downloads über `HttpsOnlyClient` (nur `https`, keine Weiterleitungen). Das SDK macht keine eigene `.well-known`-Abfrage (`checkWellKnown:false`); die bei der Prüfung bestätigte Basisadresse wird beim Login wiederverwendet (kein Wechsel dazwischen).

## E-27 Verschlüsselung nur nachweislich
- Gesendet wird nur, wenn `client.encryptionEnabled` **und** der Raum Megolm nutzt (auch bei Wiederholungen). Das SDK würde sonst bei fehlender Krypto im Klartext senden.

## E-28 Anhänge eingehend
- Endung und behaupteter MIME-Typ müssen übereinstimmen, Größe muss bekannt und ≤ 25 MB sein; der Download ist hart auf das Limit begrenzt (nicht auf den behaupteten Wert vertraut); Bilder werden verkleinert dekodiert (`cacheHeight`). Eingehende Namen/Anzeigenamen/Reaktionen werden bereinigt (Bidi-/Steuerzeichen, Länge, nur Emoji, max. 12 Arten).

## E-29 Privater Raum später
- Der private Raum (E-09) wird mit der Kalender-Synchronisation in Phase 3 umgesetzt (PLAN 3.3); Phase 2 enthielt ihn irrtümlich.

## E-30 Kalender-Ereignisformat v1 – Ergänzungen — **schwer rückholbar**
- Das Feld `owner` im Inhalt muss dem authentischen Absender entsprechen (sonst verworfen). Private Termine nur im privaten Raum und nur vom eigenen Konto; Sichtbarkeit steht nie im Inhalt, sondern ergibt sich aus dem Raum. Zusagen tragen den Antwortzeitpunkt des Absenders (`ts`, nicht Serverzeit), damit verspätete Echos neuere Antworten nicht überschreiben. Teilen im Chat: Nachricht mit Zusatzfeld `de.inneso.familynexus.event_ref` (nur geteilte Termine).
- Sichtbarkeitswechsel: privat → geteilt behält die ID; geteilt → privat löscht den geteilten Termin für alle (Löschmarke ohne Inhalt) und legt eine private Kopie mit neuer ID an. Bereits zugestellte Inhalte bleiben auf fremden Geräten (nicht erzwingbar, UI weist darauf hin).
- Wiederholungen: Monatsende-Klemmung (31. → letzter Tag), 29.02. → 28.02.; Ausnahmen zählen für „Anzahl“ mit; Obergrenzen (Intervall 366, Anzahl 5000, 1000 Ausnahmen, Dauer ≤ 366 Tage).

## E-31 Erinnerungen: Plattformdetails
- Empfänger `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver` müssen in der App-Manifestdatei deklariert werden (das Plugin tut es nicht; ohne sie feuern Erinnerungen nie). Auf dem Gerät belegt: zugestellte Benachrichtigung = „Erinnerung“ / „Termin in 10 Minuten“, keine Nutzlast.
- Berechtigungen: `POST_NOTIFICATIONS`, `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM` (nur bis API 32), `RECEIVE_BOOT_COMPLETED`, `VIBRATE` (vom Plugin). Plan: höchstens 100 Erinnerungen in 60 Tagen; Neuplanung bei jeder Änderung und beim Start.

## E-32 Lokale Daten bei Kontowechsel
- Meldet sich ein anderer Matrix-Nutzer an als zuletzt, werden die lokalen Termine des Vorgängers vollständig gelöscht (`calendarOwner`).

## E-33 Ergänzungen nach Review Phase 3
- Standard für neue Termine ist **privat** (Teilen ist bewusst). Anzeigefarbe: eigene Termine in der gewählten Farbe, fremde in der Personenfarbe des Besitzers (kein Fälschen von Farben); der Besitzer steht immer als Text in der Kachel.
- Signalverarbeitung strikt seriell (Warteschlange) und im Dienst per Sperre; `CalendarGateway`-Signale werden für späte Zuhörer wiedergegeben (Kalender startet erst nach Bekanntwerden der Familie). Verlauf je Termin ≤ 20 Fassungen; höchstens 2000 Termine je fremdem Absender; Antworten nur auf bekannte geteilte Termine.
- Resync neuer Mitglieder: eigene geteilte Termine/Zusagen werden in der Warteschlange neu vorgemerkt (überlebt Ausfälle/Neustarts).
- Der private Raum wird vor jedem Senden geprüft (nicht der Familienraum, nur das eigene Konto als Mitglied).
- Erinnerungen ganztägiger Termine beziehen sich auf 09:00 Ortszeit; eigene Absagen erzeugen keine Erinnerung; Planung serialisiert, bei Rückkehr in die App aufgefrischt; Abmeldung/Datenlöschung/Kontowechsel entfernen geplante Erinnerungen, das bloße Schließen der Oberfläche nicht.
- Text in Titel/Ort/Notiz: Steuer-, Bidi- und Nullbreiten-Zeichen führen zum Verwerfen des Ereignisses.

## E-34 Einladungen, QR und Deep Links (Phase 4)
- Der Einladungslink wird als QR-Code **angezeigt**; Empfänger scannen ihn mit der System-Kamera, die `familynexus://join?…` an die App übergibt (Intent-Filter nur für dieses Schema/Host; Länge ≤ 512; strikte Prüfung; die App handelt nie automatisch, sondern verlangt eine Bestätigung mit Server und Einladendem). Ein In-App-Scanner (mobile_scanner/ML Kit) wurde **nicht** aufgenommen: ML Kit kann Nutzungsdaten an Google senden (Verstoß gegen „keine Telemetrie/Analyse-SDKs“); Alternative → OFFEN.
- Das SDK liefert den `knock`-Abschnitt nicht aus. Die eigene wartende Anfrage wird daher als Kontodaten-Vermerk (`…join_request`, 7 Tage gültig) geführt und kann zurückgezogen werden; eine Ablehnung ist für den Anfragenden nicht sichtbar (Hinweis in OFFEN).
- Beitritt: Anfrage (Knock, Raumversion 10) → Moderator bestätigt (= Einladung) → Annahme durch den Eingeladenen; bestehende Familie wird nie überschrieben; Einladungen von Fremden werden nur nach ausdrücklicher Annahme angenommen. Entfernen = Kick; das SDK rotiert die Megolm-Sitzung (E2E belegt: neue Sitzung, Entfernte lesen neue Nachrichten nicht).
- Rechte werden im Gateway (`Permissions`) **und** vom Server erzwungen (E2E belegt `M_FORBIDDEN` für Mitglieder bei Einladen, Namensänderung und Verschlüsselungsänderung).

## E-35 Schlüsselsicherung und Verifizierung
- Einrichtung: SSSS mit zufälligem **Wiederherstellungsschlüssel** (keine nutzergewählte Passphrase), Cross-Signing, Online-Schlüsselbackup; der Schlüssel wird einmalig angezeigt (nicht kopierbar, Bildschirmschutz aktiv) und muss bestätigt werden. Die erste Einrichtung verlangt auf Synapse keine Passwortbestätigung; verlangt ein Server sie, fragt die App das Passwort ab (nie gespeichert).
- Neues Gerät eines bestehenden Kontos: Pflicht-Verifizierung per **Emoji-Vergleich** mit einem anderen Gerät oder per Wiederherstellungsschlüssel (lädt auch die Schlüsselsicherung, alte Nachrichten werden lesbar – E2E belegt). Nur die anfragende Seite sendet den SAS-Start (sonst Start-Kollision mit abweichenden Emoji). Personenverifizierung nutzt denselben Ablauf.
- Nicht enthalten (OFFEN): QR-Verifizierung, Abmelden fremder Sitzungen (benötigt UIA), lokalisierte Emoji-Namen.

## E-36 Testinfrastruktur
- `tool/e2e.sh` startet einen isolierten Synapse (Docker, Caddy-TLS-Proxy auf `https://localhost:18448`) und führt `test/e2e` mit der echten vodozemac-Bibliothek (für den Host gebaut) aus. Die selbstsignierte Zertifikatsakzeptanz existiert ausschließlich im Testcode (`HttpsOnlyClient` bleibt https-only).

## E-37 Ergänzungen nach Review Phase 4 (2026-10-21)
- **Einladungslink v1 erweitert** (`n` = 128-Bit-Zufalls-ID, `exp`, `via`): Der Moderator vermerkt jede ausgegebene ID mit Ablauf in seinen Kontodaten (`…invites`); die Beitrittsanfrage nennt die ID im Knock-Grund (`FamilyNexus:<id>`). Bestätigt werden nur Anfragen mit eigener, gültiger, unverbrauchter ID (Gateway **und** Oberfläche), nach Rückfrage mit voller Matrix-ID; die ID wird beim Bestätigen verbraucht. Anfragen mit fremder/unbekannter oder abgelaufener ID zeigen einen Hinweis und sind nicht bestätigbar (ablehnen bleibt möglich). *Verworfen:* automatisches Ablehnen unbekannter IDs – ein zweiter Moderator, dessen Kontodaten noch nicht synchron sind, würde gültige Anfragen verwerfen. Das Format ist neu und noch nirgends ausgeliefert, daher keine Abwärtskompatibilität (alte Links ohne `n` werden abgelehnt).
- **`via`** muss zur Domain der Raum-ID passen und darf weder IP-Adresse noch `localhost` sein (Ausnahme: Server des eigenen Kontos) – verhindert, dass ein Link einen Knock an einen beliebigen Host föderiert. `exp` wird vor dem Umrechnen auf Grenzen geprüft (kein Überlauf).
- **Identität der Mitglieder (S1):** Beim ersten Kontakt wird der Cross-Signing-Hauptschlüssel jedes Mitglieds vermerkt (TOFU, geräteübergreifend in den Kontodaten). Ändert er sich, sperrt die App alle Geräte des Mitglieds (kein Schlüsselversand), zeigt Warnung und Badge (Text + Symbol) und gibt erst nach ausdrücklicher Bestätigung wieder frei. Statusanzeige je Mitglied: verifiziert / nicht persönlich geprüft / keine Schlüssel / geändert. *Verworfen:* `directlyVerifiedOnly` (jedes Mitglied müsste mit jedem anderen persönlich verifizieren – für Familien unpraktikabel, dann würde Sicherheit eher umgangen).
- **Verifizierungsanfragen** werden nur vom eigenen Konto oder von Familienmitgliedern angezeigt und nur eine zur Zeit; alles andere wird still mit `m.user` abgebrochen. Zustand wird beim Abmelden zurückgesetzt.
- **Einladung annehmen:** Gehört sie nicht zur eigenen Beitrittsanfrage, kommt eine Warnung mit Einladendem. Nach dem Beitritt wird geprüft, dass der Raum Megolm-verschlüsselt ist – sonst sofort Austritt und Fehler. Der Familienvermerk wird vor dem Beitritt gesetzt und bei Fehlschlag zurückgenommen (kein halber Beitritt).
- **Wiederherstellung** legt nie eine neue Cross-Signing-Identität an (bricht ab); Netzwerkfehler werden als solche gemeldet, nicht als „falscher Schlüssel“. Bei Anzeige des Wiederherstellungsschlüssels ist der Bildschirmschutz erzwungen, unabhängig von der Einstellung.
- **Familienwechsel:** Lokale Termine sind an Konto **und** Familienraum gebunden; bei Wechsel werden sie gelöscht (keine Vermischung, kein Senden alter Termine in die neue Familie).
- **Moderatoren und Löschen (S10):** `redact` bleibt bei 50 (Moderation von Chatnachrichten). Folge: Moderatoren können auch Kalendernachrichten anderer redigieren; der Besitzer-Prüfung im Format hilft dagegen nicht. Akzeptiert, weil Moderatoren ohnehin vertraut werden (sie können Mitglieder entfernen); in OFFEN vermerkt.
- **Entfernen = Kick (S11):** Erneutes Anklopfen braucht einen neuen, vom Moderator ausgegebenen Link (E-37, Nonce) und eine neue Bestätigung; ein Bann würde Wiedereintritt auch nach Versöhnung erschweren (kein UI zum Aufheben).

## E-38 Online-Status der Familie (Phase 6, 2026-10-21) — **schwer rückholbar** (Ereignisformat)
- **Frage:** Wie erfährt die Familie, wer gerade online ist, ohne Klartext oder Dauerlast im Chatverlauf?
- **Gewählt:** Eigener, **Ende-zu-Ende-verschlüsselter Geräte-zu-Geräte-Ereignistyp** `de.inneso.familynexus.presence` (Matrix-„to-device“ mit Olm, Inhalt `{v:1, state: online|offline, ts: <ms UTC>, ask: bool}`), gesendet nur an die Geräte *aktueller Familienmitglieder*, die auch Raumschlüssel erhalten dürfen (`encryptToDevice`, E-37/SA-1: cross-signiert, nicht gesperrt). Die App sendet „online“ beim Vordergrundwechsel und alle 120 s, „offline“ beim Wechsel in den Hintergrund und beim Abmelden. Ein Eintrag gilt 300 s; ohne neuen Eintrag ist das Mitglied **offline**. Beim Start fragt ein Gerät mit `ask: true`; online befindliche Geräte der Mitglieder antworten direkt an die Anfragenden (`ask: false`, keine Schleife). Empfangen wird nur, was **verschlüsselt** ankam (`encryptedContent != null`) und von einem aktuellen, beigetretenen Familienmitglied stammt; `ts` muss zu 300 s zurück/60 s voraus passen, Felder werden strikt geprüft, je Absender zählt nur der neueste Zeitstempel. Der Zustand liegt nur im Arbeitsspeicher (nie in Datenbank, Log oder Backup) und wird **je Gerät** geführt (Schlüssel des sendenden Geräts): ein Mitglied gilt als online, solange irgendein Gerät aktuell online meldet. Beim Abmelden und Schließen wird „offline“ gesendet (best effort); bei Wechsel der Familie beginnt der Zustand neu. Anzeige immer mit Text („Online“, „Offline“, „zuletzt online vor …“), nie nur Farbe.
- **Abschaltbar:** Einstellung „Online-Status teilen“ (Standard: **an**, weil das der ausdrückliche Zweck der Funktion ist; Änderung ist jederzeit möglich). Beim Abschalten wird einmal „offline“ gesendet und danach nichts mehr; andere sehen dann „Offline“ (es ist nicht erkennbar, ob jemand den Status verbirgt). Die Anzeige fremder Status bleibt davon unberührt.
- **Verworfen:** (a) Matrix-Präsenz (`m.presence`): Klartext auf dem Server, auf `matrix.org` serverseitig abgeschaltet und für alle Nutzer des Servers sichtbar, die einen Raum teilen. (b) Verschlüsselte Raumereignisse im Familienraum: würden den Verlauf verstopfen; das Nachladen alter Ereignisse (20 Seiten, E-13) erreichte dann keine Termine mehr. (c) Tippen-Benachrichtigungen (`m.typing`): unverschlüsselt, ungeeignet. (d) Eigener Präsenzraum: zusätzliche Mitgliederverwaltung ohne Mehrwert.
- **Restrisiko:** Der Server sieht – wie bei jedem Sync – Zeitpunkte und Umfang der Gerätenachrichten (Metadaten), aber keinen Inhalt. Ein böswilliges Mitglied kann seinen eigenen Status fälschen, aber nicht den anderer (Absender wird kryptografisch festgestellt). Gerätenachrichten bleiben auf dem Server liegen, bis ein offline befindliches Gerät sie abholt; veraltete Einträge werden beim Empfang verworfen.

## E-39 Einzelchats zwischen Mitgliedern (Phase 6)
- **Frage:** Wie schreiben Mitglieder einander direkt, ohne die Familienregeln zu umgehen?
- **Gewählt:** Je Mitgliederpaar ein privater, **verschlüsselter** Matrix-Raum mit höchstens zwei Mitgliedern (`is_direct`, `m.megolm.v1.aes-sha2`, Verlauf „geteilt“, kein Beitritt per Link). Gespräche gibt es nur mit **aktuellen, beigetretenen Familienmitgliedern**; wer entfernt wird, verschwindet aus der Liste, an ihn wird nichts mehr gesendet (Gateway verweigert). Eine Direkteinladung wird **nur dann automatisch angenommen**, wenn der Einladende ein beigetretenes Familienmitglied ist und wir selbst schon eine Familie haben; nach dem Beitritt wird die Megolm-Verschlüsselung geprüft, sonst sofortiger Austritt. Räume mit weiteren Mitgliedern werden nach dem Beitritt verlassen, je Mitglied wird nur ein Einzelchat geführt (weitere Einladungen werden ignoriert), ein vorläufiger Fehler beim Beitritt wird nach einer Minute erneut versucht. Alle anderen Direkteinladungen werden **ignoriert** (nie angenommen, nicht als Familieneinladung angezeigt). Existieren mehrere Räume für dasselbe Paar (gleichzeitiges Anlegen), zeigen beide Seiten denselben (kleinste Raum-ID). Die Chatfunktionen (Antworten, Reaktionen, Anhänge samt Prüfregeln E-19/E-28, Wiederholen, Lesestatus) gelten je Gespräch unverändert.
- **Verworfen:** Gruppenchats beliebiger Größe (nicht gefordert, Mitgliederverwaltung ohne Moderator); Einladung von Nicht-Mitgliedern; Annahme aller Direkteinladungen (Spam/Phishing-Weg); eigener Raum-Typ ohne `is_direct` (andere Matrix-Apps zeigen sie nicht korrekt).
- **Bekannt:** Ein entferntes Mitglied bleibt Mitglied der gemeinsamen Einzelchat-Räume. Weil die App an dieses Mitglied nicht mehr sendet, den Raum ausblendet und einen Neuaufbau verweigert, erhält es von dieser App nichts Neues; andere Matrix-Apps der verbleibenden Person würden dort jedoch weiter schreiben. Das automatische Verlassen des Raums fehlt (OFFEN).

## E-40 Einkaufszettel (Phase 6) — **schwer rückholbar** (Ereignisformat, Datenmodell)
- **Frage:** Wie teilt die Familie eine Einkaufsliste, auch offline, ohne Server-Klartext?
- **Gewählt:** **Eine** gemeinsame Liste je Familie. Jeder Eintrag ist ein Datensatz mit zufälliger ID, Text (≤ 100 Zeichen), Menge (≤ 30), abgehakt-Kennzeichen, Löschmarke, Version und Zeitstempel. Änderungen laufen als **verschlüsselte Raumereignisse** `de.inneso.familynexus.shopping` im Familienraum (Format v1; strikt geprüft; das Feld `by` muss dem authentischen Absender entsprechen, sonst verworfen). Jedes Mitglied darf jeden Eintrag ändern (gemeinsame Liste, kein Besitzer). **Konfliktregel (deterministisch):** höhere Version gewinnt; bei Gleichstand der spätere Zeitstempel, danach die größere Absender-ID. Eine Änderung setzt `version = bisherige + 1`. Lokal liegt alles in der verschlüsselten App-Datenbank (Migration 3); gesendet wird über eine Warteschlange mit Wiederholung (wie Termine). Neue Mitglieder erhalten den Bestand, indem jeder Eintrag erneut gesendet wird, dessen **letzter Bearbeiter man selbst** ist (Resync wie E-13). Löschen erzeugt eine Löschmarke (kein Inhalt, nur ID/Version), „Erledigte entfernen“ löscht alle abgehakten Einträge.
- **Grenzen (Speicherschutz):** höchstens 300 aktive Einträge; höchstens 1000 Datensätze insgesamt (inkl. Löschmarken). Ist die Ablage voll, werden die ältesten **bereits veröffentlichten** Löschmarken verdrängt (es bleiben ≤ 200; unveröffentlichte nie). Folge: Eine sehr spät eintreffende alte Fassung eines längst gelöschten und verdrängten Eintrags kann diesen wieder auftauchen lassen (Version/Zeitstempel entscheiden; selten, begrenzt auf das Backfill-Fenster). Eingehende Einträge: erste Version ≤ 10000, Versionssprung ≤ 1000 gegenüber der bekannten (kein „Unveränderbar-Machen“ durch hochgesetzte Versionen); Texte ohne Steuer-/Bidi-Zeichen; Einträge über den Grenzen werden verworfen.
- **Verworfen:** mehrere Listen/Kategorien/Preise (Umfang); Matrix-Raumzustand oder Raumnotizen (nicht verschlüsselt bzw. nicht offlinefähig); CRDT-Bibliothek (neue Abhängigkeit ohne Bedarf); Bearbeitung nur durch den Ersteller (unpraktisch für eine gemeinsame Liste).
- **Bekannt:** Versionszähler und Zeitstempel stammen vom Absender; ein böswilliges Mitglied kann Einträge ändern oder löschen, wie es jedes Mitglied darf – der Schaden ist auf die Liste begrenzt. Gegen das Hochsetzen der Version siehe Grenzen oben.

## E-41 Oberfläche (Phase 6)
- **Gewählt:** Neuer Tab „Einkauf“ (sechs Tabs; seit E-46 fünf, Einstellungen im Burger-Menü). Der Chat-Tab zeigt die Gesprächsliste (Familienchat zuerst, darunter die Mitglieder mit Online-Status und ungelesenen Nachrichten) und öffnet je Gespräch den bekannten Chatbildschirm. Der Online-Status erscheint in der Mitgliederliste, in der Gesprächsliste und im Chatkopf (Punkt **und** Text). Die Gesprächsleiste erscheint ab dem ersten Einzelchat. Der Tab „Heute“ zeigt zusätzlich, wer online ist, und die Zahl offener Einkaufseinträge.
- **Verworfen:** Einstellungen in die Kopfzeile verschieben (Änderung vertrauter Navigation und vieler Tests ohne Not); zweiter Chat-Tab.

## E-42 Chat-Schnittstelle je Gespräch
- **Gewählt:** `MatrixGateway` bleibt die einzige Schnittstelle (E-04). Gespräche sind `ChatThread`s; der Familienchat hat die feste Kennung `ChatThread.familyId`. Bestehende Chatmethoden erhalten den optionalen Parameter `threadId` (Standard = Familienchat), `messages` bleibt der Familienchat. Neu: `threads`, `messagesIn`, `unreadIn`, `startDirectChat`, `presence`, `announcePresence`, `presenceAsks`, Einkaufszettel-Senden (`publishShoppingItem`) und das Signal `ShoppingSignal`.
- **Verworfen:** neues Gateway je Funktion (mehrfache Client-Zustände), Chatmethoden mit Pflichtparameter (Bruch aller Aufrufer und Tests ohne Gewinn).

## E-43 iOS-Version (2026-10-21)
- **Frage:** Wie kommt die App (bisher nur Android, E-01/Prompt) auf iOS, ohne die Sicherheitsvorgaben aufzuweichen?
- **Gewählt:** Gleiche Codebasis (`flutter create --platforms=ios`), Android-Adapter heißen jetzt plattformneutral (`LocalReminderScheduler`, `PlatformScreenProtection`, `PlatformLinkSource`). Nativ (`ios/Runner`): Kanäle `…/window` und `…/links` wie unter Android; Schlüssel im iOS-Schlüsselbund (`first_unlock_this_device`: nie in Sicherungen oder auf anderen Geräten); Dokumente, „Application Support“ und „Library“ sind von iCloud-/iTunes-Sicherungen ausgenommen; Deep-Link-Schema `familynexus` (nur dieses Schema wird weitergereicht, Prüfung wie bisher in Dart); Face-ID-Hinweistext für die App-Sperre; Erinnerungen als lokale Benachrichtigungen (Berechtigung erst auf Wunsch, höchstens 60 geplante, Rest bei der nächsten Neuplanung, da iOS 64 zulässt); Datenbank und Kryptografie unverändert (SQLCipher, vodozemac über Rust: Ziele `aarch64-apple-ios(-sim)`).
- **Sicherheitsabweichung SA-5 (iOS):** Android verhindert Screenshots mit `FLAG_SECURE`; iOS bietet das nicht. Nächstsichere Lösung: undurchsichtige Abdeckung im App-Umschalter und bei laufender Bildschirmaufnahme (solange „Bildschirmschutz“ an ist). Einzelne Screenshots durch den Nutzer bleiben möglich (OFFEN).
- **Nicht entschieden:** `ITSAppUsesNonExemptEncryption` (Exportnachweis für verschlüsselnde Apps) wird bewusst **nicht** gesetzt; die Angabe trifft der Herausgeber vor einer Veröffentlichung.
- **Verworfen:** Eigene Brücke je Funktion statt gleicher Kanalnamen (doppelter Dart-Code); Face-ID-Pflicht (Geräteanmeldung inkl. Code bleibt, E-17).

## E-44 macOS-Version (2026-10-21)
- **Gewählt:** Gleiche Codebasis (`flutter create --platforms=macos`), App-Sandbox mit `network.client` (TLS-Verbindung zum Homeserver) und Dateiauswahl (`user-selected.read-write`); `network.server` nur im Debug (Hot Reload). Schlüssel im klassischen macOS-Schlüsselbund (`usesDataProtectionKeychain: false`, `first_unlock_this_device`, nicht iCloud-synchronisiert), weil der Data-Protection-Schlüsselbund eine Entwickler-Signierung mit Gruppen-Berechtigung verlangt; für eine signierte Verteilung kann das umgestellt werden. Bildschirmschutz: Das Fenster wird mit `NSWindow.sharingType = .none` von Screenshots und Bildschirmaufnahmen ausgenommen (damit gilt für macOS die Vorgabe ohne Abweichung). Application Support/Documents des App-Containers sind von Time-Machine-Sicherungen ausgenommen. Deep-Link-Schema `familynexus` wie auf iOS. Erinnerungen und App-Sperre nutzen dieselben Plugins (Benachrichtigungsberechtigung auf Wunsch; Geräteanmeldung/Touch ID).
- **Verworfen:** Eigener Desktop-Code für Kalender/Chat (die Oberfläche ist adaptiv genug; eine Zwei-Spalten-Ansicht für große Fenster steht in OFFEN).

## E-45 Anmeldung eines bestehenden Mitglieds an einem weiteren Gerät (2026-10-21)
- **Fehler:** Der Einrichtungsschritt „Familie“ erkannte eine bereits vorhandene Familie nicht; auf einem zweiten Gerät blieb der Nutzer bei „Familie gründen/beitreten“ hängen (Gründen scheiterte mit „bereits vorhanden“).
- **Behoben:** Ist das Konto schon Mitglied einer Familie, schließt der Schritt die Einrichtung selbst ab (Hinweis „Familie … gefunden“). Der Ablauf auf dem neuen Gerät ist: Server → Anmeldung → **Geräteverifizierung** (Emoji-Vergleich mit einem bekannten Gerät oder Wiederherstellungsschlüssel, nie eine neue Schlüsselsicherung, E-35) → Hauptansicht. Außerdem gilt „abgeglichen“ (`initialSyncDone`) erst, wenn Familie und Sicherheitsstatus aus den ersten Daten berechnet sind; vorher sah ein bestehendes Mitglied kurz „keine Familie“ und hätte eine zweite gründen können (das Gateway verweigert das ohnehin).
- **Belegt durch:** Widget-Test (Schlüssel eingeben → Hauptansicht), Synapse-E2E (Familie sofort bekannt nach dem ersten Abgleich).

## E-46 Wählbare Akzentfarbe und Burger-Menü (2026-10-21)
- **Frage:** Wie wählt der Nutzer seine Neon-Kontrastfarbe, und wohin wandern die Einstellungen?
- **Gewählt:** Acht kuratierte Neonfarben (Türkis = Standard/AURORA, Magenta, Violett, Himmelblau, Limette, Orange, Rosé, Grün) als Auswahl in Einstellungen → Darstellung. Jede Farbe hat eine **leuchtende** Variante (dunkles Design) und eine **abgedunkelte** (helles Design); die Schriftfarbe auf der Akzentfläche wird nach dem besseren Kontrast gewählt, der Hintergrundverlauf passend getönt. Die Auswahl zeigt Farbe, Namen **und** Häkchen. Gespeichert wird nur die Kennung (`accent`), unbekannte Werte fallen auf Türkis zurück. Ein Test prüft für alle Farben in beiden Designs Kontrast ≥ 4,5 (Schrift auf Akzent, Akzent als Text auf Oberfläche und Glas, Text auf dem getönten Verlauf) bzw. ≥ 3 für Bedienelemente. Die Einstellungen stehen nicht mehr in der unteren Navigationsleiste (jetzt fünf Tabs: Heute, Kalender, Chat, Einkauf, Familie), sondern im **Burger-Menü rechts oben** (Seitenmenü mit „Einstellungen“ und „Datenschutzerklärung“); Einstellungen öffnen als eigene Seite mit Zurück-Pfeil und schließen sich, wenn man die Hauptansicht verlässt (z. B. beim Abmelden). Ändert E-41 (dort „sechs Tabs“).
- **Verworfen:** Freie Farbwahl (Farbrad/Hex): beliebige Farben können AA-Kontrast verletzen (Vorgabe Barrierefreiheit); Personenfarben (Termine) bleiben unverändert und getrennt; eine Menü-Schaltfläche links (Android-Konvention für Navigation, hier aber rechts verlangt).

## E-47 Vorbereitung der Store-Veröffentlichung (2026-10-21)
- **Gewählt:** Version `1.0.0+1`; einheitliche Kennung `de.inneso.familynexus` (Android, iOS, macOS; vorher iOS/macOS mit großem „N“); Symbol per reproduzierbarem Skript (`tool/make_icons.py`, Motiv: drei verbundene Knoten = Familie im „Nexus“); iOS **nur iPhone** (keine iPad-Oberfläche vorhanden → keine Screenshot-Pflicht für iPad); Zielgruppe in der Play Console **18+** (Kinder nur über Einladung eines Moderators, Hinweis in der App; vermeidet die Families-Richtlinien); `PrivacyInfo.xcprivacy` ohne Tracking und ohne Datenerhebung; Android App Bundle über `tool/build_release.sh aab`, iOS-IPA über `tool/build_ios_release.sh` (beide obfuskiert); Signierung ausschließlich über nicht eingecheckte Dateien (`key.properties`) bzw. Team-ID des Herausgebers; Store-Texte, Datenschutz-Seiten und Prüfhinweise unter `store/`; Anleitung und Fragebogen-Vorschläge in `docs/STORE.md`.
- **Nicht entschieden (Herausgeber):** `ITSAppUsesNonExemptEncryption` wird nicht gesetzt (Antwort bei jedem Upload bewusst); Entwicklerkonten, Impressum/Kontakt, Hosting der Datenschutzseite, Prüfkonto, Team-ID, rechtliche Prüfung AGPL ↔ App-Store-Bedingungen.
- **Verworfen:** Generierter Upload-Schlüssel im Repository (Geheimnis); Standardsymbol von Flutter; Eintrag „Daten werden erhoben“ als Vorgabe (der Herausgeber erhält keine Daten – Details und Vorbehalte in STORE.md).

## E-48 Melden und Blockieren von Nachrichten (2026-10-22)
- **Gewählt:** *Melden:* Langdruck auf eine fremde Nachricht → Grund (Spam, Belästigung, unangemessen, anderer) und optionaler Freitext (höchstens 300 Zeichen, bereinigt) → Matrix `POST /rooms/{roomId}/report/{eventId}` an den Homeserver (`MatrixGateway.reportMessage`); eigene und unbekannte Nachrichten werden im Gateway abgelehnt, der Dialog sagt vorab, dass der Freitext für den Serverbetreiber lesbar ist, der Nachrichteninhalt aber nicht übertragen wird. Danach wird das Blockieren des Absenders angeboten. *Blockieren:* lokale Liste (`blockedUsers` in den Einstellungen der verschlüsselten Datenbank, höchstens 200 gültige Matrix-IDs); Nachrichten blockierter Absender und Einzelchats mit ihnen werden ausgeblendet (`visibleMessages`/`visibleThreads`, Domäne), „Nachricht schreiben“ entfällt; erreichbar aus dem Nachrichtenmenü und dem Mitgliedermenü, Aufheben in Einstellungen → Blockierte Mitglieder. Der Blockierte erfährt nichts und bleibt Mitglied.
- **Verworfen:** Matrix-Ignorierliste (`m.ignored_user_list`): wirkt serverseitig auf alle Räume, lässt sich nicht sauber rückgängig machen (verlorene Historie) und gibt die Blockierung an den Server preis. Meldung an Moderatoren der Familie: ein eigener Ereignistyp wäre ein Protokollzusatz; Moderatoren können Mitglieder bereits entfernen.
- **Begründung:** Apple-Richtlinie 1.2 (Nutzerinhalte) verlangt Melden und Blockieren; die Lösung bleibt local-first und datensparsam (keine neuen Daten auf dem Server außer der Meldung selbst, die der Nutzer ausdrücklich auslöst).
- **Grenzen:** siehe OFFEN.md (Termine, Einkaufszettel, Reaktionen, Online-Status und Ungelesen-Zähler blockierter Mitglieder bleiben unberührt).

## Sicherheitsabweichungen

### SA-1 Schlüsselweitergabe vor Cross-Signing (Phase 2–3, **Sicherheitsabweichung**)
- **Vorgabe:** Unverifizierte Geräte erhalten keine Raumschlüssel.
- **Ist:** `ShareKeysWith.crossVerifiedIfEnabled` – solange ein Konto noch kein Cross-Signing eingerichtet hat, erhalten alle nicht gesperrten Geräte des Kontos Schlüssel. Ein striktes `crossVerified` würde vor der Geräteverifizierung (Phase 4) jeden Chat verhindern.
- **Schutzwirkung erhalten durch:** Beitritt nur nach Moderatorbestätigung; Phase 4 richtet beim Einrichten Cross-Signing ein (ab dann greift die Einschränkung automatisch) und schaltet auf `crossVerified` um.
- **Status: geschlossen am 2026-10-21 (Phase 4).** `ShareKeysWith.crossVerified`; die Schlüsselsicherung (Cross-Signing, SSSS, Online-Backup) ist in der Einrichtung Pflicht, ohne verifiziertes Gerät gibt es keine Hauptansicht. Belegt durch E2E-Test gegen echten Synapse: ein unverifiziertes zweites Gerät sieht nur Chiffretext, nach der Emoji-Verifizierung sind neue Nachrichten lesbar.

### SA-2 Eingeladene erhalten Nachrichtenschlüssel vor der Annahme (Phase 4, **Sicherheitsabweichung**)
- **Vorgabe:** Nur tatsächliche Mitglieder erhalten Raumschlüssel.
- **Ist:** Das Matrix-SDK bezieht beim Erzeugen einer Megolm-Sitzung auch *eingeladene* (nicht beigetretene) Nutzer ein (`Room.getUserDeviceKeys`: Mitgliedschaft `join` und `invite`). Wer eingeladen ist, kann ab der Einladung neue Nachrichten lesen, sobald er (mit seinen cross-signierten Geräten) den Raum betritt oder die Schlüssel abruft – auch ohne die Einladung bewusst anzunehmen.
- **Nächstsichere Lösung:** Einladen nur durch Moderatoren, nach Rückfrage mit voller Matrix-ID und ausdrücklichem Hinweis; Beitrittsanfragen nur mit eigenem gültigem Link; Schlüssel gehen nur an cross-signierte Geräte (`crossVerified`), und Identitätsänderungen sperren Geräte (E-37). Eine Änderung am SDK (Fork) wurde verworfen (Wartbarkeit).
- **Status:** offen, in OFFEN.md geführt.

### SA-3 „Anhang speichern“ schreibt unverschlüsselt (Phase 5, **Sicherheitsabweichung**)
- **Vorgabe:** Keine Funktion, die Daten unverschlüsselt speichert.
- **Ist:** Auf ausdrücklichen Wunsch des Nutzers wird ein entschlüsselter Anhang über den System-Dateidialog in einen vom Nutzer gewählten Ordner geschrieben. Diese Datei liegt außerhalb der App (überlebt Abmelden und Datenlöschung).
- **Nächstsichere Lösung:** Nur nach Warnhinweis (Pflichtdialog vor jedem Speichern); keine automatische Ablage; nichts anderes verlässt die verschlüsselte Datenbank. Eine Variante ohne Speichern würde Anhänge nur in der App anzeigbar machen – verworfen, weil Dokumente sonst nicht weiterverwendet werden können.
- **Status:** akzeptiert; im Datenschutztext der App und in OFFEN genannt.

### SA-4 Verschlüsselungs-Zustandsereignis ist für Moderatoren änderbar (Phase 1–2, **Sicherheitsabweichung**)
- **Vorgabe:** Verschlüsselung nicht abschaltbar.
- **Ist:** `m.room.encryption` hat Power-Level 50 (nicht 100), da Raumersteller und Moderatoren gleichrangig sind (E-12). Matrix erlaubt ohnehin kein Abschalten der Verschlüsselung; ein Moderator könnte nur den Algorithmus setzen.
- **Schutzwirkung:** Das Gateway sendet nur, wenn der Raum nachweislich Megolm nutzt (E-27), und prüft das beim Beitritt (E-37). Ein manipulierter Raum führt zu Sendeverweigerung, nicht zu Klartext.
- **Status:** akzeptiert (Restrisiko: Denial of Service durch einen böswilligen Moderator).

### SA-5 Kein Screenshot-Schutz unter iOS (2026-10-21, **Sicherheitsabweichung**)
- **Vorgabe:** Keine Klartext-Vorschauen im Task-Switcher; Screenshot-Schutz auf Wunsch.
- **Ist:** iOS erlaubt kein Sperren von Screenshots. Task-Switcher-Vorschau und Bildschirmaufnahme werden durch eine Abdeckung verhindert; Screenshots durch den Nutzer nicht.
- **Status:** akzeptiert, in OFFEN geführt (Details E-43).

