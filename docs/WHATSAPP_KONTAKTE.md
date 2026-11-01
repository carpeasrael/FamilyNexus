# WhatsApp-Kontakte in FamilyNexus (Implementierungskonzept)

Stand: 2026-10-31 · Status: **Entwurf zur Abstimmung, nicht umgesetzt, rechtliche Freigabe fehlt** · Basis: Version 1.2.1 (22)
und das Kontakte-Konzept `docs/KONTAKTE.md` (V1.4) · Entscheidung: E-76, für Weg A E-77 (vorgeschlagen) · Sicherheitsabweichung:
SA-12, für Weg A SA-13 (vorgeschlagen) · Arbeitstitel Release: nach V1.4 · Detailkonzepte: `docs/WHATSAPP_KONTAKTE_OPT-A.md`,
`docs/WHATSAPP_KONTAKTE_OPT-C.md` (bei Abweichungen gilt das Detailkonzept, für die Wahl des Weges gilt Abschnitt 1.1)

## 1. Ergebnis vorab

**Keiner der verfügbaren Wege erfüllt alle Anforderungen und ist zugleich von WhatsApp erlaubt.**

| Weg | Chat | Eigene Kontakte | Status | Echte E2EE | Von WhatsApp erlaubt | Store möglich |
|---|---|---|---|---|---|---|
| **A** Offizielle Schnittstelle (DMA) | teilweise: neuer Chat, nur eins zu eins, nur EWR, Gegenseite muss einschalten | ✔ von Hand, kein Import | ✘ | ✔ | ✔ mit Vertrag | ✔ nur Android und iOS, sofern NDA und AGPL vereinbar sind |
| **B** Server-Bridge (mautrix-whatsapp) | ✔ | ✔ teilweise | teilweise | **✘ Bridge liest Klartext** | ✘ inoffiziell | ✘ |
| **C** Gekoppeltes Gerät in der App (whatsmeow) | ✔ nur bei laufender App | ✔ | ✔ Online-Status nur mit eigener Sichtbarkeit | ✔ | ✘ inoffiziell | ✘ |

Nutzer tragen bei Weg C ein reales Risiko: **Ihr WhatsApp-Konto kann gesperrt werden**, nach Berichten auch ohne Massenversand.
Das Konzept kann das nicht beseitigen, nur offenlegen. Maßnahmen zur Umgehung von Erkennung oder Sperren sind ausdrücklich
ausgeschlossen. **Android auf dem Hauptgerät ist nicht koppelbar** (Abschnitt 3.4).

### 1.1 Entscheidung: Weg C, nicht Weg A

**Implementiert wird Weg C, und zwar erst nach positiver rechtlicher Freigabe (Gate G0, Abschnitt 4). Weg A wird nicht implementiert.
Weg B bleibt abgelehnt.** Stand: E-76, vorgeschlagen; die Freigabe durch den Herausgeber steht aus.

Weg C wird als **zusätzliche `-wa`-Pakete** außerhalb der Stores gebaut und ist standardmäßig aus. Store-Ausgaben und die bisherigen
Download-Dateien enthalten keinerlei WhatsApp-Code. Er ist ein Zusatzangebot für Desktop und Zweitgeräte.

| Kriterium | Weg A | Weg C | Vorteil |
|---|---|---|---|
| Vorhandene WhatsApp-Kontakte und -Chats (A1) | Nein, neuer Dienst; Gegenseite muss einschalten | Ja, das eigene Konto | C |
| In Kontakte aufnehmen (A2) | Von Hand | Aus dem Konto | C |
| Status (A3) | Nein | Ja, Online-Status mit eigener Sichtbarkeit | C |
| E2EE (A4) | Ja | Ja, mit inoffizieller Umsetzung | A |
| Von WhatsApp erlaubt | Ja, mit Vertrag | Nein | A |
| Risiko für das WhatsApp-Konto | Keins | **Sperre möglich** | A |
| Rolle des Herausgebers | Betreiber mit Vertrag, Prüfrechten und Server | Softwareherausgeber, kein Server | C |
| Plattformen | Android und iOS | Android als Zweitgerät, Linux, Windows, macOS | offen |
| Store | Möglich, sofern H1 gelöst | Nein | A |
| Größtes Hindernis | NDA gegen AGPL, außerhalb eigener Kontrolle | Rechtsprüfung, verschlüsselte Ablage | C |
| Dauerlast | Betrieb, Vorfälle, 3-Monats-Frist | Pflege bei Protokolländerungen | C |
| Rücknahme | Vertrag und Dienst abwickeln | `-wa`-Pakete einstellen | C |

**Begründung:**
1. **Weg A löst eine andere Aufgabe.** Er erreicht Personen, ohne selbst WhatsApp zu nutzen. Der Auftrag ist, mit den eigenen Kontakten
   weiterzuchatten und ihren Status zu sehen. Selbst vollständig umgesetzt erfüllt Weg A das nicht.
2. **Weg A verändert das Projekt mehr als Weg C.** Er macht den Herausgeber zum Betreiber und beendet „kein Server, keine Daten“. Weg C
   lässt alle bisherigen Ausgaben und deren Zusagen unberührt.
3. **Weg C ist umkehrbar.** Er lässt sich einstellen, ohne dass Vertrag, Dienst und Nutzerkonten abzuwickeln sind.

**Der Preis dieser Entscheidung:** Weg C ist der einzige Weg, der gegen die WhatsApp-Bedingungen verstößt (meine Lesart, keine
Rechtsberatung). Das Risiko der Kontosperre tragen die Nutzer. Das ist nur mit Warnseite, ausdrücklicher Zustimmung und Stopp ohne
Neuversuch vertretbar. iOS bleibt ohne WhatsApp, und Android-Nutzer mit nur einem Telefon können es nicht nutzen.

| Ergebnis | Folge |
|---|---|
| G0 positiv, Herausgeber bestätigt Zusatzangebot und Pflege | Start mit C0 |
| G0 negativ oder Pflege nicht gesichert | **Verzicht** |
| C0 negativ (Ablage nicht verschlüsselbar, Lizenz unvereinbar) | **Verzicht** |
| Status (A3) wird aufgegeben und die Betreiberrolle ist gewollt | Neu bewerten, dann Phase P0 aus `docs/WHATSAPP_KONTAKTE_OPT-A.md` |

Weg A ist also keine automatische Rückfallebene. Ohne die letzte Zeile wird auch P0 nicht gestartet. Nächster Schritt ist die
Rechtsberatung zu G0; vorher entsteht kein WhatsApp-Code.

## 2. Anforderungen und Begriffe

| # | Anforderung | Umsetzung in diesem Konzept |
|---|---|---|
| A1 | Mit WhatsApp-Kontakten weiter chatten | Einzel- und bestehende Gruppenchats, Antworten, Reaktionen, Anhänge |
| A2 | In die eigenen Kontakte aufnehmen | Abschnitt „WhatsApp“ in der Kontaktliste aus V1.4 |
| A3 | Deren Status sehen | Drei verschiedene Dinge, siehe unten |
| A4 | Ende-zu-Ende-Verschlüsselung | WhatsApp-Verschlüsselung endet auf dem FamilyNexus-Gerät, Abschnitt 8 |

