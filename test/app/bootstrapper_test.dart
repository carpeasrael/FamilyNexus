import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/app/bootstrap.dart' show timedStep;
import 'package:family_nexus/app/bootstrapper.dart';
import 'package:family_nexus/app/startup_failure.dart';
import 'package:family_nexus/app/startup_loading.dart';
import 'package:family_nexus/core/app_log.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:family_nexus/ui/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  group('#316: Bootstrapper', () {
    testWidgets('solange der Start läuft: Ladebild statt leerer Fläche', (tester) async {
      final pending = Completer<AppServices>();
      await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) => pending.future));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
      expect(find.byType(FamilyNexusApp), findsNothing);
      expect(find.byType(StartupFailureApp), findsNothing);
    });

    testWidgets('Fehler zeigt StartupFailureApp, „Try again“ startet neu: währenddessen wieder das Ladebild', (tester) async {
      var calls = 0;
      final retry = Completer<AppServices>();
      await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) {
        calls++;
        return calls == 1 ? Future<AppServices>.error(StateError('x')) : retry.future;
      }));
      await tester.pumpAndSettle();
      expect(find.byType(StartupFailureApp), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(calls, 2);
      expect(find.byType(StartupFailureApp), findsNothing);
      expect(find.byKey(const Key('startup-loading')), findsOneWidget);
    });

    testWidgets('Erfolg zeigt FamilyNexusApp', (tester) async {
      final app = await buildTestApp();
      await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) async => app.services));
      await tester.pump();
      await tester.pump();
      expect(find.byType(FamilyNexusApp), findsOneWidget);
      expect(find.byKey(const Key('startup-loading')), findsNothing);
    });
  });

  group('#316: StartupLoadingApp', () {
    for (final (mode, color) in <(Brightness, Color)>[(Brightness.light, const Color(0xFFF6F7FB)), (Brightness.dark, const Color(0xFF0B1120))]) {
      testWidgets('${mode.name}: Ladeanzeige mit Text und Semantik, Grundfarbe passend', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = mode;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(const StartupLoadingApp());
        await tester.pump();
        expect(find.text('Loading …'), findsOneWidget);
        expect(find.bySemanticsLabel('Loading …'), findsWidgets);
        final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AuroraBackground), matching: find.byType(DecoratedBox)).first);
        expect((box.decoration as BoxDecoration).color, color);
      });
    }

    // #345, E-94: Das Ladebild folgt der Systemdarstellung, die App danach ihrer Einstellung (Standard: dunkel).
    for (final (system, base, app) in <(Brightness, Color, Brightness)>[
      (Brightness.light, const Color(0xFFF6F7FB), Brightness.dark),
      (Brightness.dark, const Color(0xFF0B1120), Brightness.dark),
    ]) {
      testWidgets('#345: System ${system.name}: Ladebild ${system.name}, danach die App im Standard-Thema ${app.name}', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = system;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final pending = Completer<AppServices>();
        await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) => pending.future));
        await tester.pump();
        final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(AuroraBackground), matching: find.byType(DecoratedBox)).first);
        expect((box.decoration as BoxDecoration).color, base);
        expect(Theme.of(tester.element(find.byType(Scaffold))).brightness, system);

        final started = await buildTestApp();
        pending.complete(started.services);
        await tester.pump();
        await tester.pump();
        expect(find.byType(FamilyNexusApp), findsOneWidget);
        expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, app);
      });
    }

    testWidgets('Deutsch', (tester) async {
      tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(const StartupLoadingApp());
      await tester.pump();
      expect(find.text('Lädt …'), findsOneWidget);
    });
  });

  group('#316: timedStep', () {
    setUp(() {
      AppLog.capture = true;
      AppLog.captured.clear();
    });
    tearDown(() => AppLog.capture = false);

    test('loggt Schrittname und Millisekunden, liefert das Ergebnis', () async {
      final r = await timedStep('probe', () async => 'geheim-ergebnis');
      expect(r, 'geheim-ergebnis');
      expect(AppLog.captured.single, matches(RegExp(r'^D/startup: schritt=probe ms=\d+$')));
    });

    test('Fehler wird weitergereicht, Dauer trotzdem geloggt, ohne Fehlertext', () async {
      await expectLater(timedStep('kaputt', () async => throw StateError('geheimer-text')), throwsStateError);
      expect(AppLog.captured.single, matches(RegExp(r'^D/startup: schritt=kaputt ms=\d+$')));
      expect(AppLog.captured.single, isNot(contains('geheimer-text')));
    });
  });
}
