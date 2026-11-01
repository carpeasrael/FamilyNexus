import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/event_codec.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';
import '../support/fake_matrix.dart';
import '../support/peer.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);

  late FakeMatrixServer server;
  late Peer anna;
  late Peer ben;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('ben', 'pw2', displayName: 'Ben');
    server.addAccount('cara', 'pw3', displayName: 'Cara');
    anna = await Peer.create(server, 'anna', 'pw1');
    await anna.gateway.createFamily('Familie');
    final room = anna.gateway.familyRoom!;
    server.addMember(room, '@ben:fake.test');
    ben = await Peer.create(server, 'ben', 'pw2', familyRoomId: room.id);
  });

  tearDown(() {
    anna.dispose();
    ben.dispose();
  });

  Iterable<FakeEvent> familyCalendarEvents() =>
      server.log.where((e) => e.roomId == anna.gateway.familyRoom!.id && e.type.startsWith('de.inneso'));

  group('geteilte Termine', () {
    test('werden verschlüsselt in den Familienraum gesendet und von Ben übernommen', () async {
      final e = await anna.createEvent(title: 'Elternabend');
      await anna.sync.publishPending();
      await pumpEventQueue();
      final got = await ben.store.get(e.id);
      expect(got, isNotNull);
      expect(got!.title, 'Elternabend');
      expect(got.ownerId, anna.userId);
      expect(ben.service.canEdit(got), isFalse, reason: 'Ben darf fremde Termine nicht ändern');
      expect(await anna.store.pendingPublish(), isEmpty);
    });

    test('Änderung und Löschung erreichen Ben; ältere Fassung bleibt im Verlauf', () async {
      final e = await anna.createEvent(title: 'Alt');
      await anna.sync.publishPending();
      await anna.service.update(e.copyWith(title: 'Neu'));
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect((await ben.store.get(e.id))!.title, 'Neu');
      expect((await ben.store.history(e.id)).map((x) => x.title), <String>['Alt']);
      await anna.service.delete(e.id);
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect((await ben.store.get(e.id))!.deleted, isTrue);
    });
  });

  group('private Termine (Sicherheit)', () {
    test('verlassen nie den privaten Raum: nicht im Familienraum, nicht bei Ben', () async {
      final shared = await anna.createEvent(title: 'Offen', visibility: EventVisibility.shared);
      final secret = await anna.createEvent(title: 'GEHEIM-ARZT', visibility: EventVisibility.private);
      await anna.sync.publishPending();
      await pumpEventQueue();

      // 1. Kein Ereignis des Familienraums trägt privaten Typ oder Inhalt.
      for (final ev in familyCalendarEvents()) {
        expect(ev.type, isNot(EventCodec.privateType));
        expect(ev.content.toString(), isNot(contains('GEHEIM-ARZT')));
      }
      expect(familyCalendarEvents().map((e) => e.content['id']), <Object?>[shared.id]);

      // 2. Bens Bestand enthält ihn nicht.
      expect(await ben.store.get(secret.id), isNull);
      expect((await ben.store.all()).map((e) => e.title), <String>['Offen']);

      // 3. Der private Raum gehört nur Anna.
      final priv = server.privateRooms['@anna:fake.test']!;
      expect(priv.membership.keys, <String>['@anna:fake.test']);
      expect(priv.events.single.content['title'], 'GEHEIM-ARZT');
      expect(server.privateRooms.containsKey('@ben:fake.test'), isFalse);
    });

    test('erscheinen auf einem zweiten Gerät derselben Person', () async {
      final secret = await anna.createEvent(title: 'Privat', visibility: EventVisibility.private);
      await anna.sync.publishPending();
      final phone2 = await Peer.create(server, 'anna', 'pw1', familyRoomId: anna.gateway.familyRoom!.id);
      // Neues Gerät erhält Bestand über Wiederholung (Resync des privaten Raums im echten Gateway:
      // hier simuliert durch erneutes Senden vom ersten Gerät).
      await anna.gateway.publishPrivateEvent(secret);
      await pumpEventQueue();
      expect((await phone2.store.get(secret.id))!.title, 'Privat');
      phone2.dispose();
    });

    test('Mischbestand: nach beliebig vielen Aktionen nie ein privater Titel im Familienraum', () async {
      for (var i = 0; i < 10; i++) {
        final p = await anna.createEvent(title: 'PRIVAT-$i', visibility: EventVisibility.private);
        final s = await anna.createEvent(title: 'SHARED-$i');
        await anna.service.update(p.copyWith(title: 'PRIVAT-$i-neu'));
        await anna.service.changeVisibility(s.id, EventVisibility.private); // geteilt → privat
      }
      await anna.sync.publishPending();
      await pumpEventQueue();
      final familyDump = server.rooms[anna.gateway.familyRoom!.id]!.events.map((e) => e.content.toString()).join('\n');
      expect(familyDump, isNot(contains('PRIVAT-')));
      // Beim Wechsel geteilt→privat geht für alle nur eine Löschmarke ohne Inhalt hinaus.
      expect(familyDump, isNot(contains('SHARED-')), reason: 'Inhalt nicht mehr als Klartext im Verlauf des Familienraums');
    });

    test('Geteilt → privat nach Veröffentlichung: danach geht nur eine Löschmarke ohne Inhalt in den Familienraum', () async {
      final s = await anna.createEvent(title: 'WAR-GETEILT');
      await anna.sync.publishPending();
      final room = server.rooms[anna.gateway.familyRoom!.id]!;
      final before = room.events.where((e) => e.type == EventCodec.sharedType).length;
      final priv = await anna.service.changeVisibility(s.id, EventVisibility.private);
      await anna.sync.publishPending();
      await pumpEventQueue();
      final sharedEvents = room.events.where((e) => e.type == EventCodec.sharedType).toList();
      expect(sharedEvents.length, before + 1, reason: 'genau eine Löschmarke kommt hinzu');
      final tomb = sharedEvents.last.content;
      expect(tomb['deleted'], isTrue);
      expect(tomb['id'], s.id);
      expect(tomb['title'], isNot('WAR-GETEILT'));
      expect(tomb.toString(), isNot(contains('WAR-GETEILT')));
      expect(room.events.map((e) => e.content['id']), isNot(contains(priv.id)), reason: 'die private Kopie erreicht den Familienraum nie');
      // Ben zeigt den Termin nicht mehr an.
      expect((await ben.store.get(s.id))!.deleted, isTrue);
    });

    test('Fremder Absender im privaten Raum wird verworfen', () async {
      final forged = EventCodec.encodePrivate(
        (await anna.createEvent(title: 'x', visibility: EventVisibility.private)).copyWith(),
      )..['owner'] = '@ben:fake.test';
      final before = anna.sync.rejected;
      anna.gateway.injectSignal(PrivateEventSignal('@ben:fake.test', DateTime.utc(2026), forged));
      await pumpEventQueue();
      expect(anna.sync.rejected, before + 1);
    });
  });

  group('Fälschung und Müll', () {
    test('Ben kann einen Termin von Anna nicht überschreiben (owner ≠ Absender)', () async {
      final e = await anna.createEvent(title: 'Echt');
      await anna.sync.publishPending();
      await pumpEventQueue();
      final forged = EventCodec.encodeShared(e.copyWith(title: 'Gefälscht', version: 99));
      server.post(server.rooms[anna.gateway.familyRoom!.id]!, '@ben:fake.test', EventCodec.sharedType, forged);
      await pumpEventQueue();
      expect((await anna.store.get(e.id))!.title, 'Echt');
      expect((await ben.store.get(e.id))!.title, 'Echt');
      expect(anna.sync.rejected, greaterThan(0));
    });

    test('Ben kann Annas Termin nicht unter eigenem Namen mit derselben ID übernehmen', () async {
      final e = await anna.createEvent(title: 'Echt');
      await anna.sync.publishPending();
      await pumpEventQueue();
      final asBen = e.copyWith(version: 50, title: 'Übernommen');
      final content = EventCodec.encodeShared(asBen)..['owner'] = '@ben:fake.test';
      server.post(server.rooms[anna.gateway.familyRoom!.id]!, '@ben:fake.test', EventCodec.sharedType, content);
      await pumpEventQueue();
      expect((await anna.store.get(e.id))!.ownerId, anna.userId);
      expect((await anna.store.get(e.id))!.title, 'Echt');
    });

    test('Ungültige Inhalte werden verworfen, nichts bricht', () async {
      final room = server.rooms[anna.gateway.familyRoom!.id]!;
      for (final junk in <Map<String, Object?>>[
        <String, Object?>{},
        <String, Object?>{'v': 1, 'owner': '@ben:fake.test'},
        <String, Object?>{'title': 5},
      ]) {
        server.post(room, '@ben:fake.test', EventCodec.sharedType, junk);
      }
      server.post(room, '@ben:fake.test', EventCodec.rsvpType, <String, Object?>{'x': 1});
      await pumpEventQueue();
      expect(await anna.store.all(), isEmpty);
      expect(anna.sync.rejected, 4);
    });
  });

  group('Warteschlange (offline)', () {
    test('Termine bleiben erhalten und werden nachgereicht, in Änderungsreihenfolge', () async {
      anna.gateway.failPublishes = true;
      final a = await anna.createEvent(title: 'A');
      final b = await anna.createEvent(title: 'B', visibility: EventVisibility.private);
      await anna.sync.publishPending();
      expect((await anna.store.pendingPublish()).length, 2);
      expect(familyCalendarEvents(), isEmpty);
      anna.gateway.failPublishes = false;
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect(await anna.store.pendingPublish(), isEmpty);
      expect((await ben.store.get(a.id))!.title, 'A');
      expect(await ben.store.get(b.id), isNull);
    });

    test('Server nicht erreichbar → nichts geht verloren', () async {
      final e = await anna.createEvent();
      server.reachable = false;
      await anna.sync.publishPending();
      expect(await anna.store.pendingPublish(), <CalendarEvent>[e]);
      server.reachable = true;
      await anna.sync.publishPending();
      expect(await anna.store.pendingPublish(), isEmpty);
    });
  });

  group('Zusagen', () {
    test('Ben sagt zu; Anna sieht es; Offline-Antwort wird nachgereicht', () async {
      final e = await anna.createEvent();
      await anna.sync.publishPending();
      await pumpEventQueue();
      ben.gateway.failPublishes = false;
      server.reachable = false;
      await ben.sync.respond(e.id, RsvpStatus.maybe);
      await ben.sync.publishPending();
      expect((await ben.store.pendingRsvps(ben.userId)), hasLength(1));
      server.reachable = true;
      await ben.sync.publishPending();
      await pumpEventQueue();
      expect((await anna.store.rsvps())[e.id]!['@ben:fake.test'], RsvpStatus.maybe);
      expect(await ben.store.pendingRsvps(ben.userId), isEmpty);
    });

    test('verspätetes Echo einer älteren Antwort überschreibt die neuere nicht', () async {
      final e = await anna.createEvent();
      await anna.sync.publishPending();
      await anna.sync.respond(e.id, RsvpStatus.accepted);
      await anna.sync.publishPending();
      await anna.sync.respond(e.id, RsvpStatus.declined);
      // Echo der ersten Antwort trifft nach der zweiten erneut ein (Server-Zeit deutlich später):
      anna.gateway.injectSignal(RsvpSignal(
        '@anna:fake.test',
        DateTime.utc(2030),
        EventCodec.encodeRsvp(e.id, RsvpStatus.accepted, DateTime.utc(2026, 3, 20)),
      ));
      await pumpEventQueue();
      expect((await anna.store.rsvps())[e.id]!['@anna:fake.test'], RsvpStatus.declined);
    });

    test('die neuere Zusage gewinnt, auch bei umgekehrter Zustellung', () async {
      final e = await anna.createEvent();
      final t = DateTime.utc(2026, 11, 1);
      await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.declined, t.add(const Duration(minutes: 5)));
      await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.accepted, t);
      expect((await anna.store.rsvps())[e.id]!['@ben:fake.test'], RsvpStatus.declined);
    });
  });

  group('onChanged nur bei wirksamer Änderung (#131)', () {
    late int changed;

    setUp(() {
      changed = 0;
      ben.sync.onChanged = () => changed++;
    });

    Map<String, Object?> sentContent(String id) =>
        familyCalendarEvents().lastWhere((e) => e.content['id'] == id).content;

    test('neuer und geänderter Termin melden eine Änderung, Duplikat und ältere Fassung nicht', () async {
      final e = await anna.createEvent(title: 'Alt');
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect(changed, 1, reason: 'neu (insert)');
      final v1 = Map<String, Object?>.of(sentContent(e.id));

      ben.gateway.injectSignal(SharedEventSignal(anna.userId, DateTime.utc(2030), v1));
      await pumpEventQueue();
      expect(changed, 1, reason: 'Duplikat');

      await anna.service.update(e.copyWith(title: 'Neu'));
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect(changed, 2, reason: 'neue Fassung (replace)');

      ben.gateway.injectSignal(SharedEventSignal(anna.userId, DateTime.utc(2030), v1));
      await pumpEventQueue();
      expect(changed, 2, reason: 'ältere Fassung (nur Verlauf)');
      expect((await ben.store.get(e.id))!.title, 'Neu');
    });

    test('abgelehnter Besitzer meldet keine Änderung', () async {
      final e = await anna.createEvent(title: 'Annas');
      await anna.sync.publishPending();
      await pumpEventQueue();
      expect(changed, 1);
      // Cara gibt dieselbe Termin-ID mit höherer Version als eigenen Termin aus.
      final forged = EventCodec.encodeStored(e.copyWith(version: e.version + 5, title: 'Fälschung'));
      ben.gateway.injectSignal(SharedEventSignal('@cara:fake.test', DateTime.utc(2030), forged));
      await pumpEventQueue();
      expect(changed, 1);
      expect((await ben.store.get(e.id))!.title, 'Annas');
    });

    test('Zusagen: neu und neuer melden eine Änderung, gleicher und älterer Zeitstempel nicht', () async {
      final e = await anna.createEvent();
      await anna.sync.publishPending();
      await pumpEventQueue();
      changed = 0;
      RsvpSignal rsvp(RsvpStatus s, DateTime t) =>
          RsvpSignal(anna.userId, DateTime.utc(2030), EventCodec.encodeRsvp(e.id, s, t));
      final t1 = DateTime.utc(2026, 11, 1, 10);

      ben.gateway.injectSignal(rsvp(RsvpStatus.accepted, t1));
      await pumpEventQueue();
      expect(changed, 1, reason: 'neu');
      ben.gateway.injectSignal(rsvp(RsvpStatus.accepted, t1));
      await pumpEventQueue();
      expect(changed, 1, reason: 'gleicher Zeitstempel');
      ben.gateway.injectSignal(rsvp(RsvpStatus.declined, t1.subtract(const Duration(minutes: 1))));
      await pumpEventQueue();
      expect(changed, 1, reason: 'älter');
      ben.gateway.injectSignal(rsvp(RsvpStatus.declined, t1.add(const Duration(minutes: 1))));
      await pumpEventQueue();
      expect(changed, 2, reason: 'neuer');
      expect((await ben.store.rsvps())[e.id]![anna.userId], RsvpStatus.declined);
    });

    test('putRsvp meldet, ob geschrieben wurde', () async {
      final e = await anna.createEvent();
      final t = DateTime.utc(2026, 11, 1);
      expect(await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.accepted, t), isTrue);
      expect(await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.declined, t), isFalse);
      expect(await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.declined, t.subtract(const Duration(seconds: 1))), isFalse);
      expect(await anna.store.putRsvp(e.id, '@ben:fake.test', RsvpStatus.declined, t.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('Resync für neue Mitglieder', () {
    test('Anna sendet beim Beitritt von Cara ihre aktuellen geteilten Termine erneut', () async {
      final live = await anna.createEvent(title: 'Bleibt');
      final gone = await anna.createEvent(title: 'Weg');
      await anna.sync.publishPending();
      await anna.service.delete(gone.id);
      await anna.createEvent(title: 'Privat', visibility: EventVisibility.private);
      await anna.sync.publishPending();
      final before = familyCalendarEvents().length;

      final room = anna.gateway.familyRoom!;
      server.addMember(room, '@cara:fake.test');
      final cara = await Peer.create(server, 'cara', 'pw3', familyRoomId: room.id);
      // Anna erhält das Beitritts-Signal beim Hinzufügen; nach Caras Start erneut auslösen:
      await anna.sync.resyncOwnShared();
      await pumpEventQueue();

      expect(familyCalendarEvents().length, greaterThan(before));
      expect((await cara.store.get(live.id))!.title, 'Bleibt');
      expect(await cara.store.get(gone.id), isNull, reason: 'Gelöschtes wird nicht erneut gesendet');
      expect((await cara.store.all()).every((e) => e.isShared), isTrue, reason: 'Privates nie');
      cara.dispose();
    });

    test('Resync ist idempotent für bestehende Mitglieder', () async {
      final e = await anna.createEvent();
      await anna.sync.publishPending();
      await anna.sync.resyncOwnShared();
      await anna.sync.resyncOwnShared();
      await pumpEventQueue();
      expect(await ben.store.all(), hasLength(1));
      expect((await ben.store.get(e.id))!.version, 1);
    });
  });

  test('ohne Sitzung wird nichts gesendet', () async {
    final e = await anna.createEvent();
    await anna.gateway.logout();
    await anna.sync.publishPending();
    expect(await anna.store.pendingPublish(), <CalendarEvent>[e]);
    expect(familyCalendarEvents(), isEmpty);
    expect(anna.gateway.session, SessionState.loggedOut);
  });

  group('Review-Funde Phase 3', () {
    test('K4: gleichzeitig eintreffende Fassungen enden immer bei der neuesten (beide Reihenfolgen)', () async {
      for (final reversed in <bool>[false, true]) {
        final id = reversed ? kId2 : kId1;
        final v1 = ev(owner: '@ben:fake.test', id: id, version: 1, title: 'alt');
        final v2 = ev(owner: '@ben:fake.test', id: id, version: 2, title: 'neu');
        final sigs = <EventCodecSignal>[
          EventCodecSignal(v1),
          EventCodecSignal(v2),
          EventCodecSignal(v1),
        ];
        final order = reversed ? sigs.reversed.toList() : sigs;
        for (final s in order) {
          anna.gateway.injectSignal(SharedEventSignal('@ben:fake.test', DateTime.utc(2026), EventCodec.encodeShared(s.event)));
        }
        await anna.sync.idle();
        await pumpEventQueue();
        await anna.sync.idle();
        expect((await anna.store.get(id))!.title, 'neu', reason: 'reversed=$reversed');
      }
    });

    test('K3: privat → geteilt konvergiert auf dem zweiten eigenen Gerät', () async {
      final phone2 = await Peer.create(server, 'anna', 'pw1', familyRoomId: anna.gateway.familyRoom!.id);
      final e = await anna.createEvent(title: 'Später geteilt', visibility: EventVisibility.private);
      await anna.sync.publishPending();
      await pumpEventQueue();
      await phone2.sync.idle();
      expect((await phone2.store.get(e.id))!.visibility, EventVisibility.private);
      await anna.service.changeVisibility(e.id, EventVisibility.shared);
      await anna.sync.publishPending();
      await pumpEventQueue();
      await phone2.sync.idle();
      final got = (await phone2.store.get(e.id))!;
      expect(got.visibility, EventVisibility.shared);
      expect(got.version, 2);
      expect((await ben.store.get(e.id))!.title, 'Später geteilt');
      phone2.dispose();
    });

    test('K5: Resync übersteht einen Ausfall (Vormerken statt einmaligem Senden)', () async {
      final e = await anna.createEvent(title: 'Bleibt');
      await anna.sync.publishPending();
      anna.gateway.failPublishes = true;
      final room = anna.gateway.familyRoom!;
      server.addMember(room, '@cara:fake.test');
      await pumpEventQueue();
      await anna.sync.idle();
      expect(await anna.store.pendingPublish(), isNotEmpty, reason: 'Neuversand ist vorgemerkt');
      anna.gateway.failPublishes = false;
      final cara = await Peer.create(server, 'cara', 'pw3', familyRoomId: room.id);
      await anna.sync.publishPending();
      await pumpEventQueue();
      await cara.sync.idle();
      expect((await cara.store.get(e.id))!.title, 'Bleibt');
      cara.dispose();
    });

    test('K6: Serverfehler lassen den Termin in der Warteschlange; lokale Codec-Fehler nicht', () async {
      final e = await anna.createEvent(title: 'Wichtig');
      anna.gateway.failPublishes = true;
      await anna.sync.publishPending();
      expect((await anna.store.pendingPublish()).single.id, e.id);
      anna.gateway.failPublishes = false;
      await anna.sync.publishPending();
      expect(await anna.store.pendingPublish(), isEmpty);
    });

    test('S2: Antworten auf unbekannte oder private Termine werden verworfen', () async {
      final priv = await anna.createEvent(title: 'privat', visibility: EventVisibility.private);
      final before = anna.sync.rejected;
      for (final id in <String>[kId2, priv.id]) {
        anna.gateway.injectSignal(RsvpSignal('@ben:fake.test', DateTime.utc(2026), EventCodec.encodeRsvp(id, RsvpStatus.accepted, DateTime.utc(2026))));
      }
      await anna.sync.idle();
      expect(anna.sync.rejected, before + 2);
      expect(await anna.store.rsvps(), isEmpty);
    });

    test('S3: Titel mit Steuer-/Bidi-Zeichen werden verworfen', () async {
      final json = EventCodec.encodeStored(ev(owner: '@ben:fake.test'))..['title'] = 'Normal\u202Eevil';
      anna.gateway.injectSignal(SharedEventSignal('@ben:fake.test', DateTime.utc(2026), json));
      await anna.sync.idle();
      expect(await anna.store.all(), isEmpty);
    });
  });
}

/// Hilfstyp, um Reihenfolgen übersichtlich zu bauen.
class EventCodecSignal {
  EventCodecSignal(this.event);
  final CalendarEvent event;
}