„Status“ ist mehrdeutig. Die Anfrage nennt nur das Wort, daher sind alle drei Bedeutungen eingeplant:

| Bedeutung | Quelle | Umfang |
|---|---|---|
| **Online-Status** (online, zuletzt online) | `SubscribePresence` | Optional und nur im offenen Chat, Abschnitt 7.4 |
| **Status-Meldungen** (24-Stunden-Beiträge) | `status@broadcast` | Nur lesen |
| **Info-Text** („about“) | `GetUserInfo`, `events.UserAbout` | Nur lesen |

**Nicht enthalten:** Anrufe (whatsmeow setzt sie nicht um), eigene Status-Meldungen (dort als experimentell markiert),
Listen, Weiterleiten zwischen Familie und WhatsApp, iOS, Web.

## 3. Bewertung der Wege

Stand der Recherche 2026-10-31. Quellen in Abschnitt 17. Was nicht belegt werden konnte, steht unter 3.2 und 3.4.

### 3.1 Gemeinsame Tatsachen
- Die WhatsApp-Bedingungen (gültig ab 17.08.2026) nennen inoffizielle Clients nicht wörtlich. Sie verbieten aber Reverse
  Engineering und abgeleitete Werke, unerlaubten Zugriff sowie Software, die den Diensten im Wesentlichen gleicht, und
  erlauben das Sperren von Konten. **Meine Lesart:** B und C fallen voraussichtlich darunter. Das ist keine Rechtsberatung.
- WhatsApp testet laut Berichten aus 2026 Warnhinweise zu inoffiziellen Web-Clients bei den gekoppelten Geräten.
- In whatsmeow-Issue #810 berichten Nutzer von der Meldung „Your account may be at risk“ auch ohne Massenversand, bei rein
  antwortenden und sogar untätigen Konten, teils mit Sperre. Die Maintainer äußerten sich nicht zur Ursache, Zahlen gibt es keine.
- `whatsmeow` kennt die Ereignisse `TemporaryBan` und `ClientOutdated`. Beides muss man also als normalen Betriebsfall
  einplanen.

### 3.2 Weg A: Offizielle Schnittstelle nach DMA
Von Meta vertraglich erlaubt, mit echter E2EE, passt aber nicht zum Auftrag und nicht zum Projekt. Details in
`docs/WHATSAPP_KONTAKTE_OPT-A.md`.

- **Anderes Modell:** FamilyNexus wäre ein eigener Dienst neben WhatsApp, nicht Client des vorhandenen WhatsApp-Kontos.
  Die vorhandenen Chats, Kontakte und der Verlauf kommen nicht mit. Der Weg dient dazu, Personen zu erreichen, ohne selbst
  WhatsApp zu nutzen.
- **Die Gegenseite muss mitmachen:** WhatsApp-Nutzer schalten Drittanbieter-Chats selbst ein (laut Meta 2025; nur Android
  und iOS, nur europäische Nummern) und sehen von einer Anfrage nur die Kennung, ohne Name und Vorschau (BEREC).
- **Umfang:** Nachrichten, Bilder, Sprachnachrichten, Videos, Dateien, eins zu eins. Gruppen sind seit 09/2025 dokumentiert,
  Partner bieten sie laut Berichten noch nicht an. Anzeigename, Profilbild, Online-Status und Status-Meldungen fehlen.
- **Eigene Kontakte:** möglich als lokale Liste nach Rufnummer, von Hand gepflegt. Ein Import aus WhatsApp ist nicht vorgesehen.
- **Ein Gerät:** Mehrgeräte-Betrieb war Stand 12/2024 nicht vorgesehen. Der Verlauf bleibt bei einem Gerätewechsel zurück.

**Vier Hindernisse, jedes kann das Vorhaben allein beenden:**

| # | Hindernis | Warum kritisch |
|---|---|---|
| H1 | NDA gegen AGPL | Details gibt es nur unter NDA, die App muss offen bleiben. Für fremden AGPL-Code kann der Herausgeber keine Ausnahme erteilen. Darf der Protokollcode nicht veröffentlicht werden, geht Weg A in dieser App nicht |
| H2 | Nur Android und iOS | `Client` war definiert als native Android- oder iOS-App (Stand 12/2024). Linux, Windows, macOS und Web fielen weg |
| H3 | Herausgeber wird Anbieter | Vertrag, weitreichende Prüfrechte, Vorfallmeldungen, Rolle als Verantwortlicher, eigener Dienst für Anmeldung, Token, Medien und Push. `docs/STORE.md` sagt dagegen: „Der Herausgeber betreibt keinen Server“. Änderungen von Meta sind binnen 3 Monaten zu übernehmen |
| H4 | Aufenthaltsprüfung | Der Anbieter muss prüfen, dass seine Nutzer im EWR sind; das verlangt eine IP-Auswertung |

- **Matrix passt nicht:** Laut Matrix.org (2024) braucht jeder Anbieter einen eigenen Vertrag, offene Föderation ist nicht vorgesehen,
  und die ursprünglichen Bedingungen ließen kein serverseitiges Puffern zu. Selbst betriebene Instanzen scheiden damit aus, und
  der Weg wäre am Matrix-Teil vorbei zu bauen. Element hat 2024 einen Versuch nur als experimentell beschrieben.
- **Aufwand:** Die Nutzung ist unentgeltlich (Art. 7(1) DMA), Betrieb, Prüfung und Rechtsberatung kosten trotzdem. Bis zur Aktivierung
  sind nach eigener Schätzung mindestens 12 Monate zu erwarten; die gesetzlichen 3 Monate gelten nur für Meta.
- **Quellenlage:** Metas Entwicklerportal war nicht abrufbar. Die Vertragsdetails stammen aus BEREC-Stellungnahmen (Angebotsstand 12/2024).
  Meta hat das Angebot am 06.09.2025 aktualisiert, einzelne Punkte können überholt sein.

**Weg A wird nicht implementiert (Abschnitt 1.1).** Eine Neubewertung begänne mit Phase P0 ohne Code: aktuelles Angebot, Rechtsberatung,
Rechtsträger, Vorgespräch mit Meta. Scheitert H1, wäre Weg A in dieser App beendet. Die Architektur hält die Schnittstelle offen
(Abschnitt 6.2).

### 3.3 Weg B: Server-Bridge
- **Erfüllt A4 nicht.** End-to-Bridge-Verschlüsselung schützt nur vor dem Homeserver. Die Bridge selbst verarbeitet
  Klartext, ihr Betreiber kann mitlesen. Das widerspricht „Kein Klartext verlässt das Gerät“ (`Concept.md`).
- **Online-Status fehlt:** mautrix-whatsapp überträgt Presence nicht von WhatsApp nach Matrix. Status-Meldungen ja.
- **Nicht mit matrix.org nutzbar:** Bridges werden in der Homeserver-Konfiguration registriert. Das setzt einen eigenen
  Server voraus (eigene Schlussfolgerung, keine Richtlinie von matrix.org gefunden). Standard der App ist matrix.org (E-70).
