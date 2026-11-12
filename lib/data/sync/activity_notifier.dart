import 'dart:collection';

import '../../core/app_log.dart';
import '../../domain/app_settings.dart';
import '../../domain/chat.dart';
import '../../domain/moderation.dart';
import '../matrix/matrix_gateway.dart';

/// Art einer Meldung zu Chat oder Einkauf (#254, E-88). Je Art eine feste ID, neue Ereignisse ersetzen die Meldung.
enum ActivityKind {
  chat(1),
  shopping(2);

  const ActivityKind(this.id);

  /// Feste ID der Meldung; liegt im reservierten Bereich von `ReminderPlanner.reservedIds`.
  final int id;
}

/// Zeigt und entfernt die Meldungen. Texte sind fest und generisch, ohne Absender, Gespräch oder Inhalt.
abstract class ActivityPlatform {
  /// [alert]: mit Ton/Hinweis; sonst wird die vorhandene Meldung still ersetzt.
  Future<void> show(ActivityKind kind, {required bool alert, int count = 0});

  Future<void> cancel(ActivityKind kind);
}

/// Zahl am App-Symbol (#254).
abstract class AppBadge {
  void update(int count);
}

/// Erzeugt lokale Meldungen für neue Chat-Nachrichten und neue Einträge auf dem Einkaufszettel, solange die App läuft
/// (auf Mobilgeräten nur im Vordergrund zugesagt, #273; #254, E-88; kein Push). Neu ist nur, was nach [MatrixGateway.liveSince] liegt (Server-Zeitstempel): Verlauf,
/// Nachgeladenes und alles, was bei geschlossener App kam, lösen nichts aus.
class ActivityNotifier {
  ActivityNotifier({
    required this.gateway,
    required this.platform,
    required this.settings,
    required this.isThreadVisible,
    this.badge,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final MatrixGateway gateway;
  final ActivityPlatform platform;
  final AppBadge? badge;

  /// Aktuelle Einstellungen (Schalter, blockierte Mitglieder).
  final AppSettings Function() settings;

  /// Ist das Gespräch gerade sichtbar (App im Vordergrund, nicht gesperrt, Chat-Tab, dieses Gespräch)?
  final bool Function(String threadId) isThreadVisible;
  final DateTime Function() _clock;

  /// Höchstens ein Ton bzw. Hinweis je Art in diesem Abstand; dazwischen wird still ersetzt.
  static const Duration alertInterval = Duration(seconds: 30);

  /// Gemerkte Nachrichten je Gespräch (nur die jüngsten).
  static const int maxSeenPerThread = 500;

  final Map<String, LinkedHashSet<String>> _seen = <String, LinkedHashSet<String>>{};
  final Map<ActivityKind, DateTime> _lastAlert = <ActivityKind, DateTime>{};
  final Set<ActivityKind> _shown = <ActivityKind>{};
  String? _family;
  int? _badgeCount;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    gateway.addListener(_onGateway);
    _onGateway();
  }

  void dispose() {
    if (!_started) return;
    _started = false;
    gateway.removeListener(_onGateway);
  }

  void _onGateway() {
    try {
      _check();
    } catch (e) {
      AppLog.e('activity', 'Meldungen konnten nicht geprüft werden', e);
    }
  }

  void _check() {
    final unread = gateway.unreadCount;
    if (unread != _badgeCount) {
      _badgeCount = unread;
      badge?.update(unread);
    }
    // Gelesen, auch auf einem anderen Gerät: Meldung weg.
    if (unread == 0 && _shown.remove(ActivityKind.chat)) platform.cancel(ActivityKind.chat).ignore();

    final since = gateway.liveSince;
    // Ohne Grundlinie wird nichts gemeldet und nichts gemerkt (E-88, Regel 5): Was jetzt abgebildet wird, wird nach
    // dem Setzen erneut gegen den Zeitstempel geprüft.
    if (since == null) {
      _seen.clear();
      return;
    }
    final family = gateway.family?.roomId;
    if (family != _family) {
      _family = family;
      _seen.clear();
    }
    final s = settings();
    final me = gateway.userId;
    var fresh = false;
    for (final t in gateway.threads) {
      final seen = _seen.putIfAbsent(t.id, LinkedHashSet<String>.new);
      final msgs = visibleMessages(gateway.messagesIn(t.id), s.blockedUsers, myUserId: me);
      for (var i = msgs.length - 1; i >= 0; i--) {
        final m = msgs[i];
        if (!m.time.isAfter(since)) break;
        // Nicht Entschlüsseltes nicht merken: Wird es später lesbar, ist es dann neu.
        if (m.undecryptable || m.beforeJoin) continue;
        if (!seen.add(m.id)) continue;
        if (m.senderId == me || m.status != MessageStatus.sent) continue;
        if (gateway.unreadIn(t.id) > 0 && !isThreadVisible(t.id)) fresh = true;
      }
      while (seen.length > maxSeenPerThread) {
        seen.remove(seen.first);
      }
    }
    if (fresh && s.notifyChat) _show(ActivityKind.chat, count: unread);
  }

  /// Ein anderes Mitglied hat einen neuen Eintrag angelegt (geprüft in `ShoppingSync`).
  void shoppingArrived() {
    if (!settings().notifyShopping) return;
    _show(ActivityKind.shopping);
  }

  /// Der Tab „Einkauf“ wurde geöffnet: Meldung weg.
  void clearShopping() {
    if (_shown.remove(ActivityKind.shopping)) platform.cancel(ActivityKind.shopping).ignore();
  }

  void _show(ActivityKind kind, {int count = 0}) {
    final now = _clock();
    final last = _lastAlert[kind];
    final alert = last == null || now.difference(last) >= alertInterval || now.isBefore(last);
    if (alert) _lastAlert[kind] = now;
    _shown.add(kind);
    platform.show(kind, alert: alert, count: count).catchError((Object e) {
      AppLog.e('activity', 'Meldung konnte nicht gezeigt werden', e);
    });
  }
}
