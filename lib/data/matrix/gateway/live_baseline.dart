part of '../sdk_matrix_gateway.dart';

/// Grundlinie für Meldungen (AP-5, #254, E-88): ab wann Ereignisse als „neu“ gelten. Die Felder (`_live*`, `_maxServerTs`,
/// `_pendingSeed`), `liveSkew` und die statischen Hilfen (`_later`, `_capLive`, `_readLiveSeed`, `latestSynced`) bleiben
/// in der Klasse (Tests und andere Module nutzen sie).
mixin _LiveBaselineModule on ChangeNotifier implements MatrixGateway {
  int get _liveGeneration;
  set _liveGeneration(int value);
  String? get _liveKey;
  set _liveKey(String? value);
  DateTime? get _liveSince;
  set _liveSince(DateTime? value);
  bool get _liveFirstPending;
  set _liveFirstPending(bool value);
  DateTime? get _maxServerTs;
  set _maxServerTs(DateTime? value);
  Future<DateTime?>? get _pendingSeed;
  set _pendingSeed(Future<DateTime?>? value);

  void _resetLive() {
    _liveGeneration++;
    _liveSince = null;
    _maxServerTs = null;
    _liveKey = null;
    _liveFirstPending = false;
  }

  /// Wertet einen Sync für [liveSince] aus. Künstliche Syncs des SDK (Verlauf, Sendezustände) haben ein leeres
  /// `nextBatch` und zählen nicht; `room.lastEvent` scheidet aus, weil es App-Ereignisse nicht kennt.
  void _trackLive(Client client, SyncUpdate update) {
    if (update.nextBatch.isEmpty) return;
    final key = '${client.userID}|${client.deviceID}';
    if (key != _liveKey) {
      _resetLive();
      _liveKey = key;
    }
    final seen = _liveSince != null || _liveFirstPending;
    for (final room in update.rooms?.join?.values ?? const <JoinedRoomUpdate>[]) {
      for (final e in room.timeline?.events ?? const <MatrixEvent>[]) {
        _maxServerTs = SdkMatrixGateway._later(_maxServerTs, e.originServerTs.toUtc());
      }
    }
    if (seen) return;
    _liveFirstPending = true;
    final generation = _liveGeneration;
    final seed = _pendingSeed ?? Future<DateTime?>.value();
    _pendingSeed = null;
    seed.catchError((Object _) => null).then((value) {
      if (generation != _liveGeneration) return;
      _liveFirstPending = false;
      _liveSince = SdkMatrixGateway._capLive(SdkMatrixGateway._later(value, _maxServerTs) ?? DateTime.now().toUtc());
      notifyListeners();
    });
  }
}