- **Client-Einstellung:** Die Bridge braucht `self_sign`, weil die App nur cross-signierten Geräten Schlüssel gibt.
  Geisternutzer tragen keine eigenen Schlüssel; die Bridge verschlüsselt über ihren Bot. Das Modell „Absender besitzt das
  Gerät“ aus E-27 gilt dort nicht.

**Abgelehnt.** Folge für V1.4: Wer selbst eine Bridge betreibt, bekäme ihre Räume als normale Megolm-Räume mit Kontakten
angezeigt. Das Schloss-Symbol wäre irreführend. In V1.4 ist das nicht zuverlässig erkennbar; `OFFEN.md` sollte das nennen.

### 3.4 Weg C: Gekoppeltes Gerät in der App
Die App wird zu einem **gekoppelten Gerät** des vorhandenen WhatsApp-Kontos, wie WhatsApp Web, über die Bibliothek
`whatsmeow` (MPL-2.0, aktiv gepflegt, Stand 30.10.2026). Signal-Sitzungen enden auf dem FamilyNexus-Gerät. Es gibt keinen
Server des Herausgebers, keinen Zwischenknoten, und Matrix ist nicht beteiligt.

**Befunde aus dem Quellcode von whatsmeow:**
- **Nur Kopplung per QR.** `PairPhone` verlangt einen Namen der Form `Browser (OS)` mit gängigen Werten. Für FamilyNexus wäre das eine
  Falschangabe (W5). Der QR-Code muss mit dem WhatsApp-Telefon gescannt werden, daher ist **Android auf dem Hauptgerät nicht koppelbar**.
  Android taugt nur als Zweitgerät.
- **Selbstauskunft als Web-Client.** Die Bibliothek meldet Plattform `WEB`, Gerät `Desktop` und eine feste WhatsApp-Web-Version.
  Das gehört in die Prüfung von G0.
- **Keine verschlüsselte Ablage von Haus aus.** whatsmeow speichert in SQLite oder Postgres, ein gepflegter SQLCipher-Treiber für Go ist
  nicht gesichert. Ohne Lösung in C0 kein Weg C.
- **Signal-Umsetzung inoffiziell.** `go.mau.fi/libsignal` stammt weder von Signal noch von WhatsApp. Ein unabhängiges Audit ist nicht bekannt.

**Einordnung:** Am Desktop gibt es WhatsApp bereits offiziell. Der Gewinn ist dort eine gemeinsame App, der Einsatz ist das
WhatsApp-Konto der Person. Auf dem Telefon, wo der Nutzen am größten wäre, greift die Grenze der Kopplung.

**Noch nicht belegt, Klärung in C0** (vollständige Liste: `docs/WHATSAPP_KONTAKTE_OPT-C.md` Abschnitt 18):
- Wie oft Warnhinweise oder Sperren vorkommen. Das ist nicht messbar, ein Test mit einer Nummer beweist nichts.
- Ob das Telefon Benachrichtigungen unterdrückt, solange ein gekoppeltes Gerät „online“ ist.
- Welche Nachrichten beim Wiederverbinden nachkommen, wenn die App lange nicht lief.
- Stand der Lizenzen aller Go-Abhängigkeiten (licenses.dev nennt für einen älteren Stand einzelne GPL-3.0-Einträge;
  AGPL-3.0 sollte damit vereinbar sein, ist aber zu prüfen).

## 4. Gate G0: Rechtliche Freigabe

**Vor jeder Zeile WhatsApp-Code und vor jedem Test gegen echte WhatsApp-Server.** Durch eine Rechtsberatung zu klären, durch
den Herausgeber zu entscheiden:

1. Haftung des Herausgebers beim Verbreiten eines Clients, der die Bedingungen voraussichtlich verletzt (mögliches
   Vorgehen von Meta, Verleitung zum Vertragsbruch).
2. Reichweite von Art. 7 DMA und Software-Richtlinie (Interoperabilität) als Argument. Hier wird bewusst nichts behauptet.
   Dazu gehört, dass die Bibliothek sich technisch als Web-Client meldet (Abschnitt 3.4).
3. Markenrecht: Der Name „WhatsApp“ darf nur beschreibend erscheinen, kein Logo, Hinweis auf fehlende Verbindung zu WhatsApp.
4. Verhältnis zur laufenden Apple-Prüfung: Der Herausgeber sollte vermeiden, dass zeitgleiche `-wa`-Pakete die
   Store-Einreichung gefährden.
5. Datenschutzrolle, wenn Rufnummern Dritter verarbeitet werden (Abschnitt 14).

**Ohne positive Entscheidung kein Weg C.**

## 5. Verbindliche Grundsätze

| # | Grundsatz |
|---|---|
| W1 | **Aus, bis ausdrücklich eingeschaltet:** Erst nach Warnung zum Kontorisiko und Kopplung durch die Person selbst. |
| W2 | **Getrennte Ausgaben:** Store-Builds und die bisherigen Download-Dateien enthalten weder Go-Bibliothek noch WhatsApp-Oberfläche. WhatsApp gibt es nur in zusätzlichen `-wa`-Paketen. Ein Prüfskript belegt das. |
| W3 | **Keine Brücke:** WhatsApp-Daten gelangen nie nach Matrix, Matrix-Daten nie nach WhatsApp. Kein automatisches Weiterleiten, keine Spiegelung, keine Synchronisierung über den privaten Raum. |
| W4 | **Familie unberührt:** Alle Invarianten I1–I8 aus `docs/KONTAKTE.md` gelten. WhatsApp-Gespräche liegen im Bereich „Kontakte“. |
| W5 | **Keine Umgehung:** Die App fügt keine Tarnung hinzu. Sie bleibt beim Standardverhalten der Bibliothek, nennt sich am Telefon `FamilyNexus`, ruft `SetWAVersion` nicht auf, ahmt kein Nutzerverhalten nach, verteilt Versand nicht zeitlich, um Erkennung zu vermeiden, fälscht keine Gerätenamen und umgeht weder Sperren, Warnungen, Versionsprüfungen noch Ratenbegrenzungen. Dass die Bibliothek sich technisch als Web-Client meldet, ist offenzulegen (Abschnitt 3.4). Bei Sperre oder Ablehnung stoppt die App und erklärt es. |
| W6 | **Kein Massenbetrieb:** Keine Automatisierung, kein Massenversand, keine Prüfung ganzer Rufnummernlisten. Jede Aktion geht von einem Tipp der Person aus. |
| W7 | **Ehrliche Aussagen:** Die App behauptet nur, was gilt (Abschnitt 8.3). |
| W8 | **Regeln der Gegenseite gelten:** Verschwindende Nachrichten, Einmal-Ansicht, Löschen für alle und Datenschutz-Einstellungen werden eingehalten. |
| W9 | **Daten sparsam:** Online-Status nur Arbeitsspeicher, keine Beobachtung im Hintergrund, keine Verlaufsdaten zu Anwesenheit. |

## 6. Architektur

