import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/conflict.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';

/// #431, E-112: Totalordnung `(deleted, version, ohne editor, updatedAt, canonical)`. Alle Empfangsreihenfolgen enden
/// auf derselben Fassung.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  const mod = '@cara:fake.test';
  const mod2 = '@dora:fake.test';
  final t0 = DateTime.utc(2026, 3, 1, 10);

  CalendarEvent byMod(int v, {String editor = mod, String title = 'M', DateTime? at}) =>
      ev(version: v, title: title, updatedAt: at ?? t0).copyWith(editorId: editor);

  /// Wendet [list] in der gegebenen Reihenfolge an und liefert die Endfassung.
  CalendarEvent run(List<CalendarEvent> list) {
    CalendarEvent? cur;
    for (final e in list) {
      final r = ConflictResolver.resolve(cur, e);
      if (r == Resolution.insert || r == Resolution.replace) cur = e;
    }
    return cur!;
  }

  Iterable<List<T>> perms<T>(List<T> l) sync* {
    if (l.length <= 1) {
      yield l;
      return;
    }
    for (var i = 0; i < l.length; i++) {
      final rest = <T>[...l]..removeAt(i);
      for (final p in perms(rest)) {
        yield <T>[l[i], ...p];
      }
    }
  }

  void converges(List<CalendarEvent> list, {String? title}) {
    final ends = <CalendarEvent>{for (final p in perms(list)) run(p)};
    expect(ends, hasLength(1), reason: 'alle ${list.length}! Reihenfolgen enden gleich');
    if (title != null) expect(ends.single.title, title);
  }

  test('Besitzer schlägt Moderator bei gleicher Version, auch mit späterer updatedAt des Moderators', () {
    final owner = ev(version: 2, title: 'O', updatedAt: t0);
    final m = byMod(2, at: t0.add(const Duration(days: 2)));
    expect(ConflictResolver.resolve(m, owner), Resolution.replace);
    expect(ConflictResolver.resolve(owner, m), Resolution.ignoreStale);
    converges(<CalendarEvent>[owner, m], title: 'O');
  });

  test('höhere Version gewinnt weiterhin, auch die des Moderators', () {
    converges(<CalendarEvent>[ev(version: 2, title: 'O', updatedAt: t0), byMod(3)], title: 'M');
  });

  test('Kette V, V+1 (M1), V+2 (M2): jede Reihenfolge endet auf V+2', () {
    converges(<CalendarEvent>[ev(version: 1, title: 'V'), byMod(2, title: 'M1'), byMod(3, editor: mod2, title: 'M2')],
        title: 'M2');
  });

  test('zwei Moderatoren, gleiche Version: deterministisch über updatedAt, dann kanonisch', () {
    converges(<CalendarEvent>[
      byMod(2, title: 'A', at: t0),
      byMod(2, editor: mod2, title: 'B', at: t0.add(const Duration(seconds: 1))),
    ], title: 'B');
    converges(<CalendarEvent>[byMod(2, title: 'A'), byMod(2, editor: mod2, title: 'B')]);
  });

  test('Löschmarke schlägt jede lebende Fassung, auch mit höherer Version (alle Reihenfolgen)', () {
    final base = ev(version: 1);
    final gone = base.tombstone(DateTime.utc(2026, 3, 2)); // Version 2
    converges(<CalendarEvent>[gone, ev(version: 5, title: 'lebt'), byMod(6)]);
    expect(run(<CalendarEvent>[ev(version: 5), gone, byMod(6)]).deleted, isTrue);
    expect(run(<CalendarEvent>[gone, ev(version: 5)]).deleted, isTrue);
  });

  test('Löschmarke V2 gegen lebende V5 desselben Besitzers: Löschen gewinnt (Verhaltensänderung, E-13 Nachtrag)', () {
    final gone = ev(version: 1).tombstone(DateTime.utc(2026, 3, 2));
    final live = ev(version: 5, title: 'Zweitgerät');
    expect(ConflictResolver.resolve(live, gone), Resolution.replace);
    expect(ConflictResolver.resolve(gone, live), Resolution.ignoreStale);
  });

  test('unterschiedliche Sichtbarkeit: weiter die Version (privat → geteilt zweier Geräte)', () {
    final privGone = ev(version: 1, visibility: EventVisibility.private).tombstone(DateTime.utc(2026, 3, 2)); // V2
    final sharedLive = ev(version: 3, title: 'geteilt');
    expect(ConflictResolver.resolve(privGone, sharedLive), Resolution.replace);
    expect(ConflictResolver.resolve(sharedLive, privGone), Resolution.ignoreStale);
  });

  test('Duplikat: gleiche Fassung inklusive editor', () {
    expect(ConflictResolver.resolve(byMod(2), byMod(2)), Resolution.ignoreDuplicate);
    expect(ConflictResolver.resolve(byMod(2), byMod(2, editor: mod2)), isNot(Resolution.ignoreDuplicate));
  });
}
