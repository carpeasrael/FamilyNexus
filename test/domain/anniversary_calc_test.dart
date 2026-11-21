import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_calc.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime d(int y, int m, int day) => DateTime.utc(y, m, day);

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

AnniversaryPerson person({AnniversaryDate? birth, AnniversaryDate? death, String name = 'Oma', String id = '00000000-0000-4000-8000-000000000001'}) =>
    AnniversaryPerson(id: id, name: name, birth: birth, death: death, by: '@anna:fake.test', updatedAt: DateTime.utc(2026, 1, 1));

void main() {
  group('Geburtstag 15.03.1990', () {
    final b = date(3, 15, 1990);
    test('heute 14.03.2026: 35 / 36 / 1 Tag', () {
      final t = d(2026, 3, 14);
      expect((AnniversaryCalc.yearsSince(b, t), AnniversaryCalc.ageAtNext(b, t), AnniversaryCalc.daysUntil(b, t)), (35, 36, 1));
    });
    test('heute 15.03.2026: 36 / 36 / 0', () {
      final t = d(2026, 3, 15);
      expect((AnniversaryCalc.yearsSince(b, t), AnniversaryCalc.ageAtNext(b, t), AnniversaryCalc.daysUntil(b, t)), (36, 36, 0));
    });
    test('heute 16.03.2026: 36 / 37 / 364, nächstes 15.03.2027', () {
      final t = d(2026, 3, 16);
      expect((AnniversaryCalc.yearsSince(b, t), AnniversaryCalc.ageAtNext(b, t), AnniversaryCalc.daysUntil(b, t)), (36, 37, 364));
      expect(AnniversaryCalc.nextOccurrence(b, t), d(2027, 3, 15));
    });
    test('Jahreswechsel: heute 31.12.2026, Eintrag 01.01.1990 in 1 Tag, Alter bezieht 2027 ein', () {
      final e = date(1, 1, 1990);
      final t = d(2026, 12, 31);
      expect(AnniversaryCalc.daysUntil(e, t), 1);
      expect(AnniversaryCalc.ageAtNext(e, t), 37);
      expect(AnniversaryCalc.yearsSince(e, t), 36);
    });
    test('ohne Jahr: kein Alter', () {
      final e = date(3, 15);
      expect(AnniversaryCalc.yearsSince(e, d(2026, 3, 14)), isNull);
      expect(AnniversaryCalc.ageAtNext(e, d(2026, 3, 14)), isNull);
      expect(AnniversaryCalc.daysUntil(e, d(2026, 3, 14)), 1);
    });
  });

  group('29.2.-Regel (Eintrag 29.02.2000)', () {
    final e = date(2, 29, 2000);
    test('wirksames Datum: 29.2. im Schaltjahr, 28.2. sonst', () {
      expect(AnniversaryCalc.effectiveDate(e, 2024), d(2024, 2, 29));
      expect(AnniversaryCalc.effectiveDate(e, 2025), d(2025, 2, 28));
      expect(AnniversaryCalc.effectiveDate(e, 2100), d(2100, 2, 28), reason: '2100 ist kein Schaltjahr');
      expect(AnniversaryCalc.effectiveDate(e, 2000), d(2000, 2, 29));
    });
    test('heute 27.02.2025: nächstes 28.02.2025', () {
      expect(AnniversaryCalc.nextOccurrence(e, d(2025, 2, 27)), d(2025, 2, 28));
    });
    test('heute 28.02.2025: erreicht, 25 / 25 / 0', () {
      final t = d(2025, 2, 28);
      expect((AnniversaryCalc.yearsSince(e, t), AnniversaryCalc.ageAtNext(e, t), AnniversaryCalc.daysUntil(e, t)), (25, 25, 0));
    });
    test('heute 01.03.2025: yearsSince 25, nächstes 28.02.2026, ageAtNext 26, 364 Tage', () {
      final t = d(2025, 3, 1);
      expect(AnniversaryCalc.yearsSince(e, t), 25);
      expect(AnniversaryCalc.nextOccurrence(e, t), d(2026, 2, 28));
      expect(AnniversaryCalc.ageAtNext(e, t), 26);
      expect(AnniversaryCalc.daysUntil(e, t), 364);
    });
    test('Schaltjahrfall: heute 01.03.2027 → nächstes 29.02.2028, Alter 28; heute 29.02.2028 → 28', () {
      expect(AnniversaryCalc.nextOccurrence(e, d(2027, 3, 1)), d(2028, 2, 29));
      expect(AnniversaryCalc.ageAtNext(e, d(2027, 3, 1)), 28);
      expect(AnniversaryCalc.ageAtNext(e, d(2028, 2, 29)), 28);
      expect(AnniversaryCalc.daysUntil(e, d(2028, 2, 29)), 0);
    });
  });

  group('dueWithin', () {
    final people = <AnniversaryPerson>[person(birth: date(3, 22, 1950))];
    final today = d(2026, 3, 15);
    test('Tag 7 enthalten, Tag 8 nicht (Vorlauf 7)', () {
      expect(AnniversaryCalc.dueWithin(people, today, 7), hasLength(1));
      expect(AnniversaryCalc.dueWithin(people, d(2026, 3, 14), 7), isEmpty, reason: 'Tag 8');
    });
    test('Vorlauf 0: nur der Tag selbst', () {
      expect(AnniversaryCalc.dueWithin(people, d(2026, 3, 22), 0), hasLength(1));
      expect(AnniversaryCalc.dueWithin(people, d(2026, 3, 21), 0), isEmpty);
    });
    test('Vorlauf 60: Tag 60 enthalten, Tag 61 nicht', () {
      expect(AnniversaryCalc.dueWithin(people, d(2026, 1, 21), 60), hasLength(1), reason: '60 Tage');
      expect(AnniversaryCalc.dueWithin(people, d(2026, 1, 20), 60), isEmpty, reason: '61 Tage');
    });
    test('Todestag zählt ebenso, Geburts- und Todestag einer Person ergeben zwei Treffer', () {
      final both = <AnniversaryPerson>[person(birth: date(3, 22, 1950), death: date(3, 18, 2010))];
      final hits = AnniversaryCalc.dueWithin(both, today, 7);
      expect(hits.map((h) => h.kind), <AnniversaryKind>[AnniversaryKind.death, AnniversaryKind.birth], reason: 'nach Datum sortiert');
      expect(AnniversaryCalc.dueWithin(both, today, 3).single.kind, AnniversaryKind.death);
    });
    test('Gleicher Tag: erst Name (ohne Groß-/Kleinschreibung), dann Art (#550)', () {
      final ps = <AnniversaryPerson>[
        AnniversaryPerson(id: '00000000-0000-4000-8000-000000000002', name: 'berta', birth: date(3, 22, 1950), by: '@a:b.c', updatedAt: DateTime.utc(2026, 1, 1)),
        AnniversaryPerson(id: '00000000-0000-4000-8000-000000000001', name: 'Anna', birth: date(3, 22, 1950), death: date(3, 22, 2010), by: '@a:b.c', updatedAt: DateTime.utc(2026, 1, 1)),
      ];
      final hits = AnniversaryCalc.upcoming(ps, today);
      expect(hits.map((h) => '${h.person.name}/${h.kind.name}'), <String>['Anna/birth', 'Anna/death', 'berta/birth']);
    });
    test('Löschmarken zählen nicht', () {
      final gone = AnniversaryPerson(id: '00000000-0000-4000-8000-000000000009', name: '', deleted: true, by: '@a:b.c', updatedAt: DateTime.utc(2026, 1, 1));
      expect(AnniversaryCalc.dueWithin(<AnniversaryPerson>[gone], today, 60), isEmpty);
    });
  });

  group('between (Kalender)', () {
    test('findet 29.2. im Nichtschaltjahr am 28.2.; über Jahreswechsel', () {
      final p = <AnniversaryPerson>[person(birth: date(2, 29, 2000)), person(birth: date(1, 1, 1990), id: '00000000-0000-4000-8000-000000000002')];
      final hits = AnniversaryCalc.between(p, d(2025, 2, 25), d(2025, 3, 3), d(2025, 3, 1));
      expect(hits.single.occursOn, d(2025, 2, 28));
      expect(hits.single.daysUntil, -1, reason: 'vergangener Tag');
      expect(hits.single.ageAtNext, 25);
      final year = AnniversaryCalc.between(p, d(2026, 12, 28), d(2027, 1, 3), d(2026, 12, 31));
      expect(year.single.occursOn, d(2027, 1, 1));
      expect(year.single.ageAtNext, 37);
    });

    group('keine Treffer vor dem Jahr des Datums (#575)', () {
      final today = d(2026, 11, 21);
      test('(a) Todestag 15.03.2024: 2023 leer, 2024 mit Alter 0, 2025 mit Alter 1', () {
        final p = <AnniversaryPerson>[person(death: date(3, 15, 2024))];
        expect(AnniversaryCalc.between(p, d(2023, 1, 1), d(2023, 12, 31), today), isEmpty);
        final y24 = AnniversaryCalc.between(p, d(2024, 1, 1), d(2024, 12, 31), today);
        expect((y24.single.occursOn, y24.single.ageAtNext), (d(2024, 3, 15), 0));
        final y25 = AnniversaryCalc.between(p, d(2025, 1, 1), d(2025, 12, 31), today);
        expect(y25.single.ageAtNext, 1);
      });
      test('(b) Geburtstag 10.05.2021, Bereich 2019 bis 2023: nur 2021 bis 2023', () {
        final p = <AnniversaryPerson>[person(birth: date(5, 10, 2021))];
        final hits = AnniversaryCalc.between(p, d(2019, 1, 1), d(2023, 12, 31), today);
        expect(hits.map((h) => h.occursOn.year), <int>[2021, 2022, 2023]);
        expect(hits.map((h) => h.ageAtNext), <int>[0, 1, 2]);
      });
      test('(c) Datum ohne Jahr: Treffer in jedem Jahr', () {
        final p = <AnniversaryPerson>[person(birth: date(5, 10))];
        final hits = AnniversaryCalc.between(p, d(2019, 1, 1), d(2023, 12, 31), today);
        expect(hits.map((h) => h.occursOn.year), <int>[2019, 2020, 2021, 2022, 2023]);
        expect(hits.every((h) => h.ageAtNext == null), isTrue);
      });
      test('(d) 29.02.2020: 2019 leer, 2021 liefert den 28.02.', () {
        final p = <AnniversaryPerson>[person(birth: date(2, 29, 2020))];
        expect(AnniversaryCalc.between(p, d(2019, 1, 1), d(2019, 12, 31), today), isEmpty);
        final h = AnniversaryCalc.between(p, d(2021, 1, 1), d(2021, 12, 31), today);
        expect(h.single.occursOn, d(2021, 2, 28));
        expect(h.single.ageAtNext, 1);
      });
      test('(e) Bereich über den Jahreswechsel mit Datum 01.01.2024', () {
        final p = <AnniversaryPerson>[person(birth: date(1, 1, 2024))];
        final h = AnniversaryCalc.between(p, d(2023, 12, 28), d(2024, 1, 3), today);
        expect((h.single.occursOn, h.single.ageAtNext), (d(2024, 1, 1), 0));
      });
    });
  });
}
