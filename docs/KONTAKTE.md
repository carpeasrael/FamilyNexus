# Kontakte und Gruppen außerhalb der Familie (Release V1.4)

Stand: 2026-10-31 · Status: **Entwurf zur Abstimmung, nicht umgesetzt** · Basis: Version 1.2.1 (22) · Entscheidung: E-75
(vorgeschlagen) · Sicherheitsabweichung: SA-11 (vorgeschlagen) · ändert E-39, ergänzt E-11, E-41, E-47, E-48

## 1. Ziel und Abgrenzung

FamilyNexus erhält **Kontakte**: andere Matrix-Konten, die nicht zur Familie gehören. Mit Kontakten kann man direkt
chatten und **Chatgruppen** gründen. Die Familie bleibt davon unberührt.

| Bereich | Familie | Kontakte und Gruppen |
|---|---|---|
| Familienchat, Einzelchats mit Mitgliedern | ✔ wie bisher | – |
| Einzelchat, Gruppenchat, Antworten, Reaktionen, Anhänge | – | ✔ |
| Termine, Zusagen, Einkaufszettel, Aufgabenlisten | ✔ wie bisher | ✘ nicht sichtbar, nicht teilbar |
| Online-Status (E-38) | ✔ wie bisher | ✘ weder senden noch empfangen |
| Mitgliederliste, Rollen, Einladungen | ✔ wie bisher | ✘ Kontakte erfahren nichts über die Familie |

**Nicht in V1.4:** Suche im Benutzerverzeichnis, Telefonbuch-Abgleich, Sprach- und Videoanrufe, öffentliche Räume und
Räume mit Beitritt per Adresse, unverschlüsselte Räume, Übernahme vorhandener Matrix-Räume des Kontos, Push (E-16 gilt
weiter: neue Nachrichten erscheinen nur bei laufender App).

**Annahme:** Das Repo nennt für V1.3 keinen Inhalt. Dieses Konzept baut auf 1.2.1 auf und hängt nicht vom
Familienspeicher (E-74) ab.

## 2. Grundsätze

Für die Umsetzung sind diese Invarianten verbindlich. Jede wird durch mindestens einen Test belegt (Abschnitt 13).

| # | Invariante |
|---|---|
| I1 | **Update ändert nichts:** Ohne ausdrückliches Einschalten verhält sich die App wie 1.2.1; Einladungen Fremder bleiben unbeantwortet und unsichtbar. |
| I2 | **Positivliste:** Ein Raum erscheint nur als Gespräch, wenn er als Familienraum, Einzelchat mit Mitglied oder bestätigter Kontakt-/Gruppenraum eingestuft ist. Alles andere bleibt unsichtbar. |
| I3 | **Einbahnstraße der Daten:** Familiendaten werden nur in den Familienraum, den privaten Raum und an Geräte beigetretener Mitglieder gesendet. Kein Sendeweg für Familiendaten nimmt eine Gesprächskennung entgegen. |
| I4 | **Kein Rückkanal:** Aus Kontakt- und Gruppenräumen entstehen keine Signale für Kalender, Einkauf, Aufgaben oder Online-Status. Ereignisse dieser Typen dort werden verworfen. |
| I5 | **Immer verschlüsselt:** Jeder Raum ist Megolm-verschlüsselt, gesendet wird nur nach Prüfung (E-27). Unverschlüsselte Räume werden nie genutzt. |
| I6 | **Zustimmung:** Niemand landet ohne eigenen Tipp in einem Gespräch mit einem Fremden. Es gibt keine automatische Annahme von Unbekannten. |
| I7 | **Erkennbare Grenze:** Gespräche außerhalb der Familie sind immer als solche gekennzeichnet (Text und Form, nicht nur Farbe). Ein Entwurf gelangt nie in ein anderes Gespräch. |
| I8 | **Familie bleibt unsichtbar:** Kontakte sehen weder Familiennamen noch Mitglieder noch den Status einer Person als Familienmitglied. |

## 3. Was die heutige Implementierung dafür verlangt

Die Analyse des Codes ergab Stellen, die bei einem einfachen Öffnen der Einzelchats die Grundsätze verletzen würden. Sie
sind **Pflichtbestandteil** der Umsetzung.

