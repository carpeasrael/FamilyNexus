import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';

Map<String, Object?> _shared([CalendarEvent? e]) => EventCodec.encodeShared(e ?? ev());

DecodeResult _dec(Map<String, Object?> m, {String sender = kOwner, EventVisibility v = EventVisibility.shared}) =>
    EventCodec.decode(m, sender: sender, visibility: v);

void main() {
  setUpAll(TimeZones.ensureInitialized);

  test('Roundtrip erhält alle Felder inkl. Wiederholung und Teilnehmer', () {
    final e = ev(
      title: 'Zahnarzt',
      attendees: const <String>[kOther],
      recurrence: Recurrence(
        frequency: Frequency.weekly,
        interval: 2,
        weekdays: const <int>{1, 3},
        until: DateTime.utc(2026, 12, 31),
        exdates: const <String>{'2026-04-01'},
      ),
    ).copyWith(location: 'Praxis', note: 'Karte mitbringen', colorIndex: 3);
    final r = _dec(_shared(e));
    expect(r.isOk, isTrue, reason: r.error);
    expect(r.event, e);
  });

  test('ganztägiger Termin und Tombstone laufen durch', () {
    final e = ev(allDay: true, allDayEnd: DateTime.utc(2026, 3, 22));
    expect(_dec(_shared(e)).event, e);
    final t = ev().tombstone(DateTime.utc(2026, 4));
    final r = _dec(_shared(t));
    expect(r.event!.deleted, isTrue);
    expect(r.event!.version, 2);
  });

  test('Löschmarke enthält weder Zeitpunkt noch Farbe des Termins', () {
    final t = ev().tombstone(DateTime.utc(2026, 4));
    expect(t.start, CalendarEvent.minDate);
    expect(t.end, CalendarEvent.minDate);
    expect(t.colorIndex, 0);
    expect(t.title, '–');
  });

  group('Sichtbarkeit', () {
    test('private Termine können nicht für den Familienraum kodiert werden', () {
      expect(() => EventCodec.encodeShared(ev(visibility: EventVisibility.private)), throwsStateError);
    });
    test('geteilte Termine gehören nicht in den privaten Raum', () {
      expect(() => EventCodec.encodePrivate(ev()), throwsStateError);
      expect(EventCodec.encodePrivate(ev(visibility: EventVisibility.private)), isNotEmpty);
    });
    test('Sichtbarkeit steht nie im Inhalt; sie ergibt sich aus dem Raum', () {
      final m = _shared();
      expect(m.containsKey('visibility'), isFalse);
      expect(_dec(m, v: EventVisibility.private).event!.visibility, EventVisibility.private);
    });
  });

  group('Fälschungsschutz und Validierung', () {
    test('Absender muss mit owner übereinstimmen', () {
      final r = _dec(_shared(), sender: kOther);
      expect(r.isOk, isFalse);
      expect(r.error, 'owner-mismatch');
    });

    test('falsche Schemaversion, Typen und fehlende Felder werden abgelehnt', () {
      final base = _shared();
      for (final entry in <String, Object?>{
        'v': 2,
        'title': 5,
        'version': '1',
        'deleted': 'nein',
        'start': 'gestern',
        'end': '2026-03-20T09:00:00', // ohne Z → lokal, nicht UTC
        'tz': 'Mars/Olympus',
        'all_day': null,
        'color': 99,
        'attendees': <Object?>[1],
        'rec': 'x',
        'id': 'kein-uuid',
      }.entries) {
        final m = Map<String, Object?>.of(base)..[entry.key] = entry.value;
        expect(_dec(m).isOk, isFalse, reason: entry.key);
      }
      for (final k in base.keys) {
        final m = Map<String, Object?>.of(base)..remove(k);
        expect(_dec(m).isOk, isFalse, reason: 'fehlt: $k');
      }
    });

    test('Größenlimits', () {
      final base = _shared();
      expect(_dec(Map<String, Object?>.of(base)..['title'] = 'x' * 201).isOk, isFalse);
      expect(_dec(Map<String, Object?>.of(base)..['note'] = 'x' * 5001).isOk, isFalse);
      expect(_dec(Map<String, Object?>.of(base)..['attendees'] = List<String>.filled(101, kOther)).isOk, isFalse);
      expect(_dec(Map<String, Object?>.of(base)..['title'] = '   ').isOk, isFalse);
    });

    test('unsinnige Zeiten und Wiederholungen', () {
      final base = _shared();
      expect(_dec(Map<String, Object?>.of(base)..['end'] = '2026-03-19T09:00:00.000Z').isOk, isFalse, reason: 'Ende vor Beginn');
      expect(_dec(Map<String, Object?>.of(base)..['start'] = '1900-01-01T00:00:00.000Z').isOk, isFalse);
      final rec = Map<String, Object?>.of(base['rec']! as Map<String, Object?>);
      for (final bad in <Map<String, Object?>>[
        <String, Object?>{'interval': 0},
        <String, Object?>{'interval': 100000},
        <String, Object?>{'freq': 'hourly'},
        <String, Object?>{'count': 99999, 'freq': 'daily'},
        <String, Object?>{'ex': <Object?>['kein-datum'], 'freq': 'daily'},
        <String, Object?>{'weekdays': <Object?>[9], 'freq': 'weekly'},
        <String, Object?>{'count': 3, 'until': '2026-05-01T00:00:00.000Z', 'freq': 'daily'},
      ]) {
        final m = Map<String, Object?>.of(base)..['rec'] = (Map<String, Object?>.of(rec)..addAll(bad));
        expect(_dec(m).isOk, isFalse, reason: '$bad');
      }
    });

    test('Termine über 366 Tage Dauer werden abgelehnt', () {
      final e = ev(length: const Duration(days: 400));
      expect(e.validate(), contains('duration'));
    });

    test('Zufallsmüll stürzt nie ab', () {
      for (final junk in <Map<String, Object?>>[
        <String, Object?>{},
        <String, Object?>{'v': 1},
        <String, Object?>{'v': 1, 'owner': kOwner, 'rec': <String, Object?>{}},
        <String, Object?>{'v': 1, 'owner': kOwner, 'rec': <String, Object?>{'freq': 'daily', 'interval': 1, 'weekdays': 'x'}},
      ]) {
        expect(() => _dec(junk), returnsNormally);
        expect(_dec(junk).isOk, isFalse);
      }
    });

    test('ungültiger Absender wird abgelehnt', () {
      expect(_dec(_shared(), sender: 'nicht-mxid').isOk, isFalse);
    });
  });

  group('RSVP', () {
    test('Roundtrip inkl. Zeitstempel des Absenders', () {
      final ts = DateTime.utc(2026, 3, 20, 10, 5, 7, 123);
      final m = EventCodec.encodeRsvp(kId1, RsvpStatus.maybe, ts);
      final r = EventCodec.decodeRsvp(m)!;
      expect(r.eventId, kId1);
      expect(r.status, RsvpStatus.maybe);
      expect(r.timestamp, ts);
    });
    test('ungültige Inhalte → null', () {
      for (final m in <Map<String, Object?>>[
        <String, Object?>{'v': 1, 'event_id': 'x', 'status': 'accepted', 'ts': 1},
        <String, Object?>{'v': 1, 'event_id': kId1, 'status': 'vielleicht', 'ts': 1700000000000},
        <String, Object?>{'v': 2, 'event_id': kId1, 'status': 'accepted', 'ts': 1700000000000},
        <String, Object?>{'v': 1, 'event_id': kId1, 'status': 'accepted'},
        <String, Object?>{'v': 1, 'event_id': kId1, 'status': 'accepted', 'ts': '1700000000000'},
        <String, Object?>{'v': 1, 'event_id': kId1, 'status': 'accepted', 'ts': 99999999999999},
        <String, Object?>{'v': 1, 'event_id': kId1, 'status': 'accepted', 'ts': -5},
        <String, Object?>{},
      ]) {
        expect(EventCodec.decodeRsvp(m), isNull);
      }
    });
  });

  group('Review: Text und Wiederholungsende', () {
    test('Steuer-/Bidi-/Nullbreiten-Zeichen in Titel und Ort werden abgelehnt, Zeilenumbruch in der Notiz nicht', () {
      for (final t in <String>['a\u202Eb', 'x\u200By', 'a\u0000b', 'a\nb', '\u2066x']) {
        expect(ev(title: t).validate(), contains('text'), reason: t);
      }
      expect(ev().copyWith(location: 'Ort\u202E').validate(), contains('text'));
      expect(ev().copyWith(note: 'Zeile 1\nZeile 2\tTab').validate(), isEmpty);
      expect(ev().copyWith(note: 'a\u202Eb').validate(), contains('text'));
    });

    test('#161: Termine bleiben bei E-33 – ZWJ/ZWNJ in Titel, Ort und Notiz werden weiter abgelehnt', () {
      for (final z in <String>['\u200D', '\u200C']) {
        expect(ev(title: '👨${z}👩 Essen').validate(), contains('text'), reason: z.codeUnits.toString());
        expect(ev().copyWith(location: 'Ort${z}x').validate(), contains('text'));
        expect(ev().copyWith(note: 'Notiz${z}x').validate(), contains('text'));
      }
    });

    test('Wiederholungsende vor dem ersten Termin ist ungültig', () {
      final bad = ev(recurrence: Recurrence(frequency: Frequency.daily, until: DateTime.utc(2026, 3, 19)));
      expect(bad.validate(), contains('recurrence:until-before-start'));
      final ok = ev(recurrence: Recurrence(frequency: Frequency.daily, until: DateTime.utc(2026, 3, 20)));
      expect(ok.validate(), isEmpty);
    });
  });
}
