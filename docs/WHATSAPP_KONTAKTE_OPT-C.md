# WhatsApp als gekoppeltes Gerät in der App (Weg C, Detailkonzept)

Stand: 2026-10-31 · Status: **Entwurf, nicht umgesetzt, rechtliche Freigabe fehlt** · Basis: Version 1.2.1 (22),
`docs/KONTAKTE.md`, `docs/WHATSAPP_KONTAKTE.md` · Entscheidung: E-76 (vorgeschlagen) · Sicherheitsabweichung: SA-12 (vorgeschlagen)

Dieses Dokument detailliert Weg C aus `docs/WHATSAPP_KONTAKTE.md`: FamilyNexus wird mit der Bibliothek `whatsmeow` ein gekoppeltes
Gerät des vorhandenen WhatsApp-Kontos. Gate G0 (rechtliche Freigabe) und die Grundsätze W1–W9 aus dem Hauptkonzept gelten
unverändert, soweit Abschnitt 2 nichts anderes sagt. **Vor G0 kein Code und kein Test gegen WhatsApp-Server.**

## 1. Ergebnis vorab

Weg C ist der einzige Weg, der alle vier Anforderungen fachlich erfüllt. Er verstößt nach meiner Lesart gegen die WhatsApp-Bedingungen
(keine Rechtsberatung) und hat im Detail mehr Grenzen, als das Hauptkonzept annahm.

| Anforderung | Weg C | Grenze |
|---|---|---|
| A1 Chatten | **Ja** | Nur bei laufender App, keine Anrufe |
| A2 In Kontakte aufnehmen | **Ja** | Aus den WhatsApp-Kontakten des Kontos |
| A3 Status sehen | **Ja, mit Preis** | Online-Status nur, wenn man selbst online erscheint |
| A4 E2EE | **Ja** | Hängt an einer inoffiziellen Implementierung; Meta sieht Metadaten |

**Was gegen den Bau spricht:**

| # | Befund | Folge |
|---|---|---|
| R1 | **Warnungen und Sperren trotz normaler Nutzung.** In whatsmeow-Issue #810 berichten Nutzer von der Meldung „Your account may be at risk“ auch ohne Massenversand, bei rein antwortenden und sogar untätigen Konten, teils mit Sperre. Maintainer äußerten sich nicht zur Ursache. | Risiko besteht auch bei vorbildlichem Verhalten. Zahlen gibt es keine |
| R2 | **Android auf dem Hauptgerät ist nicht koppelbar.** Der QR-Code muss mit dem Telefon gescannt werden, auf dem WhatsApp läuft. Die Code-Kopplung verlangt einen Namen der Form `Browser (OS)`, den die App nicht wahrheitsgemäß angeben kann (Abschnitt 2). | Android nur als Zweitgerät; der häufigste Fall fällt weg |
| R3 | **Technische Selbstauskunft als Web-Client.** whatsmeow meldet Plattform `WEB`, Gerät `Desktop` und eine WhatsApp-Web-Version. | Die frühere Zusage „keine Tarnung“ gilt nur eingeschränkt. Für G0 relevant |
| R4 | **Keine verschlüsselte Ablage von Haus aus.** whatsmeow speichert Schlüssel in SQLite oder Postgres; ein gepflegter SQLCipher-Treiber für Go ist nicht gesichert. | Muss C0 lösen, sonst Abbruch |
| R5 | **Laufende Pflege.** Die Bibliothek enthält eine feste Web-Version. Veraltete Clients lehnt WhatsApp ab. | Kurzfristige Releases ohne Vorwarnung |

**Einordnung:** Am Desktop gibt es WhatsApp bereits offiziell. Der Gewinn ist dort eine gemeinsame App, der Einsatz ist das WhatsApp-Konto
der Person. Auf dem Telefon, wo der Nutzen am größten wäre, greift R2.

**Empfehlung:** Weg C nur bauen, wenn G0 positiv ausfällt **und** der Herausgeber den Einsatz als bewusstes Zusatzangebot für Desktop und
Zweitgeräte will. Sonst ist Verzicht die bessere Entscheidung.

## 2. Korrekturen am Hauptkonzept

Der Quellcode von whatsmeow widerlegte oder präzisierte frühere Aussagen aus `docs/WHATSAPP_KONTAKTE.md`. Die Korrekturen sind dort übernommen; die Tabelle hält fest, was sich geändert hat. Bei Abweichungen geht dieses Dokument vor.

| Hauptkonzept | Befund | Neue Regel |
|---|---|---|
| Kopplung per QR **oder Code** (7.1, 6.4) | `PairPhone`: Name muss `Browser (OS)` lauten, nur gängige Werte, sonst Fehler 400 | **Nur QR.** Ein Name wie `Chrome (Android)` wäre eine Falschangabe (W5) |
| W5 „Keine Tarnung als offizieller Client“ | Standardwerte: `Platform: WEB`, `WebSubPlatform: WEB_BROWSER`, feste Web-Version. Eine Abweichung ist für die Bibliothek nicht vorgesehen | W5 neu: siehe unten |
| „Name wie FamilyNexus (Linux), soweit erlaubt“ | `SetOSInfo` setzt `DeviceProps.Os` | `SetOSInfo("FamilyNexus", …)`; Anzeige am Telefon in C0 prüfen |
| Gelesen-Meldung bei Status „in W0 klären“ | `MarkRead` ist ein ausdrücklicher Aufruf | Für Status nie aufrufen; Beleg am Testkonto in C0 |
| Offener Punkt Lizenzen | MPL-2.0 plus `go.mau.fi/libsignal` | Abschnitt 15 |
| „Rückfall lokal löschen, wenn Logout offline scheitert“ | `Logout` löscht bei Fehlschlag nichts | Bestätigt, also eigene Löschung nötig (9.3) |

