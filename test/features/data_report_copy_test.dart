import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/features/settings/data_report_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #157: Das Datenprotokoll (alle Inhalte im Klartext) wird wie der Notfall-Schlüssel (SA-8) als vertraulich
/// kopiert und nach einer Minute geleert – auch wenn es länger als 512 Zeichen ist.
void main() {
  const window = MethodChannel('de.inneso.familynexus/window');

  Future<void> open(WidgetTester tester, TestApp app, {Locale locale = const Locale('de')}) async {
    await tester.pumpWidget(AppScope(
      services: app.services,
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DataReportScreen(kind: DataReportKind.online),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Zwischenablage und eigener Kanal werden gemockt; [adapter] bestimmt die Antwort des Kanals.
  ({String? Function() clipboard, List<String> sensitive}) mock(WidgetTester tester, Future<Object?> Function(MethodCall) adapter) {
    String? clipboard;
    final sensitive = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      if (call.method == 'Clipboard.getData') return <String, Object?>{'text': clipboard};
      return null;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, (call) async {
      if (call.method == 'copySensitive') sensitive.add(call.arguments as String);
      final r = await adapter(call);
      if (call.method == 'copySensitive' && r == null) clipboard = call.arguments as String;
      return r;
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(window, null);
    });
    return (clipboard: () => clipboard, sensitive: sensitive);
  }

  testWidgets('Protokoll wird als vertraulich kopiert (auch > 512 Zeichen) und nach einer Minute geleert', (tester) async {
    final app = await buildTestApp();
    final m = mock(tester, (_) async => null);
    await open(tester, app);

    await tester.tap(find.byTooltip('Kopieren'));
    await tester.pumpAndSettle();
    expect(m.sensitive, hasLength(1), reason: 'über den vertraulichen Kanal, nicht über Clipboard.setData');
    expect(m.sensitive.single.length, greaterThan(512), reason: 'die 512er-Grenze des Notfall-Schlüssels gilt hier nicht');
    expect(m.clipboard(), m.sensitive.single);
    expect(find.textContaining('versucht'), findsOneWidget, reason: 'keine feste Zusage (#148)');

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(m.clipboard(), '', reason: 'Protokoll bleibt nicht in der Zwischenablage');
  });

  testWidgets('Fehler im nativen Adapter: Rückfall auf die normale Zwischenablage, geleert wird trotzdem', (tester) async {
    final app = await buildTestApp();
    final m = mock(tester, (call) async {
      if (call.method == 'copySensitive') throw PlatformException(code: 'failed');
      return null;
    });
    await open(tester, app);

    await tester.tap(find.byTooltip('Kopieren'));
    await tester.pumpAndSettle();
    expect(m.sensitive, hasLength(1));
    expect(m.clipboard(), isNotEmpty, reason: 'Rückfall: normal kopiert');

    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(m.clipboard(), '');
  });

  test('reportCopied: keine feste Zusage (de, en)', () {
    expect(lookupAppLocalizations(const Locale('de')).reportCopied, contains('versucht'));
    expect(lookupAppLocalizations(const Locale('en')).reportCopied, contains('tries'));
  });
}
