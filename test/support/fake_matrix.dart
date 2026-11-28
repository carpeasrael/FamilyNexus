import 'dart:async';

import 'package:family_nexus/data/matrix/contact_group_spec.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart' show groupSendLockError;
import 'package:family_nexus/domain/account_deletion.dart';
import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_codec.dart';
import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/book_signal.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/conversation_policy.dart';
import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/family_code.dart';
import 'package:family_nexus/domain/group_rights.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:family_nexus/domain/password_change.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:family_nexus/domain/presence.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/username_suggestion.dart';
import 'package:family_nexus/domain/verification_policy.dart';
import 'package:flutter/foundation.dart';

import 'fake_outbound_session_port.dart';

/// Ereignis im Fake-Server (entspricht einem verschlüsselten Raumereignis).
class FakeEvent {
  FakeEvent(this.id, this.roomId, this.sender, this.type, this.content, this.time);
  final String id;
  final String roomId;
  final String sender;
  final String type;
  final Map<String, Object?> content;
  final DateTime time;
}

class FakeRoom {
  FakeRoom(this.id, this.name);
  final String id;
  String name;

  /// Immer verschlüsselt (E-12); der Fake bietet keinen Weg, es abzuschalten.
  final bool encrypted = true;

  /// Zählt Schlüsselrotationen (Entfernen von Mitgliedern).
  int keyEpoch = 0;
  final Map<String, int> power = <String, int>{};

  /// Power-Levels: Schwellen je Zustandstyp (`events`) und `state_default`. Neue Familien geben den Avatar-Typ für
  /// Mitglieder frei (E-101); Tests für Familien von vor dem Update entfernen den Eintrag.
  final Map<String, int> eventPower = <String, int>{AvatarPresets.type: PowerLevels.member};
  int stateDefault = PowerLevels.moderator;

  /// Avatar-Raumzustand: Zustandsschlüssel (Matrix-ID) → Inhalt. Nicht verschlüsselt, ein Wert aus zwölf.
  final Map<String, Map<String, Object?>> avatarState = <String, Map<String, Object?>>{};
  final Map<String, MemberStatus> membership = <String, MemberStatus>{};

  /// Ausgegebene Link-IDs (`nonce` → Ablauf) und die je Anfrage genannte ID.
  final Map<String, DateTime> issued = <String, DateTime>{};
  final Map<String, String> knockNonce = <String, String>{};

  /// Mitglieder, deren Identität sich geändert hat (Tests setzen das).
  final Set<String> identityChanged = <String>{};

  /// Abgelehnte Anfragen (Person → Raum bleibt für sie sichtbar als „abgelehnt“).
  final Set<String> rejected = <String>{};
  final List<FakeEvent> events = <FakeEvent>[];

  /// Nur Einzelchats: die zwei Beteiligten.
  final Set<String> dmMembers = <String>{};

  /// Nur Kontakt-Räume (#119): Beteiligte, die nur eingeladen sind (noch nicht beigetreten).
  final Set<String> invitedUsers = <String>{};

  /// Nur Gruppen (#119, K4-2a): Einladender, Regel, Verlauf, Verschlüsselung und Stufen. Alle Beteiligten (beigetreten und
  /// eingeladen) stehen in [dmMembers], die nur eingeladenen zusätzlich in [invitedUsers].
  String? groupInviter;
  String? joinRule = 'invite';
  String? history = 'invited';
  bool groupEncrypted = true;
}

class _Account {
  _Account(this.userId, this.password);
  final String userId;
  String password;
  String displayName = '';
}

/// Fake-Homeserver für Tests ohne Netz. Mehrere [FakeMatrixGateway] (Geräte)
/// können sich verbinden; alle gesendeten Ereignisse sind in [log] einsehbar,
/// damit Tests prüfen können, was den Server erreicht.
class FakeMatrixServer {
  FakeMatrixServer({this.host = 'fake.test', this.operatorName = 'Fake-Betreiber'});

  final String host;
  final String? operatorName;
  final Map<String, _Account> _accounts = <String, _Account>{};
  final Map<String, FakeRoom> rooms = <String, FakeRoom>{};

  /// Offene Einladungen je Nutzer: Raum-IDs.
  final Map<String, List<String>> invites = <String, List<String>>{};

  /// Privater Raum je Konto (nur dieses Konto ist Mitglied).
  final Map<String, FakeRoom> privateRooms = <String, FakeRoom>{};
  final List<FakeEvent> log = <FakeEvent>[];

  /// Meldungen an den Homeserver-Betreiber (Melder, Raum, Ereignis, Grundtext).
  final List<({String reporter, String roomId, String eventId, String reason})> reports =
      <({String reporter, String roomId, String eventId, String reason})>[];

  /// Einzelchat-Räume (immer verschlüsselt, genau zwei Beteiligte).
  final Map<String, FakeRoom> dmRooms = <String, FakeRoom>{};

  /// Einzelchat-Räume mit Personen außerhalb der Familie (#119, K3a-2); [FakeRoom.invitedUsers] sind nur eingeladen.
  final Map<String, FakeRoom> contactRooms = <String, FakeRoom>{};

  /// Legt einen Kontakt-Raum an: [from] ist beigetreten, [to] eingeladen (oder beigetreten mit [toJoined]).
  FakeRoom createContactRoom(String from, String to, {bool toJoined = false}) {
    final room = FakeRoom('${nextId('!ct')}:$host', 'ct')..dmMembers.addAll(<String>[from, to]);
    if (!toJoined) room.invitedUsers.add(to);
    contactRooms[room.id] = room;
    notifyAll();
    return room;
  }

  /// Gruppen mit Personen außerhalb der Familie (#119, K4-2a).
  final Map<String, FakeRoom> groupRooms = <String, FakeRoom>{};

  /// Legt eine Gruppe an: [joined] sind beigetreten (der Ersteller [creator] zuerst), [invited] nur eingeladen, [inviter] lädt ein.
  FakeRoom createGroupRoom(String creator, String name, {List<String> joined = const <String>[], List<String> invited = const <String>[], String? inviter}) {
    final room = FakeRoom('${nextId('!gr')}:$host', name)
      ..dmMembers.addAll(<String>[creator, ...joined, ...invited])
      ..invitedUsers.addAll(invited)
      ..groupInviter = inviter;
    groupRooms[room.id] = room;
    notifyAll();
    return room;
  }

  /// Gesendete Statusmeldungen (Absender, online, ask, Empfänger) – nur Gerätenachrichten, nie Raumereignisse.
  final List<({String sender, bool online, bool ask, List<String> to})> presenceLog =
      <({String sender, bool online, bool ask, List<String> to})>[];
  final List<FakeMatrixGateway> _gateways = <FakeMatrixGateway>[];
  int _seq = 0;
  bool reachable = true;

  /// Simuliert einen Server, der für die Einrichtung eine Passwortbestätigung verlangt.
  bool requirePasswordForSecurity = false;

  /// Wie das echte Gateway (`await refreshSecurity()`): Der Zustand ist schon „bereit“ und gemeldet,
  /// bevor `setUpSecurity` den Schlüssel liefert.
  Duration? securityKeyDelay;

  /// Konten mit eingerichteter Schlüsselsicherung → Wiederherstellungsschlüssel.
  final Map<String, String> recoveryKeys = <String, String>{};

  /// Laufende simulierte Verifizierung (Initiator, Gegenseite).
  FakeVerification? verification;

  // ------------------------------------------------- Kontoanlage (E-55)

  /// Wie bei diesem Server ein Konto angelegt wird.
  RegistrationMode registrationMode = RegistrationMode.inApp;

  /// Angebotene UIA-Abläufe der klassischen Registrierung.
  List<List<String>> registrationFlows = <List<String>>[
    <String>[RegistrationFlows.dummy],
  ];

  /// Gültiger Einladungscode (Stufe `m.login.registration_token`).
  String registrationToken = 'FAMILIE-2026';

  /// Webseite des Anbieters für die Kontoanlage außerhalb der App.
  Uri? registrationWebPage = Uri.parse('https://fake.test/signup');

  /// Vom Test gesetzt: Captcha im Browser gelöst bzw. Bestätigungslink der E-Mail geöffnet.
  bool captchaSolved = false;
  bool emailConfirmed = false;

  /// E-Mail-Adressen, an die eine Bestätigung ging, und bereits verwendete Adressen.
  final List<String> emailsSent = <String>[];
  final Set<String> emailsInUse = <String>{};

  /// Zähler der Registrierungsanfragen (z. B. um zu prüfen, dass nichts gesendet wurde).
  int registerCalls = 0;

  /// Hält die Kontoanlage an, bis der Test fortsetzt.
  Completer<void>? registerGate;

  /// Hält `sendMessage` an, bis der Test fortsetzt (#410: Eingabe während des Sendens).
  Completer<void>? sendGate;

  bool hasAccount(String localpart) => _accounts.containsKey('@$localpart:$host');

  /// Konten ohne Cross-Signing (nicht erreichbar), mit gescheiterter Schlüsselabfrage und mit unbekanntem Profil
  /// (z. B. `M_FORBIDDEN`) für `probeContact`/`startContactChat` (#119, K3a-2b).
  final Set<String> unreachableUsers = <String>{};
  final Set<String> keyQueryFailures = <String>{};
  final Set<String> profileUnknown = <String>{};

  /// Zahl der Profil- und Schlüsselabfragen (Tests: Familienmitglieder werden ohne Netz beantwortet).
  int probeNetworkCalls = 0;

  /// Test: `probeContact` scheitert mit diesem Fehler (z. B. `rateLimited`).
  GatewayError? probeError;

  /// Test: Konten, deren Sicherheitsschlüssel sich geändert hat (`probeContact` meldet `identityChanged`).
  final Set<String> identityChangedUsers = <String>{};

  /// Test: Identitätszustand der Kontakte (Standard `unknown`; `identityChangedUsers` hat Vorrang und ergibt `changed`).
  final Map<String, IdentityStatus> contactIdentities = <String, IdentityStatus>{};

  /// Test-Uhr (für Ablauf von Einladungslinks).
  DateTime Function() now = () => DateTime.utc(2026, 10, 21, 12);

  String nextId(String prefix) => '$prefix${++_seq}';

  String addAccount(String localpart, String password, {String? displayName}) {
    final id = '@$localpart:$host';
    _accounts[id] = _Account(id, password)..displayName = displayName ?? localpart;
    return id;
  }

  String displayNameOf(String userId) => _accounts[userId]?.displayName ?? userId;

  /// Passwort eines Kontos (nur Tests: belegt, dass die Registrierung das richtige Passwort übertrug).
  String? passwordOf(String userId) => _accounts[userId]?.password;

  FakeMatrixGateway newDevice() => FakeMatrixGateway(this);

  // ------------------------------------------------- Kontolöschung (#12)

  /// Kontoseite des Anbieters für Konten mit Anmeldung im Browser; `null` = keine angeboten.
  Uri? accountManagementPage = Uri.parse('https://fake.test/account?action=org.matrix.account_deactivate');

  /// Passwortänderung (#117): erzwingt den Weg, speist einmal einen Fehler ein, hält den Aufruf an.
  PasswordChange? passwordChangeMode;
  GatewayException? passwordChangeFailure;
  Completer<void>? passwordChangeGate;
  int passwordChangeCalls = 0;
  bool? lastLogoutOtherDevices;

  /// Gelöschte Konten (in der App oder beim Anbieter).
  final List<String> deactivated = <String>[];

  /// Löscht ein Konto wie der Homeserver: Es verlässt alle Räume, Anmeldung und Schlüssel sind weg.
  /// Die Sitzungen der Geräte enden erst, wenn sie den Server das nächste Mal fragen.
  void deactivateAccount(String userId) {
    _accounts.remove(userId);
    recoveryKeys.remove(userId);
    privateRooms.remove(userId);
    for (final r in <FakeRoom>[...rooms.values, ...dmRooms.values]) {
      r.membership.remove(userId);
    }
    deactivated.add(userId);
    notifyAll();
  }

  void _register(FakeMatrixGateway g) => _gateways.add(g);

  /// Verteilt Kalender-Ereignisse an alle Geräte, die den Raum sehen dürfen.
  void _dispatch(FakeRoom room, FakeEvent e) {
    final isPrivate = privateRooms.values.contains(room);
    for (final g in _gateways) {
      final uid = g.userId;
      if (uid == null) continue;
      final CalendarSignal? sig;
      if (isPrivate) {
        if (privateRooms[uid] != room) continue;
        sig = switch (e.type) {
          EventCodec.privateType => PrivateEventSignal(e.sender, e.time, e.content),
          ContactCodec.type => ContactSignal(e.sender, e.time, e.content),
          _ => null,
        };
      } else {
        if (room.membership[uid] != MemberStatus.joined) continue;
        sig = switch (e.type) {
          EventCodec.sharedType => SharedEventSignal(e.sender, e.time, e.content),
          EventCodec.rsvpType => RsvpSignal(e.sender, e.time, e.content),
          ShoppingCodec.type => ShoppingSignal(e.sender, e.time, e.content),
          TaskCodec.listType => TaskListSignal(e.sender, e.time, e.content),
          TaskCodec.logType => TaskLogSignal(e.sender, e.time, e.content),
          EventThemeCodec.type => EventThemeSignal(e.sender, e.time, e.content),
          AnniversaryCodec.type => AnniversarySignal(e.sender, e.time, e.content),
          AvatarPhotoCodec.type => AvatarPhotoSignal(e.sender, e.time, e.content, eventId: e.id),
          AvatarResetCodec.type => AvatarResetSignal(e.sender, e.time, e.content),
          _ => null,
        };
      }
      if (sig != null) g._signals.add(sig);
    }
  }

