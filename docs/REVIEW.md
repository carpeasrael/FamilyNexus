# Review-Protokoll

Jede Phase wird von einem separaten Review-Agenten (frischer Kontext, ohne Wissen zur Entstehung) gegen `Concept.md` und die Sicherheitsvorgaben geprüft. Funde und Behebung stehen hier.

## Phase 1 – Fundament (2026-10-21)

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| S1 | hoch | Schlüsselverlust führte zu Absturz bzw. stillem Neuschlüssel; `getOrCreateKey` nicht atomar | `AppDatabase.open` erzeugt bei vorhandener DB nie einen neuen Schlüssel (`KeyLostException`); Startfehler-Bildschirm mit Wiederholen/Zurücksetzen; paralleles `getOrCreateKey` liefert dasselbe Future; `resetOnError:false` im Keystore-Plugin (Standard hätte still gelöscht). Geräte-Tests ergänzt |
| S2 | hoch | `AppLog.redact` ließ Geheimnisse bei `password: x`, `Bearer …`, Zitaten durch; Fehler gingen ungefiltert nach logcat | Neue Muster mit Wortgrenzen, Trennern, Anführungszeichen, Bearer, langen Blobs; `FlutterError.onError`/`PlatformDispatcher.onError` → `AppLog`; Tests für alle Varianten (fanden dabei einen echten Bearer-Fehler) |
| S3 | mittel | `FLAG_SECURE` erst nach Dart-Start | Nativ in `onCreate` gesetzt; Manifest-Test; Fehler werden geloggt |
| S4 | mittel | `serverUrl` aus Speicher nicht validiert | `ServerUrl`-Prüfung in `fromMap`/`copyWith`; Tests |
| S5 | mittel | Test-Doubles im Produktionscode | nach `test/support/memory_stores.dart` verschoben |
| S6 | mittel | Dart-Obfuskierung nicht erzwungen | `tool/build_release.sh`, Test, E-22 präzisiert |
| S7 | niedrig | `path_provider` nur im Test genutzt | in `dev_dependencies` |
| S8 | niedrig | Plugin-/minSdk-Defaults implizit | `AndroidOptions(resetOnError:false)`, `minSdk=26` explizit |
| K1 | hoch | `onError` weiß auf `danger` (Dunkel) < AA | dunkles `onError`; Test prüft alle ColorScheme-Paare beider Themes |
| K2 | mittel | `SettingsController.update` ohne Fehlerbehandlung | atomares `apply`, Rollback + Log bei Fehler; Test |
| K3 | mittel | Dropdowns ohne semantisches Label | `Semantics(label)` |
| K4 | niedrig | „Effekte reduzieren“ ignoriert Systemeinstellung | bewusst nicht (Concept: eigene Option) – dokumentiert |
| K5 | niedrig | Migrationen ungetestet | Gerätetest deckt `onCreate`; Upgrade-Test folgt mit der ersten echten Migration (Phase 3) |
| A1 | mittel | README noch Vorlage, SBOM/OFFEN fehlen | README/OFFEN/ABHAENGIGKEITEN folgen in Phase 5 (Plan 5.4) |
| W1 | mittel | Domäne importierte Flutter | Domäne rein Dart; `KeyValueStore` als Port in `domain/`; Architekturtest erzwingt Schichten |
| W2 | niedrig | Kanalname doppelt | Vertragstest Dart ↔ Kotlin |
| W3 | niedrig | `HomeShell` baute Tabs neu | `IndexedStack` |
| T1 | mittel | Tests teils tautologisch (Manifest, Backup-Regeln, Berechtigungen, l10n-Regex, Scan überspringt Secure-Storage-Datei) | Tests verschärft: exakte Berechtigungsliste, `<exclude>` statt `contains`, mehrzeiliger l10n-Scan über ganz `lib/`, Scan inkl. Keystore-Datei |

Nicht übernommen: Zusätzlicher Test, dass `NoopScreenProtection` nicht im Release verdrahtet ist – entfällt, da das Double nun nur unter `test/` liegt.

