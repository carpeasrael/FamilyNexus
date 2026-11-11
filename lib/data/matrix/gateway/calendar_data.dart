part of '../sdk_matrix_gateway.dart';

/// Daten (AP-5): Kalender, Einkaufszettel und Aufgabenlisten im privaten und im Familienraum. Die Felder
/// `_privateRoomIdCache` und `_privateVerified` liegen hier, die Klasse setzt sie in `_resetLocal` zurück.
mixin _CalendarDataModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Future<void>? get _creatingPrivateRoom;
  set _creatingPrivateRoom(Future<void>? value);
  void _emit(CalendarSignal s);
  Room? _familyRoom();
  Set<String>? get _knownJoined;
  set _knownJoined(Set<String>? value);
  GatewayException _map(Object e);
  BoundedIdSet get _plaintextWarned;
  Timeline? get _privateTimeline;
  set _privateTimeline(Timeline? value);
  String? get _privateTimelineRoomId;
  set _privateTimelineRoomId(String? value);
  Room _requireEncryptedRoom();
  void _scheduleRefresh();
  Set<String> get _signaled;
  bool get _syncedOnce;

  /// Erster Stand der Mitglieder ist die Basis; nur spätere Beitritte lösen den
  /// Resync aus.
  void _emitMemberJoins(Family f) {
    final now = f.joined.map((m) => m.userId).toSet();
    final before = _knownJoined;
    _knownJoined = now;
    if (before == null) return;
    for (final id in now.difference(before)) {
      if (id != f.myUserId) _emit(MemberJoinedSignal(id, DateTime.now().toUtc()));
    }
  }

  Room? _privateRoom() {
    final client = _client;
    if (client == null || !client.isLogged()) return null;
    // Kontodaten treffen lokal erst mit dem nächsten Sync ein; bis dahin gilt die gemerkte ID.
    final fromAccount = client.accountData[SdkMatrixGateway.privateAccountData]?.content['room_id'];
    final id = fromAccount is String ? fromAccount : _privateRoomIdCache;
    if (id == null || !MatrixIds.isRoomId(id)) return null;
    final room = client.getRoomById(id);
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  String? _privateRoomIdCache;

  Future<void> _ensurePrivateTimeline(Client client) async {
    final room = _privateRoom();
    if (room == null) {
      _privateTimeline?.cancelSubscriptions();
      _privateTimeline = null;
      _privateTimelineRoomId = null;
      return;
    }
    if (_privateTimelineRoomId == room.id) return;
    _privateTimeline?.cancelSubscriptions();
    _privateTimeline = await room.getTimeline(
      onUpdate: _scheduleRefresh,
      onInsert: (_) => _scheduleRefresh(),
      onChange: (_) => _scheduleRefresh(),
      onNewEvent: _scheduleRefresh,
    );
    _privateTimelineRoomId = room.id;
    _backfill(_privateTimeline!).ignore();
  }

  /// Lädt ältere Ereignisse nach, damit ein neues Gerät den bisherigen Bestand
  /// erhält (begrenzt auf [SdkMatrixGateway.backfillPages] Seiten).
  Future<void> _backfill(Timeline t, {int pages = SdkMatrixGateway.backfillPages}) async {
    try {
      for (var i = 0; i < pages && t.canRequestHistory; i++) {
        await t.requestHistory();
      }
      _scheduleRefresh();
    } catch (e) {
      AppLog.e('gateway', 'Nachladen des Verlaufs fehlgeschlagen', e);
    }
  }

  /// Klartext löst kein Signal aus (#138). Keine Ausnahme für eigene Ereignisse: `sender`, Kennungen und Status
  /// setzt der Server, und eigene Sendungen stehen ohnehin im lokalen Store. Erst nach der Prüfung gilt ein Ereignis
  /// als behandelt, damit ein eigenes Echo nach seiner Reparatur noch ankommt.
  void _scanForSignals(Timeline? t, {required bool shared}) {
    if (t == null) return;
    for (final e in t.events.reversed) {
      if (e.redacted || e.status.isError) continue;
      if (e.type != EventTypes.Encrypted && !arrivedEncrypted(e)) {
        _warnPlaintext(e);
        continue;
      }
      if (!_signaled.add(e.eventId)) continue;
      final c = e.content;
      if (shared && e.type == EventCodec.sharedType) {
        _emit(SharedEventSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == EventCodec.rsvpType) {
        _emit(RsvpSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == ShoppingCodec.type) {
        _emit(ShoppingSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == TaskCodec.listType) {
        _emit(TaskListSignal(e.senderId, e.originServerTs, c));
      } else if (shared && e.type == TaskCodec.logType) {
        _emit(TaskLogSignal(e.senderId, e.originServerTs, c));
      } else if (!shared && e.type == EventCodec.privateType) {
        _emit(PrivateEventSignal(e.senderId, e.originServerTs, c));
      } else if (e.type == EventTypes.Encrypted) {
        // Noch nicht entschlüsselt: später erneut betrachten.
        _signaled.remove(e.eventId);
      }
    }
  }

  static const Set<String> _appEventTypes = <String>{
    EventCodec.sharedType,
    EventCodec.rsvpType,
    EventCodec.privateType,
    ShoppingCodec.type,
    TaskCodec.listType,
    TaskCodec.logType,
    InviteTicket.type,
  };

  /// Einmal je Ereignis, ohne Inhalt, nur für die Typen, die etwas auslösen würden. Das lokale Echo einer eigenen
  /// Sendung ist bis zum Sync kein Vorfall.
  void _warnPlaintext(Event e) {
    if (!e.status.isSynced || !_appEventTypes.contains(e.type) || !_plaintextWarned.add(e.eventId)) return;
    AppLog.w('gateway', 'Klartext-Ereignis eines App-Typs verworfen');
  }

  Future<void> _ensurePrivateRoom() async {
    if (_privateRoom() != null) return;
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (!_syncedOnce) throw const GatewayException(GatewayError.serverUnreachable);
    // Nur ein gleichzeitiger Anlegevorgang pro Gerät.
    return _creatingPrivateRoom ??= () async {
      try {
        final me = client.userID!;
        final roomId = await client.createRoom(
          name: 'FamilyNexus',
          roomVersion: FamilyRoomSpec.roomVersion,
          preset: CreateRoomPreset.privateChat,
          visibility: Visibility.private,
          initialState: <StateEvent>[
            StateEvent(
              type: 'm.room.encryption',
              stateKey: '',
              content: <String, Object?>{'algorithm': FamilyRoomSpec.megolm},
            ),
            StateEvent(
              type: 'm.room.history_visibility',
              stateKey: '',
              content: <String, Object?>{'history_visibility': 'shared'},
            ),
          ],
        );
        await client.setAccountData(me, SdkMatrixGateway.privateAccountData, <String, Object?>{'room_id': roomId});
        _privateRoomIdCache = roomId;
        try {
          await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
        } on TimeoutException {
          AppLog.w('gateway', 'Privater Raum noch nicht im Sync');
        }
      } finally {
        _creatingPrivateRoom = null;
      }
    }();
  }

  String? _privateVerified;

  /// „Privat nie senden“ hängt nicht allein am Kontodaten-Zeiger: Der Raum darf nicht
  /// der Familienraum sein und außer dem eigenen Konto kein weiteres Mitglied haben.
  Future<void> _verifyPrivateRoom(Room room) async {
    final me = _client!.userID!;
    if (room.id == _familyRoom()?.id) throw const GatewayException(GatewayError.notAllowed);
    if (_privateVerified != room.id) {
      await room.requestParticipants();
      _privateVerified = room.id;
    }
    final others = room.getParticipants().where((u) =>
        u.id != me &&
        (u.membership == Membership.join || u.membership == Membership.invite || u.membership == Membership.knock));
    if (others.isNotEmpty) {
      AppLog.e('gateway', 'Privater Raum hat weitere Mitglieder – Senden verweigert');
      throw const GatewayException(GatewayError.notAllowed);
    }
  }

  Future<String?> _sendCalendar(Room room, String type, Map<String, Object?> content, {String? txid}) async {
    if (!(_client?.encryptionEnabled ?? false) || room.encryptionAlgorithm != FamilyRoomSpec.megolm) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    final id = await room.sendEvent(content, type: type, txid: txid);
    // `null` = das SDK hat nach Wiederholungen aufgegeben.
    if (id == null) throw const GatewayException(GatewayError.serverUnreachable);
    return id;
  }

  @override
  Future<void> publishSharedEvent(CalendarEvent event) async {
    final room = _requireEncryptedRoom();
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodeShared(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, EventCodec.sharedType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Geteilter Termin konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishPrivateEvent(CalendarEvent event) async {
    final Map<String, Object?> content;
    try {
      content = EventCodec.encodePrivate(event);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _ensurePrivateRoom();
      final room = _privateRoom();
      if (room == null) throw const GatewayException(GatewayError.serverUnreachable);
      await _verifyPrivateRoom(room);
      await _sendCalendar(room, EventCodec.privateType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Privater Termin konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishRsvp(String eventId, RsvpStatus status, DateTime timestamp) async {
    final room = _requireEncryptedRoom();
    try {
      await _sendCalendar(room, EventCodec.rsvpType, EventCodec.encodeRsvp(eventId, status, timestamp));
    } on GatewayException {
      rethrow;
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> publishShoppingItem(ShoppingItem item) async {
    final room = _requireEncryptedRoom();
    // Gesendet werden nur eigene Änderungen; Empfänger verwerfen fremde `by`-Angaben.
    if (item.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = ShoppingCodec.encode(item);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, ShoppingCodec.type, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Einkaufseintrag konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishTaskList(TaskList list) async {
    final room = _requireEncryptedRoom();
    if (list.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeList(list);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, TaskCodec.listType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Aufgabenliste konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> publishTaskLog(TaskLogEntry entry) async {
    final room = _requireEncryptedRoom();
    if (entry.by != _client?.userID) throw const GatewayException(GatewayError.invalidInput);
    final Map<String, Object?> content;
    try {
      content = TaskCodec.encodeLog(entry);
    } on StateError {
      throw const GatewayException(GatewayError.invalidInput);
    }
    try {
      await _sendCalendar(room, TaskCodec.logType, content);
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Protokolleintrag konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }
}