```
┌─ Flutter ───────────────────────────────────────────────────────────────┐
│ features/chat, features/contacts  ──▶  ChatHub (ChatBackend je Präfix)  │
│        │                                  │                 │           │
│        │                       MatrixGateway        WhatsAppGateway     │
│        │                       (unverändert)       (nur `-wa`-Pakete)   │
│ data/db  familynexus_app.db               │                 │  dart:ffi │
│          familynexus_matrix.db            │        SqlWhatsAppStore     │
│          familynexus_wa.db  ◀─────────────┼─────────────────┤           │
└───────────────────────────────────────────┼─────────────────┼───────────┘
                                 Matrix-Homeserver   libfn_whatsapp (Go, whatsmeow)
                                                      familynexus_wa_keys.db
                                                            │  Noise, Signal
                                                      WhatsApp-Server (Meta)
```

### 6.1 Bestandteile

```
native/fn_whatsapp/                 Go-Modul, schmale C-Schnittstelle über whatsmeow, nur `-wa`-Pakete
lib/domain/whatsapp.dart            WaPeer, WaMessage, WaLink, WaPresence, WaStatusPost, Regeln, Grenzen
lib/domain/chat_backend.dart        ChatBackend (siehe 6.2), ThreadKind + whatsapp
lib/data/whatsapp/                  WhatsAppGateway (Schnittstelle), FfiWhatsAppGateway, Stub für Store-Builds,
                                    WaMapper (nicht vertrauenswürdig: bereinigt, prüft wie ChatMapper),
                                    SqlWhatsAppStore, WaSync
lib/app/chat_hub.dart               Vermittelt zwischen ChatScreen und den Backends
lib/features/whatsapp/              Kopplung, Warnseite, Verwaltung, Status-Ansicht, Trennen
test/support/fake_whatsapp.dart     Vollständiger Ersatz für Tests ohne Netz
tool/check_no_whatsapp.sh           Nachweis für W2
```

Der Architekturtest wird erweitert: `dart:ffi` zu whatsmeow nur in `lib/data/whatsapp/`; keine Datei unter `lib/data/matrix/`
oder `lib/data/sync/` importiert `data/whatsapp`; `features` nur über Schnittstellen.

### 6.2 Trennung im Chat

`ChatScreen` ruft heute rund zehn Methoden direkt auf `MatrixGateway` auf. Diese wandern in eine Schnittstelle:

```dart
abstract class ChatBackend {
  List<ChatThread> get threads;
  List<ChatMessage> messagesIn(String threadId);
  int unreadIn(String threadId);
  Future<void> sendMessage(String text, {String? replyToId, required String threadId});
  Future<void> sendReaction(String messageId, String emoji, {required String threadId});
  Future<void> sendAttachment({required String fileName, required Uint8List bytes, String? replyToId, required String threadId});
  Future<Uint8List> loadAttachment(String messageId, {required String threadId});
  Future<void> retryMessage(String messageId, {required String threadId});
  Future<void> markChatRead({required String threadId});
  Future<void> loadOlderMessages({required String threadId});
}
```

- `ChatHub` leitet nach Kennung: `wa:<jid>` geht an WhatsApp, alles andere an Matrix.
- `threadId` kann bei `SdkMatrixGateway` nie mit `wa:` beginnen, `_roomForThread` lehnt es ab. Ein Test belegt beide
  Richtungen (W3).
- `MatrixGateway` erfüllt `ChatBackend`, seine Sicherheitsprüfungen bleiben, wo sie sind. Familienfunktionen werden nicht
  über den Hub geführt und behalten ihre Standardwerte (`ChatThread.familyId`).
- Weg A ließe sich als weiterer `ChatBackend` hinter derselben Oberfläche ergänzen: Kennung `wai:<id>`, `InteropGateway` mit Rust-Kern
  (libsignal) statt Go, zusätzlich ein Dienst `fn-interop` (`docs/WHATSAPP_KONTAKTE_OPT-A.md` Abschnitte 7 und 8).

### 6.3 Go-Kern

- `c-shared`-Bibliothek `libfn_whatsapp` (Android je ABI, Linux, Windows, macOS) mit wenigen Funktionen, Details in
  `docs/WHATSAPP_KONTAKTE_OPT-C.md` 4.2: `fn_wa_open`, `fn_wa_call`, `fn_wa_put_bytes`, `fn_wa_ack`, `fn_wa_free`, `fn_wa_close`.
- Ereignisse gehen über den von Dart übergebenen `NativeApi.postCObject` an einen `ReceivePort`; Format JSON mit Versionsfeld. Der
  Kern enthält keine Logik für Oberfläche, Regeln oder Nachrichtenablage und ist damit klein und austauschbar.
- Bestätigung an WhatsApp erst nach Speicherung in Dart (`SynchronousAck`, `fn_wa_ack`), damit keine Nachricht verloren geht.
- Protokollierung von whatsmeow ist abgeschaltet. Fehler liefern nur Codes, nie Inhalte, Rufnummern oder JIDs.
- Geräteschlüssel in `familynexus_wa_keys.db` (`whatsmeow/store/sqlstore`) mit SQLCipher. Vorschlag: `mattn/go-sqlite3` gegen SQLCipher
  linken, Entscheidung in C0; ohne verschlüsselte Ablage kein Weg C.
- Netzverkehr geht am `HttpsOnlyClient` und an der Network-Security-Config vorbei, weil Go seinen eigenen Stack nutzt.
  Der Kern erlaubt deshalb nur verschlüsselte Verbindungen und keine benutzerdefinierten Ziele. Einen Proxy aus der Umgebung
  (`https_proxy`) übernimmt er nicht.

### 6.4 Schnittstelle zur Oberfläche

```dart
abstract class WhatsAppGateway implements ChatBackend, Listenable {
  WaLinkState get link;                                  // aus, koppelnd, verbunden, getrennt, gesperrt, veraltet
  Stream<String> startQrPairing();                       // laufend neue QR-Inhalte, einziger Kopplungsweg
  Future<void> connect();  Future<void> disconnect();    // an den App-Lebenszyklus gebunden
  Future<void> unlink();                                 // Logout und vollständige Löschung, Abschnitt 11
  List<WaPeer> get peers;
  Future<bool> setSaved(String jid, bool saved);         // „in Kontakte aufnehmen“
  Future<WaPeer?> lookupNumber(String phoneNumber);      // nur einzeln, nach Tipp (W6)
  Future<void> watchPresence(String jid, {required bool active});
  WaPresence? presenceOf(String jid);                    // nur Arbeitsspeicher
  List<WaStatusPost> get statusPosts;
  Future<Uint8List> loadStatusMedia(String id);
  Future<void> setBlocked(String jid, bool blocked);
  Future<String> securityCode(String jid);
}
```

## 7. Abläufe

### 7.1 Einschalten und Koppeln
1. Kontakte → **WhatsApp verbinden**. Warnseite mit den Punkten aus 8.3 und 12: inoffiziell, Konto kann gesperrt werden, Meta
   sieht Metadaten, nicht von WhatsApp. Pflichtbestätigung, keine vorbelegten Häkchen.
2. QR-Code zeigen. Das Scannen übernimmt das Telefon mit WhatsApp, die App braucht keinen Scanner (E-34). Auf Android weist die App
   darauf hin, dass das ein anderes Gerät sein muss. Eine Kopplung per Code gibt es nicht (Abschnitt 3.4).
