import 'dart:async';
import 'dart:convert';

import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/key_value_store.dart';
import 'package:family_nexus/domain/reminder_planner.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:family_nexus/features/reminders/reminder_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_scheduler.dart';
import '../support/memory_stores.dart';
import '../support/test_app.dart';

/// Ablage mit steuerbarem Laden: [readAll] wartet auf [release].
class _SlowStore extends MemoryKeyValueStore {
  final Completer<void> release = Completer<void>();

  @override
  Future<Map<String, String>> readAll() async {
    await release.future;
    return super.readAll();
  }
}

/// #218: Bestätigen fälliger Erinnerungen im Coordinator (E-87).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late DateTime now;
  late TestApp app;
  late CalendarController cal;
  late FakeReminderScheduler sched;
  final coords = <ReminderCoordinator>[];

  setUp(() async {
    now = DateTime.utc(2026, 3, 20, 10);
    app = await buildTestApp(clock: () => now);
    cal = await app.services.calendarBuilder!('@anna:fake.test', null);
    sched = FakeReminderScheduler();
  });

  tearDown(() {
    for (final c in coords) {
      c.dispose();
    }
    coords.clear();
    cal.dispose();
  });

  ReminderCoordinator coordinator({KeyValueStore? store}) {
    final c = ReminderCoordinator(calendar: cal, scheduler: sched, settings: app.services.settings, store: store, clock: () => now)..start();
    coords.add(c);
    return c;
  }

  Future<CalendarEvent> make(String title, DateTime start) =>
      cal.create(title: title, start: start, end: start.add(const Duration(hours: 1)), visibility: EventVisibility.private);

  Map<String, Object?> stored(MemoryKeyValueStore s) =>
      json.decode(s.data[ReminderCoordinator.acknowledgedKey] ?? '{}') as Map<String, Object?>;

  test('fällig folgt der Uhr; Bestätigen entfernt und ruft dismiss', () async {
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 15));
    final c = coordinator();
    expect(c.dueCount, 0);
    now = DateTime.utc(2026, 3, 20, 10, 6);
    final due = c.due();
    expect(due.single.occurrence.event.title, 'Arzt');
    await c.acknowledge(due);
    expect(c.dueCount, 0);
    expect(sched.dismissed, <int>[due.single.reminder.id]);
  });

  test('Bestätigung übersteht einen Neuaufbau mit derselben Ablage', () async {
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 5));
    final store = MemoryKeyValueStore();
    final c1 = coordinator(store: store);
    await c1.acknowledge(c1.due());
    final c2 = coordinator(store: store);
    await Future<void>.delayed(Duration.zero);
    expect(c2.dueCount, 0);
  });

  test('kaputter Wert wird verworfen, ohne Absturz', () async {
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 5));
    final store = MemoryKeyValueStore()..data[ReminderCoordinator.acknowledgedKey] = '{kaputt';
    final c = coordinator(store: store);
    await Future<void>.delayed(Duration.zero);
    expect(c.dueCount, 1);
  });

  test('Abgelaufenes fällt beim Laden und beim Speichern weg', () async {
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 5));
    final store = MemoryKeyValueStore()..data[ReminderCoordinator.acknowledgedKey] = json.encode(<String, int>{'42': now.millisecondsSinceEpoch - 1});
    final c = coordinator(store: store);
    await c.acknowledge(c.due());
    expect(stored(store).keys, isNot(contains('42')));
    expect(stored(store), hasLength(1));
  });

  test('Bestätigen vor dem Ende des Ladens geht nicht verloren und verdrängt nichts', () async {
    final a = await make('A', DateTime.utc(2026, 3, 20, 10, 5));
    await make('B', DateTime.utc(2026, 3, 20, 10, 6));
    final store = _SlowStore();
    final probe = coordinator();
    final idA = probe.due().firstWhere((e) => e.occurrence.event.id == a.id).reminder.id;
    store.data[ReminderCoordinator.acknowledgedKey] = json.encode(<String, int>{'$idA': now.add(const Duration(hours: 1)).millisecondsSinceEpoch});
    final c = coordinator(store: store);
    final b = c.due().firstWhere((e) => e.occurrence.event.title == 'B');
    final done = c.acknowledge(<ReminderEntry>[b]);
    store.release.complete();
    await done;
    expect(c.dueCount, 0, reason: 'A aus der Ablage, B aus dem Speicher');
    expect(stored(store).keys.toSet(), <String>{'$idA', '${b.reminder.id}'});
  });

  test('nach dispose wird nichts mehr geschrieben', () async {
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 5));
    final store = MemoryKeyValueStore();
    final c = coordinator(store: store);
    final due = c.due();
    c.dispose();
    coords.remove(c);
    await c.acknowledge(due);
    expect(store.data.containsKey(ReminderCoordinator.acknowledgedKey), isFalse);
  });

  test('höchstens maxAcknowledged Einträge, die mit dem frühesten Ende fallen zuerst', () async {
    final store = MemoryKeyValueStore()
      ..data[ReminderCoordinator.acknowledgedKey] = json.encode(<String, int>{
        for (var i = 0; i < ReminderCoordinator.maxAcknowledged; i++) '$i': now.millisecondsSinceEpoch + 1000 + i,
      });
    await make('Arzt', DateTime.utc(2026, 3, 20, 10, 5));
    final c = coordinator(store: store);
    await Future<void>.delayed(Duration.zero);
    await c.acknowledge(c.due());
    final keys = stored(store).keys;
    expect(ReminderCoordinator.maxAcknowledged, 500, reason: 'Grenze aus E-87');
    expect(keys, hasLength(ReminderCoordinator.maxAcknowledged));
    expect(keys, isNot(contains('0')));
  });
}
