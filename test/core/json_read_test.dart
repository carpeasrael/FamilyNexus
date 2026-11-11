import 'package:family_nexus/core/json_read.dart';
import 'package:flutter_test/flutter_test.dart';

/// AP-6b: `JsonRead` liest typsicher; ein falscher Typ oder ein fehlender Wert ergibt `null`, nie eine Ausnahme.
void main() {
  group('Einzelwerte', () {
    test('string', () {
      expect(JsonRead.string('a'), 'a');
      expect(JsonRead.string(''), '');
      expect(<Object?>[1, 1.5, true, null, <Object?>[], <String, Object?>{}].map(JsonRead.string), everyElement(isNull));
    });

    test('integer: nur echte ganze Zahlen', () {
      expect(JsonRead.integer(3), 3);
      expect(JsonRead.integer(-1), -1);
      expect(<Object?>['3', 3.0, 3.5, true, null, <Object?>[]].map(JsonRead.integer), everyElement(isNull));
    });

    test('boolean', () {
      expect(JsonRead.boolean(true), isTrue);
      expect(JsonRead.boolean(false), isFalse);
      expect(<Object?>['true', 1, null].map(JsonRead.boolean), everyElement(isNull));
    });

    test('map und list', () {
      expect(JsonRead.map(<String, Object?>{'a': 1}), <String, Object?>{'a': 1});
      expect(JsonRead.map(<Object?, Object?>{1: 'x'}), <Object?, Object?>{1: 'x'});
      expect(<Object?>['x', 1, null, <Object?>[]].map(JsonRead.map), everyElement(isNull));
      expect(JsonRead.list(<Object?>[1, 'a']), <Object?>[1, 'a']);
      expect(JsonRead.list(<String>['a']), <Object?>['a'], reason: 'Liste mit engerem Elementtyp bleibt lesbar');
      expect(<Object?>['x', 1, null, <String, Object?>{}].map(JsonRead.list), everyElement(isNull));
    });
  });

  group('Zugriff in Verschachtelung', () {
    const doc = <String, Object?>{
      'rooms': <String, Object?>{
        'leave': <String, Object?>{
          '!r:hs': <String, Object?>{
            'state': <String, Object?>{
              'events': <Object?>[1, 2],
            },
          },
        },
      },
    };

    test('at: kein Objekt oder fehlender Schlüssel ergibt null', () {
      expect(JsonRead.at(doc, 'rooms'), isA<Map<Object?, Object?>>());
      expect(JsonRead.at(doc, 'nope'), isNull);
      expect(JsonRead.at('text', 'rooms'), isNull);
      expect(JsonRead.at(null, 'rooms'), isNull);
      expect(JsonRead.at(<Object?>[1], 0), isNull, reason: 'Listen sind keine Objekte');
    });

    test('path: folgt dem Pfad und bricht beim ersten Nicht-Objekt ab', () {
      expect(JsonRead.list(JsonRead.path(doc, <Object?>['rooms', 'leave', '!r:hs', 'state', 'events'])), <Object?>[1, 2]);
      expect(JsonRead.path(doc, <Object?>['rooms', 'join', '!r:hs']), isNull);
      expect(JsonRead.path(doc, <Object?>['rooms', 'leave', '!r:hs', 'state', 'events', 'x']), isNull);
      expect(JsonRead.path('kaputt', <Object?>['rooms']), isNull);
      expect(JsonRead.path(doc, const <Object?>[]), same(doc));
    });
  });
}