3. Verlangt das Konto einen Passkey (`PairPasskeyRequest`), bricht die App mit Erklärung ab. Das ist in der ersten Stufe nicht vorgesehen.
4. Das Gerät erscheint in WhatsApp unter „Gekoppelte Geräte“ mit dem Namen aus `SetOSInfo` (`FamilyNexus`). Die Anzeige prüft C0 (W5).
5. Abfrage, ob der Verlauf übernommen wird (7.5). Standard: nein.

Jedes FamilyNexus-Gerät koppelt sich einzeln und belegt einen der vier Plätze für gekoppelte Geräte. WhatsApp selbst gleicht ab,
Matrix bleibt außen vor (W3).

### 7.2 Chat
Der Chat-Tab bekommt keinen neuen Bereich; WhatsApp-Gespräche stehen im Umschalter **Kontakte** aus V1.4 mit Text „WhatsApp“
und eigenem Symbol (kein WhatsApp-Logo).

| Funktion | Verhalten |
|---|---|
| Text, Antworten, Reaktionen | Wie Matrix-Chat |
| Bearbeiten und Löschen durch die Gegenseite | Wird übernommen |
| Anhänge | E-19 und E-28: 25 MB, kein automatisches Laden. Audio und Video nur für WhatsApp über `WaAttachmentPolicy`; Wiedergabe zunächst nicht in der App, keine Aufnahme |
| Verschwindende Nachrichten | Frist wird lokal eingehalten und gelöscht (W8) |
| Einmal-Ansicht | Nicht anzeigen, Hinweis „Im Telefon öffnen“ (W8) |
| Lesebestätigungen | Standard aus, Schalter in den Einstellungen |
| Eingabe-Anzeige | Wird nicht gesendet |
| Gruppen | Vorhandene Gruppen lesen und schreiben, keine Verwaltung |
| Melden | Nicht verfügbar, Hinweis auf die WhatsApp-App |
| Blockieren | Lokal wie E-48; ob zusätzlich die WhatsApp-Sperrliste, entscheidet die Person |
| Benachrichtigungen | Wie E-16 keine; ohne laufende App bleibt das Telefon die Quelle |

Der Entwurf je Gespräch (B4 in `docs/KONTAKTE.md`) ist Voraussetzung.

### 7.3 Kontakte
- Die Liste der WhatsApp-Kontakte stammt aus dem App-Zustand, den WhatsApp dem gekoppelten Gerät liefert. Das Adressbuch des
  Geräts wird nie gelesen.
- **Aufnehmen** setzt `saved` im lokalen Datensatz. Der Kontakt erscheint dann in der Kontaktliste unter „WhatsApp“ mit
  Name und Quelle, die Übrigen bleiben unter „Alle WhatsApp-Kontakte“.
- Neuer Kontakt über Nummer: einzeln, nach Tipp, mit `lookupNumber`. Die Rufnummer geht dabei an WhatsApp.
- Kein automatisches Zusammenführen mit Matrix-Kontakten oder Familienmitgliedern, auch nicht bei gleichem Namen.
- Kontakte werden nicht über den privaten Raum synchronisiert (W3). Das ist ein bewusster Unterschied zu V1.4: Rufnummern
  Dritter sollen nicht als Matrix-Ereignis existieren. Jedes Gerät hat die Liste ohnehin von WhatsApp.

### 7.4 Status
**Online-Status.** Laut whatsmeow verlangen die WhatsApp-Server, selbst als online zu gelten, um Status anderer zu bekommen.
Wer den Status anderer sehen will, erscheint also selbst als online. Daraus folgt:
- Schalter „Online-Status in WhatsApp-Chats zeigen“, Standard **aus**, mit genau diesem Hinweis.
- Nach dem Verbinden meldet die App `unavailable`. Erst beim Öffnen eines Gesprächs mit aktivem Schalter sendet sie `available` und
  abonniert den Status; beim Verlassen und im Hintergrund sendet sie wieder `unavailable` (W9).
- Ohne Datenschutz-Token kein Abruf (`ErrorOnSubscribePresenceWithoutToken`), Anzeige „Status unbekannt“.
- Keine Speicherung (Regel wie E-38), kein „zuletzt online“-Verlauf, keine Sammelanzeige in der Kontaktliste.
- Kommt nichts an, etwa weil die Person ihren Status verbirgt, zeigt die App „Status unbekannt“, nie „Offline“.
- Solange die App `unavailable` meldet, gehen Empfangsbestätigungen als `inactive` hinaus. Der Absender sieht dann womöglich keine
  zwei grauen Haken. Das ist gewollt.

**Status-Meldungen.** Ansicht „Status“ im WhatsApp-Bereich. Meldungen anderer als aufgenommener Kontakte werden schon beim Eingang
verworfen. Medien nur auf Tipp laden. Die App ruft für Status nie `MarkRead` auf, damit die Ansicht in FamilyNexus nichts preisgibt;
den Beleg am Testkonto liefert C0. Löschung nach 24 Stunden, auch ohne Ereignis der Gegenseite.

**Info-Text.** Im Kontaktprofil, abgerufen beim Öffnen, nur für aufgenommene Kontakte. Profilbilder nur auf Tipp.

### 7.5 Verlauf
Nur auf Wunsch über `DownloadHistorySync` (`ManualHistorySyncDownload`): höchstens die letzten 90 Tage, alle Inhalte nur in
`familynexus_wa.db`, Medien erst auf Tipp. Mit Fortschritt und Abbruch.

### 7.6 Verbindung
Verbunden nur, solange die App im Vordergrund läuft (Mobil, Trennung 30 s nach dem Wechsel in den Hintergrund) oder geöffnet ist
(Desktop); kein Hintergrunddienst, passend zu E-16. Laut mautrix-Doku trennt WhatsApp gekoppelte Geräte, wenn das Telefon länger als zwei Wochen offline ist. Die App
warnt nach zwölf Tagen ohne Verbindung.

## 8. Ende-zu-Ende-Verschlüsselung

### 8.1 Was geschützt ist
Nachrichten und Medien sind per Signal-Protokoll zwischen dem FamilyNexus-Gerät und den Geräten der Gegenseite
verschlüsselt. Sitzungsschlüssel entstehen und bleiben auf dem Gerät. Weder Herausgeber noch Matrix-Server sehen etwas.
Die Transportverschlüsselung (Noise) liegt darunter.

Die Umsetzung stammt aus `go.mau.fi/libsignal`, nicht von Signal oder WhatsApp. Ein unabhängiges Audit ist nicht bekannt, C0 sucht
danach. Ohne Audit darf die App „verschlüsselt“ sagen, aber nicht mehr behaupten.

### 8.2 Ablage und Prüfung
- Beide Datenbanken verschlüsselt mit SQLCipher. Ein eigener Zufallsschlüssel `db.whatsapp` im Plattform-Schlüsselspeicher,
  Übergabe nur im Arbeitsspeicher (Muster E-05).
- Keine Sicherung: Android `allowBackup=false` gilt weiter. Dateien liegen im App-Bereich ohne Cloud-Sicherung.
- `events.IdentityChange`: Warnung im Gespräch „Der Sicherheitscode hat sich geändert“. Gesendet wird weiter wie in WhatsApp
  selbst, die Warnung ist aber nicht ausblendbar.
