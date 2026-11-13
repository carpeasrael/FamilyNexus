import 'package:uuid/uuid.dart';

import 'event_theme_store.dart';
import 'event_themes.dart';

enum EventThemeError { invalid, notFound, limit, notAllowed }

class EventThemeException implements Exception {
  const EventThemeException(this.error);
  final EventThemeError error;

  @override
  String toString() => 'EventThemeException(${error.name})';
}

/// Fachlogik der Kalender-Themen (E-99); kennt nur den [EventThemeStore]-Port.
///
/// [isModerator] liefert, ob eine Person (Matrix-ID) aktuell Moderator der Familie ist. Die Prüfung
/// gilt für lokale Änderungen und für den Empfang (Themen von Nicht-Moderatoren werden verworfen).
class EventThemeService {
  EventThemeService({
    required this.store,
    required this.myUserId,
    required this.isModerator,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final EventThemeStore store;
  final String myUserId;
  final bool Function(String userId) isModerator;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(_clock().toUtc().millisecondsSinceEpoch, isUtc: true);

  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  void _requireModerator() {
    if (!isModerator(myUserId)) throw const EventThemeException(EventThemeError.notAllowed);
  }

  void _check(EventTheme t) {
    if (t.validate().isNotEmpty) throw const EventThemeException(EventThemeError.invalid);
  }

  Future<EventTheme> create({required String name, required int colorIndex}) => _serial(() async {
        _requireModerator();
        final theme = EventTheme(
          id: _newId(),
          name: _norm(name),
          colorIndex: colorIndex,
          by: myUserId,
          updatedAt: now,
        );
        _check(theme);
        var c = await store.counts();
        if (c.total >= EventTheme.maxTotal) {
          await store.pruneTombstones(keep: EventTheme.keepTombstones);
          c = await store.counts();
        }
        if (c.active >= EventTheme.maxActive || c.total >= EventTheme.maxTotal) {
          throw const EventThemeException(EventThemeError.limit);
        }
        await store.put(theme, publishedVersion: 0);
        return theme;
      });

  Future<EventTheme> rename(String id, String name) => _change(id, name: name);

  Future<EventTheme> recolor(String id, int colorIndex) => _change(id, colorIndex: colorIndex);

  /// Benennt ein Thema um und/oder ändert seine Farbe (eine neue Version).
  Future<EventTheme> update(String id, {required String name, required int colorIndex}) =>
      _change(id, name: name, colorIndex: colorIndex);

  Future<EventTheme> _change(String id, {String? name, int? colorIndex}) => _serial(() async {
        _requireModerator();
        final current = await store.get(id);
        if (current == null || current.deleted) throw const EventThemeException(EventThemeError.notFound);
        if (current.version >= EventTheme.maxVersion) throw const EventThemeException(EventThemeError.limit);
        final next = current.copyWith(
          name: name == null ? null : _norm(name),
          colorIndex: colorIndex,
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        await store.put(next);
        return next;
      });

  Future<void> delete(String id) => _serial(() async {
        _requireModerator();
        final current = await store.get(id);
        if (current == null || current.deleted) throw const EventThemeException(EventThemeError.notFound);
        if (current.version >= EventTheme.maxVersion) throw const EventThemeException(EventThemeError.limit);
        final next = current.copyWith(
          name: '',
          deleted: true,
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        await store.put(next);
      });

  /// Nimmt ein empfangenes (dekodiertes) Thema an; `true`, wenn sich der Bestand geändert hat.
  Future<bool> applyIncoming(EventTheme incoming) => _serial(() async {
        // Nur Moderatoren dürfen Themen anlegen oder ändern (zum Zeitpunkt des Empfangs).
        if (!isModerator(incoming.by)) return false;
        final current = await store.get(incoming.id);
        if (current == null) {
          if (incoming.version > EventTheme.maxFirstVersion) return false;
          var c = await store.counts();
          if (c.total >= EventTheme.maxTotal) {
            await store.pruneTombstones(keep: EventTheme.keepTombstones);
            c = await store.counts();
          }
          if (c.total >= EventTheme.maxTotal || (!incoming.deleted && c.active >= EventTheme.maxActive)) return false;
        } else if (incoming.version > current.version + EventTheme.maxVersionJump) {
          return false;
        }
        if (!EventThemeMerge.incomingWins(current, incoming)) return false;
        await store.put(incoming, publishedVersion: incoming.version);
        return true;
      });
}
