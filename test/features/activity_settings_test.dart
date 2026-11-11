import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/data/sync/activity_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/nav.dart';
import '../support/test_app.dart';

class _Platform implements ActivityPlatform {
  @override
  Future<void> show(ActivityKind kind, {required bool alert, int count = 0}) async {}

  @override
  Future<void> cancel(ActivityKind kind) async {}
}

/// #254: Schalter „Benachrichtigungen“ in den Einstellungen.
void main() {
  Future<void> open(WidgetTester tester, TestApp app) async {
    // Hohe Fläche: Die Liste baut sonst nicht alle Schalter.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('Neue Chat-Nachrichten'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Schalter sind an, Hinweis „nur solange die App läuft“; Ausschalten speichert, Einschalten fragt nur Benachrichtigungen an',
      (tester) async {
    final app = await buildTestApp(activity: _Platform());
    app.scheduler.current = ReminderPermission.notificationsDenied;
    await open(tester, app);
    expect(find.text('Benachrichtigungen'), findsWidgets);
    expect(find.textContaining('nur solange die App läuft'), findsOneWidget);
    final chat = find.widgetWithText(SwitchListTile, 'Neue Chat-Nachrichten');
    final shopping = find.widgetWithText(SwitchListTile, 'Neue Einträge auf dem Einkaufszettel');
    expect(tester.widget<SwitchListTile>(chat).value, isTrue);
    expect(tester.widget<SwitchListTile>(shopping).value, isTrue);

    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.notifyChat, isFalse);
    expect(app.scheduler.notificationsRequested, 0);

    await tester.tap(chat);
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.notifyChat, isTrue);
    expect(app.scheduler.notificationsRequested, 1);
    expect(app.scheduler.requested, 0, reason: 'keine genauen Alarme');

    await tester.tap(shopping);
    await tester.pumpAndSettle();
    expect(app.services.settings.settings.notifyShopping, isFalse);
  });

  testWidgets('ohne Plattform-Meldungen (Browser) kein Abschnitt', (tester) async {
    final app = await buildTestApp();
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    expect(find.text('Neue Chat-Nachrichten', skipOffstage: false), findsNothing);
  });
}
