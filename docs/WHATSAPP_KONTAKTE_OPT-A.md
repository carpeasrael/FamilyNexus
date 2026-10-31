# WhatsApp über die offizielle Schnittstelle (Weg A, Detailkonzept)

Stand: 2026-10-31 · Status: **Zurückgestellt, wird nicht implementiert** (Entscheidung: `docs/WHATSAPP_KONTAKTE.md` Abschnitt 1.1) ·
Basis: Version 1.2.1 (22), `docs/KONTAKTE.md`, `docs/WHATSAPP_KONTAKTE.md` · E-77 und SA-13 gelten nur bei einer Neubewertung

Dieses Dokument detailliert Weg A aus `docs/WHATSAPP_KONTAKTE.md`: FamilyNexus wird **Interoperabilitäts-Partner von WhatsApp**
nach Art. 7 Digital Markets Act (DMA). Der Weg ist von Meta vertraglich erlaubt.

**Einordnung:** Gewählt ist Weg C, und nur nach positiver rechtlicher Freigabe. Weg A ist **keine automatische Rückfallebene.** Dieses
Dokument bleibt als Grundlage für eine Neubewertung erhalten und beschreibt, wie eine Umsetzung aussähe. Phasen, Vorschläge und
Repository-Änderungen werden nicht ausgeführt, solange keine Neubewertung beschlossen ist.

## 1. Ergebnis vorab

**Weg A ist kein Anschluss des eigenen WhatsApp-Kontos, sondern ein eigener Messenger-Dienst, der mit WhatsApp sprechen darf.**
Der Herausgeber wird dadurch Betreiber eines Dienstes, und zwei der vier Anforderungen bleiben unerfüllt oder eingeschränkt.

| Anforderung | Weg A | Anmerkung |
|---|---|---|
| A1 Mit WhatsApp-Kontakten chatten | **teilweise** | Nur Personen mit eingeschalteten Drittanbieter-Chats im EWR. Neuer Chat, kein Verlauf, keine Teilnahme am eigenen WhatsApp-Konto |
| A2 In eigene Kontakte aufnehmen | **ja, von Hand** | Lokale Liste nach Rufnummer. Kein Import aus WhatsApp |
| A3 Status sehen | **nein** | Weder Online-Status noch Status-Meldungen noch Info-Text. Laut BEREC (Stand 12/2024) nicht einmal Anzeigenamen |
| A4 Ende-zu-Ende-Verschlüsselung | **ja** | Signal-Protokoll im Client. Meta und der Herausgeber sehen keine Inhalte, aber beide sehen Metadaten |

**Harte Hindernisse**, jedes kann das Vorhaben allein beenden:

| # | Hindernis | Warum kritisch |
|---|---|---|
| H1 | **NDA gegen AGPL** | Technische Details gibt es nur unter NDA. Die App steht unter AGPL (E-02) und muss ihren Quellcode offenlegen. Darf der Protokollcode nicht veröffentlicht werden, ist die Einbindung in die App lizenzrechtlich nicht möglich (Abschnitt 15). |
| H2 | **Nur Android und iOS** | Das Referenzangebot definierte `Client` als native Android- oder iOS-App (Stand 12/2024). Linux, Windows, macOS und Web wären ausgeschlossen. |
| H3 | **Herausgeber wird Anbieter** | Vertrag mit Meta, weitreichende Prüfrechte, Vorfallmeldungen, eigener Serverbetrieb, Rolle als Verantwortlicher. Das beendet „Der Herausgeber betreibt keinen Server und erhält keine Daten“ (`docs/STORE.md`). |
| H4 | **Aufenthaltsprüfung im EWR** | Der Anbieter muss prüfen, dass seine Nutzer im EWR sind. Das verlangt IP-Auswertung und steht gegen die Datensparsamkeit der App. |

**Entscheidung:** Weg A wird nicht implementiert. Er erfüllt den Auftrag nicht (A1, A3) und macht den Herausgeber zum Betreiber.

**Neubewertung nur, wenn** der Status (A3) aufgegeben wird **und** die Betreiberrolle gewollt ist. Dann beginnt sie mit **Phase P0**
(Abschnitt 18): ohne Entwicklung klären, ob H1 bis H4 lösbar sind, und erst dann entscheiden. Scheitert H1, ist Weg A in dieser App
beendet. Für einen einzelnen Herausgeber halte ich den Aufwand nur für vertretbar, wenn FamilyNexus ohnehin ein betriebener Dienst
werden soll.

## 2. Quellenlage und Grenzen dieses Dokuments

Das **Entwicklerportal von Meta** und damit das Referenzangebot in seiner aktuellen Fassung konnte ich nicht abrufen. Die
Detaildokumentation liegt ohnehin hinter einem NDA. Grundlage sind deshalb:

| Stufe | Quelle | Stand |
|---|---|---|
| Hoch | BEREC-Stellungnahmen mit Zitaten aus dem Referenzangebot | 02/2024, 03/2025 (Angebotsstand 12/2024) |
| Hoch | EU-Kommission (Tabelle der Fristen, Bericht COM(2026) 247) | 2026 |
| Hoch | WhatsApp-Hinweis für Nutzer anderer Dienste, Meta Engineering | 2024–2026 |
| Mittel | Berichte zu BirdyChat und Haiket | 2025–2026 |

Meta hat Referenzangebot und Dokumentation am **06.09.2025** für Gruppenchats aktualisiert (COM(2026) 247). **Alles, was aus dem
Stand 12/2024 stammt, kann überholt sein.** Namen und Formate auf Meta-Seite sind in diesem Dokument Platzhalter. Die Schnittstellen
zwischen App und Dienst sind mein Entwurf. Rechtliche Aussagen sind keine Rechtsberatung.

