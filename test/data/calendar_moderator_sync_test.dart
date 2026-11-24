import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';
import '../support/fake_matrix.dart';
import '../support/peer.dart';

/// #431, E-112: Moderatorfassungen im Sync (Empfang). Ben empfängt Signale von Anna (Besitzerin) und Cara (Moderatorin).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  const cara = '@cara:fake.test';
  final now = DateTime.utc(2026, 11, 22, 12);
  final stamp = DateTime.utc(2026, 11, 22, 11);

  late FakeMatrixServer server;
  late Peer ben;
  late String room;
  late Map<String, Role?> roles;
  var changed = 0;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    final anna = await Peer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final r = anna.gateway.familyRoom!;
    room = r.id;
    server.addMember(r, '@ben:fake.test');
    anna.dispose();
    roles = <String, Role?>{cara: Role.moderator};
    ben = await Peer.create(server, 'ben', 'pw2', familyRoomId: room, clock: () => now, roleOf: (id) => roles[id]);
    changed = 0;
    ben.sync.onChanged = () => changed++;
  });

  tearDown(() => ben.dispose());

  const anna = '@anna:fake.test';

  Map<String, Object?> content(CalendarEvent e) => EventCodec.encodeShared(e);

  Future<void> signal(String sender, CalendarEvent e, {DateTime? at}) async {
    ben.gateway.injectSignal(SharedEventSignal(sender, at ?? stamp, content(e)));
    await pumpEventQueue();
  }

  CalendarEvent base() => ev(owner: anna, updatedAt: stamp);
  CalendarEvent byCara(int v, {String title = 'M'}) =>
      ev(owner: anna, version: v, title: title, updatedAt: stamp).copyWith(editorId: cara);

  test('Moderatorfassung auf bekannter Basis ersetzt sie und meldet eine Änderung', () async {
    await signal(anna, base());
    expect(changed, 1);
    await signal(cara, byCara(2));
    expect(changed, 2);
    final got = await ben.store.get(kId1);
    expect(got!.title, 'M');
    expect(got.editorId, cara);
    expect(got.ownerId, anna);
  });

  test('ohne Basis legt ein Moderator nie einen Termin an; die Basis des Besitzers holt ihn nach', () async {
    await signal(cara, byCara(2));
    expect(await ben.store.get(kId1), isNull);
    expect(changed, 0);
    await signal(anna, base());
    expect((await ben.store.get(kId1))!.version, 2, reason: 'gepufferte Fassung nach der Basis angenommen');
  });

  test('Nicht-Moderator, falscher editor, Löschmarke: nichts gespeichert, abgelehnt gezählt', () async {
    await signal(anna, base());
    roles[cara] = Role.member;
    await signal(cara, byCara(2));
    expect((await ben.store.get(kId1))!.version, 1);
    final forged = content(byCara(3))..['editor'] = '@ben:fake.test';
    ben.gateway.injectSignal(SharedEventSignal(cara, stamp, forged));
    await pumpEventQueue();
    expect(ben.sync.rejected, greaterThan(0));
    expect((await ben.store.get(kId1))!.version, 1);
  });

  test('Beförderung: Gateway-Änderung löst den Wiederholungslauf aus, nur bei geändertem Rollenabbild', () async {
    await signal(anna, base());
    roles[cara] = Role.member;
    await signal(cara, byCara(2));
    expect((await ben.store.get(kId1))!.version, 1);
    roles[cara] = Role.moderator;
    ben.gateway.attachFamilyRoom(room);
    await pumpEventQueue();
    expect((await ben.store.get(kId1))!.editorId, cara);
  });

  test('viele Gateway-Benachrichtigungen ohne Änderung lesen den Bestand nicht (Entprellung)', () async {
    // Moderatorin, aber ohne Basis: bleibt gepuffert, jeder Lauf würde die Basis lesen.
    await signal(cara, byCara(2));
    ben.gateway.attachFamilyRoom(room);
    await pumpEventQueue();
    final before = ben.store.getCalls;
    for (var i = 0; i < 1000; i++) {
      ben.gateway.attachFamilyRoom(room);
    }
    await pumpEventQueue();
    expect(ben.store.getCalls, before, reason: 'Rollenabbild unverändert: kein Lauf');
  });

  test('Familienwechsel: gepufferte Fassungen werden nicht mehr angewendet', () async {
    await signal(cara, byCara(2)); // gepuffert, keine Basis
    final dora = server.addAccount('dora', 'pw4', displayName: 'Dora');
    expect(dora, isNotEmpty);
    final other = await Peer.create(server, 'dora', 'pw4');
    await other.gateway.createFamily('Zwei');
    final otherRoom = other.gateway.familyRoom!.id;
    other.dispose();
    ben.gateway.attachFamilyRoom(otherRoom); // Wechsel: sameFamily ist falsch
    await pumpEventQueue();
    roles[cara] = Role.member; // Rollenabbild ändert sich, ein Lauf wäre fällig
    ben.gateway.attachFamilyRoom(otherRoom);
    await pumpEventQueue();
    await ben.store.put(base(), publishedVersion: 1); // Basis liegt jetzt da
    roles[cara] = Role.moderator;
    ben.gateway.attachFamilyRoom(otherRoom);
    await pumpEventQueue();
    expect((await ben.store.get(kId1))!.version, 1, reason: 'kein Lauf in fremder Familie');
  });

  test('Fremdfassung über den Sync legt nie einen neuen Termin an, auch nicht mit Basis eines anderen Besitzers', () async {
    await signal(cara, byCara(1));
    await signal(cara, byCara(5));
    expect(await ben.store.all(), isEmpty);
  });

  test('Resync des Besitzers mit editor-Behauptung ist ein Duplikat und meldet keine Änderung', () async {
    await signal(anna, base());
    await signal(cara, byCara(2));
    final n = changed;
    await signal(anna, byCara(2));
    expect(changed, n);
  });
}
