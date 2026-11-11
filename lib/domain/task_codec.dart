import 'calendar_event.dart';
import 'server.dart';
import 'task_models.dart';
import 'task_period.dart';
import 'task_rule.dart';

/// Ereignisformat der Aufgabenlisten: verschlüsselte Raumereignisse im Familienraum (E-51, E-58).
///
/// Listen mit bisheriger Regel und ohne Erklärung bleiben im Format v1, damit ältere App-Versionen sie
/// unverändert lesen. Listen mit neuer Regel oder Erklärung verwenden v2 (zusätzlich `rule`, `note`);
/// ältere Versionen verwerfen sie vollständig, statt sie mit falschen Perioden anzuzeigen.
/// Protokolleinträge bleiben v1 (nur die Schlüssel neuer Regeln sind Startdaten).
class TaskCodec {
  const TaskCodec._();

  static const String listType = 'de.inneso.familynexus.tasklist';
  static const String logType = 'de.inneso.familynexus.taskdone';
  static const int schema = 1;
  static const int listSchemaV2 = 2;

  static int get _minMs => CalendarEvent.minDate.millisecondsSinceEpoch;
  static int get _maxMs => CalendarEvent.maxDate.millisecondsSinceEpoch;

  static Map<String, Object?> encodeList(TaskList l) {
    final problems = l.validate();
    if (problems.isNotEmpty) throw StateError('Ungültige Liste: ${problems.join(',')}');
    final v2 = !l.rule.isLegacy || l.description.isNotEmpty;
    return <String, Object?>{
      'v': v2 ? listSchemaV2 : schema,
      'id': l.id,
      'by': l.by,
      'version': l.version,
      'deleted': l.deleted,
      'title': l.title,
      'assignee': l.assignee,
      'interval': l.interval.name,
      if (v2) 'rule': l.rule.toJson(),
      if (v2) 'note': l.description,
      'tz': l.timeZone,
      'items': <Object?>[
        for (final i in l.items) <String, Object?>{'id': i.id, 'title': i.title},
      ],
      'ts': l.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// `null` bei ungültigem Inhalt. `by` muss mit [sender] übereinstimmen (kein Schreiben in fremdem Namen).
  static TaskList? decodeList(Map<String, Object?> c, {required String sender}) {
    final v = c['v'];
    if (!MatrixIds.isUserId(sender) || (v != schema && v != listSchemaV2)) return null;
    final id = c['id'];
    final by = c['by'];
    final version = c['version'];
    final deleted = c['deleted'];
    final title = c['title'];
    final assignee = c['assignee'];
    final interval = c['interval'];
    final zone = c['tz'];
    final items = c['items'];
    final ts = c['ts'];
    if (id is! String || by is! String || version is! int || deleted is! bool) return null;
    if (title is! String || assignee is! String || interval is! String || zone is! String) return null;
    if (items is! List<Object?> || ts is! int || by != sender) return null;
    if (ts < _minMs || ts > _maxMs) return null;
    if (title.length > TaskList.maxTitle * 2 || items.length > TaskList.maxItems) return null;
    final parsedInterval = TaskInterval.values.where((i) => i.name == interval);
    if (parsedInterval.isEmpty) return null;
    TaskRule? rule;
    var note = '';
    if (v == listSchemaV2) {
      rule = TaskRule.fromJson(c['rule']);
      final n = c['note'];
      if (rule == null || rule.interval != parsedInterval.first || n is! String) return null;
      if (n.length > TaskList.maxDescription * 2) return null;
      // Eindeutige Form: v2 nur, wenn v1 nicht genügt (sonst ließen sich v1-Listen vor älteren Versionen verbergen).
      if (rule.isLegacy && n.isEmpty) return null;
      note = n;
    } else if (c.containsKey('rule') || c.containsKey('note')) {
      return null; // v1 kennt diese Felder nicht: mehrdeutig
    }
    final out = <TaskItem>[];
    for (final e in items) {
      if (e is! Map<String, Object?>) return null;
      final iid = e['id'];
      final it = e['title'];
      if (iid is! String || it is! String || it.length > TaskList.maxTitle * 2) return null;
      out.add(TaskItem(id: iid, title: it));
    }
    final list = TaskList(
      id: id,
      title: title,
      assignee: assignee,
      interval: parsedInterval.first,
      rule: rule,
      description: note,
      timeZone: zone,
      items: out,
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
    );
    return list.validate().isEmpty ? list : null;
  }

  static Map<String, Object?> encodeLog(TaskLogEntry e) {
    final problems = e.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Eintrag: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'id': e.id,
      'list': e.listId,
      'item': e.itemId,
      'by': e.by,
      'period': e.periodKey,
      'on': e.doneOn,
      'ts': e.at.millisecondsSinceEpoch,
      'kind': e.kind.name,
      'comment': e.comment,
    };
  }

  static TaskLogEntry? decodeLog(Map<String, Object?> c, {required String sender}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final id = c['id'];
    final list = c['list'];
    final item = c['item'];
    final by = c['by'];
    final period = c['period'];
    final on = c['on'];
    final ts = c['ts'];
    final kind = c['kind'];
    final comment = c['comment'];
    if (id is! String || list is! String || item is! String || by is! String) return null;
    if (period is! String || on is! String || ts is! int || kind is! String || comment is! String) return null;
    if (by != sender || ts < _minMs || ts > _maxMs) return null;
    if (comment.length > TaskLogEntry.maxComment * 2) return null;
    final k = TaskLogKind.values.where((v) => v.name == kind);
    if (k.isEmpty) return null;
    final entry = TaskLogEntry(
      id: id,
      listId: list,
      itemId: item,
      periodKey: period,
      doneOn: on,
      at: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
      by: by,
      kind: k.first,
      comment: comment,
    );
    return entry.validate().isEmpty ? entry : null;
  }
}