## 3. Was Weg A fachlich bedeutet

```
  Anna (FamilyNexus)                                     Ben (WhatsApp)
  Kennung: Nutzername beim Partner                       Kennung: Rufnummer
        │  Signal-Protokoll, Ende-zu-Ende                      │
        └──────────▶  WhatsApp-Server  ◀───────────────────────┘
```

- **Anna braucht kein WhatsApp-Konto.** Sie erscheint bei WhatsApp als Nutzerin des Dienstes „FamilyNexus“. Hat sie selbst WhatsApp,
  bleibt das davon getrennt: Vorhandene Chats, Gruppen, Kontakte und der Verlauf kommen nicht mit.
- **Ben muss zustimmen.** Laut den von Meta veröffentlichten Oberflächen-Entwürfen fragt WhatsApp beim ersten Angebot, bei jedem
  neuen Partnerdienst und bei einer Kontaktaufnahme durch Nicht-Eingeschaltete nach. Laut Meta geht das nur unter Android und iOS.
- **Ben sieht wenig.** BEREC beschreibt (Stand 12/2024), dass Partnernutzer nur mit ihrer Kennung erscheinen, ohne Name und Bild.
  Eine Anfrage zeigt keine Vorschau. Viele werden sie deshalb ablehnen. Das Produkt muss das auffangen (Abschnitt 9.2).
- **Beide müssen im EWR sein.** Laut Annex 1 Punkt 7.5.1 müssen Partnernutzer im EWR sein und bleiben. WhatsApp-Nutzer außerhalb sind
  nicht erreichbar.

Der Weg dient also dazu, **eine Person zu erreichen, ohne selbst WhatsApp zu nutzen**. Das ist etwas anderes als „mit meinen
WhatsApp-Kontakten weiterchatten“.

## 4. Pflichten aus DMA und Referenzangebot

| Thema | Regel | Quelle (Stand) | Folge für FamilyNexus |
|---|---|---|---|
| Kosten | Interoperabilität ist unentgeltlich | Art. 7(1) DMA | Keine Gebühr an Meta, aber eigene Betriebs- und Prüfkosten |
| Antragsberechtigt | Anbieter nummernunabhängiger Dienste, die in der EU anbieten oder das planen | Art. 7(5) | Der Herausgeber muss Anbieter sein oder werden |
| Frist | Vernünftige Anfragen binnen 3 Monaten; Veröffentlichung kann länger dauern | Art. 7(5), Berichte | Uhr startet mit dem Antrag, also erst stellen, wenn man liefern kann |
| Vertrag | Unterschrift vor Aktivierung, Bewerbung über Formular | Meta | Rechtsträger nötig |
| Detaildoku | Nur unter NDA | BEREC 2025 | **H1** |
| Client | „Android or iOS device running a native app“ | Annex 1, 1.3 (12/2024) | **H2** |
| Nutzer-Opt-in | Einschreiben nur nach freiwilliger Zustimmung | Annex 1, 7.4.2 | Pflichtdialog, nachweisbar |
| Aufenthalt | Im EWR; Anwesenheit in jedem 60-Tage-Zeitraum; Verdacht führt zu Sperre | Annex 1, 7.5.1 | **H4** |
| Kryptografie | Signal-Protokoll, eigene Lizenz, Unterlizenz von Meta oder gleichwertiges Verfahren mit Bestätigung | BEREC 2025 | Quelloffenes libsignal |
| Tests | Testphase mit Partner; Meta darf verlängern und Status beschränken | Annex 1, Kap. 5 | Bestandener Test ist Voraussetzung |
| Änderungen | Doku jederzeit änderbar, **3 Monate** zur Übernahme, sonst Sperre | Annex 2, 2 | Dauerhafte Release-Pflicht |
| Sperre | Auch aus „operational reasons“; BEREC nennt das zu weit | Punkt 5 | Betriebsrisiko, Oberfläche muss es abfangen |
| Prüfrechte | Inspektion von Unterlagen, Anlagen, Daten und Systemen; Kosten bei Verstoß lagen im Entwurf beim Partner | Abschnitt 18, BEREC 2024/2025 | **H3**, siehe auch H1 |
| Datenschutz | Beide unabhängige Verantwortliche; Standardvertragsklauseln | Annex 5, 2.1 | Eigene Verantwortung, Abschnitt 13 |
| Sicherheit | Sicherheitsprogramm mit Verschlüsselung bei Ablage und Transport | Kap. 10, Annexe 3–5 | Nachweisbares Programm |
| Vorfälle | Meldepflicht des Partners an Meta, nicht umgekehrt | BEREC 2025 | Bereitschaft nötig |
| Dienstgüte | Meta: „commercially reasonable endeavours“ | Appendix A | Keine feste Zusage |
| Alter | WhatsApp: keine Altersgrenze im Angebot | BEREC 2025 | Eigene Regel, Abschnitt 12 |

## 5. Rechtsträger und Rolle

Heute verteilt der Herausgeber Software. Mit Weg A betreibt er einen Dienst für die Öffentlichkeit. In P0 sind zu klären:

- Rechtsform und Haftung. Ein Vertrag dieser Art mit Prüfrechten sollte nicht bei einer Privatperson liegen.
- Einordnung als Telekommunikationsdienst und daraus folgende Pflichten (TKG, TDDDG, Fernmeldegeheimnis, Auskunftsersuchen).
- Betriebsmodell: nur ein zentraler Dienst des Herausgebers. **Selbst betriebene Instanzen scheiden aus**, denn laut Matrix.org braucht
  jeder Anbieter einen eigenen Vertrag und offene Föderation ist nicht vorgesehen. Das widerspricht dem Grundsatz „Replaceable server“
  und ist in `Concept.md` als Ausnahme festzuhalten.