  /// Legt einen weiteren Familienraum an, in dem [userId] Mitglied ist (Familienwechsel, #140).
  FakeRoom addFamilyRoom(String name, String userId) {
    final room = FakeRoom('${nextId('!room')}:$host', name)
      ..membership[userId] = MemberStatus.joined
      ..power[userId] = PowerLevels.admin;
    rooms[room.id] = room;
    return room;
  }

  /// Nimmt [userId] in den Raum auf (wie nach Einladung und Beitritt) und
  /// benachrichtigt die übrigen Mitglieder.
  void addMember(FakeRoom room, String userId, {int power = 0}) {
    room.membership[userId] = MemberStatus.joined;
    room.power[userId] = power;
    for (final g in _gateways) {
      final uid = g.userId;
      if (uid != null && uid != userId && room.membership[uid] == MemberStatus.joined) {
        g._signals.add(MemberJoinedSignal(userId, DateTime.utc(2026, 10, 21, 12)));
      }
    }
    notifyAll();
  }

  void notifyAll() {
    for (final g in _gateways) {
      g.notifyListeners();
    }
  }

  /// Der Avatar-Zustand eines Raums hat sich geändert: alle Geräte mit diesem Familienraum zählen hoch.
  void bumpAvatars(FakeRoom room) {
    for (final g in _gateways) {
      if (g._familyRoomId == room.id) g._bumpAvatars();
    }
  }

  /// Test: Zeitstempel des nächsten Ereignisses (einmalig), sonst fortlaufend ab 21.10.2026 12:00 UTC.
  DateTime? nextTime;

  FakeEvent post(FakeRoom room, String sender, String type, Map<String, Object?> content) {
    final at = nextTime ?? DateTime.utc(2026, 10, 21, 12).add(Duration(seconds: _seq));
    nextTime = null;
    final e = FakeEvent(nextId(r'$ev'), room.id, sender, type, content, at);
    room.events.add(e);
    log.add(e);
    _dispatch(room, e);
    notifyAll();
    return e;
  }
}

class FakeMatrixGateway extends ChangeNotifier implements MatrixGateway {
  /// Test: `inviteUser` scheitert mit diesem Fehler (#156).
  Object? inviteError;

  FakeMatrixGateway(this.fake) {
    fake._register(this);
  }

  // ------------------------------------------------------ Kassenbücher (#311)
  // Standard: gesperrt/leer. Tests setzen Bücher, Mitglieder und Sendeergebnisse und lösen Signale aus.

  /// Beigetretene Bücher der aktuellen Familie (Test).
  List<BookRoomInfo> fakeBooks = const <BookRoomInfo>[];

  /// Zugriffe auf die Buch-Schnittstelle (Test: bei gesperrtem Kassenbuch darf nichts zugreifen).
  int bookCalls = 0;

  final StreamController<BookSignal> _bookSignals = StreamController<BookSignal>.broadcast(sync: true);

  /// Wird neuen Zuhörern von [bookSignals] zuerst geliefert (wie die Historie des echten Gateways).
  final List<BookSignal> bookReplay = <BookSignal>[];

  /// Vollständige Verläufe, Zähler unentschlüsselbarer Ereignisse und „nicht mehr beigetreten“ (Test).
  final Set<String> completeBooks = <String>{};
  final Map<String, int> undecryptableBooks = <String, int>{};
  final Set<String> goneBooks = <String>{};

  /// Bekannte Mitglieder je Buch; `knownMembersError` lässt den Abruf scheitern (Test).
  final Map<String, Set<String>> knownMembers = <String, Set<String>>{};
  Object? knownMembersError;
  int knownMembersCalls = 0;

  /// Sendeergebnis je Aufruf (Standard: alles gesendet); `publishError` wirft.
  List<BookSendResult> Function(String roomId, List<BookOutgoing> events)? publishHandler;
  GatewayException? publishError;
  final List<({String roomId, List<BookOutgoing> events})> bookPublished = <({String roomId, List<BookOutgoing> events})>[];

  /// Ergebnis von [reconcileBook] (Test); zählt Aufrufe.
  List<String> Function(String roomId)? reconcileHandler;
  int reconcileCalls = 0;

  /// Bon-Dateien (Test): Ergebnis von [loadBookReceipt], Fehler und Protokoll der Aufrufe.
  BookReceiptLoad Function(String roomId, String eventId, CashReceipt receipt, String author)? loadReceiptHandler;
  GatewayException? sendReceiptError;
  GatewayException? Function(String roomId, String eventId)? redactReceiptHandler;
  final List<({String roomId, Uint8List bytes})> sentReceipts = <({String roomId, Uint8List bytes})>[];
  final List<({String roomId, String eventId})> redactedReceipts = <({String roomId, String eventId})>[];
  int receiptCounter = 0;

  @override
  Future<String> sendBookReceipt(String roomId, Uint8List bytes) async {
    bookCalls++;
    final e = sendReceiptError;
    if (e != null) throw e;
    sentReceipts.add((roomId: roomId, bytes: bytes));
    return '\$receipt${++receiptCounter}';
  }

  @override
  Future<BookReceiptLoad> loadBookReceipt(String roomId, String eventId, {required CashReceipt receipt, required String author}) async {
    bookCalls++;
    return loadReceiptHandler?.call(roomId, eventId, receipt, author) ?? const BookReceiptLoad(BookReceiptStatus.missing);
  }

  @override
  Future<void> redactBookReceipt(String roomId, String eventId) async {
    bookCalls++;
    final e = redactReceiptHandler?.call(roomId, eventId);
    if (e != null) throw e;
    redactedReceipts.add((roomId: roomId, eventId: eventId));
  }

  /// Mitglieder je Buch und „andere Familie“ (Test).
  final Map<String, List<BookMember>> bookMemberList = <String, List<BookMember>>{};
  GatewayException? bookMembersError;
  List<String> fakeStaleBooks = const <String>[];
  final List<String> leftBooks = <String>[];

  @override
  Future<List<BookMember>> bookMembers(String roomId) async {
    bookCalls++;
    final e = bookMembersError;
    if (e != null) throw e;
    return bookMemberList[roomId] ?? const <BookMember>[];
  }

  @override
  List<String> get staleBooks {
    bookCalls++;
    return fakeStaleBooks;
  }

  void injectBookSignal(BookSignal s) => _bookSignals.add(s);

  @override
  List<BookRoomInfo> get books {
    bookCalls++;
    return fakeBooks;
  }

  /// Einladungen und Buchaktionen (Test): Standard wie gesperrt (`notAllowed`); mit [nextBookRoom] gelingt das Anlegen.
  List<BookInvitationInfo> fakeInvitations = const <BookInvitationInfo>[];
  String? nextBookRoom;
  GatewayException? bookActionError;
  final List<(String, String)> invitedToBook = <(String, String)>[];
  final List<(String, String)> removedFromBook = <(String, String)>[];
  final List<String> acceptedBooks = <String>[];
  final List<String> declinedBooks = <String>[];

  @override
  List<BookInvitationInfo> get bookInvitations {
    bookCalls++;
    return fakeInvitations;
  }

  GatewayException _actionError() => bookActionError ?? const GatewayException(GatewayError.notAllowed);

  @override
  Future<String> createBook() async {
    bookCalls++;
    final r = nextBookRoom;
    if (r == null || bookActionError != null) throw _actionError();
    return r;
  }

  @override
  Future<void> inviteToBook(String roomId, String userId) async {
    bookCalls++;
    if (nextBookRoom == null || bookActionError != null) throw _actionError();
    invitedToBook.add((roomId, userId));
  }

  @override
  Future<void> removeFromBook(String roomId, String userId) async {
    bookCalls++;
    if (nextBookRoom == null || bookActionError != null) throw _actionError();
    removedFromBook.add((roomId, userId));
  }

  /// Test: wird vor jeder Buchaktion (`leave`) gerufen und darf werfen.
  void Function(String op, String roomId)? bookActionHook;

  @override
  Future<void> leaveBook(String roomId) async {
    bookCalls++;
    bookActionHook?.call('leave', roomId);
    if (nextBookRoom == null || bookActionError != null) throw _actionError();
    leftBooks.add(roomId);
  }

  @override
  Future<void> acceptBookInvitation(String roomId) async {
    bookCalls++;
    if (nextBookRoom == null || bookActionError != null) throw _actionError();
    acceptedBooks.add(roomId);
  }

  @override
  Future<void> declineBookInvitation(String roomId) async {
    bookCalls++;
    if (nextBookRoom == null || bookActionError != null) throw _actionError();
    declinedBooks.add(roomId);
  }

  @override
  Future<void> verifyBookRecipients(String roomId) => throw const GatewayException(GatewayError.notAllowed);

  @override
  Future<List<String>> reconcileBook(String roomId) async {
    bookCalls++;
    reconcileCalls++;
    return reconcileHandler?.call(roomId) ?? const <String>[];
  }

  @override
  Stream<BookSignal> get bookSignals {
    bookCalls++;
    return Stream<BookSignal>.multi((c) {
      for (final s in List<BookSignal>.of(bookReplay)) {
        c.add(s);
      }
      final sub = _bookSignals.stream.listen(c.add);
      c.onCancel = sub.cancel;
    });
  }

  @override
  bool bookHistoryComplete(String roomId) {
    bookCalls++;
    return completeBooks.contains(roomId);
  }

  @override
  int bookUndecryptableCount(String roomId) {
    bookCalls++;
    return undecryptableBooks[roomId] ?? 0;
  }

  @override
  bool bookRoomGone(String roomId) {
    bookCalls++;
    return goneBooks.contains(roomId);
  }

  @override
  Future<Set<String>> bookKnownMembers(String roomId) async {
    bookCalls++;
    knownMembersCalls++;
    final e = knownMembersError;
    if (e != null) throw e;
    return knownMembers[roomId] ?? const <String>{};
  }

  @override
  Future<List<BookSendResult>> publishBookEvents(String roomId, List<BookOutgoing> events) async {
    bookCalls++;
    final e = publishError;
    if (e != null) throw e;
    bookPublished.add((roomId: roomId, events: events));
    return publishHandler?.call(roomId, events) ?? List<BookSendResult>.filled(events.length, BookSendResult.sent);
  }

  final FakeMatrixServer fake;
  String? _userId;
  ServerUrl? _server;
  String? _familyRoomId;
  final Map<String, Uint8List> _files = <String, Uint8List>{};
  // ignore: close_sinks
  final StreamController<CalendarSignal> _signals = StreamController<CalendarSignal>.broadcast(sync: true);

  @override
  SessionState get session => _userId == null ? SessionState.loggedOut : SessionState.ready;

  bool _sessionEndedByServer = false;

  @override
  bool get sessionEndedByServer => _sessionEndedByServer && _userId == null;

  /// Simuliert, dass der Server die Sitzung beendet (Konto gelöscht, Token ungültig, #556).
  void endSessionByServer() {
    _userId = null;
    _server = null;
    _familyRoomId = null;
    _sessionEndedByServer = true;
    notifyListeners();
  }

  @override
  String? get userId => _userId;

  @override
  ServerUrl? get server => _server;

  FakeRoom? get familyRoom => _familyRoomId == null ? null : fake.rooms[_familyRoomId];

  /// Test-Hook: Familienraum für diesen Nutzer festlegen (z. B. nach Einladung). [notify]: `false` wie im echten
  /// Gateway, wo `family` wechselt, bevor der Abgleich am Ende die Zuhörer benachrichtigt (#140).
  void attachFamilyRoom(String roomId, {bool notify = true}) {
    _familyRoomId = roomId;
    if (notify) notifyListeners();
  }

  /// Test-Hook: Dieser Nutzer hat keine Familie mehr (entfernt, Raum verlassen).
  void detachFamilyRoom() {
    _familyRoomId = null;
    notifyListeners();
  }

  /// Hört noch ein gestarteter Dienst zu?
  bool get debugHasListeners => hasListeners;

  final ValueNotifier<int> _avatarRevision = ValueNotifier<int>(0);
  bool _avatarRevisionDisposed = false;

  void _bumpAvatars() {
    if (!_avatarRevisionDisposed) _avatarRevision.value++;
  }

  @override
  void dispose() {
    _avatarRevisionDisposed = true;
    _avatarRevision.dispose();
    super.dispose();
  }

  @override
  ValueListenable<int> get avatarRevision => _avatarRevision;

  @override
  String? avatarOf(String userId) {
    final room = familyRoom;
    if (room == null || _userId == null) return null;
    final content = room.avatarState[userId];
    return content == null ? null : AvatarPresets.fromContent(content);
  }

  @override
  AvatarAvailability get avatarAvailability {
    final room = familyRoom;
    if (room == null || _userId == null) return AvatarAvailability.unknown;
    final mine = room.power[_userId] ?? 0;
    return mine >= (room.eventPower[AvatarPresets.type] ?? room.stateDefault)
        ? AvatarAvailability.settable
        : AvatarAvailability.needsModerator;
  }

