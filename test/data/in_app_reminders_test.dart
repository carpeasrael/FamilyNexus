import 'package:family_nexus/data/platform/in_app_reminders.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:flutter_test/flutter_test.dart';

/// #152: Linux/Windows halten die Erinnerungen selbst. Eine seit dem letzten Takt fällig gewordene Erinnerung
/// darf bei einer Neuplanung nicht verloren gehen.
void main() {
  final base = DateTime.utc(2026, 3, 20, 10);
  late DateTime now;
  late List<(int, String, String)> shown;
  late InAppReminders r;

  PlannedReminder planned(int id, DateTime fireAt) => PlannedReminder(
        id: id,
        fireAt: fireAt,
        eventId: 'e$id',
        occurrenceStart: fireAt.add(const Duration(minutes: 10)),
        minutesBefore: 10,
      );

  void replace(List<PlannedReminder> l) => r.replace(l, title: 'Erinnerung', bodyFor: (m) => 'in $m');

  setUp(() {
    now = base;
    shown = <(int, String, String)>[];
    r = InAppReminders(show: (id, t, b) async => shown.add((id, t, b)), clock: () => now);
  });

  tearDown(() => r.clear());

  test('kürzlich fällig gewordene Erinnerung erscheint beim Ersetzen, auch wenn die neue Liste sie nicht enthält', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(seconds: 5)))]);
    expect(shown, isEmpty, reason: 'noch nicht fällig');

    now = base.add(const Duration(seconds: 10)); // fällig seit 5 s, letzter Takt davor
    replace(<PlannedReminder>[planned(2, base.add(const Duration(hours: 1)))]);
    await Future<void>.delayed(Duration.zero);

    expect(shown.map((s) => s.$1), <int>[1]);
    expect(shown.single.$3, 'in 10');
  });

  test('noch nicht fällige alte Erinnerung, die in der neuen Liste fehlt, erscheint nicht', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(minutes: 5)))]);
    now = base.add(const Duration(minutes: 1));
    replace(<PlannedReminder>[planned(2, base.add(const Duration(hours: 1)))]);
    await r.fireDue(base.add(const Duration(minutes: 10)));
    expect(shown.map((s) => s.$1), <int>[], reason: 'gelöscht oder verschoben, bevor sie fällig war');
  });

  test('zu alte Erinnerungen (länger als staleAfter) werden verworfen', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(minutes: 1)))]);
    now = base.add(const Duration(hours: 2));
    replace(const <PlannedReminder>[]);
    await Future<void>.delayed(Duration.zero);
    expect(shown, isEmpty);
    expect(r.isEmpty, isTrue);
  });

  test('Gezeigtes erscheint nach dem Ersetzen nicht noch einmal', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(seconds: 5)))]);
    now = base.add(const Duration(seconds: 10));
    replace(<PlannedReminder>[planned(2, base.add(const Duration(hours: 1)))]);
    await Future<void>.delayed(Duration.zero);
    await r.fireDue(now);
    await r.fireDue(now.add(const Duration(minutes: 1)));
    expect(shown.map((s) => s.$1), <int>[1]);
  });

  test('fireDue zeigt fällige einmal und beendet den Takt bei leerer Liste', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(minutes: 1)))]);
    expect(r.tickActive, isTrue);
    await r.fireDue(base.add(const Duration(minutes: 2)));
    expect(shown.map((s) => s.$1), <int>[1]);
    expect(r.tickActive, isFalse);
    await r.fireDue(base.add(const Duration(minutes: 3)));
    expect(shown, hasLength(1));
  });

  test('clear leert die Liste und beendet den Takt', () async {
    replace(<PlannedReminder>[planned(1, base.add(const Duration(minutes: 1)))]);
    r.clear();
    expect(r.isEmpty, isTrue);
    expect(r.tickActive, isFalse);
    await r.fireDue(base.add(const Duration(hours: 1)));
    expect(shown, isEmpty);
  });

  test('eine leere Planung legt keinen Takt an', () {
    replace(const <PlannedReminder>[]);
    expect(r.tickActive, isFalse);
    expect(r.isEmpty, isTrue);
  });

  test('ein fehlschlagendes show verhindert die übrigen Anzeigen nicht', () async {
    final failing = InAppReminders(
      show: (id, t, b) async {
        if (id == 1) throw StateError('Plugin');
        shown.add((id, t, b));
      },
      clock: () => now,
    );
    failing.replace(<PlannedReminder>[planned(1, base), planned(2, base)], title: 't', bodyFor: (m) => 'b');
    now = base.add(const Duration(seconds: 1));
    await failing.fireDue();
    expect(shown.map((s) => s.$1), <int>[2]);
    failing.clear();
  });
}
