import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_log.dart';
import '../../domain/avatar_photo.dart';
import '../../domain/avatar_photo_service.dart';
import '../../domain/avatar_photo_store.dart';
import '../../domain/calendar_signal.dart';
import '../matrix/matrix_gateway.dart';
import 'send_backoff.dart';

/// Verbindet die Avatar-Fotos mit Matrix (#434, E-111), nach dem Muster von `EventThemeSync`:
///
/// * eingehend: Signale streng prüfen ([AvatarPhotoCodec], [AvatarResetCodec]), über [AvatarPhotoService] zusammenführen
///   (neuestes Ereignis gewinnt, Zurücksetzen als wachsende Menge);
/// * ausgehend: noch nicht gesendete eigene Fotos und Zurücksetzen (Warteschlange mit Wiederholung), danach das
///   Schwärzen früherer eigener Kopien (nur Aufräumen, nach bestem Bemühen, nie Zustand);
/// * Resync: beim Beitritt neuer Mitglieder das eigene aktuelle Ereignis (gleiche `id` und `created_at`) und, als
///   Moderator, alle bekannten Zurücksetzen erneut senden.
///
/// Solange [enabled] `false` ist (Sperre [AvatarPhotoFlags.enabled]), tut die Klasse nichts: Sie hört nicht zu, sendet
/// nichts und startet keinen Zeitgeber.
class AvatarPhotoSync {
  AvatarPhotoSync({
    required this.gateway,
    required this.service,
    required this.store,
    this.enabled = AvatarPhotoFlags.enabled,
    this.retryInterval = const Duration(seconds: 60),
    DateTime Function()? clock,
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  }) : _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final AvatarPhotoService service;
  final AvatarPhotoStore store;
  final bool enabled;
  final Duration retryInterval;
  final SendBackoff _backoff;

  /// Wird nach jeder Änderung des lokalen Bestands aufgerufen (Anzeige neu aufbauen).
  void Function()? onChanged;

  /// Verworfene (ungültige, gefälschte oder unberechtigte) Ereignisse.
  int rejected = 0;

  StreamSubscription<CalendarSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;

  String get _me => service.myUserId;
  String get _room => service.roomId;

  /// Fehlerstand der Warteschlange (Tests).
  @visibleForTesting
  SendBackoff get backoff => _backoff;

  /// `false`: Die aktuelle Familie ist eine andere als die, zu der der lokale Bestand gehört (#140). „Keine Familie“
  /// ist kein Wechsel.
  bool get _sameFamily {
    final current = gateway.family?.roomId;
    return current == null || current == _room;
  }

  Future<void> _queue = Future<void>.value();

  void _enqueue(CalendarSignal s) {
    _queue = _queue.then((_) => _onSignal(s)).catchError((Object e) {
      AppLog.e('avatarphoto', 'Signal konnte nicht verarbeitet werden', e);
    });
  }

  /// Wartet, bis alle bisher eingegangenen Signale verarbeitet sind (Schließen der Familie, Tests).
  Future<void> idle() => _queue;

  void start() {
    if (!enabled) return;
    _sub ??= gateway.calendarSignals.listen(_enqueue);
    _timer ??= Timer.periodic(retryInterval, (_) => kick());
    _backoff.changed(_gatewayState()); // Ausgangszustand merken, erst spätere Wechsel heben das Fenster auf
    gateway.addListener(_onGatewayChanged);
    kick();
  }

  Object _gatewayState() =>
      (gateway.session, gateway.userId, gateway.server, gateway.family?.roomId, gateway.initialSyncDone);

  /// Im Wartefenster nach einem Sendefehler löst eine Meldung des Gateways keinen neuen Versuch aus (#132).
  void _onGatewayChanged() {
    final changed = _backoff.changed(_gatewayState());
    if (!changed && _backoff.blocked) return;
    kick();
  }

  void dispose() {
    _sub?.cancel().ignore();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    if (enabled) gateway.removeListener(_onGatewayChanged);
  }

