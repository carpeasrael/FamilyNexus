import 'package:uuid/uuid.dart';

import 'task_models.dart';
import 'task_period.dart';
import 'task_progress.dart';
import 'task_rule.dart';
import 'task_store.dart';
import 'time_zones.dart';

enum TaskError { invalid, notFound, limit, notAllowed }

class TaskException implements Exception {
  const TaskException(this.error);
  final TaskError error;

  @override
  String toString() => 'TaskException(${error.name})';
}

/// Fachlogik der Aufgabenlisten; kennt nur den [TaskStore]-Port.
///
/// [isModerator] liefert, ob eine Person (Matrix-ID) aktuell Moderator der Familie ist. Die Domäne
/// kennt die Familie nicht; die Prüfung wird eingereicht. Sie gilt für lokale Änderungen und für den
/// Empfang (fremde Listenänderungen von Nicht-Moderatoren werden verworfen).
class TaskService {
  TaskService({
    required this.store,
    required this.myUserId,
    required this.isModerator,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final TaskStore store;
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

  List<TaskItem> _items(Iterable<String> titles, [List<TaskItem> existing = const <TaskItem>[]]) {
    // Bestehende Punkte behalten ihre ID, wenn der Titel unverändert an derselben Stelle bleibt.
    final out = <TaskItem>[];
    final unused = List<TaskItem>.of(existing);
    for (final raw in titles) {
      final t = _norm(raw);
      if (t.isEmpty) continue;
      final i = unused.indexWhere((e) => e.title == t);
      if (i >= 0) {
        out.add(unused.removeAt(i));
      } else {
        out.add(TaskItem(id: _newId(), title: t));
      }
    }
    return out;
  }

  void _requireModerator() {
    if (!isModerator(myUserId)) throw const TaskException(TaskError.notAllowed);
  }

  void _check(TaskList l) {
    if (l.validate().isNotEmpty) throw const TaskException(TaskError.invalid);
  }

  /// Erklärung: Leerraum je Zeile vereinheitlicht, höchstens zwei Leerzeilen in Folge.
  static String _normDescription(String s) => s
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  Future<TaskList> createList({
    required String title,
    required String assignee,
    TaskInterval interval = TaskInterval.daily,
    TaskRule? rule,
    String description = '',
    required String timeZone,
    required List<String> items,
  }) =>
      _serial(() async {
        _requireModerator();
        final list = TaskList(
          id: _newId(),
          title: _norm(title),
          description: _normDescription(description),
          assignee: assignee,
          interval: interval,
          rule: rule,
          timeZone: timeZone,
          items: _items(items),
          by: myUserId,
          updatedAt: now,
        );
        _check(list);
        var c = await store.listCounts();
        if (c.total >= TaskList.maxTotal) {
          await store.pruneListTombstones(keep: TaskList.keepTombstones);
          c = await store.listCounts();
        }
        if (c.active >= TaskList.maxActive || c.total >= TaskList.maxTotal) {
          throw const TaskException(TaskError.limit);
        }
        await store.putList(list, publishedVersion: 0);
        return list;
      });

  Future<TaskList> updateList(
    String id, {
    required String title,
    required String assignee,
    TaskInterval? interval,
    TaskRule? rule,
    String? description,
    required List<String> items,
  }) =>
      _serial(() async {
        _requireModerator();
        final current = await store.getList(id);
        if (current == null || current.deleted) throw const TaskException(TaskError.notFound);
        if (current.version >= TaskList.maxVersion) throw const TaskException(TaskError.limit);
        final next = current.copyWith(
          title: _norm(title),
          description: description == null ? null : _normDescription(description),
          assignee: assignee,
          rule: rule ?? (interval == null ? null : TaskRule.fromInterval(interval)),
          items: _items(items, current.items),
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        await store.putList(next);
        return next;
      });

  Future<void> deleteList(String id) => _serial(() async {
        _requireModerator();
        final current = await store.getList(id);
        if (current == null || current.deleted) throw const TaskException(TaskError.notFound);
        if (current.version >= TaskList.maxVersion) throw const TaskException(TaskError.limit);
        final next = current.copyWith(
          title: '',
          description: '',
          // Löschmarke immer im Format v1: ältere App-Versionen müssen das Löschen auch sehen (Review R1).
          rule: TaskRule.fromInterval(current.interval),
          items: const <TaskItem>[],
          deleted: true,
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        await store.putList(next);
      });

  /// Hakt einen Punkt in der aktuellen Periode ab (nur die zugewiesene Person).
  Future<TaskLogEntry> complete(String listId, String itemId, {String comment = ''}) =>
      _log(listId, itemId, TaskLogKind.done, comment);

  /// Nimmt die Erledigung in der aktuellen Periode zurück.
  Future<TaskLogEntry> undo(String listId, String itemId, {String comment = ''}) =>
      _log(listId, itemId, TaskLogKind.undone, comment);

  Future<TaskLogEntry> _log(String listId, String itemId, TaskLogKind kind, String comment) => _serial(() async {
        final list = await store.getList(listId);
        if (list == null || list.deleted) throw const TaskException(TaskError.notFound);
        if (list.assignee != myUserId) throw const TaskException(TaskError.notAllowed);
        if (!list.items.any((i) => i.id == itemId)) throw const TaskException(TaskError.notFound);
        final loc = TimeZones.tryGet(list.timeZone);
        if (loc == null) throw const TaskException(TaskError.invalid);
        final at = now;
        final on = TaskPeriod.localDate(loc, at);
        final entry = TaskLogEntry(
          id: _newId(),
          listId: listId,
          itemId: itemId,
          periodKey: list.rule.keyForDate(on)!,
          doneOn: on,
          at: at,
          by: myUserId,
          kind: kind,
          comment: _norm(comment),
        );
        if (entry.validate().isNotEmpty) throw const TaskException(TaskError.invalid);
        if (await store.logCount(listId) >= TaskLogEntry.keepPerList) {
          await store.pruneLog(listId, keep: TaskLogEntry.keepPerList - 1);
        }
        await store.addLog(entry, published: false);
        return entry;
      });

  /// Nimmt eine empfangene (dekodierte) Liste an; `true`, wenn sich der Bestand geändert hat.
  Future<bool> applyIncomingList(TaskList incoming) => _serial(() async {
        // Nur Moderatoren dürfen Listen anlegen oder ändern.
        if (!isModerator(incoming.by)) return false;
        final current = await store.getList(incoming.id);
        if (current == null) {
          if (incoming.version > TaskList.maxFirstVersion) return false;
          var c = await store.listCounts();
          if (c.total >= TaskList.maxTotal) {
            await store.pruneListTombstones(keep: TaskList.keepTombstones);
            c = await store.listCounts();
          }
          if (c.total >= TaskList.maxTotal || (!incoming.deleted && c.active >= TaskList.maxActive)) return false;
        } else if (incoming.version > current.version + TaskList.maxVersionJump) {
          return false;
        }
        if (!TaskMerge.incomingWins(current, incoming)) return false;
        await store.putList(incoming, publishedVersion: incoming.version);
        return true;
      });

  /// Nimmt einen empfangenen Protokolleintrag an. [serverTime] ist die Zeit des Matrix-Ereignisses;
  /// weicht der gemeldete Zeitpunkt stark davon ab, wird der Eintrag verworfen.
  Future<bool> applyIncomingLog(TaskLogEntry incoming, {required DateTime serverTime}) => _serial(() async {
        if ((incoming.at.difference(serverTime.toUtc())).abs() > TaskLogEntry.maxSkew) return false;
        if (await store.hasLog(incoming.id)) return false;
        if (await store.logTotal() >= TaskLogEntry.maxTotal) return false;
        if (await store.logCount(incoming.listId) >= TaskLogEntry.keepPerList) {
          await store.pruneLog(incoming.listId, keep: TaskLogEntry.keepPerList - 1);
        }
        await store.addLog(incoming, published: true);
        return true;
      });
}
