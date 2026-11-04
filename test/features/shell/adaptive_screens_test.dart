import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/startup_failure.dart';
import 'package:family_nexus/app/web_gate.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:family_nexus/data/platform/vault_key_store.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/family/family_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/nav.dart';
import '../../support/test_app.dart';

/// #274, REQ-TABLET-01: Jede Ansicht bleibt bei den Tablet-Größen und den vertauschten Maßen ohne Layoutüberlauf
/// bedienbar. Je Ansicht wird das Fenster während der Anzeige durch alle Größen geführt (also auch der Größenwechsel).
const List<Size> _sizes = <Size>[
  Size(360, 800),
  Size(600, 960),
  Size(960, 600),
  Size(800, 1280),
  Size(1280, 800),
  Size(1024, 1366),
  Size(1366, 1024),
];

class _Vault implements VaultBackend {
  @override
  bool get exists => false;
  @override
  Future<void> create(String password) async {}
  @override
  Future<void> unlock(String password) async {}
  @override
  Future<Map<String, String>> load() async => <String, String>{};
  @override
  Future<void> save(Map<String, String> entries) async {}
  @override
  Future<void> destroy() async {}
}

Future<void> _acrossSizes(WidgetTester tester, {Future<void> Function()? check, double textScale = 1}) async {
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  for (final size in _sizes) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Überlauf bei $size');
    await check?.call();
  }
  addTearDown(tester.view.reset);
}

Future<void> _pump(WidgetTester tester, TestApp app, {Size size = const Size(800, 1280)}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String entry) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, entry));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(TimeZones.ensureInitialized);

  for (final scale in <double>[1, 2]) {
    final suffix = scale == 1 ? '' : ' (Schrift 200 %)';

    testWidgets('Einstellungen$suffix', (tester) async {
      final app = await buildTestApp();
      await _pump(tester, app);
      await openSettings(tester);
      expect(find.text('Einstellungen'), findsWidgets);
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Datenschutz$suffix', (tester) async {
      final app = await buildTestApp();
      await _pump(tester, app);
      await _menu(tester, 'Datenschutzerklärung');
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Familie und Familienverwaltung$suffix', (tester) async {
      final app = await buildTestApp();
      await _pump(tester, app);
      await tester.tap(navTab('Familie'));
      await tester.pumpAndSettle();
      expect(find.byType(FamilyScreen), findsOneWidget);
      await _acrossSizes(tester, textScale: scale, check: () async {
        // Die Navigation gehört zum Fenster: nach jedem Wechsel ist genau eine vorhanden.
        expect(findNavigation(), findsOneWidget);
      });
    });

    testWidgets('Aufgaben$suffix', (tester) async {
      final app = await buildTestApp();
      await _pump(tester, app);
      await _menu(tester, 'Aufgaben');
      expect(find.text('Aufgaben'), findsWidgets);
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Terminformular$suffix', (tester) async {
      final app = await buildTestApp();
      await _pump(tester, app);
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Titel'), findsOneWidget);
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Einrichtung (Willkommen)$suffix', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      await _pump(tester, app);
      expect(findNavigation(), findsNothing);
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Sperrbildschirm$suffix', (tester) async {
      final app = await buildTestApp(lockEnabled: true);
      app.auth.succeed = false;
      await _pump(tester, app);
      expect(find.text('FamilyNexus ist gesperrt'), findsOneWidget);
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Startfehler$suffix', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1280);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(StartupFailureApp(onRetry: () {}, onReset: () async {}, sessionLost: false));
      await tester.pumpAndSettle();
      await _acrossSizes(tester, textScale: scale);
    });

    testWidgets('Browser-Entsperrung$suffix', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 1280);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(WebUnlockApp(backend: _Vault(), onUnlocked: (KeyStore keys) {}, onWipe: () async {}));
      await tester.pumpAndSettle();
      await _acrossSizes(tester, textScale: scale);
    });
  }

  testWidgets('Einladung: Konto erstellen aus dem Einladungslink', (tester) async {
    final anna = await buildTestApp();
    anna.server.now = () => DateTime.now().toUtc();
    final link = await anna.gateway.createInviteLink();
    final guest = await buildTestApp(loggedIn: false, server: anna.server);
    guest.links.initial = link;
    await _pump(tester, guest);
    expect(find.text('Schritt 1 von 3'), findsOneWidget);
    await _acrossSizes(tester);
    await _acrossSizes(tester, textScale: 2);
  });

  testWidgets('Geräteprüfung: eingehende Anfrage als Dialog', (tester) async {
    final first = await buildTestApp();
    await _pump(tester, first);
    final second = first.server.newDevice();
    await second.login(server: ServerUrl.tryParse('fake.test')!, username: 'anna', password: 'geheim123');
    await second.startVerification(userId: '@anna:fake.test', deviceId: 'DEV1');
    await tester.pumpAndSettle();
    expect(find.textContaining('möchte die Verifizierung starten'), findsOneWidget);
    await _acrossSizes(tester, check: () async => expect(find.byType(AlertDialog), findsOneWidget));
    await _acrossSizes(tester, textScale: 2);
  });
}
