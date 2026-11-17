import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_service.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;

import '../support/memory_anniversary_store.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

/// Kalendertag in [zone] zur UTC-Zeit [utc] (wie `CalendarController.today`).
DateTime todayIn(String zone, DateTime utc) {
  final l = tz.TZDateTime.from(utc, TimeZones.tryGet(zone) ?? TimeZones.utc);
  return DateTime.utc(l.year, l.month, l.day);
}

void main() {
  setUpAll(TimeZones.ensureInitialized);

  late MemoryAnniversaryStore store;
  var ids = 0;
  var now = DateTime.utc(2026, 3, 15, 12);

  AnniversaryService service({String me = _anna, String zone = 'UTC', MemoryAnniversaryStore? s}) => AnniversaryService(
        store: s ?? store,
        myUserId: me,
        today: () => todayIn(zone, now),
        clock: () => now,
        idGenerator: () => '00000000-0000-4000-8000-3${(++ids).toString().padLeft(11, '0')}',
      );

  setUp(() {
    store = MemoryAnniversaryStore();
    now = DateTime.utc(2026, 3, 15, 12);
  });

  test('anlegen, ändern, löschen; jedes Mitglied darf ändern und löschen (kein Besitzer)', () async {
    final p = await service().create(name: '  Oma  Erna ', birth: date(3, 15, 1940));
    expect(p.name, 'Oma Erna');
    expect(await store.pending(), [p]);
    final changed = await service(me: _ben).update(p.id, name: 'Oma', birth: date(3, 15, 1940), death: date(1, 5, 2020));
    expect((changed.version, changed.by, changed.death), (2, _ben, date(1, 5, 2020)));
    await service(me: _ben).delete(p.id);
    final gone = (await store.get(p.id))!;
    expect((gone.deleted, gone.name, gone.birth, gone.death, gone.version), (true, '', null, null, 3));
    await expectLater(service().update(p.id, name: 'x', birth: date(1, 1)), throwsA(isA<AnniversaryException>().having((e) => e.error, 'error', AnniversaryError.notFound)));
  });

  test('ungültige Eingaben: leerer Name, kein Datum, 31.02., Todesdatum vor Geburtsdatum', () async {
    final s = service();
    for (final f in <Future<Object?> Function()>[
      () => s.create(name: '  ', birth: date(1, 1)),
      () => s.create(name: 'Oma'),
      () => s.create(name: 'Oma', birth: date(2, 31)),
      () => s.create(name: 'Oma', birth: date(3, 1, 1940), death: date(2, 1, 1940)),
    ]) {
      await expectLater(f(), throwsA(isA<AnniversaryException>().having((e) => e.error, 'error', AnniversaryError.invalid)));
    }
    expect(await store.all(), isEmpty);
  });

  group('Zukunftsregel', () {
    test('Anlegen mit Datum in der Zukunft wird abgelehnt (invalid); heute und gestern sind erlaubt', () async {
      final s = service();
      await expectLater(s.create(name: 'Baby', birth: date(3, 16, 2026)), throwsA(isA<AnniversaryException>()));
      await expectLater(s.create(name: 'Baby', birth: date(1, 1, 2027)), throwsA(isA<AnniversaryException>()));
      await s.create(name: 'Baby', birth: date(3, 15, 2026));
      await s.create(name: 'Baby2', birth: date(3, 14, 2026));
      await s.create(name: 'Ohne Jahr', birth: date(12, 31));
    });

    test('empfangenes Jahr 2100 wird angenommen; Namensänderung bleibt möglich, Jahr auf Zukunft nicht', () async {
      final incoming = AnniversaryPerson(id: '00000000-0000-4000-8000-0000000000a1', name: 'Zukunft', birth: date(3, 15, 2100), by: _ben, updatedAt: now);
      expect(await service().applyIncoming(incoming), isTrue);
      final renamed = await service().update(incoming.id, name: 'Umbenannt', birth: date(3, 15, 2100));
      expect(renamed.name, 'Umbenannt', reason: 'unverändertes Feld wird nicht geprüft');
      await expectLater(service().update(incoming.id, name: 'x', birth: date(4, 1, 2090)), throwsA(isA<AnniversaryException>()));
    });

    test('Todesdatum: empfangenes Zukunftsjahr bleibt bei Namensänderung, Änderung auf die Zukunft wird abgelehnt', () async {
      final incoming = AnniversaryPerson(
          id: '00000000-0000-4000-8000-0000000000a2', name: 'Spät', birth: date(3, 15, 1990), death: date(3, 15, 2100), by: _ben, updatedAt: now);
      expect(await service().applyIncoming(incoming), isTrue);
      final renamed = await service().update(incoming.id, name: 'Umbenannt', birth: date(3, 15, 1990), death: date(3, 15, 2100));
      expect(renamed.name, 'Umbenannt', reason: 'unverändertes Todesdatum wird nicht geprüft');
      await expectLater(
        service().update(incoming.id, name: 'x', birth: date(3, 15, 1990), death: date(4, 1, 2090)),
        throwsA(isA<AnniversaryException>().having((e) => e.error, 'error', AnniversaryError.invalid)),
      );
    });
  });

  group('Namen', () {
    // Wie bei Themen (E-99) wird Leerraum vor der Prüfung zu einem Leerzeichen zusammengefasst (Tabulator und
    // Zeilenumbruch werden zu ' '); Steuer- und Bidi-Zeichen sperrt die gemeinsame Textprüfung (`hasBadTitleText`).
    test('Tabulator und Zeilenumbruch werden zu einem Leerzeichen normalisiert', () async {
      final s = service();
      expect((await s.create(name: 'Oma\tX', birth: date(3, 1, 1950))).name, 'Oma X');
      expect((await s.create(name: 'Opa\n\nY', birth: date(3, 2, 1950))).name, 'Opa Y');
    });

    test('Steuer-, Bidi- und Zero-Width-Zeichen sowie nur Leerraum werden abgelehnt', () async {
      final s = service();
      for (final bad in <String>['Oma\u202EX', 'Oma\u0000', 'Oma\u200BX', '   ']) {
        await expectLater(
          s.create(name: bad, birth: date(3, 1, 1950)),
          throwsA(isA<AnniversaryException>().having((e) => e.error, 'error', AnniversaryError.invalid)),
          reason: 'Name ${bad.codeUnits}',
        );
      }
      expect(await store.all(), isEmpty);
    });

    test('genau 60 Zeichen sind erlaubt, 61 nicht; Emoji zählt als ein Codepunkt', () async {
      final s = service();
      await s.create(name: 'x' * 60, birth: date(3, 1, 1950));
      await expectLater(s.create(name: 'x' * 61, birth: date(3, 1, 1950)), throwsA(isA<AnniversaryException>()));
      await s.create(name: '${'x' * 59}\u{1F382}', birth: date(3, 2, 1950));
    });
  });

  group('Zeitzone (today aus dem Controller-Weg)', () {
    final utc = DateTime.utc(2026, 3, 15, 23, 30);
    test('Auckland: heute 16.03.2026; Geburt 16.03. angenommen, 17.03. abgelehnt', () async {
      now = utc;
      final s = service(zone: 'Pacific/Auckland');
      await s.create(name: 'A', birth: date(3, 16, 2026));
      await expectLater(s.create(name: 'B', birth: date(3, 17, 2026)), throwsA(isA<AnniversaryException>()));
    });
    test('Los Angeles: heute 15.03.; umgekehrt: 16.03. abgelehnt, 15.03. angenommen', () async {
      now = utc;
      final s = service(zone: 'America/Los_Angeles');
      await expectLater(s.create(name: 'B', birth: date(3, 16, 2026)), throwsA(isA<AnniversaryException>()));
      await s.create(name: 'A', birth: date(3, 15, 2026));
    });
  });

  group('Grenzen', () {
    AnniversaryPerson incoming(int i, {int version = 1, bool deleted = false, DateTime? at, String by = _ben}) => AnniversaryPerson(
          id: '00000000-0000-4000-8000-4${i.toString().padLeft(11, '0')}',
          name: deleted ? '' : 'P$i',
          birth: deleted ? null : date(3, 15, 1940),
          deleted: deleted,
          version: version,
          by: by,
          updatedAt: at ?? now,
        );

    test('200 aktive: der 201. wird abgelehnt (limit), empfangen verworfen', () async {
      final s = service();
      for (var i = 0; i < AnniversaryPerson.maxActive; i++) {
        await store.put(incoming(i));
      }
      await expectLater(s.create(name: 'Zu viel', birth: date(1, 1)), throwsA(isA<AnniversaryException>().having((e) => e.error, 'error', AnniversaryError.limit)));
      expect(await s.applyIncoming(incoming(999)), isFalse);
      expect(await s.applyIncoming(incoming(999, deleted: true)), isTrue, reason: 'eine Löschmarke zählt nur gegen die Gesamtgrenze');
    });

    test('300 gesamt: veröffentlichte Löschmarken werden bereinigt, bis auf 20', () async {
      final s = service();
      for (var i = 0; i < 100; i++) {
        await store.put(incoming(i), publishedVersion: 1);
      }
      for (var i = 100; i < 300; i++) {
        await store.put(incoming(i, deleted: true), publishedVersion: 1);
      }
      expect((await store.counts()).total, 300);
      await s.create(name: 'Neu', birth: date(1, 1));
      final c = await store.counts();
      expect(c.total, 100 + AnniversaryPerson.keepTombstones + 1);
    });

    test('Versionssprung und erste Version', () async {
      final s = service();
      expect(await s.applyIncoming(incoming(1, version: AnniversaryPerson.maxFirstVersion + 1)), isFalse);
      expect(await s.applyIncoming(incoming(1, version: AnniversaryPerson.maxFirstVersion)), isTrue);
      expect(await s.applyIncoming(incoming(1, version: AnniversaryPerson.maxFirstVersion + AnniversaryPerson.maxVersionJump + 1)), isFalse);
      expect(await s.applyIncoming(incoming(1, version: AnniversaryPerson.maxFirstVersion + AnniversaryPerson.maxVersionJump)), isTrue);
    });
  });

  group('Konfliktlösung', () {
    AnniversaryPerson v(int version, DateTime at, String by, String name) =>
        AnniversaryPerson(id: '00000000-0000-4000-8000-0000000000b1', name: name, birth: date(3, 15, 1940), version: version, by: by, updatedAt: at);
    final t0 = DateTime.utc(2026, 3, 1);

    test('höhere Version, dann Zeit, dann Absender-ID, dann Inhalt', () {
      expect(AnniversaryMerge.incomingWins(null, v(1, t0, _anna, 'A')), isTrue);
      expect(AnniversaryMerge.incomingWins(v(2, t0, _anna, 'A'), v(1, t0.add(const Duration(days: 1)), _ben, 'B')), isFalse);
      expect(AnniversaryMerge.incomingWins(v(1, t0, _anna, 'A'), v(2, t0, _anna, 'B')), isTrue);
      expect(AnniversaryMerge.incomingWins(v(1, t0, _anna, 'A'), v(1, t0.add(const Duration(seconds: 1)), _anna, 'B')), isTrue);
      expect(AnniversaryMerge.incomingWins(v(1, t0, _anna, 'A'), v(1, t0, _ben, 'B')), isTrue, reason: 'Gleichstand: größere Absender-ID');
      expect(AnniversaryMerge.incomingWins(v(1, t0, _ben, 'A'), v(1, t0, _anna, 'B')), isFalse);
      expect(AnniversaryMerge.incomingWins(v(1, t0, _anna, 'A'), v(1, t0, _anna, 'B')), isTrue, reason: 'selbe ID: Inhalt entscheidet deterministisch');
      expect(AnniversaryMerge.incomingWins(v(1, t0, _anna, 'B'), v(1, t0, _anna, 'A')), isFalse);
    });

    test('Empfang konvergiert unabhängig von der Reihenfolge', () async {
      final a = MemoryAnniversaryStore();
      final b = MemoryAnniversaryStore();
      final x = v(2, t0, _anna, 'X');
      final y = v(2, t0, _ben, 'Y');
      final sa = service(s: a);
      final sb = service(s: b);
      await sa.applyIncoming(x);
      await sa.applyIncoming(y);
      await sb.applyIncoming(y);
      await sb.applyIncoming(x);
      expect(await a.get(x.id), await b.get(x.id));
    });
  });

  test('Löschmarken-Bereinigung entfernt nur veröffentlichte', () async {
    final s = service();
    final p = await s.create(name: 'Oma', birth: date(1, 1));
    await s.delete(p.id);
    await store.pruneTombstones(keep: 0);
    expect(await store.get(p.id), isNotNull, reason: 'noch nicht veröffentlicht');
    await store.markPublished(p.id, 2);
    await store.pruneTombstones(keep: 0);
    expect(await store.get(p.id), isNull);
  });
}
