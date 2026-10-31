import 'package:family_nexus/domain/task_period.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);
  final berlin = TimeZones.tryGet('Europe/Berlin')!;

  test('#163: Uhrzeit in der Zone der Liste, passend zum Datum (localClock)', () {
    // 02:00 UTC am 23.10. ist in Berlin (MESZ) 04:00 am 23.10.; in New York wäre es 22:00 am 22.10.
    final t = DateTime.utc(2026, 10, 23, 2);
    expect(TaskPeriod.localDate(berlin, t), '2026-10-23');
    expect(TaskPeriod.localClock(berlin, t), (hour: 4, minute: 0));
    final ny = TimeZones.tryGet('America/New_York')!;
    expect(TaskPeriod.localDate(ny, t), '2026-10-22');
    expect(TaskPeriod.localClock(ny, t), (hour: 22, minute: 0));
    // Zeitumstellung (25.10.2026, 03:00 MESZ → 02:00 MEZ): dieselbe Wanduhr, verschiedene Zeitpunkte.
    expect(TaskPeriod.localClock(berlin, DateTime.utc(2026, 10, 25, 0, 30)), (hour: 2, minute: 30));
    expect(TaskPeriod.localClock(berlin, DateTime.utc(2026, 10, 25, 1, 30)), (hour: 2, minute: 30));
    // Eine Zone mit halber Stunde Versatz.
    expect(TaskPeriod.localClock(TimeZones.tryGet('Asia/Kolkata')!, DateTime.utc(2026, 10, 23, 0, 0)), (hour: 5, minute: 30));
  });

  test('täglich: lokales Datum, nicht UTC-Datum', () {
    // 22:30 UTC am 21.10. ist in Berlin (UTC+2) bereits der 22.10.
    final t = DateTime.utc(2026, 10, 21, 22, 30);
    expect(TaskPeriod.key(TaskInterval.daily, berlin, t), '2026-10-22');
    expect(TaskPeriod.key(TaskInterval.daily, TimeZones.utc, t), '2026-10-21');
  });

  test('Tageswechsel genau um lokale Mitternacht (auch über die Sommerzeitumstellung)', () {
    expect(TaskPeriod.key(TaskInterval.daily, berlin, DateTime.utc(2026, 10, 24, 21, 59, 59)), '2026-10-24');
    expect(TaskPeriod.key(TaskInterval.daily, berlin, DateTime.utc(2026, 10, 24, 22)), '2026-10-25');
    // Umstellung am 25.10.2026 (03:00 → 02:00): der 25.10. dauert 25 Stunden.
    expect(TaskPeriod.key(TaskInterval.daily, berlin, DateTime.utc(2026, 10, 25, 22, 59)), '2026-10-25');
    expect(TaskPeriod.key(TaskInterval.daily, berlin, DateTime.utc(2026, 10, 25, 23)), '2026-10-26');
  });

  test('wöchentlich: ISO-Woche, Montag bis Sonntag', () {
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2026-10-19'), '2026-W43', reason: 'Montag');
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2026-10-25'), '2026-W43', reason: 'Sonntag');
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2026-10-26'), '2026-W44', reason: 'nächster Montag');
  });

  test('wöchentlich: Jahresgrenzen folgen dem Donnerstag der Woche', () {
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2026-01-01'), '2026-W01');
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2024-12-30'), '2025-W01', reason: 'Montag gehört schon zu 2025');
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2021-01-03'), '2020-W53', reason: 'Sonntag noch zu 2020');
    expect(TaskPeriod.keyForDate(TaskInterval.weekly, '2020-12-31'), '2020-W53');
  });

  test('monatlich: Monatswechsel inkl. Schaltjahr', () {
    expect(TaskPeriod.keyForDate(TaskInterval.monthly, '2028-02-29'), '2028-02');
    expect(TaskPeriod.keyForDate(TaskInterval.monthly, '2028-03-01'), '2028-03');
    expect(TaskPeriod.key(TaskInterval.monthly, berlin, DateTime.utc(2026, 10, 31, 23)), '2026-11',
        reason: '23:00 UTC am 31.10. ist in Berlin schon der 1.11.');
  });

  test('ungültige Daten werden abgelehnt', () {
    for (final bad in <String>['2026-02-30', '2026-13-01', '2026-1-1', '1999-12-31', '2101-01-01', '', 'x', '2026-10-22 ']) {
      expect(TaskPeriod.parseDate(bad), isNull, reason: bad);
      expect(TaskPeriod.keyForDate(TaskInterval.daily, bad), isNull, reason: bad);
    }
  });

  test('isKey akzeptiert nur bekannte Formate', () {
    for (final ok in <String>['2026-10-22', '2026-W43', '2026-10']) {
      expect(TaskPeriod.isKey(ok), isTrue, reason: ok);
    }
    for (final bad in <String>['', '2026', '2026-W4', 'abc', '2026-10-22-1', '2026-10-22\n']) {
      expect(TaskPeriod.isKey(bad), isFalse, reason: bad);
    }
  });

  test('Rückfallzone UTC (Gerätezeitzone unbekannt) ist gültig', () {
    expect(TimeZones.tryGet('UTC'), isNotNull);
    expect(TaskPeriod.key(TaskInterval.daily, TimeZones.tryGet('UTC')!, DateTime.utc(2026, 10, 21, 23, 59)), '2026-10-21');
  });
}