## 6. Architekturentscheidung

### 6.1 Direkt oder Proxy

Das Angebot erlaubt zwei Architekturen:

| | **Direkt** | **Proxy** |
|---|---|---|
| Verbindung | App ↔ WhatsApp (Noise, XMPP-basiert) | App ↔ eigener Proxy ↔ WhatsApp |
| Wer sieht Metadaten | Meta | Meta **und der Herausgeber** vollständig |
| Client-IP bei Meta | direkt | über Proxy; Meta verlangt Zusatzmaßnahmen |
| Protokollcode | In der App | Teilweise auf dem Server |
| Serverlast | Gering | Hoch, dauerhafte Verbindung je Nutzer |
| NDA-Risiko (H1) | Maximal: alles in der AGPL-App | Geringer, aber nicht gelöst |
| Akkulaufzeit | Eigene dauerhafte Verbindung | Eigener Kanal zum Proxy |

**Entscheidung: Direkt.** Das hält den Herausgeber aus dem Nachrichtenfluss heraus und passt zum Ziel, möglichst wenig zu wissen.
**Ausnahme:** Erlaubt Meta die Veröffentlichung des Transportcodes nicht, wohl aber die des Nachrichtenformats, wird der Proxy zur
einzigen Option. Der Inhalt bleibt auch dann auf dem Gerät verschlüsselt.

### 6.2 Gesamtbild

```
┌─ App (Android, iOS) ───────────────────────────────────────────┐
│ ChatHub ─▶ MatrixGateway                     (Familie, Kontakte)│
│        └─▶ InteropGateway                    (WhatsApp, Weg A)  │
│              │ dart:ffi                                         │
│              ▼                                                  │
│            native/fn_interop (Rust)                             │
│              libsignal · Noise · Stanzas · SQLCipher            │
└───────┬───────────────────────────────┬─────────────────────────┘
        │ Anmeldung, Token, Medien      │ Noise, verschlüsselte Nachrichten
        ▼                               ▼
┌─ fn-interop (Herausgeber) ──┐   ┌─ WhatsApp-Infrastruktur (Meta) ─┐
│ Sitzung, Kennungen          │◀──│ holt öffentliche Schlüssel      │
│ Token-Signatur, JWKS        │◀──│ Push-Hinweise (HTTP)            │
│ Medienablage (Chiffrat)     │◀──│ Medienabruf über Meta-Proxy     │
│ Aufenthaltsprüfung          │   └─────────────────────────────────┘
│ Missbrauch, Vorfälle        │
└─────────────────────────────┘
        ▲
        │ OpenID-Prüfung einmalig bei der Anmeldung
   Matrix-Homeserver der Person
```

Grundsätze W3 (keine Brücke), W4 (Familie unberührt), W6 (kein Massenbetrieb), W7 (ehrliche Aussagen) und W8 (Regeln der Gegenseite)
aus `docs/WHATSAPP_KONTAKTE.md` gelten. W2 (getrennte Ausgaben) entfällt in dieser Form: Weg A darf in die Store-Ausgaben, soweit H1
gelöst ist.

## 7. Interop-Dienst `fn-interop`

Eigener, kleiner Dienst (Vorschlag: Go oder Rust, eigenes Repo, AGPL). Er sieht **nie Inhalte**. Er speichert keine Rufnummern von
Kontakten und keine Kommunikationspartner.

### 7.1 Bausteine

| Baustein | Aufgabe | Daten |
|---|---|---|
| `session` | Nachweis des Matrix-Kontos, Sitzung der App | Sitzungstoken (kurzlebig) |
| `identity` | Vergabe der Interop-Kennung | HMAC der Matrix-ID, Kennung, Zustimmung mit Zeitstempel |
| `token` | Signiert die JWT für WhatsApp; veröffentlicht öffentliche Schlüssel | Signaturschlüssel im HSM oder KMS |
| `location` | EWR-Prüfung aus IP mit lokaler Datenbank | Land und Datum der letzten Prüfung, **keine IP** |
| `media` | Ablage verschlüsselter Anhänge für den Abruf durch Meta | Chiffrat, Frist, Größe |
| `push` | Nimmt Hinweise von Meta entgegen, weckt die App ohne Inhalt | Geräte-Token |
| `abuse` | Ratenbegrenzung, Sperren, Meldungen | Zähler je Kennung |
| `ops` | Vorfallprozess, Protokolle ohne Personendaten, Überwachung | – |

### 7.2 Schnittstelle zur App (Entwurf)

```
POST   /v1/session          { matrix_openid_token, matrix_server }      → { session }
PUT    /v1/identity         { handle, consent_version }                 → { interop_id }
POST   /v1/wa-token                                                     → { jwt, expires_at } | 403 outside_eea
POST   /v1/media            { size, sha256 }                            → { upload_url, media_id }
PUT    /v1/push             { platform, token } 
DELETE /v1/account                                                      → löscht alles, siehe 9.8

GET    /.well-known/jwks.json                                           öffentlich, für Meta
GET    /media/{id}                                                      nur Meta-Proxy, zeitlich begrenzte URL
POST   /meta/push                                                       nur Meta, Absender geprüft
```

### 7.3 Anmeldung ohne neues Passwort

Das SDK bietet `requestOpenIdToken`. Die App holt ein kurzlebiges Token; `fn-interop` prüft es am Homeserver der Person
(`/_matrix/federation/v1/openid/userinfo`). So gibt es kein zweites Passwort.