- Sicherheitscode je Kontakt anzeigen, damit er mit der offiziellen App verglichen werden kann. Ob sich der Code aus der
  Bibliothek mit gleichem Ergebnis berechnen lässt, klärt C0. Ohne Übereinstimmung wird die Anzeige nicht angeboten.

### 8.3 Pflichtaussagen (W7)
| Die App sagt | Die App sagt nicht |
|---|---|
| „Nachrichten sind zwischen diesem Gerät und den Geräten deines Kontakts verschlüsselt.“ | „So sicher wie die Familie“ |
| „WhatsApp (Meta) sieht, wer wann mit wem schreibt, und deine Rufnummer.“ | „Kein Dritter ist beteiligt“ |
| „Diese Verbindung ist nicht von WhatsApp freigegeben. Dein Konto kann gesperrt werden.“ | „Sicher“, „Offiziell“, „Unterstützt“ |
| „Auf diesem Gerät liegen diese Chats in einer eigenen verschlüsselten Datenbank.“ | Das Schloss-Symbol der Familie |

**Schutzniveau:** Inhalte sind E2EE wie in WhatsApp, die Metadaten liegen bei Meta. Das ist ein geringeres Schutzniveau als
die Familienfunktionen und wird in der Oberfläche nie gleichgestellt.

## 9. Fehler- und Sonderfälle

| Ereignis | Verhalten |
|---|---|
| `LoggedOut` | Status „getrennt“, keine neuen Daten, neu koppeln möglich, lokale Chats bleiben bis zur Löschung |
| `TemporaryBan`, Verbindungsfehler 402 | **Sofort stoppen, kein Neuversuch**, Zeitpunkt nennen falls bekannt, Empfehlung zur Prüfung am Telefon (W5). Die Texte geben keine Hinweise zum Vermeiden oder Umgehen |
| Verbindungsfehler 406 (`UnknownLogout`), 403 (`MainDeviceGone`) | Stopp, kein Neuversuch, „Möglicherweise gesperrt, in WhatsApp prüfen“ bzw. Hauptgerät prüfen |
| `NotifyAccountReachoutTimelock` | Warnung, Senden aus |
| `ClientOutdated` (405), `BadUserAgent` (409) | Stoppen, Hinweis auf App-Update. Keine eigenen Versionsangaben (W5) |
| `StreamReplaced` | Nicht wieder verbinden, Hinweis „Verbindung wurde an anderer Stelle übernommen“ |
| Warnung „Account may be at risk“ am Telefon | Die App sieht sie womöglich nicht; die Warnseite erklärt: sofort trennen |
| Telefon lange offline | Warnung ab Tag 12, nach Trennung Neukopplung |
| Netzfehler | Begrenzter Rückoff, Ausstehende bleiben mit „Erneut senden“ |
| Bibliothek lädt nicht | WhatsApp-Bereich ausgeblendet, Familie und Kontakte laufen unverändert |

Nach einem Stopp sendet die App nichts mehr, bis die Person ausdrücklich neu verbindet. Ein Fehler in WhatsApp darf den Start, die
Familie und den Chat nie blockieren (Muster aus `_syncDirectChats`). Vollständige Tabelle: `docs/WHATSAPP_KONTAKTE_OPT-C.md` Abschnitt 10.

## 10. Familie und Minderjährige

| Funktion | Auswirkung |
|---|---|
| Termine, Einkauf, Aufgaben, Online-Status der Familie | Keine. Kein Teilen nach WhatsApp, keine Anzeige von WhatsApp-Daten dort |
| „Heute“, Familienansicht | Keine WhatsApp-Inhalte; `familyUnreadCount` zählt sie nicht |
| Chat-Abzeichen | Summe über sichtbare Gespräche; WhatsApp zählt im Bereich Kontakte |
| Familienmitglied mit WhatsApp | Bleibt getrennt; wird nicht verknüpft (W3) |

**Moderatoren-Sperre:** `member_policy` aus `docs/KONTAKTE.md` Abschnitt 9.4 erhält das Feld `whatsapp`; ein gesperrter
Bereich schließt WhatsApp ein. Grenze wie dort: nur die App setzt das durch. In Konten mit gesetzter Sperre trennt die App
die WhatsApp-Kopplung und löscht die lokalen Daten erst nach Bestätigung der Person.

## 11. Datenhaltung und Löschung

| Daten | Ort | Löschung |
|---|---|---|
| Signal-Schlüssel, Gerätekennung | `familynexus_wa_keys.db` | Trennen, Abmelden, „Alle lokalen Daten löschen“ |
| Nachrichten, Kontakte, Status-Meldungen | `familynexus_wa.db` | ebenso; Status nach 24 h, Verschwindende nach Frist |
| Online-Status | Arbeitsspeicher | Beim Verlassen oder Beenden |
| Medien | Verschlüsselter Zwischenspeicher, bewusstes Speichern wie SA-3 | ebenso |

- **Trennen** ruft `Logout` auf, löscht beide Dateien samt Schlüssel `db.whatsapp`. Klappt der Logout offline nicht, wird lokal
  dennoch gelöscht und angezeigt, dass das Gerät am Telefon zu entfernen ist.
- Abmelden aus Matrix trennt WhatsApp mit. Das ist ein **eigener Schritt** in `logout`, `onFullReset`, `bootstrap.dart` und vor
  `deleteAccount`, nicht Teil von `wipeAccountDataIn`: Diese Funktion endet früh, wenn `calendarOwner` fehlt.
- Eine eigene Migration der App-Datenbank ist nicht nötig. Store-Builds bleiben schemagleich.
- `data_report`: eigener Abschnitt „WhatsApp“ mit Anzahl und Art, ohne Rufnummern.
- `AppLog` redigiert zusätzlich Rufnummern und JIDs (`@s.whatsapp.net`, `@g.us`, `@lid`). JIDs gelten als undurchsichtige
  Kennung, weil WhatsApp neben Rufnummern auch `@lid` verwendet.

## 12. Sicherheit

| Risiko | Gegenmaßnahme | Restrisiko |
|---|---|---|
| Kontosperre, Warnung | Warnung, W5, W6, kein Automatismus, sofortiger Stopp | **Bleibt**, nach Berichten auch bei normaler Nutzung und nach dem Trennen. Kann das wichtigste Konto einer Person treffen |
| Protokolländerung | Beobachten, Release-Bereitschaft, sauberer Ausfall (Abschnitt 9) | Funktion fällt ohne Vorwarnung aus |
| Lieferkette whatsmeow | Festes Commit, `go.sum`, Durchsicht jeder Aktualisierung, SBOM | Nur Commit-Versionen, schnelle Updates kollidieren mit Prüfung |
| Go-Bibliothek im selben Prozess | Kleine Schnittstelle, W2, Pen-Test | Eine Lücke dort erreicht auch die Matrix-Schlüssel im Speicher (SA-12). Eigener Prozess als spätere Stufe |
| Schadinhalte aus WhatsApp | `WaMapper` wie `ChatMapper`, E-19/E-28, kein Link-Vorschau, kein automatisches Laden | Lücke im Bilddecoder nach Tipp |
| Identitätstäuschung | Quelle immer sichtbar, Warnung bei Namensgleichheit mit Mitglied | – |
| Rufnummern im Log, Absturzberichte | `AppLog`, kein Logging im Kern, Test | – |
| Fremde Daten im Klartext auf dem Desktop | SQLCipher, SA-3 unverändert | SA-6 und SA-10 gelten mit |
| Nutzer verwechselt Bereiche | Getrennte Kennzeichnung, Entwürfe je Gespräch | Bewusstes Kopieren |