| # | Stelle | Problem | Maßnahme |
|---|---|---|---|
| B1 | `SdkMatrixGateway.invitations` | Jede Einladung ohne `is_direct` gilt als Familieneinladung. Eine Gruppeneinladung würde einem Konto ohne Familie als „Du wurdest eingeladen“ gezeigt, `acceptInvitation` machte die Gruppe zur Familie. | Familieneinladungen an `join_rules: knock` erkennen (E-12), Abschnitt 6.3. Annahme in Gateway **und** Oberfläche trennen. |
| B2 | `_ensureClient` setzt kein `syncPresence` | `/sync` läuft ohne `set_presence`, der Server führt das Konto damit als online. Kontakte in gemeinsamen Räumen könnten diesen **Matrix-eigenen** Status sehen (je nach Server). E-38 verspricht aber: Status nur an die Familie. | `client.syncPresence = PresenceType.offline` setzen. Der Familienstatus läuft über Gerätenachrichten und ist nicht betroffen. |
| B3 | `ChatMapper._map` liest `event_ref` in jedem Raum | Ein Kontakt kann eine Terminkarte erzwingen: `_EventCard` zeigt zur ID den Familientermin samt Zusage-Knöpfen an, `RsvpButtons` senden in den Familienraum. | Mapper erhält `allowEventRefs`; außerhalb der Familie wird das Feld verworfen und `body` normal angezeigt. Pen-Test. |
| B4 | `ChatScreen._select` | `_ctrl` bleibt beim Gesprächswechsel gefüllt. Ein Familien-Entwurf könnte an einen Kontakt gehen, beim Rückfall auf den Familienchat (Zeile 219) ein Kontakt-Entwurf an die Familie. | Entwurf und Antwortbezug je Gespräch führen. Rückfall ohne Übernahme des Entwurfs. |
| B5 | `ShareKeysWith.crossVerified` | Raumschlüssel gehen nur an cross-signierte Geräte (`encryptToDevice`). Hat ein Kontakt kein Cross-Signing, kommen Nachrichten **stillschweigend nicht lesbar** an. | Einstellung bleibt (kein Aufweichen, sie gilt im ganzen Client). Stattdessen Erreichbarkeit prüfen und anzeigen, Abschnitt 8.3. |
| B6 | `_participantsLoaded` | Solange die Mitgliederliste nur teilweise geladen ist, sähe ein Mitglied wie ein Fremder aus; seine Einladung würde zur Kontaktanfrage. | Einstufung erst nach vollständiger Liste (wie `_syncDirectChats`). |
| B7 | `unreadCount`, Heute, Abzeichen | `unreadCount` summiert alle Gespräche, auch ausgeblendete. Ein blockierter Spammer hielte das Abzeichen aktiv; die Karte auf „Heute“ zählte Kontaktnachrichten mit. | Neu `familyUnreadCount` für „Heute“; das Chat-Abzeichen summiert über `visibleThreads`. |
| B8 | `_onIncomingVerification`, `acceptIdentityChange` | Beide lassen nur beigetretene Mitglieder zu. | Auf bestätigte Kontakte erweitern, sonst sind Kontakte nicht prüfbar und ein Identitätswechsel nicht auflösbar. Fremde bleiben abgelehnt. |
| B9 | `presence`, `PresenceStatusText`, `_ThreadBar` | Chatkopf und Leiste zeigen für jedes `peerId` einen Status. | Für Kontakte keinen Status anzeigen statt „Offline“ (sonst falsche Aussage). |
| B10 | `Client.ignoreUser` | Naheliegend für Blockieren, leert aber den gesamten Zwischenspeicher und filtert den Nutzer in **allen** Räumen. | Nicht verwenden. Blockieren bleibt lokal (E-48), Abschnitt 9.3. |
| B11 | `store/metadata/*/review_notes.txt`, Datenschutz, STORE.md | Sagen aus, dass Nachrichten nur an eingeladene Familienmitglieder gehen. Mit V1.4 unwahr. | Abschnitt 12. |

## 4. Begriffe und Zustände

- **Kontakt:** Datensatz in der App zu einer Matrix-ID außerhalb der Familie.
- **Kontaktanfrage:** Matrix-Einladung in einen verschlüsselten Zweier- oder Gruppenraum. Es gibt kein eigenes Protokoll;
  Kontakte können deshalb jeden Matrix-Client verwenden (Element, FluffyChat …).
- **Gesprächsbereich:** `Familie` (Familienchat, Einzelchats mit Mitgliedern) oder `Außerhalb` (Kontakte, Gruppen).

```
                 ich füge hinzu                  Gegenseite tritt bei
  (kein Kontakt) ───────────────▶  angefragt  ─────────────────────────▶  bestätigt
        │                              │ zurückziehen / abgelehnt             │  entfernen: Raum verlassen,
        │ Einladung eines Fremden      ▼                                      ▼  Datensatz gelöscht
        ├──────────▶ Anfrage ──annehmen──▶ bestätigt                     (kein Kontakt)
        │               │
        │               ├─ ablehnen: Raum verlassen, die Gegenseite sieht das
        │               └─ blockieren: bleibt unbeantwortet, Absender erfährt nichts
        └── Mitglied der Familie: immer Bereich Familie, nie Kontaktanfrage
```

**Vorrang der Familie:** Wird ein Kontakt Mitglied, wird sein Raum zum Einzelchat im Bereich Familie (derselbe Raum, kein
zweiter). Ein **entferntes** Mitglied bleibt wie heute ausgeblendet (E-39). Der Raum erscheint erst wieder, wenn man die
Person ausdrücklich als Kontakt hinzufügt und sie zustimmt.

## 5. Matrix-Modell