- Gespeichert wird nur `HMAC(geheim, matrix_id)`, um Doppelanmeldungen zu erkennen.
- **Die Matrix-ID geht nie an Meta.** Die Kennung ist ein frei gewählter Nutzername, keine Ableitung daraus (I8, W3).
- **Offen:** Matrix-Konten sind beliebig anlegbar. Ob Meta das als Prüfung der Nutzer genügt, muss P0 klären. Ersatzweise E-Mail-Bestätigung
  wie bei BirdyChat oder eine Rufnummer, die ein Gateway kostet und dem Grundsatz der Datensparsamkeit widerspricht.

### 7.4 EWR-Prüfung

- Bei jedem `wa-token` bildet der Dienst die IP mit einer lokalen GeoIP-Datenbank auf ein Land ab. Die IP wird nicht gespeichert.
- Außerhalb des EWR: 403, die App sagt warum und nennt die Frist. Die Regel für Reisen ist unklar (BEREC bemängelt die 60-Tage-Regel).
  P0 klärt, ob ein Urlaub zur Sperre führt.
- VPN und ungenaue Datenbanken ergeben Fehlalarme. Die App erklärt das und bietet einen neuen Versuch.
- Die App nutzt **nie** GPS oder Standortrechte (`tool/check_permissions.sh` bleibt gültig).

### 7.5 Medien

Anhänge an WhatsApp liegen beim Partner: Die App verschlüsselt, lädt Chiffrat hoch, und Meta ruft es über einen Proxy ab. Die Ablage
enthält nur zufällige IDs. Löschung nach Frist (Vorschlag 30 Tage, Wert aus der Doku abzuleiten). Kosten skalieren mit Nutzung.

### 7.6 Push

Mit `docs/OFFEN.md` und E-16 gibt es bisher keinen Push, und `firebase` kommt in der App nicht vor. Meta sieht eine HTTP-Schnittstelle
für Push-Hinweise vor.

| Plattform | Vorschlag | Folge |
|---|---|---|
| iOS | APNs direkt, ohne Inhalt, ohne Firebase | Braucht Anbieter-Schlüssel beim Dienst |
| Android | UnifiedPush, falls installiert | Für die meisten Nutzer nicht vorhanden |
| Android ohne Verteiler | **Kein Push** | Nachrichten kommen erst beim Öffnen |

FCM bleibt ausgeschlossen (E-16). Ob Meta Push verlangt und wie lange Nachrichten warten, klärt P0. Der Hinweis nennt weder Absender noch
Inhalt.

### 7.7 Betrieb

Mindestens: zwei getrennte Instanzen in der EU, Sicherung, Überwachung, Schlüsselrotation, Vorfallbereitschaft, Kontakt für Meta und
Behörden, Pen-Test je Release. Das ist eine dauerhafte Aufgabe; sie endet nicht mit dem Release.

## 8. Umsetzung in der App

### 8.1 Bestandteile

```
native/fn_interop/                  Rust: libsignal, Noise, Stanzas, SQLCipher-Ablage, schmale C-Schnittstelle
lib/domain/interop.dart             InteropPeer, InteropState, ChatRequest, Grenzen, RufnummernId (E.164)
lib/domain/chat_backend.dart        aus docs/WHATSAPP_KONTAKTE.md 6.2
lib/data/interop/                   InteropGateway, FfiInteropGateway, InteropApi (Dienst), InteropMapper,
                                    SqlInteropStore, InteropSync
lib/app/chat_hub.dart               Kennung `wai:<id>` führt zu InteropGateway
lib/features/interop/               Einstieg, Zustimmung, Kennung, Kontakt hinzufügen, Verwaltung, Austritt
test/support/fake_interop.dart      Vollständiger Ersatz ohne Netz
```

**Warum Rust:** `flutter_vodozemac` bringt die Toolchain bereits mit (`docs/OFFEN.md`), `flutter_rust_bridge` ist vorhanden, und libsignal
ist in Rust geschrieben. Ein zusätzlicher Go-Kern wie in Weg C ist nicht nötig. libsignal steht unter AGPL-3.0, passt also zur App. Die
Einbindung über Git mit festem Stand ist in P1 zu prüfen, ebenso die Kompatibilität mit WhatsApps Variante.

### 8.2 Schnittstelle

```dart
abstract class InteropGateway implements ChatBackend, Listenable {
  InteropState get state;  // aus, angemeldet, verbunden, gesperrt, außerhalbEwr, aktualisierungNötig, anderesGerät
  Future<void> enable({required String handle, required int consentVersion});
  Future<void> disable();  // Austritt, Abschnitt 9.8
  Future<InteropReach> checkNumber(String e164);  // einzeln, nach Tipp (W6)
  Future<String> startChat(String e164, {required String localName});
  List<InteropPeer> get peers;
  Future<void> rename(String peerId, String localName);
  Future<void> setBlocked(String peerId, bool blocked);
  Future<void> report(String messageId, ReportCategory category);
  Future<String?> securityCode(String peerId);  // nur falls von Meta unterstützt
}
```

### 8.3 Datenhaltung

| Datei | Inhalt |
|---|---|
| `familynexus_wai_keys.db` | Identität, Prekeys, Sitzungen (nur Rust, SQLCipher) |
| `familynexus_wai.db` | `peers`, `threads`, `messages`, `attachments`, `outbox` |

Eigener Schlüssel `db.interop` im Plattform-Schlüsselspeicher (Muster E-05). Die Datenbanken bleiben von der App-Datenbank getrennt,
damit Löschung vollständig ist. Rufnummern gehen nie in den privaten Raum (W3).

### 8.4 Nur ein Gerät