**W5 neu:** Die App fügt **keine** Tarnung hinzu. Sie bleibt beim Standardverhalten der Bibliothek, nennt sich am Telefon `FamilyNexus`,
ruft `SetWAVersion` nicht auf, ahmt kein Nutzerverhalten nach, verteilt Versand nicht zeitlich, um Erkennung zu vermeiden, und umgeht weder
Sperren noch Warnungen. Dass die Bibliothek sich technisch als Web-Client meldet, ist offenzulegen und gehört in die Prüfung von G0.

## 3. Überblick

```
┌─ Flutter ──────────────────────────────────────────────────────┐
│ features/whatsapp, features/chat ─▶ ChatHub                    │
│                                       ├─▶ MatrixGateway        │
│                                       └─▶ WhatsAppGateway      │
│                                            │  dart:ffi         │
│ familynexus_wa.db ◀─ SqlWhatsAppStore ◀────┤                   │
└────────────────────────────────────────────┼───────────────────┘
                                             ▼
┌─ libfn_whatsapp (Go, c-shared) ────────────────────────────────┐
│ bridge: Befehle, Ereignisse, Binärkanal, Bestätigungen         │
│ waclient: Schnittstelle um whatsmeow.Client (testbar)          │
│ mapping: waE2E.Message ⇄ DTO      store: SQLCipher             │
│ whatsmeow · go.mau.fi/libsignal                                │
└────────────────────────────┬───────────────────────────────────┘
       familynexus_wa_keys.db │ WebSocket, Noise, Signal
                              ▼
                  WhatsApp-Server (Meta) ◀──── Telefon der Person (Hauptgerät)
```

Kein Server des Herausgebers, kein Matrix-Bezug. Ausfall des Kerns betrifft nur den WhatsApp-Bereich.

**Aufgabenteilung:** Go verwaltet Protokoll und Signal-Schlüssel und hält **keine** Nachrichten. Dart besitzt Nachrichten, Regeln und
Oberfläche. So bleibt der Kern austauschbar, und Sicherheitsregeln liegen an einer Stelle wie heute.

## 4. Go-Kern

### 4.1 Struktur

```
native/fn_whatsapp/
  go.mod, go.sum            Fester whatsmeow-Commit, go 1.26, toolchain go1.27.2
  main.go                   //export fn_wa_*
  bridge/                   Befehlsverteilung, Ereignisposten, Bestätigungen, Binärkanal
  waclient/                 Schnittstelle + echte Implementierung
  mapping/                  Eingehend und ausgehend, unbekannte Typen ergeben Platzhalter
  store/                    SQLCipher-Anbindung, Upgrades
  policy/                   Sperren der Befehle nach Zustand
  logging/                  No-op-Logger, Fehlercodes ohne Inhalte
```

### 4.2 C-Schnittstelle

```c
int32_t fn_wa_open(const char* config_json, void* post_cobject, int64_t event_port);
int32_t fn_wa_call(const char* request_json);                 // kehrt sofort zurück, Antwort als Ereignis
int32_t fn_wa_put_bytes(int64_t id, const uint8_t* p, int64_t n);  // Anhang Dart → Go
void    fn_wa_ack(int64_t event_id);                          // Dart hat dauerhaft gespeichert
void    fn_wa_free(void* p);                                  // gibt von Go gelieferte Daten frei
void    fn_wa_close(void);
```

- Dart übergibt `NativeApi.postCObject` und einen `ReceivePort`. Ereignisse kommen so ohne Abfrage-Schleife an. Der Zeiger ist die
  einzige Rückrichtung.
- JSON mit Feld `v`; bei unbekannter Version bricht der Start mit Fehlercode ab, der WhatsApp-Bereich bleibt aus.
- Anhänge laufen über den Binärkanal, nicht als Base64 und nie über temporäre Dateien (E-19).

### 4.3 Einstellungen am Client

| Einstellung | Wert | Grund |
|---|---|---|
| `SynchronousAck` | `true` | Bestätigung an WhatsApp erst nach Speicherung; kein Nachrichtenverlust |
| `UseRetryMessageStore` | `true` | Wiederholungen überstehen einen Neustart |
| `AutoTrustIdentity` | `true` | Sonst scheitert Entschlüsselung; Anzeige über `IdentityChange` |
| `AutomaticMessageRerequestFromPhone` | `true` | Nicht entschlüsselbare Nachrichten vom Telefon nachfordern |
| `ManualHistorySyncDownload` | `true` | Verlauf nur nach Zustimmung (W9) |
| `EmitAppStateEventsOnFullSync` | `true` | Kontakte beim ersten Abgleich erhalten |
| `ErrorOnSubscribePresenceWithoutToken` | `true` | Kein Status ohne bestehende Beziehung |
| `EnableAutoReconnect` | `true`, Stopp bei dauerhaften Trennungen | Abschnitt 10 |
| Proxy | Aus der Umgebung nicht übernehmen | whatsmeow liest sonst `https_proxy`; in C0 festlegen |
| `SetOSInfo` | `FamilyNexus` | W5 |
| `DeviceProps.RequireFullSync` | `false` | Datensparsam |
| `SetMediaHTTPClient` | Eigener Client, TLS ≥ 1.2, Zeitlimits | `HttpsOnlyClient` wirkt in Go nicht |

