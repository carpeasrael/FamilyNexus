import 'dart:async';

import 'package:family_nexus/data/sync/contact_sync.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/memory_contact_store.dart';

/// Speicher, dessen nächster Lesezugriff nach einem Schreibvorgang einen **veralteten** Stand liefert, der erst später
/// ankommt (Race der Richtlinie, K3a-1).
class _StaleStore extends MemoryContactStore {
  bool armed = false;
  bool failNextAll = false;
  bool _delayNext = false;
  Completer<void>? gate;

  @override
  Future<void> put(ContactRecord record, {int? publishedVersion}) async {
    await super.put(record, publishedVersion: publishedVersion);
    if (armed) _delayNext = true;
  }

  @override
  Future<List<ContactRecord>> all([ContactKind? kind]) async {
    if (failNextAll) {
      failNextAll = false;
      throw StateError('Speicher nicht lesbar');
    }
    final snapshot = await super.all(kind);
    if (_delayNext) {
      _delayNext = false;
      gate = Completer<void>();
      await gate!.future;
    }
    return snapshot;
  }
}

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

  group('Richtlinie fürs Gateway (K3a-1)', () {
    test('ohne Datensätze bleibt es bei off, nichts wird geschoben; mit Datensätzen folgt die Richtlinie dem Bestand', () async {
      await a.sync.idle();
      expect(a.gateway.contactPolicy, ContactPolicy.off);
      expect(a.gateway.contactPolicyChanges, 0);
      await a.service.setEnabled(true);
      await a.service.addOutgoing(_carla);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.enabled, isTrue);
      expect(a.gateway.contactPolicy.contacts, <String, ContactState>{_carla: ContactState.outgoing});
      await a.service.markAccepted(_carla);
      await a.service.block(_ben);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.contacts, <String, ContactState>{_carla: ContactState.accepted, _ben: ContactState.blocked});
      expect(a.gateway.contactPolicy.blocked, <String>{_ben});
      await a.service.remove(_carla);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.contacts.keys, <String>[_ben], reason: 'Löschmarken fehlen');
    });

    test('ein Empfang vom anderen Gerät aktualisiert die Richtlinie ebenfalls', () async {
      await a.service.setEnabled(true);
      await a.service.addOutgoing(_carla);
      await a.flush([b]);
      await b.sync.idle();
      expect(b.gateway.contactPolicy.enabled, isTrue);
      expect(b.gateway.contactPolicy.contacts.keys, <String>[_carla]);
    });

    test('lokale Blockierliste (E-48): eine spätere lokale Blockierung erreicht die Richtlinie mit der nächsten Meldung des Gateways', () async {
      await a.service.setEnabled(true);
      await a.sync.idle();
      a.blockedList.list.add(_ben);
      expect(a.gateway.contactPolicy.blocked, isEmpty, reason: 'noch nicht gemeldet');
      a.gateway.setContactPolicy(ContactPolicy.off); // irgendeine Meldung des Gateways
      await a.sync.idle();
      expect(a.gateway.contactPolicy.blocked, <String>{_ben});
    });

    test('keine Schleife: Meldung des Gateways durch setContactPolicy löst keinen weiteren Aufbau aus', () async {
      await a.service.setEnabled(true);
      await a.service.addOutgoing(_carla);
      await a.sync.idle();
      final n = a.gateway.contactPolicyChanges;
      await a.sync.idle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await a.sync.idle();
      expect(a.gateway.contactPolicyChanges, n);
    });

    test('Race: ein langsamer älterer Aufbau überschreibt nie einen neueren (accepted, dann blockiert)', () async {
      final store = _StaleStore();
      final peer = await ContactPeer.create(server, 'anna', 'pw1', store: store);
      addTearDown(peer.dispose);
      await peer.service.setEnabled(true);
      await peer.service.addOutgoing(_carla);
      await peer.service.markAccepted(_carla);
      await peer.sync.idle();
      expect(peer.gateway.contactPolicy.contacts[_carla], ContactState.accepted);
      store.armed = true;
      final rename = peer.service.rename(_carla, 'C'); // der Aufbau liest hier den Stand „accepted“, kommt aber spät an
      await rename;
      await Future<void>.delayed(Duration.zero);
      store.armed = false;
      await peer.service.block(_carla); // während der erste Aufbau noch hängt
      expect(store.gate, isNotNull, reason: 'Voraussetzung: der erste Aufbau hängt');
      expect(peer.gateway.contactPolicy.contacts[_carla], ContactState.accepted, reason: 'noch der alte Stand');
      store.gate!.complete();
      await peer.sync.idle();
      expect(peer.gateway.contactPolicy.contacts[_carla], ContactState.blocked, reason: 'der neueste Stand gewinnt');
      expect(peer.gateway.contactPolicy.blocked, <String>{_carla});
    });

    test('idle wartet auf einen laufenden Aufbau der Richtlinie', () async {
      final store = _StaleStore();
      final peer = await ContactPeer.create(server, 'anna', 'pw1', store: store);
      addTearDown(peer.dispose);
      await peer.sync.idle();
      store.armed = true;
      await peer.service.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      store.armed = false;
      expect(store.gate, isNotNull, reason: 'Voraussetzung: der Aufbau hängt');
      var done = false;
      final idle = peer.sync.idle().then((_) => done = true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse, reason: 'idle darf nicht vor dem Aufbau fertig sein');
      store.gate!.complete();
      await idle;
      expect(peer.gateway.contactPolicy.enabled, isTrue);
    });

    test('dispose während eines laufenden Aufbaus: das späte Ergebnis erreicht das Gateway nicht mehr', () async {
      final store = _StaleStore();
      final peer = await ContactPeer.create(server, 'anna', 'pw1', store: store);
      await peer.sync.idle();
      store.armed = true;
      await peer.service.setEnabled(true);
      await Future<void>.delayed(Duration.zero);
      store.armed = false;
      expect(store.gate, isNotNull);
      peer.sync.dispose();
      store.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(peer.gateway.contactPolicy, ContactPolicy.off, reason: 'nach dispose bleibt es bei off');
    });

    test('dispose löst den eigenen Rückruf des Dienstes, lässt aber einen fremden stehen', () async {
      expect(a.service.onChanged, isNotNull);
      a.sync.dispose();
      expect(a.service.onChanged, isNull);
      a.sync.start();
      void other() {}
      a.service.onChanged = other;
      a.sync.dispose();
      expect(a.service.onChanged, same(other));
      a.service.onChanged = null;
    });

    test('ein Fehler beim Aufbau wird abgefangen; der nächste Anstoß baut wieder auf', () async {
      final store = _StaleStore();
      final peer = await ContactPeer.create(server, 'anna', 'pw1', store: store);
      addTearDown(peer.dispose);
      await peer.sync.idle();
      store.failNextAll = true;
      await peer.service.setEnabled(true); // der Aufbau liest und scheitert
      await peer.sync.idle();
      expect(peer.gateway.contactPolicy, ContactPolicy.off, reason: 'der Fehlschlag ändert nichts');
      await peer.service.addOutgoing(_carla);
      await peer.sync.idle();
      expect(peer.gateway.contactPolicy.enabled, isTrue);
      expect(peer.gateway.contactPolicy.contacts.keys, <String>[_carla]);
    });

    test('Wechsel des Gateway-Zustands (Abmelden) baut die Richtlinie neu', () async {
      await a.service.setEnabled(true);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.enabled, isTrue);
      a.gateway.setContactPolicy(ContactPolicy.off); // wie das Zurücksetzen des Gateways beim Abmelden
      await a.sync.idle();
      expect(a.gateway.contactPolicy, ContactPolicy.off, reason: 'ohne Zustandswechsel kein Aufbau');
      await a.gateway.logout();
      await a.sync.idle();
      expect(a.gateway.contactPolicy.enabled, isTrue, reason: 'Zustandswechsel: neu aus dem Bestand gebaut');
    });

    test('lokale Blockierliste: ein Austausch bei gleicher Länge (A gegen B) erreicht die Richtlinie', () async {
      await a.service.setEnabled(true);
      await a.sync.idle();
      a.blockedList.list.add(_ben);
      a.gateway.setContactPolicy(ContactPolicy.off);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.blocked, <String>{_ben});
      a.blockedList.list
        ..clear()
        ..add(_carla);
      a.gateway.setContactPolicy(ContactPolicy.off);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.blocked, <String>{_carla});
    });

    test('dispose setzt die Richtlinie zurück und beendet den Rückruf; start danach baut sie wieder auf', () async {
      await a.service.setEnabled(true);
      await a.service.addOutgoing(_carla);
      await a.sync.idle();
      expect(a.gateway.contactPolicy.enabled, isTrue);
      a.sync.dispose();
      expect(a.gateway.contactPolicy, ContactPolicy.off);
      await a.service.addOutgoing(_ben);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(a.gateway.contactPolicy, ContactPolicy.off, reason: 'nach dispose kein Aufbau mehr');
      a.sync.start();
      await a.sync.idle();
      expect(a.gateway.contactPolicy.contacts.keys, unorderedEquals(<String>[_carla, _ben]));
    });

    test('dispose nach dem Gateway wirft nicht', () async {
      final peer = await ContactPeer.create(server, 'anna', 'pw1');
      await peer.service.setEnabled(true);
      await peer.sync.idle();
      expect(peer.gateway.contactPolicy.enabled, isTrue);
      peer.gateway.dispose();
      expect(peer.sync.dispose, returnsNormally);
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