**SA-12 (vorgeschlagen):** Die `-wa`-Pakete enthalten eine inoffizielle Implementierung eines fremden Protokolls, deren
Nachrichten an Meta gehen und die sich technisch als Web-Client meldet. Sie verlässt das Versprechen „nur Matrix-Server“
(`docs/STORE.md`) für alle, die sie einschalten, und läuft im selben Prozess wie die Familienkryptografie.

## 13. Build und Verteilung

**Die bisherigen Assets bleiben unverändert.** WhatsApp kommt nur in zusätzliche `-wa`-Pakete, damit niemand es versehentlich bekommt.

| Ausgabe | Plattform | WhatsApp |
|---|---|---|
| App Store, Google Play | iOS, iPadOS, macOS, Android | ✘ |
| Alle bisherigen Download-Dateien | alle | ✘ |
| GitHub Pages | Web | ✘ (kein Weg für Go-Kern und Sitzungen vorgesehen) |
| `FamilyNexus-v<V>-wa.apk` | Android (nur als Zweitgerät, Abschnitt 3.4) | ✔ |
| `FamilyNexus-v<V>-wa.dmg` (E-62) | macOS | ✔ |
| `FamilyNexus-v<V>-wa-x86_64.AppImage`, `…-wa.flatpak` | Linux | ✔ |
| `FamilyNexus-v<V>-wa-windows.zip` | Windows | ✔ |

- Schalter `--dart-define=FN_WHATSAPP=true` plus getrennte Paketierung; alle anderen Builds nutzen den Stub und enthalten keine
  Bibliothek. Keine Dart-Abhängigkeit in `pubspec.yaml`, die Bibliothek wird per `DynamicLibrary.open` geladen. Android: Produkt-Flavors
  `standard` und `wa`, nur dort `libfn_whatsapp.so`.
- `tool/check_no_whatsapp.sh` durchsucht jedes Nicht-`wa`-Artefakt nach `whatsmeow`, `libfn_whatsapp`, `whatsapp` und läuft im
  Release-Workflow als Pflichtschritt. Texte für WhatsApp liegen in einer eigenen ARB-Datei, die nur die `-wa`-Pakete einbinden.
- `.github/workflows/release.yml`: Go-Toolchain mit fester Version, cgo je Plattform, Android-NDK, eigene `-wa`-Jobs. Android braucht
  `-Wl,-z,max-page-size=16384`; Windows mit MinGW und SQLCipher ist der schwierigste Fall. `tool/check_apk_abis.sh` und `tool/sbom.py`
  erweitern; `docs/ABHAENGIGKEITEN.md` bekommt einen Go-Abschnitt.
- Regelbetrieb: whatsmeow-Änderungen wöchentlich sichten, Commit anheben. `SetWAVersion` wird auch als Notlösung nicht genutzt.
- Keine automatische Aktualisierung vorhanden: Die App prüft nicht selbst und meldet Updates nur über `ClientOutdated`.
- AGPL: Der vollständige Quellcode inklusive `native/fn_whatsapp` bleibt öffentlich. Das Repo enthält dadurch WhatsApp-Code
  auch für Store-Nutzer sichtbar; G0 prüft, ob ein getrenntes Repo nötig ist. Das ist für Apple relevant (Punkt 4 in G0).

## 14. Dokumente, Datenschutz, Store

| Datei | Änderung |
|---|---|
| `store/privacy/privacy-policy.{de,en}.md` | Eigener Abschnitt nur für die `-wa`-Pakete: Meta als eigenständiger Empfänger, Rufnummer, Daten Dritter, Ablage. Für alle anderen Ausgaben unverändert. Aufbau trennen, damit keine Ausgabe Falsches sagt |
| `docs/STORE.md` | Festhalten, dass Store-Ausgaben kein WhatsApp enthalten; Apple 5.2.2 verlangt die Erlaubnis des Drittdienstes, 5.2.1 die Rechte an Marken |
| `docs/export-compliance/` | `-wa`-Pakete: zusätzliche Kryptografie (Signal-Protokoll, Noise) beschreiben |
| `Concept.md`, `docs/ARCHITEKTUR.md`, `docs/ENTSCHEIDUNGEN.md`, `docs/OFFEN.md`, `README.md` | E-76, SA-12, zwei Ausgaben, Grenzen. Grundsatz „Kein Klartext verlässt das Gerät“ bleibt gültig, „nur Matrix“ nicht mehr für die `-wa`-Pakete |
| `docs/KONTAKTE.md` | Hinweis auf Bridges und fehlende Erkennbarkeit, `member_policy` um `whatsapp` ergänzen |

## 15. Tests

| Ebene | Inhalt |
|---|---|
| Domäne, Mapper | Regeln, Fristen, Bereinigung, JID-Behandlung; Fehlformate aus dem Kern |
| Daten | `SqlWhatsAppStore` (Verschlüsselung, falscher Schlüssel), Löschpfade, `AppLog` |
| Widget (`FakeWhatsAppGateway`) | Warnseite ist Pflicht, Kopplung, Bereich Kontakte, Verschwindende, Sperre, Veraltet, Status-Hinweis, Entwürfe |
| Isolation | Kein Weg von Matrix zu WhatsApp oder zurück: Kennungen, Importregeln, keine WhatsApp-Daten im privaten Raum, keine Änderung an Kalender, Einkauf, Aufgaben |
| Artefakte | `check_no_whatsapp.sh` gegen jedes Nicht-`wa`-Artefakt; Stub-Build zeigt keine WhatsApp-Oberfläche; ABI- und 16-KB-Prüfung |
| Go-Kern | `go test` mit whatsmeow-Testdaten ohne Netz; Prüfung der C-Schnittstelle; Absturzsicherheit |
| Pen-Test | Fehlerhafte Ereignisse über die FFI-Grenze, übergroße Medien, Rufnummern in Fehlern, Trennen bei laufendem Abgleich |
| Manuell (Testplan) | **Nur mit eigenen Testkonten und ausdrücklicher Zustimmung des Inhabers, nie mit einer Hauptnummer.** Jeder Lauf ist ein Zugriff auf einen fremden Dienst und kann die Nummer sperren. Automatische Tests gegen echte WhatsApp-Server gibt es nicht |

Gate-Regeln aus `docs/PLAN.md` gelten je Phase.

## 16. Umsetzung in Phasen

