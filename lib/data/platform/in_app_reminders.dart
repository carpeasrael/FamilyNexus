import 'dart:async';

import '../../core/app_log.dart';
import '../../domain/reminder_planner.dart';

/// Erinnerungen, die die App selbst hält und anzeigt, solange sie läuft (Linux E-50, Windows E-52): Das
/// Plugin kann dort nicht verlässlich im Voraus planen. Geprüft wird gegen die Uhrzeit (nicht mit einem langen
/// Timer), damit Erinnerungen auch nach einem Standby noch erscheinen. Ohne Plugin testbar: Anzeige und Uhr
/// sind austauschbar (#152).
class InAppReminders {
  InAppReminders({required this.show, DateTime Function()? clock, this.tickInterval = const Duration(seconds: 30)})
      : _clock = clock ?? DateTime.now;

  final Future<void> Function(int id, String title, String body) show;
  final DateTime Function() _clock;
  final Duration tickInterval;

  /// Verpasste Erinnerungen (z. B. Rechner im Standby) erscheinen nur, wenn sie höchstens so alt sind.
  static const Duration staleAfter = Duration(minutes: 30);

  List<_InApp> _list = const <_InApp>[];
  Timer? _tick;

  bool get isEmpty => _list.isEmpty;
  bool get tickActive => _tick != null;

  /// Ersetzt die Liste. Was bis jetzt fällig geworden ist, wird vorher noch gezeigt: Der Planer liefert nur
  /// Zukünftiges, eine seit dem letzten Takt fällige Erinnerung ginge sonst verloren (#152). Ein in den
  /// letzten Sekunden verschobener oder gelöschter Termin zeigt seine alte Erinnerung dabei noch einmal.
  void replace(List<PlannedReminder> planned, {required String title, required String Function(int minutesBefore) bodyFor}) {
    fireDue().ignore();
    _list = <_InApp>[
      for (final r in planned) _InApp(r.id, r.fireAt.toUtc(), title, bodyFor(r.minutesBefore)),
    ];
    _tick?.cancel();
    _tick = _list.isEmpty ? null : Timer.periodic(tickInterval, (_) => fireDue());
    fireDue().ignore();
  }

  /// Zeigt fällige Erinnerungen; öffentlich für Tests.
  Future<void> fireDue([DateTime? now]) async {
    final t = (now ?? _clock()).toUtc();
    final due = _list.where((r) => !r.fireAt.isAfter(t)).toList();
    if (due.isEmpty) return;
    _list = _list.where((r) => r.fireAt.isAfter(t)).toList();
    if (_list.isEmpty) {
      _tick?.cancel();
      _tick = null;
    }
    for (final r in due) {
      if (t.difference(r.fireAt) > staleAfter) continue;
      try {
        await show(r.id, r.title, r.body);
      } catch (e) {
        AppLog.e('reminders', 'Erinnerung konnte nicht angezeigt werden', e);
      }
    }
  }

  void clear() {
    _list = const <_InApp>[];
    _tick?.cancel();
    _tick = null;
  }
}

class _InApp {
  const _InApp(this.id, this.fireAt, this.title, this.body);
  final int id;
  final DateTime fireAt;
  final String title;
  final String body;
}
