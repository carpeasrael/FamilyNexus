import 'calendar_event.dart';
import 'server.dart';
import 'task_period.dart';
import 'task_rule.dart';
import 'time_zones.dart';

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
