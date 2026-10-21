import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_log.dart';
import '../../domain/presence.dart';
import '../matrix/matrix_gateway.dart';

/// Steuert die eigenen Statusmeldungen (E-38): „online“ im Vordergrund (sofort, dann alle
/// [PresenceCodec.heartbeat]), „offline“ beim Wechsel in den Hintergrund oder beim Abschalten.
///
/// Sendet nie ohne Familie und nie, wenn der Nutzer das Teilen ausgeschaltet hat. Antworten auf
/// Anfragen (`ask`) gehen nur an die Anfragenden und höchstens einmal je [replyGap].
class PresenceSync {
  PresenceSync({
    required this.gateway,
    required this.enabled,
    this.heartbeat = PresenceCodec.heartbeat,
    this.replyGap = const Duration(seconds: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MatrixGateway gateway;

  /// Liefert, ob der Nutzer seinen Status teilen möchte (Einstellung).
  final bool Function() enabled;
  final Duration heartbeat;
  final Duration replyGap;
  final DateTime Function() _clock;

  StreamSubscription<String>? _asks;
  Timer? _timer;
  bool _foreground = false;
  bool _started = false;

  /// Zuletzt gesendeter Zustand (nach Erfolg); `null` = noch nichts gesendet.
  bool? _sent;
  bool _busy = false;
  bool _again = false;
  String? _roomId;
  DateTime? _lastTry;
  final Map<String, DateTime> _lastReply = <String, DateTime>{};

  /// Ob wir gerade als online gelten sollen.
  bool get wantsOnline => _started && _foreground && enabled();

  bool get _ready => gateway.session == SessionState.ready && gateway.family != null;

  void start({required bool foreground}) {
    if (_started) return;
    _started = true;
    _foreground = foreground;
    _roomId = gateway.family?.roomId;
    _asks = gateway.presenceAsks.listen(_onAsk);
    gateway.addListener(_onGateway);
    _timer = Timer.periodic(heartbeat, (_) => _tick());
    update();
  }

  void dispose() {
    final wasOnline = _sent == true;
    _started = false;
    _timer?.cancel();
    _asks?.cancel().ignore();
    gateway.removeListener(_onGateway);
    // Beim Schließen der Oberfläche noch „offline“ melden (best effort; TTL deckt Ausfälle ab).
    if (wasOnline && _ready) {
      gateway.announcePresence(online: false).catchError((Object e) {
        AppLog.w('presence', 'Offline-Meldung nicht gesendet');
      }).ignore();
    }
  }

  void setForeground(bool v) {
    if (_foreground == v) return;
    _foreground = v;
    update();
  }

  void _onGateway() {
    // Andere Familie: in der neuen von vorn beginnen (sofort „online“ mit Bitte um Antwort).
    final room = gateway.family?.roomId;
    if (room != _roomId) {
      _roomId = room;
      _sent = null;
    }
    // Familie/Sitzung wurden erst jetzt bereit: den gewünschten Zustand nachholen (höchstens alle 10 s,
    // damit ein dauerhafter Fehler nicht bei jeder Änderung einen Sendeversuch auslöst).
    if (_ready && _sent == null) {
      final now = _clock();
      final last = _lastTry;
      if (last != null && now.difference(last) < const Duration(seconds: 10)) return;
      _lastTry = now;
      update();
    }
  }

  /// Meldet vor dem Abmelden noch „offline“ (best effort, kurze Zeitschranke).
  Future<void> goOffline() async {
    if (_sent != true || !_ready) return;
    try {
      await gateway.announcePresence(online: false).timeout(const Duration(seconds: 5));
      _sent = false;
    } catch (_) {
      AppLog.w('presence', 'Offline-Meldung vor dem Abmelden nicht gesendet');
    }
  }

  void _tick() {
    if (wantsOnline && _ready) {
      // Ein früherer Versuch ist gescheitert: beim Neuversuch wieder um Antworten bitten.
      _send(online: true, ask: _sent != true).ignore();
    }
  }

  /// Gleicht den gesendeten mit dem gewünschten Zustand ab (z. B. nach Einstellungs- oder Lebenszyklusänderung).
  void update() {
    if (!_started || !_ready) return;
    final want = wantsOnline;
    if (want && _sent != true) {
      _send(online: true, ask: true).ignore();
    } else if (!want && _sent == true) {
      _send(online: false, ask: false).ignore();
    } else if (!want && _sent == null) {
      // Nichts gemeldet, aber auch nichts nötig.
    }
  }

  Future<void> _send({required bool online, required bool ask}) async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      await gateway.announcePresence(online: online, ask: ask);
      _sent = online;
    } on GatewayException catch (e) {
      AppLog.w('presence', 'Statusmeldung verschoben (${e.error.name})');
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        update();
      }
    }
  }

  void _onAsk(String userId) {
    if (!wantsOnline || !_ready) return;
    final now = _clock();
    final last = _lastReply[userId];
    if (last != null && now.difference(last) < replyGap) return;
    _lastReply[userId] = now;
    if (_lastReply.length > 100) _lastReply.clear();
    gateway.announcePresence(online: true, onlyTo: userId).catchError((Object e) {
      AppLog.w('presence', 'Antwort auf Statusanfrage nicht gesendet');
    }).ignore();
  }

  @visibleForTesting
  bool? get lastSent => _sent;
}
