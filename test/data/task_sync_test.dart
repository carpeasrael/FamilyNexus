import 'package:family_nexus/domain/tasks.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/task_peer.dart';

void main() {
  late FakeMatrixServer server;
  late TaskPeer anna;
  late TaskPeer ben;
  late TaskPeer cara;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await TaskPeer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@ben:fake.test');
    server.addMember(room, '@cara:fake.test');
    ben = await TaskPeer.create(server, 'ben', 'pw2', familyRoomId: room.id);
    cara = await TaskPeer.create(server, 'cara', 'pw3', familyRoomId: room.id);
  });

  tearDown(() {
    anna.dispose();
    ben.dispose();
    cara.dispose();
  });

  Future<TaskList> newList() => anna.service.createList(
        title: 'Haushalt',
        assignee: ben.userId,
        interval: TaskInterval.daily,
        timeZone: 'Europe/Berlin',
        items: ['Müll raus', 'Spülmaschine'],
      );

  List<TaskPeer> others(TaskPeer me) => [anna, ben, cara].where((p) => p != me).toList();

  test('Liste erreicht alle Mitglieder, nur als Ereignis im Familienraum', () async {
    final l = await newList();
    await anna.flush(others(anna));
    for (final p in [ben, cara]) {
      expect(await p.store.getList(l.id), l);
    }
    expect(await ben.store.pendingLists(), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    expect(server.log.where((e) => e.type == TaskCodec.listType).every((e) => e.roomId == anna.gateway.familyRoom!.id), isTrue);
  });

  test('Abhaken mit Kommentar erscheint im Verlauf aller Geräte', () async {
    final l = await newList();
    await anna.flush(others(anna));
    final e = await ben.service.complete(l.id, l.items.first.id, comment: 'erledigt');
    await ben.flush(others(ben));
    for (final p in [anna, cara]) {
      final got = (await p.store.log(listId: l.id)).single;
      expect((got.id, got.comment, got.by, got.doneOn), (e.id, 'erledigt', ben.userId, '2026-10-21'));
    }
    expect(TaskProgress.doneNow(l, await anna.store.log(), server.now()).keys, [l.items.first.id]);
  });

  test('Issue #1: Liste mit Erklärung und neuer Regel (v2) erreicht alle; Abhaken nutzt den Schlüssel der Regel', () async {
    final l = await anna.service.createList(
      title: 'Hausaufgaben',
      assignee: ben.userId,
      rule: const TaskRule.weekly(DateTime.wednesday),
      description: 'Vor dem Abendessen.',
      timeZone: 'Europe/Berlin',
      items: ['Hefte packen'],
    );
    await anna.flush(others(anna));
    for (final p in [ben, cara]) {
      final got = await p.store.getList(l.id);
      expect((got?.rule, got?.description), (const TaskRule.weekly(DateTime.wednesday), 'Vor dem Abendessen.'));
    }
    expect(server.log.where((e) => e.type == TaskCodec.listType).last.content['v'], 2);
    final e = await ben.service.complete(l.id, l.items.single.id);
    await ben.flush(others(ben));
    // Test-Uhr: Mittwoch, 21.10.2026 → Periode beginnt an diesem Mittwoch.
    expect(e.periodKey, '2026-10-21');
    expect(TaskProgress.doneNow(l, await anna.store.log(), server.now()).keys, [l.items.single.id]);
  });

  test('Nicht-Moderator kann keine Liste einschleusen', () async {
    final l = await newList();
    await anna.flush(others(anna));
    // Cara baut an der Oberfläche vorbei eine Liste (eigener Dienst hält sie nicht auf).
    final rogue = TaskPeer.create(server, 'cara', 'pw3', familyRoomId: anna.gateway.familyRoom!.id, moderators: {'@cara:fake.test'});
    final c = await rogue;
    await c.service.createList(title: 'Böse', assignee: cara.userId, interval: TaskInterval.daily, timeZone: 'UTC', items: ['x']);
    await c.flush(<TaskPeer>[anna, ben]);
    expect((await ben.store.lists()).map((x) => x.title), [l.title], reason: 'Empfänger verwerfen');
    expect(ben.sync.rejected, greaterThan(0));
    c.dispose();
  });

  test('Nicht Zugewiesene können nicht in fremdem Namen abhaken', () async {
    final l = await newList();
    await anna.flush(others(anna));
    // Cara erzeugt einen Eintrag in ihrem Namen (gültig geformt, aber nicht zugewiesen).
    final e = TaskLogEntry(
      id: '00000000-0000-4000-8000-0000000000c1',
      listId: l.id,
      itemId: l.items.first.id,
      periodKey: '2026-10-21',
      doneOn: '2026-10-21',
      at: server.now(),
      by: cara.userId,
    );
    await cara.gateway.publishTaskLog(e);
    await TaskPeer.pumpAll([anna, ben, cara]);
    // Der Eintrag kommt an (er ist ein gültiges Ereignis), zählt aber nicht.
    expect(TaskProgress.doneNow(l, await ben.store.log(), server.now()), isEmpty);
    expect(TaskProgress.history(l, await ben.store.log()), isEmpty);
  });

  test('gefälschtes by wird verworfen', () async {
    final l = await newList();
    await anna.flush(others(anna));
    final forged = TaskCodec.encodeLog(TaskLogEntry(
      id: '00000000-0000-4000-8000-0000000000c2',
      listId: l.id,
      itemId: l.items.first.id,
      periodKey: '2026-10-21',
      doneOn: '2026-10-21',
      at: server.now(),
      by: ben.userId,
    ));
    server.post(anna.gateway.familyRoom!, cara.userId, TaskCodec.logType, forged);
    await TaskPeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.log(), isEmpty);
    expect(ben.sync.rejected, 1);
  });

  test('Müll blockiert nichts', () async {
    server.post(anna.gateway.familyRoom!, anna.userId, TaskCodec.listType, {'v': 1, 'x': 'y'});
    server.post(anna.gateway.familyRoom!, anna.userId, TaskCodec.logType, {'v': 'eins'});
    final l = await newList();
    await anna.flush(others(anna));
    await TaskPeer.pumpAll([anna, ben, cara]);
    expect(await ben.store.getList(l.id), l);
    expect(ben.sync.rejected, 2);
  });

  test('Offline-Warteschlange: nichts geht verloren, später wird gesendet', () async {
    final l = await newList();
    await anna.flush(others(anna));
    anna.gateway.failPublishes = false;
    ben.gateway.failPublishes = true;
    await ben.service.complete(l.id, l.items.first.id);
    await ben.sync.publishPending();
    expect(await ben.store.pendingLog(), hasLength(1));
    expect(await anna.store.log(), isEmpty);
    ben.gateway.failPublishes = false;
    await ben.flush(others(ben));
    expect(await ben.store.pendingLog(), isEmpty);
    expect(await anna.store.log(), hasLength(1));
  });

  test('Änderung durch die Moderatorin (Neuzuweisung) konvergiert', () async {
    final l = await newList();
    await anna.flush(others(anna));
    await anna.service.updateList(l.id,
        title: 'Haushalt', assignee: cara.userId, interval: TaskInterval.weekly, items: ['Müll raus', 'Spülmaschine']);
    await anna.flush(others(anna));
    final got = (await cara.store.getList(l.id))!;
    expect((got.assignee, got.interval, got.version), (cara.userId, TaskInterval.weekly, 2));
  });
}