  @override
  Future<void> setMemberAvatar(String? preset) async {
    _requireSession();
    if (!AvatarPresets.isValid(preset)) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (room.membership[_userId] != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    if (avatarAvailability != AvatarAvailability.settable) throw const GatewayException(GatewayError.notAllowed);
    final error = avatarError;
    if (error != null) throw error;
    final content = AvatarPresets.content(preset);
    if (holdAvatarEcho) {
      _heldAvatar = content;
      return;
    }
    room.avatarState[_userId!] = content;
    fake.bumpAvatars(room);
    fake.notifyAll();
  }

  /// Test: `setMemberAvatar` scheitert mit diesem Fehler.
  Object? avatarError;

  /// Test: Die gesetzte Wahl erscheint erst mit [releaseAvatarEcho] im Zustand (wie das Sync-Echo des Servers).
  bool holdAvatarEcho = false;
  Map<String, Object?>? _heldAvatar;

  /// Test: spielt die zurückgehaltene Wahl ein.
  void releaseAvatarEcho() {
    final room = familyRoom;
    final held = _heldAvatar;
    if (room == null || held == null) return;
    _heldAvatar = null;
    room.avatarState[_userId!] = held;
    fake.bumpAvatars(room);
    fake.notifyAll();
  }

  RequestCheck _check(FakeRoom room, String user) {
    final n = room.knockNonce[user];
    if (n == 'code') return RequestCheck.code;
    final exp = n == null ? null : room.issued[n];
    if (exp == null) return RequestCheck.unknown;
    return fake.now().isBefore(exp) ? RequestCheck.valid : RequestCheck.expired;
  }

  @override
  Future<void> acceptIdentityChange(String userId) async {
    final room = familyRoom;
    if (room != null && !room.membership.containsKey(userId) && _contactAllowed(userId)) {
      // Kontakt (K3b-2b): dieselbe Richtlinie wie im Gateway, ohne Raumbindung.
      if (!fake.identityChangedUsers.remove(userId)) throw const GatewayException(GatewayError.notFound);
      fake.notifyAll();
      return;
    }
    if (room == null || !room.identityChanged.remove(userId)) throw const GatewayException(GatewayError.notFound);
    fake.notifyAll();
  }

  @override
  Family? get family {
    final room = familyRoom;
    if (room == null || _userId == null) return null;
    final members = <FamilyMember>[
      for (final e in room.membership.entries)
        FamilyMember(
          userId: e.key,
          displayName: fake.displayNameOf(e.key),
          role: PowerLevels.roleFor(room.power[e.key] ?? 0),
          status: e.value,
          identity: room.identityChanged.contains(e.key) ? IdentityStatus.changed : IdentityStatus.pinned,
          request: e.value == MemberStatus.requested ? _check(room, e.key) : null,
        ),
    ];
    return Family(roomId: room.id, name: room.name, members: members, myUserId: _userId!);
  }

  @override
  List<ChatMessage> get messages => messagesIn(ChatThread.familyId);

  /// Raum eines Gesprächs aus Sicht dieses Nutzers (Einzelchats nur mit aktuellen Familienmitgliedern).
  FakeRoom? _roomOf(String threadId) {
    if (threadId == ChatThread.familyId) return familyRoom;
    if (!fake.dmRooms.containsKey(threadId)) return _contactRoomOf(threadId) ?? _groupRoomOf(threadId);
    final room = fake.dmRooms[threadId];
    final me = _userId;
    if (room == null || me == null || !room.dmMembers.contains(me)) return null;
    final peer = room.dmMembers.firstWhere((m) => m != me);
    return family?.member(peer)?.status == MemberStatus.joined ? room : null;
  }

  @override
  List<ChatThread> get threads {
    final f = family;
    // Wie das Gateway seit K3c-1: ohne Familie nur Kontakt-Gespräche.
    if (f == null) return <ChatThread>[..._contactThreads(), ..._groupThreads()];
    final dms = <ChatThread>[
      for (final r in fake.dmRooms.values)
        if (_roomOf(r.id) != null && !hiddenThreads.contains(r.id))
          ChatThread(
            id: r.id,
            kind: ThreadKind.direct,
            title: fake.displayNameOf(r.dmMembers.firstWhere((m) => m != _userId)),
            peerId: r.dmMembers.firstWhere((m) => m != _userId),
            unread: unreadIn(r.id),
          ),
    ]..sort((a, b) => a.title.compareTo(b.title));
    return <ChatThread>[
      ChatThread(id: ChatThread.familyId, kind: ThreadKind.family, title: f.name, unread: unreadIn(ChatThread.familyId)),
      ...dms,
      ..._contactThreads(),
      ..._groupThreads(),
    ];
  }

  @override
  List<ChatMessage> messagesIn(String threadId) {
    final room = _roomOf(threadId);
    if (room == null) return const <ChatMessage>[];
    // Kontakt-Zeitleisten gibt es erst nach `openThread` (Konzept §7.1).
    if ((fake.contactRooms.containsKey(threadId) || fake.groupRooms.containsKey(threadId)) && !_opened.contains(threadId)) return const <ChatMessage>[];
    final reactions = <String, Map<String, Set<String>>>{};
    for (final e in room.events.where((e) => e.type == 'm.reaction')) {
      final target = e.content['target']! as String;
      reactions.putIfAbsent(target, () => <String, Set<String>>{})
          .putIfAbsent(e.content['emoji']! as String, () => <String>{})
          .add(e.sender);
    }
    final ids = <String>[for (final e in room.events.where((e) => e.type == 'm.room.message')) e.id];
    final markers = readMarkers[threadId] ?? const <String, String>{};
    return <ChatMessage>[
      for (final e in room.events.where((e) => e.type == 'm.room.message'))
        ChatMessage(
          id: e.id,
          senderId: e.sender,
          senderName: fake.displayNameOf(e.sender),
          time: e.time,
          body: (e.content['body'] as String?) ?? '',
          replyToId: e.content['reply_to'] as String?,
          // Terminverweise gelten nur im Familienraum (#119, B3), wie im Gateway (`allowEventRefs`).
          sharedEventId: threadId == ChatThread.familyId ? e.content['event_ref'] as String? : null,
          undecryptable: undecryptable.contains(e.id),
          reactions: reactions[e.id] ?? const <String, Set<String>>{},
          attachment: e.content['file_name'] == null
              ? null
              : AttachmentInfo(
                  name: e.content['file_name']! as String,
                  mimeType: e.content['mime']! as String,
                  size: e.content['size']! as int,
                ),
        ).copyWith(
          status: sendStates[e.id]?.status,
          retryable: sendStates[e.id]?.retryable,
          readBy: _readBy(e.sender, e.id, ids, markers),
        ),
    ];
  }

  /// Wer eine eigene Nachricht gelesen hat: Mitglieder, deren Lesemarker (Test) auf oder hinter ihr liegt. Leer bei
  /// fremden Nachrichten, bei ausgeschalteter Lesebestätigung (Gegenseitigkeit, #526) und für die eigene ID.
  Set<String> _readBy(String sender, String id, List<String> ids, Map<String, String> markers) {
    if (!shareReadReceipts || sender != _userId) return const <String>{};
    final at = ids.indexOf(id);
    return <String>{
      for (final m in markers.entries)
        if (m.key != _userId && ids.indexOf(m.value) >= at) m.key,
    };
  }

  /// Test (#526): Einstellung „Lesebestätigung senden“ dieses Nutzers; aus = `readBy` bleibt leer.
  bool shareReadReceipts = true;

  /// Test (#526): Lesemarker anderer je Gespräch: Nutzer-ID → Nachrichten-ID (`messagesIn` füllt `readBy` daraus).
  final Map<String, Map<String, String>> readMarkers = <String, Map<String, String>>{};

  /// Test (#526): setzt den Lesemarker von [userId] in [threadId] auf [eventId] und meldet die Änderung.
  void setReadMarker(String userId, String eventId, {String threadId = ChatThread.familyId}) {
    readMarkers.putIfAbsent(threadId, () => <String, String>{})[userId] = eventId;
    notifyListeners();
  }

  /// Test (#526): Anzahl der Aufrufe von [refreshReadStates].
  int readStateRefreshes = 0;

  @override
  void refreshReadStates() {
    readStateRefreshes++;
    notifyListeners();
  }

  void _require() {
    if (!fake.reachable) throw const GatewayException(GatewayError.serverUnreachable);
  }

  void _requireSession() {
    if (_userId == null) throw const GatewayException(GatewayError.notAllowed);
  }

  @override
  bool get initialSyncDone => syncDone;

  /// Für Tests: erster Abgleich noch nicht fertig („Synchronisiere …“).
  bool syncDone = true;
  int syncRetries = 0;

  @override
  Future<void> retrySync() async {
    syncRetries++;
  }

  final Map<String, int> _read = <String, int>{};

  @override
  int unreadIn(String threadId) {
    // Wie die Raum-Zähler des SDK: Auch ein Kontakt-Gespräch ohne geöffnete Zeitleiste hat Ungelesenes.
    final cr = fake.contactRooms[threadId] ?? fake.groupRooms[threadId];
    if (cr != null && !_opened.contains(threadId)) {
      return cr.events.where((e) => e.type == 'm.room.message' && e.sender != _userId).length;
    }
    final list = messagesIn(threadId);
    var n = 0;
    for (var i = _read[threadId] ?? 0; i < list.length; i++) {
      if (list[i].senderId != _userId) n++;
    }
    return n;
  }

  /// Test: Grundlinie für Meldungen (#254); `null` = noch kein echter Sync.
  @override
  DateTime? liveSince;

  @override
  String? firstUnreadIdIn(String threadId) {
    final list = messagesIn(threadId);
    for (var i = _read[threadId] ?? 0; i < list.length; i++) {
      if (list[i].senderId != _userId) return list[i].id;
    }
    return null;
  }

  @override
  int get unreadCount => threads.fold<int>(0, (a, t) => a + t.unread);

  /// Test (#119, B7): Zahl des Bereichs Familie, wenn sie von [unreadCount] abweichen soll (später mit Kontakten).
  int? familyUnreadOverride;

  @override
  int get familyUnreadCount =>
      familyUnreadOverride ?? threads.where((t) => t.kind == ThreadKind.family || t.kind == ThreadKind.direct).fold<int>(0, (a, t) => a + t.unread);

  @override
  Future<void> markChatRead({String threadId = ChatThread.familyId}) async {
    markedRead.add(threadId);
    markedReadPublic.add(shareReadReceipts);
    _read[threadId] = messagesIn(threadId).length;
    notifyListeners();
  }

  @override
  Stream<CalendarSignal> get calendarSignals => _signals.stream;

  // --------------------------------------------- Sicherheit und Verifizierung

  bool deviceVerified = false;
  late final String deviceId = 'DEV${fake._gateways.indexOf(this) + 1}';

  @override
  SecurityState get securityState {
    final uid = _userId;
    if (uid == null) return SecurityState.unknown;
    if (!fake.recoveryKeys.containsKey(uid)) return SecurityState.needsSetup;
    return deviceVerified ? SecurityState.ready : SecurityState.needsRestore;
  }

  @override
  Future<void> refreshSecurity() async {}

  /// Zählt die Abgleiche (#358).
  int syncNowCalls = 0;

  @override
  Future<void> syncNow() async {
    syncNowCalls++;
  }

  @override
  List<DeviceEntry> get devices {
    final uid = _userId;
    if (uid == null) return const <DeviceEntry>[];
    return <DeviceEntry>[
      for (final g in fake._gateways)
        if (g._userId == uid)
          DeviceEntry(userId: uid, deviceId: g.deviceId, name: 'Gerät ${g.deviceId}', verified: g.deviceVerified, isCurrent: identical(g, this)),
    ];
  }

  @override
  Future<String> setUpSecurity({String? password}) async {
    _requireSession();
    final acc = fake._accounts[_userId];
    if (fake.requirePasswordForSecurity) {
      if (password == null) throw const GatewayException(GatewayError.reauthRequired);
      if (acc == null || acc.password != password) throw const GatewayException(GatewayError.invalidCredentials);
    }
    if (fake.recoveryKeys.containsKey(_userId)) throw const GatewayException(GatewayError.alreadyExists);
    final key = 'EsTx ${fake.nextId('KEY')} fake';
    fake.recoveryKeys[_userId!] = key;
    deviceVerified = true;
    notifyListeners();
    final delay = fake.securityKeyDelay;
    if (delay != null) await Future<void>.delayed(delay);
    return key;
  }

  @override
  Future<String> resetRecoveryKey() async {
    _requireSession();
    if (securityState != SecurityState.ready) throw const GatewayException(GatewayError.notAllowed);
    final key = 'EsTx ${fake.nextId('KEY')} fake';
    fake.recoveryKeys[_userId!] = key;
    notifyListeners();
    final delay = fake.securityKeyDelay;
    if (delay != null) await Future<void>.delayed(delay);
    return key;
  }

  @override
  Future<void> restoreSecurity(String recoveryKey) async {
    _requireSession();
    if (fake.recoveryKeys[_userId] != recoveryKey.trim()) throw const GatewayException(GatewayError.invalidInput);
    deviceVerified = true;
    notifyListeners();
  }

  @override
  VerificationInfo? get verification {
    final v = fake.verification;
    if (v == null) return null;
    final isInit = identical(v.initiator, this);
    final isPeer = v.peer != null && identical(v.peer, this);
    if ((!isInit && !isPeer) || v.dismissedBy.contains(this)) return null;
    final peerId = isInit ? v.peerUserId : v.initiator.userId!;
    VerificationPhase phase;
    if (v.cancelled) {
      phase = VerificationPhase.cancelled;
    } else if (v.done) {
      phase = VerificationPhase.done;
    } else if (!v.accepted) {
      phase = isPeer ? VerificationPhase.incomingRequest : VerificationPhase.waiting;
    } else {
      final mine = isInit ? v.initiatorConfirmed : v.peerConfirmed;
      phase = mine ? VerificationPhase.waitingForPeerConfirmation : VerificationPhase.comparing;
    }
    return VerificationInfo(
      phase: phase,
      peerUserId: peerId,
      peerDeviceId: isInit ? null : v.initiator.deviceId,
      emojis: phase == VerificationPhase.comparing ? FakeVerification.emojis : const <VerificationEmoji>[],
      incoming: isPeer,
    );
  }

  /// Gewählter Kontakt-Raum mit beigetretenem Gegenüber (wie `_contactRoomOf` im Gateway).
  String? _contactRoomIdOf(String peer) {
    String? best;
    for (final r in fake.contactRooms.values) {
      if (!r.dmMembers.contains(_userId) || !r.dmMembers.contains(peer) || r.invitedUsers.contains(peer) || r.invitedUsers.contains(_userId)) continue;
      if (_contactClass(r) != RoomClass.contactDirect) continue;
      if (best == null || r.id.compareTo(best) < 0) best = r.id;
    }
    return best;
  }

  bool _contactAllowed(String userId) => VerificationPolicy.contactAllowed(
        contactState: contactPolicy.enabled ? contactPolicy.contacts[userId] : null,
        blocked: contactPolicy.blocked.contains(userId),
        contactRoomId: _contactRoomIdOf(userId),
      );

  /// Dieselbe Regel wie im Gateway ([VerificationPolicy]).
  bool _verificationAllowed(String userId) => VerificationPolicy.allowed(
        userId: userId,
        me: _userId ?? '',
        familyJoined: familyRoom?.membership[userId] == MemberStatus.joined,
        contactState: contactPolicy.enabled ? contactPolicy.contacts[userId] : null,
        blocked: contactPolicy.blocked.contains(userId),
        contactRoomId: _contactRoomIdOf(userId),
      );

  @override
  Future<void> startVerification({required String userId, String? deviceId}) async {
    _requireSession();
    if (fake.verification != null && !fake.verification!.done && !fake.verification!.cancelled) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    if (userId != _userId && !_verificationAllowed(userId)) throw const GatewayException(GatewayError.notAllowed);
    FakeMatrixGateway? peer;
    for (final g in fake._gateways) {
      if (g._userId == userId && !identical(g, this) && (deviceId == null || g.deviceId == deviceId)) peer = g;
    }
    if (peer == null) throw const GatewayException(GatewayError.notFound);
    fake.verification = FakeVerification(this, peer, userId);
    fake.notifyAll();
  }

  @override
  Future<void> acceptVerification() async {
    final v = fake.verification;
    if (v == null || !identical(v.peer, this)) throw const GatewayException(GatewayError.notFound);
    v.accepted = true;
    fake.notifyAll();
  }

  @override
  Future<void> confirmEmojiMatch(bool matches) async {
    final v = fake.verification;
    if (v == null) throw const GatewayException(GatewayError.notFound);
    if (!matches) {
      v.cancelled = true;
      fake.notifyAll();
      return;
    }
    if (identical(v.initiator, this)) {
      v.initiatorConfirmed = true;
    } else {
      v.peerConfirmed = true;
    }
    if (v.initiatorConfirmed && v.peerConfirmed) {
      v.done = true;
      // Beide Geräte desselben Kontos gelten danach als verifiziert.
      if (v.initiator.userId == v.peerUserId) {
        v.initiator.deviceVerified = true;
        v.peer?.deviceVerified = true;
      }
    }
    fake.notifyAll();
  }

  @override
  Future<void> cancelVerification() async {
    final v = fake.verification;
    if (v == null) return;
    if (!v.done) v.cancelled = true;
    v.dismissedBy.add(this);
    final others = <FakeMatrixGateway>[v.initiator, ?v.peer];
    if (others.every(v.dismissedBy.contains)) fake.verification = null;
    fake.notifyAll();
  }

  // ------------------------------------------- Einladungen und Rollen

  @override
  List<PendingInvitation> get invitations {
    final uid = _userId;
    if (uid == null) return const <PendingInvitation>[];
    return <PendingInvitation>[
      for (final id in fake.invites[uid] ?? const <String>[])
        PendingInvitation(
          roomId: id,
          requested: fake.rooms[id]!.knockNonce.containsKey(uid),
          roomName: fake.rooms[id]!.name,
          inviterId: fake.rooms[id]!.power.entries.firstWhere((e) => e.value >= 50).key,
          inviterName: fake.displayNameOf(fake.rooms[id]!.power.entries.firstWhere((e) => e.value >= 50).key),
        ),
    ];
  }

  @override
  bool get joinRequestPending =>
      fake.rooms.values.any((r) => r.membership[_userId] == MemberStatus.requested);

  bool _rejectionAcknowledged = false;

  @override
  bool get joinRequestRejected => !_rejectionAcknowledged && fake.rooms.values.any((r) => r.rejected.contains(_userId));

  /// Im Test frei setzbar; die Oberfläche soll beim Antippen den aktuellen Wert lesen.
  @override
  String joinRequestDiagnostic = 'Zustand: -';

  Family _fam() {
    final f = family;
    if (f == null) throw const GatewayException(GatewayError.notFound);
    return f;
  }

  FamilyMember _mem(Family f, String id) {
    if (!MatrixIds.isUserId(id)) throw const GatewayException(GatewayError.invalidInput);
    final m = f.member(id);
    if (m == null) throw const GatewayException(GatewayError.notFound);
    return m;
  }

  @override
  Future<String> createInviteLink({Duration validity = InviteLink.defaultValidity, String? accountServer}) async {
    final f = _fam();
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom!;
    final nonce = (_nonceCounter++).toRadixString(16).padLeft(32, '0');
    room.issued[nonce] = fake.now().add(validity);
    return InviteLink.create(
      roomId: f.roomId,
      via: fake.host,
      inviter: f.myUserId,
      now: fake.now(),
      validity: validity,
      nonce: nonce,
      ownHost: fake.host,
      inviterName: fake.displayNameOf(f.myUserId),
      accountServer: accountServer,
    );
  }

  static int _nonceCounter = 1;

  @override
  Future<void> requestToJoin(InviteLink link) async {
    _requireSession();
    _require();
    if (!link.isValidAt(fake.now())) throw const GatewayException(GatewayError.invalidInput);
    if (_familyRoomId != null) throw const GatewayException(GatewayError.alreadyExists);
    final room = fake.rooms[link.roomId];
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (room.membership[_userId] == MemberStatus.joined) throw const GatewayException(GatewayError.alreadyExists);
    room.membership[_userId!] = MemberStatus.requested;
    room.power[_userId!] = 0;
    room.knockNonce[_userId!] = link.nonce;
    _rejectionAcknowledged = false;
    room.rejected.remove(_userId);
    fake.notifyAll();
  }

  @override
  Future<void> requestToJoinByCode(String code) async {
    _requireSession();
    _require();
    final roomId = FamilyCode.parse(code);
    if (roomId == null) throw const GatewayException(GatewayError.invalidInput);
    if (_familyRoomId != null) throw const GatewayException(GatewayError.alreadyExists);
    final room = fake.rooms[roomId];
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (room.membership[_userId] == MemberStatus.joined) throw const GatewayException(GatewayError.alreadyExists);
    room.membership[_userId!] = MemberStatus.requested;
    room.power[_userId!] = 0;
    room.knockNonce[_userId!] = 'code';
    _rejectionAcknowledged = false;
    room.rejected.remove(_userId);
    fake.notifyAll();
  }

  @override
  Future<void> cancelJoinRequest() async {
    _rejectionAcknowledged = true;
    for (final r in fake.rooms.values) {
      if (r.membership[_userId] == MemberStatus.requested) {
        r.membership.remove(_userId);
        r.power.remove(_userId);
      }
    }
    fake.notifyAll();
  }

  @override
  Future<void> inviteUser(String userId) async {
    final error = inviteError;
    if (error != null) throw error;
    final f = _fam();
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canInvite(f)) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom!;
    room.membership[userId] = MemberStatus.invited;
    room.power[userId] = 0;
    (fake.invites[userId] ??= <String>[]).add(room.id);
    fake.notifyAll();
  }

