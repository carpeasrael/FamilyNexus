import 'package:family_nexus/data/sync/calendar_sync.dart';
import 'package:family_nexus/data/sync/shopping_sync.dart';
import 'package:family_nexus/data/sync/task_sync.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_event_store.dart';
import '../support/memory_shopping_store.dart';
import '../support/memory_task_store.dart';

/// Wechselt die Familie an einer gewählten Stelle mitten im Sendelauf: Die Warteschlange hält noch offene Zeilen aus A.
class _EventStore extends MemoryEventStore {
  void Function()? onMark;
  void Function()? onAll;

  void _fire() {
    final f = onMark;
    onMark = null;
    f?.call();
  }

  @override
  Future<void> markPublished(String id, int version) async {
    await super.markPublished(id, version);
    _fire();
  }

  @override
  Future<void> markRsvpPublished(String eventId, String userId, DateTime timestamp) async {
    await super.markRsvpPublished(eventId, userId, timestamp);
    _fire();
  }

  @override
  Future<List<CalendarEvent>> all() async {
    final r = await super.all();
    onAll?.call();
    return r;
  }
}

class _ShoppingStore extends MemoryShoppingStore {
  void Function()? onMark;

  @override
  Future<void> markPublished(String id, int version) async {
    await super.markPublished(id, version);
    final f = onMark;
    onMark = null;
    f?.call();
  }
}

class _TaskStore extends MemoryTaskStore {
  void Function()? onMark;

  void _fire() {
    final f = onMark;
    onMark = null;
    f?.call();
  }

  @override
  Future<void> markListPublished(String id, int version) async {
    await super.markListPublished(id, version);
    _fire();
  }

  @override
  Future<void> markLogPublished(String id) async {
    await super.markLogPublished(id);
    _fire();
  }
}

