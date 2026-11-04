import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_screen.dart';
import 'package:family_nexus/features/chat/chat_screen.dart';
import 'package:family_nexus/features/family/family_screen.dart';
import 'package:family_nexus/features/shopping/shopping_screen.dart';
import 'package:family_nexus/features/today/today_screen.dart';
import 'package:family_nexus/ui/layout/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/fake_matrix.dart';
import '../../support/test_app.dart';

/// #274, REQ-TABLET-01, E-92: Hauptansicht passt sich der nutzbaren Fläche an (Leiste, Rail, Zweispalter), ohne dass
/// beim Drehen, Verkleinern oder Tippen Zustand verloren geht.
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

void _view(WidgetTester tester, Size size, {double dpr = 1}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

Future<TestApp> _start(
  WidgetTester tester,
  Size size, {
  String lang = 'de',
  TestApp? existing,
  bool light = false,
  double textScale = 1,
}) async {
  _view(tester, size);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final app = existing ?? await buildTestApp(lang: lang, clock: () => _now);
  if (light) await app.services.settings.update((c) => c.copyWith(themeMode: AppThemeMode.light));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  return app;
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(navTab(label));
  await tester.pumpAndSettle();
}

Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  return ben;
}

bool _chatActive(WidgetTester tester) => tester.widget<ChatScreen>(find.byType(ChatScreen, skipOffstage: false)).active;

State<StatefulWidget> _state(WidgetTester tester, Type t) => tester.state(find.byType(t, skipOffstage: false));

