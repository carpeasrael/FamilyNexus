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
| Anmeldung im Browser (OAuth) in der Browser-App | Die Web-Version bietet keine OAuth-Rückkehr (Seitenwechsel verliert die Sitzung); dort gibt es Kontoanlage in der App (klassische Anbieter) oder den Weg über die Webseite des Anbieters und die Passwort-Anmeldung (E-55). |
| Einladungslink als https-Link (App-/Universal-Links) | Mail-Programme machen `familynexus://` oft nicht anklickbar; die Anleitung nennt „Link einfügen“. Ein https-Link bräuchte eine eigene Domain mit signierter Zuordnung (E-56). |
| Registrierung mit Telefonnummer, SSO-Registrierung | Nicht unterstützte Abläufe führen zum Hinweis „auf der Webseite des Anbieters anlegen“ (E-55). |
| Verifizierung per QR-Code | Nur Emoji-Vergleich (SAS). |
| Lokalisierte Emoji-Namen bei der Verifizierung | Emojis werden mit englischen Namen angezeigt (Symbole sind maßgeblich). |
| EXIF-Entfernung bei Bildern | Anhänge werden unverändert (verschlüsselt) gesendet. |
| Mehrere Familien je Konto | Eine Familie je Konto. |
| Gruppenchats außer dem Familienchat | Einzelchats gibt es nur zwischen zwei Mitgliedern (E-39). |
| Mehrere Einkaufslisten, Kategorien, Preise | Eine gemeinsame Liste je Familie (E-40). |
| Erinnerungen und Benachrichtigung zum Periodenwechsel bei Aufgabenlisten | Der Erinnerungs-Planer kennt nur Termine und ersetzt bei `replaceAll` alle geplanten Benachrichtigungen (E-51). |
| Nachträgliches Abhaken früherer Perioden, Fälligkeitszeiten, Unteraufgaben | Umfang (E-51). |
| Familie selbst verlassen | Mitglieder werden nur durch Moderatoren entfernt; Austritt (`leave`) fehlt in der Oberfläche. Das Recht auf Löschung wird über die lokale Löschung und die Kontolöschung beim Betreiber wahrgenommen. |
| Server durch Moderator ändern | Der Server ist in den Einstellungen nur lesbar; Wechsel = neue Familie/neue Anmeldung. |
| Löschmarken beim „Alle lokalen Daten löschen“ | Geteilte Termine bleiben bei den anderen Geräten bestehen; vor dem Löschen sollten sie einzeln gelöscht werden. |
| Chat-Benachrichtigungen (auch lokal) | Keine; siehe E-16. |

## Bekannte Einschränkungen

- **Einrichtung (E-55–E-57):** Zusatzschritte „Bedingungen“ und „kein Roboter“ (reCAPTCHA) sind nur gegen den Fake geprüft;
  der lokale Test-Synapse verlangt sie nicht. Die OAuth-Anmeldung (matrix.org) ist automatisch nur gegen den Fake geprüft,
  gegen den echten Anbieter manuell (Testplan TP-OAUTH-M1); der OAuth-Rücksprung braucht die Projektseite als `client_uri`.
  Beendet das System die App während der Anmeldung im Browser, ist die OAuth- bzw. UIA-Sitzung verloren (der Einladungslink
  bleibt erhalten); es genügt, erneut auf „Konto erstellen“ zu tippen. Ältere App-Versionen lehnen Einladungslinks `v=2`
  ab. Links von Servern im Heimnetz (IP/localhost) sind vor der Anmeldung nicht lesbar.
- **SA-8:** Notfall-Schlüssel in Zwischenablage (nach 60 s geleert) bzw. als unverschlüsselte Datei, nur auf ausdrücklichen Tipp.

- **Online-Status (E-38):** Mehrere Geräte desselben Kontos werden einzeln geführt; die Person gilt als online, solange irgendein
  Gerät online meldet. Im Hintergrund oder bei beendeter App gilt man nach 5 Minuten als offline (kein Push, keine
  Hintergrunddienste). „Zuletzt online“ ist nur seit dem letzten App-Start bekannt (nicht gespeichert). Der Server
  sieht den Takt der Gerätenachrichten (Metadaten).
- **Einzelchats (E-39):** Entfernt man ein Mitglied, bleibt der gemeinsame Raum bestehen (er wird ausgeblendet, nichts wird
  mehr gesendet); das automatische Verlassen fehlt. Entsteht durch gleichzeitiges Anlegen ein zweiter Raum für dasselbe
  Paar, gilt auf beiden Seiten der mit der kleinsten Raum-ID; Nachrichten im anderen Raum sind dann unsichtbar.
  Einzelchats werden nur nach vollständig geladener Mitgliederliste angezeigt; Einladungen Fremder bleiben unbeantwortet
  liegen (nicht abgelehnt).
- **Aufgabenlisten (E-51):** Der „Reset“ ist ein abgeleiteter Zustand (Periodenschlüssel), kein Ereignis; er wirkt auf jedem Gerät beim nächsten Neuzeichnen (Minutentakt, beim Öffnen). Rechte (nur Moderatoren legen an, nur die zugewiesene Person hakt ab) werden bei manipulierten Geräten nur beim Empfang durchgesetzt. Wird die zugewiesene Person entfernt, bleibt die Liste bestehen, abgehakt werden kann erst nach Neuzuweisung. Ein Zeitzonenwechsel der Liste verschiebt Periodengrenzen. Der Backfill ist auf 20 Seiten/5000 Signale begrenzt; ältere Verlaufseinträge fehlen ggf. auf neuen Geräten.
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

## Linux (E-50)

