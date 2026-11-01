import 'package:uuid/uuid.dart';

import 'calendar_event.dart';
import 'server.dart';
import 'task_period.dart';
import 'task_rule.dart';
import 'task_store.dart';
import 'time_zones.dart';

export 'task_period.dart' show TaskInterval;
export 'task_rule.dart' show TaskRepeat, TaskRule;

/// Ohne Steuer-/Bidi-Zeichen, erlaubt aber ZWNJ/ZWJ (U+200C/U+200D) wie die Erklärung (#161).
final RegExp _badText = RegExp(
  '[\\u0000-\\u001F\\u007F-\\u009F\\u061C\\u200B\\u200E\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
);

/// Wie [_badText], erlaubt aber Zeilenumbrüche (mehrzeilige Erklärung) sowie ZWNJ/ZWJ (U+200C/U+200D),
/// ohne die zusammengesetzte Emojis (👨‍👩‍👧) und viele Schriften nicht darstellbar wären.
final RegExp _badDescription = RegExp(
  '[\\u0000-\\u0009\\u000B-\\u001F\\u007F-\\u009F\\u061C\\u200B\\u200E\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
);

/// Leer oder nur Leerraum und Verbinder (ZWNJ/ZWJ): sonst wäre ein Titel unsichtbar (#161).
bool _blank(String s) => s.replaceAll(RegExp('[\\u200C\\u200D]'), '').trim().isEmpty;

/// Ein Punkt einer Aufgabenliste.
class TaskItem {
  const TaskItem({required this.id, required this.title});

  final String id;
  final String title;

  @override
  bool operator ==(Object other) => other is TaskItem && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);
}

/// Definition einer Aufgabenliste (E-51, E-58): Titel, optionale Erklärung, zugewiesene Person,
/// Wiederholungsregel, Punkte.
///
/// Nur Moderatoren legen Listen an oder ändern sie. Gleichzeitige Änderungen konvergieren über
/// [TaskMerge] (höhere Version, dann Zeit, dann Absender-ID). Erledigungen stehen **nicht** hier,
/// sondern im anfügenden Protokoll ([TaskLogEntry]).
class TaskList {
  /// [rule] legt fest, wann die Liste erneuert wird; ohne Angabe gilt das bisherige [interval].
  TaskList({
    required this.id,
    required this.title,
    required this.assignee,
    TaskInterval interval = TaskInterval.daily,
    TaskRule? rule,
    required this.timeZone,
    required this.items,
    required this.by,
    required this.updatedAt,
    this.description = '',
    this.deleted = false,
    this.version = 1,
  }) : rule = rule ?? TaskRule.fromInterval(interval);

  static const int maxTitle = 100;
  static const int maxDescription = 500;
  static const int maxItems = 50;
  static const int maxVersion = 1000000;

  /// Höchstzahl aktiver Listen und aller Datensätze (inkl. Löschmarken), Speicherschutz.
  static const int maxActive = 30;
  static const int maxTotal = 100;
  static const int keepTombstones = 20;

  static const int maxFirstVersion = 10000;
  static const int maxVersionJump = 1000;

  final String id;
  final String title;

  /// Matrix-ID der Person, der die Liste zugewiesen ist.
  final String assignee;

  /// Wann die Liste neu startet (E-58).
  final TaskRule rule;

  /// Optionale Erklärung des Moderators (z. B. was genau zu tun ist).
  final String description;

  /// Grobe Einordnung der [rule] (täglich, wöchentlich, monatlich).
  TaskInterval get interval => rule.interval;

  /// IANA-Zeitzone, in der Periodengrenzen (Mitternacht, Wochen- und Monatswechsel) gelten.
  final String timeZone;
  final List<TaskItem> items;
  final bool deleted;
  final int version;

  /// Letzter Bearbeiter (Matrix-ID); beim Empfang muss er dem authentischen Absender entsprechen.
  final String by;
  final DateTime updatedAt;

  List<String> validate() {
    final p = <String>[];
    if (!CalendarEvent.isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(by)) p.add('by');
    if (!MatrixIds.isUserId(assignee)) p.add('assignee');
    if (version < 1 || version > maxVersion) p.add('version');
    if (!updatedAt.isUtc || updatedAt.isBefore(CalendarEvent.minDate) || updatedAt.isAfter(CalendarEvent.maxDate)) p.add('time');
    if (TimeZones.tryGet(timeZone) == null) p.add('tz');
    if (title.runes.length > maxTitle || _badText.hasMatch(title)) p.add('title');
    if (!rule.isValid) p.add('rule');
    if (description.runes.length > maxDescription || _badDescription.hasMatch(description)) p.add('description');
    if (items.length > maxItems) p.add('items');
    final seen = <String>{};
    for (final i in items) {
      if (!CalendarEvent.isValidId(i.id) || !seen.add(i.id)) p.add('item-id');
      final t = i.title;
      if (_blank(t) || t.runes.length > maxTitle || _badText.hasMatch(t)) p.add('item-title');
    }
    if (deleted) {
      if (title.isNotEmpty || items.isNotEmpty || description.isNotEmpty) p.add('tombstone');
    } else if (_blank(title)) {
      p.add('title');
    }
    return p;
  }