  @override
  Future<void> approveRequest(String userId) async {
    final f = _fam();
    final m = _mem(f, userId);
    if (!Permissions.canDecideRequest(f, m)) throw const GatewayException(GatewayError.notAllowed);
    if (m.request != RequestCheck.valid && m.request != RequestCheck.code) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom!;
    room.issued.remove(room.knockNonce[userId]);
    room.membership[userId] = MemberStatus.invited;
    (fake.invites[userId] ??= <String>[]).add(room.id);
    fake.notifyAll();
  }

  @override
  Future<void> rejectRequest(String userId) async {
    final f = _fam();
    final m = _mem(f, userId);
    if (!Permissions.canDecideRequest(f, m) && !Permissions.canRemove(f, m)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    final room = familyRoom!;
    if (room.membership[userId] == MemberStatus.requested) room.rejected.add(userId);
    room.membership.remove(userId);
    room.power.remove(userId);
    fake.invites[userId]?.remove(room.id);
    fake.notifyAll();
  }

  @override
  Future<void> promote(String userId) async {
    final f = _fam();
    final m = _mem(f, userId);
    if (!Permissions.canPromote(f, m)) throw const GatewayException(GatewayError.notAllowed);
    familyRoom!.power[userId] = PowerLevels.moderator;
    fake.notifyAll();
  }

  @override
  Future<void> removeMember(String userId) async {
    final f = _fam();
    final m = _mem(f, userId);
    if (!Permissions.canRemove(f, m)) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom!;
    room.membership.remove(userId);
    room.power.remove(userId);
    room.keyEpoch++; // Schlüsselrotation
    for (final g in fake._gateways) {
      if (g.userId == userId && g._familyRoomId == room.id) g._familyRoomId = null;
    }
    fake.notifyAll();
  }

  @override
  Future<void> renameFamily(String name) async {
    final f = _fam();
    final n = name.trim();
    if (n.isEmpty || n.length > 60) throw const GatewayException(GatewayError.invalidInput);
    if (!Permissions.canConfigure(f)) throw const GatewayException(GatewayError.notAllowed);
    familyRoom!.name = n;
    fake.notifyAll();
  }

  @override
  Future<void> acceptInvitation(String roomId) async {
    _requireSession();
    if (_familyRoomId != null) throw const GatewayException(GatewayError.alreadyExists);
    final list = fake.invites[_userId];
    if (list == null || !list.contains(roomId)) throw const GatewayException(GatewayError.notFound);
    list.remove(roomId);
    final room = fake.rooms[roomId]!;
    room.membership[_userId!] = MemberStatus.joined;
    final existing = fake._gateways.where((g) => g.userId != null && g.userId != _userId).toList();
    _familyRoomId = roomId;
    // Mitglieder werden über den Beitritt informiert (Resync).
    for (final g in existing) {
      if (room.membership[g.userId] == MemberStatus.joined) {
        g._signals.add(MemberJoinedSignal(_userId!, DateTime.utc(2026, 10, 21, 12)));
      }
    }
    fake.notifyAll();
  }

  @override
  Future<void> declineInvitation(String roomId) async {
    _requireSession();
    final list = fake.invites[_userId];
    if (list == null || !list.contains(roomId)) throw const GatewayException(GatewayError.notFound);
    list.remove(roomId);
    fake.rooms[roomId]!.membership.remove(_userId);
    fake.notifyAll();
  }

  /// Test-Hook: ein (ggf. gefälschtes) Signal direkt zustellen.
  void injectSignal(CalendarSignal s) => _signals.add(s);

  /// Test-Hook: Ausfall der Verbindung für Veröffentlichungen simulieren.
  bool failPublishes = false;

  /// Test-Hook: Zahl der Sendeversuche (`publish*`), auch der fehlgeschlagenen (#132).
  int publishAttempts = 0;

  FakeRoom _privateRoom() => fake.privateRooms.putIfAbsent(
        _userId!,
        () => FakeRoom('${fake.nextId('!private')}:${fake.host}', 'privat')..membership[_userId!] = MemberStatus.joined,
      );

  @override
  Future<void> publishSharedEvent(CalendarEvent event) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodeShared(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, EventCodec.sharedType, content);
  }

  @override
  Future<void> publishPrivateEvent(CalendarEvent event) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodePrivate(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(_privateRoom(), _userId!, EventCodec.privateType, content);
  }

