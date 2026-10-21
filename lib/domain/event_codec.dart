import 'calendar_event.dart';
import 'recurrence.dart';
import 'server.dart';

/// Ergebnis des Dekodierens eines fremden (nicht vertrauenswürdigen) Ereignisses.
class DecodeResult {
  const DecodeResult.ok(CalendarEvent this.event) : error = null;
  const DecodeResult.failure(String this.error) : event = null;

  final CalendarEvent? event;
  final String? error;
  bool get isOk => event != null;
}

/// Ereignisformat v1 (E-13). Geteilte Termine laufen als Zeitleisten-Ereignis
/// `de.inneso.familynexus.event` im verschlüsselten Familienraum, private als
/// `de.inneso.familynexus.private_event` im privaten Raum des eigenen Kontos.
///
/// Sicherheitsregeln:
/// * [encodeShared] akzeptiert ausschließlich geteilte, [encodePrivate] nur private Termine.
/// * Beim Dekodieren muss das Feld `owner` mit dem authentischen Absender des
///   Matrix-Ereignisses übereinstimmen, sonst wird verworfen (kein Fälschen in
///   fremdem Namen). Alle Felder werden streng typgeprüft und über
///   [CalendarEvent.validate] begrenzt.
class EventCodec {
  const EventCodec._();

  static const String sharedType = 'de.inneso.familynexus.event';
  static const String privateType = 'de.inneso.familynexus.private_event';
  static const String rsvpType = 'de.inneso.familynexus.rsvp';
  static const int schema = 1;

  static Map<String, Object?> encodeShared(CalendarEvent e) {
    if (e.visibility != EventVisibility.shared) {
      throw StateError('Nur geteilte Termine dürfen in den Familienraum gesendet werden');
    }
    return _encode(e);
  }

  static Map<String, Object?> encodePrivate(CalendarEvent e) {
    if (e.visibility != EventVisibility.private) {
      throw StateError('In den privaten Raum gehören nur private Termine');
    }
    return _encode(e);
  }

  /// Speicherformat der lokalen (verschlüsselten) Datenbank: wie das Ereignisformat,
  /// aber für beide Sichtbarkeiten. Wird **nie** gesendet.
  static Map<String, Object?> encodeStored(CalendarEvent e) => _encode(e);

  static DecodeResult decodeStored(Map<String, Object?> c, {required String owner, required EventVisibility visibility}) =>
      decode(c, sender: owner, visibility: visibility);

  static Map<String, Object?> _encode(CalendarEvent e) {
    final problems = e.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Termin: ${problems.join(',')}');
    final r = e.recurrence;
    return <String, Object?>{
      'v': schema,
      'id': e.id,
      'owner': e.ownerId,
      'version': e.version,
      'deleted': e.deleted,
      'title': e.title,
      'start': e.start.toIso8601String(),
      'end': e.end.toIso8601String(),
      'tz': e.timeZone,
      'all_day': e.allDay,
      'location': e.location,
      'note': e.note,
      'color': e.colorIndex,
      'rec': <String, Object?>{
        'freq': r.frequency.name,
        'interval': r.interval,
        'weekdays': (r.weekdays.toList()..sort()),
        'count': r.count,
        'until': r.until?.toIso8601String(),
        'ex': (r.exdates.toList()..sort()),
      },
      'attendees': e.attendees,
      'updated_at': e.updatedAt.toIso8601String(),
    };
  }

  /// Deterministische Darstellung (sortierte Schlüssel) für Gleichstand-Auflösung.
  static String canonical(CalendarEvent e) {
    final m = _encode(e);
    final keys = m.keys.toList()..sort();
    return keys.map((k) => '$k=${m[k]}').join('|');
  }