- Flatpak gebaut und gestartet (`tool/build_flatpak.sh --install`); nicht ausführlich bedient (Anmeldung gegen echten Server, Erinnerungen, Einladungslink aus dem Browser, Secret-Portal auf KDE/anderen Desktops).
- **SA-6:** keine App-Sperre (keine Geräteanmeldung für Apps unter Linux) und kein Bildschirmschutz (Wayland/X11 bieten keinen).
- Nur **x86_64** (Flutter liefert kein Linux-SDK für arm64 als Archiv). Der Build braucht Netzzugriff (pub, crates, Flutter-Engine) und ist deshalb nicht Flathub-konform; Verteilung als Bundle über GitHub-Releases (`flatpak install --user FamilyNexus-v….flatpak`, Laufzeit kommt von Flathub).
- Erinnerungen erscheinen nur, solange die App läuft (keine Hintergrunddienste; Benachrichtigungen über `org.freedesktop.Notifications`). Ein Tray-Symbol (Concept) fehlt.
- Ohne Flatpak (`flutter run -d linux`) braucht das System `libsqlcipher.so` (Arch/Manjaro: `sqlcipher`, Debian/Ubuntu: `libsqlcipher-dev`), libsecret und einen Secret Service; ohne SQLCipher startet die App bewusst nicht. Das gilt auch für `flutter test` auf Linux-Hosts.
- Die adaptive Zwei-Spalten-Ansicht für große Fenster fehlt wie unter macOS.

## Windows (E-52)

- Gebaut mit dem Release-Workflow (Job `windows`) und der Datenbank-Bibliothek geladen/geprüft; **nicht auf einem Windows-Gerät bedient** (Anmeldung gegen echten Server, Anmeldeinformationsverwaltung, Erinnerungen, App-Sperre mit Windows Hello).
- **SA-6:** kein Bildschirmschutz. Keine Code-Signatur: Windows SmartScreen warnt beim ersten Start („Weitere Informationen → Trotzdem ausführen“).
- Einladungslinks aus dem Browser funktionieren nicht automatisch (Schema nicht registriert, keine Einzelinstanz); Start mit `familynexus.exe familynexus://join?…` oder Link in der App einfügen. Zwei gleichzeitig gestartete Instanzen sind nicht abgesichert.
- Nur **x64**. Erinnerungen erscheinen nur, solange die App läuft. Kein Installer (Zip zum Entpacken).
- Die Plugin-Vorlagen brauchen unter neueren Visual-Studio-Versionen `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` (`windows/CMakeLists.txt`); entfällt, sobald `local_auth_windows` auf C++20-Coroutinen umgestellt ist.

## Web-Version (E-53)

- Gebaut und im Release-Workflow in Chrome (headless) geprüft: Datenbank-Verschlüsselung, Tresor, vodozemac, Start, Entsperren. **Nicht geprüft:** Anmeldung gegen einen echten Matrix-Server, Chat, Termine, Dateiauswahl, andere Browser (Firefox, Safari), Mobilbrowser, Installation als PWA.
- **SA-7:** Schutz hängt am Browser-Passwort; kein Bildschirmschutz, keine App-Sperre, kein Hardware-Schlüsselspeicher. Nicht auf fremden/gemeinsam genutzten Rechnern verwenden. Der Browser kann Website-Daten bei Speichermangel oder auf Wunsch löschen; dann ist die lokale Datenbank samt Tresor weg (Wiederherstellungsschlüssel der Matrix-Sicherung bereithalten).
- Passwort vergessen = alle lokalen Daten löschen. Keine Passwortänderung in der App.
- Der Matrix-Server muss Browseranfragen von `https://carpeasrael.github.io` erlauben (CORS; Synapse tut das standardmäßig) und per `https` erreichbar sein.
- Das Zip im Release ist für den Betrieb am Stamm einer Adresse gebaut (`<base href="/">`); für einen Unterpfad die Zeile in `index.html` anpassen. Auf GitHub Pages läuft die Fassung für `/FamilyNexus/`.
- Keine Erinnerungen und keine Benachrichtigungen (kein Hintergrunddienst im Browser). Einladungslinks (`familynexus://`) öffnen nichts automatisch: Link in der App einfügen. Keine Zwei-Spalten-Ansicht für große Fenster.
- Nur ein Tab gleichzeitig (Web Locks). Ältere Browser ohne Web Locks erzwingen das nicht.
- IndexedDB schreibt verzögert: Schließt man den Tab unmittelbar nach einer Änderung, kann sie fehlen.
- `'unsafe-eval'` in der Inhaltsrichtlinie (vodozemac-Anbindung); entfällt, sobald die Anbindung ohne `new Function` auskommt.
- Das SDK-Patch-Skript ist auf `matrix` 14.2.0 festgelegt und bricht bei jeder anderen Version ab (bewusst).

## Betrieb / Build

- Ende-zu-Ende-Tests laufen nur lokal gegen einen eigenen Synapse (`tool/e2e.sh`), nicht gegen Produktivserver.
- Obfuskierung wird nur durch `tool/build_release.sh` erzwungen (ein direktes `flutter build apk --release` ist nicht obfuskiert); Release stets über das Skript bauen.
- Release-Signierung braucht `android/key.properties` (nicht eingecheckt); ohne bleibt das APK unsigniert.
- Rust-Toolchain ist Build-Voraussetzung (vodozemac wird aus Quelltext gebaut).
- Dart-AOT-Symbole: `flutter build --obfuscate` warnt vor unobfuskierten DWARF-Informationen in der ELF-Bibliothek;
  Android-Release verwendet `--split-debug-info`, Code ist per R8 minimiert.