  @override
  Future<void> publishRsvp(String eventId, RsvpStatus status, DateTime timestamp) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    fake.post(room, _userId!, EventCodec.rsvpType, EventCodec.encodeRsvp(eventId, status, timestamp));
  }

  @override
  Future<void> shareEventInChat(CalendarEvent event) async {
    _requireSession();
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (!event.isShared || event.deleted) throw const GatewayException(GatewayError.invalidInput);
    fake.post(room, _userId!, 'm.room.message', <String, Object?>{'body': event.title, 'event_ref': event.id});
  }

  @override
  Future<void> loadOlderMessages({String threadId = ChatThread.familyId}) async {
    loadedOlder.add(threadId);
  }

  /// Test (#423): Gespräche, für die gelesen markiert bzw. nachgeladen wurde, in der Reihenfolge der Aufrufe.
  final List<String> markedRead = <String>[];

  /// Test (#526): je Aufruf von [markChatRead], ob die Lesebestätigung öffentlich gewesen wäre.
  final List<bool> markedReadPublic = <bool>[];
  final List<String> loadedOlder = <String>[];

  @override
  Future<void> restore() async {}

  /// Anzahl der Anbieterprüfungen (#272: nach „Alle lokalen Daten löschen“ keine).
  int probeCalls = 0;

  /// Hosts der Anbieterprüfungen in der Reihenfolge (#545: nach einer verworfenen Einladung kein Abruf des alten Servers).
  final List<String> probedHosts = <String>[];

  @override
  Future<ServerInfo> probeServer(ServerUrl url) async {
    probeCalls++;
    probedHosts.add(url.host);
    _require();
    if (url.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    return ServerInfo(
      url: url,
      versions: const <String>['v1.11'],
      supportsPasswordLogin: fake.registrationMode != RegistrationMode.oauth,
      contact: fake.operatorName,
      usesOAuth: fake.registrationMode == RegistrationMode.oauth,
    );
  }

  // ------------------------------------------------- Kontoanlage (E-55)

  _FakeRegistration? _reg;
  String? _oauthState;
  bool _oauthCreate = false;
  int _oauthSeq = 0;

  /// Zuletzt vorbereitete Anmeldung im Browser (Adresse, die die App öffnen soll).
  Uri? lastOAuthUri;

  @override
  Future<RegistrationOptions> registrationOptions(ServerUrl server) async {
    _require();
    if (server.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    final mode = fake.registrationMode == RegistrationMode.inApp && !RegistrationFlows.anySupported(fake.registrationFlows)
        ? RegistrationMode.disabled
        : fake.registrationMode;
    return RegistrationOptions(mode: mode, webPage: fake.registrationWebPage);
  }

  @override
  Future<UsernameCheck> checkUsername(ServerUrl server, String username) async {
    if (!fake.reachable) return UsernameCheck.unknown;
    if (!UsernameSuggestion.isValid(username)) return UsernameCheck.invalid;
    return fake.hasAccount(username) ? UsernameCheck.taken : UsernameCheck.available;
  }

  @override
  Future<RegistrationStage?> register({
    required ServerUrl server,
    required String username,
    required String password,
    required String displayName,
    String language = 'de',
  }) async {
    _require();
    fake.registerCalls++;
    await fake.registerGate?.future;
    if (_userId != null) throw const GatewayException(GatewayError.notAllowed);
    if (server.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    if (!UsernameSuggestion.isValid(username)) throw const GatewayException(GatewayError.usernameInvalid);
    if (password.length < 8) throw const GatewayException(GatewayError.weakPassword);
    if (fake.registrationMode != RegistrationMode.inApp) throw const GatewayException(GatewayError.registrationDisabled);
    if (fake.hasAccount(username)) throw const GatewayException(GatewayError.usernameTaken);
    if (!RegistrationFlows.anySupported(fake.registrationFlows)) throw const GatewayException(GatewayError.registrationDisabled);
    _reg = _FakeRegistration(username, password, displayName.trim());
    return _advance(null);
  }

  /// Nächster offener Schritt; `dummy` erledigt die App selbst.
  RegistrationStage? _advance(String? tried) {
    final r = _reg!;
    final next = RegistrationFlows.next(fake.registrationFlows, r.completed);
    switch (next) {
      case null:
        final id = fake.addAccount(r.username, r.password!, displayName: r.displayName.isEmpty ? r.username : r.displayName);
        r.password = null;
        _reg = null;
        _userId = id;
        _server = ServerUrl.tryParse(fake.host);
        notifyListeners();
        return null;
      case RegistrationFlows.dummy:
        r.completed.add(RegistrationFlows.dummy);
        return _advance(RegistrationFlows.dummy);
      case RegistrationFlows.terms:
        return TermsStage(<TermsPolicy>[TermsPolicy(name: 'Nutzungsbedingungen', url: Uri.parse('https://${fake.host}/terms'))]);
      case RegistrationFlows.token:
        return TokenStage(wrong: tried == RegistrationFlows.token);
      case RegistrationFlows.recaptcha:
        return CaptchaStage(Uri.parse('https://${fake.host}/captcha?session=s1'), notDoneYet: tried == RegistrationFlows.recaptcha);
      case RegistrationFlows.email:
        return EmailStage(sent: r.emailSent, notConfirmedYet: tried == RegistrationFlows.email);
      default:
        throw const GatewayException(GatewayError.unknown);
    }
  }

  /// `true`, solange eine Registrierung läuft (Test: Passwort liegt nur hier).
  bool get registrationInProgress => _reg != null;

  @override
  Future<RegistrationStage?> continueRegistration(RegistrationInput input) async {
    _require();
    final r = _reg;
    if (r == null) throw const GatewayException(GatewayError.notFound);
    switch (input) {
      case AcceptTerms():
        r.completed.add(RegistrationFlows.terms);
        return _advance(RegistrationFlows.terms);
      case SubmitToken(:final token):
        if (token.trim() == fake.registrationToken) r.completed.add(RegistrationFlows.token);
        return _advance(RegistrationFlows.token);
      case CaptchaDone():
        if (fake.captchaSolved) r.completed.add(RegistrationFlows.recaptcha);
        return _advance(RegistrationFlows.recaptcha);
      case SubmitEmail(:final email):
        if (!isPlausibleEmail(email)) throw const GatewayException(GatewayError.invalidInput);
        if (fake.emailsInUse.contains(email.trim())) throw const GatewayException(GatewayError.emailInUse);
        fake.emailsSent.add(email.trim());
        r.emailSent = true;
        return const EmailStage(sent: true);
      case EmailConfirmed():
        if (!r.emailSent) return const EmailStage();
        if (fake.emailConfirmed) r.completed.add(RegistrationFlows.email);
        return _advance(RegistrationFlows.email);
    }
  }

  @override
  void cancelRegistration() {
    _reg?.password = null;
    _reg = null;
  }

  @override
  Future<Uri> startOAuth({required ServerUrl server, required Uri redirectUri, required bool create}) async {
    _require();
    if (_userId != null) throw const GatewayException(GatewayError.notAllowed);
    if (server.host != fake.host || fake.registrationMode != RegistrationMode.oauth) {
      throw const GatewayException(GatewayError.serverUnsupported);
    }
    _oauthState = 'state${++_oauthSeq}';
    _oauthCreate = create;
    final uri = Uri.https('account.${fake.host}', '/authorize', <String, String>{
      'redirect_uri': '$redirectUri',
      'state': _oauthState!,
      'prompt': ?(create ? 'create' : null),
    });
    lastOAuthUri = uri;
    return uri;
  }

  /// Test-Hilfe: Rücksprung, den der Anbieter nach Anmeldung bzw. Kontoanlage von [localpart] sendet.
  Uri oauthCallback(String localpart, {Uri? redirect, String? state, bool denied = false}) {
    final base = redirect ?? Uri.parse(lastOAuthUri!.queryParameters['redirect_uri']!);
    return base.replace(queryParameters: <String, String>{
      if (denied) 'error': 'access_denied' else 'code': localpart,
      'state': state ?? lastOAuthUri!.queryParameters['state']!,
    });
  }

  @override
  Future<void> completeOAuth(Uri callback) async {
    final expected = _oauthState;
    final p = callback.queryParameters;
    final code = p['code'];
    if (expected == null) throw const GatewayException(GatewayError.oauthCancelled);
    // Wie das echte Gateway: fremder state wird verworfen, die Anmeldung bleibt offen.
    if (p['state'] != expected) throw const GatewayException(GatewayError.oauthStateMismatch);
    _oauthState = null;
    if (p.containsKey('error') || code == null) {
      throw GatewayException(p['error'] == 'access_denied' ? GatewayError.oauthAborted : GatewayError.oauthCancelled);
    }
    final id = '@$code:${fake.host}';
    if (!fake._accounts.containsKey(id)) {
      if (!_oauthCreate) throw const GatewayException(GatewayError.invalidCredentials);
      fake.addAccount(code, 'oauth-only');
    }
    _userId = id;
    _viaOAuth = true;
    _server = ServerUrl.tryParse(fake.host);
    for (final r in fake.rooms.values) {
      if (r.membership[id] == MemberStatus.joined) {
        _familyRoomId = r.id;
        break;
      }
    }
    notifyListeners();
  }

  @override
  Future<void> setDisplayName(String name) async {
    _requireSession();
    final n = name.trim();
    if (n.isEmpty) throw const GatewayException(GatewayError.invalidInput);
    fake._accounts[_userId]!.displayName = n;
    fake.notifyAll();
  }

  @override
  Future<void> login({required ServerUrl server, required String username, required String password}) async {
    _require();
    if (server.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    final account = fake._accounts[username.startsWith('@') ? username : '@$username:${fake.host}'];
    if (account == null || account.password != password) {
      throw const GatewayException(GatewayError.invalidCredentials);
    }
    _userId = account.userId;
    _server = server;
    // Wie die Kontodaten in Matrix: Ist das Konto bereits Mitglied einer Familie, kennt auch ein neues Gerät sie.
    for (final r in fake.rooms.values) {
      if (r.membership[account.userId] == MemberStatus.joined) {
        _familyRoomId = r.id;
        break;
      }
    }
    notifyListeners();
  }

  @override
  Future<void> close() async {}

  @override
  Future<OnlineInventory> dataInventory({bool refresh = true}) async {
    final uid = _userId;
    if (uid == null) throw const GatewayException(GatewayError.notAllowed);
    final room = familyRoom;
    return OnlineInventory(
      server: 'https://${fake.host}',
      homeserver: 'https://${fake.host}',
      userId: uid,
      deviceId: deviceId,
      displayName: fake.displayNameOf(uid),
      hasAvatar: false,
      devices: devices,
      crossSigning: fake.recoveryKeys.containsKey(uid),
      keyBackup: fake.recoveryKeys.containsKey(uid),
      accountDataTypes: <String>[if (room != null) 'de.inneso.familynexus.family'],
      rooms: <InventoryRoom>[
        if (room != null)
          InventoryRoom(
            id: room.id,
            kind: InventoryRoomKind.family,
            name: room.name,
            encrypted: room.encrypted,
            membership: 'join',
            joinedMembers: room.membership.values.where((m) => m == MemberStatus.joined).length,
            invitedMembers: room.membership.values.where((m) => m == MemberStatus.invited).length,
            cachedEvents: room.events.length,
            eventTypes: <String, int>{
              for (final e in room.events) e.type: room.events.where((x) => x.type == e.type).length,
            },
            attachments: 0,
          ),
      ],
      family: family,
    );
  }

  /// Anmeldung im Browser (OAuth): Das Konto wird dann beim Anbieter gelöscht.
  bool _viaOAuth = false;

  @override
  Future<AccountDeletion> accountDeletion() async {
    _requireSession();
    _require();
    if (!_viaOAuth) return const AccountDeletionInApp();
    final page = fake.accountManagementPage;
    if (page == null) throw const GatewayException(GatewayError.serverUnsupported);
    return AccountDeletionInBrowser(page);
  }

  @override
  Future<PasswordChange> passwordChange() async {
    _requireSession();
    _require();
    final forced = fake.passwordChangeMode;
    if (forced != null) return forced;
    if (!_viaOAuth) return const PasswordChangeInApp();
    final page = fake.accountManagementPage;
    return page == null ? const PasswordChangeUnavailable() : PasswordChangeInBrowser(page);
  }

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword, required bool logoutOtherDevices}) async {
    _requireSession();
    _require();
    fake.passwordChangeCalls++;
    fake.lastLogoutOtherDevices = logoutOtherDevices;
    await fake.passwordChangeGate?.future;
    final failure = fake.passwordChangeFailure;
    if (failure != null) {
      fake.passwordChangeFailure = null;
      throw failure;
    }
    if (_viaOAuth) throw const GatewayException(GatewayError.notAllowed);
    if (newPassword.length < PasswordChange.minLength) throw const GatewayException(GatewayError.weakPassword);
    final account = fake._accounts[_userId];
    if (account?.password != oldPassword) throw const GatewayException(GatewayError.invalidCredentials);
    account!.password = newPassword;
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    _requireSession();
    _require();
    if (_viaOAuth) throw const GatewayException(GatewayError.notAllowed);
    if (password.isEmpty) throw const GatewayException(GatewayError.invalidInput);
    if (fake._accounts[_userId]?.password != password) throw const GatewayException(GatewayError.invalidCredentials);
    fake.deactivateAccount(_userId!);
    await logout();
  }

  @override
  Future<bool> checkAccountDeleted() async {
    final uid = _userId;
    if (uid == null) return true;
    _require();
    if (fake._accounts.containsKey(uid)) return false;
    await logout();
    return true;
  }

  @override
  Future<void> logout() async {
    cancelRegistration();
    _sessionEndedByServer = false;
    _oauthState = null;
    _viaOAuth = false;
    _userId = null;
    _server = null;
    _familyRoomId = null;
    _presence.clear();
    _read.clear();
    notifyListeners();
  }

  @override
  Future<void> createFamily(String name) async {
    _requireSession();
    _require();
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 60) throw const GatewayException(GatewayError.invalidInput);
    if (_familyRoomId != null) throw const GatewayException(GatewayError.alreadyExists);
    final room = FakeRoom('${fake.nextId('!room')}:${fake.host}', trimmed)
      ..membership[_userId!] = MemberStatus.joined
      ..power[_userId!] = PowerLevels.admin;
    fake.rooms[room.id] = room;
    _familyRoomId = room.id;
    fake.notifyAll();
  }

  FakeRoom _chatRoom(String threadId) {
    _requireSession();
    final room = _roomOf(threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    // Gruppen (K4-2b): das Tor wie im Gateway (§3.3), auf dem für das Gateway sichtbaren Mitgliederstand.
    if (fake.groupRooms.containsKey(threadId)) _requireGroupGate(room, threadId);
    // Kontakt-Räume: Senden nur nach `openThread` und bei beigetretenem Gegenüber (nie in wartenden Räumen).
    if (fake.contactRooms.containsKey(threadId)) {
      final peer = room.dmMembers.firstWhere((m) => m != _userId);
      if (!_opened.contains(threadId) || room.invitedUsers.contains(peer)) throw const GatewayException(GatewayError.notAllowed);
      if (fake.identityChangedUsers.contains(peer)) throw const GatewayException(GatewayError.notAllowed); // vor „nicht erreichbar“
      if (_reachOf(peer) == ContactReachability.notReachable) throw const GatewayException(GatewayError.peerNotReachable);
    }
    return room;
  }

  @override
  Future<void> sendMessage(String text, {String? replyToId, String threadId = ChatThread.familyId}) async {
    final room = _chatRoom(threadId);
    if (text.trim().isEmpty) throw const GatewayException(GatewayError.invalidInput);
    await fake.sendGate?.future;
    // Wie das Gateway: bei geändertem Schlüssel des Kontakts (auch erst während des Sendens) `notAllowed`.
    final cr = fake.contactRooms[threadId];
    if (cr != null && fake.identityChangedUsers.contains(cr.dmMembers.firstWhere((m) => m != _userId))) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    fake.post(room, _userId!, 'm.room.message', <String, Object?>{
      'body': text,
      'reply_to': ?replyToId,
    });
  }

  @override
  Future<void> sendReaction(String messageId, String emoji, {String threadId = ChatThread.familyId}) async {
    // Seit K4-2b (§3.5) auch in Kontakt- und Gruppenräumen, über dieselben Tore wie der Text; kein Ziel eines Blockierten.
    final room = _chatRoom(threadId);
    if (emoji.isEmpty || emoji.length > 16) throw const GatewayException(GatewayError.invalidInput);
    final target = room.events.where((e) => e.id == messageId).firstOrNull;
    if (target != null &&
        (fake.contactRooms.containsKey(threadId) || fake.groupRooms.containsKey(threadId)) &&
        contactPolicy.blocked.contains(target.sender)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    fake.post(room, _userId!, 'm.reaction', <String, Object?>{'target': messageId, 'emoji': emoji});
  }

  @override
  Future<void> reportMessage(ReportRequest request) async {
    final room = _chatRoom(request.threadId);
    final event = room.events.where((e) => e.id == request.messageId && e.type == 'm.room.message').firstOrNull;
    if (event == null) throw const GatewayException(GatewayError.notFound);
    if (event.sender == _userId) throw const GatewayException(GatewayError.notAllowed);
    fake.reports.add((reporter: _userId!, roomId: room.id, eventId: event.id, reason: request.reason));
  }

  @override
  Future<void> sendAttachment({
    required String fileName,
    required Uint8List bytes,
    String? replyToId,
    String threadId = ChatThread.familyId,
  }) async {
    final room = _chatRoom(threadId);
    final name = AttachmentPolicy.sanitizeFileName(fileName);
    if (AttachmentPolicy.check(fileName: name, bytes: bytes) != null) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    final e = fake.post(room, _userId!, 'm.room.message', <String, Object?>{
      'body': name,
      'file_name': name,
      'mime': AttachmentPolicy.mimeForName(name),
      'size': bytes.length,
      'reply_to': ?replyToId,
    });
    _files[e.id] = bytes;
  }

  /// Sendestand einzelner Nachrichten für Widget-Tests: Kennung → Status und Wiederholbarkeit.
  final Map<String, ({MessageStatus status, bool retryable})> sendStates = <String, ({MessageStatus status, bool retryable})>{};

  /// Kennungen, die der Chat als nicht entschlüsselbar zeigt.
  final Set<String> undecryptable = <String>{};

  /// Kennungen, für die [retryMessage] aufgerufen wurde, und der jeweilige Thread.
  final List<String> retried = <String>[];
  final List<String> retriedThreads = <String>[];

  @override
  Future<void> retryMessage(String messageId, {String threadId = ChatThread.familyId}) async {
    retried.add(messageId);
    retriedThreads.add(threadId);
  }

  @override
  Future<Uint8List> loadAttachment(String messageId, {String threadId = ChatThread.familyId}) async {
    for (final g in fake._gateways) {
      final f = g._files[messageId];
      if (f != null) return f;
    }
    throw const GatewayException(GatewayError.notFound);
  }

  /// Für Tests (#31): Ein neu eröffneter Einzelchat erscheint erst später in [threads] – wie beim echten
  /// Server, wo der Raum erst mit einem späteren Abgleich vollständig geladen ist.
  bool delayNewDirectChats = false;
  final Set<String> hiddenThreads = <String>{};

  /// Test (#574): Hält [startDirectChat] nach der Prüfung an, bis der Completer erfüllt ist (steuert das Warten).
  Completer<void>? holdDirectChat;

  @override
  Future<String> startDirectChat(String userId) async {
    _requireSession();
    _require();
    final f = _fam();
    final m = _mem(f, userId);
    if (userId == _userId || m.status != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    final hold = holdDirectChat;
    if (hold != null) await hold.future;
    for (final r in fake.dmRooms.values) {
      if (r.dmMembers.contains(_userId) && r.dmMembers.contains(userId)) return r.id;
    }
    final room = FakeRoom('${fake.nextId('!dm')}:${fake.host}', 'dm')..dmMembers.addAll(<String>[_userId!, userId]);
    if (delayNewDirectChats) hiddenThreads.add(room.id);
    fake.dmRooms[room.id] = room;
    fake.notifyAll();
    return room.id;
  }

  // ------------------------------------------------------ Online-Status

  final Map<String, PresenceStamp> _presence = <String, PresenceStamp>{};
  // ignore: close_sinks
  final StreamController<String> _asks = StreamController<String>.broadcast(sync: true);

  @override
  Map<String, PresenceStamp> get presence {
    final joined = family?.joined.map((m) => m.userId).toSet() ?? const <String>{};
    return <String, PresenceStamp>{
      for (final e in _presence.entries)
        if (joined.contains(e.key)) e.key: e.value,
    };
  }

  @override
  Stream<String> get presenceAsks => _asks.stream;

  @override
  Future<void> announcePresence({required bool online, bool ask = false, String? onlyTo}) async {
    _requireSession();
    _require();
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notAllowed);
    if (onlyTo != null && !MatrixIds.isUserId(onlyTo)) throw const GatewayException(GatewayError.invalidInput);
    final to = <String>[];
    for (final g in fake._gateways) {
      final uid = g._userId;
      if (uid == null || uid == _userId || (onlyTo != null && uid != onlyTo)) continue;
      if (room.membership[uid] != MemberStatus.joined || g._familyRoomId != room.id) continue;
      if (!to.contains(uid)) to.add(uid);
      // Echte Uhr: Anzeige und Gültigkeit des Status hängen von der aktuellen Zeit ab (nicht von der Test-Uhr der Einladungen).
      final real = DateTime.now().toUtc();
      final c = PresenceCodec.decode(PresenceCodec.encode(online: online, now: real, ask: ask), now: real)!;
      final old = g._presence[_userId!];
      // Die Test-Uhr steht still; spätere Meldungen sind trotzdem strikt neuer.
      final at = (old != null && !c.at.isAfter(old.at)) ? old.at.add(const Duration(milliseconds: 1)) : c.at;
      g._presence[_userId!] = PresenceStamp(online: c.online, at: at);
      g.notifyListeners();
      if (c.ask) g._asks.add(_userId!);
    }
    fake.presenceLog.add((sender: _userId!, online: online, ask: ask, to: to));
  }

  // -------------------------------------------------------- Einkaufszettel

  @override
  Future<void> publishShoppingItem(ShoppingItem item) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (item.by != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = ShoppingCodec.encode(item);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, ShoppingCodec.type, content);
  }

  // ----------------------------------------------------------- Aufgabenlisten

  @override
  Future<void> publishTaskList(TaskList list) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (list.by != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeList(list);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, TaskCodec.listType, content);
  }

  // ---------------------------------------------------------- Kalender-Themen

  @override
  Future<void> publishEventTheme(EventTheme theme) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (theme.by != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = EventThemeCodec.encode(theme);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, EventThemeCodec.type, content);
  }

  // ------------------------------------------------------------ Avatar-Fotos

  /// Test: Ereignis-IDs, die `redactOwnEvent` geschwärzt hat.
  final List<String> redactedEvents = <String>[];

  /// Test: `redactOwnEvent` scheitert mit diesem Fehler.
  GatewayError? redactError;

  /// Test: `publishAvatarPhoto` scheitert mit diesem Fehler.
  GatewayError? publishAvatarError;

  @override
  Future<String> publishAvatarPhoto(AvatarPhoto photo) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final avatarError = publishAvatarError;
    if (avatarError != null) throw GatewayException(avatarError);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (photo.owner != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = AvatarPhotoCodec.encode(photo);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    return fake.post(room, _userId!, AvatarPhotoCodec.type, content).id;
  }

  @override
  Future<void> publishAvatarReset(AvatarReset reset) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    final Map<String, Object?> content;
    try {
      content = AvatarResetCodec.encode(reset);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, AvatarResetCodec.type, content);
  }

  @override
  Future<void> redactOwnEvent(String eventId) async {
    _requireSession();
    _require();
    final err = redactError;
    if (err != null) throw GatewayException(err);
    redactedEvents.add(eventId);
  }

  // ------------------------------------------------- Geburts- und Gedenktage

  @override
  Future<void> publishAnniversary(AnniversaryPerson person) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (person.by != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = AnniversaryCodec.encode(person);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, AnniversaryCodec.type, content);
  }

  /// Zuletzt gesetzte Kontaktrichtlinie und die Zahl der Änderungen (Tests).
  ContactPolicy contactPolicy = ContactPolicy.off;
  int contactPolicyChanges = 0;

  @override
  void setContactPolicy(ContactPolicy policy) {
    if (policy == contactPolicy) return;
    contactPolicy = policy;
    contactPolicyChanges++;
    _autoAcceptContacts();
    notifyListeners();
  }

  // ------------------------------------------------ Kontakt-Einzelchats (#119, K3a-2)

  final Set<String> _opened = <String>{};

  /// Dieselbe reine Einstufung wie im echten Gateway ([ConversationPolicy]), damit beide nicht auseinanderlaufen.
  PolicyContext? _contactContext() {
    // Wie das Gateway seit K3c-1: Der Kontext braucht keine Familie (das Konto genügt).
    final f = family;
    final me = _userId;
    if (me == null) return null;
    return PolicyContext(
      myUserId: me,
      familyRoomId: f?.roomId,
      joinedMembers: <String>{for (final m in f?.joined ?? const <FamilyMember>[]) m.userId},
      membersLoaded: true,
      contactsEnabled: contactPolicy.enabled,
      contacts: contactPolicy.contacts,
      blockedUsers: contactPolicy.blocked,
      familyIds: <String>{for (final m in f?.members ?? const <FamilyMember>[]) m.userId},
      groups: contactPolicy.groups,
    );
  }

  RoomFacts? _contactFacts(FakeRoom r) {
    final me = _userId;
    if (me == null || !r.dmMembers.contains(me)) return null;
    final other = r.dmMembers.firstWhere((m) => m != me);
    if (r.invitedUsers.contains(me)) {
      return RoomFacts(id: r.id, membership: RoomMembership.invite, inviterId: other, inviteIsDirect: true, joinedCount: 1, invitedCount: 1, joinRule: 'invite');
    }
    return RoomFacts(
      id: r.id,
      membership: RoomMembership.join,
      peerId: other,
      megolm: true,
      joinedCount: 2 - r.invitedUsers.length,
      invitedCount: r.invitedUsers.length,
      peerMembership: r.invitedUsers.contains(other) ? PeerMembership.invite : PeerMembership.join,
    );
  }

  RoomClass _contactClass(FakeRoom r) {
    final ctx = _contactContext();
    final facts = _contactFacts(r);
    if (ctx == null || facts == null) return RoomClass.ignored;
    return ConversationPolicy.classify(facts, ctx);
  }

  FakeRoom? _contactRoomOf(String threadId) {
    final r = fake.contactRooms[threadId];
    return r != null && _contactClass(r) == RoomClass.contactDirect ? r : null;
  }

  IdentityStatus _contactIdentityOf(String peer, {required bool pending}) {
    if (pending) return IdentityStatus.unknown;
    if (fake.identityChangedUsers.contains(peer)) return IdentityStatus.changed;
    return fake.contactIdentities[peer] ?? IdentityStatus.unknown;
  }

  List<ChatThread> _contactThreads() {
    final me = _userId;
    return <ChatThread>[
      for (final r in fake.contactRooms.values)
        if (_contactClass(r) == RoomClass.contactDirect)
          ChatThread(
            id: r.id,
            kind: ThreadKind.contact,
            title: ContactNames.title(fake.displayNameOf(r.dmMembers.firstWhere((m) => m != me)), r.dmMembers.firstWhere((m) => m != me)),
            peerId: r.dmMembers.firstWhere((m) => m != me),
            peerName: ContactNames.cleanName(fake.displayNameOf(r.dmMembers.firstWhere((m) => m != me))),
            unread: unreadIn(r.id),
            pending: r.invitedUsers.contains(r.dmMembers.firstWhere((m) => m != me)),
            reachable: _reachOf(r.dmMembers.firstWhere((m) => m != me)) != ContactReachability.notReachable,
            identity: _contactIdentityOf(r.dmMembers.firstWhere((m) => m != me), pending: r.invitedUsers.contains(r.dmMembers.firstWhere((m) => m != me))),
          ),
    ]..sort((a, b) => a.title.compareTo(b.title));
  }

  /// Einladungen eigener Kontakte werden angenommen (wie `autoAcceptContact` im Gateway), je Einladendem die kleinste ID.
  void _autoAcceptContacts() {
    final ctx = _contactContext();
    final me = _userId;
    if (ctx == null || me == null) return;
    final byFrom = <String, FakeRoom>{};
    for (final r in fake.contactRooms.values) {
      final facts = _contactFacts(r);
      if (facts == null || !ConversationPolicy.autoAcceptContact(facts, ctx)) continue;
      final cur = byFrom[facts.inviterId!];
      if (cur == null || r.id.compareTo(cur.id) < 0) byFrom[facts.inviterId!] = r;
    }
    for (final e in byFrom.entries) {
      final hasJoined = fake.contactRooms.values.any((r) => r.dmMembers.contains(me) && r.dmMembers.contains(e.key) && !r.invitedUsers.contains(me) && !r.invitedUsers.contains(e.key));
      if (!hasJoined) e.value.invitedUsers.remove(me);
    }
  }

  // ------------------------------------------------ Gruppen (#119, K4-2a)

  /// Test: `createGroup` scheitert mit diesem Fehler; `acceptGroupInvite` scheitert beim Beitritt mit diesem Fehler.
  GatewayError? createGroupError;
  GatewayError? acceptGroupError;
  final Set<String> _createdGroups = <String>{};
  final Set<String> _leftGroups = <String>{};
  /// Test: simuliert eine laufende Anlage (die zweite ergibt `alreadyExists`).
  bool groupCreationRunning = false;

  /// Test: Zahl der Aufrufe von `createGroup` und `acceptGroupInvite`.
  int createGroupCalls = 0;
  int acceptGroupCalls = 0;

  RoomFacts? _groupFacts(FakeRoom r) {
    final me = _userId;
    if (me == null || !r.dmMembers.contains(me)) return null;
    final invited = r.invitedUsers.length;
    final joined = r.dmMembers.length - invited;
    if (r.invitedUsers.contains(me)) {
      return RoomFacts(id: r.id, membership: RoomMembership.invite, inviterId: r.groupInviter, joinRule: r.joinRule, joinedCount: joined, invitedCount: invited);
    }
    return RoomFacts(id: r.id, membership: RoomMembership.join, megolm: r.groupEncrypted, joinedCount: joined, invitedCount: invited);
  }

  RoomClass _groupClass(FakeRoom r) {
    final ctx = _contactContext();
    final facts = _groupFacts(r);
    if (ctx == null || facts == null) return RoomClass.ignored;
    return ConversationPolicy.classify(facts, ctx);
  }

  FakeRoom? _groupRoomOf(String threadId) {
    final r = fake.groupRooms[threadId];
    return r != null && _groupClass(r) == RoomClass.contactGroup ? r : null;
  }

  // ---- Gruppen: Mitgliederwechsel, Zustandsverzögerung und Wisch (K4-2b)

  /// Außensitzung der Gruppen (Fake des SDK-Verhaltens, `fake_outbound_session_port.dart`).
  final FakeOutboundSessionPort outboundPort = FakeOutboundSessionPort();
  final Map<String, Set<String>> _lastGroupMembers = <String, Set<String>>{};
  final Map<String, Set<String>> _laggedMembers = <String, Set<String>>{};

  /// Räume mit fälligem oder gescheitertem Wisch: Senden `groupBusy`.
  final Set<String> groupPendingWipe = <String>{};

  /// Mitglieder (beigetreten und eingeladen), wie das Gateway sie sieht; mit [lagGroupState] bleibt der alte Stand sichtbar.
  Set<String> _visibleMembers(FakeRoom r) => _laggedMembers[r.id] ?? r.dmMembers.toSet();

  /// Test: das Gateway sieht Änderungen der Mitglieder dieser Gruppe erst nach [releaseGroupState] (Zustandsverzögerung).
  void lagGroupState(String roomId) => _laggedMembers[roomId] = fake.groupRooms[roomId]!.dmMembers.toSet();

  Future<void> releaseGroupState(String roomId) async {
    _laggedMembers.remove(roomId);
    await syncGroups();
  }

  /// Test: ein Mitglied verlässt die Gruppe oder wird entfernt (auch ein nur Eingeladener).
  void removeGroupMember(String roomId, String userId) {
    final r = fake.groupRooms[roomId]!;
    r.dmMembers.remove(userId);
    r.invitedUsers.remove(userId);
    fake.notifyAll();
  }

  /// Der Mitgliederabgleich des Gateways (je Sync): Weggang ⇒ Laden, Wisch, Beleg; ohne Beleg bleibt der Raum gesperrt.
  Future<void> syncGroups() async {
    for (final r in fake.groupRooms.values.toList()) {
      if (_groupClass(r) != RoomClass.contactGroup) continue;
      final cur = _visibleMembers(r);
      final base = _lastGroupMembers[r.id];
      final lost = base != null && base.difference(cur).isNotEmpty;
      if (lost || groupPendingWipe.contains(r.id)) {
        await outboundPort.load(r.id);
        if (outboundPort.recipients(r.id) != null) await outboundPort.wipe(r.id);
        if (outboundPort.recipients(r.id) == null) {
          groupPendingWipe.remove(r.id);
        } else {
          groupPendingWipe.add(r.id);
        }
      }
      _lastGroupMembers[r.id] = cur;
    }
    fake.notifyAll();
  }

  void _requireGroupGate(FakeRoom room, String threadId) {
    final me = _userId;
    if (!_opened.contains(threadId)) throw const GatewayException(GatewayError.notAllowed);
    if (groupPendingWipe.contains(threadId) || _removingGroups.contains(threadId)) throw GatewayException(groupSendLockError(GroupSendLock.wechsel)!);
    final lock = _groupLock(room);
    final e = groupSendLockError(lock);
    if (e != null) throw GatewayException(e);
    final others = _visibleMembers(room).where((m) => m != me).toList();
    if (others.isEmpty) throw GatewayException(groupSendLockError(GroupSendLock.keineMitglieder)!);
    var reachable = 0;
    var unreachable = 0;
    for (final m in others) {
      final r = fake.identityChangedUsers.contains(m) ? ContactReachability.identityChanged : _reachOf(m);
      if (r == ContactReachability.reachable) {
        reachable++;
      } else if (r != ContactReachability.unknown) {
        unreachable++;
      }
    }
    if (reachable == 0) throw GatewayException(unreachable > 0 ? GatewayError.peerNotReachable : GatewayError.serverUnreachable);
  }

  GroupSendLock _groupLock(FakeRoom r) {
    if (groupPendingWipe.contains(r.id) || _removingGroups.contains(r.id)) return GroupSendLock.wechsel;
    final health = GroupHealth.evaluate(
      megolm: r.groupEncrypted,
      joinRule: r.joinRule,
      historyVisibility: r.history,
      joined: _visibleMembers(r).length,
      invited: 0,
    );
    if (health != GroupSendLock.keiner) return health;
    return _visibleMembers(r).where((m) => m != _userId).isEmpty ? GroupSendLock.keineMitglieder : GroupSendLock.keiner;
  }

  List<ChatThread> _groupThreads() {
    for (final r in fake.groupRooms.values) {
      if (_groupClass(r) == RoomClass.contactGroup) _lastGroupMembers.putIfAbsent(r.id, () => _visibleMembers(r));
    }
    return <ChatThread>[
      for (final r in fake.groupRooms.values)
        if (_groupClass(r) == RoomClass.contactGroup)
          ChatThread(
            id: r.id,
            kind: ThreadKind.group,
            title: ContactNames.groupTitle(r.name),
            unread: unreadIn(r.id),
            memberCount: _visibleMembers(r).length,
            canManage: (r.power[_userId] ?? 0) >= PowerLevels.moderator,
            sendLock: _groupLock(r),
          ),
    ];
  }

  // ---- Gruppen: Verwaltung (K4-3)

  /// Räume mit laufendem Entfernen: das Senden ist `groupBusy`, bis der Test [completeRemoval] ruft (der Weggang ist dann im
  /// Zustand angekommen und der Abgleich gelaufen).
  final Set<String> _removingGroups = <String>{};

  /// Test: die nächste Verwaltungsoperation (Einladen, Entfernen, Admin ändern, Mitglieder) scheitert mit diesem Fehler.
  GatewayError? groupAdminError;

  /// Test: wird zu Beginn von `inviteToGroup` bzw. `acceptGroupInvite` gerufen (Reihenfolge und Wettläufe prüfen).
  Future<void> Function(String roomId, String userId)? onInviteToGroup;
  Future<void> Function(String roomId)? beforeAcceptGroup;

  /// Zahl der Aufrufe je Operation (Einladen, Entfernen, Admin ändern).
  int inviteToGroupCalls = 0;
  int removeFromGroupCalls = 0;
  int setGroupAdminCalls = 0;

  /// Test: der Weggang des Entfernten ist angekommen; der Abgleich wischt, danach ist das Senden wieder frei.
  Future<void> completeRemoval(String roomId) async {
    _removingGroups.remove(roomId);
    await syncGroups();
  }

  FakeRoom _adminRoom(String roomId) {
    _requireSession();
    final r = _groupRoomOf(roomId);
    if (r == null || !contactPolicy.enabled) throw const GatewayException(GatewayError.notAllowed);
    final e = groupAdminError;
    if (e != null) throw GatewayException(e);
    return r;
  }

  GroupRights _myRights(FakeRoom r) => GroupRights(myUserId: _userId!, myLevel: r.power[_userId] ?? 0);

  @override
  Future<List<GroupMember>> groupMembers(String roomId) async {
    final r = _adminRoom(roomId);
    final me = _userId!;
    return <GroupMember>[
      for (final m in _visibleMembers(r))
        GroupMember(
          userId: m,
          displayName: ContactNames.title(fake.displayNameOf(m), m),
          membership: r.invitedUsers.contains(m) ? GroupMembership.invite : GroupMembership.join,
          power: r.power[m] ?? 0,
          reachability: m == me ? ContactReachability.unknown : _reachOf(m),
          isFamily: m != me && family?.member(m) != null,
          isMe: m == me,
        ),
    ]..sort((a, b) => a.isMe != b.isMe ? (a.isMe ? -1 : 1) : a.userId.compareTo(b.userId));
  }

  @override
  Future<void> inviteToGroup(String roomId, String userId) async {
    inviteToGroupCalls++;
    await onInviteToGroup?.call(roomId, userId);
    final r = _adminRoom(roomId);
    final me = _userId!;
    if (!_myRights(r).canInvite) throw const GatewayException(GatewayError.notAllowed);
    if (userId == me || contactPolicy.blocked.contains(userId)) throw const GatewayException(GatewayError.notAllowed);
    if (family?.member(userId) == null && contactPolicy.contacts[userId] != ContactState.accepted) throw const GatewayException(GatewayError.notAllowed);
    if (r.dmMembers.contains(userId)) throw const GatewayException(GatewayError.alreadyExists);
    if (r.dmMembers.length >= ContactGroupSpec.maxMembers) throw const GatewayException(GatewayError.groupFull);
    final reach = fake.identityChangedUsers.contains(userId) ? ContactReachability.identityChanged : _reachOf(userId);
    switch (reach) {
      case ContactReachability.reachable:
        break;
      case ContactReachability.notReachable:
        throw const GatewayException(GatewayError.peerNotReachable);
      case ContactReachability.unknown:
        throw const GatewayException(GatewayError.serverUnreachable);
      case ContactReachability.identityChanged:
        throw const GatewayException(GatewayError.notAllowed);
    }
    r.dmMembers.add(userId);
    r.invitedUsers.add(userId);
    fake.notifyAll();
  }

  @override
  Future<void> removeFromGroup(String roomId, String userId) async {
    removeFromGroupCalls++;
    final r = _adminRoom(roomId);
    if (!r.dmMembers.contains(userId)) throw const GatewayException(GatewayError.notFound);
    if (!_myRights(r).canRemove(userId, r.power[userId] ?? 0)) throw const GatewayException(GatewayError.notAllowed);
    _removingGroups.add(roomId);
    r.dmMembers.remove(userId);
    r.invitedUsers.remove(userId);
    fake.notifyAll();
  }

  @override
  Future<void> setGroupAdmin(String roomId, String userId, {required bool admin}) async {
    setGroupAdminCalls++;
    final r = _adminRoom(roomId);
    final me = _userId!;
    final target = r.power[userId] ?? 0;
    if (!_myRights(r).canSetAdmin(userId, target, admin: admin)) throw const GatewayException(GatewayError.notAllowed);
    if (userId != me && (!r.dmMembers.contains(userId) || r.invitedUsers.contains(userId))) throw const GatewayException(GatewayError.notFound);
    if (userId == me && !admin) {
      final members = <GroupMember>[
        for (final m in r.dmMembers)
          GroupMember(userId: m, displayName: '', membership: r.invitedUsers.contains(m) ? GroupMembership.invite : GroupMembership.join, power: r.power[m] ?? 0, isMe: m == me),
      ];
      if (GroupRights.isLastAdmin(members)) throw const GatewayException(GatewayError.notAllowed);
    }
    if (admin) {
      r.power[userId] = GroupRights.levelFor(admin: true);
    } else {
      r.power.remove(userId);
    }
    fake.notifyAll();
  }

  @override
  Future<String> createGroup(String name) async {
    createGroupCalls++;
    final title = ContactNames.groupTitle(name);
    if (title.isEmpty || name.trim().length > ContactGroupSpec.nameMax) throw const GatewayException(GatewayError.invalidInput);
    _requireSession();
    final me = _userId;
    if (me == null || !contactPolicy.enabled || contactPolicy.groups.length >= ContactLimits.maxGroups) throw const GatewayException(GatewayError.notAllowed);
    if (groupCreationRunning) throw const GatewayException(GatewayError.alreadyExists);
    final failure = createGroupError;
    if (failure != null) throw GatewayException(failure);
    final room = fake.createGroupRoom(me, title);
    room.power[me] = PowerLevels.admin;
    _createdGroups.add(room.id);
    return room.id;
  }

  @override
  Future<void> acceptGroupInvite(String roomId) async {
    acceptGroupCalls++;
    await beforeAcceptGroup?.call(roomId);
    final r = fake.groupRooms[roomId];
    final me = _userId;
    if (r == null || me == null) throw const GatewayException(GatewayError.notFound);
    if (_groupClass(r) == RoomClass.contactGroup) return; // idempotent
    if (_groupClass(r) != RoomClass.contactRequest) throw const GatewayException(GatewayError.notAllowed);
    final failure = acceptGroupError;
    if (failure != null) throw GatewayException(failure);
    r.invitedUsers.remove(me);
    final ok = ContactGroupSpec.verifyJoined(
      encryptionAlgorithm: r.groupEncrypted ? ContactGroupSpec.megolm : null,
      joinRule: r.joinRule,
      historyVisibility: r.history,
      joined: r.dmMembers.length - r.invitedUsers.length,
      invited: r.invitedUsers.length,
    );
    if (!ok) {
      r.dmMembers.remove(me);
      _leftGroups.add(roomId);
      fake.notifyAll();
      throw const GatewayException(GatewayError.notAllowed);
    }
    fake.notifyAll();
  }

  @override
  Set<String> get leftGroupRooms => <String>{
        for (final id in contactPolicy.groups)
          if (_leftGroups.contains(id) || (fake.groupRooms[id] != null && !fake.groupRooms[id]!.dmMembers.contains(_userId))) id,
      };

  @override
  List<ContactRequest> get contactRequests {
    final ctx = _contactContext();
    if (ctx == null) return const <ContactRequest>[];
    final groupRequests = <ContactRequest>[
      for (final r in fake.groupRooms.values)
        if (_groupClass(r) == RoomClass.contactRequest && r.groupInviter != null)
          ContactRequest(
            roomId: r.id,
            fromUserId: r.groupInviter!,
            fromName: ContactNames.title(fake.displayNameOf(r.groupInviter!), r.groupInviter!),
            name: ContactNames.cleanName(fake.displayNameOf(r.groupInviter!)),
            groupName: ContactNames.groupTitle(r.name),
            isGroup: true,
            inviterIsFamily: family?.member(r.groupInviter!) != null,
          ),
    ];
    final bySender = <String, FakeRoom>{};
    for (final r in fake.contactRooms.values) {
      final facts = _contactFacts(r);
      if (facts == null || ConversationPolicy.classify(facts, ctx) != RoomClass.contactRequest) continue;
      final cur = bySender[facts.inviterId!];
      if (cur == null || r.id.compareTo(cur.id) < 0) bySender[facts.inviterId!] = r;
    }
    return <ContactRequest>[
      for (final e in bySender.entries)
        ContactRequest(
          roomId: e.value.id,
          fromUserId: e.key,
          fromName: ContactNames.title(fake.displayNameOf(e.key), e.key),
          name: ContactNames.cleanName(fake.displayNameOf(e.key)),
        ),
      ...groupRequests,
    ]..sort((a, b) => a.roomId.compareTo(b.roomId));
  }

  /// Test: Zahl der weiteren, nicht angezeigten Anfragen (K3b-1).
  int hiddenRequests = 0;

  /// Test: `leaveConversation` scheitert, ohne etwas zu verändern.
  bool failLeaveConversation = false;

  /// Test: `startContactChat` scheitert **vor** dem Anlegen mit diesem Fehler (z. B. `alreadyExists`), oder — mit
  /// [startFailsAfterCreate] — **nachdem** der Raum angelegt wurde.
  GatewayError? startError;
  bool startFailsAfterCreate = false;

  /// Test: `declineContactRequest` scheitert mit diesem Fehler.
  GatewayError? declineError;

  @override
  int get contactRequestsHidden => hiddenRequests;

  void _requireProbeable(String userId) {
    _requireSession();
    // Wie das Gateway seit K3c-1: Kontakte brauchen keine Familie (das Konto genügt).
    if (_userId == null) throw const GatewayException(GatewayError.notAllowed);
    if (!MatrixIds.isUserId(userId)) throw const GatewayException(GatewayError.invalidInput);
    if (userId == _userId || !contactPolicy.enabled || contactPolicy.blocked.contains(userId)) {
      throw const GatewayException(GatewayError.notAllowed);
    }
  }

  ContactReachability _reachOf(String userId) {
    if (fake.keyQueryFailures.contains(userId)) return ContactReachability.unknown;
    if (fake.identityChangedUsers.contains(userId)) return ContactReachability.identityChanged;
    return fake.unreachableUsers.contains(userId) ? ContactReachability.notReachable : ContactReachability.reachable;
  }

  @override
  Future<ContactProbe> probeContact(String userId) async {
    _requireProbeable(userId);
    if (family?.member(userId) != null) {
      return ContactProbe(userId: userId, existence: ContactExistence.unknown, displayName: '', reachability: ContactReachability.unknown, isFamilyMember: true);
    }
    final failure = fake.probeError;
    if (failure != null) throw GatewayException(failure);
    fake.probeNetworkCalls++;
    final known = fake.hasAccount(MatrixIds.localpart(userId)) && MatrixIds.serverName(userId) == fake.host;
    return ContactProbe(
      userId: userId,
      existence: fake.profileUnknown.contains(userId) ? ContactExistence.unknown : (known ? ContactExistence.yes : ContactExistence.no),
      displayName: known ? ContactNames.cleanName(fake.displayNameOf(userId)) : '',
      reachability: _reachOf(userId),
    );
  }

  @override
  Future<String> startContactChat(String userId) async {
    _requireProbeable(userId);
    if (family?.member(userId) != null || contactPolicy.contacts[userId] != ContactState.outgoing) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    for (final r in fake.contactRooms.values) {
      if (r.dmMembers.contains(_userId) && r.dmMembers.contains(userId) && _contactClass(r) == RoomClass.contactDirect) return r.id;
    }
    fake.probeNetworkCalls++;
    final reach = _reachOf(userId);
    if (reach == ContactReachability.notReachable) throw const GatewayException(GatewayError.peerNotReachable);
    if (reach == ContactReachability.unknown) throw const GatewayException(GatewayError.serverUnreachable);
    // Pin-Sackgasse (K3c-1): Bei geändertem Schlüssel oder gesperrten Geräten entsteht der Raum trotzdem, Senden bleibt gesperrt.
    final failure = startError;
    if (failure != null && !startFailsAfterCreate) throw GatewayException(failure);
    final room = fake.createContactRoom(_userId!, userId);
    if (failure != null) throw GatewayException(failure);
    return room.id;
  }

  @override
  bool isThreadOpen(String threadId) {
    if (threadId == ChatThread.familyId || fake.dmRooms.containsKey(threadId)) return true;
    if (fake.groupRooms.containsKey(threadId)) return _opened.contains(threadId) && _groupRoomOf(threadId) != null;
    final r = fake.contactRooms[threadId];
    // Wie das SDK: wartende Räume bekommen nie eine Zeitleiste.
    return r != null && _opened.contains(threadId) && _contactRoomOf(threadId) != null && !r.invitedUsers.contains(r.dmMembers.firstWhere((m) => m != _userId));
  }

  /// Test: Zahl der Aufrufe von `openThread` (je Gespräch) und ein Schalter, der das Öffnen scheitern lässt.
  final Map<String, int> openCalls = <String, int>{};
  bool failOpenThread = false;

  @override
  Future<void> openThread(String threadId) async {
    openCalls.update(threadId, (n) => n + 1, ifAbsent: () => 1);
    if (failOpenThread) return;
    if (_groupRoomOf(threadId) != null) {
      _opened.add(threadId);
      return;
    }
    final r = _contactRoomOf(threadId);
    if (r != null && !r.invitedUsers.contains(r.dmMembers.firstWhere((m) => m != _userId))) _opened.add(threadId);
  }

  @override
  Future<void> declineContactRequest(String roomId) async {
    final failure = declineError;
    if (failure != null) throw GatewayException(failure);
    final g = fake.groupRooms[roomId];
    if (g != null) {
      if (_groupClass(g) != RoomClass.contactRequest) throw const GatewayException(GatewayError.notAllowed);
      g.dmMembers.remove(_userId);
      g.invitedUsers.remove(_userId);
      _leftGroups.add(roomId);
      fake.notifyAll();
      return;
    }
    final r = fake.contactRooms[roomId];
    if (r == null || _contactClass(r) != RoomClass.contactRequest) throw const GatewayException(GatewayError.notAllowed);
    r.dmMembers.remove(_userId);
    r.invitedUsers.remove(_userId);
    fake.notifyAll();
  }

  @override
  Future<void> leaveConversation(String threadId) async {
    if (failLeaveConversation) throw const GatewayException(GatewayError.serverUnreachable);
    final grp = fake.groupRooms[threadId];
    if (grp != null) {
      // Eine Gruppe lässt sich immer verlassen (auch unverschlüsselt, zu groß), nie ohne Beitritt.
      if (_groupClass(grp) != RoomClass.contactGroup && !_createdGroups.contains(threadId)) throw const GatewayException(GatewayError.notAllowed);
      grp.dmMembers.remove(_userId);
      grp.invitedUsers.remove(_userId);
      _createdGroups.remove(threadId);
      _leftGroups.add(threadId);
      _opened.remove(threadId);
      fake.notifyAll();
      return;
    }
    final r = _contactRoomOf(threadId);
    if (r == null) throw const GatewayException(GatewayError.notAllowed);
    r.dmMembers.remove(_userId);
    r.invitedUsers.remove(_userId);
    _opened.remove(threadId);
    fake.notifyAll();
  }

  @override
  Future<void> publishContactRecord(ContactRecord record) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final Map<String, Object?> content;
    try {
      content = ContactCodec.encode(record);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(_privateRoom(), _userId!, ContactCodec.type, content);
  }

  @override
  Future<void> publishTaskLog(TaskLogEntry entry) async {
    _requireSession();
    _require();
    publishAttempts++;
    if (failPublishes) throw const GatewayException(GatewayError.serverUnreachable);
    final room = familyRoom;
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (entry.by != _userId) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeLog(entry);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    fake.post(room, _userId!, TaskCodec.logType, content);
  }
}