/// #140: Die Sync-Klassen gehören fest zu einer Familie. Nach einem Wechsel geht nichts aus A nach B, und nichts aus
/// fremden Signalen in die Ablage von A; Warteschlange und Wartefenster bleiben dabei unberührt.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late FakeRoom roomA;
  late FakeRoom roomB;
  const me = '@anna:fake.test';
  final at = DateTime.utc(2026, 11, 1, 12);

  setUp(() async {
    server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gateway.createFamily('Familie A');
    roomA = gateway.familyRoom!;
    roomB = server.addFamilyRoom('Familie B', me);
  });

  void toB() => gateway.attachFamilyRoom(roomB.id);

  int sent(FakeRoom room, String type) => room.events.where((e) => e.type == type).length;

  group('Kalender', () {
    late _EventStore store;
    late CalendarService service;
    late CalendarSync sync;

    setUp(() {
      store = _EventStore();
      service = CalendarService(store: store, myUserId: me);
      sync = CalendarSync(gateway: gateway, service: service, store: store, retryInterval: const Duration(hours: 1));
    });

    tearDown(() => sync.dispose());

    Future<CalendarEvent> event(String title, {EventVisibility visibility = EventVisibility.shared}) => service.create(
          title: title,
          start: DateTime.utc(2026, 11, 2, 9),
          end: DateTime.utc(2026, 11, 2, 10),
          timeZone: 'Europe/Berlin',
          visibility: visibility,
        );

    test('Wechsel während publishPending: der Rest bleibt in der Warteschlange, nichts geht nach B', () async {
      await event('A1');
      await event('A2');
      await event('A3', visibility: EventVisibility.private);
      sync.start(familyRoom: roomA.id);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, EventCodec.sharedType), 1);
      expect(sent(roomB, EventCodec.sharedType), 0);
      expect(server.log.where((e) => e.type == EventCodec.privateType), isEmpty, reason: 'Termin aus dem alten Bestand');
      expect(await store.pendingPublish(), hasLength(2));
    });

    test('Wechsel zwischen zwei Zusagen: die zweite geht nicht nach B', () async {
      final a = await event('A1');
      final b = await event('A2');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      await sync.respond(a.id, RsvpStatus.accepted);
      await sync.respond(b.id, RsvpStatus.declined);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, EventCodec.rsvpType), 1);
      expect(sent(roomB, EventCodec.rsvpType), 0);
      expect(await store.pendingRsvps(me), hasLength(1));
    });

    test('Wechsel während des Resync: nichts geht nach B', () async {
      await event('A1');
      await event('A2');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      final before = sent(roomA, EventCodec.sharedType);
      store.onAll = toB;
      await sync.resyncOwnShared();
      expect(sent(roomA, EventCodec.sharedType), before);
      expect(sent(roomB, EventCodec.sharedType), 0);
    });

    test('der Abbruch ändert das Wartefenster nicht, weder als Erfolg noch als Fehler', () async {
      await event('A1');
      await event('A2');
      sync.start(familyRoom: roomA.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      gateway.failPublishes = false;
      store.onMark = () => gateway.attachFamilyRoom(roomB.id, notify: false);
      await sync.publishPending();
      expect(sync.backoff.failures, 1, reason: 'kein zweiter Fehler und kein Erfolg');
      expect(sync.backoff.blocked, isTrue);
    });

    test('Signale nach dem Wechsel werden verworfen, auch der Beitritt eines Mitglieds', () async {
      final a = await event('A1');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      await store.markPublished(a.id, a.version);
      toB();
      final foreign = CalendarEvent(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ownerId: '@ben:fake.test',
        title: 'Fremd',
        start: DateTime.utc(2026, 11, 2, 9),
        end: DateTime.utc(2026, 11, 2, 10),
        timeZone: 'Europe/Berlin',
        updatedAt: at,
        visibility: EventVisibility.shared,
      );
      gateway.injectSignal(SharedEventSignal('@ben:fake.test', at, EventCodec.encodeShared(foreign)));
      gateway.injectSignal(RsvpSignal('@ben:fake.test', at, EventCodec.encodeRsvp(a.id, RsvpStatus.accepted, at)));
      gateway.injectSignal(MemberJoinedSignal('@ben:fake.test', at));
      await sync.idle();
      expect(await store.get(foreign.id), isNull);
      expect((await store.rsvps())[a.id], isNull);
      expect(await store.pendingPublish(), isEmpty, reason: 'kein erneutes Vormerken für die Mitglieder von B');
      expect(sync.rejected, 0, reason: 'verworfen ist nicht ungültig');
    });

    test('die Bindung kommt aus start, nicht aus dem Stand des Gateways beim Start', () async {
      await event('A1');
      toB();
      sync.start(familyRoom: roomA.id);
      expect(sync.sameFamily, isFalse);
      await sync.publishPending();
      expect(gateway.publishAttempts, 0);
      expect(sent(roomB, EventCodec.sharedType), 0);
    });

    test('ohne Angabe bindet die erste bekannte Familie', () async {
      final other = server.newDevice();
      server.addAccount('ben', 'pw2', displayName: 'Ben');
      await other.login(server: ServerUrl.tryParse(server.host)!, username: 'ben', password: 'pw2');
      final mine = CalendarSync(gateway: other, service: CalendarService(store: MemoryEventStore(), myUserId: '@ben:fake.test'), store: MemoryEventStore(), retryInterval: const Duration(hours: 1))..start();
      addTearDown(mine.dispose);
      expect(mine.sameFamily, isTrue, reason: 'noch keine Familie');
      server.addMember(roomA, '@ben:fake.test');
      other.attachFamilyRoom(roomA.id);
      expect(mine.sameFamily, isTrue);
      server.addMember(roomB, '@ben:fake.test');
      other.attachFamilyRoom(roomB.id);
      expect(mine.sameFamily, isFalse);
    });

    test('derselbe Raum bleibt offen; zurück in A geht es weiter', () async {
      await event('A1');
      sync.start(familyRoom: roomA.id);
      toB();
      await sync.publishPending();
      expect(sent(roomA, EventCodec.sharedType), 0);
      gateway.attachFamilyRoom(roomA.id);
      expect(sync.sameFamily, isTrue);
      await sync.publishPending();
      expect(sent(roomA, EventCodec.sharedType), 1);
      expect(sent(roomB, EventCodec.sharedType), 0);
    });
  });

  group('Einkaufszettel', () {
    late _ShoppingStore store;
    late ShoppingService service;
    late ShoppingSync sync;

    setUp(() {
      store = _ShoppingStore();
      service = ShoppingService(
        store: store,
        myUserId: me,
        idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
      );
      sync = ShoppingSync(gateway: gateway, service: service, store: store, retryInterval: const Duration(hours: 1));
    });

    tearDown(() => sync.dispose());

    test('Wechsel während publishPending: der Rest bleibt in der Warteschlange, nichts geht nach B', () async {
      await service.add('Milch');
      await service.add('Brot');
      sync.start(familyRoom: roomA.id);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, ShoppingCodec.type), 1);
      expect(sent(roomB, ShoppingCodec.type), 0);
      expect(await store.pendingPublish(), hasLength(1));
    });

    test('der Abbruch ändert das Wartefenster nicht, weder als Erfolg noch als Fehler', () async {
      await service.add('Milch');
      await service.add('Brot');
      sync.start(familyRoom: roomA.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      gateway.failPublishes = false;
      store.onMark = () => gateway.attachFamilyRoom(roomB.id, notify: false);
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      expect(sync.backoff.blocked, isTrue);
    });

    test('Signale nach dem Wechsel werden verworfen, auch der Beitritt eines Mitglieds', () async {
      final mine = await service.add('Milch');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      toB();
      final item = ShoppingItem(id: '00000000-0000-4000-8000-00000000f00d', title: 'Fremd', by: '@ben:fake.test', updatedAt: at);
      gateway.injectSignal(ShoppingSignal('@ben:fake.test', at, ShoppingCodec.encode(item)));
      gateway.injectSignal(MemberJoinedSignal('@ben:fake.test', at));
      await sync.idle();
      expect(await store.get(item.id), isNull);
      expect(await store.pendingPublish(), isEmpty, reason: '${mine.title} wird nicht erneut vorgemerkt');
      expect(sync.rejected, 0);
    });

    test('Bindung aus start: bereits gewechselt, nichts geht hinaus', () async {
      await service.add('Milch');
      toB();
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      expect(gateway.publishAttempts, 0);
      expect(await store.pendingPublish(), hasLength(1));
    });
  });

  group('Aufgaben', () {
    late _TaskStore store;
    late TaskService service;
    late TaskSync sync;

    setUp(() {
      store = _TaskStore();
      service = TaskService(
        store: store,
        myUserId: me,
        isModerator: (id) => id == me,
        clock: () => server.now(),
        idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
      );
      sync = TaskSync(gateway: gateway, service: service, store: store, retryInterval: const Duration(hours: 1));
    });

    tearDown(() => sync.dispose());

    Future<TaskList> list(String title) => service.createList(
          title: title,
          assignee: me,
          interval: TaskInterval.daily,
          timeZone: 'Europe/Berlin',
          items: <String>['Eins', 'Zwei'],
        );

    test('Wechsel zwischen zwei Listen: nichts geht nach B', () async {
      await list('Haushalt');
      await list('Garten');
      sync.start(familyRoom: roomA.id);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, TaskCodec.listType), 1);
      expect(sent(roomB, TaskCodec.listType), 0);
      expect(await store.pendingLists(), hasLength(1));
    });

    test('Wechsel zwischen zwei Protokolleinträgen: nichts geht nach B', () async {
      final l = await list('Haushalt');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      await service.complete(l.id, l.items[0].id);
      await service.complete(l.id, l.items[1].id);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, TaskCodec.logType), 1);
      expect(sent(roomB, TaskCodec.logType), 0);
      expect(await store.pendingLog(), hasLength(1));
    });

    test('Wechsel zwischen Listen und Protokoll: das Protokoll geht nicht nach B', () async {
      final l = await list('Haushalt');
      await service.complete(l.id, l.items[0].id);
      sync.start(familyRoom: roomA.id);
      store.onMark = toB;
      await sync.publishPending();
      expect(sent(roomA, TaskCodec.listType), 1);
      expect(sent(roomB, TaskCodec.logType) + sent(roomA, TaskCodec.logType), 0);
    });

    test('der Abbruch ändert das Wartefenster nicht, weder als Erfolg noch als Fehler', () async {
      await list('Haushalt');
      await list('Garten');
      sync.start(familyRoom: roomA.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      gateway.failPublishes = false;
      store.onMark = () => gateway.attachFamilyRoom(roomB.id, notify: false);
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      expect(sync.backoff.blocked, isTrue);
    });

    test('Signale nach dem Wechsel werden verworfen, auch der Beitritt eines Mitglieds', () async {
      await list('Haushalt');
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      toB();
      final foreign = await TaskService(
        store: MemoryTaskStore(),
        myUserId: me,
        isModerator: (id) => id == me,
        clock: () => server.now(),
        idGenerator: () => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}',
      ).createList(title: 'Fremd', assignee: me, interval: TaskInterval.daily, timeZone: 'Europe/Berlin', items: <String>['Eins']);
      gateway.injectSignal(TaskListSignal(me, at, TaskCodec.encodeList(foreign)));
      gateway.injectSignal(MemberJoinedSignal('@ben:fake.test', at));
      await sync.idle();
      expect(await store.getList(foreign.id), isNull);
      expect(await store.pendingLists(), isEmpty, reason: 'kein erneutes Vormerken');
      expect(sync.rejected, 0);
    });

    test('Bindung aus start: bereits gewechselt, nichts geht hinaus', () async {
      await list('Haushalt');
      toB();
      sync.start(familyRoom: roomA.id);
      await sync.publishPending();
      expect(gateway.publishAttempts, 0);
      expect(await store.pendingLists(), hasLength(1));
    });
  });
}

int _ids = 0;