### 4.4 Verschlüsselte Schlüsselablage

`sqlstore` kennt nur SQLite und Postgres und verlangt Fremdschlüssel. `NewWithDB` nimmt ein bestehendes `*sql.DB`.

| Option | Bewertung |
|---|---|
| **A** `mattn/go-sqlite3` gegen SQLCipher linken, `PRAGMA key` im Verbindungs-Hook | **Vorschlag.** Gleiches SQLCipher wie Flatpak, AppImage und Windows (E-50, E-52). Android braucht einen eigenen Build je ABI |
| **B** `mutecomm/go-sqlcipher` oder Fork | Upstream wirkt veraltet, Fork von WissCore ungeprüft. Nur Rückfall |
| **C** Eigene Umsetzung von `store.AllStores` per FFI nach Dart | Abgelehnt: viele synchrone Aufrufe, Fehlerrisiko bei Kryptozustand |
| **D** Unverschlüsselt | **Ausgeschlossen** (E-05) |

Die Dialekt-Erkennung von `dbutil` ist bei eigenem Treibernamen über `NewWithWrappedDB` zu lösen. Schlüssel: `db.whatsapp`, erzeugt mit
`AppDatabase.resolveKey`, im Go-Prozess nur im Arbeitsspeicher. Prüfung in C0: Datei ohne Schlüssel nicht lesbar.

## 5. Dart-Schicht

### 5.1 Dateien

```
lib/domain/whatsapp.dart             WaPeer, WaMessage, WaLink, WaPresence, WaStatusPost, WaRules
lib/domain/chat_backend.dart         ChatBackend aus dem Hauptkonzept 6.2
lib/data/whatsapp/
  whatsapp_gateway.dart              Schnittstelle (Hauptkonzept 6.4)
  ffi_whatsapp_gateway.dart          Nur mit dart:ffi, bedingter Import für Web
  whatsapp_stub.dart                 Store-Ausgaben und Web
  wa_mapper.dart                     Eingaben als nicht vertrauenswürdig: bereinigt wie ChatMapper
  sql_whatsapp_store.dart            Tabellen aus 5.3
  wa_sync.dart                       Ereignisse → Store → Oberfläche, Bestätigung an Go
lib/app/chat_hub.dart                `wa:` → WhatsApp, sonst Matrix
lib/features/whatsapp/               Abschnitt 7
```

Änderung bei `lib/data/matrix/`: keine.

### 5.2 Nachrichtenzuordnung

| WhatsApp | FamilyNexus |
|---|---|
| `conversation`, `extendedTextMessage` | Text, Antwort über `ContextInfo` |
| `imageMessage`, `documentMessage` | Anhang, Regeln E-19/E-28 |
| `audioMessage`, `videoMessage` | Anhang über `WaAttachmentPolicy`, Wiedergabe in 8.4 |
| `stickerMessage` | Bild-Anhang, nur auf Tipp |
| `reactionMessage` | Reaktion |
| `protocolMessage`: Widerruf | Inhalt lokal löschen, Hinweis „Nachricht gelöscht“ |
| `protocolMessage`: Bearbeiten (`IsEdit`) | Text ersetzen, Vermerk |
| `IsEphemeral`, Fristen | `expires_at`, Löschlauf (W8) |
| `IsViewOnce` | Kein Inhalt speichern, „Im Telefon öffnen“ |
| Standort, Kontakt, Umfrage, Sonstiges | Platzhalter „Im Telefon ansehen“ |
| `UndecryptableMessage` | Platzhalter wie `undecryptable`, automatisches Nachfordern |

**Wichtig:** `ChatMessage.sharedEventId` bleibt für WhatsApp immer leer; `RsvpButtons` können nie erscheinen (B3 aus `docs/KONTAKTE.md`).

### 5.3 Datenbank `familynexus_wa.db`

```sql
wa_peers(jid PK, phone, lid, full_name, push_name, about, saved, blocked, identity_changed_ms)
wa_threads(id PK, jid, kind, title, muted, last_ts, unread, ephemeral_s)
wa_messages(id PK, thread_id, sender_jid, ts, body, reply_to, kind, status, edited, revoked, expires_at)
wa_media(message_id PK, name, mime, size, sha256, direct_path, media_key, cached_blob)
wa_reactions(message_id, sender_jid, emoji, PRIMARY KEY(message_id, sender_jid))
wa_status(id PK, sender_jid, ts, kind, body, media_ref, expires_at)
wa_kv(key PK, value)  -- Schalter, letzter Telefon-Kontakt, Stand des Verlaufs
```

Geöffnet mit `EncryptedDb.open`, eigene Datei, eigene Versionierung. Die App-Datenbank bleibt unverändert, Store-Ausgaben schemagleich.

### 5.4 Rufnummer und LID

WhatsApp führt Personen zunehmend über `@lid` statt `@s.whatsapp.net`. Die Bibliothek hat dafür `LIDStore` und `GetPNForLID`. Regeln:
- Kennung ist die LID, sobald bekannt; sonst die Rufnummern-JID. `wa_peers` führt beides.
- Wird eine Zuordnung bekannt, werden Gespräche zusammengeführt, in einer Transaktion und idempotent.
- `GetMessageForRetry` muss beide Formen prüfen (Hinweis im Quellcode).
- JIDs erscheinen nie in `AppLog`, der Filter wird erweitert.

