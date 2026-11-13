import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/event_theme_peer.dart';
import '../support/fake_matrix.dart';

void main() {
  late FakeMatrixServer server;
  late EventThemePeer anna;
  late EventThemePeer ben;
  late EventThemePeer cara;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await EventThemePeer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@ben:fake.test');
    server.addMember(room, '@cara:fake.test');
    ben = await EventThemePeer.create(server, 'ben', 'pw2', familyRoomId: room.id);
    cara = await EventThemePeer.create(server, 'cara', 'pw3', familyRoomId: room.id);
  });

  tearDown(() {
    anna.dispose();
    ben.dispose();
    cara.dispose();
  });

  List<EventThemePeer> others(EventThemePeer me) => [anna, ben, cara].where((p) => p != me).toList();

  test('Thema erreicht alle Mitglieder, nur als Ereignis im Familienraum', () async {
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.flush(others(anna));
    for (final p in [ben, cara]) {
      expect(await p.store.get(t.id), t);
    }
    expect(await ben.store.pending(), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    expect(await anna.store.pending(), isEmpty, reason: 'Gesendetes ist als veröffentlicht vermerkt');
    final events = server.log.where((e) => e.type == EventThemeCodec.type).toList();
    expect(events, hasLength(1));
    expect(events.single.roomId, anna.gateway.familyRoom!.id);
    expect(events.single.content['name'], 'Schule');
  });

  test('Umbenennen, Farbe und Löschen konvergieren auf allen Geräten', () async {
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.flush(others(anna));
    await anna.service.update(t.id, name: 'Uni', colorIndex: 5);
    await anna.flush(others(anna));
    final got = (await cara.store.get(t.id))!;
    expect((got.name, got.colorIndex, got.version), ('Uni', 5, 2));
    await anna.service.delete(t.id);
    await anna.flush(others(anna));
    expect((await ben.store.get(t.id))!.deleted, isTrue);
  });

  test('Nicht-Moderator kann kein Thema einschleusen', () async {
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.flush(others(anna));
    // Cara hält sich lokal für Moderatorin und sendet trotzdem: Empfänger prüfen selbst.
    final rogue = await EventThemePeer.create(server, 'cara', 'pw3',
        familyRoomId: anna.gateway.familyRoom!.id, moderators: {'@cara:fake.test'});
    await rogue.service.create(name: 'Böse', colorIndex: 1);
    await rogue.flush(<EventThemePeer>[anna, ben]);
    expect((await ben.store.all()).map((x) => x.name), [t.name], reason: 'Empfänger verwerfen');
    expect(ben.sync.rejected, greaterThan(0));
    rogue.dispose();
  });

  test('gefälschtes by (Absender stimmt nicht) wird verworfen', () async {
    final forged = EventThemeCodec.encode(EventTheme(
      id: '00000000-0000-4000-8000-0000000000f1',
      name: 'Falsch',
      colorIndex: 1,
      by: anna.userId,
      updatedAt: server.now(),
    ));
    server.post(anna.gateway.familyRoom!, cara.userId, EventThemeCodec.type, forged);
    await EventThemePeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.all(), isEmpty);
    expect(ben.sync.rejected, 1);
  });

  test('Himmelblau und Müll werden gezählt und blockieren nichts', () async {
    final sky = EventThemeCodec.encode(EventTheme(
      id: '00000000-0000-4000-8000-0000000000f2',
      name: 'Blau',
      colorIndex: 1,
      by: anna.userId,
      updatedAt: server.now(),
    ))
      ..['color'] = 3;
    server.post(anna.gateway.familyRoom!, anna.userId, EventThemeCodec.type, sky);
    server.post(anna.gateway.familyRoom!, anna.userId, EventThemeCodec.type, {'v': 'eins'});
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.flush(others(anna));
    await EventThemePeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.get(t.id), t);
    expect(await ben.store.all(), hasLength(1));
    expect(ben.sync.rejected, 2);
  });

  test('Veröffentlichen mit Wiederholung: bei Fehler bleibt es in der Warteschlange, später wird gesendet', () async {
    anna.gateway.failPublishes = true;
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.sync.publishPending();
    expect(await anna.store.pending(), [t]);
    expect(await ben.store.all(), isEmpty);
    expect(anna.sync.backoff.blocked, isTrue, reason: 'Wartefenster nach dem Sendefehler');
    anna.gateway.failPublishes = false;
    await anna.flush(others(anna));
    expect(await anna.store.pending(), isEmpty);
    expect(await ben.store.get(t.id), t);
  });

  test('MemberJoinedSignal sendet das Eigene erneut (späte Beitritte, neue Geräte)', () async {
    final t = await anna.service.create(name: 'Schule', colorIndex: 2);
    await anna.flush(others(anna));
    expect(await anna.store.pending(), isEmpty);
    final before = server.log.where((e) => e.type == EventThemeCodec.type).length;
    server.addAccount('dora', 'pw4', displayName: 'Dora');
    final dora = await EventThemePeer.create(server, 'dora', 'pw4');
    // Der Beitritt benachrichtigt die Mitglieder (wie im echten Ablauf, E-13).
    server.addMember(anna.gateway.familyRoom!, '@dora:fake.test');
    dora.gateway.attachFamilyRoom(anna.gateway.familyRoom!.id);
    await anna.sync.idle();
    expect(await anna.store.pending(), [t], reason: 'erneut vorgemerkt');
    await anna.flush(<EventThemePeer>[dora, ben, cara]);
    expect(server.log.where((e) => e.type == EventThemeCodec.type).length, before + 1);
    expect(await dora.store.get(t.id), t, reason: 'das später beigetretene Mitglied sieht das Thema');
    dora.dispose();
  });

  test('Fremdes bleibt beim erneuten Senden unberührt (nur eigene Themen)', () async {
    // Ben ist (hier) ebenfalls Moderator und besitzt ein eigenes Thema; Annas Thema darf er nicht erneut senden.
    final mods = {'@anna:fake.test', '@ben:fake.test'};
    final b2 = await EventThemePeer.create(server, 'ben', 'pw2', familyRoomId: anna.gateway.familyRoom!.id, moderators: mods);
    final a2 = await EventThemePeer.create(server, 'anna', 'pw1', familyRoomId: anna.gateway.familyRoom!.id, moderators: mods);
    final ta = await a2.service.create(name: 'Annas', colorIndex: 2);
    await a2.flush(<EventThemePeer>[b2]);
    final tb = await b2.service.create(name: 'Bens', colorIndex: 4);
    await b2.flush(<EventThemePeer>[a2]);
    final before = server.log.where((e) => e.type == EventThemeCodec.type).length;
    b2.gateway.injectSignal(MemberJoinedSignal('@cara:fake.test', server.now()));
    await b2.sync.idle();
    expect((await b2.store.pending()).map((t) => t.id), [tb.id], reason: 'nur das eigene');
    await b2.sync.publishPending();
    expect(server.log.where((e) => e.type == EventThemeCodec.type).length, before + 1);
    expect(ta.by, '@anna:fake.test');
    a2.dispose();
    b2.dispose();
  });

  test('Signal eines anderen Familienraums wird ignoriert (Familienwechsel, #140)', () async {
    final other = server.addFamilyRoom('Andere', '@anna:fake.test');
    EventThemeSignal signal(String id, String name) => EventThemeSignal(
          '@anna:fake.test',
          server.now(),
          EventThemeCodec.encode(EventTheme(id: id, name: name, colorIndex: 2, by: '@anna:fake.test', updatedAt: server.now())),
        );
    anna.gateway.injectSignal(signal('00000000-0000-4000-8000-0000000000e1', 'Alte Familie'));
    await anna.sync.idle();
    expect((await anna.store.all()).single.name, 'Alte Familie', reason: 'Kontrolle: vor dem Wechsel kommt es an');
    await anna.store.wipe();
    anna.gateway.attachFamilyRoom(other.id);
    anna.gateway.injectSignal(signal('00000000-0000-4000-8000-0000000000e2', 'Nach Wechsel'));
    await anna.sync.idle();
    expect(await anna.store.all(), isEmpty, reason: 'Der Bestand gehört zur alten Familie');
    expect(anna.sync.rejected, 0);
  });

  test('Nach dem Wechsel geht nichts aus der alten Familie hinaus (kein Senden in die neue)', () async {
    final other = server.addFamilyRoom('Andere', '@anna:fake.test');
    await anna.service.create(name: 'Schule', colorIndex: 2);
    anna.gateway.attachFamilyRoom(other.id);
    await anna.sync.publishPending();
    expect(other.events.where((e) => e.type == EventThemeCodec.type), isEmpty);
    expect(await anna.store.pending(), hasLength(1), reason: 'bleibt in der Warteschlange');
  });

  test('Signal vor dem Familienstand wird verworfen, kein Absturz', () async {
    server.addAccount('eva', 'pw5', displayName: 'Eva');
    // Wie im echten Aufbau: Moderator ist, wer es laut aktuellem Familienstand ist (ohne Familie niemand).
    final eva = await EventThemePeer.create(server, 'eva', 'pw5', isModerator: (g, id) => Permissions.isModeratorId(g.family, id));
    eva.gateway.injectSignal(EventThemeSignal(
      '@anna:fake.test',
      server.now(),
      EventThemeCodec.encode(EventTheme(
        id: '00000000-0000-4000-8000-0000000000e3',
        name: 'Zu früh',
        colorIndex: 2,
        by: '@anna:fake.test',
        updatedAt: server.now(),
      )),
    ));
    await eva.sync.idle();
    expect(await eva.store.all(), isEmpty, reason: 'ohne Familie ist niemand Moderator: verworfen');
    eva.dispose();
  });
}
