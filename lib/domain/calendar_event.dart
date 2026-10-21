import 'package:timezone/timezone.dart' as tz;

import 'recurrence.dart';
import 'server.dart';
import 'time_zones.dart';

/// Sichtbarkeit: privat = nur eigene Geräte, geteilt = Familienraum.
enum EventVisibility { private, shared }

enum RsvpStatus { accepted, declined, maybe }

/// Ein Termin.
///
/// Zeitmodell (E-20): Termine mit Uhrzeit speichern [start]/[end] als UTC-Zeitpunkt
/// plus IANA-Zeitzone [timeZone]; Wiederholungen werden in dieser Zone auf
/// Wanduhrzeit gerechnet. Ganztägige Termine sind zeitzonenfrei: [start] und
/// [end] sind die UTC-Mitternachten des ersten und des **letzten** Tages (inklusive).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.start,
    required this.end,
    required this.timeZone,
    required this.updatedAt,
    this.version = 1,
    this.allDay = false,
    this.location = '',
    this.note = '',
    this.colorIndex = 0,
    this.visibility = EventVisibility.private,
    this.recurrence = Recurrence.none,
    this.attendees = const <String>[],
    this.deleted = false,
  });

  static const int maxTitle = 200;
  static const int maxLocation = 200;
  static const int maxNote = 5000;
  static const int maxAttendees = 100;
  static const int colorCount = 8;
  static final DateTime minDate = DateTime.utc(2000);
  static final DateTime maxDate = DateTime.utc(2100);
  static const int maxDurationDays = 366;

  final String id;

  /// Matrix-ID des Erstellers. Bei geteilten Terminen ist das der Absender des
  /// Ereignisses (nicht fälschbar im Inhalt, siehe [EventCodec]).
  final String ownerId;
  final int version;
  final String title;
  final DateTime start;
  final DateTime end;
  final String timeZone;
  final bool allDay;
  final String location;
  final String note;
  final int colorIndex;
  final EventVisibility visibility;
  final Recurrence recurrence;
  final List<String> attendees;
  final DateTime updatedAt;
  final bool deleted;

  bool get isShared => visibility == EventVisibility.shared;

  Duration get duration => allDay ? Duration(days: end.difference(start).inDays + 1) : end.difference(start);

  static final RegExp _idRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static bool isValidId(String s) => _idRe.hasMatch(s);

  // Steuer-, Bidi- und Nullbreiten-Zeichen sind in Titel/Ort unzulässig; in der Notiz sind nur
  // Zeilenumbruch und Tabulator erlaubt.
  static final RegExp _badText = RegExp(
    '[\\u0000-\\u001F\\u007F-\\u009F\\u061C\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
  );
  static final RegExp _badNote = RegExp(
    '[\\u0000-\\u0008\\u000B-\\u001F\\u007F-\\u009F\\u061C\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
  );

  /// Fachliche Prüfung; leer = gültig. Wird beim Anlegen und beim Import genutzt.
  List<String> validate() {
    final p = <String>[];
    if (!isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(ownerId)) p.add('owner');
    if (version < 1 || version > 0x7fffffff) p.add('version');
    final t = title.trim();
    if (t.isEmpty || title.length > maxTitle) p.add('title');
    if (location.length > maxLocation) p.add('location');
    if (note.length > maxNote) p.add('note');
    if (_badText.hasMatch(title) || _badText.hasMatch(location)) p.add('text');
    if (_badNote.hasMatch(note)) p.add('text');
    if (colorIndex < 0 || colorIndex >= colorCount) p.add('color');
    if (!start.isUtc || !end.isUtc || !updatedAt.isUtc) p.add('utc');
    if (start.isBefore(minDate) || start.isAfter(maxDate) || end.isBefore(minDate) || end.isAfter(maxDate)) p.add('range');
    if (end.isBefore(start)) p.add('end-before-start');
    if (!allDay && end.difference(start) > const Duration(days: maxDurationDays)) p.add('duration');
    if (allDay && end.difference(start).inDays + 1 > maxDurationDays) p.add('duration');
    if (allDay && (start.hour != 0 || start.minute != 0 || end.hour != 0 || end.minute != 0)) p.add('allday-time');
    if (TimeZones.tryGet(timeZone) == null) p.add('timezone');
    if (attendees.length > maxAttendees || attendees.any((a) => !MatrixIds.isUserId(a))) p.add('attendees');
    p.addAll(recurrence.validate().map((e) => 'recurrence:$e'));
    // Ein Enddatum vor dem ersten Tag ergäbe keinen einzigen Termin.
    final until = recurrence.until;
    final loc = TimeZones.tryGet(timeZone);
    if (until != null && loc != null) {
      final first = allDay ? start : tz.TZDateTime.from(start, loc);
      if (until.isBefore(DateTime.utc(first.year, first.month, first.day))) p.add('recurrence:until-before-start');
    }
    return p;
  }

  CalendarEvent copyWith({
    int? version,
    String? title,
    DateTime? start,
    DateTime? end,
    String? timeZone,
    bool? allDay,
    String? location,
    String? note,
    int? colorIndex,
    EventVisibility? visibility,
    Recurrence? recurrence,
    List<String>? attendees,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      CalendarEvent(
        id: id,
        ownerId: ownerId,
        version: version ?? this.version,
        title: title ?? this.title,
        start: start ?? this.start,
        end: end ?? this.end,
        timeZone: timeZone ?? this.timeZone,
        allDay: allDay ?? this.allDay,
        location: location ?? this.location,
        note: note ?? this.note,
        colorIndex: colorIndex ?? this.colorIndex,
        visibility: visibility ?? this.visibility,
        recurrence: recurrence ?? this.recurrence,
        attendees: attendees ?? this.attendees,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  /// Löschmarke (Tombstone): behält nur die ID und erhöht die Version. Zeitpunkt, Zeitzone und
  /// Farbe werden bewusst nicht übernommen (ein nie veröffentlichter Termin verrät so nichts).
  CalendarEvent tombstone(DateTime now) => CalendarEvent(
        id: id,
        ownerId: ownerId,
        version: version + 1,
        title: '–',
        start: minDate,
        end: minDate,
        timeZone: 'Etc/UTC',
        visibility: visibility,
        updatedAt: now.toUtc(),
        deleted: true,
      );

  @override
  bool operator ==(Object other) =>
      other is CalendarEvent &&
      other.id == id &&
      other.ownerId == ownerId &&
      other.version == version &&
      other.title == title &&
      other.start == start &&
      other.end == end &&
      other.timeZone == timeZone &&
      other.allDay == allDay &&
      other.location == location &&
      other.note == note &&
      other.colorIndex == colorIndex &&
      other.visibility == visibility &&
      other.recurrence == recurrence &&
      _listEq(other.attendees, attendees) &&
      other.updatedAt == updatedAt &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(id, ownerId, version, title, start, end, timeZone, allDay, updatedAt, deleted);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