  static DecodeResult decode(
    Map<String, Object?> c, {
    required String sender,
    required EventVisibility visibility,
  }) {
    try {
      if (!MatrixIds.isUserId(sender)) return const DecodeResult.failure('sender');
      if (c['v'] != schema) return const DecodeResult.failure('schema');
      final owner = _str(c, 'owner');
      if (owner != sender) return const DecodeResult.failure('owner-mismatch');
      final rec = c['rec'];
      if (rec is! Map<String, Object?>) return const DecodeResult.failure('rec');

      final freqName = _str(rec, 'freq');
      final freq = Frequency.values.where((f) => f.name == freqName);
      if (freq.isEmpty) return const DecodeResult.failure('freq');

      final until = rec['until'];
      final count = rec['count'];
      final recurrence = Recurrence(
        frequency: freq.first,
        interval: _int(rec, 'interval'),
        weekdays: _intList(rec, 'weekdays').toSet(),
        count: count == null ? null : _int(rec, 'count'),
        until: until == null ? null : _date(until),
        exdates: _strList(rec, 'ex').toSet(),
      );

      final event = CalendarEvent(
        id: _str(c, 'id'),
        ownerId: owner,
        version: _int(c, 'version'),
        deleted: _bool(c, 'deleted'),
        title: _str(c, 'title'),
        start: _date(c['start']),
        end: _date(c['end']),
        timeZone: _str(c, 'tz'),
        allDay: _bool(c, 'all_day'),
        location: _str(c, 'location'),
        note: _str(c, 'note'),
        colorIndex: _int(c, 'color'),
        visibility: visibility,
        recurrence: recurrence,
        attendees: _strList(c, 'attendees'),
        updatedAt: _date(c['updated_at']),
      );
      final problems = event.validate();
      if (problems.isNotEmpty) return DecodeResult.failure(problems.first);
      return DecodeResult.ok(event);
    } on FormatException catch (e) {
      return DecodeResult.failure(e.message);
    }
  }

  // ---------------------------------------------------------------- RSVP

  /// [timestamp] ist der Zeitpunkt der Antwort auf der Uhr des Absenders; er
  /// ordnet mehrere Antworten derselben Person (nicht die Serverzeit, damit
  /// verspätete Echos eine neuere Antwort nicht überschreiben).
  static Map<String, Object?> encodeRsvp(String eventId, RsvpStatus status, DateTime timestamp) {
    if (!CalendarEvent.isValidId(eventId)) throw StateError('ungültige Termin-ID');
    return <String, Object?>{
      'v': schema,
      'event_id': eventId,
      'status': status.name,
      'ts': timestamp.toUtc().millisecondsSinceEpoch,
    };
  }

  /// `null` bei ungültigem Inhalt.
  static ({String eventId, RsvpStatus status, DateTime timestamp})? decodeRsvp(Map<String, Object?> c) {
    if (c['v'] != schema) return null;
    final id = c['event_id'];
    final st = c['status'];
    final ts = c['ts'];
    if (id is! String || !CalendarEvent.isValidId(id) || st is! String || ts is! int) return null;
    final when = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    if (when.isBefore(CalendarEvent.minDate) || when.isAfter(CalendarEvent.maxDate)) return null;
    for (final s in RsvpStatus.values) {
      if (s.name == st) return (eventId: id, status: s, timestamp: when);
    }
    return null;
  }

  // --------------------------------------------------------------- Helfer

  static String _str(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! String) throw FormatException(k);
    return v;
  }

  static int _int(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! int) throw FormatException(k);
    return v;
  }

  static bool _bool(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! bool) throw FormatException(k);
    return v;
  }

  static List<String> _strList(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! List<Object?> || v.length > 2000) throw FormatException(k);
    return <String>[
      for (final e in v)
        if (e is String) e else throw FormatException(k),
    ];
  }

  static List<int> _intList(Map<String, Object?> m, String k) {
    final v = m[k];
    if (v is! List<Object?> || v.length > 14) throw FormatException(k);
    return <int>[
      for (final e in v)
        if (e is int) e else throw FormatException(k),
    ];
  }

  static DateTime _date(Object? v) {
    if (v is! String || v.length > 40) throw const FormatException('date');
    final d = DateTime.tryParse(v);
    if (d == null || !d.isUtc) throw const FormatException('date');
    return d;
  }
}
