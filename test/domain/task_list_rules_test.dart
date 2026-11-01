import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_task_store.dart';

const String kAnna = '@anna:fake.test';
const String kBen = '@ben:fake.test';
const String _list1 = '00000000-0000-4000-8000-000000000001';
const String _item1 = '00000000-0000-4000-8000-000000000002';

TaskList _list({
  TaskRule rule = const TaskRule.everyDay(),
  String description = '',
  bool deleted = false,
  String title = 'Haushalt',
  String itemTitle = 'Müll raus',
}) =>
    TaskList(
      id: _list1,
      title: deleted ? '' : title,
      assignee: kBen,
      rule: rule,
      description: description,
      timeZone: 'Europe/Berlin',
      items: deleted ? const <TaskItem>[] : <TaskItem>[TaskItem(id: _item1, title: itemTitle)],
      by: kAnna,
      deleted: deleted,
      updatedAt: DateTime.utc(2026, 10, 21, 12),
    );

TaskLogEntry _entry({required String on, required String period, required DateTime at}) => TaskLogEntry(
      id: '00000000-0000-4000-8000-0000000000a1',
      listId: _list1,
      itemId: _item1,
      periodKey: period,
      doneOn: on,
      at: at,
      by: kBen,
    );

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Issue #1: Erklärung und Regel in der Liste', () {
    test('Erklärung ist optional, mehrzeilig, begrenzt und ohne Steuer-/Bidi-Zeichen', () {
      expect(_list().validate(), isEmpty);
      expect(_list(description: 'Erst sortieren,\ndann rausbringen.').validate(), isEmpty);
      expect(_list(description: 'x' * (TaskList.maxDescription + 1)).validate(), contains('description'));
      expect(_list(description: 'Text\u202Eversteckt').validate(), contains('description'));
      expect(_list(description: 'Tab\tim Text').validate(), contains('description'));
      // Review R2: zusammengesetzte Emojis (ZWJ) und ZWNJ sind erlaubt.
      expect(_list(description: 'Für die ganze 👨‍👩‍👧 ❤️‍🔥').validate(), isEmpty);
      expect(_list(description: 'می\u200Cخواهم').validate(), isEmpty);
      expect(_list(description: 'Rest', deleted: true).validate(), contains('tombstone'));
    });

    test('ungültige Regel wird abgelehnt', () {
      expect(_list(rule: const TaskRule.weekly(9)).validate(), contains('rule'));
      expect(_list(rule: const TaskRule.monthlyByDate(32)).validate(), contains('rule'));
    });
  });

  group('#161: zusammengesetzte Emojis und ZWNJ in Titeln und Punkten', () {
    const family = '👨\u200D👩\u200D👧';
    test('Listentitel und Punkt dürfen ZWJ/ZWNJ enthalten', () {
      expect(_list(title: '$family Haushalt').validate(), isEmpty);
      expect(_list(itemTitle: '$family Müll raus').validate(), isEmpty);
      expect(_list(itemTitle: 'می\u200Cخواهم').validate(), isEmpty);
    });

    test('andere Steuer- und Bidi-Zeichen bleiben gesperrt', () {
      for (final bad in <String>['\u200B', '\u200E', '\u200F', '\u202E', '\u2060', '\uFEFF', '\u061C', '\u2066']) {
        expect(_list(title: 'a${bad}b').validate(), contains('title'), reason: bad.codeUnits.toString());
        expect(_list(itemTitle: 'a${bad}b').validate(), contains('item-title'), reason: bad.codeUnits.toString());
      }
    });

    test('ein Titel nur aus Verbindern ist leer (kein unsichtbarer Titel)', () {
      expect(_list(title: '\u200D\u200C').validate(), contains('title'));
      expect(_list(itemTitle: ' \u200D ').validate(), contains('item-title'));
    });

    test('Länge wird in Zeichen (Runen) gezählt, auch mit ZWJ', () {
      expect(_list(itemTitle: 'a' * (TaskList.maxTitle - 1) + '\u200D').validate(), isEmpty);
      expect(_list(itemTitle: 'a' * TaskList.maxTitle + '\u200D').validate(), contains('item-title'));
    });
  });

  group('Ereignisformat: v1 für bisherige Listen, v2 nur für neue Regeln/Erklärung', () {
    test('bisherige Regel ohne Erklärung bleibt v1 (ältere App-Versionen lesen sie weiter)', () {
      for (final r in <TaskRule>[const TaskRule.everyDay(), const TaskRule.weekly(DateTime.monday), const TaskRule.monthlyByDate(1)]) {
        final c = TaskCodec.encodeList(_list(rule: r));
        expect(c['v'], 1, reason: '$r');
        expect(c.containsKey('rule') || c.containsKey('note'), isFalse);
        expect(TaskCodec.decodeList(c, sender: kAnna)!.rule, r);
      }
    });

    test('neue Regel oder Erklärung → v2 mit Roundtrip', () {
      final weekdays = _list(rule: const TaskRule.weekdays());
      final c1 = TaskCodec.encodeList(weekdays);
      expect(c1['v'], 2);
      expect(c1['interval'], 'daily');
      expect(TaskCodec.decodeList(c1, sender: kAnna), weekdays);

      final withNote = _list(description: 'Bitte Gelbe Säcke extra.');
      final c2 = TaskCodec.encodeList(withNote);
      expect(c2['v'], 2);
      expect(TaskCodec.decodeList(c2, sender: kAnna), withNote);

      final nth = _list(rule: const TaskRule.monthlyByWeekday(TaskRule.last, DateTime.friday), description: 'Zeile 1\nZeile 2');
      expect(TaskCodec.decodeList(TaskCodec.encodeList(nth), sender: kAnna), nth);
    });

    test('manipulierte Ereignisse werden verworfen', () {
      final v2 = TaskCodec.encodeList(_list(rule: const TaskRule.weekly(DateTime.wednesday)));
      final v1 = TaskCodec.encodeList(_list());
      final bad = <String, Map<String, Object?>>{
        'v1 mit Regel': <String, Object?>{...v1, 'rule': const TaskRule.weekdays().toJson()},
        'v1 mit Erklärung': <String, Object?>{...v1, 'note': 'x'},
        'v2 ohne Regel': <String, Object?>{...v2}..remove('rule'),
        'v2 ohne Erklärungsfeld': <String, Object?>{...v2}..remove('note'),
        'v2 Regel passt nicht zum Intervall': <String, Object?>{...v2, 'interval': 'monthly'},
        'v2 ungültige Regel': <String, Object?>{...v2, 'rule': <String, Object?>{'kind': 'weekly', 'weekday': 0}},
        'v2 Erklärung kein Text': <String, Object?>{...v2, 'note': 5},
        'v2 Erklärung zu lang': <String, Object?>{...v2, 'note': 'x' * 1001},
        'Version 3': <String, Object?>{...v2, 'v': 3},
        'v2 mit bisheriger Regel ohne Erklärung (mehrdeutig, R4)': <String, Object?>{
          ...v2,
          'interval': 'daily',
          'rule': const TaskRule.everyDay().toJson(),
          'note': '',
        },
        'v2 unbekanntes Feld in der Regel': <String, Object?>{
          ...v2,
          'rule': <String, Object?>{'kind': 'weekly', 'weekday': 3, 'every': 2},
        },
      };
      bad.forEach((name, c) => expect(TaskCodec.decodeList(c, sender: kAnna), isNull, reason: name));
    });
  });

  group('Verlauf und aktueller Stand mit neuen Regeln', () {
    test('Schlüssel neuer Regeln: Startdatum ≤ Erledigungsdatum, höchstens 35 Tage davor', () {
      final at = DateTime.utc(2026, 10, 24, 10);
      expect(_entry(on: '2026-10-24', period: '2026-10-23', at: at).validate(), isEmpty);
      expect(_entry(on: '2026-10-24', period: '2026-09-25', at: at).validate(), isEmpty);
      expect(_entry(on: '2026-10-24', period: '2026-09-10', at: at).validate(), contains('period'), reason: 'zu weit zurück');
      expect(_entry(on: '2026-10-24', period: '2026-10-25', at: at).validate(), contains('period'), reason: 'in der Zukunft');
    });

    test('ein Eintrag zählt nur mit dem Schlüssel der Regel der Liste', () {
      final list = _list(rule: const TaskRule.weekly(DateTime.wednesday));
      final at = DateTime.utc(2026, 10, 24, 10); // Samstag, Periode ab Mittwoch 21.10.
      expect(TaskProgress.isValidFor(list, _entry(on: '2026-10-24', period: '2026-10-21', at: at)), isTrue);
      expect(TaskProgress.isValidFor(list, _entry(on: '2026-10-24', period: '2026-10-24', at: at)), isFalse);
      expect(TaskProgress.isValidFor(list, _entry(on: '2026-10-24', period: '2026-W43', at: at)), isFalse);
    });

    test('Montag bis Freitag: am Samstag Erledigtes bleibt bis Sonntag erledigt, Montag beginnt neu', () async {
      var now = DateTime.utc(2026, 10, 24, 10); // Samstag
      final store = MemoryTaskStore();
      TaskService service(String me) => TaskService(
            store: store,
            myUserId: me,
            isModerator: (id) => id == kAnna,
            clock: () => now,
          );
      final list = await service(kAnna).createList(
        title: 'Hausaufgaben',
        assignee: kBen,
        rule: const TaskRule.weekdays(),
        description: '  Erst  Mathe,\n\n\n\ndann Deutsch.  ',
        timeZone: 'Europe/Berlin',
        items: <String>['Hefte packen'],
      );
      expect(list.description, 'Erst Mathe,\n\ndann Deutsch.', reason: 'Leerraum vereinheitlicht');
      final e = await service(kBen).complete(list.id, list.items.single.id);
      expect(e.periodKey, '2026-10-23', reason: 'Samstag gehört zur Periode vom Freitag');
      final log = await store.log();
      now = DateTime.utc(2026, 10, 25, 20); // Sonntag
      expect(TaskProgress.doneNow(list, log, now), hasLength(1));
      now = DateTime.utc(2026, 10, 25, 23, 30); // Montag 0:30 in Berlin (Winterzeit, UTC+1)
      expect(TaskProgress.doneNow(list, log, now), isEmpty, reason: 'Montag beginnt neu');
    });

    test('monatlich am 31.: im November gilt der 30. als Neustart', () async {
      var now = DateTime.utc(2026, 11, 30, 9);
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => now);
      final list = await s.createList(
        title: 'Abrechnung',
        assignee: kAnna,
        rule: const TaskRule.monthlyByDate(31),
        timeZone: 'Europe/Berlin',
        items: <String>['Belege'],
      );
      final e = await s.complete(list.id, list.items.single.id);
      expect(e.periodKey, '2026-11-30');
      now = DateTime.utc(2026, 12, 30, 9);
      expect(TaskProgress.doneNow(list, await store.log(), now), hasLength(1), reason: 'bis zum 31.12. dieselbe Periode');
      now = DateTime.utc(2026, 12, 31, 9);
      expect(TaskProgress.doneNow(list, await store.log(), now), isEmpty);
    });

    test('Ändern der Regel: andere Periode beginnt leer, der Verlauf bleibt vollständig (R5/R6)', () async {
      final now = DateTime.utc(2026, 10, 24, 10);
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => now);
      final list = await s.createList(title: 'Garten', assignee: kAnna, timeZone: 'Europe/Berlin', items: <String>['Gießen']);
      await s.complete(list.id, list.items.single.id);
      final changed = await s.updateList(
        list.id,
        title: 'Garten',
        assignee: kAnna,
        rule: const TaskRule.weekly(DateTime.wednesday),
        description: 'Nur bei Trockenheit',
        items: <String>['Gießen'],
      );
      expect(changed.rule, const TaskRule.weekly(DateTime.wednesday));
      expect(changed.description, 'Nur bei Trockenheit');
      expect(changed.items.single.id, list.items.single.id, reason: 'Punkte behalten ihre ID');
      expect(TaskProgress.doneNow(changed, await store.log(), now), isEmpty, reason: 'Samstag ≠ Periode ab Mittwoch');
      expect(TaskProgress.history(changed, await store.log()), hasLength(1), reason: 'Verlauf zeigt auch alte Einträge');
    });

    test('Ändern der Regel bei gleichem Schlüssel: Erledigtes bleibt erledigt (täglich → Mo–Fr an einem Werktag)', () async {
      final now = DateTime.utc(2026, 10, 22, 10); // Donnerstag
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => now);
      final list = await s.createList(title: 'Garten', assignee: kAnna, timeZone: 'Europe/Berlin', items: <String>['Gießen']);
      await s.complete(list.id, list.items.single.id);
      final changed = await s.updateList(list.id, title: 'Garten', assignee: kAnna, rule: const TaskRule.weekdays(), items: <String>['Gießen']);
      expect(TaskProgress.doneNow(changed, await store.log(), now), hasLength(1));
    });

    test('R1: Löschmarke einer v2-Liste wird als v1 gesendet (ältere Versionen sehen das Löschen)', () async {
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => DateTime.utc(2026, 10, 24));
      final list = await s.createList(
        title: 'Hausaufgaben',
        assignee: kAnna,
        rule: const TaskRule.weekdays(),
        description: 'Vor dem Essen',
        timeZone: 'Europe/Berlin',
        items: <String>['Hefte'],
      );
      expect(TaskCodec.encodeList(list)['v'], 2);
      await s.deleteList(list.id);
      final tomb = (await store.getList(list.id))!;
      expect(tomb.deleted, isTrue);
      final c = TaskCodec.encodeList(tomb);
      expect(c['v'], 1);
      expect(c['interval'], 'daily');
    });

    test('R8: Ändern ohne Angabe der Erklärung behält sie', () async {
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => DateTime.utc(2026, 10, 24));
      final list = await s.createList(title: 'A', assignee: kAnna, description: 'bleibt', timeZone: 'UTC', items: <String>['x']);
      final changed = await s.updateList(list.id, title: 'B', assignee: kAnna, items: <String>['x']);
      expect(changed.description, 'bleibt');
    });

    test('R2: einzelnes \\r beim Einfügen wird zum Zeilenumbruch', () async {
      final store = MemoryTaskStore();
      final s = TaskService(store: store, myUserId: kAnna, isModerator: (_) => true, clock: () => DateTime.utc(2026, 10, 24));
      final list = await s.createList(title: 'A', assignee: kAnna, description: 'Zeile 1\rZeile 2', timeZone: 'UTC', items: <String>['x']);
      expect(list.description, 'Zeile 1\nZeile 2');
    });
  });
}
