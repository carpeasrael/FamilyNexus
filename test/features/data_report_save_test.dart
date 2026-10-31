import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/features/settings/data_report_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('#136: Abgebrochenes Speichern des Protokolls meldet keinen Erfolg', (tester) async {
    final app = await buildTestApp();
    await tester.pumpWidget(AppScope(
      services: app.services,
      child: MaterialApp(
        theme: buildTheme(Brightness.dark),
        locale: const Locale('de'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DataReportScreen(kind: DataReportKind.online),
      ),
    ));
    await tester.pumpAndSettle();
    final files = app.services.files as FakeFileAccess;

    files.cancelSave = true;
    await tester.tap(find.byTooltip('Als Datei speichern'));
    await tester.pumpAndSettle();
    expect(files.saved, isEmpty);
    expect(find.text('Protokoll gespeichert.'), findsNothing);

    files.cancelSave = false;
    await tester.tap(find.byTooltip('Als Datei speichern'));
    await tester.pumpAndSettle();
    expect(files.saved, hasLength(1));
    expect(find.text('Protokoll gespeichert.'), findsOneWidget);
  });
}