| Element | Umsetzung |
|---|---|
| Kontakt-Einzelchat | Privater Raum mit `is_direct`, Megolm, höchstens zwei Mitglieder. Anlage wie E-39 (`client.startDirectChat`, `skipExistingChat: true`, `enableEncryption: true`), Verlauf `shared`. Je Person höchstens ein Einzelchat, bei mehreren gilt die kleinste Raum-ID. |
| Gruppe | Privater Raum nach neuer `ContactGroupSpec`: Raumversion 10, `private_chat`, nicht im Verzeichnis, `join_rules: invite`, Megolm, Verlauf `invited`. Bis 50 Mitglieder. |
| Rechte in Gruppen | Wie `FamilyRoomSpec.powerLevels`: Ersteller 100, Schwellen 50 für `invite`, `kick`, `ban`, `redact`, Zustände; Tombstone und Server-ACL unerreichbar. In der App: **Gruppen-Admin** (ab 50) und Mitglied. |
| Kontaktliste | Datensätze im **privaten Raum** (E-09) als `de.inneso.familynexus.contact`, Megolm, nur eigene Geräte; lokal in SQLCipher. Nie im Familienraum. |
| Familie im Raum | Kontakträume tragen keinerlei Familienbezug (kein Name, keine Familien-ID, keine eigenen Ereignistypen). |
| Klartext-Metadaten | Gruppenname (`m.room.name`) ist wie der Familienname für Server lesbar. Die App sagt das beim Anlegen. |

`invited` als Verlauf: Neu Hinzugefügte sehen nichts aus der Zeit vor ihrer Einladung. Das SDK verteilt neue
Sitzungsschlüssel auch an Eingeladene (`Room.getUserDeviceKeys`, SA-2): Wer in eine Gruppe eingeladen ist, kann ab der
Einladung mitlesen. Deshalb weist der Dialog darauf hin (wie Abschnitt „Einladungen“ der Datenschutzerklärung).

### 5.1 Ereignisformat

```jsonc
// de.inneso.familynexus.contact, nur im privaten Raum, nur eigener Absender
{ "v": 1, "rec": "contact", "id": "@anna:example.org", "state": "accepted",
  "nick": "Anna (Verein)", "room": "!abc:example.org", "ver": 3, "ts": 1793000000000, "del": false }
{ "v": 1, "rec": "group",   "id": "!def:example.org", "ver": 1, "ts": 1793000000000, "del": false }
{ "v": 1, "rec": "prefs",   "id": "prefs", "enabled": true, "ver": 2, "ts": 1793000000000, "del": false }
```

Regeln wie E-40: strikte Prüfung, unbekanntes `v` wird verworfen, Konfliktlösung nach `ver`, dann `ts`. Annahme nur, wenn
verschlüsselt angekommen und Absender das eigene Konto.

## 6. Einstufung der Räume (Kern der Umsetzung)

### 6.1 Eine Entscheidungsstelle
Heute verteilt sich die Logik auf `_eligibleDirectRooms`, `_acceptDirectInvites`, `invitations` und
`_requireEncryptedRoom`. Sie wandert in eine reine Domänenfunktion; damit endet auch die Lücke aus `OFFEN.md`, dass diese
Regeln nur per Synapse-E2E geprüft sind.

```dart
// lib/domain/conversation_policy.dart
enum RoomClass { family, private, familyDirect, contactDirect, contactGroup, familyInvite, contactRequest, ignored }

class RoomFacts { // aus dem SDK-Raum gelesen, keine SDK-Typen
  final String id; final bool isInvite; final bool isDirect; final String? peerId; final String? inviterId;
  final bool megolm; final int? joinedCount; final int? invitedCount; final String? joinRule;
}

class ConversationPolicy {
  /// Reihenfolge: Familie vor Kontakt, unbekannt ist immer `ignored` (I2).
  static RoomClass classify(RoomFacts r, PolicyContext c);
}
```

`PolicyContext` enthält Familienraum-ID, privaten Raum, beigetretene Mitglieder, ob die Liste vollständig geladen ist,
Kontakte und bestätigte Gruppen, Blockierliste und den Schalter `enabled`.

### 6.2 Entscheidungstabelle

| Raum | Bedingung | Einstufung |
|---|---|---|
| Familienraum, privater Raum | ID aus Kontodaten | `family`, `private` |
| Beigetreten, `is_direct`, Gegenüber beigetretenes Mitglied, Megolm, höchstens zwei Personen | – | `familyDirect` |
| Beigetreten, Gegenüber mit Datensatz `accepted`, Megolm, höchstens zwei Personen | Bereich eingeschaltet, nicht blockiert | `contactDirect` |
| Beigetreten, ID mit Datensatz `group`, Megolm, höchstens 50 Personen | Bereich eingeschaltet | `contactGroup` |
| Einladung `is_direct` von beigetretenem Mitglied | – | automatische Annahme wie E-39 |
| Einladung von Kontakt `accepted` oder `outgoing` | Bereich eingeschaltet | automatische Annahme (gegenseitiges Hinzufügen) |
| Einladung mit `join_rules: knock`, keine eigene Familie | – | `familyInvite` |
| Sonstige Einladung | Liste geladen, Bereich eingeschaltet, nicht blockiert, Obergrenze nicht erreicht | `contactRequest` |
| Alles andere | – | `ignored` |

