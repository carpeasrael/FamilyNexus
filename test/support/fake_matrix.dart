import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'dart:async';

import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:family_nexus/domain/presence.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/foundation.dart';

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
  final Map<String, MemberStatus> membership = <String, MemberStatus>{};

  /// Ausgegebene Link-IDs (`nonce` → Ablauf) und die je Anfrage genannte ID.
  final Map<String, DateTime> issued = <String, DateTime>{};
  final Map<String, String> knockNonce = <String, String>{};

  /// Mitglieder, deren Identität sich geändert hat (Tests setzen das).
  final Set<String> identityChanged = <String>{};
  final List<FakeEvent> events = <FakeEvent>[];

  /// Nur Einzelchats: die zwei Beteiligten.
  final Set<String> dmMembers = <String>{};
}

class _Account {
  _Account(this.userId, this.password);
  final String userId;
  final String password;
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

  /// Gesendete Statusmeldungen (Absender, online, ask, Empfänger) – nur Gerätenachrichten, nie Raumereignisse.
  final List<({String sender, bool online, bool ask, List<String> to})> presenceLog =
      <({String sender, bool online, bool ask, List<String> to})>[];
  final List<FakeMatrixGateway> _gateways = <FakeMatrixGateway>[];
  int _seq = 0;
  bool reachable = true;

  /// Simuliert einen Server, der für die Einrichtung eine Passwortbestätigung verlangt.
  bool requirePasswordForSecurity = false;

  /// Konten mit eingerichteter Schlüsselsicherung → Wiederherstellungsschlüssel.
  final Map<String, String> recoveryKeys = <String, String>{};

  /// Laufende simulierte Verifizierung (Initiator, Gegenseite).
  FakeVerification? verification;

  /// Test-Uhr (für Ablauf von Einladungslinks).
  DateTime Function() now = () => DateTime.utc(2026, 10, 21, 12);

  String nextId(String prefix) => '$prefix${++_seq}';

  String addAccount(String localpart, String password, {String? displayName}) {
    final id = '@$localpart:$host';
    _accounts[id] = _Account(id, password)..displayName = displayName ?? localpart;
    return id;
  }

  String displayNameOf(String userId) => _accounts[userId]?.displayName ?? userId;

  FakeMatrixGateway newDevice() => FakeMatrixGateway(this);

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
        sig = e.type == EventCodec.privateType ? PrivateEventSignal(e.sender, e.time, e.content) : null;
      } else {
        if (room.membership[uid] != MemberStatus.joined) continue;
        sig = switch (e.type) {
          EventCodec.sharedType => SharedEventSignal(e.sender, e.time, e.content),
          EventCodec.rsvpType => RsvpSignal(e.sender, e.time, e.content),
          ShoppingCodec.type => ShoppingSignal(e.sender, e.time, e.content),
          TaskCodec.listType => TaskListSignal(e.sender, e.time, e.content),
          TaskCodec.logType => TaskLogSignal(e.sender, e.time, e.content),
          _ => null,
        };
      }
      if (sig != null) g._signals.add(sig);
    }
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

  FakeEvent post(FakeRoom room, String sender, String type, Map<String, Object?> content) {
    final e = FakeEvent(nextId(r'$ev'), room.id, sender, type, content, DateTime.utc(2026, 10, 21, 12).add(Duration(seconds: _seq)));
    room.events.add(e);
    log.add(e);
    _dispatch(room, e);
    notifyAll();
    return e;
  }
}