## Phase 2 – Matrix und E2EE (2026-10-21)

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| S1 | hoch | SDK sendet bei fehlender Krypto im Klartext; Retry-Pfade ungeprüft | `_requireEncryptedRoom` (Client-Krypto + Megolm) vor jedem Senden/Wiederholen (E-27) |
| S2 | hoch | TLS-Pflicht nicht durchgesetzt (SDK-`.well-known`, Weiterleitungen; NSC gilt nicht für dart:io) | `HttpsOnlyClient`, `checkWellKnown:false`, bestätigte Basisadresse beim Login; Tests (E-26) |
| S3 | mittel | SDK-Logs/`print(wtf)` gelangen nach logcat | nur Typ bei Fehler-Level, Puffer geleert, ruhige Zone um `main`; Tests |
| S4 | mittel | Anhänge: unbegrenzter Download, Name/MIME nicht gebunden, Bild-Bombe | begrenzter Download, Endung=MIME, `cacheHeight`; Tests (E-28) |
| S5 | mittel | Schlüsselweitergabe vor Cross-Signing nicht dokumentiert | **Sicherheitsabweichung SA-1**, Schließung in Phase 4 |
| S6 | niedrig | Anzeigenamen/Reaktionen unbereinigt | `TextSanitizer`, Reaktionen nur Emoji, max. 12 |
| S7 | niedrig | `m.homeserver` als Nicht-Map warf | defensiv; Test |
| K1 | hoch | `size` als Kommazahl/Text ließ Chat abbrechen | `tryGet<int>`, Anhang blockiert; pro Ereignis abgesichert; Test mit echten SDK-Objekten |
| K2 | hoch | Antwort-Fallback im Text | `calcUnlocalizedBody(hideReply:true)`; Test |
| K3 | hoch | nicht entschlüsselbare Nachrichten verschwanden | sichtbarer Platzhalter (l10n) |
| K4 | hoch | `createFamily` konnte Familie überschreiben | Abbruch (`alreadyExists`); Einrichtung wartet auf ersten Sync |
| K5 | mittel | `waitForRoomInSync` ohne Timeout, Kontodaten nicht wiederholt | Verweis zuerst (2 Versuche), Timeout 30 s |
| K6 | mittel | `events`-Override ersetzt Standard-Map | explizite Stufen inkl. Tombstone/ServerACL=100; Test „alle Anfangszustände für Ersteller erlaubt“; Echtserver-Test offen (OFFEN) |
| K7 | mittel | Zustand bei erzwungenem Logout | gemeinsames `_resetLocal` |
| K8 | mittel | Retry parallel/unbegrenzt | In-Flight-Menge, Grenze 5, Fehler sichtbar |
| K9 | mittel | keine Paginierung | `loadOlderMessages` + Scroll-Auslöser |
| K10 | niedrig | Duplikat-Reaktion, Antwort auf unbekanntes Ereignis, Rate-Limit-Fehler | still ignoriert / `notFound` / `rateLimited` |
| A1 | mittel | Privatraum in 2.6 versprochen | verschoben nach 3.3 (E-29), PLAN korrigiert |
| A2 | mittel | Mindestversion/Versionsanzeige | v1.1 verlangt, höchste Version angezeigt |
| A3 | niedrig | `file_picker` außerhalb der Plattform-Schicht | `FileAccess`-Port; Architekturtest erweitert |
| T1 | mittel | Gateway ungetestet; Fake tautologisch | Tests mit echten SDK-Objekten (`chat_mapper_test`), Spezifikations-/Sicherheitstests; verbleibende Lücke (Raumerzeugung, Senden, Sync gegen echten Server) in OFFEN |

