import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/sync/event_theme_sync.dart';
import 'package:family_nexus/data/sync/shopping_sync.dart';
import 'package:family_nexus/data/sync/task_sync.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
import 'package:family_nexus/domain/event_theme_service.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_event_theme_store.dart';
import '../support/memory_shopping_store.dart';
import '../support/memory_task_store.dart';

/// Ersatz für eine Ausnahme der lokalen Datenbank; nach dem Abschalten funktioniert der Speicher wieder.
class _ShoppingStore extends MemoryShoppingStore {
  bool failPending = false;
  bool failMark = false;

  @override
  Future<List<ShoppingItem>> pendingPublish() async {
    if (failPending) throw StateError('db');
    return super.pendingPublish();
  }

  @override
  Future<void> markPublished(String id, int version) async {
    if (failMark) throw StateError('db');
    return super.markPublished(id, version);
  }
}

class _TaskStore extends MemoryTaskStore {
  bool failLists = false;
  bool failLog = false;

  @override
  Future<List<TaskList>> pendingLists() async {
    if (failLists) throw StateError('db');
    return super.pendingLists();
  }

  @override
  Future<List<TaskLogEntry>> pendingLog() async {
    if (failLog) throw StateError('db');
    return super.pendingLog();
  }
}

class _ThemeStore extends MemoryEventThemeStore {
  bool failPending = false;

  @override
  Future<List<EventTheme>> pending() async {
    if (failPending) throw StateError('db');
    return super.pending();
  }
}

int _ids = 0;
String _id() => '00000000-0000-4000-8000-${(++_ids).toString().padLeft(12, '0')}';

