part of '../sdk_matrix_gateway.dart';

/// Chat (AP-5): Nachrichten senden, wiederholen, melden, Anhänge laden, Reaktionen. Abhängigkeiten stehen als
/// abstrakte Member am Anfang.
mixin _ChatModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Map<String, String> get _dmPeers;
  Map<String, Timeline> get _dmTimelines;
  Family? get _family;
  Room? _familyRoom();
  HttpsOnlyClient get _http;
  bool _isCurrentFamily(Room room);
  LocalSends get _localSends;
  Set<String> get _reactionInFlight;
  void _scheduleRefresh();
  Future<String?> _sendCalendar(Room room, String type, Map<String, Object?> content);
  Timeline? get _timeline;
  GatewayException _map(Object e);

  /// Raum eines Gesprächs: Familienraum oder ein bekannter Einzelchat-Raum.
  Room? _roomForThread(String threadId) {
    if (threadId == ChatThread.familyId) return _familyRoom();
    if (!_dmTimelines.containsKey(threadId)) return null;
    final room = _client?.getRoomById(threadId);
    return (room != null && room.membership == Membership.join) ? room : null;
  }

  Timeline? _timelineFor(String threadId) => threadId == ChatThread.familyId ? _timeline : _dmTimelines[threadId];

  /// Senden nur, wenn der Client Verschlüsselung kann UND der Raum Megolm nutzt.
  /// Das SDK würde sonst stillschweigend im Klartext senden. Einzelchats nur mit aktuellen
  /// Familienmitgliedern (E-39).
  Room _requireEncryptedRoom([String threadId = ChatThread.familyId]) {
    final room = _roomForThread(threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    if (threadId == ChatThread.familyId && !_isCurrentFamily(room)) {
      throw const GatewayException(GatewayError.serverUnreachable);
    }
    final client = _client;
    if (client == null || !client.encryptionEnabled || room.encryptionAlgorithm != FamilyRoomSpec.megolm) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    if (threadId != ChatThread.familyId) {
      final peer = _dmPeers[threadId];
      if (peer == null || _family?.member(peer)?.status != MemberStatus.joined) {
        throw const GatewayException(GatewayError.notAllowed);
      }
    }
    return room;
  }

  bool _canEncryptIn(Room? room) =>
      room != null && (_client?.encryptionEnabled ?? false) && room.encryptionAlgorithm == FamilyRoomSpec.megolm;

  Event? _findEvent(String id, [String threadId = ChatThread.familyId]) {
    final t = _timelineFor(threadId);
    if (t == null) return null;
    for (final e in t.events) {
      if (e.eventId == id) return e;
    }
    return null;
  }

  /// Antwortziel im Thread. Das SDK zitiert dessen Text in der verschlüsselten Antwort, im Namen dieses Geräts: Was nicht
  /// verschlüsselt ankam und auch keine eigene Sendung ist ([ChatMapper.visible]), wäre Text des Servers.
  Event? _replyTarget(String? replyToId, String threadId) {
    if (replyToId == null) return null;
    final e = _findEvent(replyToId, threadId);
    // Nicht stillschweigend ohne Antwortbezug senden.
    if (e == null || !ChatMapper.visible(e, _client?.userID, _localSends)) throw const GatewayException(GatewayError.notFound);
    return e;
  }

  @override
  Future<void> sendMessage(String text, {String? replyToId, String threadId = ChatThread.familyId}) async {
    if (text.trim().isEmpty || text.length > SdkMatrixGateway.maxMessageLength) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final room = _requireEncryptedRoom(threadId);
    final target = _replyTarget(replyToId, threadId);
    final roomId = room.id;
    final txid = room.client.generateUniqueTransactionId();
    try {
      await _sendTracked(
        txid: txid,
        threadId: threadId,
        roomId: roomId,
        tail: text,
        send: () => _roomForSend(threadId, roomId).sendTextEvent(
          text,
          txid: txid,
          inReplyTo: target,
          parseMarkdown: false,
          parseCommands: false,
        ),
      );
    } catch (e) {
      AppLog.e('gateway', 'Nachricht konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> sendReaction(String messageId, String emoji, {String threadId = ChatThread.familyId}) async {
    if (!TextSanitizer.isReactionKey(emoji)) throw const GatewayException(GatewayError.invalidInput);
    final room = _requireEncryptedRoom(threadId);
    final target = _findEvent(messageId, threadId);
    if (target == null || !target.status.isSent || !ReactionCodec.isTarget(messageId)) {
      throw const GatewayException(GatewayError.notFound);
    }
    // Im Chiffretext erkennt der Server Duplikate nicht. Bis zum `add` läuft alles ohne `await`.
    final me = room.client.userID!;
    final flight = '$threadId\n$messageId\n$emoji';
    if (_reactionInFlight.contains(flight) || ChatMapper.hasOwnReaction(_timelineFor(threadId)!, target, emoji, me)) {
      return;
    }
    _reactionInFlight.add(flight);
    try {
      await _sendCalendar(room, ReactionCodec.type, ReactionCodec.encode(target: messageId, key: emoji, sender: me));
    } catch (e) {
      AppLog.e('gateway', 'Reaktion konnte nicht gesendet werden', e);
      throw _map(e);
    } finally {
      _reactionInFlight.remove(flight);
    }
  }

  @override
  Future<void> reportMessage(ReportRequest request) async {
    final room = _roomForThread(request.threadId);
    if (room == null) throw const GatewayException(GatewayError.notFound);
    final event = _findEvent(request.messageId, request.threadId);
    if (event == null) throw const GatewayException(GatewayError.notFound);
    if (event.senderId == _client?.userID) throw const GatewayException(GatewayError.notAllowed);
    try {
      await _client!.reportEvent(room.id, event.eventId, reason: request.reason);
    } catch (e) {
      AppLog.e('gateway', 'Meldung konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> sendAttachment({
    required String fileName,
    required Uint8List bytes,
    String? replyToId,
    String threadId = ChatThread.familyId,
  }) async {
    final name = AttachmentPolicy.sanitizeFileName(fileName);
    if (AttachmentPolicy.check(fileName: name, bytes: bytes) != null) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    final room = _requireEncryptedRoom(threadId);
    final target = _replyTarget(replyToId, threadId);
    final roomId = room.id;
    final txid = room.client.generateUniqueTransactionId();
    try {
      await _sendTracked(
        txid: txid,
        threadId: threadId,
        roomId: roomId,
        tail: name,
        bytes: bytes.lengthInBytes,
        send: () {
          final file = MatrixFile.fromMimeType(
            bytes: bytes,
            name: name,
            mimeType: AttachmentPolicy.mimeForName(name),
          );
          return _roomForSend(threadId, roomId).sendFileEvent(file, txid: txid, inReplyTo: target);
        },
      );
    } catch (e) {
      AppLog.e('gateway', 'Anhang konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<void> retryMessage(String messageId, {String threadId = ChatThread.familyId}) async {
    final e = _findEvent(messageId, threadId);
    // `sending` zählt mit: Ohne laufende Sendung zeigt der Chat das als gescheitert (Ausnahme ohne Fehler-Echo).
    if (e == null || e.status.isSent) throw const GatewayException(GatewayError.notFound);
    if (!_canEncryptIn(_roomForThread(threadId))) throw const GatewayException(GatewayError.encryptionUnavailable);
    if (_localSends.isRunning(messageId)) return;
    final roomId = _timelineFor(threadId)!.room.id;
    if (!_localSends.canRetry(messageId, threadId, roomId)) throw const GatewayException(GatewayError.notFound);
    try {
      await _retryTracked(messageId, threadId, roomId);
    } catch (err) {
      AppLog.e('gateway', 'Wiederholen fehlgeschlagen', err);
      throw _map(err);
    }
  }

  /// Führt eine Sendung über [LocalSends] aus. Der Abgleich danach ordnet das Ergebnis ein: Das letzte Ereignis der
  /// Zeitleiste kam vor der Rückkehr von [send], der Stand von [LocalSends] danach.
  Future<void> _sendTracked({
    required String txid,
    required String threadId,
    required String roomId,
    required String tail,
    int bytes = 0,
    required SendAttempt send,
  }) async {
    try {
      await _localSends.run(txid: txid, threadId: threadId, roomId: roomId, tail: tail, bytes: bytes, send: send);
    } finally {
      _scheduleRefresh();
    }
  }

  Future<void> _retryTracked(String txid, String threadId, String roomId) async {
    try {
      await _localSends.retry(txid, threadId, roomId);
    } finally {
      _scheduleRefresh();
    }
  }

  /// Raum für einen Sendeversuch einer gemerkten Sendung, vor jedem Versuch neu aufgelöst und geprüft ([_requireEncryptedRoom]).
  /// Für die Familie ist die Thread-Kennung eine Konstante und der Raum stammt aus unverschlüsselten Kontodaten: Zeigen
  /// sie auf einen anderen Raum, geht nichts dorthin, sondern nur in den beim ersten Senden geprüften Raum [roomId].
  Room _roomForSend(String threadId, String roomId) {
    final room = _requireEncryptedRoom(threadId);
    if (room.id != roomId) throw const GatewayException(GatewayError.notAllowed);
    return room;
  }

  /// Ließe [_roomForSend] jetzt einen Versuch durch?
  bool _canSendTo(String threadId, String roomId) {
    try {
      _roomForSend(threadId, roomId);
      return true;
    } on GatewayException {
      return false;
    }
  }

  /// Begrenzter Download: bricht ab, sobald mehr als das Limit ankommt (der im
  /// Ereignis behauptete Wert ist nicht vertrauenswürdig).
  Future<Uint8List> _boundedDownload(Uri uri) async {
    final client = _client!;
    final req = http.Request('GET', uri)
      ..headers['authorization'] = 'Bearer ${client.accessToken}';
    final res = await _http.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw const GatewayException(GatewayError.notFound);
    }
    final declared = res.contentLength;
    if (declared != null && declared > AttachmentPolicy.maxBytes + 1024) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    final buf = BytesBuilder(copy: false);
    await for (final chunk in res.stream) {
      buf.add(chunk);
      if (buf.length > AttachmentPolicy.maxBytes + 1024) {
        throw const GatewayException(GatewayError.attachmentRejected);
      }
    }
    return buf.takeBytes();
  }

  @override
  Future<Uint8List> loadAttachment(String messageId, {String threadId = ChatThread.familyId}) async {
    final e = _findEvent(messageId, threadId);
    if (e == null) throw const GatewayException(GatewayError.notFound);
    final size = e.content.tryGetMap<String, Object?>('info')?.tryGet<int>('size');
    final mime = e.attachmentMimetype.toLowerCase();
    if (size == null || !AttachmentPolicy.incomingAllowed(mimeType: mime, size: size)) {
      throw const GatewayException(GatewayError.attachmentRejected);
    }
    try {
      final file = await e.downloadAndDecryptAttachment(downloadCallback: _boundedDownload);
      if (file.bytes.length > AttachmentPolicy.maxBytes ||
          !AttachmentPolicy.contentMatches(mime, file.bytes)) {
        throw const GatewayException(GatewayError.attachmentRejected);
      }
      return file.bytes;
    } on GatewayException {
      rethrow;
    } catch (err) {
      AppLog.e('gateway', 'Anhang konnte nicht geladen werden', err);
      throw _map(err);
    }
  }

  @override
  Future<void> loadOlderMessages({String threadId = ChatThread.familyId}) async {
    final t = _timelineFor(threadId);
    if (t == null || !t.canRequestHistory) return;
    try {
      await t.requestHistory();
    } catch (e) {
      AppLog.e('gateway', 'Ältere Nachrichten konnten nicht geladen werden', e);
    }
  }
}