Mehrgeräte-Betrieb war Stand 12/2024 nicht vorgesehen. Daraus folgt: **WhatsApp über FamilyNexus läuft auf genau einem Gerät.**
- Der Zustand steht beim Dienst (`device_id`). Ein zweites Gerät sieht „Auf einem anderen Gerät aktiv“ und kann übernehmen.
- Übernahme: neue Schlüssel, altes Gerät wird abgemeldet, **der Verlauf bleibt auf dem alten Gerät**. Die Gegenseite sieht einen geänderten
  Sicherheitscode.
- Das iPhone und das Android-Gerät derselben Person teilen sich also keine Chats. Das ist ein deutlicher Unterschied zu Familie und
  Kontakten, die Matrix über alle Geräte hält.

### 8.5 Anbindung an die Oberfläche

- Gespräche liegen im Bereich **Kontakte** aus V1.4, gekennzeichnet mit „WhatsApp“ als Text, ohne Logo.
- Desktop und Web zeigen den Bereich nicht, solange H2 gilt, mit dem Hinweis „Nur in der App für Android und iOS“.
- Kopfzeile: „Über WhatsApp. Verschlüsselt, aber Meta und FamilyNexus sehen, wann du schreibst.“
- Kein Online-Status, kein Profilbild, keine Zustellung von Familieninhalten.
- `AttachmentPolicy` deckt **weder Audio noch Video** ab. Sprachnachrichten und Videos sind Pflichtumfang des DMA. Neu ist eine eigene
  `InteropAttachmentPolicy` mit Audio- und Videotypen; die Regeln für Matrix-Räume bleiben. Eine Aufnahmefunktion hat die App nicht:
  eingehend abspielen braucht eine Medienbibliothek, die in `docs/ABHAENGIGKEITEN.md` zu prüfen ist. Vorschlag: zunächst nur als Datei anbieten.

## 9. Abläufe

### 9.1 Einschalten
1. Kontakte → **WhatsApp-Personen erreichen**. Erklärung: was es ist, was es nicht ist („Dein WhatsApp-Konto wird nicht verbunden“).
2. Zustimmung zu Bedingungen des Dienstes und zur Datenweitergabe an Meta (Annex 1, 7.4.2). Nicht vorbelegt, Version wird gespeichert.
3. Nutzername wählen. Prüfung gegen Familienname und Matrix-ID, kein Hinweis auf die Familie.
4. App holt Matrix-OpenID-Token, `POST /v1/session`, `PUT /v1/identity`.
5. App erzeugt Schlüssel, ruft `wa-token`, schreibt sich über die Enlistment-API ein und lädt Prekeys hoch.

### 9.2 Kontakt hinzufügen
1. Rufnummer eingeben, Eingabe je Person. Das Adressbuch wird nicht gelesen (kein Upload, W6).
2. Existence-Check-API. Anzeige: „Erreichbar“ oder „Diese Person hat Drittanbieter-Chats noch nicht eingeschaltet“.
3. Name lokal vergeben, weil WhatsApp keinen liefert.
4. Erste Nachricht wird zur **Chat-Anfrage**. Die App schlägt vor, die Person vorher anderweitig zu informieren: Sie sieht nur eine Kennung.
5. Zustand: `anfrage gesendet` → `aktiv` oder `abgelehnt`.

BEREC weist darauf hin, dass Rufnummern neu vergeben werden. Die App warnt deshalb bei einer geänderten Sicherheitsnummer.

### 9.3 Senden
1. `ChatHub` leitet `wai:` an `InteropGateway`, Eintrag in `outbox`.
2. Rust holt bei neuer Sitzung die Schlüssel des Empfängers, baut die Protobuf-Nachricht und verschlüsselt sie mit Signal.
3. Paket als Stanza über die Noise-Verbindung. Zustand nach Bestätigung des Servers.

### 9.4 Empfangen
Offene Verbindung nur im Vordergrund (E-16), außer ein Push weckt die App kurz. Die Entschlüsselung erfolgt in Rust. `InteropMapper`
behandelt alles als nicht vertrauenswürdig wie `ChatMapper`.

### 9.5 Medien senden
App verschlüsselt, `POST /v1/media`, Upload, Verweis mit Schlüssel und Hash in der Signal-Nachricht. Größe nach Doku, höchstens 25 MB (E-19).

### 9.6 Medien empfangen
Nur auf Tipp, begrenzter Download, Hash-Prüfung, Allowlist.

### 9.7 Sperre, Protokollwechsel, Reise

| Ereignis | Verhalten |
|---|---|
| Meta sperrt die Person | Hinweis, Chats lesbar, kein Senden |
| Meta sperrt den Partner (Punkt 5) | Bereich schreibgeschützt, Meldung für alle; Abschaltplan in den Bedingungen des Dienstes |
| Neue Mindestversion | `aktualisierungNötig`, Hinweis auf Update; Frist 3 Monate |
| Außerhalb EWR | `außerhalbEwr`, Text und Frist; Lesen bleibt |
| Anderes Gerät | `anderesGerät`, Übernahme möglich |
| Fehler im Bereich | Familie und Kontakte laufen weiter |

Ein Vertragsende ist einzuplanen: BEREC bemängelt, dass die Abwicklung für Endnutzer ungeregelt ist. Die App muss lokale Chats trotzdem
lesbar lassen.

### 9.8 Austritt
Ausschreiben bei WhatsApp, `DELETE /v1/account`, Löschen beider Datenbanken und von `db.interop`, Medienablage per Frist. Auch ausgelöst
durch „Alle lokalen Daten löschen“ und Abmelden (`wipeAccountDataIn`, `onFullReset`). Beim Konto-Löschen (E-73) läuft der Austritt vorher,
weil danach kein Matrix-Nachweis mehr möglich ist.

