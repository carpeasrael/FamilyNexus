import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/settings/settings_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

/// #237: Im Browser gibt es keine Erinnerungen (E-53); der Untertitel von „Alle lokalen Daten löschen“
/// darf dort keine nennen, wie Abschnitt 7 der Datenschutzseite (#225).
void main() {
  for (final lang in ['de', 'en']) {
    final de = lang == 'de';
    test('$lang: Browser nennt keine Erinnerungen, nativ bleibt der Text', () {
      final l = lookupAppLocalizations(Locale(lang));
      final web = deleteDataHint(l, web: true);
      expect(web, isNot(contains(de ? 'Erinnerungen' : 'reminders')));
      expect(web, contains(de ? 'in diesem Browser' : 'in this browser'));
      expect(web, isNot(contains(de ? 'Gerät' : 'device')));
      expect(deleteDataHint(l, web: false), l.settingsDeleteDataHint);
      expect(l.settingsDeleteDataHint, contains(de ? 'Erinnerungen auf diesem Gerät' : 'reminders on this device'));
    });
  }

  testWidgets('Einstellungen zeigen außerhalb des Browsers den bisherigen Untertitel', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.ensureVisible(find.text('Alle lokalen Daten löschen'));
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Alle lokalen Daten löschen'),
        matching: find.text('Meldet dich ab und löscht Datenbank, Schlüssel und Erinnerungen auf diesem Gerät.'),
      ),
      findsOneWidget,
    );
  });
}