## Phase 3 – Kalender (2026-10-21)

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| K1 | hoch | Start-Backlog der Kalendersignale ging verloren (Kalender abonniert nach der ersten Aktualisierung) | Signalverlauf (≤ 5000) wird späten Zuhörern wiedergegeben; **E2E-Test gegen echten Synapse** |
| K2 | hoch | Familien-Zeitleiste nur 30 Ereignisse | Nachladen (20 Seiten) auch für den Familienraum, `requestHistoryOnLimitedTimeline`; Grenze in OFFEN |
| K3 | hoch | privat → geteilt konvergierte auf eigenem Zweitgerät nie | Übergang für den Besitzer mit höherer Version erlaubt; Test mit zwei Geräten |
| K4 | hoch | Race bei parallelen Signalen | serielle Warteschlange + Sperre im Dienst; Reihenfolgetests |
| K5 | mittel | Resync unzuverlässig (Lazy-Loading-Basis, einmaliges Senden) | Basis erst nach geladener Mitgliederliste; Neuvormerken in der Warteschlange |
| K6 | mittel | Serverfehler verwarf Termine als „veröffentlicht“ | Serverfehler nie `invalidInput`; nur lokale Codec-Fehler verwerfen |
| K7 | mittel | Erinnerungen ganztägiger Termine um 01:00 Uhr | 09:00 Ortszeit, Geräte-Zone; Tests |
| K8 | mittel | Planung nicht serialisiert, kein Auffrischen | Serialisierung, Auffrischen bei Rückkehr, Absagen übersprungen |
| K9 | niedrig | Ende vor Beginn ließ Termin verschwinden | Validierung + Fehlermeldung im Editor |
| K10 | niedrig | Zeitzone beim Bearbeiten | Geräte-Zone wird gesetzt |
| K11 | niedrig | Standard „geteilt“; 23-Uhr-Standard; Sichtbarkeitswechsel in zwei Schritten | Standard privat; Folgetag; Wechsel zuerst, dann Inhalt |
| S1 | mittel | privater Raum nur über Zeiger | Prüfung vor jedem Senden (nicht Familienraum, nur eigenes Konto) |
| S2 | mittel | keine Speichergrenzen | Verlauf ≤ 20, ≤ 2000 Termine je Absender, Antworten nur für bekannte geteilte Termine |
| S3 | niedrig | Steuer-/Bidi-Zeichen in Texten | Ereignis wird verworfen; Tests |
| S4 | niedrig | Erinnerungen überlebten Abmeldung/Löschung | `cancelAll` bei Abmeldung/Reset/Kontowechsel (nicht beim Schließen der UI) |
| A1 | mittel | „Farbe pro Person“ fälschbar, Besitzer nur als Farbe | Personenfarbe aus Besitzer, Name als Text |
| A3 | niedrig | Doku inkonsistent | E-13/E-15 korrigiert, E-33 ergänzt |
| T1–T3 | mittel | Tests tautologisch/lückenhaft | realistischer Veröffentlichen-dann-Privat-Test; neue Tests für K3–K9, S2, S3; E2E gegen echten Server |
| Zusatz | – | E2E gegen echten Synapse fand: privater Raum nach Anlage nicht sofort nutzbar | Raum-ID gemerkt bis Kontodaten eintreffen |

## Phase 4 – Familie und Rollen (2026-10-21)

