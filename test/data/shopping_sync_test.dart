import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/shopping_peer.dart';

void main() {
  late FakeMatrixServer server;
  late ShoppingPeer anna;
  late ShoppingPeer ben;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await ShoppingPeer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@ben:fake.test');
    ben = await ShoppingPeer.create(server, 'ben', 'pw2', familyRoomId: room.id);
  });

  tearDown(() {
    anna.dispose();
    ben.dispose();
  });

  Iterable<FakeEvent> shoppingEvents() => server.log.where((e) => e.type == ShoppingCodec.type);

  test('ein neuer Eintrag erreicht Ben, nur als Ereignis im Familienraum', () async {
    final i = await anna.service.add('Milch', quantity: '2 Liter');
    await anna.flush(<ShoppingPeer>[ben]);
    final got = await ben.store.get(i.id);
    expect(got, isNotNull);
    expect((got!.title, got.quantity, got.by), ('Milch', '2 Liter', anna.userId));
    expect(await anna.store.pendingPublish(), isEmpty);
    expect(await ben.store.pendingPublish(), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    expect(shoppingEvents().every((e) => e.roomId == anna.gateway.familyRoom!.id), isTrue);
  });

  test('Ben darf Annas Eintrag abhaken und löschen; beide Seiten stimmen überein', () async {
    final i = await anna.service.add('Brot');
    await anna.flush(<ShoppingPeer>[ben]);
    await ben.service.setChecked(i.id, true);
    await ben.flush(<ShoppingPeer>[anna]);
    expect((await anna.store.get(i.id))!.checked, isTrue);
    expect((await anna.store.get(i.id))!.by, ben.userId);
    await anna.service.remove(i.id);
    await anna.flush(<ShoppingPeer>[ben]);
    expect((await ben.store.get(i.id))!.deleted, isTrue);
  });

  test('gleichzeitige Änderungen konvergieren auf beiden Geräten', () async {
    final i = await anna.service.add('Käse');
    await anna.flush(<ShoppingPeer>[ben]);
    // Beide ändern, ohne voneinander zu wissen.
    await anna.service.edit(i.id, title: 'Gouda');
    await ben.service.edit(i.id, title: 'Emmentaler');
    await anna.sync.publishPending();
    await ben.sync.publishPending();
    await ShoppingPeer.pumpAll(<ShoppingPeer>[anna, ben]);
    final a = (await anna.store.get(i.id))!;
    final b = (await ben.store.get(i.id))!;
    expect(a, b);
    expect(a.version, 2);
  });

  test('fremde Absender in „by“ werden verworfen (kein Schreiben in fremdem Namen)', () async {
    final forged = ShoppingItem(
      id: '00000000-0000-4000-8000-00000000f00d',
      title: 'Gefälscht',
      by: anna.userId,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );
    // Ben sendet einen Eintrag, der behauptet, von Anna zu sein.
    ben.gateway.injectSignal(ShoppingSignal(ben.userId, DateTime.utc(2026, 10, 21, 12), ShoppingCodec.encode(forged)));
    await ShoppingPeer.pumpAll(<ShoppingPeer>[ben]);
    expect(await ben.store.get(forged.id), isNull);
    expect(ben.sync.rejected, 1);
  });

  test('Ungültiges und Unsinn werden verworfen und blockieren nichts', () async {
    ben.gateway.injectSignal(ShoppingSignal(anna.userId, DateTime.utc(2026, 10, 21, 12), <String, Object?>{'v': 1}));
    ben.gateway.injectSignal(ShoppingSignal(anna.userId, DateTime.utc(2026, 10, 21, 12), <String, Object?>{'v': 9, 'id': 7}));
    final i = await anna.service.add('Butter');
    await anna.flush(<ShoppingPeer>[ben]);
    expect(ben.sync.rejected, 2);
    expect(await ben.store.get(i.id), isNotNull);
  });

  test('Offline: Änderungen bleiben in der Warteschlange und gehen später raus', () async {
    anna.gateway.failPublishes = true;
    final i = await anna.service.add('Eier');
    await anna.sync.publishPending();
    await ShoppingPeer.pumpAll(<ShoppingPeer>[anna, ben]);
    expect(await ben.store.get(i.id), isNull);
    expect((await anna.store.pendingPublish()).single.id, i.id);
    anna.gateway.failPublishes = false;
    await anna.flush(<ShoppingPeer>[ben]);
    expect(await ben.store.get(i.id), isNotNull);
    expect(await anna.store.pendingPublish(), isEmpty);
  });

  test('neues Mitglied erhält den Bestand: nur aktive Einträge, die man zuletzt selbst bearbeitet hat', () async {
    final a1 = await anna.service.add('A-Eintrag');
    final b1 = await anna.service.add('B-Eintrag');
    final gone = await anna.service.add('Gelöscht');
    await anna.flush(<ShoppingPeer>[ben]);
    await ben.service.setChecked(b1.id, true); // Ben ist letzter Bearbeiter von b1
    await anna.service.remove(gone.id);
    await ben.flush(<ShoppingPeer>[anna]);
    await anna.flush(<ShoppingPeer>[ben]);

    server.addAccount('dora', 'pw4', displayName: 'Dora');
    final dora = await ShoppingPeer.create(server, 'dora', 'pw4', familyRoomId: anna.gateway.familyRoom!.id);
    addTearDown(dora.dispose);
    final before = shoppingEvents().length;
    server.addMember(anna.gateway.familyRoom!, '@dora:fake.test');
    await ShoppingPeer.pumpAll(<ShoppingPeer>[anna, ben, dora]);
    await anna.sync.publishPending();
    await ben.sync.publishPending();
    await ShoppingPeer.pumpAll(<ShoppingPeer>[anna, ben, dora]);

    final resent = shoppingEvents().skip(before).map((e) => (e.sender, e.content['id'])).toList();
    expect(resent, contains((anna.userId, a1.id)));
    expect(resent, contains((ben.userId, b1.id)));
    expect(resent.where((r) => r.$2 == gone.id), isEmpty, reason: 'Löschmarken werden nicht erneut gesendet');
    expect(resent.where((r) => r.$1 == anna.userId && r.$2 == b1.id), isEmpty, reason: 'nur der letzte Bearbeiter sendet');
    expect((await dora.store.get(a1.id))!.title, 'A-Eintrag');
    expect((await dora.store.get(b1.id))!.checked, isTrue);
  });
}
