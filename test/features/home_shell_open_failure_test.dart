import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #153: Scheitert das Öffnen der Familiendienste, zeigt die Hauptansicht eine Meldung mit „Erneut versuchen“
/// und das Menü statt eines dauerhaften Ladekreises; es bleibt kein Teilzustand zurück.
void main() {
  Future<void> start(WidgetTester tester, TestApp app) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
  }

  for (final lang in ['de', 'en']) {
    final de = lang == 'de';
    final failed = de ? 'Deine Familiendaten konnten nicht geöffnet werden' : 'Your family data could not be opened';
    final retry = de ? 'Erneut versuchen' : 'Try again';

    testWidgets('$lang: Kalender-Aufbau scheitert – Meldung, Menü, Neuversuch führt zu den Tabs', (tester) async {
      var broken = true;
      final app = await buildTestApp(
        lang: lang,
        beforeCalendarBuild: (_) async {
          if (broken) throw StateError('Speicher voll');
        },
      );
      await start(tester, app);
      expect(find.textContaining(failed), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(retry), findsOneWidget);
      expect(app.services.calendar, isNull);

      // Menü erreichbar, ohne „Aufgaben“ (braucht die Familiendienste), Einstellungen vorhanden.
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      expect(find.text(de ? 'Aufgaben' : 'Tasks'), findsNothing);
      expect(find.text(de ? 'Einstellungen' : 'Settings'), findsWidgets);
      await tester.tapAt(const Offset(20, 300)); // Menü schließen
      await tester.pumpAndSettle();

      broken = false;
      await tester.tap(find.text(retry));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.textContaining(failed), findsNothing);
      expect(app.services.calendar, isNotNull);
    });

    testWidgets('$lang: später Fehler (Aufgaben) hinterlässt keinen Teilzustand; Neuversuch baut alles auf', (tester) async {
      var broken = true;
      final app = await buildTestApp(
        lang: lang,
        beforeTasksBuild: (_) async {
          if (broken) throw StateError('Speicher voll');
        },
      );
      await start(tester, app);
      expect(find.textContaining(failed), findsOneWidget);
      expect(app.services.calendar, isNull, reason: 'Kalender wurde wieder abgebaut');
      expect(app.services.shopping, isNull);
      expect(app.services.tasks, isNull);
      expect(app.services.presence, isNull);
      expect(app.services.reminders, isNull);

      broken = false;
      await tester.tap(find.text(retry));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(app.services.calendar, isNotNull);
      expect(app.services.tasks, isNotNull);
      expect(app.services.presence, isNotNull);
      expect(app.services.reminders, isNotNull);
    });
  }

  testWidgets('ein veralteter Fehler baut einen neueren, erfolgreichen Aufruf nicht ab', (tester) async {
    final slowFailure = Completer<void>();
    var call = 0;
    final app = await buildTestApp(
      beforeCalendarBuild: (_) async {
        call++;
        if (call == 1) await slowFailure.future; // erster Aufruf hängt und scheitert erst später
      },
    );
    final first = app.services.openCalendar();
    await tester.pump();
    // Zweiter Aufruf (z. B. Neuaufbau der Oberfläche) läuft durch.
    await app.services.openCalendar();
    expect(app.services.calendar, isNotNull);
    slowFailure.completeError(StateError('zu spät'));
    await expectLater(first, throwsStateError);
    expect(app.services.calendar, isNotNull, reason: 'der neuere Aufruf bleibt bestehen');
    app.services.closeCalendar();
  });
}
