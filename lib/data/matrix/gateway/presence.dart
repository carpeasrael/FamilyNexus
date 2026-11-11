part of '../sdk_matrix_gateway.dart';

/// Online-Status (AP-5, E-38): Status an Geräte der Mitglieder senden und eingehenden Status auswerten. Die Felder
/// (`_presence`, `_presenceAsks`) bleiben in der Klasse.
mixin _PresenceModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  GatewayException _map(Object e);
  PresenceBoard get _presence;
  StreamController<String> get _presenceAsks;
  @override
  Map<String, PresenceStamp> get presence => _presence.snapshot();

  @override
  Stream<String> get presenceAsks => _presenceAsks.stream;

  @override
  Future<void> announcePresence({required bool online, bool ask = false, String? onlyTo}) async {
    final client = _client;
    final f = _family;
    if (client == null || !client.isLogged() || f == null || !client.encryptionEnabled) {
      throw const GatewayException(GatewayError.notAllowed);
    }
    if (onlyTo != null && !MatrixIds.isUserId(onlyTo)) throw const GatewayException(GatewayError.invalidInput);
    // Nur an Geräte, die auch Raumschlüssel erhielten (cross-signiert, nicht gesperrt) und nur an
    // beigetretene Mitglieder – nie an Eingeladene, Anfragende oder Entfernte.
    final devices = <DeviceKeys>[];
    for (final m in f.joined) {
      if (m.userId == f.myUserId || (onlyTo != null && m.userId != onlyTo)) continue;
      final list = client.userDeviceKeys[m.userId]?.deviceKeys.values;
      if (list == null) continue;
      for (final d in list) {
        if (d.encryptToDevice) devices.add(d);
      }
    }
    if (devices.isEmpty) return;
    try {
      await client.sendToDeviceEncryptedChunked(
        devices,
        PresenceCodec.type,
        PresenceCodec.encode(online: online, now: DateTime.now().toUtc(), ask: ask),
      );
    } catch (e) {
      AppLog.e('gateway', 'Online-Status konnte nicht gesendet werden', e);
      throw _map(e);
    }
  }

  void _onToDevice(ToDeviceEvent e) {
    if (e.type != PresenceCodec.type) return;
    // Nur Ende-zu-Ende-verschlüsselt Angekommenes zählt: ein unverschlüsseltes Ereignis könnte
    // der Server im Namen eines Mitglieds erzeugen.
    if (e.encryptedContent == null) return;
    final f = _family;
    if (f == null || e.sender == f.myUserId || f.member(e.sender)?.status != MemberStatus.joined) return;
    final d = PresenceCodec.decode(Map<String, Object?>.from(e.content), now: DateTime.now().toUtc());
    if (d == null) return;
    // Je Gerät führen (Schlüssel des sendenden Geräts): ein Mitglied gilt als online, solange
    // irgendein Gerät online meldet.
    final key = e.encryptedContent?['sender_key'];
    final now = DateTime.now().toUtc();
    final before = _presence.stampOf(e.sender, now);
    if (_presence.apply(e.sender, deviceId: key is String ? key : '', online: d.online, at: d.at)) {
      final after = _presence.stampOf(e.sender, now);
      if (before == null || after == null || before.online != after.online) notifyListeners();
    }
    if (d.ask && !_presenceAsks.isClosed) _presenceAsks.add(e.sender);
  }
}
