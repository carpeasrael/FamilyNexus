import 'package:family_nexus/domain/event_theme_service.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_event_theme_store.dart';

const String kAnna = '@anna:fake.test';
const String kBen = '@ben:fake.test';
const String kCara = '@cara:fake.test';

EventTheme _t(
  int n, {
  String? name,
  int color = 2,
  String by = kAnna,
  int version = 1,
  bool deleted = false,
  DateTime? at,
}) =>
    EventTheme(
      id: '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}',
      name: deleted ? '' : (name ?? 'Thema $n'),
      colorIndex: color,
      by: by,
      version: version,
      deleted: deleted,
      updatedAt: at ?? DateTime.utc(2026, 10, 21, 12),
    );

void main() {
  late MemoryEventThemeStore store;
  late DateTime clock;
  var n = 100;

  EventThemeService svc(String me, {Set<String> mods = const {kAnna, kCara}}) => EventThemeService(
        store: store,
        myUserId: me,
        isModerator: mods.contains,
        clock: () => clock,
        idGenerator: () => '00000000-0000-4000-8000-${(++n).toString().padLeft(12, '0')}',
      );

  setUp(() {
    store = MemoryEventThemeStore();
    clock = DateTime.utc(2026, 10, 22, 10);
  });

  Matcher throwsTheme(EventThemeError e) => throwsA(isA<EventThemeException>().having((x) => x.error, 'error', e));

  group('Rechte', () {
    test('nur Moderatoren legen an, ändern und löschen', () async {
      await expectLater(svc(kBen).create(name: 'Schule', colorIndex: 2), throwsTheme(EventThemeError.notAllowed));
      final th = await svc(kAnna).create(name: '  Schule ', colorIndex: 2);
      expect(th.name, 'Schule', reason: 'Leerraum bereinigt');
      expect(th.by, kAnna);
      expect(th.version, 1);
      expect(await store.pending(), [th], reason: 'noch nicht gesendet');
      await expectLater(svc(kBen).rename(th.id, 'x'), throwsTheme(EventThemeError.notAllowed));
      await expectLater(svc(kBen).recolor(th.id, 4), throwsTheme(EventThemeError.notAllowed));
      await expectLater(svc(kBen).delete(th.id), throwsTheme(EventThemeError.notAllowed));
    });

    test('Himmelblau und ungültige Namen werden beim Anlegen abgelehnt', () async {
      await expectLater(svc(kAnna).create(name: 'Privat', colorIndex: 3), throwsTheme(EventThemeError.invalid));
      await expectLater(svc(kAnna).create(name: '   ', colorIndex: 2), throwsTheme(EventThemeError.invalid));
      await expectLater(svc(kAnna).create(name: 'a' * 31, colorIndex: 2), throwsTheme(EventThemeError.invalid));
      expect(await store.all(), isEmpty);
    });

    test('Umbenennen, Farbe ändern und Löschen erhöhen die Version', () async {
      final a = svc(kAnna);
      final th = await a.create(name: 'Schule', colorIndex: 2);
      final r = await a.rename(th.id, 'Uni');
      expect((r.name, r.colorIndex, r.version), ('Uni', 2, 2));
      final c = await a.recolor(th.id, 5);
      expect((c.name, c.colorIndex, c.version), ('Uni', 5, 3));
      await expectLater(a.recolor(th.id, 3), throwsTheme(EventThemeError.invalid));
      await a.delete(th.id);
      final dead = (await store.get(th.id))!;
      expect((dead.deleted, dead.name, dead.version), (true, '', 4));
      await expectLater(a.rename(th.id, 'x'), throwsTheme(EventThemeError.notFound));
      await expectLater(a.delete(th.id), throwsTheme(EventThemeError.notFound));
      await expectLater(a.rename('00000000-0000-4000-8000-0000000000ff', 'x'), throwsTheme(EventThemeError.notFound));
    });

    test('Versionsgrenze beim lokalen Ändern', () async {
      final a = svc(kAnna);
      final th = await a.create(name: 'Schule', colorIndex: 2);
      await store.put(th.copyWith(version: EventTheme.maxVersion));
      await expectLater(a.rename(th.id, 'x'), throwsTheme(EventThemeError.limit));
      await expectLater(a.delete(th.id), throwsTheme(EventThemeError.limit));
    });
  });

  group('Grenzen', () {
    test('höchstens 12 aktive Themen', () async {
      final a = svc(kAnna);
      for (var i = 0; i < EventTheme.maxActive; i++) {
        await a.create(name: 'T$i', colorIndex: 0);
      }
      await expectLater(a.create(name: 'zu viel', colorIndex: 0), throwsTheme(EventThemeError.limit));
      // Löschen gibt einen aktiven Platz frei.
      await a.delete((await store.all()).first.id);
      await a.create(name: 'wieder frei', colorIndex: 0);
      expect((await store.counts()).active, EventTheme.maxActive);
    });

    test('höchstens 40 Datensätze: veröffentlichte Löschmarken werden auf 10 gekürzt', () async {
      for (var i = 1; i <= EventTheme.maxTotal; i++) {
        await store.put(_t(i, deleted: true, version: 2), publishedVersion: 2);
      }
      expect((await store.counts()).total, EventTheme.maxTotal);
      await svc(kAnna).create(name: 'neu', colorIndex: 0);
      final c = await store.counts();
      expect(c.active, 1);
      expect(c.total, EventTheme.keepTombstones + 1, reason: '10 Löschmarken bleiben, dazu das neue Thema');
    });

    test('unveröffentlichte Löschmarken werden nicht gekürzt: Grenze erreicht', () async {
      for (var i = 1; i <= EventTheme.maxTotal; i++) {
        await store.put(_t(i, deleted: true, version: 2), publishedVersion: 0);
      }
      await expectLater(svc(kAnna).create(name: 'neu', colorIndex: 0), throwsTheme(EventThemeError.limit));
    });

    test('Empfang: höchstens 12 aktive neue Themen, Löschmarken passen weiter, Gesamtgrenze', () async {
      final s = svc(kBen);
      for (var i = 1; i <= EventTheme.maxActive; i++) {
        expect(await s.applyIncoming(_t(i)), isTrue);
      }
      expect(await s.applyIncoming(_t(50)), isFalse, reason: 'dreizehntes aktives Thema');
      expect(await s.applyIncoming(_t(51, deleted: true, version: 2)), isTrue, reason: 'Löschmarken zählen nicht als aktiv');
      // Auf 40 auffüllen: alle weiteren neuen Datensätze (auch Löschmarken) werden abgelehnt, sobald nichts zu kürzen ist.
      for (var i = 60; i < 60 + EventTheme.maxTotal - 13; i++) {
        expect(await s.applyIncoming(_t(i, deleted: true, version: 2)), isTrue, reason: '$i');
      }
      expect((await store.counts()).total, EventTheme.maxTotal);
    });

    test('Empfang: Löschmarken-Bereinigung bei voller Ablage', () async {
      final s = svc(kBen);
      for (var i = 1; i <= EventTheme.maxTotal; i++) {
        await store.put(_t(i, deleted: true, version: 2), publishedVersion: 2);
      }
      expect(await s.applyIncoming(_t(500)), isTrue);
      expect((await store.counts()).total, EventTheme.keepTombstones + 1);
    });

    test('Empfang: erste Version höchstens 10000, Versionssprung höchstens 1000, maxVersion', () async {
      final s = svc(kBen);
      expect(await s.applyIncoming(_t(1, version: EventTheme.maxFirstVersion + 1)), isFalse);
      expect(await s.applyIncoming(_t(1, version: EventTheme.maxFirstVersion)), isTrue);
      expect(await s.applyIncoming(_t(2)), isTrue);
      expect(await s.applyIncoming(_t(2, version: 1 + EventTheme.maxVersionJump + 1)), isFalse, reason: 'Sprung zu groß');
      expect(await s.applyIncoming(_t(2, version: 1 + EventTheme.maxVersionJump)), isTrue, reason: 'Sprung genau am Limit');
      // maxVersion gilt schon beim Dekodieren/Validieren; der Dienst nimmt nichts darüber an.
      expect(_t(3, version: EventTheme.maxVersion + 1).validate(), contains('version'));
    });
  });

  group('Empfang und Konflikte', () {
    test('Thema eines Nicht-Moderators wird verworfen', () async {
      final s = svc(kBen);
      expect(await s.applyIncoming(_t(1, by: kBen)), isFalse);
      expect(await store.all(), isEmpty);
      expect(await s.applyIncoming(_t(1, by: kAnna)), isTrue);
      expect(await s.applyIncoming(_t(1, by: kAnna)), isFalse, reason: 'gleiche Fassung');
      expect((await store.pending()), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
    });

    test('Moderatorprüfung gilt zum Zeitpunkt des Empfangs; Angenommenes bleibt nach Herabstufung', () async {
      var mods = <String>{kAnna};
      final s = EventThemeService(store: store, myUserId: kBen, isModerator: (id) => mods.contains(id));
      expect(await s.applyIncoming(_t(1, by: kAnna)), isTrue);
      mods = <String>{kCara};
      expect(await s.applyIncoming(_t(2, by: kAnna)), isFalse);
      expect((await store.get(_t(1).id)), isNotNull, reason: 'bereits angenommen: bleibt gültig (dokumentierte Grenze)');
    });

    test('zwei Moderatoren, zwei verschiedene Themen: beide bleiben erhalten', () async {
      final s = svc(kBen);
      expect(await s.applyIncoming(_t(1, name: 'Schule', by: kAnna)), isTrue);
      expect(await s.applyIncoming(_t(2, name: 'Sport', by: kCara)), isTrue);
      expect((await store.all()).map((t) => t.name).toSet(), {'Schule', 'Sport'});
    });

    test('zwei Moderatoren, dasselbe Thema, gleiche Version: spätere Zeit gewinnt, dann Absender-ID', () async {
      final s = svc(kBen);
      final a = _t(1, name: 'Von Anna', by: kAnna, version: 2);
      final c = _t(1, name: 'Von Cara', by: kCara, version: 2, at: DateTime.utc(2026, 10, 21, 13));
      expect(await s.applyIncoming(a), isTrue);
      expect(await s.applyIncoming(c), isTrue, reason: 'spätere Zeit');
      expect((await store.get(a.id))!.name, 'Von Cara');
      expect(await s.applyIncoming(a), isFalse, reason: 'ältere Zeit verliert');
      // Gleiche Zeit: größere Absender-ID gewinnt (reihenfolgeunabhängig).
      final s2Store = MemoryEventThemeStore();
      final s2 = EventThemeService(store: s2Store, myUserId: kBen, isModerator: {kAnna, kCara}.contains);
      final x = _t(9, name: 'X', by: kAnna, version: 2);
      final y = _t(9, name: 'Y', by: kCara, version: 2);
      await s2.applyIncoming(y);
      await s2.applyIncoming(x);
      expect((await s2Store.get(x.id))!.by, kCara);
    });

    test('höhere Version gewinnt, Löschmarke setzt sich durch, ältere Fassung nicht', () async {
      final s = svc(kBen);
      expect(await s.applyIncoming(_t(1, name: 'Schule')), isTrue);
      expect(await s.applyIncoming(_t(1, deleted: true, version: 2)), isTrue);
      expect((await store.get(_t(1).id))!.deleted, isTrue);
      expect(await s.applyIncoming(_t(1, name: 'Schule', version: 1)), isFalse, reason: 'ältere Version');
    });

    test('lokale Änderungen laufen nacheinander (kein Verlust bei gleichzeitigem Anlegen)', () async {
      final a = svc(kAnna);
      final all = await Future.wait(<Future<EventTheme>>[for (var i = 0; i < 5; i++) a.create(name: 'T$i', colorIndex: 0)]);
      expect(all.map((t) => t.id).toSet(), hasLength(5));
      expect((await store.counts()).active, 5);
    });
  });

  group('Ablage', () {
    test('pending, markPublished und requeueLastEditedBy', () async {
      final a = svc(kAnna);
      final th = await a.create(name: 'Schule', colorIndex: 2);
      await store.markPublished(th.id, 1);
      expect(await store.pending(), isEmpty);
      await store.requeueLastEditedBy(kBen);
      expect(await store.pending(), isEmpty, reason: 'nur Eigenes wird erneut vorgemerkt');
      await store.requeueLastEditedBy(kAnna);
      expect(await store.pending(), [th]);
      await store.wipe();
      expect(await store.all(), isEmpty);
    });
  });
}