Review durch separaten Agenten (frischer Kontext) gegen Concept und Sicherheitsvorgaben.

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| S1 | hoch | Fremde Mitglieder per TOFU vertraut, Schlüsselwechsel still akzeptiert | Hauptschlüssel je Mitglied vermerkt; bei Änderung Geräte gesperrt, Warnung + Badge, Freigabe nur ausdrücklich (E-37); Widget-Test |
| S2 | hoch | Einladungslink ohne Integrität/Einmaligkeit | Zufalls-ID im Link, Vermerk beim Moderator, Prüfung in Gateway und UI, Verbrauch, Rückfrage mit voller ID (E-37); **E2E gegen Synapse** (gefälscht / Wiederverwendung) |
| S3 | mittel | Eingeladene erhalten Schlüssel vor Annahme; Einladen ohne Rückfrage | Rückfrage vor dem Einladen; **SA-2** (SDK-Verhalten, nicht behebbar ohne Fork) |
| S4 | mittel | Verifizierungsanfragen Fremder, Überschreiben, kein Reset | nur Selbst/Familie, eine zur Zeit, `m.user`-Abbruch, Reset beim Abmelden |
| S5 | mittel | `acceptInvitation` ohne Prüfung | Warnung bei fremder Einladung, Megolm-Prüfung nach Beitritt (sonst Austritt) |
| S6 | mittel | Schlüsselanzeige ohne erzwungenen Bildschirmschutz; Restore konnte neue Identität anlegen; falsche Fehlerabbildung | Schutz erzwungen, Restore bricht ab, Netzwerkfehler getrennt |
| S7 | mittel | Lokale Daten vermischen sich bei Familienwechsel | Besitzer = Konto + Familienraum, Löschen bei Wechsel |
| S8 | mittel | `via` ungeprüft | Domain-Abgleich, IP/localhost abgelehnt; Unit-Tests |
| S9 | niedrig | Deep-Link-Intent bleibt erhalten | → OFFEN (Link wird nur vorgemerkt, nie automatisch ausgeführt) |
| S10/S11 | niedrig | Moderator-Redaktion; Kick statt Bann | dokumentiert (E-37), Re-Knock durch Nonce abgesichert |
| K1 | niedrig | `exp` riesig → Ausnahme | Grenzen vorab geprüft; Test |
| K2 | niedrig | nicht atomarer Beitritt | Vermerk zuerst, Rücknahme bei Fehlschlag |
| K3–K5 | niedrig | Mehrfachanfragen, Sackgassen, Backup-Prüfung | Mehrfachanfragen durch Nonce-Verbrauch begrenzt; Rest → OFFEN |
| K6 | niedrig | Verifizierungsfehler verschluckt; Link bei bestehender Familie stumm | Fehler als Meldung; Pflicht-Sicherung wird durch das Tor in `AppRoot` erzwungen (kein Gateway-Zwang → OFFEN) |
| Anf. | niedrig | Menü-Tooltip nur Name | „Aktionen für {name}“ |
| T1–T7 | mittel | Testlücken | neue Tests: Nonce/Fälschung/Wiederverwendung (E2E), Identitätswechsel, Rückfragen, Link-Grenzen; Rest → OFFEN |

Nicht umgesetzt (→ OFFEN): Geräte sperren/Fernabmelden, Verifizierungsstatus-Hinweis nach Beitritt, Identitätswechsel-E2E (Zurücksetzen von Cross-Signing), Prozess-Tod bei Schlüsselanzeige.

## Phase 5 / Gesamtreview (2026-10-21)

Separater Review-Agent gegen Concept und Sicherheitsvorgaben.

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| H1 | hoch | Obfuskierung nur durch Skript erzwungen | Release über `tool/build_release.sh` gebaut: Symboldateien und R8-Mapping vorhanden; Hinweis in OFFEN |
| H2 | hoch | „Anhang speichern“ unverschlüsselt, undokumentiert; Picker-Cache | Warndialog, **SA-3**, Cache nach dem Einlesen geleert, E-19 korrigiert |
| M1 | mittel | Gateway-Routing privat/geteilt nur im E2E | E2E vorhanden (Synapse); Unit-Test mit SDK-Room-Fake → offen (OFFEN) |
| M2 | mittel | Löschmarke verriet Zeit/Farbe eines nie veröffentlichten Termins | Löschmarke ohne Zeitpunkt/Zeitzone/Farbe |
| M3 | mittel | Sichtbarkeitswechsel + Bearbeiten zweistufig | dokumentiert (OFFEN) |
| M4 | mittel | Erinnerungen bei jedem „nicht bereit“ gelöscht | nur noch bei Abmeldung |
| M5–M8 | mittel | Doku/Umfang: E-16, fehlende Punkte, SA für Verschlüsselungs-PL, Plan | E-16 korrigiert, OFFEN erweitert, **SA-4**, PLAN abgehakt |
| L4 | niedrig | Zusagen für nicht (mehr) geteilte Termine | Prüfung in `respond` und Veröffentlichung |
| L1–L3, L5–L8 | niedrig | Totcode, Familienwechsel, Effekte, Sonstiges | dokumentiert in OFFEN |

