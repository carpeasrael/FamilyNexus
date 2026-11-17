import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_codec.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/anniversary_peer.dart';
import '../support/fake_matrix.dart';

const AnniversaryDate _birth = AnniversaryDate(month: 3, day: 15, year: 1940);

void main() {
  late FakeMatrixServer server;
  late AnniversaryPeer anna;
  late AnniversaryPeer ben;
  late AnniversaryPeer cara;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await AnniversaryPeer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@ben:fake.test');
    server.addMember(room, '@cara:fake.test');
    ben = await AnniversaryPeer.create(server, 'ben', 'pw2', familyRoomId: room.id);
    cara = await AnniversaryPeer.create(server, 'cara', 'pw3', familyRoomId: room.id);
  });

  tearDown(() {
    anna.dispose();
    ben.dispose();
    cara.dispose();
  });

  List<AnniversaryPeer> others(AnniversaryPeer me) => [anna, ben, cara].where((p) => p != me).toList();

  AnniversaryPerson person(String id, {String by = '@anna:fake.test', String name = 'Oma'}) =>
      AnniversaryPerson(id: id, name: name, birth: _birth, by: by, updatedAt: server.now());

  test('Eintrag erreicht alle Mitglieder, nur als verschlüsseltes Ereignis im Familienraum', () async {
    final p = await anna.service.create(name: 'Oma', birth: _birth);
    await anna.flush(others(anna));
    for (final peer in [ben, cara]) {
      expect(await peer.store.get(p.id), p);
    }
    expect(await ben.store.pending(), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    expect(await anna.store.pending(), isEmpty);
    final events = server.log.where((e) => e.type == AnniversaryCodec.type).toList();
    expect(events, hasLength(1));
    expect(events.single.roomId, anna.gateway.familyRoom!.id);
  });

  test('jedes Mitglied darf ändern: Bens Änderung erreicht Anna, dann löscht Cara', () async {
    final p = await anna.service.create(name: 'Oma', birth: _birth);
    await anna.flush(others(anna));
    await ben.service.update(p.id, name: 'Oma Erna', birth: _birth);
    await ben.flush(others(ben));
    final got = (await anna.store.get(p.id))!;
    expect((got.name, got.version, got.by), ('Oma Erna', 2, '@ben:fake.test'));
    await cara.service.delete(p.id);
    await cara.flush(others(cara));
    expect((await anna.store.get(p.id))!.deleted, isTrue);
  });

  test('E-40: ein Absender ohne Eintrag in gateway.family wird angenommen (Vertrauensgrenze ist der Familienraum)', () async {
    expect(anna.gateway.family!.member('@dora:fake.test'), isNull);
    final signal = person('00000000-0000-4000-8000-0000000000c1', by: '@dora:fake.test');
    anna.gateway.injectSignal(AnniversarySignal('@dora:fake.test', server.now(), AnniversaryCodec.encode(signal)));
    await anna.sync.idle();
    expect(await anna.store.get(signal.id), signal);
  });

  test('gefälschtes by (Absender stimmt nicht) wird verworfen', () async {
    final forged = AnniversaryCodec.encode(person('00000000-0000-4000-8000-0000000000f1'));
    server.post(anna.gateway.familyRoom!, cara.userId, AnniversaryCodec.type, forged);
    await AnniversaryPeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.all(), isEmpty);
    expect(ben.sync.rejected, 1);
  });

  test('Müll und ungültiges Datum werden gezählt und blockieren nichts', () async {
    final bad = AnniversaryCodec.encode(person('00000000-0000-4000-8000-0000000000f2'))..['birth'] = <String, Object?>{'m': 2, 'd': 31};
    server.post(anna.gateway.familyRoom!, anna.userId, AnniversaryCodec.type, bad);
    server.post(anna.gateway.familyRoom!, anna.userId, AnniversaryCodec.type, {'v': 'eins'});
    final p = await anna.service.create(name: 'Oma', birth: _birth);
    await anna.flush(others(anna));
    await AnniversaryPeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.get(p.id), p);
    expect(await ben.store.all(), hasLength(1));
    expect(ben.sync.rejected, 2);
  });

  test('Senden mit Wiederholung: bei Fehler bleibt es in der Warteschlange, später wird gesendet', () async {
    anna.gateway.failPublishes = true;
    final p = await anna.service.create(name: 'Oma', birth: _birth);
    await anna.sync.publishPending();
    expect(await anna.store.pending(), [p]);
    expect(await ben.store.all(), isEmpty);
    expect(anna.sync.backoff.blocked, isTrue);
    anna.gateway.failPublishes = false;
    await anna.flush(others(anna));
    expect(await anna.store.pending(), isEmpty);
    expect(await ben.store.get(p.id), p);
  });

  test('MemberJoinedSignal sendet das Eigene erneut, Fremdes nicht', () async {
    final p = await anna.service.create(name: 'Oma', birth: _birth);
    await anna.flush(others(anna));
    final q = await ben.service.create(name: 'Opa', birth: _birth);
    await ben.flush(others(ben));
    final before = server.log.where((e) => e.type == AnniversaryCodec.type).length;
    anna.gateway.injectSignal(MemberJoinedSignal('@dora:fake.test', server.now()));
    await anna.sync.idle();
    expect((await anna.store.pending()).map((x) => x.id), [p.id], reason: 'nur das eigene');
    await anna.sync.publishPending();
    expect(server.log.where((e) => e.type == AnniversaryCodec.type).length, before + 1);
    expect(q.by, '@ben:fake.test');
  });

  test('Familienwechsel (_sameFamily): Signal eines anderen Raums wird ignoriert, nichts geht in die neue Familie', () async {
    final other = server.addFamilyRoom('Andere', '@anna:fake.test');
    final p = person('00000000-0000-4000-8000-0000000000e1');
    anna.gateway.injectSignal(AnniversarySignal(anna.userId, server.now(), AnniversaryCodec.encode(p)));
    await anna.sync.idle();
    expect(await anna.store.all(), [p], reason: 'Kontrolle: vor dem Wechsel kommt es an');
    await anna.store.wipe();
    await anna.service.create(name: 'Neu', birth: _birth);
    anna.gateway.attachFamilyRoom(other.id);
    anna.gateway.injectSignal(AnniversarySignal(anna.userId, server.now(), AnniversaryCodec.encode(person('00000000-0000-4000-8000-0000000000e2'))));
    await anna.sync.idle();
    expect(await anna.store.all(), hasLength(1), reason: 'das Signal der neuen Familie wird nicht in den alten Bestand gemischt');
    await anna.sync.publishPending();
    expect(other.events.where((e) => e.type == AnniversaryCodec.type), isEmpty);
    expect(await anna.store.pending(), hasLength(1));
  });

  test('Signal vor dem Familienstand (gateway.family == null) wird verworfen und beim erneuten Senden angenommen', () async {
    server.addAccount('eva', 'pw5', displayName: 'Eva');
    final eva = await AnniversaryPeer.create(server, 'eva', 'pw5');
    expect(eva.gateway.family, isNull);
    final p = person('00000000-0000-4000-8000-0000000000e3');
    final signal = AnniversarySignal('@anna:fake.test', server.now(), AnniversaryCodec.encode(p));
    eva.gateway.injectSignal(signal);
    await eva.sync.idle();
    expect(await eva.store.all(), isEmpty, reason: 'ohne Familie wird nicht gebucht (wie bei Themen, E-99)');
    eva.gateway.attachFamilyRoom(anna.gateway.familyRoom!.id);
    eva.gateway.injectSignal(AnniversarySignal('@anna:fake.test', server.now(), AnniversaryCodec.encode(p)));
    await eva.sync.idle();
    expect(await eva.store.get(p.id), p);
    eva.dispose();
  });
}
