import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/app/startup_failure.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_stores.dart';
import '../support/test_app.dart';

class _Gateway extends FakeMatrixGateway {
  _Gateway(super.fake, {this.failure, this.loggedIn = false});
  final Object? failure;
  final bool loggedIn;

  @override
  SessionState get session => loggedIn ? SessionState.ready : SessionState.loggedOut;

  @override
  Future<void> restore() async {
    final f = failure;
    if (f != null) throw f;
  }
}

void main() {
  const key = AppServices.keepAccountDataKey;
  late MemoryKeyValueStore kv;

  setUp(() => kv = MemoryKeyValueStore());

  Matcher thrownWith({required bool sessionLost}) =>
      throwsA(isA<SessionRestoreException>().having((e) => e.sessionLost, 'sessionLost', sessionLost));

  group('#134: restoreSession', () {
    test('Sitzung verloren: Vermerk, Startfehler', () async {
      final g = _Gateway(FakeMatrixServer(), failure: const SessionRestoreException(sessionLost: true));
      await expectLater(restoreSession(g, kv), thrownWith(sessionLost: true));
      expect(kv.data, contains(key));
    });

    test('Datenbank nicht zu öffnen: Startfehler ohne Vermerk, ein echtes Sitzungsende löscht danach weiter', () async {
      final g = _Gateway(FakeMatrixServer(), failure: const SessionRestoreException(sessionLost: false));
      await expectLater(restoreSession(g, kv), thrownWith(sessionLost: false));
      expect(kv.data, isNot(contains(key)));
      expect(await restoreSession(_Gateway(FakeMatrixServer()), kv), isFalse);
    });

    test('scheitert das Schreiben des Vermerks, bleibt es beim Startfehler', () async {
      kv.failWrites = true;
      final g = _Gateway(FakeMatrixServer(), failure: const SessionRestoreException(sessionLost: true));
      await expectLater(restoreSession(g, kv), thrownWith(sessionLost: true));
    });

    test('anderer Fehler mit Sitzung: weiter wie bisher, kein Vermerk', () async {
      final g = _Gateway(FakeMatrixServer(), failure: const GatewayException(GatewayError.serverUnreachable), loggedIn: true);
      expect(await restoreSession(g, kv), isFalse);
      expect(kv.data, isNot(contains(key)));
    });

    test('ein alter Vermerk fällt mit stehender Sitzung weg, auch nach einem verschluckten Fehler', () async {
      kv.data[key] = '1';
      final g = _Gateway(FakeMatrixServer(), failure: const GatewayException(GatewayError.serverUnreachable), loggedIn: true);
      expect(await restoreSession(g, kv), isFalse);
      expect(kv.data, isNot(contains(key)));
    });

    test('ein alter Vermerk ohne Sitzung gilt weiter', () async {
      kv.data[key] = '1';
      expect(await restoreSession(_Gateway(FakeMatrixServer()), kv), isTrue);
      expect(kv.data, contains(key));
    });

    test('Abmelden ohne Vermerk bleibt ein echtes Sitzungsende', () async {
      expect(await restoreSession(_Gateway(FakeMatrixServer()), kv), isFalse);
    });

    test('Schlüsselverlust bleibt unverändert', () async {
      final g = _Gateway(FakeMatrixServer(), failure: const KeyLostException());
      await expectLater(restoreSession(g, kv), throwsA(isA<KeyLostException>()));
      expect(kv.data, isEmpty);
    });
  });

  group('#134: AppRoot', () {
    Future<(TestApp, List<int>)> start(WidgetTester tester, {required bool loggedIn, required bool keep}) async {
      final app = await buildTestApp(loggedIn: loggedIn);
      final wipes = <int>[];
      app.services
        ..keepAccountData = keep
        ..debugWipeAccountData = () async => wipes.add(1);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      return (app, wipes);
    }

    testWidgets('ohne Sitzung mit Vermerk bleiben Daten und Erinnerungen', (tester) async {
      final (app, wipes) = await start(tester, loggedIn: false, keep: true);
      expect(wipes, isEmpty);
      expect(app.scheduler.cancelled, 0);
      expect(app.services.keepAccountData, isTrue);
    });

    testWidgets('ohne Sitzung und ohne Vermerk wird gelöscht (F-02)', (tester) async {
      final (app, wipes) = await start(tester, loggedIn: false, keep: false);
      expect(wipes, isNotEmpty);
      expect(app.scheduler.cancelled, greaterThan(0));
    });

    testWidgets('mit Sitzung entfällt der Vermerk, ein späteres Abmelden löscht wieder', (tester) async {
      final (app, wipes) = await start(tester, loggedIn: true, keep: true);
      expect(app.services.keepAccountData, isFalse);
      expect(wipes, isEmpty);
      await app.gateway.logout();
      await tester.pumpAndSettle();
      expect(wipes, isNotEmpty);
    });
  });

  group('#134: Startfehler', () {
    Future<void> show(WidgetTester tester, Locale locale, {required bool sessionLost}) async {
      tester.platformDispatcher.localesTestValue = <Locale>[locale];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(StartupFailureApp(onRetry: () {}, onReset: () async {}, sessionLost: sessionLost));
      await tester.pumpAndSettle();
    }

    testWidgets('Anmeldung verloren: eigener Text, nicht „nichts verändert“', (tester) async {
      await show(tester, const Locale('de'), sessionLost: true);
      expect(find.text('Anmeldung nicht wiederhergestellt'), findsOneWidget);
      expect(find.textContaining('Deine Familiendaten bleiben auf dem Gerät'), findsOneWidget);
      expect(find.textContaining('nichts verändert'), findsNothing);
      expect(find.text('Erneut versuchen'), findsOneWidget);
    });

    testWidgets('englisch', (tester) async {
      await show(tester, const Locale('en'), sessionLost: true);
      expect(find.text('Sign-in not restored'), findsOneWidget);
    });

    testWidgets('sonst bleibt der bisherige Text', (tester) async {
      await show(tester, const Locale('de'), sessionLost: false);
      expect(find.text('Lokale Daten nicht lesbar'), findsOneWidget);
    });
  });
}