| Phase | Inhalt | Umfang | Abnahme |
|---|---|---|---|
| **G0** | Rechtliche Freigabe, Entscheidungen aus Abschnitt 18 | – | Schriftliche Entscheidung des Herausgebers |
| **V1.4** | K1–K3 aus `docs/KONTAKTE.md`: Bereich Kontakte, Entwürfe je Gespräch, Kennzeichnung | siehe dort | Voraussetzung |
| **C0** | Vorprüfung mit Testkonto: offene Punkte aus 3.4, SQLCipher auf Android und Linux, Anzeigename, Sicherheitscode, Gelesen-Meldungen, Audit-Suche, Lizenzen | M | Bericht; Abbruch, wenn die Ablage nicht verschlüsselbar oder die Lizenz unvereinbar ist |
| **C1** | `ChatBackend`, `ChatHub`, Stub, Architekturtest, Flavors, `-wa`-Jobs, `check_no_whatsapp.sh` | M | Keine Änderung im Verhalten, alle Bestandstests grün |
| **C2** | Go-Kern, FFI, Ablage, QR-Kopplung, Warnseite, Trennen und Löschen, Fehlerfälle | L | Koppeln und Trennen auf Android und Linux |
| **C3** | Einzelchats, Anhänge, Antworten, Reaktionen, verschwindende Nachrichten, LID, Gesprächsliste | L | Abnahme 4–7 |
| **C4** | Kontakte, Verlauf, Gruppen, Blockieren | M | Abnahme 12 |
| **C5** | Status-Meldungen, Info-Text, Online-Status | M | Abnahme 8–9 |
| **C6** | Windows, Doku, Datenschutz, Export, Pen-Test, Review durch separaten Agenten, `-wa`-Pakete auf allen Plattformen | M | Abnahme 1–3, 10–11 |

Dazu kommt **dauerhafter Aufwand:** Protokolländerungen von WhatsApp können jederzeit kurzfristige Releases erzwingen. Ist
diese Bereitschaft nicht leistbar, sollte Weg C nicht gestartet werden.

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
10. Jede Stopp-Bedingung aus Abschnitt 9 beendet das Senden ohne Neuversuch; Familie und Kontakte laufen weiter.
11. Trennen und alle Löschwege entfernen Dateien und Schlüssel, auch offline und ohne `calendarOwner`.
12. Keine WhatsApp-Daten in Matrix (Test), keine Rufnummern oder JIDs im Log.

## 17. Quellen

Abgerufen am 2026-10-31.

- WhatsApp-Bedingungen EWR (gültig ab 17.08.2026): https://www.whatsapp.com/legal/terms-of-service-eea
- Meta, Drittanbieter-Chats in Europa (11/2025): https://about.fb.com/news/2025/11/messaging-interoperability-whatsapp-enables-third-party-chats-for-users-in-europe/
- Meta Engineering, Interoperabilität (03/2024): https://engineering.fb.com/2024/03/06/security/whatsapp-messenger-messaging-interoperability-eu/
- EU-Kommission, Messaging-Interoperabilität: https://digital-markets-act.ec.europa.eu/messaging-interoperability_en
- BEREC, Stellungnahme zum Referenzangebot: https://www.berec.europa.eu/en/document-categories/berec/opinions/berec-opinion-on-metas-reference-offer-published-in-march-2024-to-facilitate-whatsapp-interoperability-under-article-7-of-the-digital-markets-act
- Matrix.org zum Referenzangebot (09/2024): https://matrix.org/blog/2024/09/whatsapp-dma/
- Element zum DMA: https://element.io/blog/the-eu-digital-markets-act-is-here
- BEREC, Stellungnahme 03/2025: https://www.berec.europa.eu/system/files/2025-03/BoR%20(25)%2021%20BEREC%20Opinion%20on%20Meta's%20reference%20offers.pdf
- Weitere Quellen zu Weg A: `docs/WHATSAPP_KONTAKTE_OPT-A.md` Abschnitt 21
- mautrix-whatsapp, Funktionsstand: https://raw.githubusercontent.com/mautrix/whatsapp/main/ROADMAP.md
- mautrix, Anmeldung: https://docs.mau.fi/bridges/go/whatsapp/authentication.html
- mautrix, End-to-Bridge-Verschlüsselung: https://docs.mau.fi/bridges/general/end-to-bridge-encryption.html
- whatsmeow, API und Lizenz: https://pkg.go.dev/go.mau.fi/whatsmeow
- whatsmeow, Presence und Ereignisse: https://github.com/tulir/whatsmeow/blob/main/presence.go, https://github.com/tulir/whatsmeow/blob/main/types/events/events.go
- whatsmeow, Kopplung und Clientangaben: https://raw.githubusercontent.com/tulir/whatsmeow/main/pair-code.go, https://raw.githubusercontent.com/tulir/whatsmeow/main/store/clientpayload.go
- whatsmeow, Issue #810 (Warnungen): https://github.com/tulir/whatsmeow/issues/810
- Weitere Quellen zu Weg C: `docs/WHATSAPP_KONTAKTE_OPT-C.md` Abschnitt 20
- whatsmeow, Lizenzen der Abhängigkeiten (älterer Stand): https://licenses.dev/go/go.mau.fi%2Fwhatsmeow/v0.0.0-20240603101645-64bc969fbe78
- Warnhinweise zu inoffiziellen Web-Clients: https://wabetainfo.com/whatsapp-is-testing-a-safety-warning-for-unofficial-web-clients/
- Apple App Review Guidelines (1.2, 5.2.1, 5.2.2): https://developer.apple.com/app-store/review/guidelines/

## 18. Entscheidungen zur Abstimmung

| Frage | Vorschlag | Betrifft |
|---|---|---|
| Weg A oder Weg C? | **Weg C**, erst nach G0 und als bewusstes Zusatzangebot für Desktop und Zweitgeräte. Sonst Verzicht | 1.1, 4 |
| Weg A prüfen? | **Nein.** Phase P0 nur, wenn der Status (A3) aufgegeben wird und die Betreiberrolle gewollt ist | 1.1, 3.2 |
| Weg A und Weg C zugleich? | **Nein**, um Vertrag und Partnerstatus nicht zu gefährden | 1.1 |
| Android auf dem Hauptgerät? | **Nicht unterstützen.** Code-Kopplung würde `Browser (OS)` vortäuschen (W5) | 3.4, 7.1 |
| Ist W5 trotz Web-Selbstauskunft der Bibliothek tragbar? | **In G0 prüfen** | 3.4, 5 |
| Reicht E2EE ohne Metadatenschutz? | **Ja, mit klarer Aussage** (8.3); die Anforderung A4 nennt nur Verschlüsselung | 8 |
| Eine App oder zwei Ausgaben? | **Zusätzliche `-wa`-Pakete**, Store und bisherige Downloads ohne WhatsApp | 13 |
| Ein Repo oder getrennt? | **Offen**, abhängig von G0 und Apple | 13 |
| Online-Status mit eigener Sichtbarkeit? | **Ja, aus als Standard** | 7.4 |
| Passkey-Kopplung | **Später** | 7.1 |
| Gruppen im ersten Release? | **Ja, nur vorhandene**; bei Zeitdruck als Erstes zu verschieben | 7.2, C4 |
| Eigener Prozess für den Go-Kern? | **Später**; Same-Process zunächst als SA-12 | 12 |
| Dauerhafte Pflege gesichert? | **Vom Herausgeber zu bestätigen**, sonst kein Start | 16 |