  TaskList copyWith({
    String? title,
    String? description,
    String? assignee,
    TaskRule? rule,
    String? timeZone,
    List<TaskItem>? items,
    bool? deleted,
    int? version,
    String? by,
    DateTime? updatedAt,
  }) =>
      TaskList(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        assignee: assignee ?? this.assignee,
        rule: rule ?? this.rule,
        timeZone: timeZone ?? this.timeZone,
        items: items ?? this.items,
        deleted: deleted ?? this.deleted,
        version: version ?? this.version,
        by: by ?? this.by,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is TaskList &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.assignee == assignee &&
      other.rule == rule &&
      other.timeZone == timeZone &&
      _sameItems(other.items, items) &&
      other.deleted == deleted &&
      other.version == version &&
      other.by == by &&
      other.updatedAt == updatedAt;

  static bool _sameItems(List<TaskItem> a, List<TaskItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, description, assignee, rule, timeZone, Object.hashAll(items), deleted, version, by, updatedAt);
}

enum TaskLogKind { done, undone }

/// Ein Protokolleintrag: Punkt erledigt (oder Erledigung zurückgenommen). Einträge werden nur
/// angefügt, nie überschrieben; der Verlauf ist die Vereinigung über die [id].
class TaskLogEntry {
  const TaskLogEntry({
    required this.id,
    required this.listId,
    required this.itemId,
    required this.periodKey,
    required this.doneOn,
    required this.at,
    required this.by,
    this.kind = TaskLogKind.done,
    this.comment = '',
  });

  static const int maxComment = 200;

  /// Je Liste bleiben höchstens so viele (neueste) veröffentlichte Einträge; insgesamt höchstens [maxTotal].
  static const int keepPerList = 500;
  static const int maxTotal = 5000;

  /// Größte Abweichung zwischen gemeldetem Zeitpunkt und Zeit des Matrix-Ereignisses.
  static const Duration maxSkew = Duration(days: 2);

  final String id;
  final String listId;
  final String itemId;

  /// Periode, in der erledigt wurde (siehe [TaskPeriod]).
  final String periodKey;

  /// Lokales Datum `yyyy-MM-dd` in der Zeitzone der Liste.
  final String doneOn;

  /// Zeitpunkt des Abhakens (UTC).
  final DateTime at;
  final TaskLogKind kind;
  final String comment;

  /// Person, die abgehakt hat; beim Empfang muss sie dem authentischen Absender entsprechen.
  final String by;

  List<String> validate() {
    final p = <String>[];
    if (!CalendarEvent.isValidId(id) || !CalendarEvent.isValidId(listId) || !CalendarEvent.isValidId(itemId)) p.add('id');
    if (!MatrixIds.isUserId(by)) p.add('by');
    if (!at.isUtc || at.isBefore(CalendarEvent.minDate) || at.isAfter(CalendarEvent.maxDate)) p.add('time');
    if (TaskPeriod.parseDate(doneOn) == null) {
      p.add('doneOn');
    } else if (!TaskPeriod.isKey(periodKey) || !_plausiblePeriod(periodKey, doneOn)) {
      p.add('period');
    }
    if (comment.runes.length > maxComment || _badText.hasMatch(comment)) p.add('comment');
    return p;
  }

  /// Bisherige Schlüssel passen zu einem Intervall; Schlüssel neuer Regeln (E-58) sind das Startdatum
  /// der Periode und liegen höchstens eine Periodenlänge vor dem Erledigungsdatum. Ob der Schlüssel
  /// zur Regel der Liste passt, prüft [TaskProgress.isValidFor].
  static bool _plausiblePeriod(String key, String doneOn) {
    if (TaskInterval.values.any((i) => TaskPeriod.keyForDate(i, doneOn) == key)) return true;
    final k = TaskPeriod.parseDate(key);
    final d = TaskPeriod.parseDate(doneOn)!;
    if (k == null) return false;
    final diff = DateTime.utc(d.y, d.m, d.d).difference(DateTime.utc(k.y, k.m, k.d)).inDays;
    return diff >= 0 && diff < TaskRule.maxPeriodDays;
  }

  @override
  bool operator ==(Object other) =>
      other is TaskLogEntry &&
      other.id == id &&
      other.listId == listId &&
      other.itemId == itemId &&
      other.periodKey == periodKey &&
      other.doneOn == doneOn &&
      other.at == at &&
      other.kind == kind &&
      other.comment == comment &&
      other.by == by;

  @override
  int get hashCode => Object.hash(id, listId, itemId, periodKey, doneOn, at, kind, comment, by);
}

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
