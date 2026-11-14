import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/core/contrast.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/features/family/avatar_presets_ui.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:family_nexus/features/presence/presence_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

const String _ben = '@ben:fake.test';

Widget _host(Widget child, {TestApp? app, String lang = 'de'}) {
  final body = Scaffold(body: Center(child: child));
  return MaterialApp(
    locale: Locale(lang),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: buildTheme(Brightness.light),
    home: app == null ? body : AppScope(services: app.services, child: body),
  );
}

Finder _icon(String preset) => find.byIcon(AvatarPresetsUi.styles[preset]!.icon);

void main() {
  testWidgets('beigetretenes Mitglied mit Avatar: Symbol auf der Farbfläche, kein Buchstabe', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership[_ben] = MemberStatus.joined;
    room.avatarState[_ben] = AvatarPresets.content('p03');
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 28, colorIndex: 2), app: app));
    expect(find.byKey(const ValueKey<String>('avatar-$_ben')), findsOneWidget);
    expect(_icon('p03'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('ohne Wahl: Rückfall mit Anfangsbuchstaben des Anzeigenamens in der Personenfarbe', (tester) async {
    final app = await buildTestApp();
    app.gateway.familyRoom!.membership[_ben] = MemberStatus.joined;
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 28, colorIndex: 4), app: app));
    expect(find.text('B'), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(MemberAvatarView), matching: find.byType(DecoratedBox)).first);
    expect((box.decoration as BoxDecoration).color, AuroraTokens.personColors[4]);
  });

  testWidgets('Buchstabe ab 20 dp einschließlich, darunter ein einfarbiger Kreis', (tester) async {
    final app = await buildTestApp();
    app.gateway.familyRoom!.membership[_ben] = MemberStatus.joined;
    for (final (size, letter) in <(double, bool)>[(16, false), (19.9, false), (20, true), (24, true), (40, true)]) {
      await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: size, colorIndex: 1), app: app));
      expect(find.text('B'), letter ? findsOneWidget : findsNothing, reason: '$size dp');
    }
  });

  testWidgets('Nicht-Mitglied (entfernt) zeigt trotz gespeicherter Wahl den Rückfall mit Fragezeichen', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.avatarState[_ben] = AvatarPresets.content('p05'); // Ben ist nicht (mehr) im Raum
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 28, colorIndex: 1), app: app));
    expect(_icon('p05'), findsNothing);
    expect(find.text('?'), findsOneWidget);
    // Anfragende gelten nicht als beigetreten
    room.membership[_ben] = MemberStatus.requested;
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 28, colorIndex: 1), app: app));
    expect(_icon('p05'), findsNothing);
    expect(find.text('B'), findsOneWidget, reason: 'Anzeigename bekannt, aber kein Avatar');
  });

  testWidgets('ohne AppScope: Rückfall in der übergebenen Farbe mit ?, ohne assert; maybeOf liefert null', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(_host(Builder(builder: (c) {
      captured = c;
      return MemberAvatarView(userId: _ben, size: 24, colorIndex: 3);
    })));
    expect(AppScope.maybeOf(captured), isNull);
    expect(find.text('?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Online-Punkt am Avatar und Ring in der Personenfarbe', (tester) async {
    final app = await buildTestApp();
    app.gateway.familyRoom!.membership[_ben] = MemberStatus.joined;
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 40, colorIndex: 6, online: true, ring: true), app: app));
    expect(find.byType(PresenceDot), findsOneWidget);
    final box = tester.widget<DecoratedBox>(find.descendant(of: find.byType(MemberAvatarView), matching: find.byType(DecoratedBox)).first);
    expect((box.decoration as BoxDecoration).border!.top.color, AuroraTokens.personColors[6]);
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 40, colorIndex: 6), app: app));
    expect(find.byType(PresenceDot), findsNothing);
    final plain = tester.widget<DecoratedBox>(find.descendant(of: find.byType(MemberAvatarView), matching: find.byType(DecoratedBox)).first);
    expect((plain.decoration as BoxDecoration).border, isNull);
  });

  testWidgets('Semantik: der Avatar ist dekorativ und trägt weder Label noch Bedienung', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership[_ben] = MemberStatus.joined;
    room.avatarState[_ben] = AvatarPresets.content('p01');
    await tester.pumpWidget(_host(
      Row(mainAxisSize: MainAxisSize.min, children: <Widget>[MemberAvatarView(userId: _ben, size: 28, colorIndex: 1), const Text('Ben')]),
      app: app,
    ));
    expect(find.descendant(of: find.byType(MemberAvatarView), matching: find.byType(ExcludeSemantics)), findsWidgets);
    expect(find.descendant(of: find.descendant(of: find.byType(MemberAvatarView), matching: find.byType(ExcludeSemantics)).first, matching: find.byType(DecoratedBox)), findsOneWidget, reason: 'die Fläche liegt in der Ausschließung');
    expect(find.bySemanticsLabel('Ben'), findsOneWidget, reason: 'Name steht daneben unverändert');
    expect(find.bySemanticsLabel(RegExp('Pfote|pets')), findsNothing, reason: 'kein Label vom Avatar');
    handle.dispose();
  });

  testWidgets('baut neu, wenn sich der Avatar ändert (avatarRevision)', (tester) async {
    final app = await buildTestApp();
    final room = app.gateway.familyRoom!;
    room.membership[_ben] = MemberStatus.joined;
    await tester.pumpWidget(_host(MemberAvatarView(userId: _ben, size: 28, colorIndex: 1), app: app));
    expect(_icon('p07'), findsNothing);
    room.avatarState[_ben] = AvatarPresets.content('p07');
    app.server.bumpAvatars(room);
    await tester.pump();
    expect(_icon('p07'), findsOneWidget);
  });

  test('Kontrast: Buchstabe >= 4,5 und Symbol >= 3 für alle acht Personenfarben und alle zwölf Avatare', () {
    for (final c in AuroraTokens.personColors) {
      final fg = AvatarPresetsUi.foregroundOn(c);
      expect(contrastRatio(fg, c), greaterThanOrEqualTo(MemberAvatarView.letterContrast), reason: '$c Buchstabe');
    }
    expect(AvatarPresets.all, hasLength(12));
    for (final id in AvatarPresets.all) {
      final style = AvatarPresetsUi.styles[id]!;
      final bg = AvatarPresetsUi.background(style);
      expect(contrastRatio(AvatarPresetsUi.foregroundOn(bg), bg), greaterThanOrEqualTo(MemberAvatarView.iconContrast), reason: id);
    }
  });

  test('alle zwölf Kennungen haben Symbol und Namen (de und en), ohne doppelte Namen', () async {
    expect(AvatarPresetsUi.styles.keys.toSet(), AvatarPresets.all.toSet());
    for (final lang in <String>['de', 'en']) {
      final l = await AppLocalizations.delegate.load(Locale(lang));
      final names = <String>{for (final id in AvatarPresets.all) AvatarPresetsUi.name(l, id)};
      expect(names, hasLength(12), reason: lang);
      expect(names, isNot(contains(l.avatarInitials)));
    }
  });
}
