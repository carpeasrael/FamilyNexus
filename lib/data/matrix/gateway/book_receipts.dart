part of '../sdk_matrix_gateway.dart';

/// Bon-Dateien im Buch-Raum (#311, E-113): senden, geprüft laden, eigene schwärzen. Alles hier ist gesperrt, solange
/// `cashBooksEnabled` `false` ist (`notAllowed`, keine Anfrage). Es gibt keine eigene Ablage und keine Temp-Datei: Das SDK
/// hält gesendete und geladene Dateien nur in seiner SQLCipher-Datenbank.
/// Steht in der Mixin-Liste **vor** `_BooksModule`, damit dessen Umsetzungen die abstrakten Deklarationen hier ersetzen.
mixin _BookReceiptsModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  bool get _requireEncryptionForBooks;
  HttpsOnlyClient get _http;
  GatewayException _map(Object e);
  Room _bookRoom(String roomId, {required Membership membership});
  bool _isBookOfCurrentFamily(Room room);

  Room _receiptRoom(String roomId) {
    final room = _bookRoom(roomId, membership: Membership.join);
    if (_family == null || !_isBookOfCurrentFamily(room)) throw const GatewayException(GatewayError.notAllowed);
    return room;
  }

  static bool _validEventId(String id) => id.startsWith(r'$') && id.length <= 255;

  @override
  Future<String> sendBookReceipt(String roomId, Uint8List bytes) async {
    final room = _receiptRoom(roomId);
    final client = _client!;
    if (bytes.isEmpty || bytes.length > CashBookLimits.maxReceiptBytes || !ReceiptCheck.looksLikeJpeg(bytes)) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    if (_requireEncryptionForBooks && (!client.encryptionEnabled || room.encryptionAlgorithm != FamilyRoomSpec.megolm)) {
      throw const GatewayException(GatewayError.encryptionUnavailable);
    }
    // Sendeschutz: Fremde im Raum → notAllowed, keine belastbare Mitgliederliste → serverUnreachable (nichts hochgeladen).
    await verifyBookRecipients(roomId);
    try {
      // Eine allgemeine `MatrixFile`, nie `MatrixImageFile` (`fromMimeType`): Nur diese löst im SDK Vorschau und
      // Verkleinern aus. `info` enthält so nur `mimetype` und `size`.
      final file = MatrixFile(bytes: bytes, name: 'receipt.jpg', mimeType: 'image/jpeg');
      final id = await room.sendFileEvent(file).timeout(SdkMatrixGateway.roomOpTimeout);
      if (id == null) throw const GatewayException(GatewayError.serverUnreachable);
      return id;
    } on GatewayException {
      rethrow;
    } catch (e) {
      AppLog.e('gateway', 'Bon-Foto konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  @override
  Future<BookReceiptLoad> loadBookReceipt(String roomId, String eventId, {required CashReceipt receipt, required String author}) async {
    final room = _receiptRoom(roomId);
    if (!_validEventId(eventId) || receipt.validate().isNotEmpty) return const BookReceiptLoad(BookReceiptStatus.invalid);
    final Event? e;
    try {
      e = await room.getEventById(eventId).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (err) {
      AppLog.w('gateway', 'Bon-Ereignis nicht abrufbar: ${err.runtimeType}');
      return const BookReceiptLoad(BookReceiptStatus.unavailable);
    }
    if (e == null) return const BookReceiptLoad(BookReceiptStatus.missing);
    // Zuerst geschwärzt: Ein geschwärztes verschlüsseltes Ereignis behält den Typ `m.room.encrypted`.
    if (e.redacted) return const BookReceiptLoad(BookReceiptStatus.missing);
    // Noch nicht entschlüsselbar (Schlüssel fehlt noch): später erneut, nie als Fälschung.
    if (e.type == EventTypes.Encrypted) return const BookReceiptLoad(BookReceiptStatus.unavailable);
    // Klartext zählt nie (wie bei allen Ereignissen der App); die Test-Naht schaltet nur die Prüfung der Verschlüsselung ab.
    if (_requireEncryptionForBooks && !arrivedEncrypted(e)) return const BookReceiptLoad(BookReceiptStatus.invalid);
    if (e.type != EventTypes.Message) return const BookReceiptLoad(BookReceiptStatus.invalid);
    final info = e.content.tryGetMap<String, Object?>('info');
    final verdict = ReceiptCheck.verifyInfo(
      sender: e.senderId,
      author: author,
      msgtype: e.content.tryGet<String>('msgtype'),
      mimeType: info?.tryGet<String>('mimetype'),
      infoSize: info?.tryGet<int>('size'),
      receipt: receipt,
    );
    if (verdict != ReceiptVerdict.ok) return const BookReceiptLoad(BookReceiptStatus.invalid);
    final Uint8List bytes;
    try {
      final file = await e.downloadAndDecryptAttachment(
        downloadCallback: (uri) => SdkMatrixGateway.boundedDownload(
          _http,
          uri,
          accessToken: _client!.accessToken,
          maxBytes: CashBookLimits.maxReceiptBytes,
        ),
      );
      bytes = file.bytes;
    } on GatewayException catch (g) {
      return BookReceiptLoad(g.error == GatewayError.attachmentRejected ? BookReceiptStatus.invalid : BookReceiptStatus.unavailable);
    } catch (err) {
      AppLog.w('gateway', 'Bon-Datei nicht ladbar: ${err.runtimeType}');
      return const BookReceiptLoad(BookReceiptStatus.unavailable);
    }
    if (ReceiptCheck.verifyBytes(bytes, receipt) != ReceiptVerdict.ok) return const BookReceiptLoad(BookReceiptStatus.invalid);
    return BookReceiptLoad(BookReceiptStatus.ok, bytes);
  }

  @override
  Future<void> redactBookReceipt(String roomId, String eventId) async {
    final room = _receiptRoom(roomId);
    if (!_validEventId(eventId)) throw const GatewayException(GatewayError.invalidInput);
    final Event? e;
    try {
      e = await room.getEventById(eventId).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (err) {
      throw _map(err);
    }
    if (e == null) throw const GatewayException(GatewayError.notFound);
    if (e.redacted) return; // schon geschwärzt: nichts zu tun
    // Nur eigene Dateien: Der Ersteller hat im Buch-Raum zwar `redact: 100`, schwärzt aber nie fremde Dateien.
    if (e.senderId != _client!.userID) throw const GatewayException(GatewayError.notAllowed);
    // Eigenes, aber (noch) nicht entschlüsselbares Ereignis: vorläufig.
    if (e.type == EventTypes.Encrypted) throw const GatewayException(GatewayError.serverUnreachable);
    if (e.type != EventTypes.Message) throw const GatewayException(GatewayError.notAllowed);
    try {
      await room.redactEvent(eventId).timeout(SdkMatrixGateway.roomOpTimeout);
    } catch (err) {
      AppLog.w('gateway', 'Schwärzen einer Bon-Datei fehlgeschlagen: ${err.runtimeType}');
      throw _map(err);
    }
  }
}
