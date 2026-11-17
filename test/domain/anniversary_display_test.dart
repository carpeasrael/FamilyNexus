import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_calc.dart';
import 'package:flutter_test/flutter_test.dart';

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

AnniversaryPerson person({AnniversaryDate? birth, AnniversaryDate? death}) => AnniversaryPerson(
      id: '00000000-0000-4000-8000-000000000001',
      name: 'Oma',
      birth: birth,
      death: death,
      by: '@anna:fake.test',
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AnniversaryHit hit(AnniversaryPerson p, AnniversaryKind kind, DateTime today) =>
    AnniversaryCalc.hitsOf(p, today).firstWhere((h) => h.kind == kind);

List<(AnniversaryLineKind, int)> lines(AnniversaryPerson p, AnniversaryKind kind, DateTime today) =>
    <(AnniversaryLineKind, int)>[for (final l in anniversaryLines(hit(p, kind, today), p)) (l.kind, l.number)];

void main() {
  final birth = date(3, 15, 1990);
  group('Geburtstag, Person lebt', () {
    test('d > 0: wird 36 und aktuell 35', () {
      expect(lines(person(birth: birth), AnniversaryKind.birth, DateTime.utc(2026, 3, 14)), [(AnniversaryLineKind.willBe, 36), (AnniversaryLineKind.currentAge, 35)]);
    });
    test('d = 0: nur 36 Jahre, keine wird-/aktuell-Zeile', () {
      expect(lines(person(birth: birth), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), [(AnniversaryLineKind.isAge, 36)]);
    });
    test('Säugling (Geburt im laufenden Jahr, d > 0): wird 1, aktuell 0', () {
      expect(lines(person(birth: date(1, 10, 2026)), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), [(AnniversaryLineKind.willBe, 1), (AnniversaryLineKind.currentAge, 0)]);
    });
    test('Geburt heute im laufenden Jahr (n = 0): keine Zeile', () {
      expect(lines(person(birth: date(3, 15, 2026)), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), isEmpty);
    });
    test('Jahr in der Zukunft: keine Zeile', () {
      expect(lines(person(birth: date(3, 20, 2030)), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), isEmpty);
      expect(lines(person(birth: date(12, 31, 2026)), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), isEmpty);
    });
    test('ohne Jahr: keine Zeile', () {
      expect(lines(person(birth: date(3, 20)), AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), isEmpty);
    });
  });

  group('Geburtstag, Person mit Todesdatum: wäre n, nie aktuell', () {
    final p = person(birth: birth, death: date(1, 5, 2020));
    test('d > 0 und d = 0', () {
      expect(lines(p, AnniversaryKind.birth, DateTime.utc(2026, 3, 14)), [(AnniversaryLineKind.wouldBe, 36)]);
      expect(lines(p, AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), [(AnniversaryLineKind.wouldBe, 36)]);
    });
  });

  group('Todestag', () {
    final p = person(death: date(3, 15, 2021));
    test('d > 0: 5. Todestag und vor 4 Jahren', () {
      expect(lines(p, AnniversaryKind.death, DateTime.utc(2026, 3, 14)), [(AnniversaryLineKind.nthDeathDay, 5), (AnniversaryLineKind.yearsAgo, 4)]);
    });
    test('d = 0: nur 5. Todestag', () {
      expect(lines(p, AnniversaryKind.death, DateTime.utc(2026, 3, 15)), [(AnniversaryLineKind.nthDeathDay, 5)]);
    });
    test('im laufenden Jahr (k = 0, d > 0): 1. Todestag ohne „vor 0 Jahren“', () {
      expect(lines(person(death: date(1, 10, 2026)), AnniversaryKind.death, DateTime.utc(2026, 3, 15)), [(AnniversaryLineKind.nthDeathDay, 1)]);
    });
    test('Jahr in der Zukunft oder ohne Jahr: keine Zeile', () {
      expect(lines(person(death: date(3, 20, 2030)), AnniversaryKind.death, DateTime.utc(2026, 3, 15)), isEmpty);
      expect(lines(person(death: date(3, 20)), AnniversaryKind.death, DateTime.utc(2026, 3, 15)), isEmpty);
    });
  });

  test('vergangener Kalendertag (daysUntil < 0) zeigt die Spalte „heute“', () {
    final p = person(birth: birth);
    final h = AnniversaryCalc.between(<AnniversaryPerson>[p], DateTime.utc(2026, 3, 15), DateTime.utc(2026, 3, 15), DateTime.utc(2026, 3, 20)).single;
    expect(h.daysUntil, -5);
    expect(<(AnniversaryLineKind, int)>[for (final l in anniversaryLines(h, p)) (l.kind, l.number)], [(AnniversaryLineKind.isAge, 36)]);
  });
}
