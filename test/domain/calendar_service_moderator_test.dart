import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';
import '../support/memory_event_store.dart';

/// #431, E-112: Rechte und Änderung durch Moderatoren im Dienst (Senden- und Bearbeitenseite).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  const mod = '@cara:fake.test';
  const member = '@ben:fake.test';
  final now = DateTime.utc(2026, 3, 10, 12);

  late MemoryEventStore store;
  Role? role;

  CalendarService svcFor(String me) => CalendarService(store: store, myUserId: me, clock: () => now, roleOf: (id) => id == me ? role : null);

  setUp(() {
    store = MemoryEventStore();
    role = Role.moderator;
  });

  Future<CalendarEvent> seed({EventVisibility v = EventVisibility.shared, String owner = kOwner}) async {
    final e = ev(owner: owner, visibility: v);
    await store.put(e, publishedVersion: e.version);
    return e;
  }

  group('Rechte', () {
    test('Moderator ändert geteilte fremde Termine, aber nicht private, gelöschte oder eigene Rechte darüber hinaus', () async {
      final s = svcFor(mod);
      final shared = await seed();
      expect(s.canEdit(shared), isTrue);
      expect(s.canDelete(shared), isFalse);
      expect(s.canChangeVisibility(shared), isFalse);
      expect(s.canEdit(ev(visibility: EventVisibility.private)), isFalse);
      expect(s.canEdit(shared.tombstone(now)), isFalse);
    });

    test('Mitglied und unbekannte Rolle ändern fremde Termine nicht', () async {
      final shared = await seed();
      role = Role.member;
      expect(svcFor(member).canEdit(shared), isFalse);
      role = null;
      expect(svcFor(member).canEdit(shared), isFalse);
    });

    test('Besitzer behält alle Rechte', () async {
      final s = svcFor(kOwner);
      final e = ev();
      expect(s.canEdit(e) && s.canDelete(e) && s.canChangeVisibility(e), isTrue);
    });
  });

  group('Änderung durch einen Moderator', () {
    test('neue Fassung: Version +1, jetzt, editor = Moderator, Besitzer und Sichtbarkeit unverändert, wartet auf Senden', () async {
      final base = await seed();
      final saved = await svcFor(mod).update(base.copyWith(title: 'Neu'));
      expect(saved.version, base.version + 1);
      expect(saved.title, 'Neu');
      expect(saved.editorId, mod);
      expect(saved.ownerId, kOwner);
      expect(saved.visibility, EventVisibility.shared);
      expect(saved.updatedAt, now);
      expect((await store.history(base.id)).single.version, base.version);
      expect((await store.pendingPublish()).single.editorId, mod);
    });

    test('Besitzer und Sichtbarkeit aus der Vorlage zählen nicht: ein anderer Besitzer wird abgelehnt, privat bleibt geteilt', () async {
      final base = await seed();
      await expectLater(
        svcFor(mod).update(ev(owner: mod, title: 'Fälschung')),
        throwsA(isA<CalendarException>()),
      );
      final saved = await svcFor(mod).update(base.copyWith(title: 'x', visibility: EventVisibility.private));
      expect(saved.visibility, EventVisibility.shared);
    });

    test('gleiche Kennung, anderer Besitzer in der Vorlage (Fälschung): invalid, nichts gespeichert', () async {
      final base = await seed();
      final forged = ev(id: base.id, owner: mod, title: 'Fälschung', version: base.version);
      await expectLater(
        svcFor(mod).update(forged),
        throwsA(isA<CalendarException>().having((e) => e.error, 'error', CalendarError.invalid)),
      );
      expect(await store.get(base.id), base);
    });

    test('Löschen und Sichtbarkeit wechseln wirft notAllowed, nichts ändert sich', () async {
      final base = await seed();
      final s = svcFor(mod);
      await expectLater(s.delete(base.id), throwsA(isA<CalendarException>()));
      await expectLater(s.changeVisibility(base.id, EventVisibility.private), throwsA(isA<CalendarException>()));
      expect(await store.get(base.id), base);
    });

    test('Mitglied ändert nicht', () async {
      final base = await seed();
      role = Role.member;
      await expectLater(svcFor(member).update(base.copyWith(title: 'X')), throwsA(isA<CalendarException>()));
      expect((await store.get(base.id))!.title, base.title);
    });

    test('Besitzer-Änderung danach: Version +1 auf der Moderatorfassung, editor weg', () async {
      final base = await seed();
      final byMod = await svcFor(mod).update(base.copyWith(title: 'M'));
      final byOwner = await svcFor(kOwner).update(byMod.copyWith(title: 'O'));
      expect(byOwner.version, byMod.version + 1);
      expect(byOwner.editorId, isNull);
    });
  });
}
