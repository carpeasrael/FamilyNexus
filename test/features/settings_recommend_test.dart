import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/store_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_store.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

/// #350, #351: „App teilen“ und „App bewerten“ in den Einstellungen.
void main() {
  Future<void> open(WidgetTester tester, TestApp app) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await openSettings(tester);
    await tester.scrollUntilVisible(find.text('App teilen'), 200, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
  }

  test('Store-Link ist der öffentliche Play-Eintrag, der Text enthält sonst nur den Satz', () {
    expect(AppStoreListing.playStore.toString(), 'https://play.google.com/store/apps/details?id=de.inneso.familynexus');
    expect(AppStoreListing.shareText('Hallo'), 'Hallo\nhttps://play.google.com/store/apps/details?id=de.inneso.familynexus');
  });

  testWidgets('App teilen kopiert Satz und Store-Link, ohne Familiendaten', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clip = (call.arguments as Map<Object?, Object?>)['text'] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final app = await buildTestApp();
    await open(tester, app);
    await tester.tap(find.text('App teilen'));
    await tester.pumpAndSettle();
    expect(clip, isNotNull);
    expect(clip, contains('https://play.google.com/store/apps/details?id=de.inneso.familynexus'));
    expect(clip, isNot(contains('Familie Test')));
    expect(clip, isNot(contains('anna')));
    expect(find.text('Link zum Store-Eintrag kopiert'), findsOneWidget);
  });

  testWidgets('App bewerten öffnet den Store-Eintrag; ohne Store: Hinweis statt Absturz', (tester) async {
    final fake = FakeStoreLauncher();
    final app = await buildTestApp(storeLauncher: fake);
    await open(tester, app);
    await tester.tap(find.text('App bewerten'));
    await tester.pumpAndSettle();
    expect(fake.opened, 1);
    expect(find.text('Der Store-Eintrag konnte nicht geöffnet werden.'), findsNothing);

    fake.available = false;
    await tester.tap(find.text('App bewerten'));
    await tester.pumpAndSettle();
    expect(fake.opened, 2);
    expect(find.text('Der Store-Eintrag konnte nicht geöffnet werden.'), findsOneWidget);
  });

  testWidgets('auf Plattformen ohne bekannten Eintrag gibt es „App bewerten“ nicht, „App teilen“ schon', (tester) async {
    final app = await buildTestApp(storeLauncher: FakeStoreLauncher(canRate: false));
    await open(tester, app);
    expect(find.text('App teilen'), findsOneWidget);
    expect(find.text('App bewerten'), findsNothing);
  });

  testWidgets('englisch: Beschriftungen', (tester) async {
    final app = await buildTestApp(lang: 'en');
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Share app'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Rate app'), findsOneWidget);
  });
}
