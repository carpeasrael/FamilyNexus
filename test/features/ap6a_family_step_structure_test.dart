import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/onboarding/family_step.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-6a: Der Zustand des Familienschritts wandert in einen Controller. Die Schnappschüsse (Semantik) der sechs Ansichten
/// wurden vor dem Umbau am unveränderten Code aufgenommen und müssen danach gleich sein.
Future<TestApp> _app() async {
  final app = await buildTestApp(loggedIn: false);
  await app.gateway.login(server: ServerUrl.tryParse(app.server.host)!, username: 'anna', password: 'geheim123');
  await app.gateway.setUpSecurity();
  return app;
}

Future<void> _pump(WidgetTester tester, TestApp app, {FamilyStepMode mode = FamilyStepMode.choice}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: buildTheme(Brightness.light),
    home: AppScope(
      services: app.services,
      child: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: FamilyStep(onFamilyReady: () async {}, mode: mode))),
    ),
  ));
  await tester.pumpAndSettle();
}

List<String> _snap(WidgetTester tester) => semanticsSnapshot(tester, find.byType(FamilyStep));

/// Ben gründet eine Familie und lädt Anna ein.
Future<FakeRoom> _benInvitesAnna(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  await ben.setUpSecurity();
  await ben.createFamily('Familie Ben');
  final room = app.server.rooms.values.firstWhere((r) => r.name == 'Familie Ben');
  app.server.invites['@anna:${app.server.host}'] = <String>[room.id];
  return room;
}

void main() {
  testWidgets('Auswahl: Gründen, dann Beitreten', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _app();
    await _pump(tester, app);
    final create = _snap(tester);
    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();
    final join = _snap(tester);
    expect(create, _expectedCreate);
    expect(join, _expectedJoin);
    handle.dispose();
  });

  testWidgets('Gründen: Erfolgsansicht', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _app();
    await _pump(tester, app, mode: FamilyStepMode.create);
    await tester.enterText(find.byType(TextField).first, 'Familie Müller');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Familie gründen'));
    await tester.pumpAndSettle();
    final created = _snap(tester);
    expect(created, _expectedCreated);
    handle.dispose();
  });

  testWidgets('Eingeladen: Einladungskarte', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _app();
    await _benInvitesAnna(app);
    await _pump(tester, app, mode: FamilyStepMode.join);
    final invited = _snap(tester);
    expect(invited, _expectedInvited);
    handle.dispose();
  });

  testWidgets('Anfrage per Code: wartet; dann abgelehnt', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await _app();
    final ben = app.server.newDevice();
    await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
    await ben.setUpSecurity();
    await ben.createFamily('Familie Ben');
    final room = app.server.rooms.values.firstWhere((r) => r.name == 'Familie Ben');
    await _pump(tester, app, mode: FamilyStepMode.join);
    await tester.tap(find.text('Ohne Link beitreten (Familien-Code)'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, room.id);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Beitritt anfragen').last);
    await tester.pumpAndSettle();
    final waiting = _snap(tester);
    room.rejected.add('@anna:${app.server.host}');
    app.server.notifyAll();
    await tester.pumpAndSettle();
    final rejected = _snap(tester);
    expect(waiting, _expectedWaiting);
    expect(rejected, _expectedRejected);
    handle.dispose();
  });
}

const List<String> _expectedCreate = <String>[
  'L=Gründe eine neue Familie oder tritt einer bestehenden bei.',
  'L=Gründen button selected tap',
  'L=Gründen button tap',
  'L=Beitreten button tap',
  'L=Beitreten button tap',
  'L=Du wirst Moderator. Lade später einen zweiten Moderator ein, damit die Familie bei Geräteverlust handlungsfähig bleibt.',
  'L=Kinder können Mitglied werden. Bitte hole dafür die Einwilligung der Sorgeberechtigten ein.',
  'L=Name der Familie textfield tap',
  'L=Noch 60 Zeichen',
  'L=Familie gründen button disabled',
];
const List<String> _expectedJoin = <String>[
  'L=Gründe eine neue Familie oder tritt einer bestehenden bei.',
  'L=Gründen button tap',
  'L=Gründen button tap',
  'L=Beitreten button selected tap',
  'L=Beitreten button tap',
  'L=Füge den Einladungslink ein oder öffne den Link bzw. QR-Code mit der Kamera-App.',
  'L=Einladungslink textfield tap',
  'L=Weiter button tap',
  'L=Minimiert live',
  'L=Ohne Link beitreten (Familien-Code) H=Minimiert tap',
];
const List<String> _expectedCreated = <String>[
  'L=Fertig! „Familie Müller“ ist eingerichtet. live',
  'L=Lade jetzt deine Familie ein – per QR-Code, E-Mail oder Link. Du kannst das auch später unter „Familie“ tun.',
  'L=Später button tap',
  'L=Jetzt einladen button tap',
];
const List<String> _expectedInvited = <String>[
  'L=Du wurdest eingeladen',
  'L=Familie Ben | Einladung von Ben | Diese Einladung gehört zu keiner Beitrittsanfrage von dir. Nimm sie nur an, wenn du @ben:fake.test kennst und die Einladung erwartet hast.',
  'L=Ablehnen button tap',
  'L=„Familie Ben“ beitreten button tap',
  'L=Stattdessen eine neue Familie gründen oder einer anderen beitreten button tap',
];
const List<String> _expectedWaiting = <String>[
  'L=Fast geschafft! Deine Anfrage ist unterwegs. Sobald sie bestätigt ist, bist du dabei. live',
  'L=Details button tap',
  'L=Anfrage zurückziehen button tap',
];
const List<String> _expectedRejected = <String>[
  'L=Deine Anfrage wurde abgelehnt. Frag bei der Familie nach, ob sie dich einladen möchte, und versuche es dann mit einem neuen Link. live',
  'L=Details button tap',
  'L=Verstanden button tap',
];