/// Simulierte Emoji-Verifizierung zwischen zwei Geräten.
class FakeVerification {
  FakeVerification(this.initiator, this.peer, this.peerUserId);
  final FakeMatrixGateway initiator;
  final FakeMatrixGateway? peer;
  final String peerUserId;
  bool accepted = false;
  bool initiatorConfirmed = false;
  bool peerConfirmed = false;
  bool cancelled = false;
  bool done = false;

  /// Geräte, die den Dialog geschlossen haben (sehen danach keine Verifizierung mehr).
  final Set<FakeMatrixGateway> dismissedBy = <FakeMatrixGateway>{};

  static const List<VerificationEmoji> emojis = <VerificationEmoji>[
    VerificationEmoji(emoji: '🐶', name: 'Dog'),
    VerificationEmoji(emoji: '🔑', name: 'Key'),
    VerificationEmoji(emoji: '🍀', name: 'Clover'),
    VerificationEmoji(emoji: '🎸', name: 'Guitar'),
    VerificationEmoji(emoji: '🚀', name: 'Rocket'),
    VerificationEmoji(emoji: '📌', name: 'Pin'),
    VerificationEmoji(emoji: '🌍', name: 'Globe'),
  ];
}

class _FakeRegistration {
  _FakeRegistration(this.username, this.password, this.displayName);
  final String username;
  String? password;
  final String displayName;
  final Set<String> completed = <String>{};
  bool emailSent = false;
}
