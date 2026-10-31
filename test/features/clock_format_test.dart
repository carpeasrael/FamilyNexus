import 'package:family_nexus/features/calendar/formatting.dart';
import 'package:family_nexus/features/security/security_panel.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// #162: Uhrzeiten folgen überall Gerät (12/24 h) und App-Sprache.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  Future<String> clock(WidgetTester tester, Locale locale, {required bool use24h, int hour = 14, int minute = 30}) async {
    late String out;
    // Die Testbindung legt eine übergeordnete MediaQuery an, aus der WidgetsApp die Plattformwerte übernimmt;
    // `alwaysUse24HourFormatTestValue` kommt dort nicht an.
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(alwaysUse24HourFormat: use24h),
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) {
          out = formatClock(context, hour, minute);
          return const SizedBox();
        }),
      ),
    ));
    return out;
  }

  testWidgets('formatClock: englisch + 12-h-Gerät → AM/PM', (tester) async {
    final s = await clock(tester, const Locale('en'), use24h: false);
    expect(s, DateFormat.jm('en').format(DateTime(2000, 1, 1, 14, 30)));
    expect(s, contains('PM'));
    expect(s, startsWith('2:30'));
  });

  testWidgets('formatClock: englisch + 24-h-Gerät → 14:30', (tester) async {
    expect(await clock(tester, const Locale('en'), use24h: true), '14:30');
  });

  testWidgets('formatClock: deutsch ist 24 h, auch auf einem 12-h-Gerät', (tester) async {
    expect(await clock(tester, const Locale('de'), use24h: false), '14:30');
    expect(await clock(tester, const Locale('de'), use24h: true, hour: 2, minute: 5), '02:05');
  });

  testWidgets('formatClock: Mitternacht und Mittag im 12-h-Format', (tester) async {
    expect(await clock(tester, const Locale('en'), use24h: false, hour: 0, minute: 5), startsWith('12:05'));
    expect(await clock(tester, const Locale('en'), use24h: false, hour: 0, minute: 5), contains('AM'));
    expect(await clock(tester, const Locale('en'), use24h: false, hour: 12, minute: 0), contains('PM'));
    expect(await clock(tester, const Locale('en'), use24h: true, hour: 0, minute: 5), '00:05');
  });

  test('keyFileDate: Datum der Schlüsseldatei folgt der App-Sprache', () {
    final d = DateTime(2026, 10, 31);
    expect(keyFileDate(d, 'de'), '31.10.2026');
    expect(keyFileDate(d, 'en'), '10/31/2026');
  });
}