void main() {
  setUpAll(TimeZones.ensureInitialized);

  group('Layoutklasse je Fenstergröße', () {
    // (Breite, Höhe, Rail?, Zweispalter?)
    const cases = <(double, double, bool, bool)>[
      (360, 800, false, false),
      (390, 844, false, false),
      (599, 900, false, false),
      (600, 900, true, false),
      (999, 900, true, false),
      (1000, 900, true, true),
      (1000, 479, false, false),
      (1000, 480, true, true),
      (600, 960, true, false),
      (960, 600, true, false),
      (800, 1280, true, false),
      (1280, 800, true, true),
      (1024, 1366, true, true),
      (1366, 1024, true, true),
      (844, 390, false, false),
    ];
    for (final (w, h, rail, twoPane) in cases) {
      testWidgets('${w.toInt()} × ${h.toInt()}: ${rail ? 'Rail' : 'Leiste'}${twoPane ? ', zwei Spalten' : ', eine Spalte'}', (tester) async {
        await _start(tester, Size(w, h));
        expect(find.byType(NavigationRail), rail ? findsOneWidget : findsNothing);
        expect(find.byType(NavigationBar), rail ? findsNothing : findsOneWidget);
        expect(findNavigation(), findsOneWidget);
        await _tab(tester, 'Kalender');
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(find.byType(ChatScreen), twoPane ? findsOneWidget : findsNothing, reason: 'Chat neben dem Kalender nur im Zweispalter');
        if (twoPane) {
          final cal = tester.getRect(find.byType(CalendarScreen));
          final chat = tester.getRect(find.byType(ChatScreen));
          expect(cal.width, greaterThanOrEqualTo(kPaneMinWidth));
          expect(chat.width, greaterThanOrEqualTo(kPaneMinWidth));
          expect(cal.right, lessThan(chat.left), reason: 'Kalender links, Chat rechts');
        }
        for (final t in <String>['Heute', 'Chat', 'Einkauf', 'Familie', 'Kalender']) {
          await _tab(tester, t);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Navigation', () {
    for (final size in const <Size>[Size(390, 844), Size(800, 1280)]) {
      testWidgets('alle fünf Ziele erreichbar bei ${size.width.toInt()} × ${size.height.toInt()}', (tester) async {
        await _start(tester, size);
        for (final (label, screen) in <(String, Type)>[
          ('Heute', TodayScreen),
          ('Kalender', CalendarScreen),
          ('Chat', ChatScreen),
          ('Einkauf', ShoppingScreen),
          ('Familie', FamilyScreen),
        ]) {
          await _tab(tester, label);
          expect(find.byType(screen), findsOneWidget, reason: label);
        }
      });
    }

    testWidgets('Touch-Ziele der Ziele sind mindestens 48 × 48 (Leiste und Rail)', (tester) async {
      for (final size in const <Size>[Size(390, 844), Size(800, 1280)]) {
        await _start(tester, size);
        final targets = find.descendant(of: findNavigation(), matching: find.byWidgetPredicate((w) => w is InkResponse));
        expect(targets, findsAtLeastNWidgets(5), reason: '$size');
        for (final e in targets.evaluate()) {
          final box = e.renderObject! as RenderBox;
          expect(box.size.width, greaterThanOrEqualTo(48), reason: '$size');
          expect(box.size.height, greaterThanOrEqualTo(48), reason: '$size');
        }
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Badges: ungelesene Chatnachrichten zeigen die Zahl in Leiste und Rail', (tester) async {
      for (final size in const <Size>[Size(390, 844), Size(800, 1280)]) {
        final app = await buildTestApp(clock: () => _now);
        final ben = await _joinBen(app);
        await ben.sendMessage('Hallo');
        await _start(tester, size, existing: app);
        expect(find.descendant(of: findNavigation(), matching: find.text('1')), findsOneWidget, reason: '$size');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Rail: Texte in Deutsch und Englisch, hell und dunkel', (tester) async {
      for (final (lang, light, title) in <(String, bool, String)>[
        ('de', false, 'Kalender und Chat'),
        ('de', true, 'Kalender und Chat'),
        ('en', false, 'Calendar and chat'),
        ('en', true, 'Calendar and chat'),
      ]) {
        await _start(tester, const Size(1024, 768), lang: lang, light: light);
        await tester.tap(navTab(lang == 'de' ? 'Kalender' : 'Calendar'));
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsOneWidget, reason: '$lang $light');
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('Titel: im Zweispalter bei Kalender und Chat „Kalender und Chat“, sonst der Name des Ziels', (tester) async {
      await _start(tester, const Size(1024, 768));
      Finder title(String t) => find.descendant(of: find.byType(AppBar), matching: find.text(t));
      expect(title('Heute'), findsOneWidget);
      await _tab(tester, 'Kalender');
      expect(title('Kalender und Chat'), findsOneWidget);
      await _tab(tester, 'Chat');
      expect(title('Kalender und Chat'), findsOneWidget);
      await _tab(tester, 'Einkauf');
      expect(title('Einkauf'), findsOneWidget);
      await _resize(tester, const Size(800, 1280));
      await _tab(tester, 'Kalender');
      expect(title('Kalender'), findsOneWidget, reason: 'einspaltig: Name des Ziels');
    });
  });

  group('Textgröße 200 %', () {
    for (final size in const <Size>[Size(390, 844), Size(600, 960), Size(800, 1280), Size(1024, 1366), Size(1366, 1024)]) {
      testWidgets('${size.width.toInt()} × ${size.height.toInt()}: kein Überlauf, Beschriftungen vollständig', (tester) async {
        await _start(tester, size, textScale: 2);
        for (final t in <String>['Heute', 'Kalender', 'Chat', 'Einkauf', 'Familie']) {
          await _tab(tester, t);
          expect(tester.takeException(), isNull, reason: t);
        }
        for (final label in <String>['Heute', 'Kalender', 'Chat', 'Einkauf', 'Familie']) {
          final p = tester.renderObject<RenderParagraph>(navTab(label));
          expect(p.didExceedMaxLines, isFalse, reason: 'Beschriftung $label abgeschnitten');
          final nav = tester.getRect(findNavigation());
          expect(tester.getRect(navTab(label)).right, lessThanOrEqualTo(nav.right + 0.5), reason: '$label ragt aus der Leiste');
          expect(tester.getRect(navTab(label)).left, greaterThanOrEqualTo(nav.left - 0.5), reason: '$label ragt aus der Leiste');
        }
        if (size.width >= kExpandedMin) {
          await _tab(tester, 'Kalender');
          expect(tester.getSize(find.byType(CalendarScreen)).width, greaterThanOrEqualTo(360), reason: 'Kalender bleibt mindestens so breit wie am Handy');
        }
      });
    }
  });

  group('Tastatur', () {
    testWidgets('1024 × 768 mit 350 dp Tastatur: Klasse, Rail und Chat bleiben, Eingabefeld sichtbar, active bleibt', (tester) async {
      await _start(tester, const Size(1024, 768));
      await _tab(tester, 'Chat');
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(_chatActive(tester), isTrue);
      final calendarBefore = tester.getSize(find.byType(CalendarScreen)).width;
      final chatBefore = tester.getSize(find.byType(ChatScreen)).width;

      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 350);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget, reason: 'Klasse kippt nicht auf compact');
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(CalendarScreen), findsOneWidget, reason: 'Zweispalter bleibt');
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(_chatActive(tester), isTrue, reason: 'active bleibt beim Tippen');
      expect(tester.getSize(find.byType(CalendarScreen)).width, calendarBefore);
      expect(tester.getSize(find.byType(ChatScreen)).width, chatBefore);
      final field = tester.getRect(find.byType(TextField));
      expect(field.bottom, lessThanOrEqualTo(768 - 350 + 0.5), reason: 'Eingabefeld über der Tastatur');
      expect(field.top, greaterThanOrEqualTo(0));
      expect(tester.takeException(), isNull);

      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('800 × 600 (Querformat-Tablet) mit Tastatur bleibt bei der Rail', (tester) async {
      await _start(tester, const Size(800, 600));
      await _tab(tester, 'Chat');
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sichere Ränder werden abgezogen: 1000 breit mit 40 dp Rand links wird einspaltig', (tester) async {
      await _start(tester, const Size(1000, 900));
      await _tab(tester, 'Kalender');
      expect(find.byType(ChatScreen), findsOneWidget);
      tester.view.viewPadding = const FakeViewPadding(left: 40);
      tester.view.padding = const FakeViewPadding(left: 40);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);
      await tester.pumpAndSettle();
      expect(find.byType(ChatScreen), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Größenwechsel', () {
    testWidgets('1024 → 360 → 1024: Leiste statt Rail und zurück, ohne Ausnahme', (tester) async {
      await _start(tester, const Size(1024, 768));
      await _tab(tester, 'Kalender');
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(ChatScreen), findsOneWidget);
      await _resize(tester, const Size(360, 800));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(ChatScreen), findsNothing);
      await _tab(tester, 'Chat');
      expect(find.byType(ChatScreen), findsOneWidget);
      await _resize(tester, const Size(1024, 768));
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final width in <double>[1000, 1024]) {
      testWidgets('Tabwechsel Heute → Kalender → Chat bei ${width.toInt()}: Zweispalter ohne Ausnahme', (tester) async {
        await _start(tester, Size(width, 900));
        await _tab(tester, 'Heute');
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(find.byType(CalendarScreen), findsNothing);
        await _tab(tester, 'Kalender');
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(find.byType(TodayScreen), findsNothing);
        await _tab(tester, 'Chat');
        expect(find.byType(CalendarScreen), findsOneWidget);
        expect(find.byType(ChatScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('alle fünf Seiten behalten ihren State über Hoch ↔ Quer und Klassenwechsel', (tester) async {
      await _start(tester, const Size(400, 800));
      final screens = <Type>[TodayScreen, CalendarScreen, ChatScreen, ShoppingScreen, FamilyScreen];
      Element? elementOf(Type t) => find.byType(t, skipOffstage: false).evaluate().firstOrNull;
      final before = <Element?>[for (final t in screens) elementOf(t)];
      expect(before.whereType<Element>(), hasLength(5));
      for (final size in const <Size>[
        Size(700, 900),
        Size(1100, 800),
        Size(800, 1100),
        Size(1100, 800),
        Size(900, 700),
        Size(844, 390),
        Size(1024, 1366),
        Size(400, 800),
      ]) {
        await _resize(tester, size);
        await _tab(tester, 'Kalender');
        await _tab(tester, 'Chat');
        await _tab(tester, 'Einkauf');
        await _tab(tester, 'Heute');
      }
      for (var i = 0; i < screens.length; i++) {
        expect(identical(elementOf(screens[i]), before[i]), isTrue, reason: '${screens[i]}: Element wurde ersetzt, State verloren');
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Chat: Entwurf, gewähltes Gespräch und Scrollposition über expanded ↔ medium bei Tab Kalender', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      final ben = await _joinBen(app);
      final id = await app.gateway.startDirectChat(ben.userId!);
      for (var i = 0; i < 40; i++) {
        await app.gateway.sendMessage('Nachricht $i', threadId: id);
      }
      await _start(tester, const Size(1000, 900), existing: app);
      await _tab(tester, 'Kalender');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Entwurf an Ben');
      await tester.pump();
      final list = find.descendant(of: find.byType(ChatScreen), matching: find.byType(ListView)).last;
      await tester.drag(list, const Offset(0, 300));
      await tester.pumpAndSettle();
      double pixels() => tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position.pixels;
      final scrolled = pixels();
      expect(scrolled, isNot(0));
      final state = _state(tester, ChatScreen);

      for (final size in const <Size>[Size(800, 1280), Size(1000, 900), Size(960, 600), Size(1280, 800)]) {
        await _resize(tester, size);
        final chat = find.byType(ChatScreen, skipOffstage: false);
        final field = find.descendant(of: chat, matching: find.byType(TextField, skipOffstage: false), skipOffstage: false);
        expect(tester.widget<TextField>(field).controller!.text, 'Entwurf an Ben', reason: '$size');
        final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Ben', skipOffstage: false));
        expect(chip.selected, isTrue, reason: 'Gespräch Ben bleibt gewählt, $size');
        expect(identical(_state(tester, ChatScreen), state), isTrue, reason: '$size');
        expect(_chatActive(tester), size.width >= kExpandedMin, reason: 'active folgt der Sichtbarkeit, $size');
      }
      await _resize(tester, const Size(1000, 900));
      expect(pixels(), closeTo(scrolled, 0.5), reason: 'Scrollposition bleibt');
      expect(app.gateway.messagesIn(id), hasLength(40), reason: 'kein zusätzliches Senden');
      expect(app.gateway.messages, isEmpty);
    });

    testWidgets('Kalender: Datum und Ansicht bleiben über compact → medium → expanded', (tester) async {
      await _start(tester, const Size(400, 800));
      await _tab(tester, 'Kalender');
      await tester.tap(find.text('Woche'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Weiter'));
      await tester.pumpAndSettle();
      final calendar = _state(tester, CalendarScreen);
      final selected = tester.widget<SegmentedButton<CalendarMode>>(find.byType(SegmentedButton<CalendarMode>)).selected;
      expect(selected, <CalendarMode>{CalendarMode.week});
      final title = find.descendant(of: find.byType(CalendarScreen), matching: find.textContaining('2026'));
      final titleText = tester.widget<Text>(title.first).data;

      for (final size in const <Size>[Size(700, 900), Size(1100, 800), Size(800, 1100), Size(400, 800)]) {
        await _resize(tester, size);
        await _tab(tester, 'Kalender');
        expect(identical(_state(tester, CalendarScreen), calendar), isTrue, reason: '$size');
        expect(tester.widget<SegmentedButton<CalendarMode>>(find.byType(SegmentedButton<CalendarMode>)).selected, selected, reason: '$size');
        expect(tester.widget<Text>(find.descendant(of: find.byType(CalendarScreen), matching: find.textContaining('2026')).first).data, titleText,
            reason: '$size');
      }
    });

    testWidgets('Einkauf: Eingabe und Scrollposition bleiben über compact → medium → expanded', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await _start(tester, const Size(400, 700), existing: app);
      for (var i = 0; i < 30; i++) {
        await app.services.shopping!.add('Artikel $i');
      }
      await _tab(tester, 'Einkauf');
      await tester.enterText(find.widgetWithText(TextField, 'Was wird gebraucht?'), 'Halbfertig');
      final list = find.descendant(of: find.byType(ShoppingScreen), matching: find.byType(ListView));
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      double pixels() => tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position.pixels;
      final scrolled = pixels();
      expect(scrolled, greaterThan(0));
      for (final size in const <Size>[Size(700, 700), Size(1100, 700), Size(400, 700)]) {
        await _resize(tester, size);
        expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Halbfertig')).controller!.text, 'Halbfertig', reason: '$size');
        expect(pixels(), closeTo(scrolled, 0.5), reason: '$size');
      }
      expect(app.shoppingStore.items.length, 30, reason: 'nichts zusätzlich hinzugefügt');
    });

    testWidgets('Heute: Scrollposition bleibt über compact → medium', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await _start(tester, const Size(400, 500), existing: app, textScale: 1.5);
      for (var i = 0; i < 3; i++) {
        await app.services.calendar!.create(
          title: 'Termin $i',
          start: DateTime.utc(2026, 3, 21 + i, 9),
          end: DateTime.utc(2026, 3, 21 + i, 10),
          visibility: EventVisibility.private,
        );
      }
      await tester.pumpAndSettle();
      final list = find.descendant(of: find.byType(TodayScreen), matching: find.byType(ListView));
      await tester.drag(list, const Offset(0, -150));
      await tester.pumpAndSettle();
      double pixels() => tester.state<ScrollableState>(find.descendant(of: list, matching: find.byType(Scrollable)).first).position.pixels;
      final scrolled = pixels();
      expect(scrolled, greaterThan(0));
      await _resize(tester, const Size(650, 500));
      expect(pixels(), closeTo(scrolled, 0.5));
      await _resize(tester, const Size(400, 500));
      expect(pixels(), closeTo(scrolled, 0.5));
    });

    testWidgets('Terminformular mit ungespeicherter Eingabe überlebt die Größenänderung ohne Speichern', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await _start(tester, const Size(800, 1280), existing: app);
      await _tab(tester, 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Elternabend');
      await tester.pump();
      for (final size in const <Size>[Size(1280, 800), Size(800, 1280), Size(360, 800), Size(1024, 1366)]) {
        await _resize(tester, size);
        expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Elternabend')).controller!.text, 'Elternabend', reason: '$size');
      }
      expect(await app.events.all(), isEmpty, reason: 'nicht gespeichert');
      expect(app.server.log.where((e) => e.type.contains('event')), isEmpty, reason: 'nicht gesendet');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect((await app.events.all()), hasLength(1), reason: 'genau einmal, erst auf Wunsch');
    });

    testWidgets('geöffneter Dialog mit Eingabe überlebt die Größenänderung', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      await app.services.shopping?.add('Brot');
      await _start(tester, const Size(800, 1280), existing: app);
      await app.services.shopping!.add('Brot');
      await _tab(tester, 'Einkauf');
      await tester.tap(find.byTooltip('Brot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bearbeiten'));
      await tester.pumpAndSettle();
      final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first;
      await tester.enterText(field, 'Vollkornbrot');
      await tester.pump();
      for (final size in const <Size>[Size(1280, 800), Size(360, 800), Size(800, 1280)]) {
        await _resize(tester, size);
        expect(find.byType(AlertDialog), findsOneWidget, reason: '$size');
        expect(tester.widget<TextField>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first).controller!.text,
            'Vollkornbrot',
            reason: '$size');
      }
      expect(app.shoppingStore.items.values.map((i) => i.title), <String>['Brot'], reason: 'nichts gespeichert');
    });
  });

  group('Chat sichtbar = gelesen (active)', () {
    Future<(TestApp, String)> unread(WidgetTester tester, Size size) async {
      final app = await buildTestApp(clock: () => _now);
      final ben = await _joinBen(app);
      await ben.sendMessage('Neu für dich');
      await _start(tester, size, existing: app);
      return (app, 'family');
    }

    testWidgets('expanded + Kalender: active, Nachricht gilt als gelesen', (tester) async {
      final (app, _) = await unread(tester, const Size(1024, 768));
      expect(app.gateway.unreadCount, 1);
      await _tab(tester, 'Kalender');
      expect(_chatActive(tester), isTrue);
      expect(app.gateway.unreadCount, 0, reason: 'sichtbarer Chat neben dem Kalender');
    });

    testWidgets('expanded + Heute: nicht active, ungelesen bleibt', (tester) async {
      final (app, _) = await unread(tester, const Size(1024, 768));
      expect(_chatActive(tester), isFalse);
      expect(app.gateway.unreadCount, 1);
    });

    testWidgets('medium + Kalender: nicht active, ungelesen bleibt; Tab Chat: active', (tester) async {
      final (app, _) = await unread(tester, const Size(800, 1280));
      await _tab(tester, 'Kalender');
      expect(_chatActive(tester), isFalse);
      expect(app.gateway.unreadCount, 1);
      expect(app.services.visibleChatThread, isNull);
      await _tab(tester, 'Chat');
      expect(_chatActive(tester), isTrue);
      expect(app.gateway.unreadCount, 0);
    });

    testWidgets('Drehen von expanded nach medium bei Tab Kalender: active wird false, neue Nachricht bleibt ungelesen', (tester) async {
      final app = await buildTestApp(clock: () => _now);
      final ben = await _joinBen(app);
      await _start(tester, const Size(1000, 900), existing: app);
      await _tab(tester, 'Kalender');
      expect(_chatActive(tester), isTrue);
      expect(app.services.visibleChatThread, isNotNull);
      await _resize(tester, const Size(800, 1280));
      expect(_chatActive(tester), isFalse);
      expect(app.services.visibleChatThread, isNull);
      await ben.sendMessage('Während verdeckt');
      await tester.pumpAndSettle();
      expect(app.gateway.unreadCount, 1);
      await _resize(tester, const Size(1000, 900));
      expect(_chatActive(tester), isTrue);
      expect(app.gateway.unreadCount, 0);
    });
  });

  group('Blasenbreite je Spalte', () {
    final longText = List<String>.filled(60, 'lang').join(' ');

    Future<double> bubbleWidth(WidgetTester tester, Size size) async {
      final app = await buildTestApp(clock: () => _now);
      final ben = await _joinBen(app);
      await ben.sendMessage(longText);
      await _start(tester, size, existing: app);
      await _tab(tester, size.width >= kExpandedMin ? 'Kalender' : 'Chat');
      final bubble = find.descendant(
        of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Bubble'),
        matching: find.byType(ConstrainedBox),
      );
      expect(bubble, findsWidgets);
      final card = find.descendant(of: find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Bubble'), matching: find.text(longText));
      return tester.getSize(find.ancestor(of: card, matching: find.byType(Container)).first).width;
    }

    testWidgets('Zweispalter 1366: höchstens 82 % der Chatspalte, nicht des Fensters', (tester) async {
      final w = await bubbleWidth(tester, const Size(1366, 1024));
      final pane = tester.getSize(find.byType(ChatScreen)).width;
      final rail = tester.getSize(findNavigation()).width;
      expect(pane, closeTo(paneWidths(1366 - rail).chat, 0.5), reason: 'Spaltenbreite aus der tatsächlichen Rail-Breite');
      expect(w, lessThanOrEqualTo(pane * 0.82 + 0.5));
      expect(w, greaterThan(pane * 0.82 - 40), reason: 'lange Nachricht füllt die Obergrenze');
    });

    testWidgets('einspaltig 800: Obergrenze 560', (tester) async {
      final w = await bubbleWidth(tester, const Size(800, 1280));
      expect(w, lessThanOrEqualTo(560.5));
      expect(w, greaterThan(500));
    });

    testWidgets('Handy 360: 82 % der Breite', (tester) async {
      final w = await bubbleWidth(tester, const Size(360, 800));
      expect(w, lessThanOrEqualTo(360 * 0.82 + 0.5));
      expect(w, greaterThan(360 * 0.82 - 40));
    });
  });

  group('Inhaltsbreite', () {
    testWidgets('Heute, Einkauf und Familie sind ab 800 auf 720 begrenzt und zentriert; Handy unbegrenzt', (tester) async {
      await _start(tester, const Size(1366, 1024));
      for (final (tab, type) in <(String, Type)>[('Heute', TodayScreen), ('Einkauf', ShoppingScreen), ('Familie', FamilyScreen)]) {
        await _tab(tester, tab);
        final r = tester.getRect(find.byType(type));
        expect(r.width, kContentMaxWidth, reason: tab);
      }
      await _resize(tester, const Size(390, 844));
      for (final (tab, type) in <(String, Type)>[('Heute', TodayScreen), ('Einkauf', ShoppingScreen), ('Familie', FamilyScreen)]) {
        await _tab(tester, tab);
        expect(tester.getSize(find.byType(type)).width, 390, reason: tab);
      }
      await _resize(tester, const Size(844, 390));
      await _tab(tester, 'Heute');
      expect(tester.getSize(find.byType(TodayScreen)).width, 844, reason: 'Handy quer: Leiste, keine Begrenzung');
    });
  });
}
