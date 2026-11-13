import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/event_theme_codec.dart';
import 'package:family_nexus/domain/event_themes.dart';
import 'package:family_nexus/domain/occurrence.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:family_nexus/features/calendar/event_tile.dart';
import 'package:family_nexus/features/calendar/themes_screen.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';
const String _schule = '00000000-0000-4000-8000-0000000000a1';
const String _sport = '00000000-0000-4000-8000-0000000000a2';
const String _evId = '11111111-1111-4111-8111-111111111111';
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

CalendarEvent _event({
  String owner = _anna,
  EventVisibility visibility = EventVisibility.shared,
  String? themeId,
  int color = 0,
  String id = _evId,
}) =>
    CalendarEvent(
      id: id,
      ownerId: owner,
      title: 'Elternabend',
      start: DateTime.utc(2026, 3, 21, 17),
      end: DateTime.utc(2026, 3, 21, 18),
      timeZone: 'Europe/Berlin',
      updatedAt: DateTime.utc(2026, 3, 1),
      visibility: visibility,
      colorIndex: color,
      themeId: themeId,
    );

EventTheme _theme(String id, String name, int color, {bool deleted = false}) =>
    EventTheme(id: id, name: deleted ? '' : name, colorIndex: color, by: _anna, version: deleted ? 2 : 1, deleted: deleted, updatedAt: DateTime.utc(2026, 3, 1));

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

Future<CalendarController> _open(TestApp app, {List<EventTheme> themes = const <EventTheme>[], List<CalendarEvent> events = const <CalendarEvent>[]}) async {
  for (final t in themes) {
    await app.themeStore.put(t, publishedVersion: t.version);
  }
  for (final e in events) {
    await app.events.put(e, publishedVersion: e.version);
  }
  _current = app;
  await app.services.openCalendar();
  final c = app.services.calendar!;
  await c.load();
  return c;
}

