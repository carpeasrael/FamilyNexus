import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/app/bootstrapper.dart';
import 'package:family_nexus/app/startup_failure.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  group('#316: Bootstrapper', () {
    testWidgets('solange der Start läuft: leere Fläche (Stand vor dem Fix)', (tester) async {
      final pending = Completer<AppServices>();
      await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) => pending.future));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const Key('startup-loading')), findsNothing);
      expect(find.byType(FamilyNexusApp), findsNothing);
      expect(find.byType(StartupFailureApp), findsNothing);
    });

    testWidgets('Fehler zeigt StartupFailureApp, „Try again“ startet neu; die Fehlerseite bleibt, bis der Neustart fertig ist (Stand vor dem Fix)', (tester) async {
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
      expect(find.byType(StartupFailureApp), findsOneWidget);
    });

    testWidgets('Erfolg zeigt FamilyNexusApp', (tester) async {
      final app = await buildTestApp();
      await tester.pumpWidget(Bootstrapper(bootstrapFn: ({KeyStore? keyStore}) async => app.services));
      await tester.pump();
      await tester.pump();
      expect(find.byType(FamilyNexusApp), findsOneWidget);
    });
  });
}