## 10. Funktionsumfang

| Funktion | Stand | V1 |
|---|---|---|
| Text 1:1 | Pflicht seit 2024 | ✔ |
| Bilder, Dateien | Pflicht seit 2024 | ✔ |
| Sprachnachrichten, Videos | Pflicht seit 2024 | Empfang als Datei |
| Lesebestätigung, Tippen, Reaktionen, Antworten | Für Messenger dokumentiert, für WhatsApp 12/2024 nicht | Laut aktueller Doku |
| Bearbeiten, Löschen | 12/2024 nicht vorgesehen | Nein |
| Gruppen | Doku seit 09/2025; Kommission überwacht; Partner laut Berichten noch nicht | Spätere Stufe |
| Anrufe | Frist 07.09.2027 | Nein |
| Anzeigename, Profilbild, Status, zuletzt online | 12/2024 nicht vorgesehen | **Nein** |
| Verlauf aus WhatsApp | Nicht Teil des Modells | **Nein** |
| Desktop, Web | Nur Android und iOS | **Nein** |

## 11. Ende-zu-Ende-Verschlüsselung

- **Inhalt:** Signal-Protokoll zwischen dem FamilyNexus-Gerät und den WhatsApp-Geräten der Gegenseite. Schlüssel entstehen nur auf dem
  Gerät; `fn-interop` sieht keine Inhalte, auch nicht bei Medien.
- **Meta kann laut eigenen Angaben nicht mitlesen.** Meta sagt aber auch, das Versprechen gelte nur „as far as possible“, weil es den anderen
  Client nicht kontrolliert. Die Verantwortung für den Client liegt damit bei FamilyNexus.
- **Metadaten bei Meta:** laut WhatsApp-Hinweis Nutzername, Zeitstempel einschließlich „zuletzt online“, Nachrichtentypen, IP-Adresse,
  Betriebssystem, App-Name und -Version, ungefährer Standort, Sperr- und Gruppeninformationen. Aufbewahrung ohne feste Frist.
- **Metadaten beim Herausgeber:** in der Direkt-Variante nur Anmeldung, Token-Abrufe und Medien-Uploads.
- **Sicherheitscode:** Prüfung mit dem Gegenüber anbieten, falls die Doku das hergibt; sonst sagt die App, dass sie nicht verfügbar ist.
- **Geräteverlust:** Keine Sicherung der Schlüssel. Neue Kopplung ergibt neue Identität, die Gegenseite sieht das.

Die App verwendet für diese Gespräche nicht das Familien-Schloss und stellt das Schutzniveau nicht gleich (W7).

## 12. Familie und Minderjährige

- Keine Familieninhalte, keine Termine, kein Status gehen an den Bereich oder an `fn-interop` (W3, W4). Der Bereich ist abschaltbar, und
  er ändert nichts, solange er aus ist.
- `fn-interop` kennt keine Familie. Die Kennung trägt keinen Familienbezug. WhatsApp erfährt nur „FamilyNexus“ als App-Name; das ist als
  Preisgabe der Nutzung im Dialog genannt.
- **Mindestalter:** Vorschlag 18 Jahre für diesen Dienst. Das passt zur Einstufung in Play (E-47), vermeidet Art. 8 DSGVO im eigenen Dienst
  und ist Selbstauskunft, also keine Prüfung.
- `member_policy` aus `docs/KONTAKTE.md` 9.4 sperrt auch diesen Bereich.

## 13. Datenschutz

| Punkt | Folge |
|---|---|
| Rollen | Herausgeber und Meta sind je unabhängig Verantwortliche (Annex 5) |
| Daten beim Herausgeber | HMAC, Kennung, Zustimmung, Land, Push-Token, Chiffrat. Neue Rechtsgrundlagen, Fristen, Auskunft, Löschung |
| Übermittlung | Meta in den USA; SCC im Angebot enthalten |
| Daten Dritter | Rufnummern der Kontakte gehen beim Prüfen an Meta. Nutzer tippen sie selbst ein |
| Datenschutz-Folgenabschätzung | Vorab durchzuführen; Pflicht durch Fachleute zu prüfen |
| Auftragsverarbeiter | Hosting, Push |
| Vorfälle | Meldung an Meta **und** nach DSGVO |
| Store-Angaben | „Der Herausgeber … erhält keine Daten“ wird falsch, Datensicherheit und Nährwertangaben sind neu zu erstellen |

## 14. Sicherheit

| Risiko | Gegenmaßnahme | Restrisiko |
|---|---|---|
| Diebstahl des Signaturschlüssels | HSM oder KMS, Rotation, Überwachung | Fälschung von Kennungen, Sperre durch Meta |
| Einbruch in `fn-interop` | Keine Inhalte, minimale Daten, Pen-Test | Metadaten, Sperre, Vertragsrisiko |
| Missbrauch als Spam-Kanal | Ratenbegrenzung, keine Massenprüfung, Sperren, Meldung | Sperre des gesamten Dienstes für alle Nutzer |
| Fehler in Rust-FFI | Kleine Schnittstelle, Fuzzing, kein Parser in Dart | Speicherfehler im Prozess mit Familienschlüsseln (SA-13) |
| Prüfrechte von Meta | Getrennte Systeme, Mandantentrennung | Einsicht in den Betrieb. Matrix-Daten liegen nicht beim Dienst |
| Gefälschte Mitteilung von Meta | Absenderprüfung an `/meta/push`, kein Inhalt | – |
| Rufnummern in Logs | `AppLog` erweitern, Test | – |
| Identitätstäuschung | Quelle und Rufnummer immer sichtbar, Warnung bei Namensgleichheit mit Mitglied | – |
| Prekey-Erschöpfung | Nachladen, Überwachung | Kurze Zustellprobleme |

