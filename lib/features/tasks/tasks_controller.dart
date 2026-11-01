import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/matrix/matrix_gateway.dart';
import '../../data/sync/task_sync.dart';
import '../../domain/permissions.dart';
import '../../domain/task_period.dart';
import '../../domain/task_store.dart';
import '../../domain/tasks.dart';
import '../../domain/time_zones.dart';

/// Zustand und Aktionen der Aufgabenlisten für die Oberfläche (E-51).
class TasksController extends ChangeNotifier {
  TasksController({
    required this.service,
    required this.store,
    required this.sync,
    required this.gateway,
    required this.zoneName,
    this.periodCheck = const Duration(minutes: 1),
  });

  final TaskService service;
  final TaskStore store;
  final TaskSync sync;
  final MatrixGateway gateway;

  /// Zeitzone dieses Geräts; neue Listen übernehmen sie als Zeitzone der Periodengrenzen.
  final String zoneName;
  final Duration periodCheck;

  List<TaskList> _lists = const <TaskList>[];
  List<TaskLogEntry> _log = const <TaskLogEntry>[];
  String _periods = '';
  Timer? _timer;
  bool _started = false;
  bool _disposed = false;

  String get me => service.myUserId;
  DateTime get now => service.now;

  bool get canManage {
    final f = gateway.family;
    return f != null && Permissions.canManageTasks(f);
  }

  /// Aktive Listen, sortiert nach Titel.
  List<TaskList> get lists => _lists;

  List<TaskList> get mine => <TaskList>[for (final l in _lists) if (l.assignee == me) l];
  List<TaskList> get others => <TaskList>[for (final l in _lists) if (l.assignee != me) l];

  TaskList? byId(String id) {
    for (final l in _lists) {
      if (l.id == id) return l;
    }
    return null;
  }

  /// Erledigte Punkte der laufenden Periode: Punkt-ID → maßgeblicher Eintrag.
  Map<String, TaskLogEntry> doneNow(TaskList l) => TaskProgress.doneNow(l, _log, now);

  int openCount(TaskList l) => l.items.length - doneNow(l).length;

  /// Offene Punkte aller mir zugewiesenen Listen.
  int get myOpenCount => mine.fold(0, (sum, l) => sum + openCount(l));

  List<TaskLogEntry> history(TaskList l) => TaskProgress.history(l, _log);

  /// [familyRoom]: Familie, zu der der lokale Bestand gehört (`AppServices.openCalendar`).
  void start({String? familyRoom}) {
    if (_started) return;
    _started = true;
    sync.onChanged = () => load().ignore();
    sync.start(familyRoom: familyRoom);
    // Periodenwechsel (Mitternacht, Wochen-, Monatswechsel) braucht keine Daten, nur eine neue Anzeige.
    _timer = Timer.periodic(periodCheck, (_) => _checkPeriods());
    load().ignore();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    sync.onChanged = null;
    sync.dispose();
    super.dispose();
  }

  String _periodSignature() => _lists.map((l) {
        final loc = TimeZones.tryGet(l.timeZone);
        return loc == null ? '' : '${l.id}=${l.rule.key(loc, now)}';
      }).join('|');

  void _checkPeriods() {
    if (_disposed) return;
    final sig = _periodSignature();
    if (sig != _periods) {
      _periods = sig;
      notifyListeners();
    }
  }

  Future<void> load() async {
    final all = await store.lists();
    final log = await store.log();
    if (_disposed) return;
    _lists = <TaskList>[for (final l in all) if (!l.deleted) l]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    _log = log;
    _periods = _periodSignature();
    notifyListeners();
  }

  /// Tag des nächsten Neustarts der Liste (Kalenderdatum in der Zeitzone der Liste), `null` bei unbekannter Zone.
  DateTime? nextReset(TaskList list) {
    final loc = TimeZones.tryGet(list.timeZone);
    if (loc == null) return null;
    final today = TaskPeriod.parseDate(TaskPeriod.localDate(loc, now));
    if (today == null) return null;
    return list.rule.nextStartAfter(DateTime.utc(today.y, today.m, today.d));
  }

  Future<TaskList> create({
    required String title,
    required String assignee,
    required TaskRule rule,
    String description = '',
    required List<String> items,
  }) async {
    final l = await service.createList(
      title: title,
      assignee: assignee,
      rule: rule,
      description: description,
      timeZone: zoneName,
      items: items,
    );
    await _changed();
    return l;
  }

  Future<void> update(
    String id, {
    required String title,
    required String assignee,
    required TaskRule rule,
    String? description,
    required List<String> items,
  }) async {
    await service.updateList(id, title: title, assignee: assignee, rule: rule, description: description, items: items);
    await _changed();
  }

  Future<void> delete(String id) async {
    await service.deleteList(id);
    await _changed();
  }

  Future<void> complete(String listId, String itemId, {String comment = ''}) async {
    await service.complete(listId, itemId, comment: comment);
    await _changed();
  }

  Future<void> undo(String listId, String itemId) async {
    await service.undo(listId, itemId);
    await _changed();
  }

  Future<void> _changed() async {
    await load();
    sync.kick();
  }
}
