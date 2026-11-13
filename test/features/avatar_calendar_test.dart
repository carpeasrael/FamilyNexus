import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/member_avatars.dart';
import 'package:family_nexus/domain/occurrence.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:family_nexus/features/calendar/event_detail_screen.dart';
import 'package:family_nexus/features/calendar/event_tile.dart';
import 'package:family_nexus/features/family/avatar_presets_ui.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// #422, E-101: Im Kalender ersetzt der Avatar mit Ring in der Personenfarbe den Personenpunkt; die Bedingungen, unter
/// denen er erscheint, sind dieselben wie beim Punkt.
const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _schule = '00000000-0000-4000-8000-0000000000a1';
const String _evId = '11111111-1111-4111-8111-111111111111';
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

CalendarEvent _event({String owner = _ben, String? themeId, EventVisibility visibility = EventVisibility.shared}) => CalendarEvent(
      id: _evId,
      ownerId: owner,
      title: 'Elternabend',
      start: DateTime.utc(2026, 3, 21, 17),
      end: DateTime.utc(2026, 3, 21, 18),
      timeZone: 'Europe/Berlin',
      updatedAt: DateTime.utc(2026, 3, 1),
      visibility: visibility,
      themeId: themeId,
    );

EventTheme _theme() =>
    EventTheme(id: _schule, name: 'Schule', colorIndex: 2, by: _anna, version: 1, deleted: false, updatedAt: DateTime.utc(2026, 3, 1));

Occurrence _occ(CalendarEvent e) => Occurrence(event: e, start: e.start, end: e.end, dateKey: '2026-03-21');

TestApp? _current;

/// Wie `testWidgets`, schließt aber danach die Dienste, damit keine Zeitgeber der Synchronisation offen bleiben.
void _testUi(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox());
        _current?.services.closeCalendar();
        _current = null;
      }
    });

Future<CalendarController> _open(TestApp app, {List<CalendarEvent> events = const <CalendarEvent>[]}) async {
  _current = app;
  await app.themeStore.put(_theme(), publishedVersion: 1);
  for (final e in events) {
    await app.events.put(e, publishedVersion: e.version);
  }
  await app.services.openCalendar();
  final c = app.services.calendar!;
  await c.load();
  return c;
}

Widget _host(TestApp app, Widget child) => AppScope(
      services: app.services,
      child: MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Finder _avatar(String id) => find.byKey(ValueKey<String>('avatar-$id'));

MemberAvatarView _view(WidgetTester tester, Finder f) => tester.widget<MemberAvatarView>(f);

void main() {
  _testUi('Kachel: Avatar (16 dp, Ring in der Personenfarbe) dort, wo heute der Punkt erscheint, mit Namen daneben', (tester) async {
    final app = await buildTestApp(clock: () => _now);
    addTearDown(app.services.closeCalendar);
    final c = await _open(app);
    final room = app.gateway.familyRoom!;
    room.membership[_ben] = MemberStatus.joined;
    room.avatarState[_ben] = AvatarPresets.content('p07');
    await tester.pumpWidget(_host(app, EventTile(occurrence: _occ(_event()), controller: c, onTap: () {})));
    await tester.pump();
    expect(_avatar(_ben), findsOneWidget, reason: 'fremder Termin: wie bisher der Punkt');
    final v = _view(tester, _avatar(_ben));
    expect((v.size, v.ring, v.colorIndex), (16.0, true, c.colorIndexFor(_ben)));
    expect(find.descendant(of: _avatar(_ben), matching: find.byIcon(AvatarPresetsUi.styles['p07']!.icon)), findsOneWidget);
    expect(find.textContaining('Von '), findsOneWidget, reason: 'der Avatar steht immer mit Namen');
    await tester.pumpWidget(_host(app, EventTile(occurrence: _occ(_event(owner: _anna)), controller: c, onTap: () {})));
    await tester.pump();
    expect(find.byType(MemberAvatarView), findsNothing, reason: 'eigener Termin ohne Thema: kein Avatar, wie kein Punkt');
    await tester.pumpWidget(_host(app, EventTile(occurrence: _occ(_event(owner: _anna, themeId: _schule)), controller: c, onTap: () {})));
    await tester.pump();
    expect(_avatar(_anna), findsOneWidget, reason: 'eigener Termin mit Thema: Avatar mit „Von dir“');
    expect(find.text('Von dir'), findsOneWidget);
  });

  _testUi('Terminkarte: Avatar (20 dp) nur mit Thema über ownerId; Zusagenliste immer (24 dp)', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => _now);
    addTearDown(app.services.closeCalendar);
    final room = app.gateway.familyRoom!;
    room.membership[_ben] = MemberStatus.joined;
    room.avatarState[_ben] = AvatarPresets.content('p02');
    final themed = _event(themeId: _schule);
    final c = await _open(app, events: <CalendarEvent>[themed]);
    await c.respond(themed.id, RsvpStatus.accepted);
    await tester.pumpWidget(_host(app, SizedBox(height: 2500, child: EventDetailScreen(controller: c, occurrence: _occ(themed)))));
    await tester.pumpAndSettle();
    final sizes = <double>[for (final e in find.byType(MemberAvatarView).evaluate()) (e.widget as MemberAvatarView).size];
    expect(sizes, contains(20.0), reason: 'Terminkarte mit Thema');
    expect(sizes, contains(24.0), reason: 'Zusagenliste');
    final owner = find.byWidgetPredicate((w) => w is MemberAvatarView && w.userId == _ben && w.size == 20);
    expect(owner, findsOneWidget);
    expect((tester.widget<MemberAvatarView>(owner)).colorIndex, c.colorIndexFor(_ben), reason: 'ownerId und Personenfarbe kommen vom Besitzer');
    final rsvp = find.byWidgetPredicate((w) => w is MemberAvatarView && w.userId == _anna && w.size == 24);
    expect(rsvp, findsOneWidget, reason: 'Zusage von Anna in der Liste');
    expect(AuroraTokens.personColors[(tester.widget<MemberAvatarView>(rsvp)).colorIndex], isNotNull);
    expect(find.text('Von Ben'), findsOneWidget);
  });

  _testUi('Terminkarte ohne Thema: kein Avatar des Besitzers (Bedingung wie beim Punkt)', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => _now);
    addTearDown(app.services.closeCalendar);
    final plain = _event();
    final c = await _open(app, events: <CalendarEvent>[plain]);
    await tester.pumpWidget(_host(app, SizedBox(height: 2500, child: EventDetailScreen(controller: c, occurrence: _occ(plain)))));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is MemberAvatarView && w.size == 20), findsNothing);
  });

  _testUi('Personenfilter: Avatar (20 dp) im FilterChip, Personenfarbe als Ring', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => _now);
    addTearDown(app.services.closeCalendar);
    final room = app.gateway.familyRoom!;
    final ben = app.server.newDevice();
    await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
    room.membership[_ben] = MemberStatus.joined;
    ben.attachFamilyRoom(room.id);
    room.avatarState[_ben] = AvatarPresets.content('p11');
    await _open(app);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Kalender'));
    await tester.pumpAndSettle();
    final chip = find.ancestor(of: _avatar(_ben), matching: find.byType(FilterChip));
    expect(chip, findsOneWidget);
    final v = _view(tester, _avatar(_ben));
    expect((v.size, v.ring), (20.0, true));
    expect(find.descendant(of: chip, matching: find.text('Ben')), findsOneWidget, reason: 'Name steht im Chip');
  });
}