## 6. Status im Detail

### 6.1 Online-Status

Aus `presence.go`:
- `SendPresence(Available)` schaltet zugleich aktive Empfangsbestätigungen und eine Sitzungsmeldung ein.
- `SubscribePresence` braucht nach Angabe der Bibliothek eigene Online-Meldung und nutzt, falls vorhanden, ein Datenschutz-Token.

```
Verbinden → sobald PushName bekannt: SendPresence(unavailable)
Chat öffnen, Schalter an → SendPresence(available) → SubscribePresence(jid)
Chat verlassen, App im Hintergrund → SendPresence(unavailable)
```

- Standard **aus**. Hinweis: „Solange du den Status siehst, erscheinst du selbst als online.“
- Ohne Token kein Abruf, Anzeige „Status unbekannt“ (W9).
- `events.Presence` nur im Arbeitsspeicher, nie in `wa_*`.
- Solange die App `unavailable` meldet, sendet whatsmeow Empfangsbestätigungen als `inactive`. Der Absender sieht dann womöglich
  keine zwei grauen Haken. Das ist gewollt.

**Unbelegt:** Ob das Telefon bei `available` Benachrichtigungen zurückhält. Falls ja, ist ein Warnhinweis Pflicht.

### 6.2 Status-Meldungen

- Ankunft als `events.Message` mit `Info.Chat == types.StatusBroadcastJID`.
- Beim Eingang filtern: nur `saved`-Kontakte werden gespeichert, alles andere wird verworfen.
- Kein `MarkRead`. Löschung nach 24 Stunden per `expires_at`. Medien nur auf Tipp.
- Eigene Meldungen sind nicht vorgesehen (`SetStatusMessage` bleibt ungenutzt).

### 6.3 Info-Text und Profilbild

`GetUserInfo` beim Öffnen des Profils, `events.UserAbout` für Änderungen, beides nur für aufgenommene Kontakte. Profilbilder über
`GetProfilePictureInfo` nur auf Tipp; die Liste zeigt Initialen.

## 7. Oberfläche

| Ort | Inhalt |
|---|---|
| Kontakte → WhatsApp verbinden | Warnseite, QR, Fortschritt, Verlaufsfrage |
| Kontakte → WhatsApp | Aufgenommene Kontakte, „Alle“, Suche lokal, Hinzufügen |
| Chat → Kontakte → WhatsApp | **Eigene Gesprächsliste** |
| Gespräch | `ChatScreen` über `ChatHub`, Kopfzeile aus 11.3 |
| Status | Liste nach Kontakten |
| Einstellungen → WhatsApp | Verbindung, Lesebestätigungen, Online-Status, Verlauf, Trennen und Löschen, letzter Telefon-Kontakt |

- `_ThreadBar` (Chips) trägt keine hunderte Gespräche. WhatsApp bekommt eine Liste mit Paginierung und Lazy Loading.
- `features/whatsapp` nutzt eigene ARB-Dateien mit eigenem `gen-l10n`-Lauf. Texte sind deutsch und englisch vollständig.
- QR über die vorhandene Anzeige (`qr`), mit rotierenden Codes aus `GetQRChannel` und klarem Zustand bei Zeitablauf.
- `FLAG_SECURE` schützt den QR-Code unter Android. Unter Linux gilt SA-6.

## 8. Abläufe

### 8.1 Koppeln

1. Warnseite: Pflichtbestätigung einzeln für Kontorisiko, Bedingungen, Metadaten (W1).
2. `fn_wa_open`, `Connect`, QR anzeigen. **Hinweis bei Android-Telefon: „Scanne mit dem Telefon, auf dem WhatsApp läuft. Das muss ein anderes
   Gerät sein.“**
3. Bei `PairPasskeyRequest`: Abbruch mit Erklärung. Eine Passkey-Antwort ist in der ersten Stufe nicht vorgesehen. Prüfen in C0, wie viele
   Konten das betrifft.
4. `PairSuccess`, warten auf `Connected`, App-Zustand laden, `OfflineSyncCompleted`.
5. Frage nach dem Verlauf (8.3). Danach `SendPresence(unavailable)`.

WhatsApp erlaubt vier gekoppelte Geräte. Jede FamilyNexus-Installation belegt einen Platz. Bei voller Liste meldet das Telefon das selbst.

### 8.2 Senden und Empfangen

```
Senden:  ChatHub → wa_messages(sending) → fn_wa_call(send) → whatsmeow.SendMessage → Ereignis → Status
Empfang: events.Message → mapping → Dart speichert → fn_wa_ack → ack an WhatsApp (SynchronousAck)
```

Antwortet Dart nicht binnen Frist, bleibt die Nachricht unbestätigt und kommt wieder. Doppelte IDs sind idempotent.

Lesebestätigung: `MarkRead` nur bei aktivem Schalter. Standard aus.

### 8.3 Verlauf

`events.HistorySync` wird nicht automatisch geladen. Mit Zustimmung `DownloadHistorySync`, Filter auf 90 Tage, Fortschritt, Abbruch. Ohne
Zustimmung wird der Hinweis verworfen. `SendMediaRetryReceipt` dient nur für alte Medien auf Tipp.

### 8.4 Medien

