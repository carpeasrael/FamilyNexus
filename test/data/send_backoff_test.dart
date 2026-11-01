import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/sync/calendar_sync.dart';
import 'package:family_nexus/data/sync/send_backoff.dart';
import 'package:family_nexus/data/sync/shopping_sync.dart';
import 'package:family_nexus/data/sync/task_sync.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart' show EventTypes;

import '../support/fake_matrix.dart';
import '../support/peer.dart';
import '../support/shopping_peer.dart';
import '../support/task_peer.dart';

/// #132: Fehlgeschlagene Sendeversuche lösen sich nicht mehr selbst neu aus (Backoff), und das automatische
/// Wiederholen im Gateway fasst nur Chat-Nachrichten an.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('SendBackoff', () {
    late DateTime now;
    late SendBackoff b;
    setUp(() {
      now = DateTime.utc(2026, 11, 1, 10);
      b = SendBackoff(clock: () => now);
    });

    test('Fenster verdoppelt sich von 5 s bis 60 s und endet mit Zeitablauf', () {
      expect(b.blocked, isFalse);
      final steps = <int>[5, 10, 20, 40, 60, 60];
      for (final s in steps) {
        b.failure();
        expect(b.blocked, isTrue, reason: '$s s');
        now = now.add(Duration(seconds: s - 1));
        expect(b.blocked, isTrue, reason: 'kurz vor Ablauf ($s s)');
        now = now.add(const Duration(seconds: 1));
        expect(b.blocked, isFalse, reason: 'nach Ablauf ($s s)');
      }
      expect(b.failures, steps.length);
    });

    test('Erfolg und Reset heben das Fenster auf', () {
      b.failure();
      b.success();
      expect(b.blocked, isFalse);
      expect(b.failures, 0);
      b.failure();
      b.reset();
      expect(b.blocked, isFalse);
    });

    test('changed meldet nur Änderungen und setzt dann zurück', () {
      expect(b.changed(('ready', 1)), isTrue, reason: 'erster Aufruf merkt den Ausgangszustand');
      b.failure();
      expect(b.changed(('ready', 1)), isFalse);
      expect(b.blocked, isTrue);
      expect(b.changed(('ready', 2)), isTrue);
      expect(b.blocked, isFalse, reason: 'Wechsel hebt das Fenster auf');
    });
  });

  group('automatisches Wiederholen im Gateway', () {
    RetryDecision d({String type = EventTypes.Message, String sender = '@a:x', bool error = false, bool sent = false}) =>
        SdkMatrixGateway.retryDecision(type: type, senderId: sender, me: '@a:x', isError: error, isSent: sent);

    test('nur eigene Chat-Nachrichten im Fehlerzustand werden wiederholt', () {
      expect(d(error: true), RetryDecision.retry);
      expect(d(sender: '@b:x', error: true), RetryDecision.skip, reason: 'fremder Absender');
    });

    test('andere Ereignistypen werden nicht wiederholt (Kalender, Einkauf, Aufgaben, Reaktionen)', () {
      for (final t in <String>['de.inneso.familynexus.event', 'de.inneso.familynexus.shopping', 'de.inneso.familynexus.task.list', EventTypes.Reaction]) {
        expect(d(type: t, error: true), RetryDecision.skip, reason: t);
      }
    });

    test('der Zähler bleibt während „wird gesendet“ und wird erst bei „gesendet“ gelöscht', () {
      expect(d(), RetryDecision.skip, reason: 'sending: weder wiederholen noch Zähler löschen');
      expect(d(sent: true), RetryDecision.forget);
      expect(d(type: 'de.inneso.familynexus.event', sent: true), RetryDecision.skip);
    });
  });

  /// Wartezeit für die Entprellung (200 ms) der Sync-Klassen.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 300));

  group('Kalender', () {
    late FakeMatrixServer server;
    late Peer anna;
    late DateTime now;
    late CalendarSync sync;

    setUp(() async {
      now = DateTime.utc(2026, 11, 1, 10);
      server = FakeMatrixServer();
      server.addAccount('anna', 'pw1', displayName: 'Anna');
      anna = await Peer.create(server, 'anna', 'pw1');
      await anna.gateway.createFamily('Familie');
      anna.sync.dispose();
      sync = CalendarSync(
        gateway: anna.gateway,
        service: anna.service,
        store: anna.store,
        clock: () => now,
        retryInterval: const Duration(hours: 1),
      )..start();
      await settle();
    });

    tearDown(() => sync.dispose());

    test('Anstöße im Wartefenster erzeugen keinen Versuch; danach genau einen; Erfolg setzt zurück', () async {
      await anna.createEvent(title: 'Wartet');
      anna.gateway.failPublishes = true;
      final base = anna.gateway.publishAttempts;
      await sync.publishPending();
      expect(anna.gateway.publishAttempts, base + 1);

      for (var i = 0; i < 4; i++) {
        server.notifyAll();
        await settle();
      }
      expect(anna.gateway.publishAttempts, base + 1, reason: 'Fenster 5 s: Fehlerereignisse stoßen nichts an');

      now = now.add(const Duration(seconds: 6));
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, base + 2, reason: 'nach dem Fenster genau ein Versuch');
      for (var i = 0; i < 3; i++) {
        server.notifyAll();
        await settle();
      }
      expect(anna.gateway.publishAttempts, base + 2, reason: 'neues Fenster 10 s');

      anna.gateway.failPublishes = false;
      now = now.add(const Duration(seconds: 11));
      server.notifyAll();
      await settle();
      expect(await anna.store.pendingPublish(), isEmpty, reason: 'Versuch gelingt');
      final done = anna.gateway.publishAttempts;

      await anna.createEvent(title: 'Neu');
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, greaterThan(done), reason: 'nach Erfolg gilt kein Fenster mehr');
    });

    test('ein ausdrücklicher kick() sendet auch im Wartefenster', () async {
      await anna.createEvent();
      anna.gateway.failPublishes = true;
      await sync.publishPending();
      final before = anna.gateway.publishAttempts;
      sync.kick();
      await settle();
      expect(anna.gateway.publishAttempts, before + 1);
    });

    test('Wiederverbindung (Zustandswechsel) hebt das Fenster auf und sendet sofort', () async {
      await anna.createEvent();
      anna.gateway.failPublishes = true;
      await sync.publishPending();
      anna.gateway.failPublishes = false;
      final before = anna.gateway.publishAttempts;

      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, before, reason: 'im Fenster, ohne Zustandswechsel: kein Versuch');

      anna.gateway.syncDone = false; // Verbindung weg
      server.notifyAll();
      await settle();
      anna.gateway.syncDone = true; // Verbindung wieder da
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, greaterThan(before), reason: 'Zustandswechsel hebt das Fenster auf');
      expect(await anna.store.pendingPublish(), isEmpty);
    });

    test('Termine und Zusagen laufen im selben Durchlauf, der Durchlauf zählt einen Fehler', () async {
      final e = await anna.createEvent(title: 'Mit Zusage');
      await sync.publishPending();
      await settle(); // der erfolgreiche Versand stößt über den Gateway noch einen entprellten Versuch an
      await anna.store.putRsvp(e.id, anna.userId, RsvpStatus.accepted, DateTime.utc(2026, 11, 1), published: false);
      await anna.createEvent(title: 'Zweiter');
      anna.gateway.failPublishes = true;
      final before = anna.gateway.publishAttempts;
      await sync.publishPending();
      expect(anna.gateway.publishAttempts, before + 2, reason: 'ein Termin- und ein Zusage-Versuch im selben Durchlauf');
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, before + 2, reason: 'im Fenster');
      now = now.add(const Duration(seconds: 6));
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, before + 4, reason: 'ein Fehler zählt: Fenster 5 s, nach 6 s wieder frei');
    });
  });

  group('Einkauf', () {
    test('Anstöße im Wartefenster erzeugen keinen Versuch', () async {
      final server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
      final anna = await ShoppingPeer.create(server, 'anna', 'pw1');
      await anna.gateway.createFamily('Familie');
      anna.sync.dispose();
      var now = DateTime.utc(2026, 11, 1, 10);
      final sync = ShoppingSync(
        gateway: anna.gateway,
        service: anna.service,
        store: anna.store,
        clock: () => now,
        retryInterval: const Duration(hours: 1),
      )..start();
      addTearDown(sync.dispose);
      await settle();
      await anna.service.add('Milch');
      anna.gateway.failPublishes = true;
      final base = anna.gateway.publishAttempts;
      await sync.publishPending();
      expect(anna.gateway.publishAttempts, base + 1);
      for (var i = 0; i < 3; i++) {
        server.notifyAll();
        await settle();
      }
      expect(anna.gateway.publishAttempts, base + 1);
      now = now.add(const Duration(seconds: 6));
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, base + 2);
    });
  });

  group('Aufgaben', () {
    test('Anstöße im Wartefenster erzeugen keinen Versuch', () async {
      final server = FakeMatrixServer()..addAccount('anna', 'pw1', displayName: 'Anna');
      final anna = await TaskPeer.create(server, 'anna', 'pw1');
      await anna.gateway.createFamily('Familie');
      anna.sync.dispose();
      var now = DateTime.utc(2026, 11, 1, 10);
      final sync = TaskSync(
        gateway: anna.gateway,
        service: anna.service,
        store: anna.store,
        clock: () => now,
        retryInterval: const Duration(hours: 1),
      )..start();
      addTearDown(sync.dispose);
      await settle();
      await anna.service.createList(
        title: 'Haushalt',
        assignee: anna.userId,
        interval: TaskInterval.daily,
        timeZone: 'Europe/Berlin',
        items: <String>['Müll raus'],
      );
      anna.gateway.failPublishes = true;
      final base = anna.gateway.publishAttempts;
      await sync.publishPending();
      expect(anna.gateway.publishAttempts, base + 1);
      for (var i = 0; i < 3; i++) {
        server.notifyAll();
        await settle();
      }
      expect(anna.gateway.publishAttempts, base + 1);
      now = now.add(const Duration(seconds: 6));
      server.notifyAll();
      await settle();
      expect(anna.gateway.publishAttempts, base + 2);
    });
  });
}