### 6.3 Familieneinladungen sicher erkennen (B1)
- Familienräume haben immer `join_rules: knock` (E-12), Gruppen `invite`. Der Wert gehört zum Zustand, den Server
  Eingeladenen mitliefern.
- **Noch nachzuweisen (K0):** dass Synapse und matrix.org `m.room.join_rules` im Einladungszustand liefern und das SDK ihn
  über `getState` bereitstellt.
- Fehlt der Wert, bleibt für Konten ohne Familie das heutige Verhalten mit Warnkarte (E-49), damit der Beitritt nicht
  bricht. Für Konten mit Familie gilt die Einladung als `contactRequest`.
- `acceptInvitation` prüft dieselbe Einstufung. Ein Raum ohne `knock` wird nie zur Familie (zusätzlich zur Prüfung auf
  Verschlüsselung nach dem Beitritt).
- Bösartig gesetztes `knock` auf einer Gruppe führt nur zum Zustand von heute: Warnkarte und ausdrückliche Annahme.

## 7. Architektur

```
domain/contacts.dart               Contact, GroupRecord, ContactPrefs, ContactCodec (v1), Konfliktregel, Grenzen,
                                   ContactId (Eingabe @name:server und matrix.to-Link)
domain/conversation_policy.dart    RoomFacts, PolicyContext, RoomClass, ConversationPolicy
domain/contact_service.dart        Regeln, Versionen, Grenzen, Wechselwirkung mit Blockierliste
domain/contact_store.dart          Schnittstelle
domain/chat.dart                   ThreadKind + contact, group; ChatThread.scope, memberCount, verified
domain/permissions.dart            canManageGroup(thread), canAddContacts(family, me)
data/db/sql_contact_store.dart     SQLCipher, Migration (nächste freie Version, heute 5)
data/matrix/contact_group_spec.dart  Reine Raumbeschreibung analog FamilyRoomSpec
data/matrix/matrix_gateway.dart    neue Methoden, Abschnitt 7.2
data/sync/contact_sync.dart        ContactSignal ↔ ContactService ↔ Gateway, Warteschlange, Resync
features/contacts/                 ContactsScreen, AddContactDialog, RequestCard, GroupEditor, GroupInfoScreen
features/chat/chat_screen.dart     Bereichsumschalter, Kennzeichnung, Entwürfe je Gespräch
```
Schichtenregeln gelten unverändert (Architekturtest). Damit die 3 192 Zeilen von `sdk_matrix_gateway.dart` nicht weiter
wachsen, kommt die Raumlogik in `data/matrix/contact_rooms.dart` (intern vom Gateway gehalten).

### 7.1 Änderungen am Gateway

- `_dmTimelines`/`_dmPeers` bleiben für `familyDirect`. Neu: `_contactTimelines`, `_contactPeers`. `_timelineFor` und
  `_roomForThread` schauen in beiden nach; `threads` liefert: Familienchat, Mitglieder, Kontakte, Gruppen.