Color _color(int i) => AuroraTokens.personColors[i];

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Anzeigefarbe (displayColor)', () {
    test('privat ist fest Himmelblau, auch bei früher gewählter anderer Farbe', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      expect(c.displayColor(_event(visibility: EventVisibility.private, color: 5)), EventTheme.privateColorIndex);
      expect(AuroraTokens.personColors[EventTheme.privateColorIndex], const Color(0xFF38BDF8));
    });

    test('geteilt mit bekanntem Thema: Themenfarbe, unabhängig von Besitzer und alter Farbe', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      expect(c.displayColor(_event(themeId: _schule, color: 5)), 2);
      expect(c.displayColor(_event(owner: _ben, themeId: _schule, color: 6)), 2);
      expect(c.themeFor(_event(themeId: _schule))!.name, 'Schule');
    });

    test('geteilt ohne Thema: bisheriges Verhalten (eigene gewählte Farbe, fremde Personenfarbe)', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app);
      expect(c.displayColor(_event(color: 5)), 5);
      expect(c.displayColor(_event(owner: _ben, color: 5)), c.colorIndexFor(_ben));
    });

    test('Altbestand wird nie umgefärbt: geteilter Termin in Himmelblau bleibt Himmelblau', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app);
      expect(c.displayColor(_event(color: 3)), 3);
      expect(c.displayColor(_event(color: 3)), c.displayColorIndex(_event(color: 3)));
    });

    test('gelöschtes oder unbekanntes Thema: Rückfall auf die bisherige Farbe', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2), _theme(_sport, '', 5, deleted: true)]);
      expect(c.eventThemes.map((t) => t.id), [_schule], reason: 'Löschmarken sind keine aktiven Themen');
      expect(c.displayColor(_event(themeId: _sport, color: 4)), 4);
      expect(c.displayColor(_event(themeId: '00000000-0000-4000-8000-0000000000ff', color: 4)), 4);
      expect(c.themeFor(_event(themeId: _sport)), isNull);
    });

    test('ein privater Termin zeigt nie ein Thema, auch wenn ein Altwert eine ID enthielte', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      expect(c.themeFor(_event(visibility: EventVisibility.private, themeId: _schule)), isNull);
    });

    test('Themen sind nach Name sortiert; ein später eintreffendes Thema färbt nachträglich', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_sport, 'sport', 5), _theme(_schule, 'Schule', 2)]);
      expect(c.eventThemes.map((t) => t.name), ['Schule', 'sport']);
      final late = '00000000-0000-4000-8000-0000000000b1';
      final e = _event(themeId: late, color: 4);
      expect(c.displayColor(e), 4);
      await app.themeStore.put(_theme(late, 'Chor', 6), publishedVersion: 1);
      await c.load();
      expect(c.displayColor(e), 6);
    });
  });

  group('Wechsel der Sichtbarkeit', () {
    test('geteilt -> privat setzt das Thema zurück, privat -> geteilt + Auswahl setzt es', () async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      final e = await c.create(
        title: 'Elternabend',
        start: DateTime.utc(2026, 3, 21, 17),
        end: DateTime.utc(2026, 3, 21, 18),
        visibility: EventVisibility.shared,
        themeId: _schule,
      );
      expect(e.themeId, _schule);
      final p = await c.update(e, visibility: EventVisibility.private);
      expect(p.visibility, EventVisibility.private);
      expect(p.themeId, isNull);
      expect(c.displayColor(p), EventTheme.privateColorIndex);
      final s = await c.update(p.copyWith(themeId: _schule), visibility: EventVisibility.shared);
      expect(s.isShared, isTrue);
      expect(s.themeId, _schule);
    });
  });

  group('Kachel', () {
    Future<void> pumpTile(WidgetTester tester, CalendarController c, CalendarEvent e, {String lang = 'de'}) async {
      final occ = Occurrence(event: e, start: e.start, end: e.end, dateKey: '2026-03-21');
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: SingleChildScrollView(child: EventTile(occurrence: occ, controller: c, onTap: () {}))),
      ));
      await tester.pump();
    }

    Finder bar(Color color) => find.byWidgetPredicate((w) {
          if (w is! Container || w.constraints?.maxWidth != 4) return false;
          final d = w.decoration;
          return d is BoxDecoration && d.color == color;
        });

    // Die Personenfarbe des Besitzers steht seit #422 als Ring am Avatar (früher als Punkt).
    Finder dot(Color color) => find.byWidgetPredicate((w) => w is MemberAvatarView && w.ring && AuroraTokens.personColors[w.colorIndex] == color);
    Finder ring(Color color) => find.descendant(
          of: find.byType(MemberAvatarView),
          matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).border?.top.color == color),
        );

    _testUi('privat: blau, kein Thema im Label', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await pumpTile(tester, c, _event(visibility: EventVisibility.private, color: 5));
      expect(bar(_color(3)), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Privat')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Thema')), findsNothing);
      handle.dispose();
    });

    _testUi('en: geteilt mit Thema: Label "Theme Schule", Themenname als Text (l10n en)', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await buildTestApp(lang: 'en', clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await pumpTile(tester, c, _event(owner: _ben, themeId: _schule, color: 5), lang: 'en');
      expect(find.text('Schule'), findsOneWidget, reason: 'nie nur Farbe');
      expect(find.bySemanticsLabel(RegExp(r'Shared, Theme Schule')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Thema')), findsNothing, reason: 'kein deutscher Text in der englischen App');
      handle.dispose();
    });

    _testUi('geteilt mit Thema: Themenfarbe, Themenname als Text, Avatar mit Ring und Name, Label "Thema Schule"', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await pumpTile(tester, c, _event(owner: _ben, themeId: _schule, color: 5));
      expect(bar(_color(2)), findsOneWidget);
      expect(find.text('Schule'), findsOneWidget, reason: 'nie nur Farbe');
      expect(dot(_color(c.colorIndexFor(_ben))), findsOneWidget, reason: 'Personenfarbe des Besitzers bleibt als Ring am Avatar');
      expect(ring(_color(c.colorIndexFor(_ben))), findsOneWidget, reason: 'der Ring wird auch gezeichnet');
      expect(find.textContaining('Von '), findsOneWidget, reason: 'Der Punkt steht immer mit Namen');
      expect(find.bySemanticsLabel(RegExp(r'Geteilt, Thema Schule')), findsOneWidget);
      handle.dispose();
    });

    _testUi('eigener geteilter Termin mit Thema: Avatar mit "Von dir"', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await pumpTile(tester, c, _event(themeId: _schule));
      expect(find.text('Von dir'), findsOneWidget);
      expect(find.byType(MemberAvatarView), findsOneWidget);
    });

    _testUi('ohne Thema: alte Farbe; geteilter Altbestand in Himmelblau bleibt Himmelblau, Abzeichen "Geteilt" trägt die Unterscheidung', (tester) async {
      final handle = tester.ensureSemantics();
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app);
      await pumpTile(tester, c, _event(color: 4));
      expect(bar(_color(4)), findsOneWidget);
      expect(find.byType(MemberAvatarView), findsNothing);
      await pumpTile(tester, c, _event(color: 3));
      expect(bar(_color(3)), findsOneWidget, reason: 'nicht umgefärbt');
      expect(find.text('Geteilt'), findsOneWidget, reason: 'Abzeichen mit Text, nie die Farbe allein');
      expect(find.bySemanticsLabel(RegExp('Geteilt')), findsOneWidget);
      handle.dispose();
    });

    _testUi('Thema gelöscht: Rückfall auf die alte Farbe, kein Themenname', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, '', 2, deleted: true)]);
      await pumpTile(tester, c, _event(themeId: _schule, color: 4));
      expect(bar(_color(4)), findsOneWidget);
      expect(find.byIcon(Icons.label_outline), findsNothing);
    });
  });

  group('Termin-Editor', () {
    Future<void> openEditor(WidgetTester tester, TestApp app) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
    }

    Future<void> tapText(WidgetTester tester, String text) async {
      final f = find.text(text);
      await tester.ensureVisible(f.first);
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    testWidgets('Auswahl nur bei geteilt; privat zeigt den Hinweis "Privat: immer blau" und keine Farbwahl', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await app.themeStore.put(_theme(_schule, 'Schule', 2), publishedVersion: 1);
      await openEditor(tester, app);
      expect(find.text('Privat: immer blau'), findsOneWidget);
      expect(find.text('Ohne Thema'), findsNothing);
      expect(find.text('Schule'), findsNothing);
      expect(find.text('Farbe 1'), findsNothing, reason: 'die freie Farbwahl entfällt');
      await tapText(tester, 'Geteilt');
      expect(find.text('Privat: immer blau'), findsNothing);
      expect(find.text('Ohne Thema'), findsOneWidget);
      expect(find.text('Schule'), findsOneWidget, reason: 'Chip mit Name (und Farbpunkt)');
      expect(find.text('Farbe 1'), findsNothing);
    });

    testWidgets('Speichern eines geteilten Termins schreibt die gewählte themeId', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await app.themeStore.put(_theme(_schule, 'Schule', 2), publishedVersion: 1);
      await app.themeStore.put(_theme(_sport, 'Sport', 5), publishedVersion: 1);
      await openEditor(tester, app);
      await tester.enterText(find.byType(TextFormField).first, 'Elternabend');
      await tapText(tester, 'Geteilt');
      await tapText(tester, 'Schule');
      await tapText(tester, 'Speichern');
      final saved = (await app.events.all()).single;
      expect((saved.title, saved.isShared, saved.themeId), ('Elternabend', true, _schule));
    });

    testWidgets('geteilt ohne Auswahl: kein Thema; privat gespeichert: nie ein Thema', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await app.themeStore.put(_theme(_schule, 'Schule', 2), publishedVersion: 1);
      await openEditor(tester, app);
      await tester.enterText(find.byType(TextFormField).first, 'Zahnarzt');
      await tapText(tester, 'Speichern');
      final saved = (await app.events.all()).single;
      expect(saved.isShared, isFalse);
      expect(saved.themeId, isNull);
    });
  });

  group('Themenbildschirm (Moderatoren)', () {
    Future<(TestApp, CalendarController)> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp(clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('de'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: AppScope(services: app.services, child: ThemesScreen(controller: c)),
      ));
      await tester.pumpAndSettle();
      return (app, c);
    }

    _testUi('en: Titel, Farbname und Dialog sind englisch, Himmelblau fehlt (l10n en)', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await buildTestApp(lang: 'en', clock: () => _now);
      addTearDown(app.services.closeCalendar);
      final c = await _open(app, themes: [_theme(_schule, 'Schule', 2)]);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: AppScope(services: app.services, child: ThemesScreen(controller: c)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Calendar themes'), findsOneWidget);
      expect(find.text('Schule'), findsOneWidget);
      expect(find.text('Purple'), findsOneWidget);
      expect(find.text('Kalender-Themen'), findsNothing);
      await tester.tap(find.text('Add theme'));
      await tester.pumpAndSettle();
      for (final n in <String>['Teal', 'Pink', 'Purple', 'Yellow', 'Green', 'Orange', 'Red']) {
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(n)), findsOneWidget, reason: n);
      }
      expect(find.text('Sky blue'), findsNothing, reason: 'belongs to “private”');
    });

    _testUi('listet Themen mit Name und Farbname (nie nur Farbe)', (tester) async {
      await pumpScreen(tester);
      expect(find.text('Kalender-Themen'), findsOneWidget);
      expect(find.text('Schule'), findsOneWidget);
      expect(find.text('Lila'), findsOneWidget);
    });

    _testUi('Anlegen: sieben benannte Farben, Himmelblau fehlt; das Thema wird gespeichert und zum Senden vorgemerkt', (tester) async {
      final (app, c) = await pumpScreen(tester);
      await tester.tap(find.text('Thema anlegen'));
      await tester.pumpAndSettle();
      for (final n in <String>['Türkis', 'Rosa', 'Lila', 'Gelb', 'Grün', 'Orange', 'Rot']) {
        expect(find.descendant(of: find.byType(AlertDialog), matching: find.text(n)), findsOneWidget, reason: n);
      }
      expect(find.text('Himmelblau'), findsNothing, reason: 'gehört „privat“');
      await tester.enterText(find.byType(TextField), 'Sport');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Grün')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final t = c.eventThemes.firstWhere((x) => x.name == 'Sport');
      expect((t.colorIndex, t.by), (5, _anna));
      // Die Synchronisation sendet es als Ereignis ein Thema je Datensatz in den Familienraum.
      final sent = app.server.log.where((e) => e.type == EventThemeCodec.type).toList();
      expect(sent, hasLength(1));
      expect((sent.single.content['name'], sent.single.content['color'], sent.single.content['id']), ('Sport', 5, t.id));
      expect(find.text('Sport'), findsOneWidget);
      expect(find.text('Thema gespeichert.'), findsOneWidget);
    });

    _testUi('Umbenennen und Farbe ändern erhöhen die Version', (tester) async {
      final (_, c) = await pumpScreen(tester);
      await tester.tap(find.byTooltip('Thema ändern'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Uni');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Rot')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final t = c.themeOf(_schule)!;
      expect((t.name, t.colorIndex, t.version), ('Uni', 7, 2));
    });

    _testUi('Löschen nach Rückfrage entfernt das Thema aus der Liste (Löschmarke bleibt zum Senden)', (tester) async {
      final (app, c) = await pumpScreen(tester);
      await tester.tap(find.byTooltip('Thema löschen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Geteilte Termine mit diesem Thema zeigen danach wieder ihre bisherige Farbe'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Löschen')));
      await tester.pumpAndSettle();
      expect(c.eventThemes, isEmpty);
      expect(find.text('Noch keine Themen. Lege das erste an.'), findsOneWidget);
      expect((await app.themeStore.get(_schule))!.deleted, isTrue);
    });
  });
}
