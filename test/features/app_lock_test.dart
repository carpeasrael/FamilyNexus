import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/lock/app_lock_controller.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_device_auth.dart';
import '../support/memory_stores.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

Future<(AppLockController, FakeDeviceAuth, SettingsController, DateTime Function())> _make({
  bool enabled = true,
  int timeout = 60,
}) async {
  final store = MemoryKeyValueStore();
  if (enabled) store.data['lockEnabled'] = 'true';
  store.data['lockTimeout'] = '$timeout';
  final settings = await SettingsController.load(store);
  final auth = FakeDeviceAuth();
  var now = DateTime.utc(2026, 10, 21, 12);
  final c = AppLockController(settings: settings, auth: auth, clock: () => now);
  // Zeit steuerbar machen
  return (c, auth, settings, () => now = now.add(const Duration(seconds: 1)));
}

void main() {
  group('AppLockController', () {
    test('ist beim Kaltstart gesperrt, wenn aktiviert; sonst nie', () async {
      expect((await _make()).$1.locked, isTrue);
      expect((await _make(enabled: false)).$1.locked, isFalse);
    });

    test('Entsperren nur mit erfolgreicher Geräteanmeldung', () async {
      final (c, auth, _, _) = await _make();
      auth.succeed = false;
      expect(await c.unlock('Grund'), isFalse);
      expect(c.locked, isTrue);
      auth.succeed = true;
      expect(await c.unlock('Grund'), isTrue);
      expect(c.locked, isFalse);
      expect(auth.reasons, <String>['Grund', 'Grund']);
    });

    test('sperrt nach Inaktivität im Hintergrund, nicht davor', () async {
      var now = DateTime.utc(2026, 10, 21, 12);
      final store = MemoryKeyValueStore()..data['lockEnabled'] = 'true'..data['lockTimeout'] = '60';
      final settings = await SettingsController.load(store);
      final c = AppLockController(settings: settings, auth: FakeDeviceAuth(), clock: () => now);
      await c.unlock('x');
      expect(c.locked, isFalse);

      c.onPaused();
      now = now.add(const Duration(seconds: 30));
      c.onResumed();
      expect(c.locked, isFalse, reason: 'unter der Auszeit');

      c.onPaused();
      now = now.add(const Duration(seconds: 61));
      c.onResumed();
      expect(c.locked, isTrue);
    });

    test('Pen-Test I-05: zurückgestellte Uhrzeit verhindert die Sperre nicht', () async {
      var now = DateTime.utc(2026, 10, 21, 12);
      var mono = Duration.zero;
      final store = MemoryKeyValueStore()..data['lockEnabled'] = 'true'..data['lockTimeout'] = '60';
      final settings = await SettingsController.load(store);
      final c = AppLockController(settings: settings, auth: FakeDeviceAuth(), clock: () => now, monotonic: () => mono);
      await c.unlock('x');

      // Wanduhr um 10 s vor, monotone Uhr um 120 s: Jemand hat die Uhrzeit verstellt.
      c.onPaused();
      now = now.add(const Duration(seconds: 10));
      mono += const Duration(seconds: 120);
      c.onResumed();
      expect(c.locked, isTrue, reason: 'monotone Uhr über der Auszeit');

      await c.unlock('x');
      // Wanduhr rückwärts, monotone Uhr kaum weiter.
      c.onPaused();
      now = now.subtract(const Duration(hours: 1));
      mono += const Duration(seconds: 1);
      c.onResumed();
      expect(c.locked, isTrue, reason: 'rückwärts laufende Wanduhr');

      await c.unlock('x');
      // Gerät schlief: monotone Uhr stand still, die Wanduhr lief weiter.
      c.onPaused();
      now = now.add(const Duration(minutes: 5));
      c.onResumed();
      expect(c.locked, isTrue, reason: 'Wanduhr erfasst den Geräteschlaf');

      await c.unlock('x');
      c.onPaused();
      now = now.add(const Duration(seconds: 30));
      mono += const Duration(seconds: 30);
      c.onResumed();
      expect(c.locked, isFalse, reason: 'beide Uhren unter der Auszeit');
    });

    test('Auszeit „sofort“ sperrt bei jeder Rückkehr', () async {
      final now = DateTime.utc(2026, 10, 21, 12);
      final store = MemoryKeyValueStore()..data['lockEnabled'] = 'true'..data['lockTimeout'] = '0';
      final settings = await SettingsController.load(store);
      final c = AppLockController(settings: settings, auth: FakeDeviceAuth(), clock: () => now);
      await c.unlock('x');
      c.onPaused();
      c.onResumed();
      expect(c.locked, isTrue);
    });

    test('Zustandswechsel während der Geräteabfrage zählen nicht als Inaktivität', () async {
      var now = DateTime.utc(2026, 10, 21, 12);
      final store = MemoryKeyValueStore()..data['lockEnabled'] = 'true'..data['lockTimeout'] = '0';
      final settings = await SettingsController.load(store);
      final auth = _SlowAuth(() {
        // Während des System-Dialogs wechselt die App kurz in den Hintergrund.
      });
      final c = AppLockController(settings: settings, auth: auth, clock: () => now);
      final f = c.unlock('x');
      c.onPaused();
      now = now.add(const Duration(minutes: 5));
      c.onResumed();
      auth.complete(true);
      expect(await f, isTrue);
      expect(c.locked, isFalse, reason: 'nach erfolgreicher Abfrage nicht sofort erneut sperren');
    });

    test('Aktivieren verlangt verfügbares Gerät und erfolgreiche Bestätigung', () async {
      final (c, auth, settings, _) = await _make(enabled: false);
      auth.available = false;
      expect(await c.setEnabled(true, 'x'), isFalse);
      auth.available = true;
      auth.succeed = false;
      expect(await c.setEnabled(true, 'x'), isFalse);
      expect(settings.settings.lockEnabled, isFalse);
      auth.succeed = true;
      expect(await c.setEnabled(true, 'x'), isTrue);
      expect(settings.settings.lockEnabled, isTrue);
    });

    test('Deaktivieren verlangt ebenfalls die Bestätigung', () async {
      final (c, auth, settings, _) = await _make();
      await c.unlock('x');
      auth.succeed = false;
      expect(await c.setEnabled(false, 'x'), isFalse);
      expect(settings.settings.lockEnabled, isTrue);
      auth.succeed = true;
      expect(await c.setEnabled(false, 'x'), isTrue);
      expect(settings.settings.lockEnabled, isFalse);
    });
  });

  group('Sperrbildschirm', () {
    testWidgets('verdeckt die App, fragt sofort die Geräteanmeldung ab und gibt frei', (tester) async {
      final app = await buildTestApp(lockEnabled: true);
      final svc = (app: app, auth: app.auth);
      svc.auth.succeed = false;
      await tester.pumpWidget(FamilyNexusApp(services: svc.app.services));
      await tester.pumpAndSettle();
      expect(find.text('FamilyNexus ist gesperrt'), findsOneWidget);
      expect(svc.auth.reasons, isNotEmpty, reason: 'Abfrage beim Erscheinen');
      expect(find.byType(NavigationBar).hitTestable(), findsNothing, reason: 'Inhalt nicht bedienbar');
      svc.auth.succeed = true;
      await tester.tap(find.text('Entsperren'));
      await tester.pumpAndSettle();
      expect(find.text('FamilyNexus ist gesperrt'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('Einstellungen', () {
    testWidgets('Schalter aktiviert die Sperre erst nach Bestätigung; ohne gesicherte Gerätesperre Hinweis', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp();
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await openSettings(tester);

      app.auth.available = false;
      await tester.ensureVisible(find.text('App-Sperre'));
      await tester.tap(find.text('App-Sperre'));
      await tester.pumpAndSettle();
      expect(find.text('Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.'), findsOneWidget);
      expect(app.services.settings.settings.lockEnabled, isFalse);

      app.auth.available = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.text('App-Sperre'));
      await tester.pumpAndSettle();
      expect(app.services.settings.settings.lockEnabled, isTrue);
      expect(find.text('Sperren nach'), findsOneWidget);
    });

    testWidgets('#67: Plattform ohne Geräteanmeldung (Linux) zeigt keinen Schalter „App-Sperre“', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp();
      app.auth.supported = false;
      app.auth.available = false;
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await openSettings(tester);
      expect(find.text('Online-Status teilen'), findsOneWidget, reason: 'Abschnitt Datenschutz ist sichtbar');
      expect(find.text('App-Sperre'), findsNothing);
      expect(find.text('Auf diesem Gerät ist keine gesicherte Bildschirmsperre eingerichtet.'), findsNothing);
    });
  });
}

class _SlowAuth extends FakeDeviceAuth {
  _SlowAuth(this.onStart);
  final void Function() onStart;
  late final _completer = Completer<bool>();

  void complete(bool v) => _completer.complete(v);

  @override
  Future<bool> authenticate(String reason) {
    onStart();
    return _completer.future;
  }
}
