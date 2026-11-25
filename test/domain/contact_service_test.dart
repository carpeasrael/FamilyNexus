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

  group('onChanged (K3a-1)', () {
    late int calls;
    setUp(() {
      calls = 0;
      svc.onChanged = () => calls++;
    });

    test('nach jeder schreibenden Methode genau einmal', () async {
      await svc.setEnabled(true);
      expect(calls, 1);
      await svc.addOutgoing(carla);
      expect(calls, 2);
      await svc.markAccepted(carla);
      expect(calls, 3);
      await svc.rename(carla, 'C');
      expect(calls, 4);
      await svc.block(ben);
      expect(calls, 5);
      await svc.unblock(ben);
      expect(calls, 6);
      await svc.remove(carla);
      expect(calls, 7);
      await svc.addGroup('!g:example.org');
      expect(calls, 8);
      await svc.removeGroup('!g:example.org');
      expect(calls, 9);
    });

    test('nicht ohne Wirkung: Gleiches einstellen, abgelehnte Änderung, bereits Blockiertes', () async {
      await svc.setEnabled(false);
      expect(calls, 0);
      await expectLater(svc.addOutgoing('kein-konto'), fails(ContactError.invalid));
      await svc.block(ben);
      calls = 0;
      await svc.block(ben);
      await expectLater(svc.addOutgoing(ben), fails(ContactError.notAllowed));
      expect(calls, 0);
    });

    test('angenommener Empfang meldet, abgelehnter (gleich, älter) nicht', () async {
      final r = Contact(id: carla, state: ContactState.accepted, version: 3, updatedAt: now);
      expect(await svc.applyIncoming(r), isTrue);
      expect(calls, 1);
      expect(await svc.applyIncoming(r), isFalse);
      expect(await svc.applyIncoming(Contact(id: carla, state: ContactState.outgoing, version: 2, updatedAt: now)), isFalse);
      expect(calls, 1);
    });

    test('restamp meldet nicht (nur der Zeitstempel ändert sich)', () async {
      await svc.addOutgoing(carla);
      calls = 0;
      now = now.add(const Duration(days: 3));
      final fresh = await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false);
      expect(fresh, isNotNull);
      expect(fresh!.updatedAt, now);
      expect(calls, 0);
    });

    test('der Rückruf läuft nach dem Speichern: er sieht den neuen Stand', () async {
      Object? seen;
      svc.onChanged = () => seen = 'x';
      await svc.addOutgoing(carla);
      expect(seen, 'x');
      expect(await svc.contact(carla), isNotNull);
      Contact? atCall;
      svc.onChanged = () => store.get(ContactKind.contact, ben).then((v) => atCall = v as Contact?);
      await svc.block(ben);
      await Future<void>.delayed(Duration.zero);
      expect(atCall?.state, ContactState.blocked);
    });
  });

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

  // --- Lücken der Mutationsprobe (K2b) ---

  group('Randfälle', () {
    test('Blockieren eines bestehenden Kontakts geht auch bei voller Kontaktliste; Aufheben schafft Platz in der Blockgrenze', () async {
      for (var i = 0; i < ContactLimits.maxContacts; i++) {
        await store.put(Contact(id: user(i), state: ContactState.accepted, version: 1, updatedAt: now));
      }
      final b = await svc.block(user(3));
      expect(b.state, ContactState.blocked);
      await svc.unblock(user(3));
      // 200 Blockierte, einer wird aufgehoben: der Platz ist frei (Löschmarken zählen nicht).
      final s2 = ContactService(store: MemoryContactStore(), myUserId: me, clock: () => now);
      for (var i = 0; i < BlockedUsers.maxEntries; i++) {
        await s2.block(user(i));
      }
      await expectLater(s2.block(user(900)), fails(ContactError.limit));
      await s2.unblock(user(0));
      expect((await s2.block(user(900))).state, ContactState.blocked);
    });

    test('markAccepted ohne Raum behält den bekannten Raum', () async {
      await store.put(Contact(id: carla, state: ContactState.outgoing, room: '!r:example.org', version: 1, updatedAt: now));
      final a = await svc.markAccepted(carla);
      expect(a.room, '!r:example.org');
    });

    test('Kennung wird kanonisiert gesucht (Servername in Großschreibung)', () async {
      await svc.addOutgoing(carla);
      expect((await svc.rename('@carla:EXAMPLE.org', 'C')).nick, 'C');
      await svc.markAccepted('@carla:EXAMPLE.org');
      await svc.remove('@carla:EXAMPLE.ORG');
      expect(await svc.contacts(), isEmpty);
    });

    test('Versionsüberlauf: bei maxVersion ist keine weitere Änderung möglich (limit)', () async {
      await store.put(Contact(id: carla, state: ContactState.outgoing, version: ContactLimits.maxVersion, updatedAt: now));
      await expectLater(svc.markAccepted(carla), fails(ContactError.limit));
      await expectLater(svc.rename(carla, 'x'), fails(ContactError.limit));
    });
  });

  group('Grenzen beim Empfang', () {
    Contact inc(String id, {int v = 2, ContactState s = ContactState.accepted, bool del = false}) =>
        Contact(id: id, state: s, version: v, updatedAt: now, deleted: del);

    test('Zeilengrenze 2000: eine neue Kennung wird abgelehnt, eine bestehende angenommen', () async {
      for (var i = 0; i < ContactLimits.maxRecords; i++) {
        await store.put(Contact(id: user(i), state: ContactState.accepted, version: 1, updatedAt: now, deleted: i >= 100), publishedVersion: 0);
      }
      expect(await svc.applyIncoming(inc(carla, v: 1)), isFalse, reason: 'neue Zeile, alle Löschmarken unveröffentlicht');
      expect(await svc.applyIncoming(inc(user(1), v: 2)), isTrue, reason: 'bestehende Kennung');
    });

    test('Reaktivierung einer Löschmarke am Limit 500 wird abgelehnt', () async {
      for (var i = 0; i < ContactLimits.maxContacts; i++) {
        await store.put(Contact(id: user(i), state: ContactState.accepted, version: 1, updatedAt: now));
      }
      await store.put(Contact(id: carla, state: ContactState.accepted, version: 2, updatedAt: now, deleted: true));
      expect(await svc.applyIncoming(inc(carla, v: 3)), isFalse);
      expect(await svc.applyIncoming(inc(user(0), v: 2, s: ContactState.outgoing)), isTrue, reason: 'bestehender aktiver Kontakt ändert sich');
    });

    test('Blockgrenze 200 beim Empfang: neue blockierte Zeile und Übergang aktiv → blockiert werden abgelehnt', () async {
      for (var i = 0; i < BlockedUsers.maxEntries; i++) {
        await store.put(Contact(id: user(i), state: ContactState.blocked, version: 1, updatedAt: now));
      }
      await store.put(Contact(id: carla, state: ContactState.accepted, version: 1, updatedAt: now));
      expect(await svc.applyIncoming(inc(ben, s: ContactState.blocked)), isFalse, reason: 'neue blockierte Zeile');
      expect(await svc.applyIncoming(inc(carla, s: ContactState.blocked)), isFalse, reason: 'Übergang aktiv → blockiert');
      expect(await svc.applyIncoming(inc(user(0), v: 2, s: ContactState.blocked)), isTrue, reason: 'bleibt blockiert');
    });

    test('Gruppengrenze 50 beim Empfang', () async {
      for (var i = 0; i < ContactLimits.maxGroups; i++) {
        await store.put(GroupRecord(id: '!g$i:example.org', version: 1, updatedAt: now));
      }
      expect(await svc.applyIncoming(GroupRecord(id: '!neu:example.org', version: 1, updatedAt: now)), isFalse);
      expect(await svc.applyIncoming(GroupRecord(id: '!g1:example.org', version: 2, updatedAt: now)), isTrue);
    });

    test('beim Aufräumen bleiben genau 200 veröffentlichte Löschmarken', () async {
      for (var i = 0; i < ContactLimits.maxRecords; i++) {
        await store.put(
          Contact(id: user(i), state: ContactState.accepted, version: 2, updatedAt: now.subtract(Duration(minutes: i)), deleted: true),
          publishedVersion: 2,
        );
      }
      await svc.addOutgoing(carla);
      expect((await store.all()).length, ContactLimits.keepTombstones + 1);
    });
  });

  group('restamp: Randfälle und alle Arten', () {
    test('genau ein Tag Abweichung bleibt, eine Millisekunde mehr wird neu gestempelt', () async {
      final c = await svc.addOutgoing(carla);
      now = now.add(const Duration(days: 1));
      expect((await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false))!.updatedAt, c.updatedAt);
      now = now.add(const Duration(milliseconds: 1));
      expect((await svc.restamp(ContactKind.contact, carla, expectedVersion: 1, expectedDeleted: false))!.updatedAt, now);
    });

    test('Gruppen und die Einstellung werden ebenfalls neu gestempelt', () async {
      await svc.addGroup('!g:example.org');
      await svc.setEnabled(true);
      now = now.add(const Duration(days: 3));
      final g = await svc.restamp(ContactKind.group, '!g:example.org', expectedVersion: 1, expectedDeleted: false);
      final p = await svc.restamp(ContactKind.prefs, 'prefs', expectedVersion: 1, expectedDeleted: false);
      expect(g!.updatedAt, now);
      expect(p!.updatedAt, now);
      expect((p as ContactPrefs).enabled, isTrue);
    });
  });
}
