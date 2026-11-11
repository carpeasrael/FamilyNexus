part of '../sdk_matrix_gateway.dart';

/// Familie (AP-5): Familie anlegen. Die Raumsuche (`_familyRoom`, `_familyRoomAnyState`) und die Konstanten
/// (`familyAccountData`, `maxFamilyNameLength`, `roomSyncTimeout`) bleiben in der Klasse (alle Module nutzen sie).
mixin _FamilyModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Room? _familyRoomAnyState();
  GatewayException _map(Object e);
  Future<void> _refresh();

  @override
  Future<void> createFamily(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > SdkMatrixGateway.maxFamilyNameLength) {
      throw const GatewayException(GatewayError.invalidInput);
    }
    final client = _client;
    if (client == null || !client.isLogged()) throw const GatewayException(GatewayError.notAllowed);
    if (!client.encryptionEnabled) throw const GatewayException(GatewayError.encryptionUnavailable);
    // Eine bestehende (oder angefragte) Familie darf nie überschrieben werden.
    final existing = _familyRoomAnyState();
    if (existing != null && existing.membership != Membership.leave && existing.membership != Membership.ban) {
      throw const GatewayException(GatewayError.alreadyExists);
    }
    try {
      final me = client.userID!;
      final roomId = await client.createRoom(
        name: trimmed,
        roomVersion: FamilyRoomSpec.roomVersion,
        preset: CreateRoomPreset.privateChat,
        visibility: Visibility.private,
        initialState: <StateEvent>[
          for (final s in FamilyRoomSpec.initialState())
            StateEvent(type: s.type, stateKey: '', content: s.content),
        ],
        powerLevelContentOverride: FamilyRoomSpec.powerLevels(me),
      );
      // Verweis sofort schreiben (idempotent, 2 Versuche); sonst bliebe ein verwaister Raum.
      for (var attempt = 0;; attempt++) {
        try {
          await client.setAccountData(me, SdkMatrixGateway.familyAccountData, <String, Object?>{'room_id': roomId});
          break;
        } catch (e) {
          if (attempt >= 1) rethrow;
        }
      }
      try {
        await client.waitForRoomInSync(roomId, join: true).timeout(SdkMatrixGateway.roomSyncTimeout);
      } on TimeoutException {
        AppLog.w('gateway', 'Raum noch nicht im Sync; Anzeige folgt beim nächsten Abgleich');
      }
      await _refresh();
    } catch (e) {
      AppLog.e('gateway', 'Familie konnte nicht angelegt werden', e);
      throw _map(e);
    }
  }
}
