import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/conflict.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';
import '../support/memory_event_store.dart';

/// #431, E-112: Annahme fremder Fassungen (Moderatoren) im Dienst.
void main() {
  setUpAll(TimeZones.ensureInitialized);

  const mod = '@cara:fake.test';
  const mod2 = '@dora:fake.test';
  const me = '@ben:fake.test';

  late MemoryEventStore store;
  late CalendarService svc;
  late Map<String, Role?> roles;
  var now = DateTime.utc(2026, 3, 10, 12);
  final stamp = DateTime.utc(2026, 3, 10, 11); // Serverzeit der Fassungen

  setUp(() {
    store = MemoryEventStore();
    now = DateTime.utc(2026, 3, 10, 12);
    roles = <String, Role?>{mod: Role.moderator, mod2: Role.moderator};
    svc = CalendarService(store: store, myUserId: me, clock: () => now, roleOf: (id) => roles[id]);
  });

  CalendarEvent byMod(int v, {String editor = mod, String title = 'M', String id = kId1, DateTime? at}) =>
      ev(id: id, version: v, title: title, updatedAt: at ?? stamp).copyWith(editorId: editor);

  Future<Resolution> from(CalendarEvent e, {String sender = mod, DateTime? serverTime}) =>
      svc.applyFrom(e, sender: sender, serverTime: serverTime ?? stamp);

  Future<void> base({int version = 1}) async {
    expect(await from(ev(version: version, updatedAt: stamp), sender: kOwner), Resolution.insert);
  }

  group('Annahme', () {
    test('Moderatorfassung auf bekannter geteilter Basis ersetzt sie, Basis kommt in den Verlauf', () async {
      await base();
      expect(await from(byMod(2)), Resolution.replace);
      final cur = await store.get(kId1);
      expect(cur!.editorId, mod);
      expect(cur.ownerId, kOwner);
      expect((await store.history(kId1)).single.version, 1);
    });

    test('ohne Basis nie ein neuer Termin: gepuffert, nichts gespeichert', () async {
      expect(await from(byMod(2)), Resolution.deferred);
      expect(await store.get(kId1), isNull);
      expect(svc.deferredCount, 1);
    });

    test('Fassung des Besitzers legt weiter neue Termine an (Resync)', () async {
      expect(await from(byMod(2), sender: kOwner), Resolution.insert);
      expect((await store.get(kId1))!.editorId, mod);
    });

    test('Resync des Besitzers mit editor-Behauptung ist ein Duplikat', () async {
      await base();
      await from(byMod(2));
      expect(await from(byMod(2), sender: kOwner), Resolution.ignoreDuplicate);
    });
  });

  group('Absenderprüfung im Dienst (nicht nur im Codec)', () {
    test('editor != Absender, gelöscht, privat: rejectOwner, nichts gespeichert', () async {
      await base();
      expect(await from(byMod(2, editor: mod2)), Resolution.rejectOwner);
      expect(await from(ev(version: 2, updatedAt: stamp)), Resolution.rejectOwner);
      expect(await from(byMod(2).tombstone(stamp).copyWith(editorId: mod)), Resolution.rejectOwner);
      expect((await store.get(kId1))!.version, 1);
    });

    test('private Fassung eines Moderators auf geteilter Basis: rejectOwner (Dienst prüft selbst)', () async {
      await base();
      final priv = ev(version: 2, visibility: EventVisibility.private, updatedAt: stamp).copyWith(editorId: mod);
      expect(await from(priv), Resolution.rejectOwner);
      expect((await store.get(kId1))!.version, 1);
    });

    test('Basis gelöscht oder privat: rejectOwner', () async {
      await base();
      await from(ev(version: 1, updatedAt: stamp).tombstone(stamp), sender: kOwner);
      expect(await from(byMod(3)), Resolution.rejectOwner);
      expect(
        await from(byMod(2, id: kId2).copyWith(), sender: mod),
        Resolution.deferred,
      );
      await svc.applyFrom(ev(id: kId2, visibility: EventVisibility.private, updatedAt: stamp),
          sender: kOwner, serverTime: stamp);
      expect(await from(byMod(2, id: kId2)), Resolution.rejectOwner);
    });
  });

  group('Rolle', () {
    test('Mitglied oder unbekannt: gepuffert, nach Beförderung angenommen', () async {
      await base();
      roles[mod] = Role.member;
      expect(await from(byMod(2)), Resolution.deferred);
      roles[mod] = null;
      expect(await svc.retryDeferred(), isFalse);
      expect((await store.get(kId1))!.version, 1);
      roles[mod] = Role.moderator;
      expect(await svc.retryDeferred(), isTrue);
      expect((await store.get(kId1))!.editorId, mod);
      expect(svc.deferredCount, 0);
    });

    test('deferredRoleState ändert sich mit der Rolle der gepufferten Absender', () async {
      await base();
      roles[mod] = Role.member;
      await from(byMod(2));
      final a = svc.deferredRoleState;
      roles[mod] = Role.moderator;
      expect(svc.deferredRoleState, isNot(a));
    });

    test('Standard-roleOf kennt niemanden: Fremdfassung wird nie angenommen', () async {
      final plain = CalendarService(store: store, myUserId: me, clock: () => now);
      await plain.applyFrom(ev(updatedAt: stamp), sender: kOwner, serverTime: stamp);
      expect(await plain.applyFrom(byMod(2), sender: mod, serverTime: stamp), Resolution.deferred);
      expect((await store.get(kId1))!.version, 1);
    });
  });

  group('Zeit', () {
    test('updatedAt weiter als 2 Tage von der Serverzeit: rejectOwner', () async {
      await base();
      final far = byMod(2, at: stamp.add(const Duration(days: 3)));
      expect(await from(far), Resolution.rejectOwner);
      final near = byMod(2, at: stamp.add(const Duration(days: 1)));
      expect(await from(near), Resolution.replace);
    });

    test('updatedAt mehr als 2 Tage VOR der Serverzeit: rejectOwner (beide Richtungen)', () async {
      await base();
      expect(await from(byMod(2, at: stamp.subtract(const Duration(days: 3)))), Resolution.rejectOwner);
      expect(await from(byMod(2, at: stamp.subtract(const Duration(days: 1)))), Resolution.replace);
    });

    test('Serverzeit in der Zukunft oder fehlend: rejectOwner, kein Puffereintrag', () async {
      await base();
      final future = now.add(const Duration(days: 3));
      expect(await from(byMod(2, at: future), serverTime: future), Resolution.rejectOwner);
      expect(await svc.applyFrom(byMod(2), sender: mod, serverTime: null), Resolution.rejectOwner);
      expect(svc.deferredCount, 0);
    });
  });

  group('Versionsfenster', () {
    test('bis +20 angenommen, darüber gepuffert (auch 2147483647), nie angenommen', () async {
      await base();
      expect(await from(byMod(21)), Resolution.replace);
      expect(await from(byMod(42, editor: mod2), sender: mod2), Resolution.deferred);
      expect(await from(byMod(2147483647, editor: mod)), Resolution.deferred);
      expect((await store.get(kId1))!.version, 21);
      expect(await svc.retryDeferred(), isFalse);
      expect((await store.get(kId1))!.version, 21);
    });

    test('der Besitzer bleibt arbeitsfähig: seine nächste Fassung baut auf der angenommenen Version auf', () async {
      await base();
      await from(byMod(21));
      final mine = CalendarService(store: store, myUserId: kOwner, clock: () => now);
      final next = await mine.update((await store.get(kId1))!.copyWith(title: 'Besitzer'));
      expect(next.version, 22);
      expect(next.editorId, isNull);
    });
  });

  group('Puffer', () {
    test('Fassung vor Basis: nach Basis angenommen', () async {
      expect(await from(byMod(2)), Resolution.deferred);
      await base();
      final cur = await store.get(kId1);
      expect(cur!.version, 2);
      expect(cur.editorId, mod);
      expect(svc.deferredCount, 0);
    });

    test('drei Moderatoren V+45, V+30, V+15 in allen Reihenfolgen: Fixpunkt endet auf V+45', () async {
      const mods = <String>[mod, mod2, '@eva:fake.test'];
      final orders = <List<int>>[
        <int>[0, 1, 2], <int>[0, 2, 1], <int>[1, 0, 2], <int>[1, 2, 0], <int>[2, 0, 1], <int>[2, 1, 0],
      ];
      for (final o in orders) {
        final s = MemoryEventStore();
        final c = CalendarService(store: s, myUserId: me, clock: () => now, roleOf: (_) => Role.moderator);
        final vs = <int>[46, 31, 16];
        for (final i in o) {
          await c.applyFrom(byMod(vs[i], editor: mods[i]), sender: mods[i], serverTime: stamp);
        }
        await c.applyFrom(ev(version: 1, updatedAt: stamp), sender: kOwner, serverTime: stamp);
        await c.retryDeferred();
        expect((await s.get(kId1))!.version, 46, reason: '$o');
      }
    });

    test('je Schlüssel nur die höchste Version; Entprellung zählt Termine, nicht Nachrichten', () async {
      for (var v = 2; v < 40; v++) {
        await from(byMod(v + 100));
      }
      expect(svc.deferredCount, 1);
    });

    test('Grenzen: 10 je Absender, 50 gesamt, Flut verdrängt zuerst die eigenen Einträge', () async {
      String id(int i) => '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}';
      for (var i = 0; i < 30; i++) {
        await svc.applyFrom(byMod(2, id: id(i)), sender: mod, serverTime: stamp);
      }
      expect(svc.deferredCount, CalendarService.maxDeferredPerSender);
      for (var s = 0; s < 6; s++) {
        final who = '@m$s:fake.test';
        roles[who] = Role.moderator;
        for (var i = 0; i < 10; i++) {
          await svc.applyFrom(byMod(2, id: id(100 + s * 10 + i), editor: who), sender: who, serverTime: stamp);
        }
      }
      expect(svc.deferredCount, CalendarService.maxDeferredTotal);
    });

    test('Verfall 2 Tage nach lokalem Eingang, nicht nach der Serverzeit des Absenders', () async {
      await from(byMod(2));
      now = now.add(const Duration(days: 2, hours: 1));
      await svc.retryDeferred();
      expect(svc.deferredCount, 0);
    });

    test('Wiederholungslauf bei leerem Puffer liest den Bestand nicht', () async {
      final counting = _CountingStore();
      final c = CalendarService(store: counting, myUserId: me, clock: () => now, roleOf: (_) => Role.moderator);
      for (var i = 0; i < 100; i++) {
        expect(await c.retryDeferred(), isFalse);
      }
      expect(counting.gets, 0);
    });
  });

  group('Besitzer nach Moderatorfassung', () {
    test('Löschmarke des Besitzers gewinnt gegen gepufferte und angenommene Fassungen', () async {
      await base();
      await from(byMod(3));
      final gone = ev(version: 1, updatedAt: stamp).tombstone(stamp); // V2 < V3
      expect(await from(gone, sender: kOwner), Resolution.replace);
      expect((await store.get(kId1))!.deleted, isTrue);
      expect(await from(byMod(4)), Resolution.rejectOwner);
    });
  });
}

class _CountingStore extends MemoryEventStore {
  int gets = 0;

  @override
  Future<CalendarEvent?> get(String id) {
    gets++;
    return super.get(id);
  }
}
