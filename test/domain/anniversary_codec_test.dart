import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_codec.dart';
import 'package:flutter_test/flutter_test.dart';

const String _anna = '@anna:fake.test';
const String _id = '00000000-0000-4000-8000-000000000001';

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

AnniversaryPerson person({String name = 'Oma', AnniversaryDate? birth, AnniversaryDate? death, bool deleted = false, int version = 1}) => AnniversaryPerson(
      id: _id,
      name: name,
      birth: birth,
      death: death,
      deleted: deleted,
      version: version,
      by: _anna,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );

AnniversaryPerson? decodeWith(void Function(Map<String, Object?>) change, {AnniversaryPerson? base, String sender = _anna}) {
  final m = AnniversaryCodec.encode(base ?? person(birth: date(3, 15, 1940)));
  change(m);
  return AnniversaryCodec.decode(m, sender: sender);
}

void main() {
  group('Roundtrip', () {
    for (final (label, p) in <(String, AnniversaryPerson)>[
      ('Geburt mit Jahr', person(birth: date(3, 15, 1940))),
      ('Geburt ohne Jahr', person(birth: date(3, 15))),
      ('nur Tod', person(death: date(1, 5, 2020))),
      ('beide', person(birth: date(3, 15, 1940), death: date(1, 5, 2020))),
      ('Löschmarke', person(name: '', deleted: true, version: 2)),
    ]) {
      test(label, () => expect(AnniversaryCodec.decode(AnniversaryCodec.encode(p), sender: _anna), p));
    }
    test('Format: Schlüssel v, id, by, version, deleted, name, birth {m,d,y}, ts; kein Schlüssel für fehlendes Jahr', () {
      final m = AnniversaryCodec.encode(person(birth: date(3, 15)));
      expect(m['birth'], <String, Object?>{'m': 3, 'd': 15});
      expect(m.containsKey('death'), isFalse);
      expect(m['v'], 1);
    });
  });

  group('Ablehnung', () {
    test('by ≠ Absender', () => expect(decodeWith((_) {}, sender: '@ben:fake.test'), isNull));
    test('falscher Typ', () {
      expect(decodeWith((m) => m['version'] = '1'), isNull);
      expect(decodeWith((m) => m['name'] = 5), isNull);
      expect(decodeWith((m) => m['deleted'] = 'nein'), isNull);
      expect(decodeWith((m) => m['birth'] = 'x'), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': '3', 'd': 15}), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15, 'y': '1940'}), isNull);
      expect(decodeWith((m) => m['v'] = 2), isNull);
    });
    test('31.02. und Monat 13', () {
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 2, 'd': 31}), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 13, 'd': 1}), isNull);
    });
    test('Name leer, zu lang, Steuerzeichen', () {
      expect(decodeWith((m) => m['name'] = ''), isNull);
      expect(decodeWith((m) => m['name'] = 'x' * 61), isNull);
      expect(decodeWith((m) => m['name'] = 'Oma\u0000'), isNull);
    });
    test('Jahr 999 und 2101; 1000 und 2100 gültig', () {
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15, 'y': 999}), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15, 'y': 2101}), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15, 'y': 1000}), isNotNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15, 'y': 2100}), isNotNull, reason: 'empfangenes Jahr 2100 gültig');
    });
    test('Todesjahr < Geburtsjahr; gleiches Jahr mit früherem Todesdatum', () {
      Map<String, Object?> d(int m, int day, int y) => <String, Object?>{'m': m, 'd': day, 'y': y};
      expect(decodeWith((m) => m['death'] = d(1, 1, 1939)), isNull);
      expect(decodeWith((m) => m['death'] = d(1, 1, 1940)), isNull);
      expect(decodeWith((m) => m['death'] = d(3, 15, 1940)), isNotNull);
      expect(decodeWith((m) => m['death'] = d(1, 1, 1941)), isNotNull);
    });
    test('weder Geburt noch Tod; Löschmarke mit Namen', () {
      expect(decodeWith((m) => m.remove('birth')), isNull);
      expect(decodeWith((m) => m['name'] = 'Oma', base: person(name: '', deleted: true, version: 2)), isNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 3, 'd': 15}, base: person(name: '', deleted: true, version: 2)), isNull);
    });
    test('29.02.: 1900 und 2100 ungültig, 2000 und ohne Jahr gültig', () {
      for (final y in <int>[1900, 2100]) {
        expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 2, 'd': 29, 'y': y}), isNull, reason: '29.02.$y');
      }
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 2, 'd': 29, 'y': 2000}), isNotNull);
      expect(decodeWith((m) => m['birth'] = <String, Object?>{'m': 2, 'd': 29}), isNotNull);
    });
    test('encode weigt ungültige Einträge ab', () {
      expect(() => AnniversaryCodec.encode(person()), throwsStateError, reason: 'ohne Datum');
    });
  });
}
