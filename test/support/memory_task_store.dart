import 'package:family_nexus/domain/task_store.dart';
import 'package:family_nexus/domain/tasks.dart';

class MemoryTaskStore implements TaskStore {
  final Map<String, TaskList> listsById = <String, TaskList>{};
  final Map<String, int> _listPublished = <String, int>{};
  final Map<String, TaskLogEntry> logById = <String, TaskLogEntry>{};
  final Map<String, bool> _logPublished = <String, bool>{};

  @override
  Future<TaskList?> getList(String id) async => listsById[id];

  @override
  Future<List<TaskList>> lists() async => listsById.values.toList();

  @override
  Future<({int active, int total})> listCounts() async =>
      (active: listsById.values.where((l) => !l.deleted).length, total: listsById.length);

  @override
  Future<void> putList(TaskList list, {int? publishedVersion}) async {
    listsById[list.id] = list;
    if (publishedVersion != null) {
      _listPublished[list.id] = publishedVersion;
    } else {
      _listPublished.putIfAbsent(list.id, () => 0);
    }
  }

  @override
  Future<List<TaskList>> pendingLists() async =>
      listsById.values.where((l) => l.version > (_listPublished[l.id] ?? 0)).toList();

  @override
  Future<void> markListPublished(String id, int version) async {
    if ((_listPublished[id] ?? 0) < version) _listPublished[id] = version;
  }

  @override
  Future<void> pruneListTombstones({required int keep}) async {
    final dead = listsById.values.where((l) => l.deleted).toList();
    final removable = dead.take((dead.length - keep).clamp(0, dead.length)).where((l) => (_listPublished[l.id] ?? 0) >= l.version);
    for (final l in removable.toList()) {
      listsById.remove(l.id);
      _listPublished.remove(l.id);
    }
  }

  @override
  Future<bool> hasLog(String id) async => logById.containsKey(id);

  @override
  Future<void> addLog(TaskLogEntry entry, {required bool published}) async {
    if (logById.containsKey(entry.id)) return;
    logById[entry.id] = entry;
    _logPublished[entry.id] = published;
  }

  @override
  Future<List<TaskLogEntry>> log({String? listId}) async =>
      logById.values.where((e) => listId == null || e.listId == listId).toList()..sort((a, b) => b.at.compareTo(a.at));

  @override
  Future<int> logCount(String listId) async => logById.values.where((e) => e.listId == listId).length;

  @override
  Future<int> logTotal() async => logById.length;

  @override
  Future<void> pruneLog(String listId, {required int keep}) async {
    final mine = logById.values.where((e) => e.listId == listId).toList()..sort((a, b) => b.at.compareTo(a.at));
    for (final e in mine.skip(keep)) {
      if (_logPublished[e.id] ?? false) {
        logById.remove(e.id);
        _logPublished.remove(e.id);
      }
    }
  }

  @override
  Future<List<TaskLogEntry>> pendingLog() async =>
      logById.values.where((e) => !(_logPublished[e.id] ?? false)).toList()..sort((a, b) => a.at.compareTo(b.at));

  @override
  Future<void> markLogPublished(String id) async {
    if (logById.containsKey(id)) _logPublished[id] = true;
  }

  @override
  Future<void> requeueLastEditedBy(String userId) async {
    for (final l in listsById.values) {
      if (l.by == userId && !l.deleted) _listPublished[l.id] = 0;
    }
    for (final e in logById.values) {
      if (e.by == userId) _logPublished[e.id] = false;
    }
  }

  @override
  Future<void> wipe() async {
    listsById.clear();
    _listPublished.clear();
    logById.clear();
    _logPublished.clear();
  }
}
