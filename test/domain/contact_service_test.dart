import 'package:family_nexus/domain/contact_service.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/moderation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_contact_store.dart';

/// #119, K2b (E-114): Regeln, Zustände, Grenzen und Empfang des Kontaktdienstes.
void main() {
  const me = '@ich:hs.example';
  const carla = '@carla:example.org';
  const ben = '@ben:example.org';
  var now = DateTime.utc(2026, 11, 25, 10);
  late MemoryContactStore store;
  late ContactService svc;

  setUp(() {
    now = DateTime.utc(2026, 11, 25, 10);
    store = MemoryContactStore();
    svc = ContactService(store: store, myUserId: me, clock: () => now);
  });

  Matcher fails(ContactError e) => throwsA(isA<ContactException>().having((x) => x.error, 'error', e));

  String user(int i) => '@u${i.toString().padLeft(4, '0')}:example.org';

  group('Einstellung', () {
    test('Standard aus; einschalten und ausschalten erhöht die Version, Gleiches tut nichts', () async {
      expect(await svc.isEnabled(), isFalse);
      await svc.setEnabled(false);
      expect(await store.all(), isEmpty, reason: 'Aus ist der Standard, nichts gespeichert');
      await svc.setEnabled(true);
      expect(await svc.isEnabled(), isTrue);
      await svc.setEnabled(true);
      expect((await store.get(ContactKind.prefs, 'prefs'))!.version, 1);
      await svc.setEnabled(false);
      expect(await svc.isEnabled(), isFalse);
      expect((await store.get(ContactKind.prefs, 'prefs'))!.version, 2);
    });
  });

  group('Ausgehende Kontakte', () {
    test('addOutgoing: kanonische ID, Version 1, Zeit, zum Senden vorgemerkt', () async {
      final c = await svc.addOutgoing('https://matrix.to/#/%40carla%3AExample.org', nick: 'Carla');
      expect(c.id, carla);
      expect(c.state, ContactState.outgoing);
      expect((c.version, c.updatedAt, c.nick), (1, now, 'Carla'));
      expect(await store.pending(), <ContactRecord>[c]);
      expect(await svc.contacts(), <Contact>[c]);
    });

    test('ungültige Eingabe, eigenes Konto, doppelt aktiv, blockiert', () async {
      await expectLater(svc.addOutgoing('keine id'), fails(ContactError.invalid));
      await expectLater(svc.addOutgoing(me), fails(ContactError.notAllowed));
      await svc.addOutgoing(carla);
      await expectLater(svc.addOutgoing(carla), fails(ContactError.duplicate));
      await svc.markAccepted(carla, room: '!r:example.org');
      await expectLater(svc.addOutgoing(carla), fails(ContactError.duplicate));
      await svc.block(ben);
      await expectLater(svc.addOutgoing(ben), fails(ContactError.notAllowed));
    });

    test('ungültiger Spitzname wird abgelehnt', () async {
      await expectLater(svc.addOutgoing(carla, nick: 'x' * 41), fails(ContactError.invalid));
      await expectLater(svc.addOutgoing(carla, nick: 'a\u202eb'), fails(ContactError.invalid));
      expect(await store.all(), isEmpty);
    });

    test('Wiederhinzufügen nach Entfernen: höhere Version, der bekannte Raum bleibt', () async {
      await svc.addOutgoing(carla);
      await svc.markAccepted(carla, room: '!r:example.org');
      await svc.remove(carla);
      expect(await svc.contacts(), isEmpty);
      final again = await svc.addOutgoing(carla);
      expect(again.version, 4);
      expect(again.room, '!r:example.org');
      expect(again.state, ContactState.outgoing);
    });
  });

  group('Übergänge', () {
    test('markAccepted nur aus outgoing; bei blocked, bestätigt oder fehlend abgelehnt', () async {
      await expectLater(svc.markAccepted(carla), fails(ContactError.notFound));
      await svc.addOutgoing(carla);
      final a = await svc.markAccepted(carla, room: '!r:example.org');
      expect((a.state, a.room, a.version), (ContactState.accepted, '!r:example.org', 2));
      await expectLater(svc.markAccepted(carla), fails(ContactError.notAllowed));
      await svc.block(ben);
      await expectLater(svc.markAccepted(ben), fails(ContactError.notAllowed));
      await expectLater(svc.markAccepted('kaputt'), fails(ContactError.notFound));
    });

    test('block auch für Unbekannte (ohne Raum); eigenes Konto nie; zweimal ist idempotent; bestehender Kontakt behält Namen und Raum', () async {
      final b = await svc.block(ben);
      expect((b.state, b.room, b.version), (ContactState.blocked, null, 1));
      expect(await svc.block(ben), b, reason: 'bereits blockiert: nichts ändert sich');
      await expectLater(svc.block(me), fails(ContactError.notAllowed));
      await svc.addOutgoing(carla, nick: 'Carla');
      await svc.markAccepted(carla, room: '!r:example.org');
      final c = await svc.block(carla);
      expect((c.nick, c.room, c.state), ('Carla', '!r:example.org', ContactState.blocked));
    });

    test('unblock wird zur Löschmarke; nur bei blockiert; remove nur bei outgoing/accepted; rename nicht bei blockiert', () async {
      await svc.block(ben);
      await svc.unblock(ben);
      expect(await svc.contacts(), isEmpty);
      expect((await svc.contact(ben)), isNotNull);
      expect((await svc.contact(ben))!.deleted, isTrue);
      await expectLater(svc.unblock(ben), fails(ContactError.notFound));
      await svc.addOutgoing(carla);
      await expectLater(svc.unblock(carla), fails(ContactError.notAllowed));
      await svc.block(ben);
      await expectLater(svc.remove(ben), fails(ContactError.notAllowed));
      await expectLater(svc.rename(ben, 'x'), fails(ContactError.notAllowed));
      final r = await svc.rename(carla, 'Carla V.');
      expect(r.nick, 'Carla V.');
      await expectLater(svc.rename(carla, 'x' * 41), fails(ContactError.invalid));
      await svc.remove(carla);
      await expectLater(svc.remove(carla), fails(ContactError.notFound));
    });
  });

  group('Gruppen', () {
    test('anlegen, doppelt, entfernen, ungültige Raum-ID', () async {
      final g = await svc.addGroup('!g:example.org');
      expect(g.version, 1);
      expect(await svc.groups(), <GroupRecord>[g]);
      await expectLater(svc.addGroup('!g:example.org'), fails(ContactError.duplicate));
      await expectLater(svc.addGroup('keine raum id'), fails(ContactError.invalid));
      await svc.removeGroup('!g:example.org');
      expect(await svc.groups(), isEmpty);
      await expectLater(svc.removeGroup('!g:example.org'), fails(ContactError.notFound));
      expect((await svc.addGroup('!g:example.org')).version, 3);
    });
  });

  group('Grenzen', () {
    test('höchstens 500 aktive Kontakte (blockierte zählen mit), Löschmarken nicht', () async {
      for (var i = 0; i < ContactLimits.maxContacts; i++) {
        await store.put(Contact(id: user(i), state: ContactState.accepted, version: 1, updatedAt: now));
      }
      await expectLater(svc.addOutgoing(carla), fails(ContactError.limit));
      await expectLater(svc.block(ben), fails(ContactError.limit));
      await svc.remove(user(0));
      await svc.addOutgoing(carla);
      expect((await svc.contacts()).length, ContactLimits.maxContacts);
    });

    test('höchstens 50 Gruppen', () async {
      for (var i = 0; i < ContactLimits.maxGroups; i++) {
        await store.put(GroupRecord(id: '!g$i:example.org', version: 1, updatedAt: now));
      }
      await expectLater(svc.addGroup('!neu:example.org'), fails(ContactError.limit));
    });

    test('höchstens so viele blockierte Datensätze, wie die Blockierliste aufnimmt', () async {
      for (var i = 0; i < BlockedUsers.maxEntries; i++) {
        await store.put(Contact(id: user(i), state: ContactState.blocked, version: 1, updatedAt: now));
      }
      await expectLater(svc.block(ben), fails(ContactError.limit));
      expect(ContactLimits.maxContacts, greaterThan(BlockedUsers.maxEntries));
    });

    test('alle Zeilen einschließlich Löschmarken sind begrenzt; veröffentlichte Löschmarken werden vorher geräumt, unveröffentlichte nie', () async {
      for (var i = 0; i < ContactLimits.maxRecords; i++) {
        await store.put(
          Contact(id: user(i), state: ContactState.accepted, version: 2, updatedAt: now.subtract(Duration(minutes: i)), deleted: true),
          publishedVersion: 0,
        );
      }
      // Alles unveröffentlichte Löschmarken: eine neue Zeile findet keinen Platz, nichts geht verloren.
      await expectLater(svc.addOutgoing(carla), fails(ContactError.limit));
      expect((await store.all()).length, ContactLimits.maxRecords);
      // Veröffentlicht: es wird geräumt, die neue Zeile passt.
      for (final r in await store.all()) {
        await store.markPublished(ContactKind.contact, r.id, 2);
      }
      await svc.addOutgoing(carla);
      expect((await store.all()).length, lessThanOrEqualTo(ContactLimits.keepTombstones + 1));
      expect(await svc.contact(carla), isNotNull);
    });
  });

  group('Empfang (applyIncoming)', () {
    Contact inc({int v = 2, ContactState s = ContactState.accepted, String id = carla, DateTime? at, bool del = false}) =>
        Contact(id: id, state: s, nick: 'C', version: v, updatedAt: at ?? now, deleted: del);

    test('neue Zeile: gespeichert und als gesendet vermerkt (nichts zum Senden)', () async {
      expect(await svc.applyIncoming(inc()), isTrue);
      expect(await svc.contact(carla), inc());
      expect(await store.pending(), isEmpty);
    });

    test('ältere, gleiche oder unterlegene Fassung ändert nichts; neuere ersetzt', () async {
      await svc.applyIncoming(inc(v: 5));
      expect(await svc.applyIncoming(inc(v: 4)), isFalse);
      expect(await svc.applyIncoming(inc(v: 5)), isFalse);
      expect(await svc.applyIncoming(inc(v: 5, at: now.subtract(const Duration(seconds: 1)))), isFalse);
      expect(await svc.applyIncoming(inc(v: 6, s: ContactState.blocked)), isTrue);
      expect((await svc.contact(carla))!.state, ContactState.blocked);
    });

    test('Versionssprung über 1000 wird verworfen, ein unbekannter Schlüssel nimmt jede gültige Version', () async {
      await svc.applyIncoming(inc(v: 5));
      expect(await svc.applyIncoming(inc(v: 5 + ContactLimits.maxVersionStep + 1)), isFalse);
      expect(await svc.applyIncoming(inc(v: 5 + ContactLimits.maxVersionStep)), isTrue);
      expect(await svc.applyIncoming(inc(v: 900000, id: ben)), isTrue);
    });

    test('ungültiger Datensatz wird verworfen; Grenzen gelten auch beim Empfang', () async {
      expect(await svc.applyIncoming(inc(v: 0)), isFalse);
      for (var i = 0; i < ContactLimits.maxContacts; i++) {
        await store.put(Contact(id: user(i), state: ContactState.accepted, version: 1, updatedAt: now));
      }
      expect(await svc.applyIncoming(inc(id: ben)), isFalse, reason: 'Kontaktgrenze');
      expect(await svc.applyIncoming(inc(id: user(1), v: 2, del: true)), isTrue, reason: 'eine Löschmarke ist immer annehmbar');
    });

    test('Löschmarke verdrängt die aktive Fassung; eine alte aktive Fassung belebt sie nicht', () async {
      await svc.applyIncoming(inc(v: 2));
      await svc.applyIncoming(inc(v: 3, del: true));
      expect(await svc.contacts(), isEmpty);
      expect(await svc.applyIncoming(inc(v: 2)), isFalse);
      expect(await svc.contacts(), isEmpty);
    });

    test('Einstellung und Gruppen werden wie Kontakte angenommen', () async {
      expect(await svc.applyIncoming(ContactPrefs(enabled: true, version: 3, updatedAt: now)), isTrue);
      expect(await svc.isEnabled(), isTrue);
      expect(await svc.applyIncoming(GroupRecord(id: '!g:example.org', version: 1, updatedAt: now)), isTrue);
      expect(await svc.groups(), hasLength(1));
    });
  });

  group('Neustempeln (restamp)', () {
    test('ein lange wartender eigener Datensatz bekommt bei gleicher Version die aktuelle Zeit; ein frischer bleibt', () async {
      final c = await svc.addOutgoing(carla);
      now = now.add(const Duration(hours: 23));
      expect((await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false))!.updatedAt, c.updatedAt, reason: 'unter einem Tag: unverändert');
      now = now.add(const Duration(hours: 2));
      final r = await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false);
      expect((r!.version, r.updatedAt), (1, now));
      expect(await store.pending(), isNotEmpty, reason: 'bleibt in der Warteschlange');
    });

    test('Empfänger lehnt den alten Zeitstempel ab, nach dem Neustempeln nimmt er ihn an', () async {
      final c = await svc.addOutgoing(carla);
      now = now.add(const Duration(days: 3));
      expect(ContactCodec.decode(ContactCodec.encode(c), sender: me, me: me, serverTime: now), isNull);
      final r = await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false);
      expect(ContactCodec.decode(ContactCodec.encode(r!), sender: me, me: me, serverTime: now), isNotNull);
    });

    test('zwischenzeitlich geändert oder fehlend: null', () async {
      await svc.addOutgoing(carla);
      await svc.markAccepted(carla);
      expect(await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false), isNull);
      expect(await svc.restamp(ContactKind.contact, carla, expectedVersion: 2, expectedDeleted: true), isNull);
      expect(await svc.restamp(ContactKind.contact, ben, expectedVersion: 1, expectedDeleted: false), isNull);
    });
  });
}
