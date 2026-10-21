import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/conflict.dart';
import 'package:family_nexus/domain/event_store.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/events.dart';
import '../support/memory_event_store.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);

  late MemoryEventStore store;
  late CalendarService svc;
  var ids = 0;
  var now = DateTime.utc(2026, 3, 10, 12);

  setUp(() {
    store = MemoryEventStore();
    ids = 0;
    now = DateTime.utc(2026, 3, 10, 12);
    svc = CalendarService(
      store: store,
      myUserId: kOwner,
      clock: () => now,
      idGenerator: () => '00000000-0000-4000-8000-${(++ids).toString().padLeft(12, '0')}',
    );
  });

  Future<CalendarEvent> make({EventVisibility v = EventVisibility.shared, List<int>? reminders}) => svc.create(
        title: ' Zahnarzt ',
        start: DateTime.utc(2026, 3, 20, 8),
        end: DateTime.utc(2026, 3, 20, 9),
        timeZone: 'Europe/Berlin',
        visibility: v,
        reminders: reminders,
      );

  group('anlegen', () {
    test('trimmt Titel, setzt Besitzer, Version 1, noch unveröffentlicht', () async {
      final e = await make();
      expect(e.title, 'Zahnarzt');
      expect(e.ownerId, kOwner);
      expect(e.version, 1);
      expect(await store.pendingPublish(), <CalendarEvent>[e]);
    });

    test('ungültige Eingaben werden abgelehnt', () async {
      await expectLater(
        svc.create(title: '', start: now, end: now, timeZone: 'Europe/Berlin', visibility: EventVisibility.private),
        throwsA(isA<CalendarException>()),
      );
      await expectLater(
        svc.create(title: 'x', start: now, end: now.subtract(const Duration(hours: 1)), timeZone: 'Europe/Berlin', visibility: EventVisibility.private),
        throwsA(isA<CalendarException>()),
      );
      await expectLater(
        svc.create(title: 'x', start: now, end: now, timeZone: 'Nirgendwo/Nichts', visibility: EventVisibility.private),
        throwsA(isA<CalendarException>()),
      );
      expect(await store.all(), isEmpty);
    });

    test('persönliche Erinnerungen werden gespeichert', () async {
      final e = await make(reminders: <int>[10, 60]);
      expect((await store.reminders())[e.id], <int>[10, 60]);
    });
  });

  group('ändern und löschen', () {
    test('Änderung erhöht Version, setzt updatedAt, behält Sichtbarkeit, bewahrt Verlauf', () async {
      final e = await make();
      now = now.add(const Duration(minutes: 5));
      final u = await svc.update(e.copyWith(title: 'Neu', visibility: EventVisibility.private));
      expect(u.version, 2);
      expect(u.updatedAt, now);
      expect(u.visibility, EventVisibility.shared, reason: 'Sichtbarkeit nur über changeVisibility');
      expect((await store.history(e.id)).single.title, 'Zahnarzt');
    });

    test('fremde Termine sind nicht änderbar oder löschbar (auch nicht für Moderatoren)', () async {
      final foreign = ev(owner: kOther);
      await svc.applyIncoming(foreign);
      await expectLater(svc.update(foreign.copyWith(title: 'X')), throwsA(isA<CalendarException>()));
      await expectLater(svc.delete(foreign.id), throwsA(isA<CalendarException>()));
      expect((await store.get(foreign.id))!.title, 'Test');
    });

    test('Löschen erzeugt Tombstone mit höherer Version und entfernt Erinnerungen', () async {
      final e = await make(reminders: <int>[10]);
      await svc.delete(e.id);
      final t = (await store.get(e.id))!;
      expect(t.deleted, isTrue);
      expect(t.version, 2);
      expect(t.title, isNot('Zahnarzt'), reason: 'Inhalt wird nicht mitgeführt');
      expect((await store.reminders()).containsKey(e.id), isFalse);
      expect(await store.pendingPublish(), contains(t));
    });

    test('Unbekannte ID', () async {
      await expectLater(svc.delete('00000000-0000-4000-8000-0000000000ff'), throwsA(isA<CalendarException>()));
    });
  });

  group('Sichtbarkeit wechseln', () {
    test('privat → geteilt: gleiche ID, neue Version, zur Veröffentlichung vorgemerkt', () async {
      final e = await make(v: EventVisibility.private);
      await store.markPublished(e.id, 1);
      final s = await svc.changeVisibility(e.id, EventVisibility.shared);
      expect(s.id, e.id);
      expect(s.version, 2);
      expect(s.isShared, isTrue);
      expect(await store.pendingPublish(), contains(s));
    });

    test('geteilt → privat: Tombstone für alle, private Kopie mit neuer ID, Erinnerungen wandern mit', () async {
      final e = await make(reminders: <int>[30]);
      final p = await svc.changeVisibility(e.id, EventVisibility.private);
      expect(p.id, isNot(e.id));
      expect(p.visibility, EventVisibility.private);
      expect(p.attendees, isEmpty);
      final old = (await store.get(e.id))!;
      expect(old.deleted, isTrue);
      expect(old.visibility, EventVisibility.shared, reason: 'Tombstone geht in den Familienraum');
      expect((await store.reminders())[p.id], <int>[30]);
    });

    test('gleiche Sichtbarkeit ist ein No-Op', () async {
      final e = await make();
      expect(await svc.changeVisibility(e.id, EventVisibility.shared), e);
    });
  });

  group('eingehende Termine', () {
    test('neu → eingefügt und als veröffentlicht markiert', () async {
      final e = ev(owner: kOther);
      expect(await svc.applyIncoming(e), Resolution.insert);
      expect(await store.pendingPublish(), isEmpty, reason: 'fremde Termine werden nie von uns veröffentlicht');
    });

    test('neuere Fassung ersetzt, ältere Fassung bleibt im Verlauf', () async {
      final v1 = ev(owner: kOther, version: 1, title: 'A');
      final v2 = ev(owner: kOther, version: 2, title: 'B');
      await svc.applyIncoming(v1);
      expect(await svc.applyIncoming(v2), Resolution.replace);
      expect((await store.get(v1.id))!.title, 'B');
      expect((await store.history(v1.id)).map((e) => e.title), <String>['A']);
    });

    test('veraltete Fassung ändert nichts, landet aber im Verlauf', () async {
      final v1 = ev(owner: kOther, version: 1, title: 'A');
      final v2 = ev(owner: kOther, version: 2, title: 'B');
      await svc.applyIncoming(v2);
      expect(await svc.applyIncoming(v1), Resolution.ignoreStale);
      expect((await store.get(v1.id))!.title, 'B');
      expect((await store.history(v1.id)).map((e) => e.title), <String>['A']);
    });

    test('Fälschung durch anderen Absender wird verworfen', () async {
      await svc.applyIncoming(ev(owner: kOther, title: 'Echt'));
      final r = await svc.applyIncoming(ev(owner: kOwner, version: 50, title: 'Fake'));
      expect(r, Resolution.rejectOwner);
      expect((await store.get(kId1))!.title, 'Echt');
    });

    test('privat → geteilt vom eigenen anderen Gerät mit höherer Version wird übernommen', () async {
      final mine = await make(v: EventVisibility.private);
      final r = await svc.applyIncoming(mine.copyWith(version: 2, visibility: EventVisibility.shared));
      expect(r, Resolution.replace);
      expect((await store.get(mine.id))!.visibility, EventVisibility.shared);
    });

    test('anderer Wechsel der Sichtbarkeit wird abgelehnt (geteilt → privat, gleiche/niedrigere Version, fremder Absender)', () async {
      final shared = await make();
      expect(await svc.applyIncoming(shared.copyWith(version: 9, visibility: EventVisibility.private)), Resolution.rejectOwner);
      final priv = await make(v: EventVisibility.private);
      expect(await svc.applyIncoming(priv.copyWith(version: priv.version, visibility: EventVisibility.shared)), Resolution.rejectOwner);
      final foreignPriv = ev(owner: kOther, visibility: EventVisibility.private, id: kId2);
      await store.put(foreignPriv);
      expect(
        await svc.applyIncoming(ev(owner: kOwner, id: kId2, version: 5, visibility: EventVisibility.shared)),
        Resolution.rejectOwner,
        reason: 'anderer Absender darf die Sichtbarkeit nicht wechseln',
      );
    });

    test('Grenze: höchstens ${CalendarService.maxEventsPerSender} Termine je fremdem Absender', () async {
      for (var i = 0; i < CalendarService.maxEventsPerSender; i++) {
        await store.put(ev(owner: kOther, id: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}'));
      }
      expect(await svc.applyIncoming(ev(owner: kOther, id: kId2)), Resolution.rejectOwner);
      // Eigene Termine sind nicht betroffen.
      expect(await make(), isNotNull);
    });

    test('Verlauf ist je Termin begrenzt', () async {
      final e = ev(owner: kOther);
      for (var v = 1; v <= 40; v++) {
        await store.addHistory(e.copyWith(version: v, title: 'v$v'));
      }
      expect((await store.history(e.id)).length, EventStore.maxHistoryPerEvent);
    });

    test('Wiederholung: gleiche Fassung zweimal → Duplikat', () async {
      final e = ev(owner: kOther);
      await svc.applyIncoming(e);
      expect(await svc.applyIncoming(e), Resolution.ignoreDuplicate);
    });
  });

  test('Rechte: nur eigene, nicht gelöschte Termine sind editierbar', () async {
    final mine = await make();
    expect(svc.canEdit(mine), isTrue);
    expect(svc.canEdit(mine.tombstone(now)), isFalse);
    expect(svc.canEdit(ev(owner: kOther)), isFalse);
    expect(const Recurrence().isRecurring, isFalse);
  });
}
