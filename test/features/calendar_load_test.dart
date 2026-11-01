import 'dart:async';

import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_event_store.dart';

/// Store, der Abfragen zählt, das Ergebnis erst nach einem Tor liefert und Fehler einspielen kann.
class _CountingStore extends MemoryEventStore {
  int allCalls = 0;
  Completer<void>? gate;
  Object? failNext;

  @override
  Future<List<CalendarEvent>> all() async {
    allCalls++;
    final snapshot = await super.all();
    final g = gate;
    if (g != null) await g.future;
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
    return snapshot;
  }
}

/// #131: `load()` läuft nie parallel; Aufrufe während eines Ladens ergeben genau einen Nachlauf.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late _CountingStore store;
  late CalendarController c;

  setUp(() {
    store = _CountingStore();
    c = buildCalendarController(
      store: store,
      gateway: FakeMatrixServer().newDevice(),
      userId: '@anna:fake.test',
      zoneName: 'Europe/Berlin',
      retryInterval: const Duration(hours: 1),
    );
  });

  Future<CalendarEvent> add(String title) => c.service.create(
        title: title,
        start: DateTime.utc(2026, 11, 2, 9),
        end: DateTime.utc(2026, 11, 2, 10),
        timeZone: 'Europe/Berlin',
        visibility: EventVisibility.private,
      );

  test('50 gleichzeitige load()-Aufrufe ergeben höchstens zwei Durchläufe; der Endzustand ist aktuell', () async {
    await add('A');
    store.allCalls = 0;
    final futures = <Future<void>>[for (var i = 0; i < 50; i++) c.load()];
    await Future.wait(futures);
    expect(store.allCalls, lessThanOrEqualTo(2));
    expect(c.events.map((e) => e.title), <String>['A']);
  });

  test('ein während des Ladens hinzugekommenes Ereignis wird vom Nachlauf erfasst', () async {
    store.gate = Completer<void>();
    final first = c.load();
    await pumpEventQueue();
    expect(store.allCalls, 1);
    await add('Neu'); // nach der ersten Abfrage, vor deren Abschluss
    final second = c.load(); // vorgemerkt: genau ein Nachlauf
    final gate = store.gate!;
    store.gate = null;
    gate.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(store.allCalls, 2);
    expect(c.events.map((e) => e.title), <String>['Neu']);
  });

  test('ein Fehler im Laden blockiert den nächsten Aufruf nicht', () async {
    await add('A');
    store.failNext = StateError('Datenbank');
    await expectLater(c.load(), throwsStateError);
    await c.load();
    expect(c.events.map((e) => e.title), <String>['A']);
  });

  test('nach dispose gibt es keine Benachrichtigung und keinen Nachlauf mehr', () async {
    store.gate = Completer<void>();
    final running = c.load();
    await pumpEventQueue();
    c.load().ignore(); // Nachlauf vorgemerkt
    c.dispose();
    store.gate!.complete();
    store.gate = null;
    await running; // wirft nicht („used after dispose“)
    expect(store.allCalls, 1, reason: 'kein Nachlauf nach dispose');
  });
}
