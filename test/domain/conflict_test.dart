import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/conflict.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);

  final t0 = DateTime.utc(2026, 3, 1, 10);

  test('neuer Termin wird eingefügt', () {
    expect(ConflictResolver.resolve(null, ev()), Resolution.insert);
  });

  test('höhere Version gewinnt, niedrigere ist veraltet', () {
    final v1 = ev(version: 1, title: 'A');
    final v2 = ev(version: 2, title: 'B');
    expect(ConflictResolver.resolve(v1, v2), Resolution.replace);
    expect(ConflictResolver.resolve(v2, v1), Resolution.ignoreStale);
  });

  test('gleiche Version, später aktualisiert gewinnt', () {
    final a = ev(version: 2, title: 'A', updatedAt: t0);
    final b = ev(version: 2, title: 'B', updatedAt: t0.add(const Duration(seconds: 5)));
    expect(ConflictResolver.resolve(a, b), Resolution.replace);
    expect(ConflictResolver.resolve(b, a), Resolution.ignoreStale);
  });

  test('völliger Gleichstand: deterministisch über kanonische Darstellung', () {
    final a = ev(version: 2, title: 'A', updatedAt: t0);
    final b = ev(version: 2, title: 'B', updatedAt: t0);
    final ab = ConflictResolver.resolve(a, b);
    final ba = ConflictResolver.resolve(b, a);
    expect(<Resolution>{ab, ba}, <Resolution>{Resolution.replace, Resolution.ignoreStale}, reason: 'genau einer gewinnt');
  });

  test('identische Fassung (Resync) ist ein Duplikat', () {
    expect(ConflictResolver.resolve(ev(), ev()), Resolution.ignoreDuplicate);
  });

  test('fremder Absender kann einen Termin nicht übernehmen oder ändern', () {
    final mine = ev(version: 1);
    final forged = ev(version: 99, owner: kOther, title: 'Gefälscht');
    expect(ConflictResolver.resolve(mine, forged), Resolution.rejectOwner);
  });

  test('Konvergenz: beliebige Reihenfolge ergibt dasselbe Endergebnis', () {
    final versions = <CalendarEvent>[
      ev(version: 1, title: 'a', updatedAt: t0),
      ev(version: 2, title: 'b', updatedAt: t0.add(const Duration(minutes: 1))),
      ev(version: 2, title: 'c', updatedAt: t0.add(const Duration(minutes: 2))),
      ev(version: 3, title: 'd', updatedAt: t0),
      ev(version: 3, title: 'e', updatedAt: t0),
    ];
    String finalTitle(List<CalendarEvent> order) {
      CalendarEvent? cur;
      for (final e in order) {
        final r = ConflictResolver.resolve(cur, e);
        if (r == Resolution.insert || r == Resolution.replace) cur = e;
      }
      return cur!.title;
    }

    final results = <String>{};
    final rnd = <List<int>>[
      <int>[0, 1, 2, 3, 4],
      <int>[4, 3, 2, 1, 0],
      <int>[2, 0, 4, 1, 3],
      <int>[3, 4, 0, 2, 1],
      <int>[1, 3, 0, 4, 2],
    ];
    for (final p in rnd) {
      results.add(finalTitle(<CalendarEvent>[for (final i in p) versions[i]]));
    }
    expect(results, hasLength(1));
  });

  test('Löschmarke (höhere Version) ersetzt, ältere Fassung kann sie nicht „wiederbeleben“', () {
    final live = ev(version: 1);
    final gone = live.tombstone(DateTime.utc(2026, 3, 2));
    expect(ConflictResolver.resolve(live, gone), Resolution.replace);
    expect(ConflictResolver.resolve(gone, live), Resolution.ignoreStale);
  });
}
