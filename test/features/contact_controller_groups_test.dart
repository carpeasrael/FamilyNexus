import 'dart:async';

import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/chat.dart' show ThreadKind;
import 'package:family_nexus/domain/contact_service.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/features/contacts/contact_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/memory_contact_store.dart';

/// Speicher, dessen Schreiben von Gruppen-Datensätzen scheitern kann und der nach `all(group)` einen Eingriff erlaubt (Wettlauf).
class _Store extends MemoryContactStore {
  bool failGroupPut = false;
  Future<void> Function()? afterAllGroups;

  @override
  Future<void> put(ContactRecord record, {int? publishedVersion}) async {
    if (failGroupPut && record.kind == ContactKind.group) throw StateError('Speicher');
    await super.put(record, publishedVersion: publishedVersion);
  }

  @override
  Future<List<ContactRecord>> all([ContactKind? kind]) async {
    final out = await super.all(kind);
    if (kind == ContactKind.group) await afterAllGroups?.call();
    return out;
  }
}

/// #119, K4-3: Gruppen im Kontakt-Controller gegen den Fake: Anfragen (I6), Anlegen, Annehmen, Ablehnen, Verlassen und das
/// Aufräumen der Datensätze mit Entprellung (3 Läufe und 10 Minuten, im Controller).
void main() {
  const carla = '@carla:fake.test';
  const dora = '@dora:fake.test';

  late FakeMatrixServer server;
  late ContactPeer peer;
  late ContactController c;
  late _Store store;
  late String me;
  late DateTime now;

  Matcher fails(ContactError e) => throwsA(isA<ContactException>().having((x) => x.error, 'error', e));
  Matcher failsG(GatewayError e) => throwsA(isA<GatewayException>().having((x) => x.error, 'error', e));

  setUp(() async {
    server = FakeMatrixServer();
    for (final n in <String>['anna', 'carla', 'dora']) {
      server.addAccount(n, 'pw-$n', displayName: n[0].toUpperCase() + n.substring(1));
    }
    store = _Store();
    peer = await ContactPeer.create(server, 'anna', 'pw-anna', store: store);
    await peer.gateway.createFamily('Familie');
    me = peer.gateway.userId!;
    now = DateTime.utc(2026, 11, 28, 12);
    c = ContactController(gateway: peer.gateway, sync: peer.sync, clock: () => now);
    c.start();
    await c.idle();
    await c.setEnabled(true);
    await c.idle();
  });

  tearDown(() {
    c.dispose();
    peer.dispose();
  });

  /// Eine Gruppeneinladung von Carla (nur eingeladen), sichtbar als Gruppenanfrage.
  Future<String> groupRequest() async {
    final room = server.createGroupRoom(carla, 'Skat', joined: <String>[], invited: <String>[me], inviter: carla);
    await c.idle();
    return room.id;
  }

  Future<void> confirmedContact(String id) async {
    await peer.service.addAccepted(id);
    await peer.sync.pushPolicyNow();
  }

  group('Anfragen (I6)', () {
    test('accept einer Gruppenanfrage ⇒ notAllowed, der Einladende wird nie zum bestätigten Kontakt, nichts wird geschrieben', () async {
      final room = await groupRequest();
      expect(c.requests.single.isGroup, isTrue);
      await expectLater(c.accept(room), fails(ContactError.notAllowed));
      expect(await peer.service.contact(carla), isNull, reason: 'kein addAccepted für eine Gruppenanfrage');
      expect(await peer.service.groups(), isEmpty);
      expect(peer.gateway.acceptGroupCalls, 0);
    });

    test('declineGroup lehnt ab ohne Datensatz; nur für Gruppenanfragen, unbekannt ⇒ notFound', () async {
      final room = await groupRequest();
      await c.declineGroup(room);
      expect(await peer.service.groups(), isEmpty);
      expect(await peer.service.contact(carla), isNull);
      await expectLater(c.declineGroup('!unbekannt:fake.test'), fails(ContactError.notFound));
      // Ein Einzelchat-Anfrage ist keine Gruppenanfrage.
      server.createContactRoom(dora, me);
      await c.idle();
      final direct = c.requests.firstWhere((r) => !r.isGroup);
      await expectLater(c.declineGroup(direct.roomId), fails(ContactError.notAllowed));
    });
  });

  group('createGroup', () {
    test('Reihenfolge: Raum, Datensatz, erst danach die Einladungen einzeln; Fehler je Person werden gesammelt, nie abgebrochen', () async {
      await confirmedContact(carla);
      final recordsAtInvite = <int>[];
      peer.gateway.onInviteToGroup = (room, user) async => recordsAtInvite.add((await peer.service.groups()).length);
      final result = await c.createGroup('Skatrunde', invite: <String>[dora, carla]);
      expect(recordsAtInvite, <int>[1, 1], reason: 'der Datensatz steht vor jeder Einladung');
      expect((await peer.service.groups()).single.id, result.roomId);
      expect(peer.gateway.contactPolicy.groups, contains(result.roomId), reason: 'Richtlinie geschoben');
      expect(result.invites.map((r) => r.userId), <String>[dora, carla]);
      expect(result.invites.first.error, GatewayError.notAllowed, reason: 'dora ist kein bestätigter Kontakt');
      expect(result.invites.last.ok, isTrue, reason: 'der Fehler bei der ersten Person bricht nicht ab');
      expect(peer.gateway.inviteToGroupCalls, 2);
    });

    test('Datensatz lässt sich nicht schreiben ⇒ der Raum wird verlassen (D3), der Fehler bleibt, keine Einladung', () async {
      await confirmedContact(carla);
      store.failGroupPut = true;
      await expectLater(c.createGroup('Skatrunde', invite: <String>[carla]), throwsA(isA<StateError>()));
      expect(server.groupRooms.values.single.dmMembers, isNot(contains(me)), reason: 'verlassen');
      expect(peer.gateway.inviteToGroupCalls, 0);
      expect(await peer.service.groups(), isEmpty);
    });

    test('Fehler des Gateways beim Anlegen: kein Datensatz; Bereich aus ⇒ notAllowed', () async {
      peer.gateway.createGroupError = GatewayError.serverUnreachable;
      await expectLater(c.createGroup('Skat'), failsG(GatewayError.serverUnreachable));
      expect(await peer.service.groups(), isEmpty);
      await c.setEnabled(false);
      await c.idle();
      await expectLater(c.createGroup('Skat'), fails(ContactError.notAllowed));
    });
  });

  group('acceptGroup', () {
    test('Datensatz zuerst, dann Richtlinie, dann Beitritt; die Gruppe erscheint', () async {
      final room = await groupRequest();
      var recordAtJoin = -1;
      var policyAtJoin = false;
      peer.gateway.beforeAcceptGroup = (r) async {
        recordAtJoin = (await peer.service.groups()).length;
        policyAtJoin = peer.gateway.contactPolicy.groups.contains(r);
      };
      await c.acceptGroup(room);
      expect(recordAtJoin, 1, reason: 'Datensatz vor dem Beitritt');
      expect(policyAtJoin, isTrue, reason: 'Richtlinie vor dem Beitritt');
      expect((await peer.service.groups()).single.id, room);
      expect(peer.gateway.threads.where((t) => t.kind == ThreadKind.group), hasLength(1));
      expect(await peer.service.contact(carla), isNull, reason: 'der Einladende bleibt Fremder');
    });

    test('Beitritt scheitert ⇒ Datensatz nur zurückgenommen, wenn dieser Aufruf ihn schrieb, und nur mit der geschriebenen Version', () async {
      final room = await groupRequest();
      peer.gateway.acceptGroupError = GatewayError.serverUnreachable;
      await expectLater(c.acceptGroup(room), failsG(GatewayError.serverUnreachable));
      expect(await peer.service.groups(), isEmpty, reason: 'zurückgenommen');
      expect(peer.gateway.contactPolicy.groups, isEmpty, reason: 'Richtlinie ohne die Gruppe');
      expect(c.requests.single.roomId, room, reason: 'die Anfrage bleibt sichtbar');

      // Ein anderer Stand (Version) dazwischen: die Rücknahme ist ein No-op.
      peer.gateway.beforeAcceptGroup = (r) async {
        await peer.service.removeGroup(r);
        await peer.service.addGroup(r);
      };
      await expectLater(c.acceptGroup(room), failsG(GatewayError.serverUnreachable));
      final kept = (await peer.service.groups()).single;
      expect(kept.version, greaterThan(2), reason: 'die neuere Version bleibt');
    });

    test('vorhandener Datensatz (Absturz nach dem Schreiben): kein duplicate, die Annahme läuft durch; bei Fehler bleibt der Datensatz', () async {
      final room = await groupRequest();
      await peer.service.addGroup(room);
      peer.gateway.acceptGroupError = GatewayError.serverUnreachable;
      await expectLater(c.acceptGroup(room), failsG(GatewayError.serverUnreachable));
      expect((await peer.service.groups()).single.id, room, reason: 'nicht von diesem Aufruf geschrieben: bleibt');
      peer.gateway.acceptGroupError = null;
      await c.acceptGroup(room);
      expect(peer.gateway.threads.where((t) => t.kind == ThreadKind.group), hasLength(1));
    });

    test('nur Gruppenanfragen; unbekannte Anfrage ⇒ notFound; Doppeltipp läuft nicht doppelt', () async {
      await expectLater(c.acceptGroup('!unbekannt:fake.test'), fails(ContactError.notFound));
      server.createContactRoom(dora, me);
      await c.idle();
      await expectLater(c.acceptGroup(c.requests.single.roomId), fails(ContactError.notAllowed));
      final room = await groupRequest();
      final gate = Completer<void>();
      peer.gateway.beforeAcceptGroup = (_) => gate.future;
      final first = c.acceptGroup(room);
      await Future<void>.delayed(Duration.zero);
      await c.acceptGroup(room); // läuft schon: kein zweiter Aufruf
      gate.complete();
      await first;
      expect(peer.gateway.acceptGroupCalls, 1);
    });
  });

  group('leaveGroup', () {
    Future<String> joined() async {
      final room = await groupRequest();
      await c.acceptGroup(room);
      await c.idle();
      return room;
    }

    test('erst den Raum verlassen, dann den Datensatz löschen und die Richtlinie schieben', () async {
      final room = await joined();
      await c.leaveGroup(room);
      expect(await peer.service.groups(), isEmpty);
      expect(peer.gateway.contactPolicy.groups, isEmpty);
      expect(server.groupRooms[room]!.dmMembers, isNot(contains(me)));
    });

    test('scheitert das Verlassen, bleibt der Datensatz; ohne Datensatz ⇒ notFound', () async {
      final room = await joined();
      peer.gateway.failLeaveConversation = true;
      await expectLater(c.leaveGroup(room), failsG(GatewayError.serverUnreachable));
      expect((await peer.service.groups()).single.id, room);
      peer.gateway.failLeaveConversation = false;
      await expectLater(c.leaveGroup('!unbekannt:fake.test'), fails(ContactError.notFound));
    });
  });

  group('Aufräumen der Datensätze mit Entprellung im Controller (3 Läufe, 10 Minuten)', () {
    Future<String> joinedGroup() async {
      final room = await groupRequest();
      await c.acceptGroup(room);
      await c.idle();
      expect(peer.gateway.leftGroupRooms, isEmpty);
      return room;
    }

    /// Ein Lauf: das Gateway meldet eine Änderung, der Controller liest neu.
    Future<void> run([int n = 1]) async {
      for (var i = 0; i < n; i++) {
        server.notifyAll();
        await c.idle();
      }
    }

    Future<int> count() async => (await peer.service.groups()).length;

    void gone(String room) => server.groupRooms[room]!.dmMembers.remove(me);

    test('1 oder 2 Läufe ⇒ kein Löschen (auch nach mehr als 10 Minuten); der dritte Lauf löscht', () async {
      final room = await joinedGroup();
      gone(room);
      expect(peer.gateway.leftGroupRooms, <String>{room});
      await run();
      now = now.add(const Duration(minutes: 11));
      await run();
      expect(await count(), 1, reason: 'zwei Läufe genügen nicht');
      await run();
      expect(await count(), 0, reason: 'drei Läufe und mehr als 10 Minuten');
      expect(peer.gateway.contactPolicy.groups, isEmpty, reason: 'Richtlinie geschoben');
    });

    test('3 Läufe, aber weniger als 10 Minuten ⇒ nein; danach 10 Minuten ⇒ ja', () async {
      final room = await joinedGroup();
      gone(room);
      await run(5);
      expect(await count(), 1, reason: 'viele Läufe, aber keine 10 Minuten');
      now = now.add(const Duration(minutes: 9, seconds: 59));
      await run();
      expect(await count(), 1);
      now = now.add(const Duration(seconds: 1));
      await run();
      expect(await count(), 0);
    });

    test('Rückkehr der Gruppe (ID verschwindet aus der Menge) setzt die Entprellung zurück', () async {
      final room = await joinedGroup();
      gone(room);
      await run(2);
      server.groupRooms[room]!.dmMembers.add(me); // zurück (Aussetzer des Zustands)
      await run();
      expect(peer.gateway.leftGroupRooms, isEmpty);
      now = now.add(const Duration(minutes: 11));
      gone(room);
      await run(2);
      expect(await count(), 1, reason: 'neu gezählt: erst zwei Läufe');
      now = now.add(const Duration(minutes: 11));
      await run();
      expect(await count(), 0, reason: 'dritter Lauf der neuen Zählung, mehr als 10 Minuten nach deren Beginn');
    });

    test('eine neuere Version bleibt (Versionsvergleich beim Löschen), unbekannte Räume nie, Bereich aus nie', () async {
      final room = await joinedGroup();
      gone(room);
      await run(2);
      now = now.add(const Duration(minutes: 11));
      // Zwischen Lesen und Löschen ändert sich der Datensatz (neue Version): das Löschen ist ein No-op.
      store.afterAllGroups = () async {
        store.afterAllGroups = null;
        // Neu beigetreten: neuer Datensatz (neue Version), die Gruppe ist zurück und nicht mehr in leftGroupRooms.
        await peer.service.removeGroup(room);
        await peer.service.addGroup(room);
        server.groupRooms[room]!.dmMembers.add(me);
      };
      await run();
      expect(await count(), 1, reason: 'die neuere Version bleibt');
      store.afterAllGroups = null;

      // Bereich aus: nie löschen, auch nicht nach vielen Läufen und Zeit; danach beginnt die Zählung neu.
      gone(room);
      expect(peer.gateway.leftGroupRooms, <String>{room});
      await c.setEnabled(false);
      await c.idle();
      now = now.add(const Duration(minutes: 30));
      await run(5);
      expect(await count(), 1);
      await c.setEnabled(true);
      await c.idle();
      await run(2);
      expect(await count(), 1, reason: 'nach dem Einschalten zählt wieder von vorn');
    });

    test('ein Datensatz ohne bekannten Raum (nicht in leftGroupRooms) wird nie gelöscht', () async {
      await peer.service.addGroup('!nie-gesehen:fake.test');
      await peer.sync.pushPolicyNow();
      now = now.add(const Duration(minutes: 30));
      await run(6);
      expect(await count(), 1);
      expect(peer.gateway.leftGroupRooms, isEmpty);
    });

    test('während acceptGroup für die Gruppe läuft, löscht der Controller sie nicht', () async {
      final room = await joinedGroup();
      await c.leaveGroup(room).catchError((Object _) {}); // verlässt und löscht den Datensatz
      // Gruppe wieder anfragen: Datensatz vorhanden (Absturzfall), der Raum steht in left (bewusst verlassen).
      await peer.service.addGroup(room);
      await peer.sync.pushPolicyNow();
      final r = server.groupRooms[room]!;
      r.dmMembers.add(me);
      r.invitedUsers.add(me);
      server.notifyAll();
      await c.idle();
      expect(peer.gateway.leftGroupRooms, <String>{room});
      expect(c.requests.where((q) => q.roomId == room), isNotEmpty);
      final gate = Completer<void>();
      peer.gateway.beforeAcceptGroup = (_) => gate.future;
      final accepting = c.acceptGroup(room);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(minutes: 30));
      await run(5);
      expect(await count(), 1, reason: 'acceptGroup läuft: nicht löschen');
      gate.complete();
      await accepting;
    });
  });

  test('Stand der Familienansicht bleibt: Gruppen erscheinen nie als Kontakte', () async {
    final room = await groupRequest();
    await c.acceptGroup(room);
    await c.idle();
    expect(c.contacts, isEmpty);
    expect(c.requests, isEmpty);
  });
}