- **Zeitleisten bei Bedarf:** Kontakt-Zeitleisten entstehen erst beim Öffnen des Gesprächs. `_syncDirectChats` bildet bei
  jedem `_refresh` alle Nachrichten neu ab; das skaliert nicht auf 500 Kontakte. Ungelesen kommt ohne Zeitleiste aus
  `room.notificationCount` (`unreadIn` kann das schon), in diesen Räumen gibt es keine App-Ereignisse, die den Zähler
  verfälschen (#65).
- `_requireEncryptedRoom(threadId)`: statt „Gegenüber ist Mitglied“ prüft es die Einstufung: `familyDirect`,
  `contactDirect`, `contactGroup`. Alles andere `notAllowed`.
- Bestehende Prüfungen bleiben unverändert: `startDirectChat` nur für Mitglieder, `announcePresence` und `_onToDevice`
  nur für `f.joined`, `_scanForSignals` nur auf Familien- und privater Zeitleiste, `shareEventInChat` nur Familienraum.
  Das sichert I3 und I4 ohne neuen Code; Tests halten es fest.
- `_resetDirectChats` setzt auch die Kontaktzustände zurück. Ohne Familie ist die App auf die Einrichtung beschränkt
  (`AppRoot`), damit sind auch Kontakte nicht erreichbar; die Räume bleiben auf dem Server erhalten.
- `dataInventory`: `InventoryRoomKind` + `contact`, `group`.

### 7.2 Neue Schnittstelle

```dart
// MatrixGateway
void setContactPolicy(ContactPolicy policy);          // gesetzt von ContactSync
int get familyUnreadCount;                            // nur Bereich Familie
List<ContactRequest> get contactRequests;             // eingehende Einladungen, nur Namen und IDs
Future<ContactProbe> probeContact(String userId);     // Name, hat Schlüssel, Erreichbarkeit
Future<String> startContactChat(String userId);       // verweigert für Mitglieder und Blockierte
Future<void> acceptContactRequest(String roomId);     // prüft nach Beitritt Megolm und Größe, sonst Austritt
Future<void> declineContactRequest(String roomId);
Future<String> createGroup({required String name, required List<String> members});
Future<void> renameGroup(String threadId, String name);
Future<void> inviteToGroup(String threadId, String userId);
Future<void> removeFromGroup(String threadId, String userId);
Future<void> leaveConversation(String threadId);      // nie für Familienchat und Mitglieder-Einzelchats
List<GroupMember> groupMembers(String threadId);
Future<void> publishContactRecord(ContactRecord r);   // nur privater Raum
```

`ContactSignal` läuft über denselben Signalstrom wie `ShoppingSignal`, entsteht aber nur aus `_scanForSignals(…, shared:
false)` und nur mit eigenem Absender. `FakeMatrixGateway` bildet alles nach, inklusive Fremdeinladungen und
Kontakten ohne Cross-Signing.

## 8. Abläufe

### 8.1 Kontakte einschalten
Menü → **Kontakte**. Beim ersten Öffnen erklärt eine Seite, was sich ändert, und bietet „Kontakte einschalten“ an.
Standard ist **aus** (I1). Der Zustand gilt fürs Konto (`rec: prefs`). Ausschalten verbirgt die Bereiche und ignoriert neue
Anfragen; Räume und Datensätze bleiben, nichts wird gelöscht.

### 8.2 Kontakt hinzufügen
1. Eingabe `@name:server` oder `matrix.to`-Link (`ContactId`); zusätzlich „Meine Kontakt-ID“ zum Kopieren.
2. `probeContact`: Konto vorhanden, Schlüssel vorhanden. Ist die ID ein Familienmitglied: Hinweis, Weg über „Nachricht
   schreiben“.
3. Bestätigung mit Name **und** voller ID, dann `startContactChat`. Datensatz `outgoing`, Raum wird angelegt.
4. Sobald die Gegenseite beitritt: `accepted`. Bis dahin Zustand „wartet auf Annahme“.

### 8.3 Erreichbarkeit (B5)
`probeContact` und die Gesprächsanzeige prüfen `userDeviceKeys[id]`:

| Zustand | Bedingung | Verhalten |
|---|---|---|
| erreichbar | mindestens ein Gerät mit `encryptToDevice` | normal |
| nicht erreichbar | keine Schlüssel oder kein cross-signiertes Gerät | Senden gesperrt (neuer Fehler `peerNotReachable`), Hinweis „Diese Person muss in ihrer App die Sicherheitsprüfung einrichten“ |
| Identität geändert | `_identityChanged` | Geräte gesperrt wie bei Mitgliedern, Warnung, Auflösung über Emoji-Vergleich |

In Gruppen zeigt die Mitgliederliste die nicht erreichbaren Personen; Senden bleibt möglich, sobald mindestens eine Person
erreichbar ist, und der Sendebereich nennt die Zahl der Ausgelassenen.

### 8.4 Anfrage erhalten
Im Bereich **Anfragen** stehen Name, volle ID, Server, „Gruppe: <Name>“ und bei Gruppen der Einladende. Vor der Annahme ist
kein Nachrichteninhalt verfügbar. Aktionen: **Annehmen**, **Ablehnen**, **Blockieren**. Nach dem Beitritt prüft die App
Megolm und Größe; sonst verlässt sie den Raum sofort (wie `_joinDirect`). Höchstens 50 offene Anfragen werden angezeigt,
ältere bleiben unbeantwortet liegen.

### 8.5 Gruppe gründen und verwalten
Kontakte → **Neue Gruppe**: Name (1–60, Hinweis „für Server sichtbar“), Mitglieder aus den bestätigten Kontakten. Auch
Familienmitglieder sind wählbar, der Raum bleibt im Bereich Außerhalb; sie entscheiden wie jeder andere selbst über die
Einladung. Ältere App-Versionen ignorieren solche Einladungen. `GroupInfoScreen`: Mitglieder, Hinzufügen, Entfernen,
Umbenennen (Admin), Verlassen, Blockieren einzelner Personen. Entfernen lässt das SDK die Sitzung rotieren. Verlässt der
letzte Admin die Gruppe, warnt die App vorher.

### 8.6 Chat-Oberfläche
- Der Chat-Tab zeigt über der Gesprächsleiste den Umschalter **Familie | Kontakte** mit getrennten Abzeichen, nur wenn
  Kontakte eingeschaltet sind. Sonst ist der Tab pixelgleich zu 1.2.1. Die fünf Tabs bleiben.
- Kopfzeile außerhalb der Familie, dauerhaft: „Außerhalb der Familie. Termine, Listen und Online-Status werden hier nicht
  geteilt.“ Eigenes Symbol, abweichender Glasrand; Text und Form tragen die Aussage (WCAG, Concept).
- Name stets mit Server, z. B. „Anna · example.org“. Gleicht ein Name einem Familienmitglied, erscheint „Nicht deine
  Familie: <ID>“ (Schutz vor Namensgleichheit).
- „Heute“ und die Familienansicht zeigen keine Kontakte. Dort bleibt alles wie bisher.

Die IDs der Form `@name:server` sind hier gewollt und nötig. Die Vorgabe aus Phase 8 (keine IDs auf dem normalen Weg) gilt
weiter für die Einrichtung; TP-L10N-01 bleibt unverändert.

## 9. Sicherheit

### 9.1 Bedrohungen

| Risiko | Gegenmaßnahme | Restrisiko |
|---|---|---|
| Spam, Belästigung über Einladungen | Standard aus, Anfragen nur mit Tipp, Blockieren, Melden, Obergrenzen | Lästige Anfragen bleiben möglich, solange der Bereich an ist |
| Fremder gibt sich als Familienmitglied aus | Immer volle ID oder Server, Warnung bei gleichem Namen, Bereich klar getrennt, Identitätsvermerke | Person achtet nicht auf den Hinweis |
| Abfluss von Familiendaten | I3, I4, kein Teilen von Terminen in Kontakte, Entwürfe getrennt | Nutzer kopiert Inhalte bewusst von Hand |
| Gefälschte Terminkarte, fremde App-Ereignisse | `allowEventRefs`, Signale nur aus Familienraum | – |
| Gruppe wird zur Familie gemacht | B1, Prüfung in `acceptInvitation` | Fremde Matrix-Apps sind außerhalb der App |
| Schädliche Anhänge von Fremden | E-19/E-28 unverändert, kein automatisches Laden, keine Linkvorschau, Text wird nicht als Link dargestellt | Lücke im Bilddecoder nach Tipp |
| Server-Metadaten | Transparenz in Datenschutz | Server sehen, wer mit wem in welchem Raum ist und den Gruppennamen; `m.direct` und `identity_pins` nennen Partner dem eigenen Server (SA-11) |
| Föderation | Inhalte E2EE | Fremde Server sehen Metadaten und Klartext-Gruppennamen |
| Großräume als Ressourcenangriff | Obergrenze 50, Prüfung nach Beitritt, Zeitleisten bei Bedarf | Beitritt kurzzeitig nötig, um die Größe sicher zu kennen |

### 9.2 Abweichung SA-11 (vorgeschlagen)
Kontaktbeziehungen sind dem eigenen und dem fremden Homeserver als Raummitgliedschaft bekannt und lassen sich anders als
die Liste selbst nicht verschlüsseln. Das Concept-Versprechen „nur die Familie“ gilt für diese Gespräche nicht. Inhalt
bleibt Ende-zu-Ende-verschlüsselt, die Familie selbst bleibt unsichtbar.

### 9.3 Melden, Blockieren, Entfernen

| Aktion | Wirkung |
|---|---|
| Melden | Wie E-48 an den Betreiber des **eigenen** Homeservers. |
| Blockieren | Wie E-48: lokal, der Blockierte erfährt nichts. Zusätzlich Datensatz `blocked`, damit alle eigenen Geräte es übernehmen. Einzelchat ausgeblendet, in Gruppen Nachrichten ausgeblendet, neue Einladungen unsichtbar. |
| Entfernen | Raum verlassen, Datensatz löschen. Nachrichten bleiben bei der Gegenseite. |

Mitglieder der Familie blockiert man weiter nur auf dem jeweiligen Gerät wie bisher.

### 9.4 Minderjährige
E-11 kennt keine technische Einschränkung, das war vertretbar, solange nur Eingeladene der Familie schreiben konnten. Mit
Kontakten erreicht ein Kind Fremde. Deshalb neu: **Moderatoren können Kontakte je Mitglied sperren.**
- Verschlüsseltes Raumereignis `de.inneso.familynexus.member_policy` (`{ v: 1, userId, contacts: "blocked"|"allowed" }`) im
  Familienraum, angenommen nur von Moderatoren (`Permissions.isModeratorId`).
- Die App des Mitglieds schaltet den Bereich ab, solange die Sperre gilt. Das Mitglied sieht den Grund als Text.
- **Grenze:** Das setzt nur die App durch. Mit einem anderen Matrix-Client lässt sich das Konto weiter nutzen.
- Hinweis beim Einschalten für alle: Die App prüft kein Alter. Beides ist Teil der Abstimmung (Abschnitt 15).

## 10. Datenhaltung

- Migration: Tabelle `contact_records` (`id`, `rec`, `state`, `nick`, `room`, `version`, `updated_ms`, `deleted`). Limits: 500
  Kontakte, 50 Gruppen.
- `AppSettings.blockedUsers` bleibt Quelle für die Anzeige; `ContactSync` trägt `blocked`-Datensätze dort ein. Die Grenze von
  200 Einträgen wird geprüft (E-48). Reicht sie nicht, wird sie angehoben.
- Abmelden und „Alle lokalen Daten löschen“: `SqlContactStore.wipe` in `wipeAccountDataIn` und `bootstrap.dart`.
- Familienwechsel löscht Kontakte **nicht**: Sie gehören zum Konto, nicht zur Familie (anders als E-37 für Termine).
- Nach Neuanmeldung kommt die Liste über den privaten Raum zurück (Backup-Schlüssel, E-57). Das Nachladen ist wie bei
  privaten Terminen begrenzt (20 Seiten); bei Verlust zeigt die App bestätigte Räume nicht mehr an, sie bleiben auf dem
  Server. Über „Erneut hinzufügen“ wird der vorhandene Raum wiederverwendet.

## 11. Kompatibilität

- **Ältere App-Versionen in der Familie:** nicht betroffen; keine Familienformate ändern sich. `member_policy` ignorieren
  sie, ohne Schutzwirkung auf diesen Geräten.
- **Eigene zweite Installation mit 1.2.1:** sieht keine Kontakte und ignoriert die Einladungen.
- **Konten mit vorhandenen Matrix-Räumen:** Vorhandene Räume bleiben unsichtbar (I2).
  Ältere offene Einladungen erscheinen beim Einschalten als Anfragen, gedeckelt auf 50.
- **Alle Plattformen:** gleiche Codebasis. Web: Einschränkungen aus `OFFEN.md` gelten unverändert.

## 12. Store, Datenschutz, Dokumentation

Diese Punkte sind Voraussetzung für das Release, nicht Nacharbeit.

| Datei | Änderung |
|---|---|
| `store/metadata/{ios,macos}/review_notes.txt` | „messages only go to invited family members“ ersetzen; Prüfweg für Anfrage, Melden, Blockieren ergänzen. `test/store/review_notes_test.dart` beachten. |
| `Apple-Feedback/`, `docs/STORE.md` | Aussagen zu nutzergenerierten Inhalten, Altersfreigabe und Zielgruppe neu bewerten. **Vom Herausgeber zu entscheiden:** Kontakt mit Fremden kann eine andere Altersfreigabe, sichtbare Kontaktstelle für Beschwerden und Auflagen zu Inhalten nach Apple-Richtlinie 1.2 nach sich ziehen. „Kontakte: nein“ in der Datensicherheit prüfen; das Adressbuch wird weiter nicht gelesen. |
| `store/privacy/privacy-policy.{de,en}.md` | Kontakte und Gruppen, Empfänger außerhalb der Familie, fremde Homeserver, Daten Dritter, Hinweis für Kinder. Die Datei hat gerade lokale Änderungen, also darauf aufsetzen. |
| `Concept.md`, `docs/ARCHITEKTUR.md`, `docs/ENTSCHEIDUNGEN.md`, `docs/OFFEN.md`, `README.md` | E-75 und SA-11 eintragen, E-39 als geändert markieren, „Gruppenchats außer dem Familienchat“ aus `OFFEN.md` entfernen, neue Grenzen aufnehmen. |
| `pubspec.yaml`, `lib/app/app_version.dart` | Version 1.4.0, Test `app_version_test.dart`. |

## 13. Tests

| Ebene | Inhalt |
|---|---|
| Domäne | `ConversationPolicy`: vollständige Entscheidungstabelle inkl. teilweise geladener Liste; `ContactCodec`, Konfliktregel, `ContactId`, Grenzen |
| Daten | `SqlContactStore`, Migration von Version 4, `ContactSync`, Löschung bei Abmelden |
| Widget | Kontakte aus: Chat-Tab unverändert (I1); Umschalter, Kennzeichnung, Anfragen, Entwurf je Gespräch (B4), kein Status für Kontakte, Abzeichen ohne Blockierte |
| Sicherheit (`penetration_test.dart`) | `event_ref` im Kontaktraum, Kalender-, Einkaufs-, Aufgaben- und Presence-Ereignisse von Kontakten, gefälschter `contact`-Datensatz, unverschlüsselter Raum, nachträglich vergrößerter Zweierraum, Gruppeneinladung ohne Familie, ungültige Kontakt-IDs |
| Bestand | Vorhandene Tests zur Isolation bleiben unverändert grün, insbesondere „Einzelchat-Einladung von Fremden wird weder angenommen noch als Familieneinladung gezeigt“ bei ausgeschaltetem Bereich |
| E2E (`gateway_contacts_e2e_test.dart`) | Synapse: Kontakt ohne Familie auf zweitem Konto; Einzelchat und Gruppe verschlüsselt, Server sieht keinen Klartext; Status und Termine kommen nicht an; Kontakt ohne Cross-Signing; Entfernen rotiert die Sitzung; zwei Homeserver für Föderation, falls `tool/synapse` erweiterbar |
| Interop | Manuell mit Element gegenüber: Anfrage, Antwort, Gruppe, Emoji-Vergleich |
| Testplan | `docs/TESTPLAN_KONTAKTE.md` nach dem Muster von `TESTPLAN_ONBOARDING.md`, zusätzlich Pen-Test des neuen Einfallstors |

Gate-Regeln aus `docs/PLAN.md` gelten je Phase.

## 14. Umsetzung in Phasen

| Phase | Inhalt | Umfang | Abnahme |
|---|---|---|---|
| **K0** | Vorprüfung gegen Synapse und matrix.org: `join_rules` im Einladungszustand, `syncPresence`, Cross-Signing-Prüfung, Verhalten beim Austritt. Danach Abstimmung Abschnitt 15 | S | Ergebnisse dokumentiert, Entscheidungen E-75 und SA-11 eingetragen |
| **K1** | **Härtung ohne neue Funktion:** B1, B2, B3, B4, B7. Kann als Zwischenversion ausgeliefert werden | M | Alle Bestandstests grün, neue Pen-Tests grün, keine sichtbare Änderung außer behobenen Fehlern |
| **K2** | Domäne, `ConversationPolicy`, Überführung der Bestandsregeln, Store, Migration, `ContactSync`, Fake | L | Einzelchats mit Mitgliedern unverändert, Lücke aus `OFFEN.md` geschlossen, Liste synchron über zwei Geräte |
| **K3** | Einzelchats: Hinzufügen, Anfragen, Erreichbarkeit, Verifizierung, Melden/Blockieren, Oberfläche | L | Kontakt auf fremdem Konto chattet verschlüsselt; Abnahme 1–6 unten |
| **K4** | Gruppen: `ContactGroupSpec`, Anlage, Verwaltung, Mitgliederwechsel | M | Abnahme 7–9 unten |
| **K5** | Sperre durch Moderatoren (`member_policy`), Datenauskunft, Grenzen, Barrierefreiheit | S | Abnahme 10–11 unten |
| **K6** | Store-Texte, Datenschutz, Doku, Testplan, Pen-Test, Review durch separaten Agenten, Interop | M | Abschnitt 12 erledigt, Gates grün, Release 1.4.0 |

### Abnahmekriterien V1.4
1. Nach dem Update ohne Einschalten: Oberfläche, Einladungsverhalten und gesendete Ereignisse wie 1.2.1 (bis auf die
   Härtungen aus K1).
2. Eine Person ohne Familie auf anderem Konto kann als Kontakt hinzugefügt werden und mit jedem Matrix-Client antworten.
3. Einladungen Fremder wirken erst nach Einschalten und Tipp; blockierte Absender bleiben unsichtbar.
4. Ein Kontakt erhält nachweislich keine Termine, Zusagen, Einkaufs- und Aufgabenereignisse, keinen Online-Status und keine
   Angaben zur Familie (E2E am Empfängerkonto).
5. Ereignisse von Kontakten erzeugen keine Änderung an Kalender, Einkaufszettel, Aufgaben oder Status (Pen-Test).
6. Unverschlüsselte Räume werden nie genutzt, Kontakte ohne Cross-Signing werden als nicht erreichbar gemeldet.
7. Eine Gruppe mit mindestens drei Konten auf zwei Servern funktioniert mit Text, Antworten, Reaktionen und Anhängen.
8. Eine entfernte Person kann danach gesendete Nachrichten nicht entschlüsseln; neu Eingeladene lesen nichts aus der Zeit
   vor der Einladung.
9. Eine Gruppeneinladung wird nie als Familieneinladung gezeigt und kann nie zur Familie werden.
10. Eine Sperre durch Moderatoren schaltet den Bereich beim Mitglied ab und ist nur von Moderatoren annehmbar.
11. Entwürfe bleiben je Gespräch getrennt, Kennzeichnung ist in beiden Sprachen und für Screenreader vorhanden.
12. Keine Matrix-IDs von Kontakten oder Inhalte im Log (`AppLog`), Datenauskunft nennt die neuen Räume.

## 15. Entscheidungen zur Abstimmung

Vorschläge des Konzepts. Abweichungen ändern nur die genannten Abschnitte.

| Frage | Vorschlag | Betrifft |
|---|---|---|
| Kontakte standardmäßig an oder aus? | **Aus**, ausdrückliches Einschalten je Konto | 8.1, I1 |
| Dürfen Moderatoren Kontakte für Mitglieder sperren? | **Ja**, ohne Altersprüfung, nur in der App durchgesetzt | 9.4 |
| Dürfen Fremde Anfragen stellen, oder nur Personen, die ich hinzugefügt habe? | **Fremde dürfen**, mit Tipp zur Annahme; sonst müssten beide Seiten FamilyNexus nutzen und sich gleichzeitig hinzufügen | 6.2, 8.4 |
| Dürfen Familienmitglieder in Gruppen mit Kontakten? | **Ja**, die Gruppe bleibt außerhalb der Familie | 8.5 |
| Bleibt die Pflicht zu Cross-Signing für Kontakte? | **Ja**, auch wenn manche Kontakte damit nicht erreichbar sind | 8.3, B5 |
| Gruppengröße | **50** | 5, 9.1 |
| Reihenfolge | **K1 vorab** als eigene Härtung ausliefern, B2 und B3 sind auch ohne Kontakte sinnvoll | 14 |
| Altersfreigabe und Store-Einstufung | **Offen**, Entscheidung des Herausgebers vor K6; kann das Release verzögern | 12 |