/// #459: Unerwartete Fehler im Sendedurchlauf (z. B. lokale Datenbank) werden protokolliert, zählen als genau ein
/// Fehlversuch im Wartefenster, und `publishPending` schließt trotzdem ab. Gilt auch für den Weg über `kick()`.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late FakeRoom room;
  const me = '@anna:fake.test';

  setUp(() async {
    AppLog.captured.clear();
    AppLog.capture = true;
    server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gateway.createFamily('Familie');
    room = gateway.familyRoom!;
  });

  tearDown(() => AppLog.capture = false);

  List<String> errors(String tag) =>
      AppLog.captured.where((l) => l.contains('Sendedurchlauf gescheitert')).where((l) => l.startsWith('E/$tag:')).toList();

  int sent(String type) => room.events.where((e) => e.type == type).length;

  group('Einkaufszettel', () {
    late _ShoppingStore store;
    late ShoppingService service;
    late ShoppingSync sync;

    setUp(() {
      store = _ShoppingStore();
      service = ShoppingService(store: store, myUserId: me, idGenerator: _id);
      sync = ShoppingSync(gateway: gateway, service: service, store: store, retryInterval: const Duration(hours: 1));
    });

    tearDown(() => sync.dispose());

    test('Lesen der Warteschlange wirft: protokolliert, ein Fehlversuch, schließt ab', () async {
      await service.add('Milch');
      sync.start(familyRoom: room.id);
      store.failPending = true;
      await expectLater(sync.publishPending(), completes);
      expect(sync.backoff.failures, 1);
      expect(sync.backoff.blocked, isTrue);
      expect(errors('shopping'), <String>['E/shopping: Sendedurchlauf gescheitert (StateError)']);
      expect(gateway.publishAttempts, 0);
      store.failPending = false;
      expect(await store.pendingPublish(), hasLength(1));
    });

    test('Erholung: der nächste Durchlauf sendet und setzt das Wartefenster zurück', () async {
      await service.add('Milch');
      sync.start(familyRoom: room.id);
      store.failPending = true;
      await sync.publishPending();
      store.failPending = false;
      await sync.publishPending();
      expect(sent(ShoppingCodec.type), 1);
      expect(await store.pendingPublish(), isEmpty);
      expect(sync.backoff.failures, 0);
    });

    test('über kick(): der Fehler wird nicht still verworfen', () async {
      await service.add('Milch');
      sync.start(familyRoom: room.id);
      store.failPending = true;
      sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sync.backoff.failures, 1);
      expect(errors('shopping'), hasLength(1));
    });

    test('markPublished wirft nach dem Senden: ein Fehlversuch, Eintrag bleibt ausstehend', () async {
      await service.add('Milch');
      sync.start(familyRoom: room.id);
      store.failMark = true;
      await expectLater(sync.publishPending(), completes);
      expect(sent(ShoppingCodec.type), 1);
      expect(sync.backoff.failures, 1);
      expect(errors('shopping'), hasLength(1));
      expect(await store.pendingPublish(), hasLength(1));
    });

    test('Gateway-Fehler: weiter genau ein Fehlversuch, keine Zeile „Sendedurchlauf gescheitert“', () async {
      await service.add('Milch');
      sync.start(familyRoom: room.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      expect(errors('shopping'), isEmpty);
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
        idGenerator: _id,
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

    test('Lesen der Listen wirft: protokolliert, ein Fehlversuch, schließt ab', () async {
      await list('Haushalt');
      sync.start(familyRoom: room.id);
      store.failLists = true;
      await expectLater(sync.publishPending(), completes);
      expect(sync.backoff.failures, 1);
      expect(sync.backoff.blocked, isTrue);
      expect(errors('tasks'), <String>['E/tasks: Sendedurchlauf gescheitert (StateError)']);
      expect(gateway.publishAttempts, 0);
      store.failLists = false;
      expect(await store.pendingLists(), hasLength(1));
    });

    test('Erholung: der nächste Durchlauf sendet und setzt das Wartefenster zurück', () async {
      await list('Haushalt');
      sync.start(familyRoom: room.id);
      store.failLists = true;
      await sync.publishPending();
      store.failLists = false;
      await sync.publishPending();
      expect(sent(TaskCodec.listType), 1);
      expect(await store.pendingLists(), isEmpty);
      expect(sync.backoff.failures, 0);
    });

    test('über kick(): der Fehler wird nicht still verworfen', () async {
      await list('Haushalt');
      sync.start(familyRoom: room.id);
      store.failLists = true;
      sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sync.backoff.failures, 1);
      expect(errors('tasks'), hasLength(1));
    });

    test('Lesen des Protokolls wirft nach dem Listenteil: Liste gesendet, genau ein Fehlversuch', () async {
      await list('Haushalt');
      sync.start(familyRoom: room.id);
      store.failLog = true;
      await expectLater(sync.publishPending(), completes);
      expect(sent(TaskCodec.listType), 1);
      expect(await store.pendingLists(), isEmpty);
      expect(sync.backoff.failures, 1);
      expect(errors('tasks'), hasLength(1));
    });

    test('Gateway-Fehler: weiter genau ein Fehlversuch, keine Zeile „Sendedurchlauf gescheitert“', () async {
      await list('Haushalt');
      sync.start(familyRoom: room.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      expect(errors('tasks'), isEmpty);
    });
  });

  group('Themen', () {
    late _ThemeStore store;
    late EventThemeService service;
    late EventThemeSync sync;

    setUp(() {
      store = _ThemeStore();
      service = EventThemeService(
        store: store,
        myUserId: me,
        isModerator: (id) => id == me,
        clock: () => server.now(),
        idGenerator: _id,
      );
      sync = EventThemeSync(gateway: gateway, service: service, store: store, retryInterval: const Duration(hours: 1));
    });

    tearDown(() => sync.dispose());

    test('Lesen der Warteschlange wirft: protokolliert, ein Fehlversuch, schließt ab', () async {
      await service.create(name: 'Schule', colorIndex: 2);
      sync.start(familyRoom: room.id);
      store.failPending = true;
      await expectLater(sync.publishPending(), completes);
      expect(sync.backoff.failures, 1);
      expect(sync.backoff.blocked, isTrue);
      expect(errors('themes'), <String>['E/themes: Sendedurchlauf gescheitert (StateError)']);
      expect(gateway.publishAttempts, 0);
      store.failPending = false;
      expect(await store.pending(), hasLength(1));
    });

    test('Erholung: der nächste Durchlauf sendet und setzt das Wartefenster zurück', () async {
      await service.create(name: 'Schule', colorIndex: 2);
      sync.start(familyRoom: room.id);
      store.failPending = true;
      await sync.publishPending();
      store.failPending = false;
      await sync.publishPending();
      expect(sent(EventThemeCodec.type), 1);
      expect(await store.pending(), isEmpty);
      expect(sync.backoff.failures, 0);
    });

    test('über kick(): der Fehler wird nicht still verworfen', () async {
      await service.create(name: 'Schule', colorIndex: 2);
      sync.start(familyRoom: room.id);
      store.failPending = true;
      sync.kick();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(sync.backoff.failures, 1);
      expect(errors('themes'), hasLength(1));
    });

    test('Gateway-Fehler: weiter genau ein Fehlversuch, keine Zeile „Sendedurchlauf gescheitert“', () async {
      await service.create(name: 'Schule', colorIndex: 2);
      sync.start(familyRoom: room.id);
      gateway.failPublishes = true;
      await sync.publishPending();
      expect(sync.backoff.failures, 1);
      expect(errors('themes'), isEmpty);
    });
  });
}
