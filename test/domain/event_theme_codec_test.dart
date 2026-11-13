import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:flutter_test/flutter_test.dart';

const String kAnna = '@anna:fake.test';
const String kBen = '@ben:fake.test';
const String _id1 = '00000000-0000-4000-8000-000000000001';

EventTheme _theme({
  String id = _id1,
  String name = 'Schule',
  int color = 2,
  String by = kAnna,
  int version = 1,
  bool deleted = false,
  DateTime? at,
}) =>
    EventTheme(id: id, name: name, colorIndex: color, by: by, version: version, deleted: deleted, updatedAt: at ?? DateTime.utc(2026, 10, 21, 12));

EventTheme? _dec(Map<String, Object?> m, {String sender = kAnna}) => EventThemeCodec.decode(m, sender: sender);

void main() {
  group('EventTheme', () {
    test('Grenzen und Konstanten (E-99)', () {
      expect(
        (EventTheme.maxName, EventTheme.maxActive, EventTheme.maxTotal, EventTheme.keepTombstones),
        (30, 12, 40, 10),
      );
      expect((EventTheme.maxVersion, EventTheme.maxFirstVersion, EventTheme.maxVersionJump), (1000000, 10000, 1000));
      expect(EventTheme.privateColorIndex, 3);
    });

    test('Himmelblau (Index 3) ist als Themenfarbe ungültig, die übrigen sieben Farben sind erlaubt', () {
      expect(_theme(color: 3).validate(), contains('color'));
      for (final i in <int>[0, 1, 2, 4, 5, 6, 7]) {
        expect(_theme(color: i).validate(), isEmpty, reason: 'Farbe $i');
      }
      expect(EventTheme.selectableColors, <int>[0, 1, 2, 4, 5, 6, 7]);
      expect(_theme(color: -1).validate(), contains('color'));
      expect(_theme(color: CalendarEvent.colorCount).validate(), contains('color'));
    });

    test('Name: Steuer- und Bidi-Zeichen, leer, Länge in Codepunkten', () {
      expect(_theme(name: 'A\u0007B').validate(), contains('name'));
      expect(_theme(name: 'A\u202EB').validate(), contains('name'));
      expect(_theme(name: '').validate(), contains('name'));
      expect(_theme(name: '   ').validate(), contains('name'));
      expect(_theme(name: '‌‍').validate(), contains('name'), reason: 'nur Verbinder ist unsichtbar');
      // 30 Codepunkte (jeder ein Emoji mit zwei UTF-16-Einheiten) sind erlaubt, 31 nicht.
      expect(_theme(name: '😀' * 30).validate(), isEmpty);
      expect(_theme(name: '😀' * 31).validate(), contains('name'));
      expect(_theme(name: 'a' * 30).validate(), isEmpty);
      expect(_theme(name: 'a' * 31).validate(), contains('name'));
      // ZWJ/ZWNJ sind wie bei Aufgabenlisten (#161) im Namen erlaubt.
      expect(_theme(name: '👨‍👩‍👧').validate(), isEmpty);
    });

    test('Löschmarke: leerer Name, sonst ungültig', () {
      expect(_theme(name: '', deleted: true, version: 2).validate(), isEmpty);
      expect(_theme(name: 'Schule', deleted: true, version: 2).validate(), contains('tombstone'));
    });

    test('Version, Zeit, ID und Absender', () {
      expect(_theme(version: 0).validate(), contains('version'));
      expect(_theme(version: EventTheme.maxVersion + 1).validate(), contains('version'));
      expect(_theme(id: 'x').validate(), contains('id'));
      expect(_theme(by: 'anna').validate(), contains('by'));
      expect(_theme(at: DateTime(2026)).validate(), contains('time'));
    });

    test('Konfliktregel: Version, dann Zeit, dann Absender-ID', () {
      final base = _theme();
      expect(EventThemeMerge.incomingWins(null, base), isTrue);
      expect(EventThemeMerge.incomingWins(base, _theme(version: 2)), isTrue);
      expect(EventThemeMerge.incomingWins(_theme(version: 2), base), isFalse);
      final later = _theme(at: DateTime.utc(2026, 10, 21, 13));
      expect(EventThemeMerge.incomingWins(base, later), isTrue);
      expect(EventThemeMerge.incomingWins(later, base), isFalse);
      expect(EventThemeMerge.incomingWins(base, _theme(by: kBen)), isTrue);
      expect(EventThemeMerge.incomingWins(_theme(by: kBen), base), isFalse);
      expect(EventThemeMerge.incomingWins(base, base), isFalse, reason: 'gleiche Fassung');
    });
  });

  group('EventThemeCodec', () {
    test('Ereignistyp und Rundlauf', () {
      expect(EventThemeCodec.type, 'de.inneso.familynexus.eventtheme');
      final t = _theme(name: 'Sport', color: 5, version: 3);
      final m = EventThemeCodec.encode(t);
      expect(m['v'], 1);
      expect(_dec(m), t);
      final dead = _theme(name: '', deleted: true, version: 4);
      expect(_dec(EventThemeCodec.encode(dead)), dead);
    });

    test('Kodieren ungültiger Themen wirft', () {
      expect(() => EventThemeCodec.encode(_theme(color: 3)), throwsStateError);
      expect(() => EventThemeCodec.encode(_theme(name: '')), throwsStateError);
    });

    test('by muss dem Absender entsprechen', () {
      final m = EventThemeCodec.encode(_theme());
      expect(_dec(m, sender: kBen), isNull, reason: 'kein Schreiben in fremdem Namen');
      expect(_dec(m, sender: 'ben'), isNull);
    });

    test('Himmelblau wird beim Empfang abgelehnt', () {
      final m = EventThemeCodec.encode(_theme())..['color'] = 3;
      expect(_dec(m), isNull);
    });

    test('strikte Felder: Typen, Schema, fehlende Schlüssel, Längen', () {
      Map<String, Object?> good() => EventThemeCodec.encode(_theme());
      expect(_dec(good()), isNotNull);
      for (final key in <String>['id', 'by', 'version', 'deleted', 'name', 'color', 'ts']) {
        expect(_dec(good()..remove(key)), isNull, reason: 'fehlt: $key');
        expect(_dec(good()..[key] = <Object?>[1]), isNull, reason: 'falscher Typ: $key');
      }
      expect(_dec(good()..['v'] = 2), isNull);
      expect(_dec(good()..['v'] = '1'), isNull);
      expect(_dec(good()..['version'] = 1.5), isNull);
      expect(_dec(good()..['ts'] = 0), isNull, reason: 'außerhalb des Zeitbereichs');
      expect(_dec(good()..['name'] = 'x' * 61), isNull);
      expect(_dec(good()..['name'] = 'A\u0007'), isNull);
    });

    test('Zufallsmüll stürzt nie ab', () {
      for (final m in <Map<String, Object?>>[
        <String, Object?>{},
        <String, Object?>{'v': 1},
        <String, Object?>{'v': 1, 'id': 1, 'by': 2},
        <String, Object?>{'x': 'y'},
      ]) {
        expect(_dec(m), isNull);
      }
    });
  });
}