Herunterladen nur auf Tipp (`Download`). Hash wird von der Bibliothek geprüft. Ablage als Blob in `wa_media`, bis 25 MB, mit Kontingent
(Vorschlag 2 GB, älteste zuerst). `WaAttachmentPolicy` ergänzt die Allowlist nur für WhatsApp um `audio/ogg`, `audio/mp4`, `video/mp4`.
Eine Wiedergabe braucht eine Medienbibliothek, die nach `docs/ABHAENGIGKEITEN.md` zu prüfen ist. Erste Stufe: Hinweis auf „Anhang speichern“
(SA-3). Aufnahme ist nicht vorgesehen.

### 8.5 Gruppen

`GetJoinedGroups`, `GetGroupInfo`, `events.GroupInfo`. Lesen und Schreiben, keine Verwaltung. Rufnummern anderer Mitglieder werden
nur wie in WhatsApp selbst angezeigt. Kein `CreateGroup`, kein Beitritt per Link (W6).

### 8.6 Lebenszyklus

| Zustand | Verhalten |
|---|---|
| App im Vordergrund und entsperrt | Verbunden |
| Hintergrund (Mobil) | Nach 30 s `Disconnect`, kein Dienst (E-16) |
| Desktop, Fenster offen | Verbunden |
| App-Sperre aktiv | Oberfläche gesperrt; Verbindung folgt dem Hintergrund-Zustand |
| Beenden | `Disconnect`, `fn_wa_close` |

Wiederverbinden holt Verpasstes (`OfflineSyncPreview`). Wie weit das zurückreicht, klärt C0. Das Telefon bleibt Quelle der Wahrheit.

Anrufe: Die Bibliothek setzt sie nicht um. C0 prüft, dass eingehende Anrufe nicht abgewiesen werden; das Telefon muss weiter klingeln.

## 9. Kontakte, Blockieren, Löschen

### 9.1 Kontakte

Quelle: `Store.Contacts.GetAllContacts` nach App-Zustand-Abgleich. `saved` entscheidet über die Sichtbarkeit in der Kontaktliste. Hinzufügen
per Nummer: `IsOnWhatsApp` mit genau **einer** Nummer nach Tipp, keine Liste (W6).

### 9.2 Blockieren

Lokal wie E-48 in `wa_peers.blocked`. Zusätzlich auf Wunsch `UpdateBlocklist`. `events.Blocklist` übernimmt Änderungen vom Telefon.

### 9.3 Trennen und Löschen

```
Logout versuchen → bei Fehlschlag trotzdem weiter und Hinweis „Am Telefon entfernen“
Kern schließen → beide Dateien löschen → db.whatsapp löschen → Oberfläche zurücksetzen
```

**Falle:** `AppServices.wipeAccountDataIn` endet früh, wenn `calendarOwner` fehlt. Die WhatsApp-Löschung darf nicht dahinter hängen. Sie
läuft als eigener Schritt in `logout`, im vollständigen Zurücksetzen (`onFullReset`, `bootstrap.dart`) und vor `deleteAccount`.

## 10. Ereignisse und Fehler

| Ereignis | Verhalten | Wiederholung |
|---|---|---|
| `Connected`, `KeepAliveRestored` | Anzeige verbunden | – |
| `KeepAliveTimeout`, `Disconnected` | Hinweis, automatisches Wiederverbinden | Ja, durch Bibliothek |
| `TemporaryBan` (Grund, Ablauf) | **Stopp**, Text je Grund, Zeitpunkt nennen | **Nein** |
| `ConnectFailureTempBanned` (402) | wie oben | Nein |
| `ConnectFailureUnknownLogout` (406) | **Stopp**, „Möglicherweise gesperrt, in WhatsApp prüfen“ | Nein |
| `ConnectFailureMainDeviceGone` (403) | Stopp, Hauptgerät prüfen | Nein |
| `LoggedOut` | Getrennt, Neukopplung möglich, Chats bleiben | Nein |
| `ClientOutdated` (405), `BadUserAgent` (409) | Stopp, Hinweis auf App-Update | Nein (W5) |
| `StreamReplaced` | Stopp, „An anderer Stelle übernommen“ | Nein |
| `NotifyAccountReachoutTimelock` | Warnung, Senden aus | Nein |
| `IdentityChange` | Dauerhafte Warnung im Gespräch | – |
| Warnung „Account may be at risk“ am Telefon | Die App sieht sie womöglich nicht; Text auf der Warnseite erklärt: sofort trennen | – |
| Anderer `ConnectFailure`, `StreamError` | Zeitlich begrenzter Rückoff, dann Stopp | Begrenzt |
| Kern lädt nicht, falsche `v` | Bereich aus | Nein |

Die Texte nennen die Tempban-Gründe sachlich (`SentToTooManyPeople`, `BlockedByUsers` usw.). Sie geben **keine Hinweise**, wie sich eine Sperre
vermeiden oder umgehen lässt.

**Automatischer Schutz:** Nach einem Stopp sendet die App nichts mehr, bis die Person ausdrücklich neu verbindet. Bei zweiter Sperre in 30 Tagen
Vorschlag zum Trennen.

## 11. Verschlüsselung

### 11.1 Vertrauensmodell

| Ebene | Umsetzung | Quelle |
|---|---|---|
| Inhalte | Signal-Protokoll (`go.mau.fi/libsignal`) | Nicht von Signal oder WhatsApp |
| Gruppen | Sender Keys | wie oben |
| Transport | Noise über WebSocket | whatsmeow |
| Kopplung | ADV-Signatur des Hauptgeräts | whatsmeow |
| App-Zustand | Eigene Schlüssel des Kontos | whatsmeow |