Hinweis zur Arbeitsweise: Die Vorgabe „kleine Commits“ wurde nur phasenweise erfüllt (wenige größere Commits).

## Phase 6 (2026-10-21): Online-Status, Einzelchats, Einkaufszettel

Separater Review-Agent (Quelltext des matrix-SDK 14.2.0 gegengeprüft; keine erfundenen APIs, `encryptedContent` wird nur im Olm-Pfad gesetzt).

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| 1 | hoch | Löschmarken zählten dauerhaft gegen die Obergrenze (Liste nach ~700 Löschungen unbenutzbar, gezielt auslösbar) | Bei voller Ablage werden die ältesten **veröffentlichten** Löschmarken verdrängt (≤ 200 bleiben); unveröffentlichte nie; Tests |
| 2 | hoch | `getTimeline` eines Einzelchats ohne Fehlerbehandlung blockierte den gesamten Abgleich | Fehler je Raum abgefangen und geloggt |
| 3 | mittel | Einzelchat-Räume mit Dritten/ungeprüfter Größe, beliebig viele Einladungen | Nur Räume mit höchstens zwei Mitgliedern (Summary); größere Räume werden nach dem Beitritt verlassen; je Mitglied nur ein Einzelchat, weitere Einladungen ignoriert |
| 4 | mittel | Dauerhafte Sperre einer Einladung nach vorläufigem Fehler | Erneuter Versuch nach 1 Minute; dauerhaft nur bei ungeeignetem Raum |
| 5 | mittel | `_refresh` parallel ausführbar (Leck/Null-Zugriff beim Abmelden während des Abgleichs) | `_refresh` serialisiert (ein Durchlauf, ein Nachlauf), Epoche verwirft veraltete Ergebnisse |
| 6 | mittel | Zeitüberschreitung in `startDirectChat` konnte Raum ohne `m.direct`-Eintrag hinterlassen | Eigene Zeitschranke entfernt |
| 7 | mittel | Status eines Mitglieds mit mehreren Geräten: letzter Zeitstempel gewann | Status je Gerät (Schlüssel des sendenden Geräts); online, solange irgendein Gerät aktuell online meldet; Tests |
| 9 | mittel | Abmelden meldete nicht „offline“; Familienwechsel setzte Status nicht zurück | `AppServices.logout()`/`goOffline()`, Rücksetzen bei Familienwechsel, Zähler gegen Dauerfehler (10 s) |
| 10 | mittel | Hochgesetzte Versionen machten Einträge unveränderbar | Empfang: erste Version ≤ 10000, Sprung ≤ 1000; Tests |
| 12 | niedrig | Doku (Kommentar „fünf Bereiche“), `.DS_Store` im Repository | korrigiert, `.DS_Store` aus dem Index entfernt und ignoriert |
| 8 | – | Status standardmäßig an | bewusst (E-38), im Datenschutztext und als Schalter sichtbar |
| 11 | niedrig | Resync erreicht Einträge ehemaliger Bearbeiter nicht | dokumentiert (OFFEN) |
| 13–17 | niedrig | `chatRequest` vor Aufbau, Snapshot-Kopien, Presence an Geräte mit geändertem Schlüssel | bewusst belassen bzw. dokumentiert |

Testlücke (→ OFFEN): `_acceptDirectInvites`/`_eligibleDirectRooms`/`_onToDevice` laufen nur im Synapse-E2E, nicht als Unit-Test mit SDK-Fake.


## Phase 8 (2026-10-24): Einfache Einrichtung, Kontoanlage, Einladen und Beitreten

Separater Review-Agent über `774c009..HEAD` (SDK-Verhalten an matrix-14.2.0 gegengeprüft). Kein Fund „hoch“.