  void kick() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => publishPending().ignore());
  }

  Future<void> _onSignal(CalendarSignal s) async {
    // Bleibt in der Historie des Gateways für die neuen Dienste (#140).
    if (!_sameFamily) return;
    try {
      switch (s) {
        case AvatarPhotoSignal():
          final photo = AvatarPhotoCodec.decode(s.content, sender: s.sender, now: _now());
          if (photo == null) {
            rejected++;
            AppLog.w('avatarphoto', 'Ungültiges Avatar-Foto verworfen');
            return;
          }
          if (!service.isMember(photo.owner)) {
            rejected++;
            return;
          }
          if (await service.acceptPhoto(photo, eventId: s.eventId)) onChanged?.call();
        case AvatarResetSignal():
          final reset = AvatarResetCodec.decode(s.content, sender: s.sender);
          if (reset == null) {
            rejected++;
            AppLog.w('avatarphoto', 'Ungültiges Zurücksetzen verworfen');
            return;
          }
          if (await service.acceptReset(reset, sender: s.sender)) {
            onChanged?.call();
          } else {
            rejected++;
          }
        case MemberJoinedSignal():
          // Eigenes Ereignis (nie ein zurückgesetztes Foto) und als Moderator alle bekannten Zurücksetzen erneut senden.
          if (!await service.isResetFor(_me)) await store.requeueOwnPhoto(_room, _me);
          if (service.isModerator(_me)) await store.requeueResets(_room);
          kick();
        default:
          break;
      }
    } catch (e) {
      AppLog.e('avatarphoto', 'Avatar-Ereignis konnte nicht verarbeitet werden', e);
    }
  }

  DateTime _now() => service.now;

  bool get _canPublish =>
      gateway.session == SessionState.ready && gateway.initialSyncDone && gateway.family != null && _sameFamily;

  /// Entfernt Zeilen von Mitgliedern, die nicht mehr in der Familie sind (die Zurücksetzen bleiben, E-111).
  Future<void> _pruneMembers() async {
    var changed = false;
    for (final st in await store.photos(_room)) {
      if (!service.isMember(st.photo.owner)) {
        await service.removeMember(st.photo.owner);
        changed = true;
      }
    }
    if (changed) onChanged?.call();
  }

  /// Dauerhafte Fehler beim Schwärzen: weiter versuchen hilft nicht, der Auftrag entfällt.
  static bool _permanent(GatewayError e) =>
      e == GatewayError.notAllowed || e == GatewayError.notFound || e == GatewayError.invalidInput;

  /// Sendet alle noch nicht gesendeten eigenen Ereignisse, danach das Aufräumen. Läuft nie parallel. Unerwartete
  /// Fehler werden protokolliert und zählen als Fehlversuch. Der sichtbare Stand hängt nie vom Ausgang ab.
  Future<void> publishPending() async {
    if (!enabled) return;
    if (_publishing) {
      _again = true;
      return;
    }
    _publishing = true;
    try {
      do {
        _again = false;
        if (!_canPublish) break;
        await _pruneMembers();

        // 1. eigenes Foto oder eigene Löschmarke
        for (final st in await store.pendingPhotos(_room)) {
          if (st.photo.owner != _me) continue;
          if (!_canPublish) return; // Abbruch (#140): zählt weder als Erfolg noch als Fehler
          final photo = st.photo;
          if (!photo.cleared && await service.isResetFor(_me)) {
            // Ein zurückgesetztes Foto wird nie erneut gesendet (auch nicht im Resync).
            await store.markPublished(_room, _me, photo.id, st.eventId);
            continue;
          }
          try {
            final eventId = await gateway.publishAvatarPhoto(photo);
            await store.markPublished(_room, _me, photo.id, eventId);
          } on GatewayException catch (err) {
            if (err.error == GatewayError.invalidInput) {
              AppLog.w('avatarphoto', 'Foto nicht sendbar, Warteschlange bereinigt');
              await store.markPublished(_room, _me, photo.id, st.eventId);
              continue;
            }
            AppLog.w('avatarphoto', 'Senden verschoben (${err.error.name})');
            _backoff.failure();
            return;
          }
        }

        // 2. Zurücksetzen (nur Moderatoren; für Empfänger entscheidet deren Prüfung)
        for (final r in await store.pendingResets(_room)) {
          if (!_canPublish) return;
          if (!service.isModerator(_me)) {
            await store.markResetPublished(_room, r.reset.target, r.reset.photoId);
            continue;
          }
          try {
            await gateway.publishAvatarReset(r.reset);
            await store.markResetPublished(_room, r.reset.target, r.reset.photoId);
          } on GatewayException catch (err) {
            if (err.error == GatewayError.invalidInput) {
              AppLog.w('avatarphoto', 'Zurücksetzen nicht sendbar, Warteschlange bereinigt');
              await store.markResetPublished(_room, r.reset.target, r.reset.photoId);
              continue;
            }
            AppLog.w('avatarphoto', 'Senden verschoben (${err.error.name})');
            _backoff.failure();
            return;
          }
        }

        // 3. Aufräumen: frühere eigene Kopien schwärzen (nach bestem Bemühen)
        for (final st in await store.redactQueue(_room)) {
          if (st.photo.owner != _me) continue;
          for (final id in List<String>.of(st.redactIds)) {
            if (!_canPublish) return;
            try {
              await gateway.redactOwnEvent(id);
              await store.clearRedacted(_room, st.photo.owner, id);
            } on GatewayException catch (err) {
              if (_permanent(err.error)) {
                AppLog.w('avatarphoto', 'Aufräumen entfällt (${err.error.name})');
                await store.clearRedacted(_room, st.photo.owner, id);
                continue;
              }
              AppLog.w('avatarphoto', 'Aufräumen verschoben (${err.error.name})');
              _backoff.failure();
              return;
            }
          }
        }
        _backoff.success();
      } while (_again);
    } catch (e) {
      // Unerwarteter Fehler (z. B. lokale Datenbank): protokollieren und als Fehlversuch zählen; die Warteschlange
      // bleibt erhalten, der nächste Anstoß oder der Timer versucht es erneut.
      AppLog.e('avatarphoto', 'Sendedurchlauf gescheitert', e);
      _backoff.failure();
    } finally {
      _publishing = false;
    }
  }
}
