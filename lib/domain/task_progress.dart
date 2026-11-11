import 'task_models.dart';
import 'task_period.dart';
import 'time_zones.dart';

/// Konfliktregel für Listen (wie E-40).
class TaskMerge {
  const TaskMerge._();

  static bool incomingWins(TaskList? current, TaskList incoming) {
    if (current == null) return true;
    if (incoming.version != current.version) return incoming.version > current.version;
    final byTime = incoming.updatedAt.compareTo(current.updatedAt);
    if (byTime != 0) return byTime > 0;
    final byAuthor = incoming.by.compareTo(current.by);
    if (byAuthor != 0) return byAuthor > 0;
    return _tie(incoming).compareTo(_tie(current)) > 0;
  }

  static String _tie(TaskList l) =>
      '${l.deleted}|${l.title}|${l.description}|${l.assignee}|${l.rule}|${l.timeZone}|${l.items.map((i) => '${i.id}=${i.title}').join(',')}';
}

/// Abgeleiteter Zustand einer Liste: was ist in der **aktuellen** Periode erledigt? (E-51)
class TaskProgress {
  const TaskProgress._();

  /// Ein Eintrag zählt nur, wenn er von der zugewiesenen Person stammt und in sich stimmig ist
  /// (Periode passt zum Intervall und Datum, Datum passt zum Zeitpunkt in der Zeitzone der Liste).
  static bool isValidFor(TaskList list, TaskLogEntry e) {
    if (e.listId != list.id || e.by != list.assignee) return false;
    final loc = TimeZones.tryGet(list.timeZone);
    if (loc == null) return false;
    if (TaskPeriod.localDate(loc, e.at) != e.doneOn) return false;
    return list.rule.keyForDate(e.doneOn) == e.periodKey;
  }

  /// Erledigte Punkte der aktuellen Periode: Punkt-ID → maßgeblicher Eintrag.
  static Map<String, TaskLogEntry> doneNow(TaskList list, Iterable<TaskLogEntry> log, DateTime now) {
    final loc = TimeZones.tryGet(list.timeZone);
    if (loc == null) return const <String, TaskLogEntry>{};
    final current = list.rule.key(loc, now);
    final latest = <String, TaskLogEntry>{};
    final known = {for (final i in list.items) i.id};
    for (final e in log) {
      if (e.periodKey != current || !known.contains(e.itemId) || !isValidFor(list, e)) continue;
      final prev = latest[e.itemId];
      if (prev == null || _newer(e, prev)) latest[e.itemId] = e;
    }
    latest.removeWhere((_, e) => e.kind != TaskLogKind.done);
    return latest;
  }

  static bool _newer(TaskLogEntry a, TaskLogEntry b) {
    final c = a.at.compareTo(b.at);
    return c != 0 ? c > 0 : a.id.compareTo(b.id) > 0;
  }

  /// Eintrag ist echt (zugewiesene Person, Datum passt zum Zeitpunkt), unabhängig von der aktuellen Regel.
  static bool _authentic(TaskList list, TaskLogEntry e) {
    if (e.listId != list.id || e.by != list.assignee) return false;
    final loc = TimeZones.tryGet(list.timeZone);
    return loc != null && TaskPeriod.localDate(loc, e.at) == e.doneOn;
  }

  /// Verlauf der Liste, neueste zuerst. Auch Einträge aus der Zeit vor einer Regeländerung bleiben
  /// sichtbar (Review R5); für den aktuellen Stand zählt dagegen nur [doneNow].
  static List<TaskLogEntry> history(TaskList list, Iterable<TaskLogEntry> log) =>
      <TaskLogEntry>[for (final e in log) if (_authentic(list, e)) e]
        ..sort((a, b) {
          final c = b.at.compareTo(a.at);
          return c != 0 ? c : b.id.compareTo(a.id);
        });
}