| # | Schwere | Fund | Behebung |
|---|---|---|---|
| R1 | mittel | Beitrittskarte (für Beitretende die eigentliche Sicherheitsabfrage) zeigte nur Namen aus dem Link | Karte nennt immer den Anbieter der einladenden Person; deutliche Warnung, wenn er vom Server der Familie abweicht (E-56) |
| R2 | mittel | Mobil: alter OAuth-Wartevorgang konnte den neuen abbrechen (geteilter Zustand) | Jeder Versuch ist ein eigenes `OAuthAttempt`; Test „ein neuer Versuch beendet den alten …“ |
| R3 | mittel | „Zurück“ während der Browser-Anmeldung ließ sie weiterlaufen; Anmeldung landete auf der Startseite | „Zurück“ und `dispose` beenden Versuch und Registrierung; angemeldet in jedem Schritt vor der Absicherung → weiter; Test |
| R4 | mittel | Passwort blieb nach Netzfehler mitten in der Registrierung im Gateway | Oberfläche und Gateway behalten die Registrierung nur bei vorübergehenden Fehlern; sonst und bei `dispose`, `login`, `startOAuth` verworfen; Test |
| R5 | mittel | Leeren der Zwischenablage wirkt im Hintergrund oft nicht | Erneute Prüfung beim Zurückkehren; Android markiert den Schlüssel als vertraulich (`EXTRA_IS_SENSITIVE`); SA-8 ehrlich formuliert |
| R6 | mittel | Vollständige ID + sofortiges Absenden schickte das Passwort an den bisherigen Anbieter | „Anmelden“ erst, wenn der Anbieter zur ID passt; Test |
| R7 | mittel | Echte UIA-/OAuth-Logik nur über den Fake getestet | `test/data/sdk_registration_test.dart`: echtes `SdkMatrixGateway` gegen nachgestellte Antworten (Sitzung/Schritte, Zugangscode, Dummy-Schleife, Fehlerzuordnung, PKCE, state, Rücksprungprüfung, Token-Anfrage) |
| R8 | niedrig | Fremder Rücksprung brach die echte Anmeldung ab | Fremder `state` → `oauthStateMismatch`, es wird weiter gewartet; Tests |
| R9 | niedrig | OAuth-Metadaten auch bei Passwort-Anmeldung abgefragt | nur noch im OAuth-Weg |
| R10 | niedrig | Vorübergehender Fehler zeigte „kein Konto möglich“ | 429/5xx/Netz → Fehler mit „Erneut versuchen“; Test |
| R11 | niedrig | unstable-Pfad erkannt, den das SDK nicht nutzt | entfernt; Test |
| R12 | niedrig | Token-/Widerrufs-Endpunkt nicht auf https geprüft | alle Endpunkte der SDK-Metadaten vor der Client-Anmeldung geprüft; Test |
| R13 | niedrig | Eigener Link mit vielen Emoji zu lang | Namen werden gekürzt bzw. weggelassen; Test |
| R14 | niedrig | Link in anderer Schreibweise nicht vorgemerkt; Wiederherstellung ohne `ownHost` | vereinheitlicht gespeichert (`InviteLink.normalized`), `ownHost` bei der Wiederherstellung; Test |
| R15 | niedrig | Nicht lesbare Einladenden-ID ließ „Verbinde …“ stehen | Anbieterprüfung startet trotzdem (bisheriger Anbieter) |
| R16 | niedrig | „Benutzername frei“ galt nach Anbieterwechsel weiter | erneute Prüfung bei Anbieterwechsel |
| R17 | niedrig | Abfrage `POST /register` ohne `inhibit_login` | `{"inhibit_login": true}`; Status 200 wird protokolliert und ignoriert; Test |
| R18 | niedrig | Texte: „Wir haben eine E-Mail …“, Hinweis zum Benutzernamen, „Einladungscode“ verwechselbar, „Server“ | korrigiert („Der Anbieter hat …“, „Zugangscode des Anbieters“, „Anbieter“) |
| R19 | niedrig | Testplan nicht eingecheckt | eingecheckt |
| R20 | niedrig | Gefälschter Link legt Konto beim Anbieter des Angreifers an | wie R1; Begründung in E-56 korrigiert |
