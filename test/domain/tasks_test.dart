import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_task_store.dart';

const String kAnna = '@anna:fake.test';
const String kBen = '@ben:fake.test';
const String kCara = '@cara:fake.test';
const String _id1 = '00000000-0000-4000-8000-000000000001';
const String _id2 = '00000000-0000-4000-8000-000000000002';
const String _id3 = '00000000-0000-4000-8000-000000000003';

TaskList _list({
  String id = _id1,
  String title = 'Haushalt',
  String assignee = kBen,
  TaskInterval interval = TaskInterval.daily,
  String tz = 'Europe/Berlin',
  List<TaskItem>? items,
  String by = kAnna,
  int version = 1,
  bool deleted = false,
  DateTime? updatedAt,
}) =>
    TaskList(
      id: id,
      title: title,
      assignee: assignee,
      interval: interval,
      timeZone: tz,
      items: items ?? const <TaskItem>[TaskItem(id: _id2, title: 'Müll raus'), TaskItem(id: _id3, title: 'Spülmaschine')],
      by: by,
      version: version,
      deleted: deleted,
      updatedAt: updatedAt ?? DateTime.utc(2026, 10, 21, 12),
    );

TaskLogEntry _entry({
  String id = '00000000-0000-4000-8000-0000000000a1',
  String item = _id2,
  String on = '2026-10-22',
  String? period,
  DateTime? at,
  TaskLogKind kind = TaskLogKind.done,
  String comment = '',
  String by = kBen,
  String listId = _id1,
}) =>
    TaskLogEntry(
      id: id,
      listId: listId,
      itemId: item,
      periodKey: period ?? on,
      doneOn: on,
      at: at ?? DateTime.utc(2026, 10, 22, 10),
      by: by,
      kind: kind,
      comment: comment,
    );

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('TaskList.validate', () {
    test('gültige Liste', () => expect(_list().validate(), isEmpty));

    test('lehnt ungültige Felder ab', () {
      expect(_list(id: 'x').validate(), contains('id'));
      expect(_list(assignee: 'ben').validate(), contains('assignee'));
      expect(_list(by: 'anna').validate(), contains('by'));
      expect(_list(tz: 'Mars/Olympus').validate(), contains('tz'));
      expect(_list(title: '  ').validate(), contains('title'));
      expect(_list(title: 'a\u202eb').validate(), contains('title'));
      expect(_list(version: 0).validate(), contains('version'));
      expect(_list(items: [const TaskItem(id: _id2, title: 'a'), const TaskItem(id: _id2, title: 'b')]).validate(), contains('item-id'));
      expect(_list(items: [const TaskItem(id: _id2, title: '')]).validate(), contains('item-title'));
      expect(_list(items: [for (var i = 0; i < 51; i++) TaskItem(id: '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}', title: 'x')]).validate(),
          contains('items'));
    });

    test('Löschmarke trägt keinen Inhalt', () {
      expect(_list(deleted: true).validate(), contains('tombstone'));
      expect(_list(deleted: true, title: '', items: const <TaskItem>[]).validate(), isEmpty);
    });
  });

  group('TaskCodec', () {
    test('Roundtrip Liste', () {
      final l = _list(interval: TaskInterval.weekly);
      expect(TaskCodec.decodeList(TaskCodec.encodeList(l), sender: kAnna), l);
    });

    test('Roundtrip Protokoll inkl. Kommentar', () {
      final e = _entry(comment: 'Schon am Morgen');
      expect(TaskCodec.decodeLog(TaskCodec.encodeLog(e), sender: kBen), e);
    });

    test('#161: Kommentar mit zusammengesetztem Emoji; andere Steuerzeichen bleiben gesperrt', () {
      final ok = _entry(comment: 'Erledigt 👨\u200D👩\u200D👧');
      expect(ok.validate(), isEmpty);
      expect(TaskCodec.decodeLog(TaskCodec.encodeLog(ok), sender: kBen), ok);
      for (final bad in <String>['\u200B', '\u200E', '\u200F', '\u202E', '\uFEFF']) {
        expect(_entry(comment: 'a${bad}b').validate(), contains('comment'), reason: bad.codeUnits.toString());
      }
    });

    test('by muss dem Absender entsprechen', () {
      expect(TaskCodec.decodeList(TaskCodec.encodeList(_list()), sender: kBen), isNull);
      expect(TaskCodec.decodeLog(TaskCodec.encodeLog(_entry()), sender: kAnna), isNull);
    });

    test('Zeitraum und Typen werden streng geprüft', () {
      final m = TaskCodec.encodeLog(_entry());
      expect(TaskCodec.decodeLog({...m, 'ts': 1 << 62}, sender: kBen), isNull);
      expect(TaskCodec.decodeLog({...m, 'ts': '5'}, sender: kBen), isNull);
      expect(TaskCodec.decodeLog({...m, 'kind': 'kaputt'}, sender: kBen), isNull);
      expect(TaskCodec.decodeLog({...m, 'on': '2026-02-30'}, sender: kBen), isNull);
      expect(TaskCodec.decodeLog({...m, 'period': '1999-01'}, sender: kBen), isNull, reason: 'passt nicht zum Datum');
      expect(TaskCodec.decodeLog({...m, 'v': 2}, sender: kBen), isNull);
      expect(TaskCodec.decodeLog({...m, 'comment': 'x' * 500}, sender: kBen), isNull);
      final l = TaskCodec.encodeList(_list());
      expect(TaskCodec.decodeList({...l, 'interval': 'hourly'}, sender: kAnna), isNull);
      expect(TaskCodec.decodeList({...l, 'items': 'nein'}, sender: kAnna), isNull);
      expect(TaskCodec.decodeList({...l, 'items': <Object?>[5]}, sender: kAnna), isNull);
    });

    test('encode wirft bei ungültigen Daten', () {
      expect(() => TaskCodec.encodeList(_list(title: '')), throwsStateError);
      expect(() => TaskCodec.encodeLog(_entry(on: 'x')), throwsStateError);
    });
  });

  group('TaskMerge', () {
    test('höhere Version gewinnt, dann Zeit, dann Absender', () {
      final a = _list(version: 2);
      final b = _list(version: 3, title: 'Neu');
      expect(TaskMerge.incomingWins(a, b), isTrue);
      expect(TaskMerge.incomingWins(b, a), isFalse);
      expect(TaskMerge.incomingWins(null, a), isTrue);
    });

    test('Gleichstand ist symmetrisch (genau einer gewinnt)', () {
      final a = _list(title: 'A');
      final b = _list(title: 'B');
      expect(TaskMerge.incomingWins(a, b), isNot(TaskMerge.incomingWins(b, a)));
    });
  });

  group('TaskProgress (Reset als abgeleiteter Zustand)', () {
    final list = _list();
    final berlinMorning = DateTime.utc(2026, 10, 22, 10);

    test('erledigter Punkt gilt in derselben Periode, nicht in der nächsten', () {
      final log = [_entry()];
      expect(TaskProgress.doneNow(list, log, berlinMorning).keys, [_id2]);
      // Nächster Tag (lokal ab 00:00 Berlin = 22:00 UTC).
      expect(TaskProgress.doneNow(list, log, DateTime.utc(2026, 10, 22, 21, 59)).keys, [_id2]);
      expect(TaskProgress.doneNow(list, log, DateTime.utc(2026, 10, 22, 22)), isEmpty);
    });

    test('wöchentlich: erledigt bis Sonntag, am Montag zurückgesetzt', () {
      final weekly = _list(interval: TaskInterval.weekly);
      final log = [_entry(period: '2026-W43')];
      expect(TaskProgress.doneNow(weekly, log, DateTime.utc(2026, 10, 25, 20)).keys, [_id2], reason: 'Sonntag 22:00 Berlin');
      expect(TaskProgress.doneNow(weekly, log, DateTime.utc(2026, 10, 25, 23)), isEmpty, reason: 'Montag 00:00 Berlin');
    });

    test('monatlich: erledigt bis Monatsende, danach zurückgesetzt', () {
      final monthly = _list(interval: TaskInterval.monthly);
      final log = [_entry(period: '2026-10')];
      expect(TaskProgress.doneNow(monthly, log, DateTime.utc(2026, 10, 31, 22)).keys, [_id2]);
      expect(TaskProgress.doneNow(monthly, log, DateTime.utc(2026, 10, 31, 23)), isEmpty);
    });

    test('Zurücknehmen: jüngster Eintrag entscheidet', () {
      final log = [
        _entry(),
        _entry(id: '00000000-0000-4000-8000-0000000000a2', kind: TaskLogKind.undone, at: DateTime.utc(2026, 10, 22, 11)),
      ];
      expect(TaskProgress.doneNow(list, log, berlinMorning.add(const Duration(hours: 2))), isEmpty);
      final again = [...log, _entry(id: '00000000-0000-4000-8000-0000000000a3', at: DateTime.utc(2026, 10, 22, 12))];
      expect(TaskProgress.doneNow(list, again, berlinMorning.add(const Duration(hours: 3))).keys, [_id2]);
    });

    test('Einträge anderer Personen oder inkonsistente Einträge zählen nicht', () {
      final now = berlinMorning.add(const Duration(hours: 1));
      expect(TaskProgress.doneNow(list, [_entry(by: kCara)], now), isEmpty, reason: 'nicht zugewiesen');
      expect(TaskProgress.doneNow(list, [_entry(on: '2026-10-21', at: DateTime.utc(2026, 10, 22, 10))], now), isEmpty,
          reason: 'Datum passt nicht zum Zeitpunkt');
      expect(TaskProgress.doneNow(list, [_entry(period: '2026-W43')], now), isEmpty, reason: 'Periode passt nicht zum Intervall');
      expect(TaskProgress.doneNow(list, [_entry(item: '00000000-0000-4000-8000-0000000000ff')], now), isEmpty, reason: 'Punkt unbekannt');
    });

    test('Verlauf: neueste zuerst, nur gültige Einträge', () {
      final h = TaskProgress.history(list, [
        _entry(id: '00000000-0000-4000-8000-0000000000a1'),
        _entry(id: '00000000-0000-4000-8000-0000000000a2', at: DateTime.utc(2026, 10, 22, 12)),
        _entry(id: '00000000-0000-4000-8000-0000000000a3', by: kCara),
      ]);
      expect(h.map((e) => e.id), ['00000000-0000-4000-8000-0000000000a2', '00000000-0000-4000-8000-0000000000a1']);
    });
  });

  group('TaskService', () {
    late MemoryTaskStore store;
    late DateTime clock;
    var n = 0;

    TaskService svc(String me, {Set<String> mods = const {kAnna}}) => TaskService(
          store: store,
          myUserId: me,
          isModerator: mods.contains,
          clock: () => clock,
          idGenerator: () => '00000000-0000-4000-8000-${(++n).toString().padLeft(12, '0')}',
        );

    setUp(() {
      store = MemoryTaskStore();
      clock = DateTime.utc(2026, 10, 22, 10);
    });

    Future<TaskList> create(TaskService s, {TaskInterval i = TaskInterval.daily}) => s.createList(
          title: '  Haushalt ',
          assignee: kBen,
          interval: i,
          timeZone: 'Europe/Berlin',
          items: ['Müll raus', '  ', 'Spülmaschine'],
        );

    test('nur Moderatoren legen an, ändern und löschen', () async {
      await expectLater(create(svc(kBen)), throwsA(isA<TaskException>().having((e) => e.error, 'error', TaskError.notAllowed)));
      final l = await create(svc(kAnna));
      expect(l.title, 'Haushalt');
      expect(l.items.map((i) => i.title), ['Müll raus', 'Spülmaschine'], reason: 'Leere Punkte entfallen');
      await expectLater(
        svc(kBen).updateList(l.id, title: 'x', assignee: kBen, interval: TaskInterval.daily, items: ['a']),
        throwsA(isA<TaskException>()),
      );
      await expectLater(svc(kBen).deleteList(l.id), throwsA(isA<TaskException>()));
    });

    test('Bearbeiten behält die IDs unveränderter Punkte und erhöht die Version', () async {
      final a = svc(kAnna);
      final l = await create(a);
      final u = await a.updateList(l.id,
          title: 'Haushalt', assignee: kCara, interval: TaskInterval.weekly, items: ['Spülmaschine', 'Staubsaugen']);
      expect(u.version, 2);
      expect(u.assignee, kCara);
      expect(u.items.first.id, l.items[1].id);
      expect(u.items.last.id, isNot(anyOf(l.items.map((i) => i.id))));
    });

    test('nur die zugewiesene Person hakt ab; Datum, Periode und Kommentar werden protokolliert', () async {
      final l = await create(svc(kAnna));
      final item = l.items.first.id;
      await expectLater(svc(kAnna).complete(l.id, item), throwsA(isA<TaskException>()));
      await expectLater(svc(kCara).complete(l.id, item), throwsA(isA<TaskException>()));
      final e = await svc(kBen).complete(l.id, item, comment: '  Schon  erledigt ');
      expect(e.doneOn, '2026-10-22');
      expect(e.periodKey, '2026-10-22');
      expect(e.comment, 'Schon erledigt');
      expect(e.at, clock);
      expect(e.by, kBen);
      expect(TaskProgress.doneNow(l, await store.log(), clock).keys, [item]);
    });

    test('Mitternacht in der Listen-Zeitzone setzt zurück, der Verlauf bleibt', () async {
      final l = await create(svc(kAnna));
      final item = l.items.first.id;
      final ben = svc(kBen);
      await ben.complete(l.id, item);
      clock = DateTime.utc(2026, 10, 22, 22); // 00:00 am 23.10. in Berlin
      expect(TaskProgress.doneNow(l, await store.log(), clock), isEmpty);
      await ben.complete(l.id, item, comment: 'heute wieder');
      expect(TaskProgress.doneNow(l, await store.log(), clock).keys, [item]);
      expect(TaskProgress.history(l, await store.log()), hasLength(2));
    });

    test('unbekannter Punkt, gelöschte Liste, Zurücknehmen', () async {
      final a = svc(kAnna);
      final l = await create(a);
      final ben = svc(kBen);
      await expectLater(ben.complete(l.id, '00000000-0000-4000-8000-0000000000ff'), throwsA(isA<TaskException>()));
      final item = l.items.first.id;
      await ben.complete(l.id, item);
      await ben.undo(l.id, item, comment: 'Irrtum');
      clock = clock.add(const Duration(minutes: 1));
      expect(TaskProgress.doneNow(l, await store.log(), clock), isEmpty);
      await a.deleteList(l.id);
      await expectLater(ben.complete(l.id, item), throwsA(isA<TaskException>()));
    });

    test('Grenzen: Anzahl Listen', () async {
      final a = svc(kAnna);
      for (var i = 0; i < TaskList.maxActive; i++) {
        await create(a);
      }
      await expectLater(create(a), throwsA(isA<TaskException>().having((e) => e.error, 'error', TaskError.limit)));
    });

    test('Empfang: Liste eines Nicht-Moderators wird verworfen', () async {
      final s = svc(kBen);
      expect(await s.applyIncomingList(_list(by: kCara)), isFalse);
      expect(await s.applyIncomingList(_list(by: kAnna)), isTrue);
      expect(await s.applyIncomingList(_list(by: kAnna)), isFalse, reason: 'gleiche Fassung');
      expect(await s.applyIncomingList(_list(by: kAnna, version: 5000)), isFalse, reason: 'Versionssprung');
    });

    test('Empfang: Protokoll-Duplikat, Zeitabweichung', () async {
      final s = svc(kAnna);
      await s.applyIncomingList(_list());
      final e = _entry();
      expect(await s.applyIncomingLog(e, serverTime: e.at), isTrue);
      expect(await s.applyIncomingLog(e, serverTime: e.at), isFalse, reason: 'Duplikat');
      final far = _entry(id: '00000000-0000-4000-8000-0000000000b1');
      expect(await s.applyIncomingLog(far, serverTime: far.at.add(const Duration(days: 3))), isFalse, reason: 'Uhr stimmt nicht');
    });

    // #464: Rechteprüfung beim Empfang des Protokolls, mit flüchtigem Puffer.
    String uuid(String block, int i) => '00000000-0000-4000-$block-${i.toString().padLeft(12, '0')}';
    final base = DateTime.utc(2026, 10, 22, 10);
    Future<bool> receive(TaskService s, TaskLogEntry e) => s.applyIncomingLog(e, serverTime: e.at);
    final tombstone = _list(version: 2, deleted: true, title: '', items: const <TaskItem>[]);

    test('#464: Einträge Nicht-Zugewiesener verdrängen keine Erledigung', () async {
      final s = svc(kAnna);
      expect(await s.applyIncomingList(_list()), isTrue);
      final legit = _entry(at: base);
      expect(await receive(s, legit), isTrue);
      for (var i = 0; i < TaskLogEntry.keepPerList; i++) {
        await receive(s, _entry(id: uuid('a000', i), by: kCara, at: base.add(Duration(minutes: i + 1))));
      }
      final log = await store.log(listId: _id1);
      expect(log.map((e) => e.id), contains(legit.id));
      expect(log.where((e) => e.by == kCara), isEmpty);
      expect(TaskProgress.doneNow(_list(), log, DateTime.utc(2026, 10, 22, 19)).keys, [_id2]);
    });

    test('#464: Einträge zu unbekannten Listen füllen die Gesamtgrenze nicht', () async {
      final s = svc(kAnna);
      for (var i = 0; i < TaskLogEntry.maxTotal; i++) {
        await receive(s, _entry(id: uuid('a000', i), listId: uuid('9000', i), by: kCara));
      }
      expect(await s.applyIncomingList(_list()), isTrue);
      expect(await receive(s, _entry()), isTrue);
      expect(await store.logTotal(), 1);
    });

    test('#464: Eintrag vor seiner Liste wird nachgetragen', () async {
      final s = svc(kAnna);
      final e = _entry();
      expect(await receive(s, e), isFalse);
      expect(await store.log(), isEmpty);
      expect(await s.applyIncomingList(_list()), isTrue);
      expect((await store.log()).map((x) => x.id), [e.id]);
      expect(TaskProgress.doneNow(_list(), await store.log(), base).keys, [_id2]);
    });

    test('#464: Neuzuweisung (a) Eintrag wartet auf die passende Fassung', () async {
      final s = svc(kAnna);
      await s.applyIncomingList(_list(assignee: kCara));
      final e = _entry();
      expect(await receive(s, e), isFalse);
      expect(await store.log(), isEmpty);
      expect(await s.applyIncomingList(_list(version: 2)), isTrue);
      expect((await store.log()).map((x) => x.id), [e.id]);
    });

    test('#464: Neuzuweisung (b) gespeicherte Einträge bleiben und zählen bei Rückzuweisung wieder', () async {
      final s = svc(kAnna);
      await s.applyIncomingList(_list());
      final e = _entry();
      expect(await receive(s, e), isTrue);
      final toCara = _list(assignee: kCara, version: 2);
      expect(await s.applyIncomingList(toCara), isTrue);
      expect((await store.log()).map((x) => x.id), [e.id]);
      expect(TaskProgress.doneNow(toCara, await store.log(), base), isEmpty);
      final back = _list(version: 3);
      expect(await s.applyIncomingList(back), isTrue);
      expect(TaskProgress.doneNow(back, await store.log(), base).keys, [_id2]);
    });

    test('#464: Neuzuweisung (c) lokal durch die Moderatorin trägt gepufferte Einträge nach', () async {
      final a = svc(kAnna);
      await a.applyIncomingList(_list(assignee: kCara));
      final e = _entry();
      expect(await receive(a, e), isFalse);
      final next = await a.updateList(_id1, title: 'Haushalt', assignee: kBen, items: ['Müll raus', 'Spülmaschine']);
      expect((await store.log()).map((x) => x.id), [e.id]);
      expect(TaskProgress.doneNow(next, await store.log(), base).keys, [_id2]);
    });

    test('#464: gelöschte Liste (Empfang): Verlauf bleibt, neue Einträge werden nicht gespeichert', () async {
      final s = svc(kAnna);
      await s.applyIncomingList(_list());
      final old = _entry();
      expect(await receive(s, old), isTrue);
      expect(await s.applyIncomingList(tombstone), isTrue);
      expect((await store.log()).map((x) => x.id), [old.id]);
      final later = _entry(id: uuid('b000', 1), at: base.add(const Duration(minutes: 5)));
      expect(await receive(s, later), isFalse);
      expect((await store.log()).map((x) => x.id), [old.id]);
    });

    test('#464: gelöschte Liste (lokal): Verlauf bleibt, neue Einträge werden nicht gespeichert', () async {
      final a = svc(kAnna);
      await a.applyIncomingList(_list());
      final old = _entry();
      expect(await receive(a, old), isTrue);
      await a.deleteList(_id1);
      expect((await store.log()).map((x) => x.id), [old.id]);
      final later = _entry(id: uuid('b000', 1), at: base.add(const Duration(minutes: 5)));
      expect(await receive(a, later), isFalse);
      expect((await store.log()).map((x) => x.id), [old.id]);
    });

    test('#464: Löschen und gleichzeitiges Ändern: beide Reihenfolgen kommen zum selben Ergebnis', () async {
      final change = _list(version: 2, title: 'Haushalt neu', updatedAt: DateTime.utc(2026, 10, 21, 13));
      final e = _entry();

      // Reihenfolge 1: Löschmarke, Eintrag (gepuffert), dann die gewinnende Änderung.
      final s1 = svc(kAnna);
      await s1.applyIncomingList(_list());
      expect(await s1.applyIncomingList(tombstone), isTrue);
      expect(await receive(s1, e), isFalse);
      expect(await s1.applyIncomingList(change), isTrue);
      expect((await store.getList(_id1))!.deleted, isFalse);
      expect((await store.log()).map((x) => x.id), [e.id]);
      expect(TaskProgress.doneNow(change, await store.log(), base).keys, [_id2]);

      // Reihenfolge 2 (anderes Gerät): Änderung vor der Löschmarke.
      store = MemoryTaskStore();
      final s2 = svc(kAnna);
      await s2.applyIncomingList(_list());
      expect(await s2.applyIncomingList(change), isTrue);
      expect(await s2.applyIncomingList(tombstone), isFalse);
      expect(await receive(s2, e), isTrue);
      expect((await store.getList(_id1))!.deleted, isFalse);
      expect((await store.log()).map((x) => x.id), [e.id]);
      expect(TaskProgress.doneNow(change, await store.log(), base).keys, [_id2]);
    });

    test('#464: Puffer je Absender begrenzt: eine Flut verdrängt fremde Einträge nicht', () async {
      final s = svc(kAnna);
      for (var i = 0; i <= TaskLogEntry.maxPendingPerSender; i++) {
        await receive(s, _entry(id: uuid('a000', i), by: kCara, at: base.add(Duration(minutes: i))));
      }
      final e = _entry(id: uuid('b000', 1));
      expect(await receive(s, e), isFalse);
      expect(await s.applyIncomingList(_list()), isTrue);
      expect((await store.log()).map((x) => x.id), [e.id], reason: 'Caras Flut verdrängt Bens Eintrag nicht');
    });

    test('#464: Überlauf je Absender verwirft den Eintrag mit dem ältesten Zeitpunkt', () async {
      final s = svc(kAnna);
      // Backfill-Reihenfolge: jüngste zuerst, der älteste Eintrag kommt zuletzt.
      for (var i = 0; i <= TaskLogEntry.maxPendingPerSender; i++) {
        expect(await receive(s, _entry(id: uuid('a000', i), at: base.subtract(Duration(minutes: i)))), isFalse);
      }
      expect(await s.applyIncomingList(_list()), isTrue);
      final ids = (await store.log()).map((x) => x.id).toSet();
      expect(ids, hasLength(TaskLogEntry.maxPendingPerSender));
      expect(ids, isNot(contains(uuid('a000', TaskLogEntry.maxPendingPerSender))), reason: 'ältester Zeitpunkt fällt weg');
      expect(ids, contains(uuid('a000', 0)), reason: 'zuerst angekommen und jüngster: bleibt');
    });

    test('#464: volle Liste bei voller Gesamtgrenze nimmt den neuen Eintrag an', () async {
      final s = svc(kAnna);
      await s.applyIncomingList(_list());
      final otherLists = (TaskLogEntry.maxTotal - TaskLogEntry.keepPerList) ~/ TaskLogEntry.keepPerList;
      var k = 0;
      for (var l = 0; l < otherLists; l++) {
        final listId = uuid('9000', l);
        await store.putList(_list(id: listId), publishedVersion: 1);
        for (var i = 0; i < TaskLogEntry.keepPerList; i++) {
          await store.addLog(_entry(id: uuid('c000', k++), listId: listId, at: base.subtract(Duration(minutes: i + 1))),
              published: true);
        }
      }
      for (var i = 0; i < TaskLogEntry.keepPerList; i++) {
        await store.addLog(_entry(id: uuid('d000', i), at: base.subtract(Duration(minutes: i + 1))), published: true);
      }
      expect(await store.logTotal(), TaskLogEntry.maxTotal);
      final e = _entry(id: uuid('b000', 1));
      expect(await receive(s, e), isTrue);
      expect(await store.logTotal(), TaskLogEntry.maxTotal);
      expect(await store.logCount(_id1), TaskLogEntry.keepPerList);
      expect((await store.log(listId: _id1)).map((x) => x.id), contains(e.id));
    });
  });
}
