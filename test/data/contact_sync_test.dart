import 'package:family_nexus/data/sync/contact_sync.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/memory_contact_store.dart';

const String _carla = '@carla:example.org';
const String _ben = '@ben:example.org';

/// #119, K2c (E-114): Die Kontaktliste läuft über den privaten Raum zwischen den eigenen Geräten. Der Fake bildet zwei
/// Geräte desselben Kontos ab (Gerät B lauscht **vor** der Veröffentlichung von A; der Fake spielt keinen Verlauf nach).
void main() {
  late FakeMatrixServer server;
  late ContactPeer a;
  late ContactPeer b;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('dora', 'pw2', displayName: 'Dora');
    a = await ContactPeer.create(server, 'anna', 'pw1');
    b = await ContactPeer.create(server, 'anna', 'pw1');
  });

  tearDown(() {
    a.dispose();
    b.dispose();
  });

  test('Kontakt auf Gerät A erscheint auf Gerät B (Fake-Beleg „Liste synchron über zwei Geräte“); der Empfänger sendet nichts zurück', () async {
    final c = await a.service.addOutgoing(_carla, nick: 'Carla');
    await a.flush([b]);
    expect(await b.service.contact(_carla), c);
    expect(await b.store.pending(), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    expect(await a.store.pending(), isEmpty);
    final events = server.log.where((e) => e.type == ContactCodec.type).toList();
    expect(events, hasLength(1));
    expect(events.single.roomId, server.privateRooms['@anna:fake.test']!.id, reason: 'nur im privaten Raum');
  });

  test('Gruppe, Einstellung, Annahme, Blockieren und Entfernen laufen auf das andere Gerät', () async {
    await a.service.addOutgoing(_carla);
    await a.service.markAccepted(_carla, room: '!r:example.org');
    await a.service.addGroup('!g:example.org');
    await a.service.setEnabled(true);
    await a.service.block(_ben);
    await a.flush([b]);
    expect((await b.service.contact(_carla))!.state, ContactState.accepted);
    expect((await b.service.contact(_carla))!.room, '!r:example.org');
    expect(await b.service.groups(), hasLength(1));
    expect(await b.service.isEnabled(), isTrue);
    expect((await b.service.contact(_ben))!.state, ContactState.blocked);
    await a.service.remove(_carla);
    await a.service.unblock(_ben);
    await a.flush([b]);
    expect(await b.service.contacts(), isEmpty);
  });

  test('Konflikt: beide Geräte ändern, auf beiden gewinnt dieselbe Fassung (Totalordnung)', () async {
    await a.service.addOutgoing(_carla);
    await a.flush([b]);
    await a.service.rename(_carla, 'von A');
    await b.service.rename(_carla, 'von B');
    await a.sync.publishPending();
    await b.sync.publishPending();
    await ContactPeer.pumpAll([a, b]);
    final winner = (await a.service.contact(_carla))!;
    expect(await b.service.contact(_carla), winner);
    expect(winner.version, 2, reason: 'beide Geräte haben aus Version 1 geändert, die Totalordnung entscheidet');
  });

  test('ein fremdes Konto sieht nichts und seine Liste bleibt leer', () async {
    final d = await ContactPeer.create(server, 'dora', 'pw2');
    addTearDown(d.dispose);
    await a.service.addOutgoing(_carla);
    await a.flush([b, d]);
    expect(await d.service.contacts(), isEmpty);
    expect(await d.store.all(), isEmpty);
  });

  test('Echo des eigenen Datensatzes ändert nichts und löst kein onChanged aus', () async {
    var changes = 0;
    a.sync.onChanged = () => changes++;
    await a.service.addOutgoing(_carla);
    await a.flush([b]);
    expect(changes, 0, reason: 'das eigene Echo bei Gleichstand ist wirkungslos');
    var bChanges = 0;
    b.sync.onChanged = () => bChanges++;
    await a.service.rename(_carla, 'neu');
    await a.flush([b]);
    expect(bChanges, 1);
  });

  group('eingehende Prüfung', () {
    ContactSignal signal(Map<String, Object?> content, {String? sender, DateTime? at}) =>
        ContactSignal(sender ?? '@anna:fake.test', at ?? server.now(), content);
    test('ungültiger Inhalt, fremder Absender und ein Zeitstempel außerhalb der Toleranz werden verworfen und gezählt', () async {
      final good = ContactCodec.encode(Contact(id: _carla, state: ContactState.accepted, version: 1, updatedAt: server.now()));
      final signals = <ContactSignal>[
        signal(<String, Object?>{...good, 'ver': 0}),
        signal(good, sender: '@dora:fake.test'),
        signal(good, at: server.now().add(const Duration(days: 3))),
        signal(<String, Object?>{'v': 2}),
      ];
      final peer = await ContactPeer.create(server, 'anna', 'pw1', start: false);
      addTearDown(peer.dispose);
      for (final s in signals) {
        await peer.sync.debugDeliver(s);
      }
      expect(peer.sync.rejected, 4);
      expect(await peer.store.all(), isEmpty);
      await peer.sync.debugDeliver(signal(good));
      expect(await peer.service.contact(_carla), isNotNull);
    });
  });

  group('Lebenszyklus, Reihenfolge und Parallelität', () {
    test('start ist mehrfach aufrufbar: genau ein Zuhörer, dispose entfernt ihn', () async {
      final peer = await ContactPeer.create(server, 'anna', 'pw1', start: false);
      peer.sync.start();
      peer.sync.start();
      // ignore: invalid_use_of_protected_member
      expect(peer.gateway.hasListeners, isTrue);
      peer.dispose();
      // ignore: invalid_use_of_protected_member
      expect(peer.gateway.hasListeners, isFalse, reason: 'nach zweimal start und einmal dispose bleibt kein Zuhörer hängen');
      peer.dispose();
    });

    test('nach dispose kommen keine Signale mehr an und es wird nichts mehr abgeglichen', () async {
      final peer = await ContactPeer.create(server, 'anna', 'pw1');
      peer.dispose();
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      await peer.sync.idle();
      expect(await peer.store.all(), isEmpty);
    });

    test('fremde Signalarten werden ignoriert, ohne sie als ungültig zu zählen', () async {
      final peer = await ContactPeer.create(server, 'anna', 'pw1', start: false);
      addTearDown(peer.dispose);
      await peer.sync.debugDeliver(RsvpSignal('@anna:fake.test', server.now(), const <String, Object?>{}));
      expect(peer.sync.rejected, 0);
      expect(await peer.store.all(), isEmpty);
    });

    test('ein fremdes Konto bekommt das Ereignis gar nicht erst (nichts abgelehnt, nichts gespeichert)', () async {
      final d = await ContactPeer.create(server, 'dora', 'pw2');
      addTearDown(d.dispose);
      await a.service.addOutgoing(_carla);
      await a.flush([b, d]);
      expect(d.sync.rejected, 0);
    });

    test('wartende Datensätze gehen ältester zuerst hinaus (unabhängig von der Reihenfolge der Ablage)', () async {
      final newer = Contact(id: _ben, state: ContactState.accepted, version: 1, updatedAt: server.now());
      final older = Contact(id: _carla, state: ContactState.accepted, version: 1, updatedAt: server.now().subtract(const Duration(hours: 5)));
      await a.store.put(newer);
      await a.store.put(older);
      await a.sync.publishPending();
      final order = [
        for (final e in server.log.where((e) => e.type == ContactCodec.type)) e.content['id'],
      ];
      expect(order, <Object?>[_carla, _ben]);
    });

    test('zwei gleichzeitige Durchläufe senden jeden Datensatz nur einmal', () async {
      await a.service.addOutgoing(_carla);
      await Future.wait<void>(<Future<void>>[a.sync.publishPending(), a.sync.publishPending(), a.sync.publishPending()]);
      expect(server.log.where((e) => e.type == ContactCodec.type), hasLength(1));
    });

    test('ein während des Durchlaufs angemeldeter zweiter Anstoß wird nachgeholt', () async {
      await a.service.addOutgoing(_carla);
      final first = a.sync.publishPending();
      await a.service.addOutgoing(_ben);
      final second = a.sync.publishPending();
      await Future.wait<void>(<Future<void>>[first, second]);
      expect(await a.store.pending(), isEmpty);
      expect(server.log.where((e) => e.type == ContactCodec.type), hasLength(2));
    });

    test('ein nicht sendbarer Datensatz löst keinen Backoff aus', () async {
      await a.store.put(Contact(id: 'kein-konto', state: ContactState.accepted, version: 1, updatedAt: server.now()));
      await a.sync.publishPending();
      expect(a.sync.backoff.blocked, isFalse);
    });
  });

  group('Senden', () {
    test('die Warteschlange wartet bei einem Fehler, der Backoff greift, danach wird gesendet', () async {
      await a.service.addOutgoing(_carla);
      a.gateway.failPublishes = true;
      await a.sync.publishPending();
      expect(await a.store.pending(), hasLength(1));
      expect(a.sync.backoff.blocked, isTrue);
      a.gateway.failPublishes = false;
      a.sync.backoff.success();
      await a.flush([b]);
      expect(await a.store.pending(), isEmpty);
      expect(await b.service.contact(_carla), isNotNull);
    });

    test('ein nicht sendbarer Datensatz (invalidInput) bereinigt die Warteschlange und blockiert nichts', () async {
      await a.store.put(Contact(id: 'kein-konto', state: ContactState.accepted, version: 1, updatedAt: server.now()));
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      expect(await a.store.pending(), isEmpty);
      expect(await b.service.contact(_carla), isNotNull, reason: 'der gültige Datensatz wurde trotzdem gesendet');
    });

    test('ein lange wartender Datensatz wird vor dem Senden neu gestempelt und vom Empfänger angenommen', () async {
      final c = await a.service.addOutgoing(_carla);
      final later = DateTime.utc(2026, 10, 24, 12);
      server.now = () => later;
      server.nextTime = later; // Serverzeit des Ereignisses
      await a.flush([b]);
      final got = (await b.service.contact(_carla))!;
      expect(got.version, c.version);
      expect(got.updatedAt.isAfter(c.updatedAt), isTrue);
    });

    test('ohne Sitzung oder vor dem ersten Abgleich wird nichts gesendet', () async {
      await a.service.addOutgoing(_carla);
      a.gateway.syncDone = false;
      await a.sync.publishPending();
      expect(await a.store.pending(), hasLength(1));
      expect(server.log.where((e) => e.type == ContactCodec.type), isEmpty);
    });

    test('resync sendet alles Eigene erneut, der Empfänger bleibt unverändert; dispose beendet alles', () async {
      await a.service.addOutgoing(_carla);
      await a.service.addGroup('!g:example.org');
      await a.flush([b]);
      final before = await b.store.all();
      await a.sync.resync();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await a.flush([b]);
      expect(server.log.where((e) => e.type == ContactCodec.type).length, 4);
      expect(await b.store.all(), before);
      a.dispose();
      b.dispose();
    });
  });

  group('ohne Familie und über Familienwechsel (Kontakte gehören zum Konto)', () {
    test('Senden und Empfangen funktionieren ohne Familie', () async {
      expect(a.gateway.family, isNull);
      expect(b.gateway.family, isNull);
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      expect(await b.service.contact(_carla), isNotNull);
    });

    test('bei einem Familienwechsel bleibt der Bestand und wird weiter synchronisiert', () async {
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      await a.gateway.createFamily('Familie A');
      await b.gateway.createFamily('Familie B');
      await a.service.addOutgoing(_ben);
      await a.flush([b]);
      expect((await b.service.contacts()).map((c) => c.id), <String>[_ben, _carla]);
      final neu = await ContactPeer.create(server, 'anna', 'pw1', store: a.store, blockedList: a.blockedList);
      addTearDown(neu.dispose);
      expect((await neu.service.contacts()).length, 2, reason: 'ein neuer Controller mit demselben Speicher sieht den Bestand');
    });
  });

  group('Blockierliste', () {
    test('blockierte Kontakte werden eingetragen (Empfang und lokal); nur hinzufügen, nach Kennung sortiert', () async {
      b.blockedList.list.add('@lokal:example.org');
      await a.service.block('@z:example.org');
      await a.service.block('@a:example.org');
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      expect(b.blockedList.list.toSet(), <String>{'@lokal:example.org', '@a:example.org', '@z:example.org'});
      expect(b.blockedList.list.first, '@lokal:example.org', reason: 'nur hinzufügen');
      expect(b.blockedList.list, isNot(contains(_carla)));
    });

    test('ein Abgleich trägt mehrere Datensätze deterministisch nach Kennung sortiert ein', () async {
      final store = MemoryContactStore();
      final list = MemoryBlockedList();
      final peer = await ContactPeer.create(server, 'anna', 'pw1', store: store, blockedList: list, start: false);
      addTearDown(peer.dispose);
      for (final id in <String>['@z:example.org', '@m:example.org', '@a:example.org']) {
        await peer.service.block(id);
      }
      await peer.sync.reconcileBlocked();
      expect(list.list, <String>['@a:example.org', '@m:example.org', '@z:example.org']);
      await peer.sync.reconcileBlocked();
      expect(list.adds, 1, reason: 'ein zweiter Abgleich ohne Neues schreibt nicht');
    });

    test('die Aufhebung entfernt nichts aus der Liste', () async {
      await a.service.block(_ben);
      await a.flush([b]);
      expect(b.blockedList.list, <String>[_ben]);
      await a.service.unblock(_ben);
      await a.flush([b]);
      expect(b.blockedList.list, <String>[_ben]);
    });

    test('ist die Liste voll, werden keine Kontakt-Blockierten eingetragen (bewusste Grenze), ohne Absturz', () async {
      final full = MemoryBlockedList(<String>[for (var i = 0; i < BlockedUsers.maxEntries; i++) '@v$i:example.org']);
      final peer = await ContactPeer.create(server, 'anna', 'pw1', blockedList: full, start: false);
      addTearDown(peer.dispose);
      await peer.service.block(_ben);
      await peer.sync.reconcileBlocked();
      expect(full.list, hasLength(BlockedUsers.maxEntries));
      expect(full.list, isNot(contains(_ben)));
      expect(full.adds, 0);
    });

    test('Familienwechsel: die gelöschte Liste wird beim Start aus den blocked-Datensätzen wiederhergestellt', () async {
      final store = MemoryContactStore();
      final first = await ContactPeer.create(server, 'anna', 'pw1', store: store);
      await first.service.block(_ben);
      await first.sync.reconcileBlocked();
      expect(first.blockedList.list, <String>[_ben]);
      first.dispose();
      // `claimFamilyData` löscht die Liste bei Familienwechsel; der neue Controller startet mit leerer Liste.
      final restored = MemoryBlockedList();
      final second = await ContactPeer.create(server, 'anna', 'pw1', store: store, blockedList: restored);
      addTearDown(second.dispose);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(restored.list, <String>[_ben]);
    });

    test('Teilfall: bleibt weniger Platz, als Datensätze fehlen, werden genau die kleinsten Kennungen eingetragen', () async {
      final list = MemoryBlockedList(<String>[for (var i = 0; i < BlockedUsers.maxEntries - 2; i++) '@v$i:example.org'], 1000);
      final peer = await ContactPeer.create(server, 'anna', 'pw1', blockedList: list, start: false);
      addTearDown(peer.dispose);
      for (final id in <String>['@z:example.org', '@m:example.org', '@a:example.org', '@q:example.org']) {
        await peer.service.block(id);
      }
      await peer.sync.reconcileBlocked();
      expect(list.list.length, BlockedUsers.maxEntries);
      expect(list.list.skip(BlockedUsers.maxEntries - 2), <String>['@a:example.org', '@m:example.org']);
    });

    test('ohne Adapter tut der Abgleich nichts', () async {
      final sync = ContactSync(gateway: a.gateway, service: a.service, store: a.store);
      await sync.reconcileBlocked();
      expect(sync.rejected, 0);
    });
  });
}