**SA-13 (vorgeschlagen):** FamilyNexus erhält erstmals einen zentralen Dienst des Herausgebers und einen zweiten Kryptografie-Stack im
selben Prozess. Die Verfügbarkeit hängt von Meta und vom Herausgeber ab.

## 15. Lizenzfrage (H1)

| Bestandteil | Lizenz | Folge |
|---|---|---|
| `matrix`, `flutter_vodozemac`, App | AGPL-3.0 | Gesamtwerk muss offen bleiben. **Der Herausgeber kann für fremden AGPL-Code keine Ausnahme erteilen** |
| libsignal | AGPL-3.0 | Passt zur App |
| Protokollcode nach NDA-Doku | Ungeklärt | **Kernfrage** |

BEREC warnte schon 2024: Offene Apps könnten von der Integration ausgeschlossen sein, wenn sie Code nicht veröffentlichen dürfen. Ob das
weiter gilt, ist unbelegt.

| Ergebnis in P0 | Folge |
|---|---|
| Veröffentlichung des Implementierungscodes erlaubt | Weiter, Direkt-Variante |
| Nur Transport geschützt, Nachrichtenformat offen | Proxy-Variante, geschlossener Teil auf dem Server, sofern lizenzrechtlich getrennt |
| Nichts darf veröffentlicht werden | **Abbruch in dieser App.** Nur noch als getrennte, eigenständige Anwendung denkbar, die nicht mit AGPL-Code gebunden ist |

Eine geschlossene Bibliothek in der App ist kein Ausweg, weil sie mit dem AGPL-Code zusammen verteilt würde. Das wäre eine Lizenzverletzung
gegenüber Dritten.

## 16. Änderungen im Repository

| Datei | Änderung |
|---|---|
| `Concept.md` | Dienst des Herausgebers, Ausnahme zu „Replaceable server“ |
| `docs/ENTSCHEIDUNGEN.md`, `docs/OFFEN.md`, `docs/ARCHITEKTUR.md`, `README.md` | E-77, SA-13, zwei Backends, Grenzen |
| `docs/STORE.md` | Datensicherheit, Vertrag als Nachweis für Apple 5.2.2, eigener Kontakt für Beschwerden (1.2) |
| `store/privacy/*`, `store/metadata/*` | Dienst, Meta als Empfänger, Prüfhinweise |
| `docs/export-compliance/` | Signal, Noise |
| `docs/ABHAENGIGKEITEN.md`, `tool/sbom.py` | Rust-Crates, Medienbibliothek |
| `android/`, `ios/` | Push nach 7.6, Bibliotheken je Plattform |
| `.github/workflows/release.yml`, `tool/check_apk_abis.sh` | Rust-Kern, iOS-Build |
| `test/architecture_test.dart` | Grenzen für `data/interop`, keine Rufnummern im Matrix-Pfad |

## 17. Tests

| Ebene | Inhalt |
|---|---|
| Rust | Testvektoren, Fuzzing, Wiederaufnahme, Prekey-Rotation |
| Domäne, Daten | Rufnummern, Zustände, `SqlInteropStore`, Löschpfade |
| Widget (`FakeInterop`) | Zustimmung ist Pflicht, alle `InteropState`, Anfrage, Desktop ohne Bereich |
| Isolation | Kein Weg nach Matrix, keine Matrix-ID beim Dienst außer OpenID, kein Familiendatum im Bereich |
| Dienst | API, JWT, JWKS-Rotation, EWR, Medienfrist, Ratenbegrenzung, Keine-IP-Nachweis |
| Partnertest | Testumgebung von Meta nach Annex 1 Kap. 5; alle OS-Kombinationen |
| Sicherheit | Pen-Test von Dienst und App durch Dritte, vor Aktivierung |
| Manuell | Android und iOS gegen echte WhatsApp-Clients in der Testumgebung, nur mit Freigabe |

Tests gegen die Produktion von WhatsApp laufen erst nach Aktivierung durch Meta.

## 18. Umsetzung in Phasen

Gilt nur nach einer Neubewertung (Abschnitt 1). Bis dahin startet keine dieser Phasen, auch nicht P0.

| Phase | Inhalt | Umfang | Abbruch, wenn |
|---|---|---|---|
| **P0 Klärung** | Portal und aktuelles Angebot lesen, Rechtsberatung, Rechtsträger, Vorgespräch mit Meta, NDA prüfen, Budget | M, kein Code | H1 nicht lösbar, kein Rechtsträger, Betrieb nicht leistbar |
| **P1 Antrag** | Bewerbung, NDA, Doku, Signal-Prüfung, Prototyp der Sitzung in der Testumgebung | M | Meta lehnt ab oder Doku widerspricht dem Konzept |
| **P2 Dienst** | `fn-interop`: Sitzung, Kennung, Token, JWKS, EWR, Betrieb | L | – |
| **P3 Kern** | `native/fn_interop`, Android und iOS, Ablage, Einschreiben, Verbindung | XL | Inkompatibel mit WhatsApp |
| **P4 Chat** | Kontakte, Existenzprüfung, Anfragen, Text, Bilder, Dateien, Medienablage, Fehlerfälle | L | – |
| **P5 Prüfung** | Partnertest, Pen-Test, Datenschutz, Store | L | Test nicht bestanden |
| **P6 Start** | Aktivierung, begrenzter Nutzerkreis, Überwachung | M | – |
| **P7 Ausbau** | Reaktionen, Antworten, Gruppen, soweit dokumentiert | je M | – |

