import 'dart:async';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_event_store.dart';
import '../support/memory_shopping_store.dart';
import '../support/memory_task_store.dart';
import '../support/test_app.dart';

const String _anna = '@anna:fake.test';

/// Hält die Verarbeitung eines Signals an, bis der Test sie freigibt.
class _Hold {
  Completer<void>? gate;
  final Completer<void> entered = Completer<void>();

  Future<void> pass() async {
    final g = gate;
    if (g == null) return;
    if (!entered.isCompleted) entered.complete();
    await g.future;
  }
}

class _HoldingEvents extends MemoryEventStore {
  final _Hold hold = _Hold();

  @override
  Future<CalendarEvent?> get(String id) async {
    await hold.pass();
    return super.get(id);
  }
}

class _HoldingShopping extends MemoryShoppingStore {
  final _Hold hold = _Hold();

  @override
  Future<ShoppingItem?> get(String id) async {
    await hold.pass();
    return super.get(id);
  }
}

class _HoldingTasks extends MemoryTaskStore {
  final _Hold hold = _Hold();

  @override
  Future<TaskList?> getList(String id) async {
    await hold.pass();
    return super.getList(id);
  }
}

/// #140: `AppServices` öffnet die Dienste für genau eine Familie, beansprucht die lokalen Daten vor dem Aufbau und lässt
/// einen veralteten Öffnungslauf nichts mehr starten. Ein hängender Lauf hält keinen neuen auf (#153).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(TimeZones.ensureInitialized);

  /// Führt die Sendeläufe der offenen Dienste direkt aus, statt die 200 ms der Entprellung abzuwarten, die unter Last
  /// beliebig spät ablaufen. Fake und Speicher-Ablagen warten auf nichts: Ein Lauf endet ohne Zwischenstopp, ein Lauf
  /// aus der Entprellung kann ihn nicht überholen.
  Future<void> publishAll(TestApp app) async {
    await app.services.calendar?.sync.publishPending();
    await app.services.shopping?.sync.publishPending();
    await app.services.tasks?.sync.publishPending();
  }

  late String roomA;
  late String roomB;

  Future<TestApp> make({
    Future<void> Function(String)? beforeCalendarBuild,
    Future<void> Function(String)? beforeShoppingBuild,
    Future<void> Function(String)? beforeTasksBuild,
    Future<void> Function(String)? claim,
    MemoryEventStore? events,
    MemoryShoppingStore? shopping,
    MemoryTaskStore? tasks,
  }) async {
    final app = await buildTestApp(
      beforeCalendarBuild: beforeCalendarBuild,
      beforeShoppingBuild: beforeShoppingBuild,
      beforeTasksBuild: beforeTasksBuild,
      familyDataClaim: claim,
      eventStore: events,
      shoppingItems: shopping,
      taskItems: tasks,
    );
    roomA = app.gateway.familyRoom!.id;
    roomB = app.server.addFamilyRoom('Familie B', _anna).id;
    addTearDown(app.services.closeCalendar);
    return app;
  }

  Future<void> seed(TestApp app) async {
    await CalendarService(store: app.events, myUserId: _anna).create(
      title: 'Aus A',
      start: DateTime.utc(2026, 11, 2, 9),
      end: DateTime.utc(2026, 11, 2, 10),
      timeZone: 'Europe/Berlin',
      visibility: EventVisibility.shared,
    );
    await ShoppingService(store: app.shoppingStore, myUserId: _anna).add('Aus A');
    await TaskService(store: app.taskStore, myUserId: _anna, isModerator: (id) => id == _anna).createList(
      title: 'Aus A',
      assignee: _anna,
      interval: TaskInterval.daily,
      timeZone: 'Europe/Berlin',
      items: <String>['Eins'],
    );
  }

  void expectDisposed(ChangeNotifier n) => expect(() => ChangeNotifier.debugAssertNotDisposed(n), throwsFlutterError);

  group('Familie der offenen Dienste', () {
    test('gleicher Nutzer, gleiche Familie: kein Neuaufbau', () async {
      final app = await make();
      await app.services.openCalendar();
      final c = app.services.calendar;
      await app.services.openCalendar();
      expect(app.services.calendar, same(c));
      expect(app.calendarRooms, <String>[roomA]);
      expect(app.services.openFamilyRoom, roomA);
    });

    test('gleicher Nutzer, andere Familie: baut neu auf und übergibt den neuen Raum', () async {
      final app = await make();
      await app.services.openCalendar();
      final c = app.services.calendar;
      app.gateway.attachFamilyRoom(roomB);
      await app.services.openCalendar();
      expect(app.services.calendar, isNot(same(c)));
      expect(app.calendarRooms, <String>[roomA, roomB]);
      expect(app.shoppingRooms, <String>[roomA, roomB]);
      expect(app.taskRooms, <String>[roomA, roomB]);
      expect(app.services.openFamilyRoom, roomB);
      expect(app.services.calendar!.sync.sameFamily, isTrue);
    });

    test('closeCalendar setzt den Raum zurück', () async {
      final app = await make();
      await app.services.openCalendar();
      app.services.closeCalendar();
      expect(app.services.openFamilyRoom, isNull);
    });

    test('der vor dem ersten await gemerkte Raum gilt, auch wenn die Familie währenddessen springt', () async {
      late TestApp app;
      app = await make(beforeCalendarBuild: (_) async => app.gateway.attachFamilyRoom(roomB));
      final open = app.services.openCalendar();
      expect(app.services.openFamilyRoom, roomA, reason: 'schon während des Öffnens');
      await open;
      expect(app.calendarRooms, <String>[roomA]);
      expect(app.shoppingRooms, <String>[roomA]);
      expect(app.taskRooms, <String>[roomA]);
      expect(app.services.openFamilyRoom, roomA);
      expect(app.services.calendar!.sync.sameFamily, isFalse, reason: 'Bindung und Ablage bleiben bei A');
    });

    test('Sprung während des Anspruchs: Builder und Bindung bekommen den Raum vom Beginn des Öffnens', () async {
      late TestApp app;
      app = await make(claim: (_) async => app.gateway.attachFamilyRoom(roomB));
      await app.services.openCalendar();
      expect(app.calendarRooms, <String>[roomA]);
      expect(app.shoppingRooms, <String>[roomA]);
      expect(app.taskRooms, <String>[roomA]);
      expect(app.services.openFamilyRoom, roomA);
      expect(app.services.calendar!.sync.sameFamily, isFalse);
    });

    test('nach dem Wechsel meldet „Im Chat teilen“ einen Fehler und sendet nichts', () async {
      final app = await make();
      await app.services.openCalendar();
      final cal = app.services.calendar!;
      final e = await cal.create(
        title: 'Pizzaabend',
        start: DateTime.utc(2026, 11, 2, 17),
        end: DateTime.utc(2026, 11, 2, 19),
        visibility: EventVisibility.shared,
      );
      app.gateway.attachFamilyRoom(roomB);
      await expectLater(cal.shareInChat(e), throwsA(isA<GatewayException>().having((x) => x.error, 'error', GatewayError.serverUnreachable)));
      expect(app.server.rooms[roomB]!.events, isEmpty);
      expect(app.server.rooms[roomA]!.events.where((x) => x.type == 'm.room.message'), isEmpty);
    });
  });

  group('Wechsel während des Öffnens', () {
    for (final phase in <String>['Kalender', 'Einkauf', 'Aufgaben']) {
      test('$phase: nichts aus A geht nach B, der Neuaufbau bringt jeden Dienst genau einmal', () async {
        late TestApp app;
        var first = true;
        String? owner;
        Future<void> jump(String _) async {
          if (first) app.gateway.attachFamilyRoom(roomB);
          first = false;
        }

        app = await make(
          beforeCalendarBuild: phase == 'Kalender' ? jump : null,
          beforeShoppingBuild: phase == 'Einkauf' ? jump : null,
          beforeTasksBuild: phase == 'Aufgaben' ? jump : null,
          claim: (o) async {
            if (owner != null && owner != o) {
              await app.events.wipe();
              await app.shoppingStore.wipe();
              await app.taskStore.wipe();
            }
            owner = o;
          },
        );
        await seed(app);
        final room = app.server.rooms[roomB]!;
        await app.services.openCalendar();
        await publishAll(app);
        expect(room.events, isEmpty);
        expect(app.services.openFamilyRoom, roomA, reason: 'AppRoot erkennt daran den Wechsel');
        expect(owner, '$_anna|$roomA');

        app.services.closeCalendar();
        await app.services.openCalendar();
        expect(owner, '$_anna|$roomB');
        expect(await app.events.all(), isEmpty, reason: 'Daten aus A sind vor dem Aufbau entfernt');
        final cal = app.services.calendar!;
        await cal.create(
          title: 'Aus B',
          start: DateTime.utc(2026, 11, 2, 9),
          end: DateTime.utc(2026, 11, 2, 10),
          visibility: EventVisibility.shared,
        );
        await app.services.shopping!.service.add('Aus B');
        await publishAll(app);
        expect(room.events.where((e) => e.type == EventCodec.sharedType), hasLength(1), reason: 'kein doppelter Dienst');
        expect(room.events.where((e) => e.type == ShoppingCodec.type), hasLength(1), reason: 'kein doppelter Dienst');
      });
    }

    for (final phase in <String>['Kalender', 'Einkauf', 'Aufgaben']) {
      test('$phase: closeCalendar während des Öffnens startet nichts', () async {
        final gate = Completer<void>();
        final reached = Completer<void>();
        Future<void> wait(String _) async {
          reached.complete();
          await gate.future;
        }

        final app = await make(
          beforeCalendarBuild: phase == 'Kalender' ? wait : null,
          beforeShoppingBuild: phase == 'Einkauf' ? wait : null,
          beforeTasksBuild: phase == 'Aufgaben' ? wait : null,
        );
        final open = app.services.openCalendar();
        await reached.future;
        app.services.closeCalendar();
        gate.complete();
        await open;
        expect(app.services.calendar, isNull);
        expect(app.services.shopping, isNull);
        expect(app.services.tasks, isNull);
        expect(app.services.presence, isNull);
        expect(app.services.reminders, isNull);
        expect(app.services.openFamilyRoom, isNull);
        if (phase == 'Kalender') expectDisposed(app.builtCalendars.single);
        if (phase == 'Einkauf') expectDisposed(app.builtShopping.single);
        if (phase == 'Aufgaben') expectDisposed(app.builtTasks.single);
        expect(app.gateway.debugHasListeners, isFalse, reason: 'kein gestarteter Dienst bleibt übrig, also kein späterer Sendelauf');
        expect(app.gateway.publishAttempts, 0);
      });

      test('$phase: ein veralteter Lauf überschreibt den neueren nicht', () async {
        final gate = Completer<void>();
        final reached = Completer<void>();
        var calls = 0;
        Future<void> wait(String _) async {
          if (++calls > 1) return;
          reached.complete();
          await gate.future;
        }

        final app = await make(
          beforeCalendarBuild: phase == 'Kalender' ? wait : null,
          beforeShoppingBuild: phase == 'Einkauf' ? wait : null,
          beforeTasksBuild: phase == 'Aufgaben' ? wait : null,
        );
        final stale = app.services.openCalendar();
        await reached.future;
        app.services.closeCalendar();
        await app.services.openCalendar();
        final calendar = app.services.calendar;
        final shopping = app.services.shopping;
        final tasks = app.services.tasks;
        final presence = app.services.presence;
        expect(calendar, isNotNull);
        gate.complete();
        await stale;
        expect(app.services.calendar, same(calendar));
        expect(app.services.shopping, same(shopping));
        expect(app.services.tasks, same(tasks));
        expect(app.services.presence, same(presence));
        if (phase == 'Kalender') expectDisposed(app.builtCalendars.last);
        if (phase == 'Einkauf') expectDisposed(app.builtShopping.last);
        if (phase == 'Aufgaben') expectDisposed(app.builtTasks.last);
      });
    }
  });

  group('Anspruch auf die lokalen Daten', () {
    test('läuft vor dem Aufbau mit dem Raum, bei dem das Öffnen begann', () async {
      final log = <String>[];
      final app = await make(
        claim: (o) async => log.add('Anspruch $o'),
        beforeCalendarBuild: (_) async => log.add('Aufbau'),
      );
      final open = app.services.openCalendar();
      app.gateway.attachFamilyRoom(roomB);
      await open;
      expect(log, <String>['Anspruch $_anna|$roomA', 'Aufbau']);
    });

    test('zwei Ansprüche laufen nacheinander, auch wenn der erste veraltet ist', () async {
      final gate = Completer<void>();
      final log = <String>[];
      final app = await make(
        claim: (o) async {
          log.add('Beginn $o');
          if (log.length == 1) await gate.future;
          log.add('Ende $o');
        },
      );
      final first = app.services.openCalendar();
      await Future<void>.delayed(Duration.zero);
      expect(log, hasLength(1));
      app.services.closeCalendar();
      app.gateway.attachFamilyRoom(roomB);
      final second = app.services.openCalendar();
      await Future<void>.delayed(Duration.zero);
      expect(log, hasLength(1), reason: 'der zweite wartet auf den ersten');
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(log, <String>['Beginn $_anna|$roomA', 'Ende $_anna|$roomA', 'Beginn $_anna|$roomB', 'Ende $_anna|$roomB']);
      expect(app.calendarRooms, <String>[roomB], reason: 'der veraltete Lauf baut nichts');
    });

    test('Anspruch scheitert: nichts offen, der Neuversuch gelingt', () async {
      var broken = true;
      final app = await make(
        claim: (_) async {
          if (broken) throw StateError('Speicher voll');
        },
      );
      await expectLater(app.services.openCalendar(), throwsStateError);
      expect(app.services.calendar, isNull);
      expect(app.services.openFamilyRoom, isNull);
      expect(app.calendarRooms, isEmpty, reason: 'kein Aufbau ohne Anspruch');
      broken = false;
      await app.services.openCalendar();
      expect(app.services.calendar, isNotNull);
      expect(app.services.openFamilyRoom, roomA);
    });

    test('ein Fehler des ersten Anspruchs trifft den wartenden zweiten nicht', () async {
      final gate = Completer<void>();
      var calls = 0;
      final app = await make(
        claim: (_) async {
          if (++calls == 1) {
            await gate.future;
            throw StateError('zu spät');
          }
        },
      );
      final first = app.services.openCalendar();
      await Future<void>.delayed(Duration.zero);
      app.services.closeCalendar();
      final second = app.services.openCalendar();
      final failed = expectLater(first, throwsStateError);
      gate.complete();
      await failed;
      await second;
      expect(app.services.calendar, isNotNull);
    });

    test('closeCalendar während des Anspruchs: es wird nichts gebaut', () async {
      final gate = Completer<void>();
      final app = await make(claim: (_) => gate.future);
      final open = app.services.openCalendar();
      await Future<void>.delayed(Duration.zero);
      app.services.closeCalendar();
      gate.complete();
      await open;
      expect(app.calendarRooms, isEmpty);
    });

    test('ein hängender Aufbau hält keinen neuen Lauf auf (#153)', () async {
      final gate = Completer<void>();
      var calls = 0;
      final app = await make(
        claim: (_) async {},
        beforeCalendarBuild: (_) async {
          if (++calls == 1) await gate.future;
        },
      );
      final stale = app.services.openCalendar();
      await Future<void>.delayed(Duration.zero);
      await app.services.openCalendar();
      expect(app.services.calendar, isNotNull);
      gate.complete();
      await stale;
    });
  });

  group('laufende Signale der geschlossenen Dienste', () {
    final at = DateTime.utc(2026, 11, 1, 12);

    Future<void> run(TestApp app, _Hold hold, void Function() inject) async {
      await app.services.openCalendar();
      hold.gate = Completer<void>();
      inject();
      await hold.entered.future;
      app.services.closeCalendar();
      app.services.closeCalendar(); // Ein Wechsel schließt mehrfach, der zweite Aufruf verwirft nichts.
      final open = app.services.openCalendar();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(app.calendarRooms, hasLength(1), reason: 'der Aufbau wartet auf die alte Warteschlange');
      final gate = hold.gate!;
      hold.gate = null;
      gate.complete();
      await open;
      expect(app.calendarRooms, hasLength(2));
    }

    test('Kalender: Anspruch und Aufbau laufen erst nach dem Durchlauf der alten Warteschlange', () async {
      final store = _HoldingEvents();
      final log = <String>[];
      late CalendarEvent e;
      Map<String, RsvpStatus>? atClaim;
      final app = await make(
        events: store,
        claim: (o) async {
          log.add('Anspruch');
          atClaim = (await store.rsvps())[e.id];
        },
      );
      e = await CalendarService(store: store, myUserId: _anna).create(
        title: 'Termin',
        start: DateTime.utc(2026, 11, 2, 9),
        end: DateTime.utc(2026, 11, 2, 10),
        timeZone: 'Europe/Berlin',
        visibility: EventVisibility.shared,
      );
      await run(app, store.hold, () => app.gateway.injectSignal(RsvpSignal('@ben:fake.test', at, EventCodec.encodeRsvp(e.id, RsvpStatus.accepted, at))));
      expect(log, <String>['Anspruch', 'Anspruch']);
      expect(atClaim, <String, RsvpStatus>{'@ben:fake.test': RsvpStatus.accepted}, reason: 'der Nachzügler ist vor dem Löschen fertig');
    });

    test('Einkauf: Aufbau erst nach dem Durchlauf der alten Warteschlange', () async {
      final store = _HoldingShopping();
      final app = await make(shopping: store);
      final item = ShoppingItem(id: '00000000-0000-4000-8000-00000000f00d', title: 'Milch', by: '@ben:fake.test', updatedAt: at);
      await run(app, store.hold, () => app.gateway.injectSignal(ShoppingSignal('@ben:fake.test', at, ShoppingCodec.encode(item))));
      expect(store.items[item.id], isNotNull);
    });

    test('Aufgaben: Aufbau erst nach dem Durchlauf der alten Warteschlange', () async {
      final store = _HoldingTasks();
      final app = await make(tasks: store);
      final list = await TaskService(store: MemoryTaskStore(), myUserId: _anna, isModerator: (id) => id == _anna).createList(
        title: 'Haushalt',
        assignee: _anna,
        interval: TaskInterval.daily,
        timeZone: 'Europe/Berlin',
        items: <String>['Eins'],
      );
      await run(app, store.hold, () => app.gateway.injectSignal(TaskListSignal(_anna, at, TaskCodec.encodeList(list))));
      expect(store.listsById[list.id], isNotNull);
    });
  });
}
