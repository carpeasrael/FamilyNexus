import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/family/avatar_presets_ui.dart';
import 'package:family_nexus/features/family/avatar_screen.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #422, E-101: Avatar wählen (Profilbildschirm) und Anzeige in Familie, Chat und Gesprächsliste.
const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';

Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership[_ben] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  return ben;
}

Finder _avatar(String userId) => find.byKey(ValueKey<String>('avatar-$userId'));

Widget _screen(TestApp app, {String lang = 'de', Duration? pendingLimit}) => AppScope(
      services: app.services,
      child: MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: pendingLimit == null ? AvatarScreen(services: app.services) : AvatarScreen(services: app.services, pendingLimit: pendingLimit),
      ),
    );

Future<void> _openFamily(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Familie'));
  await tester.pumpAndSettle();
}

void main() {
  group('Profilbildschirm', () {
    testWidgets('Raster mit zwölf Avataren und Initialen, Auswahl mit Häkchen und Beschriftung, Speichern setzt den Avatar', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await buildTestApp();
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      expect(find.text('Avatar'), findsOneWidget);
      for (final id in AvatarPresets.all) {
        expect(find.byIcon(AvatarPresetsUi.styles[id]!.icon), findsWidgets, reason: id);
      }
      expect(find.text('Initialen (kein Avatar)'), findsWidgets);
      expect(find.byIcon(Icons.check), findsOneWidget, reason: 'Häkchen an der aktuellen Wahl (Initialen)');
      expect(find.text('Ausgewählt'), findsOneWidget, reason: 'nie nur Häkchen oder Farbe');
      FilledButton save() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern'));
      expect(save().onPressed, isNull, reason: 'ohne Änderung nichts zu speichern');

      await tester.tap(find.text('Segelboot'));
      await tester.pump();
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.bySemanticsLabel('Segelboot'), findsOneWidget);
      expect(save().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();
      expect(app.gateway.avatarOf(_anna), 'p06');
      expect(find.text('Avatar gespeichert'), findsOneWidget);
      expect(find.text('Wird übernommen …'), findsNothing, reason: 'im Fake sofort da');
      handle.dispose();
    });

    testWidgets('Initialen wählen setzt {} (kein Avatar)', (tester) async {
      final app = await buildTestApp();
      app.gateway.familyRoom!.avatarState[_anna] = AvatarPresets.content('p02');
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      expect(find.text('Hase'), findsWidgets);
      await tester.tap(find.text('Initialen (kein Avatar)').last);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();
      expect(app.gateway.avatarOf(_anna), isNull);
      expect(app.gateway.familyRoom!.avatarState[_anna], isEmpty, reason: 'leerer Inhalt, der Schlüssel bleibt');
    });

    testWidgets('kein optimistischer Wert: „wird übernommen“ bis zum Echo', (tester) async {
      final app = await buildTestApp();
      app.gateway.holdAvatarEcho = true;
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      await tester.tap(find.text('Rakete'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();
      expect(find.text('Wird übernommen …'), findsOneWidget);
      expect(app.gateway.avatarOf(_anna), isNull, reason: 'noch nicht gemeldet');
      app.gateway.releaseAvatarEcho();
      await tester.pump();
      expect(find.text('Wird übernommen …'), findsNothing);
      expect(app.gateway.avatarOf(_anna), 'p12');
      expect(find.text('Ausgewählt'), findsOneWidget);
    });

    testWidgets('„wird übernommen“ hängt nie fest: nach 15 Sekunden gilt der tatsächliche Stand', (tester) async {
      final app = await buildTestApp();
      app.gateway.holdAvatarEcho = true;
      app.gateway.familyRoom!.avatarState[_anna] = AvatarPresets.content('p01');
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      await tester.tap(find.text('Rakete'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();
      expect(find.text('Wird übernommen …'), findsOneWidget);
      // ein anderes Gerät hat zwischenzeitlich eine andere Wahl gesetzt
      app.gateway.familyRoom!.avatarState[_anna] = AvatarPresets.content('p09');
      app.server.bumpAvatars(app.gateway.familyRoom!);
      await tester.pump(const Duration(seconds: 14));
      expect(find.text('Wird übernommen …'), findsOneWidget, reason: 'Frist noch nicht um');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Wird übernommen …'), findsNothing);
      expect(find.text('Eis'), findsWidgets);
      final selected = find.ancestor(of: find.text('Ausgewählt'), matching: find.byType(Column)).first;
      expect(find.descendant(of: selected, matching: find.text('Eis')), findsOneWidget, reason: 'der tatsächliche Stand ist gewählt');
    });

    testWidgets('Fehler beim Speichern: Meldung über errorText, nichts „wird übernommen“', (tester) async {
      final app = await buildTestApp();
      app.gateway.avatarError = const GatewayException(GatewayError.notAllowed);
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      await tester.tap(find.text('Pizza'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pump();
      expect(find.text('Dafür fehlt die Berechtigung.'), findsOneWidget);
      expect(find.text('Wird übernommen …'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Speichern'), findsOneWidget, reason: 'erneut versuchbar');
    });

    testWidgets('needsModerator: Hinweis statt Raster; unknown: nur Ladezustand ohne Hinweis', (tester) async {
      final app = await buildTestApp();
      final room = app.gateway.familyRoom!;
      room.power[_anna] = 0;
      room.eventPower.remove(AvatarPresets.type);
      expect(app.gateway.avatarAvailability, AvatarAvailability.needsModerator);
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      expect(find.textContaining('Ein Moderator muss die Avatar-Funktion'), findsOneWidget);
      expect(find.text('Rakete'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Speichern'), findsNothing);

      app.gateway.detachFamilyRoom();
      expect(app.gateway.avatarAvailability, AvatarAvailability.unknown);
      await tester.pumpWidget(_screen(app));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.textContaining('Ein Moderator muss'), findsNothing, reason: 'vor dem ersten Abgleich kein Hinweis');
      expect(find.text('Rakete'), findsNothing);
    });

    testWidgets('en: Titel, Namen und Hinweis auf Englisch, keine deutschen Texte', (tester) async {
      final app = await buildTestApp(lang: 'en');
      await tester.pumpWidget(_screen(app, lang: 'en'));
      await tester.pump();
      expect(find.text('Avatar'), findsOneWidget);
      expect(find.text('Initials (no avatar)'), findsWidgets);
      expect(find.text('Sailboat'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.textContaining('not end-to-end encrypted'), findsOneWidget);
      expect(find.text('Segelboot'), findsNothing);
    });
  });

  group('Familie', () {
    testWidgets('Avatare in der Mitgliederliste, „Avatar ändern“ nur in der eigenen Kachel (≥ 48 dp)', (tester) async {
      final app = await buildTestApp();
      await _joinBen(app);
      final room = app.gateway.familyRoom!;
      room.avatarState[_ben] = AvatarPresets.content('p05');
      room.membership['@cara:fake.test'] = MemberStatus.requested;
      await _openFamily(tester, app);
      expect(_avatar(_ben), findsOneWidget);
      expect(find.descendant(of: _avatar(_ben), matching: find.byIcon(AvatarPresetsUi.styles['p05']!.icon)), findsOneWidget);
      expect(_avatar(_anna), findsOneWidget, reason: 'eigene Kachel');
      expect(find.byTooltip('Avatar ändern'), findsOneWidget, reason: 'nur die eigene Kachel');
      final size = tester.getSize(find.byTooltip('Avatar ändern'));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      // Anfragende: nur Rückfall, kein Avatar
      expect(_avatar('@cara:fake.test'), findsOneWidget);
      expect(find.descendant(of: _avatar('@cara:fake.test'), matching: find.byType(Icon)), findsNothing);
    });

    testWidgets('„Avatar ändern“ öffnet den Bildschirm, die Wahl erscheint danach in der eigenen Kachel', (tester) async {
      final app = await buildTestApp();
      await _joinBen(app);
      await _openFamily(tester, app);
      await tester.tap(find.byTooltip('Avatar ändern'));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarScreen), findsOneWidget);
      await tester.tap(find.text('Fußball'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _avatar(_anna), matching: find.byIcon(AvatarPresetsUi.styles['p11']!.icon)), findsOneWidget);
    });
  });

  group('Chat', () {
    testWidgets('Avatar bei jeder Nachricht anderer, nicht bei eigenen', (tester) async {
      final app = await buildTestApp();
      final ben = await _joinBen(app);
      app.gateway.familyRoom!.avatarState[_ben] = AvatarPresets.content('p03');
      await ben.sendMessage('Eins');
      await ben.sendMessage('Zwei');
      await app.gateway.sendMessage('Meine');
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Chat'));
      await tester.pumpAndSettle();
      if (find.byKey(const ValueKey<String>('thread-family')).evaluate().isNotEmpty) {
        await tester.tap(find.byKey(const ValueKey<String>('thread-family')));
        await tester.pumpAndSettle();
      }
      expect(find.text('Eins'), findsOneWidget);
      expect(_avatar(_ben), findsNWidgets(2), reason: 'keine Folgenerkennung: bei jeder fremden Nachricht');
      expect(_avatar(_anna), findsNothing, reason: 'nicht bei eigenen Nachrichten');
      expect(find.descendant(of: _avatar(_ben).first, matching: find.byIcon(AvatarPresetsUi.styles['p03']!.icon)), findsOneWidget);
    });
  });

  group('Gesprächsliste', () {
    testWidgets('Einzelchat mit Avatar (ersetzt den Punkt), Familienchat behält das Gruppensymbol, Zeile ≥ 56 dp', (tester) async {
      final app = await buildTestApp();
      await _joinBen(app);
      app.gateway.familyRoom!.avatarState[_ben] = AvatarPresets.content('p08');
      final dm = await app.gateway.startDirectChat(_ben);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Chat'));
      await tester.pumpAndSettle();
      final row = find.byKey(ValueKey<String>('thread-$dm'));
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: _avatar(_ben)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.byIcon(AvatarPresetsUi.styles['p08']!.icon)), findsOneWidget);
      expect(tester.getSize(row).height, greaterThanOrEqualTo(56));
      final family = find.byKey(const ValueKey<String>('thread-family'));
      expect(find.descendant(of: family, matching: find.byIcon(Icons.groups_outlined)), findsOneWidget);
      // Kopfzeile des Einzelchats zeigt den Avatar neben dem Titel
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(_avatar(_ben), findsWidgets);
    });
  });

  testWidgets('MemberAvatarView reagiert auf die Wahl eines anderen Geräts über das Gateway', (tester) async {
    final app = await buildTestApp();
    final ben = await _joinBen(app);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: AppScope(services: app.services, child: Scaffold(body: MemberAvatarView(userId: _ben, size: 28, colorIndex: 1))),
    ));
    expect(find.byIcon(AvatarPresetsUi.styles['p10']!.icon), findsNothing);
    await ben.setMemberAvatar('p10');
    await tester.pump();
    expect(find.byIcon(AvatarPresetsUi.styles['p10']!.icon), findsOneWidget);
  });
}