Ein unabhängiges Audit von `go.mau.fi/libsignal` ist mir nicht bekannt. C0 sucht danach. Ohne Audit darf die App „verschlüsselt“ sagen, aber nicht
mehr behaupten.

### 11.2 Sicherheitscode

Anzeige nur, wenn C0 belegt, dass der berechnete Code dem der offiziellen App entspricht. Sonst fehlt die Funktion und die App sagt das.

### 11.3 Pflichttexte

Wie Hauptkonzept 8.3. Kopfzeile: „WhatsApp · inoffizielle Verbindung. Verschlüsselt, aber Meta sieht, wer wann schreibt.“ Kein Familien-Schloss.

## 12. Familie und Isolation

Alle Tabellen in `docs/WHATSAPP_KONTAKTE.md` Abschnitt 10 gelten. Technisch belegt durch:
- Architekturtest: `lib/data/matrix`, `lib/data/sync`, `lib/domain/calendar*`, `shopping`, `tasks` importieren nichts aus `data/whatsapp`.
- `ChatHub` ist die einzige Verbindungsstelle, und nur für Chatmethoden.
- `member_policy` mit `whatsapp: blocked`: Bereich zu, Verbindung getrennt.
- Mindestalter: Hinweis auf 18 Jahre für diese Ausgabe, passend zu E-47.

## 13. Ausgaben und Paketierung

### 13.1 Ausgaben

**Standard-Assets bleiben unverändert.** WhatsApp kommt nur in **zusätzliche** Assets, damit niemand sie versehentlich bekommt.

| Asset | Plattform | WhatsApp |
|---|---|---|
| Alle bisherigen Dateien und Store-Ausgaben | alle | ✘ |
| `FamilyNexus-v<V>-wa.apk` | Android | ✔ |
| `FamilyNexus-v<V>-wa-x86_64.AppImage`, `…-wa.flatpak` | Linux | ✔ |
| `FamilyNexus-v<V>-wa-windows.zip` | Windows | ✔ |
| `FamilyNexus-v<V>-wa.dmg` | macOS | ✔ |

iOS und Web gibt es nicht.

### 13.2 Trennung im Code

- `--dart-define=FN_WHATSAPP=true`; `const bool.fromEnvironment` macht den Zweig für Tree-Shaking entfernbar.
- Bedingter Import `if (dart.library.ffi)` hält `dart:ffi` aus dem Web-Build.
- Keine Dart-Abhängigkeit in `pubspec.yaml`: Die Bibliothek wird per `DynamicLibrary.open` geladen und nur in `-wa`-Paketen beigelegt. Eine
  Native-Asset-Hook würde in jedem Build laufen.
- Android: Flavors `standard` und `wa`, `src/wa/jniLibs`. Pfade in `tool/build_release.sh`, `tool/check_apk_abis.sh` und Workflow anpassen.
- `tool/check_no_whatsapp.sh` prüft jedes Nicht-`wa`-Artefakt auf `whatsmeow`, `libfn_whatsapp`, Texte. Pflicht im Workflow.

### 13.3 Build je Plattform

| Plattform | Befehl (Kern) | Besonderheit |
|---|---|---|
| Android | `GOOS=android GOARCH=arm64,arm,amd64 CGO_ENABLED=1 go build -buildmode=c-shared` mit NDK-Clang | `CGO_LDFLAGS=-Wl,-z,max-page-size=16384` für 16-KB-Seiten; SQLCipher je ABI |
| Linux | `go build -buildmode=c-shared` | Flatpak-Modul, AppImage auf Ubuntu 22.04 (glibc) |
| Windows | cgo mit MinGW | **Schwierigster Fall:** SQLCipher kommt per vcpkg für MSVC; Bindung in C0 prüfen |
| macOS | arm64 und amd64, `lipo` | Signieren wie E-62, Einbindung in Frameworks |

Reihenfolge: Linux, Android, macOS, Windows.

`.github/workflows/release.yml`: `actions/setup-go` mit fester Version, eigene `-wa`-Jobs. `tool/check_apk_abis.sh` prüft `libfn_whatsapp.so` nur im
`wa`-APK. `tool/sbom.py` nimmt `go.sum` auf.

### 13.4 Aktualisierung

Es gibt keine automatische Aktualisierung. Regelbetrieb:
- Wöchentlich whatsmeow-Änderungen sichten, Diff prüfen, Commit anheben.
- `ClientOutdated` führt zur Download-Seite. Der Link geht nur auf die eigene Release-Seite.
- `SetWAVersion` wird **nicht** als Notlösung genutzt, auch die Bibliothek rät dazu, sie stattdessen zu aktualisieren.

## 14. Sicherheit

