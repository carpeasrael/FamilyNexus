import 'package:family_nexus/domain/year_progress.dart';
import 'package:flutter_test/flutter_test.dart';

/// #337: Tag im Jahr, verbleibende Tage und Prozent.
void main() {
  test('1. Januar: Tag 1, noch 364 Tage, 0 %', () {
    final p = YearProgress.of(DateTime.utc(2026));
    expect((p.dayOfYear, p.daysInYear, p.daysLeft, p.percent), (1, 365, 364, 0));
  });

  test('31. Dezember: letzter Tag, noch 0 Tage, 100 %', () {
    final p = YearProgress.of(DateTime.utc(2026, 12, 31));
    expect((p.dayOfYear, p.daysLeft, p.percent, p.fraction), (365, 0, 100, 1.0));
  });

  test('Schaltjahr hat 366 Tage; 29. Februar ist Tag 60', () {
    final p = YearProgress.of(DateTime.utc(2028, 2, 29));
    expect((p.dayOfYear, p.daysInYear, p.daysLeft), (60, 366, 306));
    expect(YearProgress.of(DateTime.utc(2100, 12, 31)).daysInYear, 365, reason: '2100 ist kein Schaltjahr');
    expect(YearProgress.of(DateTime.utc(2000, 12, 31)).daysInYear, 366);
  });

  test('Mitte des Jahres: 2. Juli 2026 ist Tag 183, 50 %', () {
    final p = YearProgress.of(DateTime.utc(2026, 7, 2));
    expect((p.dayOfYear, p.percent), (183, 50));
  });

  test('Uhrzeit und Zeitzone ändern den Tag nicht: nur Jahr, Monat, Tag zählen', () {
    expect(YearProgress.of(DateTime(2026, 3, 1, 23, 59)).dayOfYear, 60);
    expect(YearProgress.of(DateTime.utc(2026, 3, 1, 23, 59)).dayOfYear, 60);
  });
}
