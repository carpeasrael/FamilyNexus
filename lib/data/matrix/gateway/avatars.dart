part of '../sdk_matrix_gateway.dart';

/// Avatare (#422, E-101): die Wahl eines der zwölf eingebauten Avatare liegt als Raumzustand
/// (`de.inneso.familynexus.avatar`, Schlüssel = eigene Matrix-ID) im Familienraum, bewusst nicht Ende-zu-Ende-
/// verschlüsselt. Gelesen wird durch direktes Nachschlagen in `room.states`, nie durch Iteration. Die Felder
/// (`_avatarRevision`, `_avatarSnapshot`, Wächter) bleiben in der Klasse.
mixin _AvatarsModule on ChangeNotifier implements MatrixGateway {
  _AppClient? get _client;
  Family? get _family;
  bool get _syncedOnce;
  bool get _disposed;
  FamilyScope get _scope;
  ValueNotifier<int> get _avatarRevision;
  Map<String, String> get _avatarSnapshot;
  set _avatarSnapshot(Map<String, String> value);
  bool get _ensureAvatarPermissionEnabled;
  DateTime Function() get _now;
  Future<void>? get _avatarRun;
  set _avatarRun(Future<void>? value);
  DateTime? get _avatarPauseUntil;
  set _avatarPauseUntil(DateTime? value);
  Room? _familyRoom();
  Future<void> _roomOp(Future<void> Function(Room room) op);

  /// Pause nach einem Fehler und nach einem Erfolg der Freischaltung (E-101). Die Uhr bestimmt nur diese Pausen.
  static const Duration avatarPauseAfterError = Duration(minutes: 5);
  static const Duration avatarPauseAfterSuccess = Duration(minutes: 2);

  @override
  ValueListenable<int> get avatarRevision => _avatarRevision;

  @override
  String? avatarOf(String userId) {
    final f = _family;
    if (f == null || !_syncedOnce || !MatrixIds.isUserId(userId)) return null;
    final room = _familyRoom();
    if (room == null || room.id != f.roomId) return null;
    final state = room.states[AvatarPresets.type]?[userId];
    if (state == null || state.senderId != userId) return null;
    return AvatarPresets.fromContent(state.content);
  }

  @override
  AvatarAvailability get avatarAvailability {
    final f = _family;
    final room = _familyRoom();
    if (f == null || !_syncedOnce || room == null || room.id != f.roomId) return AvatarAvailability.unknown;
    return room.canChangeStateEvent(AvatarPresets.type) ? AvatarAvailability.settable : AvatarAvailability.needsModerator;
  }

  @override
  Future<void> setMemberAvatar(String? preset) async {
    if (!AvatarPresets.isValid(preset)) throw const GatewayException(GatewayError.notAllowed);
    final f = _family;
    if (f == null) throw const GatewayException(GatewayError.notFound);
    if (f.member(f.myUserId)?.status != MemberStatus.joined) throw const GatewayException(GatewayError.notAllowed);
    if (avatarAvailability != AvatarAvailability.settable) throw const GatewayException(GatewayError.notAllowed);
    await _roomOp((room) => room.client.setRoomStateWithKey(room.id, AvatarPresets.type, f.myUserId, AvatarPresets.content(preset)));
  }

  /// Vergleicht den Avatar-Stand der Mitglieder (Kennung, Anzeigename, Beitrittsstatus) mit dem vorigen und zählt
  /// [avatarRevision] nur bei einer Änderung hoch (E-101). Ohne Familie ist der Stand leer.
  void _updateAvatarSnapshot() {
    final f = _family;
    final next = <String, String>{
      if (f != null && _syncedOnce)
        for (final m in f.members) m.userId: '${avatarOf(m.userId) ?? ''}|${m.displayName}|${m.status.name}',
    };
    final prev = _avatarSnapshot;
    var same = prev.length == next.length;
    if (same) {
      for (final e in next.entries) {
        if (prev[e.key] != e.value) {
          same = false;
          break;
        }
      }
    }
    if (same) return;
    _avatarSnapshot = next;
    if (!_disposed) _avatarRevision.value++;
  }

  // -------------------------------------------------- Freischaltung für Mitglieder

  /// Läuft bei jedem Aufbau der Familie (entkoppelt, blockiert ihn nicht), wenn [_ensureAvatarPermissionEnabled].
  void _ensureAvatarPermission() {
    if (!_ensureAvatarPermissionEnabled) return;
    unawaited(_runAvatarPermission());
  }

  /// Genau ein Lauf der Freischaltung (E-101): nur ein Moderator, nur mit vorhandenen und änderbaren Power-Levels,
  /// nur wenn der lokale Stand die Freigabe nicht zeigt; nie dauerhaft „erledigt“, nur Pausen und ein Lauf zugleich.
  Future<void> _runAvatarPermission() {
    final existing = _avatarRun;
    if (existing != null) return existing;
    final client = _client;
    final f = _family;
    final room = _familyRoom();
    if (client == null || !client.isLogged() || f == null || room == null || room.id != f.roomId) return Future<void>.value();
    if (!Permissions.isModerator(f)) return Future<void>.value();
    final local = room.getState(EventTypes.RoomPowerLevels);
    if (local == null || !room.canChangePowerLevel) return Future<void>.value();
    if (AvatarPresets.isPermitted(local.content)) return Future<void>.value();
    final pause = _avatarPauseUntil;
    if (pause != null && _now().isBefore(pause)) return Future<void>.value();
    final run = _grantAvatarPermission(client, room.id, _scope.generation).whenComplete(() => _avatarRun = null);
    _avatarRun = run;
    return run;
  }

  Future<void> _grantAvatarPermission(_AppClient client, String roomId, int generation) async {
    bool stale() => _disposed || generation != _scope.generation || _client != client || _scope.roomId != roomId;
    try {
      for (var attempt = 0;; attempt++) {
        // Vom Server lesen, nie den lokalen Zwischenspeicher zurückschreiben (E-60).
        final current = await client.getRoomStateWithKey(roomId, EventTypes.RoomPowerLevels, '');
        if (stale()) return;
        final updated = AvatarPresets.withPermission(current);
        if (updated == null) {
          _avatarPauseUntil = _now().add(avatarPauseAfterSuccess);
          return;
        }
        try {
          await client.setRoomStateWithKey(roomId, EventTypes.RoomPowerLevels, '', updated);
        } on MatrixException catch (e) {
          if (stale()) return;
          // Eine einzige Wiederholung der eigenen, idempotenten Schreibung nach veraltetem Stand (E-101, E-60).
          if (e.errcode == 'M_FORBIDDEN' && attempt == 0) continue;
          rethrow;
        }
        if (stale()) return;
        _avatarPauseUntil = _now().add(avatarPauseAfterSuccess);
        return;
      }
    } catch (e) {
      AppLog.w('gateway', 'Avatar-Freischaltung nicht möglich');
      if (!stale()) _avatarPauseUntil = _now().add(avatarPauseAfterError);
    }
  }

  /// Nur für Tests: führt genau einen Lauf der Freischaltung aus und wartet auf sein Ende (mit denselben
  /// Bedingungen und demselben Wächter wie der automatische Lauf).
  @visibleForTesting
  Future<void> debugRunAvatarPermission() => _runAvatarPermission();
}