class FakeMatrixGateway extends ChangeNotifier implements MatrixGateway {
  FakeMatrixGateway(this.fake) {
    fake._register(this);
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

  @override
  String? get userId => _userId;

  @override
  ServerUrl? get server => _server;

  FakeRoom? get familyRoom => _familyRoomId == null ? null : fake.rooms[_familyRoomId];

  /// Test-Hook: Familienraum für diesen Nutzer festlegen (z. B. nach Einladung).
  void attachFamilyRoom(String roomId) {
    _familyRoomId = roomId;
    notifyListeners();
  }

  RequestCheck _check(FakeRoom room, String user) {
    final n = room.knockNonce[user];
    final exp = n == null ? null : room.issued[n];
    if (exp == null) return RequestCheck.unknown;
    return fake.now().isBefore(exp) ? RequestCheck.valid : RequestCheck.expired;
  }

  @override
  Future<void> acceptIdentityChange(String userId) async {
    final room = familyRoom;
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
    final room = fake.dmRooms[threadId];
    final me = _userId;
    if (room == null || me == null || !room.dmMembers.contains(me)) return null;
    final peer = room.dmMembers.firstWhere((m) => m != me);
    return family?.member(peer)?.status == MemberStatus.joined ? room : null;
  }

  @override
  List<ChatThread> get threads {
    final f = family;
    if (f == null) return const <ChatThread>[];
    final dms = <ChatThread>[
      for (final r in fake.dmRooms.values)
        if (_roomOf(r.id) != null)
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
    ];
  }

  @override
  List<ChatMessage> messagesIn(String threadId) {
    final room = _roomOf(threadId);
    if (room == null) return const <ChatMessage>[];
    final reactions = <String, Map<String, Set<String>>>{};
    for (final e in room.events.where((e) => e.type == 'm.reaction')) {
      final target = e.content['target']! as String;
      reactions.putIfAbsent(target, () => <String, Set<String>>{})
          .putIfAbsent(e.content['emoji']! as String, () => <String>{})
          .add(e.sender);
    }
    return <ChatMessage>[
      for (final e in room.events.where((e) => e.type == 'm.room.message'))
        ChatMessage(
          id: e.id,
          senderId: e.sender,
          senderName: fake.displayNameOf(e.sender),
          time: e.time,
          body: (e.content['body'] as String?) ?? '',
          replyToId: e.content['reply_to'] as String?,
          sharedEventId: e.content['event_ref'] as String?,
          reactions: reactions[e.id] ?? const <String, Set<String>>{},
          attachment: e.content['file_name'] == null
              ? null
              : AttachmentInfo(
                  name: e.content['file_name']! as String,
                  mimeType: e.content['mime']! as String,
                  size: e.content['size']! as int,
                ),
        ),
    ];
  }

  void _require() {
    if (!fake.reachable) throw const GatewayException(GatewayError.serverUnreachable);
  }

  void _requireSession() {
    if (_userId == null) throw const GatewayException(GatewayError.notAllowed);
  }

  @override
  bool get initialSyncDone => true;

  final Map<String, int> _read = <String, int>{};

  @override
  int unreadIn(String threadId) {
    final list = messagesIn(threadId);
    var n = 0;
    for (var i = _read[threadId] ?? 0; i < list.length; i++) {
      if (list[i].senderId != _userId) n++;
    }
    return n;
  }

  @override
  int get unreadCount => threads.fold<int>(0, (a, t) => a + t.unread);

  @override
  Future<void> markChatRead({String threadId = ChatThread.familyId}) async {
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

  @override
  Future<void> startVerification({required String userId, String? deviceId}) async {
    _requireSession();
    if (fake.verification != null && !fake.verification!.done && !fake.verification!.cancelled) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
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
        PendingInvitation(roomId: id, requested: fake.rooms[id]!.knockNonce.containsKey(uid), roomName: fake.rooms[id]!.name, inviterId: fake.rooms[id]!.power.entries.firstWhere((e) => e.value >= 50).key),
    ];
  }

  @override
  bool get joinRequestPending =>
      fake.rooms.values.any((r) => r.membership[_userId] == MemberStatus.requested);

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
  Future<String> createInviteLink({Duration validity = InviteLink.defaultValidity}) async {
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
    fake.notifyAll();
  }

  @override
  Future<void> cancelJoinRequest() async {
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
    if (m.request != RequestCheck.valid) throw const GatewayException(GatewayError.notAllowed);
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

  FakeRoom _privateRoom() => fake.privateRooms.putIfAbsent(
        _userId!,
        () => FakeRoom('${fake.nextId('!private')}:${fake.host}', 'privat')..membership[_userId!] = MemberStatus.joined,
      );

  @override
  Future<void> publishSharedEvent(CalendarEvent event) async {
    _requireSession();
    _require();
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
  Future<void> loadOlderMessages({String threadId = ChatThread.familyId}) async {}

  @override
  Future<void> restore() async {}

  @override
  Future<ServerInfo> probeServer(ServerUrl url) async {
    _require();
    if (url.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    return ServerInfo(
      url: url,
      versions: const <String>['v1.11'],
      supportsPasswordLogin: true,
      contact: fake.operatorName,
    );
  }

  @override
  Future<void> login({required ServerUrl server, required String username, required String password}) async {
    _require();
    if (server.host != fake.host) throw const GatewayException(GatewayError.serverUnreachable);
    final account = fake._accounts['@$username:${fake.host}'];
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
  Future<void> logout() async {
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
      ..power[_userId!] = PowerLevels.moderator;
    fake.rooms[room.id] = room;
    _familyRoomId = room.id;
    fake.notifyAll();
  }

  FakeRoom _chatRoom(String threadId) {
    _requireSession();
    final room = _roomOf(threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    return room;
  }

  @override
  Future<void> sendMessage(String text, {String? replyToId, String threadId = ChatThread.familyId}) async {
    final room = _chatRoom(threadId);
    if (text.trim().isEmpty) throw const GatewayException(GatewayError.invalidInput);
    fake.post(room, _userId!, 'm.room.message', <String, Object?>{
      'body': text,
      'reply_to': ?replyToId,
    });
  }

  @override
  Future<void> sendReaction(String messageId, String emoji, {String threadId = ChatThread.familyId}) async {
    final room = _chatRoom(threadId);
    if (emoji.isEmpty || emoji.length > 16) throw const GatewayException(GatewayError.invalidInput);
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

  @override
  Future<void> retryMessage(String messageId, {String threadId = ChatThread.familyId}) async {}

  @override
  Future<Uint8List> loadAttachment(String messageId, {String threadId = ChatThread.familyId}) async {
    for (final g in fake._gateways) {
      final f = g._files[messageId];
      if (f != null) return f;
    }
    throw const GatewayException(GatewayError.notFound);
  }

  @override
  Future<String> startDirectChat(String userId) async {
    _requireSession();
    _require();
    final f = _fam();
    final m = _mem(f, userId);
    if (userId == _userId || m.status != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    for (final r in fake.dmRooms.values) {
      if (r.dmMembers.contains(_userId) && r.dmMembers.contains(userId)) return r.id;
    }
    final room = FakeRoom('${fake.nextId('!dm')}:${fake.host}', 'dm')..dmMembers.addAll(<String>[_userId!, userId]);
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

  @override
  Future<void> publishTaskLog(TaskLogEntry entry) async {
    _requireSession();
    _require();
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
