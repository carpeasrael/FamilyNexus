import 'package:family_nexus/data/sync/presence_sync.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/presence.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';

void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway anna;
  late FakeMatrixGateway ben;
  late FakeMatrixGateway cara;
  var enabled = true;
  late PresenceSync sync;
  const interval = Duration(milliseconds: 40);

  Future<FakeMatrixGateway> login(String user, String pw) async {
    final g = server.newDevice();
    await g.login(server: ServerUrl.tryParse(server.host)!, username: user, password: pw);
    return g;
  }

  setUp(() async {
    enabled = true;
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await login('anna', 'pw1');
    await anna.createFamily('Familie');
    final room = anna.familyRoom!;
    ben = await login('ben', 'pw2');
    server.addMember(room, '@ben:fake.test');
    ben.attachFamilyRoom(room.id);
    // Cara ist nur eingeladen, nicht beigetreten.
    cara = await login('cara', 'pw3');
    room.membership['@cara:fake.test'] = MemberStatus.invited;
    sync = PresenceSync(gateway: anna, enabled: () => enabled, heartbeat: interval, replyGap: Duration.zero);
  });

  tearDown(() => sync.dispose());

  Iterable<({String sender, bool online, bool ask, List<String> to})> sentByAnna() =>
      server.presenceLog.where((e) => e.sender == anna.userId);

  test('Vordergrund: „online“ mit Bitte um Antwort, nur an beigetretene Mitglieder', () async {
    sync.start(foreground: true);
    await pumpEventQueue();
    final first = sentByAnna().first;
    expect((first.online, first.ask), (true, true));
    expect(first.to, <String>[ben.userId!], reason: 'Eingeladene und Fremde erhalten nichts');
    expect(PresenceBoard.evaluate(ben.presence[anna.userId], server.now()).status, PresenceStatus.online);
    expect(cara.presence, isEmpty);
  });

  test('Lebenszeichen im Vordergrund ohne erneute Bitte um Antwort', () async {
    sync.start(foreground: true);
    await Future<void>.delayed(interval * 3);
    final list = sentByAnna().toList();
    expect(list.length, greaterThanOrEqualTo(2));
    expect(list.skip(1).every((e) => e.online && !e.ask), isTrue);
  });

  test('Hintergrund: „offline“ einmalig, danach Ruhe; zurück: wieder „online“', () async {
    sync.start(foreground: true);
    await pumpEventQueue();
    sync.setForeground(false);
    await pumpEventQueue();
    final n = sentByAnna().length;
    expect(sentByAnna().last.online, isFalse);
    await Future<void>.delayed(interval * 3);
    expect(sentByAnna().length, n, reason: 'im Hintergrund keine Lebenszeichen');
    sync.setForeground(true);
    await pumpEventQueue();
    expect(sentByAnna().last.online, isTrue);
  });

  test('Teilen ausgeschaltet: nie „online“, einmalig „offline“, keine Antworten auf Anfragen', () async {
    sync.start(foreground: true);
    await pumpEventQueue();
    enabled = false;
    sync.update();
    await pumpEventQueue();
    expect(sentByAnna().last.online, isFalse);
    final n = sentByAnna().length;
    await Future<void>.delayed(interval * 3);
    await ben.announcePresence(online: true, ask: true);
    await pumpEventQueue();
    expect(sentByAnna().length, n);
    expect(sentByAnna().skip(1).any((e) => e.online), isFalse);
  });

  test('war das Teilen von Anfang an aus, wird gar nichts gesendet', () async {
    enabled = false;
    sync.start(foreground: true);
    await Future<void>.delayed(interval * 3);
    expect(sentByAnna(), isEmpty);
  });

  test('Antwort auf eine Anfrage geht nur an den Anfragenden', () async {
    sync.start(foreground: true);
    await pumpEventQueue();
    final before = server.presenceLog.length;
    await ben.announcePresence(online: true, ask: true);
    await pumpEventQueue();
    final reply = server.presenceLog.skip(before).firstWhere((e) => e.sender == anna.userId);
    expect(reply.to, <String>[ben.userId!]);
    expect((reply.online, reply.ask), (true, false));
    expect(PresenceBoard.evaluate(anna.presence[ben.userId], server.now()).status, PresenceStatus.online);
  });

  test('im Hintergrund wird nicht auf Anfragen geantwortet', () async {
    sync.start(foreground: false);
    await pumpEventQueue();
    await ben.announcePresence(online: true, ask: true);
    await pumpEventQueue();
    expect(sentByAnna().any((e) => e.online), isFalse);
  });

  test('ohne Familie wird nichts gesendet; erst mit Familie nachgeholt', () async {
    final solo = await login('cara', 'pw3');
    final s = PresenceSync(gateway: solo, enabled: () => true, heartbeat: interval);
    addTearDown(s.dispose);
    s.start(foreground: true);
    await Future<void>.delayed(interval * 2);
    expect(server.presenceLog.where((e) => e.sender == solo.userId), isEmpty);
    expect(s.lastSent, isNull);
  });

  test('Entfernte Mitglieder erscheinen nicht mehr im Status', () async {
    await ben.announcePresence(online: true);
    expect(anna.presence.containsKey(ben.userId), isTrue);
    await anna.removeMember(ben.userId!);
    expect(anna.presence.containsKey(ben.userId), isFalse);
  });

  test('Schließen meldet „offline“', () async {
    sync.start(foreground: true);
    await pumpEventQueue();
    sync.dispose();
    await pumpEventQueue();
    expect(sentByAnna().last.online, isFalse);
  });

  test('goOffline meldet vor dem Abmelden „offline“ (nur, wenn zuvor online gemeldet)', () async {
    await sync.goOffline();
    expect(sentByAnna(), isEmpty, reason: 'nichts gemeldet, nichts zurückzunehmen');
    sync.start(foreground: true);
    await pumpEventQueue();
    await sync.goOffline();
    expect(sentByAnna().last.online, isFalse);
    expect(sync.lastSent, isFalse);
  });
}
