import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/features/onboarding/registration_stage_view.dart';
import 'package:family_nexus/features/onboarding/widgets/sign_in_icons.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Symbole der Schaltflächen, die eine Seite des Anbieters öffnen (#430, E-91): In der Sitzung der App (iOS, macOS,
/// Android) kein „extern öffnen“, im externen Browser (Linux, Windows, Web) schon.
void main() {
  group('providerPageIconFor', () {
    test('Sitzung der App: eigenes Symbol', () {
      for (final flow in <OAuthFlow>[OAuthFlow.authSession, OAuthFlow.customTab]) {
        expect(providerPageIconFor(flow, Icons.login), Icons.login, reason: '$flow');
      }
    });

    test('externer Browser und Web: „extern öffnen“', () {
      for (final flow in <OAuthFlow>[OAuthFlow.loopback, OAuthFlow.none]) {
        expect(providerPageIconFor(flow, Icons.login), Icons.open_in_new, reason: '$flow');
      }
    });
  });

  group('Registrierungsschritte (Bedingungen, Captcha)', () {
    Future<void> pumpStage(WidgetTester tester, RegistrationStage stage, TargetPlatform platform) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(platform: platform),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(body: RegistrationStageView(stage: stage, busy: false, onInput: (_) {}, onCancel: () {})),
      ));
    }

    final terms = TermsStage(<TermsPolicy>[TermsPolicy(name: 'Nutzungsbedingungen', url: Uri.parse('https://fake.test/terms'))]);
    final captcha = CaptchaStage(Uri.parse('https://fake.test/captcha'));

    for (final platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android]) {
      testWidgets('$platform: Bedingungen und Captcha ohne „extern öffnen“', (tester) async {
        await pumpStage(tester, terms, platform);
        expect(find.byIcon(Icons.article_outlined), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new), findsNothing);
        await pumpStage(tester, captcha, platform);
        expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
        expect(find.byIcon(Icons.open_in_new), findsNothing);
      });
    }

    for (final platform in <TargetPlatform>[TargetPlatform.linux, TargetPlatform.windows]) {
      testWidgets('$platform: Bedingungen und Captcha öffnen extern, Symbol „extern öffnen“', (tester) async {
        await pumpStage(tester, terms, platform);
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
        expect(find.byIcon(Icons.article_outlined), findsNothing);
        await pumpStage(tester, captcha, platform);
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
        expect(find.byIcon(Icons.verified_user_outlined), findsNothing);
      });
    }
  });

  group('Anmelden und Konto erstellen bei einem Anbieter mit OAuth', () {
    Future<void> openFlow(WidgetTester tester, TargetPlatform platform, String entry) async {
      debugDefaultTargetPlatformOverride = platform;
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp(loggedIn: false);
      app.server.registrationMode = RegistrationMode.oauth;
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
    }

    for (final platform in <TargetPlatform>[TargetPlatform.iOS, TargetPlatform.macOS, TargetPlatform.android]) {
      testWidgets('$platform: „Anmelden“ mit Anmelde-Symbol, „Konto erstellen“ mit Konto-Symbol', (tester) async {
        try {
          await openFlow(tester, platform, 'Ich habe schon ein Konto');
          expect(find.byIcon(Icons.login), findsOneWidget);
          expect(find.byIcon(Icons.open_in_new), findsNothing);
          await tester.tap(find.text('Noch kein Konto? Jetzt erstellen'));
          await tester.pumpAndSettle();
          expect(find.byIcon(Icons.person_add_alt_1), findsOneWidget);
          expect(find.byIcon(Icons.open_in_new), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('Anbieter ohne Kontoanlage in der App: „Webseite öffnen“ je Plattform', (tester) async {
      try {
        for (final (platform, icon) in <(TargetPlatform, IconData)>[
          (TargetPlatform.macOS, Icons.language),
          (TargetPlatform.linux, Icons.open_in_new),
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.physicalSize = const Size(900, 3000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final app = await buildTestApp(loggedIn: false);
          app.server.registrationMode = RegistrationMode.disabled;
          await tester.pumpWidget(FamilyNexusApp(services: app.services));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Neue Familie gründen'));
          await tester.pumpAndSettle();
          expect(find.byIcon(icon), findsOneWidget, reason: '$platform');
          expect(find.byIcon(icon == Icons.language ? Icons.open_in_new : Icons.language), findsNothing, reason: '$platform');
          await tester.pumpWidget(const SizedBox());
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('TargetPlatform.linux: weiter „extern öffnen“ (dort öffnet der Browser)', (tester) async {
      try {
        await openFlow(tester, TargetPlatform.linux, 'Ich habe schon ein Konto');
        expect(find.byIcon(Icons.open_in_new), findsOneWidget);
        expect(find.byIcon(Icons.login), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