| Risiko | Gegenmaßnahme | Restrisiko |
|---|---|---|
| Kontosperre, Warnung (R1) | Warnseite, W5, W6, Stopp ohne Neuversuch | **Bleibt** |
| Wirkung nach dem Trennen | Text: auch frühere Kopplungen können Warnungen auslösen (ein Bericht in #810) | Bleibt |
| Lieferkette | Fester Commit, `go.sum`, Diff-Prüfung, `govulncheck` im Workflow, SBOM | Zeitdruck bei Protokolländerung |
| Go im selben Prozess | Kleine C-Schnittstelle, Go speichersicher außer cgo, keine Eigenentwicklung von Parsern | SA-12 |
| Inhalte von Fremden | `wa_mapper`, Allowlist, kein automatisches Laden, keine Linkvorschau, Text ohne Links | Bilddecoder nach Tipp |
| Klartext auf Datenträger | Nur SQLCipher, keine Temp-Dateien; `Anhang speichern` wie SA-3 | SA-6, SA-10 |
| Arbeitsspeicher | Nachrichten begrenzt geladen, Go hält keine Verläufe | Speicherabbild bei entsperrter App |
| Netzwege | TLS, eigener Media-Client, Proxy aus der Umgebung ignoriert, Prüfung der Android-CA-Pfade und DNS unter cgo in C0 | – |
| Logs | Kein Logger, Codes statt Texte, `AppLog`-Filter | – |
| FFI-Fehler | Fuzzing der DTO-Dekodierung, Zeigerregeln, `recover` an der Grenze, Absturz löst keinen Datenverlust aus | Absturz der App |
| Fremder Zugriff auf das entsperrte Gerät | App-Sperre (SA-10), Bildschirmschutz | Gerät mit Zugriff kann lesen |

**SA-12** wie Hauptkonzept, ergänzt um R3.

## 15. Lizenzen

| Teil | Lizenz | Folge |
|---|---|---|
| App, `matrix`, `flutter_vodozemac` | AGPL-3.0 | Gesamtwerk bleibt offen |
| `native/fn_whatsapp` | AGPL-3.0 | Vorschlag |
| `whatsmeow` | MPL-2.0 | Quellen je Datei, vereinbar |
| `go.mau.fi/libsignal` | In C0 zu prüfen (licenses.dev nennt für einen älteren Stand GPL-3.0-Einträge) | GPLv3 und AGPLv3 sind kombinierbar; prüfen |
| `go.mau.fi/util`, `coder/websocket`, `argo-go` u. a. | C0 | SBOM |
| SQLCipher | Bestehend | – |

Keine NDA-Frage wie bei Weg A, aber die Markenfrage aus G0 bleibt. Das Repo enthält den Code öffentlich, auch für Store-Prüfer sichtbar. G0 entscheidet, ob `native/fn_whatsapp` und `features/whatsapp` in ein eigenes Repo wandern.

## 16. Tests

| Ebene | Inhalt | Netz |
|---|---|---|
| Go | `waclient`-Attrappe, `mapping` mit Beispieldaten, `policy`, `go test -race`, `govulncheck` | Nein |
| FFI | Lebenszyklus, Binärkanal, Bestätigung, ungültiges JSON, Fuzzing | Nein |
| Dart | `FakeWhatsAppGateway`, `SqlWhatsAppStore`, LID-Zusammenführung, Fristen, Löschpfade inkl. `calendarOwner == null` | Nein |
| Widget | Warnseite, Zustände aus Abschnitt 10, Hinweis zweites Gerät, Status, Schalter | Nein |
| Isolation | Architekturtest, keine WhatsApp-Daten in Matrix-Sendewegen | Nein |
| Artefakte | `check_no_whatsapp.sh`, ABI, 16-KB-Prüfung | Nein |
| Pen-Test | Fehlformate über FFI, Medien, Logs, Datei ohne Schlüssel | Nein |
| Manuell | Testplan mit offizieller App auf Gegenseite | **Ja** |

**Regel für manuelle Tests:** Erst nach G0, nur mit eigener Testnummer und Zustimmung des Inhabers, nie mit einer Hauptnummer. Automatische Läufe
gegen echte WhatsApp-Server gibt es nicht. CI und lokale Agenten führen solche Tests nicht aus.

## 17. Phasen

Voraussetzung: G0 positiv, V1.4 K1–K3, `ChatBackend` und `ChatHub`.

| Phase | Inhalt | Umfang | Abbruch, wenn |
|---|---|---|---|
| **C0 Vorprüfung** | Testkonto: Offene Punkte aus 18, SQLCipher auf Android und Linux, Anzeigename, Sicherheitscode, Audit-Suche, Lizenzen | M | Ablage nicht verschlüsselbar, Lizenz unvereinbar, R1 im Test sofort sichtbar |
| **C1 Trennung** | `ChatBackend`, `ChatHub`, Stub, Flavors, `-wa`-Jobs, Prüfskript | M | – |
| **C2 Kern** | Go-Kern, FFI, Ablage, QR-Kopplung, Warnseite, Trennen, Abschnitt 10 | L | – |
| **C3 Chat** | Einzelchats, Anhänge, Reaktionen, Verschwindende, LID, Gesprächsliste | L | – |
| **C4 Kontakte, Gruppen** | Kontakte, Verlauf, Gruppen, Blockieren | M | – |
| **C5 Status** | Status-Meldungen, Info-Text, Online-Status | M | – |
| **C6 Abschluss** | Windows, Doku, Datenschutz, Export, Pen-Test, Review, Assets | M | Pen-Test offen |

Dauerhaft: wöchentliche Pflege plus Notfall-Releases (13.4).

### Abnahmekriterien
1. Standard-Assets und Store-Ausgaben enthalten nachweislich nichts von WhatsApp; ihr Verhalten ist unverändert.
2. In `-wa`-Paketen bleibt der Bereich bis zur Pflichtbestätigung aus.
3. Kopplung nur per QR; am Telefon erscheint FamilyNexus erkennbar, sofern C0 das belegt.
4. Text und Anhänge laufen in beide Richtungen mit der offiziellen App, ohne Server des Herausgebers.
5. `familynexus_wa_keys.db` und `familynexus_wa.db` sind ohne Schlüssel nicht lesbar.
6. Kein Nachrichtenverlust bei Absturz zwischen Empfang und Speicherung (`SynchronousAck`).
7. Verschwindende Nachrichten, Widerrufe und Einmal-Ansichten werden eingehalten.
8. Online-Status nur mit Schalter, nur im offenen Chat, nie gespeichert; „unbekannt“ heißt nie „Offline“.
9. Status-Meldungen nur von aufgenommenen Kontakten, gelöscht nach 24 Stunden, keine Gelesen-Meldung (am Testkonto belegt).
10. Jede Stopp-Bedingung aus Abschnitt 10 beendet das Senden ohne Neuversuch; Familie und Kontakte laufen weiter.
11. Trennen und alle Löschwege entfernen Dateien und Schlüssel, auch offline und ohne `calendarOwner`.
12. Keine WhatsApp-Daten in Matrix (Test), keine Rufnummern oder JIDs im Log.

## 18. Offene Punkte für C0

| Punkt | Warum wichtig | Stand |
|---|---|---|
| Telefon-Benachrichtigungen bei `available` | Hinweis oder Verbot | Unbelegt |
| Reichweite des Nachholens nach Offline-Zeit | Nachrichtenlücken | Unbelegt |
| Anzeige von `SetOSInfo` am Telefon | W5, Abnahme 3 | Unbelegt |
| Anteil Konten mit Passkey-Zwang | Kopplung scheitert | Bekannt, dass es vorkommt |
| Eingehende Anrufe | Dürfen nicht abgewiesen werden | Unbelegt |
| Gelesen-Verhalten bei Status | Abnahme 9 | Quellcode spricht dafür |
| Sicherheitscode | 11.2 | Unbelegt |
| Audit von `libsignal` | Aussage zur E2EE | Unbekannt |
| Android: CA-Pfade, DNS unter cgo | Verbindung | Unbelegt |
| Windows: Go mit MinGW und SQLCipher | Ausgabe Windows | Unbelegt |
| Sperrhäufigkeit | R1 | **Nicht messbar**, nur Berichte. Ein Test mit einer Nummer beweist nichts |

## 19. Entscheidungen zur Abstimmung

| Frage | Vorschlag | Betrifft |
|---|---|---|
| Lohnt der Einsatz für Desktop und Zweitgerät? | **Vom Herausgeber zu entscheiden, sonst Verzicht** | 1 |
| Android auf dem Hauptgerät | **Nicht unterstützen.** Code-Kopplung würde `Browser (OS)` vortäuschen (W5) | 2, R2 |
| W5 trotz Web-Selbstauskunft der Bibliothek tragbar? | **G0 prüfen** | R3 |
| Eigene `-wa`-Assets | **Ja**, Standard bleibt frei davon | 13.1 |
| Repo | **G0**, Vorschlag: getrennt, falls Store-Prüfung leidet | 15 |
| Verlauf | **Aus**, höchstens 90 Tage | 8.3 |
| Lesebestätigungen, Online-Status | **Beide aus** | 6.1, 8.2 |
| Passkey-Kopplung | **Später** | 8.1 |
| Gruppen | **Ja, vorhandene**, zuerst verschiebbar | 8.5 |
| Pflege gesichert? | **Vom Herausgeber zu bestätigen**, sonst kein Start | 13.4 |

## 20. Quellen

Abgerufen am 2026-10-31.

- whatsmeow, API und Lizenz: https://pkg.go.dev/go.mau.fi/whatsmeow
- `go.mod`: https://raw.githubusercontent.com/tulir/whatsmeow/main/go.mod
- Clientangaben: https://raw.githubusercontent.com/tulir/whatsmeow/main/store/clientpayload.go
- Kopplung: https://raw.githubusercontent.com/tulir/whatsmeow/main/pair-code.go
- Presence: https://raw.githubusercontent.com/tulir/whatsmeow/main/presence.go
- Empfangsbestätigungen: https://raw.githubusercontent.com/tulir/whatsmeow/main/receipt.go
- Client: https://raw.githubusercontent.com/tulir/whatsmeow/main/client.go
- Stores: https://raw.githubusercontent.com/tulir/whatsmeow/main/store/store.go
- sqlstore: https://raw.githubusercontent.com/tulir/whatsmeow/main/store/sqlstore/container.go
- Ereignisse: https://raw.githubusercontent.com/tulir/whatsmeow/main/types/events/events.go
- Broadcast: https://raw.githubusercontent.com/tulir/whatsmeow/main/broadcast.go
- Issue #810 (Warnungen): https://github.com/tulir/whatsmeow/issues/810
- Issue #989 (Sperren): https://github.com/tulir/whatsmeow/issues/989
- mautrix, Anmeldung und Zwei-Wochen-Regel: https://docs.mau.fi/bridges/go/whatsapp/authentication.html
- go-sqlcipher: https://pkg.go.dev/github.com/mutecomm/go-sqlcipher, Fork: https://github.com/wisscore/go-sqlcipher
- Android, 16-KB-Seiten: https://source.android.com/docs/core/architecture/16kb-page-size/16kb
- Go für Android mit 16 KB: https://danballard.com/2025/09/28/generating-android-16kb-page-size-libraries-from-go/
- WhatsApp-Bedingungen EWR: https://www.whatsapp.com/legal/terms-of-service-eea
- Grenze von vier Geräten (Bericht): https://www.techadvisor.com/article/1797903/whatsapp-on-multiple-phones.html