Voraussetzung sind V1.4 (Bereich Kontakte) und `ChatBackend`, `ChatHub` aus `docs/WHATSAPP_KONTAKTE.md`.

**Zeitrahmen, eigene Schätzung:** Mindestens 12 Monate bis zur Aktivierung. Die gesetzlichen 3 Monate gelten für Meta, nicht für die eigene
Entwicklung. Meta spricht bei den Erstpartnern von mehr als drei Jahren Arbeit an der Interoperabilität; BirdyChat startete breit erst 2026.

### Abnahmekriterien
1. Eine Person ohne WhatsApp-Konto erreicht eine eingeschaltete WhatsApp-Person im EWR, und diese kann antworten.
2. Inhalte und Medien liegen beim Dienst und bei Meta nur verschlüsselt (Mitschnitt in der Testumgebung, Prüfung der Ablage).
3. Der Dienst speichert weder IP-Adressen noch Rufnummern von Kontakten noch Matrix-IDs im Klartext (Audit).
4. Die Matrix-ID erscheint nie in Daten an Meta (Test).
5. Ohne Zustimmung findet kein Einschreiben statt; die Version der Zustimmung ist belegbar.
6. Außerhalb des EWR wird kein Token ausgegeben, die App erklärt das.
7. Ein zweites Gerät übernimmt erst nach Bestätigung; das erste wird abgemeldet.
8. Austritt und Kontolöschung entfernen alle Daten beim Dienst und auf dem Gerät.
9. Sperre durch Meta und Ausfall des Dienstes beeinträchtigen Familie und Kontakte nicht.
10. Keine Rufnummern, Kennungen oder Inhalte in Logs von App und Dienst.
11. Die App behauptet nirgends, das WhatsApp-Konto sei verbunden oder Status verfügbar.
12. Partnertest von Meta bestanden, Pen-Test ohne offene hohe Befunde.

## 19. Aufwand

Keine Gebühr an Meta (Art. 7(1) DMA). Kostenblöcke ohne Schätzung in Euro, weil Angebote fehlen:

| Einmalig | Laufend |
|---|---|
| Rechtsberatung, Datenschutz-Folgenabschätzung | Hosting in der EU, Medienablage, Überwachung |
| Rechtsträger | Vertrags- und Vorfallbereitschaft |
| Entwicklung von Dienst und Rust-Kern | Pflege bei Doku-Änderungen (3-Monats-Frist) |
| Pen-Test | Pen-Test je größerem Release, Support, Beschwerden |

## 20. Entscheidungen

**Entschieden** (`docs/WHATSAPP_KONTAKTE.md` Abschnitt 1.1, Freigabe durch den Herausgeber steht aus):

| Frage | Entscheidung | Betrifft |
|---|---|---|
| Wird Weg A implementiert? | **Nein**, gewählt ist Weg C nach G0 | 1 |
| P0 starten? | **Nein**, nur bei Neubewertung | 1, 18 |
| Weg A und Weg C zugleich? | **Nein**, um Vertrag und Partnerstatus nicht zu gefährden | 1 |

**Nur bei einer Neubewertung zu entscheiden:**

| Frage | Vorschlag | Betrifft |
|---|---|---|
| Soll der Herausgeber Betreiber werden? | **Nur mit Rechtsträger und Budget** | 5, 7 |
| Direkt oder Proxy? | **Direkt**, Proxy nur wegen H1 | 6.1 |
| Anmeldung | **Matrix-OpenID plus Nutzername**, E-Mail nur wenn Meta es verlangt | 7.3 |
| Push | **APNs ohne Firebase, UnifiedPush, sonst kein Push** | 7.6 |
| Mindestalter | **18** | 12 |

## 21. Quellen

Abgerufen am 2026-10-31.

- BEREC Opinion BoR (25) 21, 03.03.2025: https://www.berec.europa.eu/system/files/2025-03/BoR%20(25)%2021%20BEREC%20Opinion%20on%20Meta's%20reference%20offers.pdf
- BEREC Opinion BoR (24) 19, 15.02.2024: https://www.berec.europa.eu/system/files/2024-03/BoR%20%2824%29%2019_BEREC%20Opinion%20on%20Meta_final.pdf
- EU-Kommission, Messaging-Interoperabilität: https://digital-markets-act.ec.europa.eu/messaging-interoperability_en
- EU-Kommission, COM(2026) 247: https://digital-markets-act.ec.europa.eu/document/download/2f31180c-b9da-49d4-ae36-3a4109cc59a5_en?filename=CELEX_52026DC0247_EN_TXT.pdf
- WhatsApp, Hinweis für Nutzer anderer Dienste: https://whatsapp.com/legal/dma-notice-non-users
- Meta Engineering (03/2024): https://engineering.fb.com/2024/03/06/security/whatsapp-messenger-messaging-interoperability-eu/
- Meta, Drittanbieter-Chats (11/2025): https://about.fb.com/news/2025/11/messaging-interoperability-whatsapp-enables-third-party-chats-for-users-in-europe/
- Meta-Entwicklerportal (nicht abrufbar): https://developers.facebook.com/m/messaging-interoperability/
- Matrix.org (09/2024): https://matrix.org/blog/2024/09/whatsapp-dma/
- Element: https://element.io/blog/the-eu-digital-markets-act-is-here
- Brussels Signal zu BirdyChat (05/2026): https://brusselssignal.eu/2026/05/european-chat-app-launches-pioneering-dmas-messaging-interoperability/
- Matrix-Spezifikation, OpenID: im SDK als `requestOpenIdToken` (matrix 14.2.0)
