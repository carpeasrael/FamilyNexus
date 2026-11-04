import 'package:family_nexus/ui/layout/adaptive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #274, E-92: Layoutgrenzen und Hilfen an der Klemme (unter, auf und über jeder Grenze).
void main() {
  group('windowClassOf', () {
    test('Breite 599 compact, 600 medium (Höhe ausreichend)', () {
      expect(windowClassOf(const Size(599, 900)), WindowClass.compact);
      expect(windowClassOf(const Size(600, 900)), WindowClass.medium);
      expect(windowClassOf(const Size(601, 900)), WindowClass.medium);
    });

    test('Breite 999 medium, 1000 expanded', () {
      expect(windowClassOf(const Size(999, 900)), WindowClass.medium);
      expect(windowClassOf(const Size(1000, 900)), WindowClass.expanded);
      expect(windowClassOf(const Size(1001, 900)), WindowClass.expanded);
    });

    test('Höhe 479 compact, 480 nicht compact (auch bei großer Breite)', () {
      expect(windowClassOf(const Size(1000, 479)), WindowClass.compact);
      expect(windowClassOf(const Size(1000, 480)), WindowClass.expanded);
      expect(windowClassOf(const Size(800, 479)), WindowClass.compact);
      expect(windowClassOf(const Size(800, 480)), WindowClass.medium);
    });

    test('Smartphones und Tablets in beiden Ausrichtungen', () {
      for (final (size, expected) in <(Size, WindowClass)>[
        (const Size(360, 800), WindowClass.compact),
        (const Size(390, 844), WindowClass.compact),
        (const Size(844, 390), WindowClass.compact),
        (const Size(600, 960), WindowClass.medium),
        (const Size(960, 600), WindowClass.medium),
        (const Size(800, 1280), WindowClass.medium),
        (const Size(1280, 800), WindowClass.expanded),
        (const Size(1024, 1366), WindowClass.expanded),
        (const Size(1366, 1024), WindowClass.expanded),
      ]) {
        expect(windowClassOf(size), expected, reason: '$size');
      }
    });

    test('Die Ausrichtung allein entscheidet nicht: gleiche Fläche, gleiche Klasse', () {
      expect(windowClassOf(const Size(700, 700)), WindowClass.medium);
      expect(windowClassOf(const Size(1000, 1000)), WindowClass.expanded);
    });
  });

  group('paneWidths', () {
    test('Zweispalter ab der Grenze: beide Spalten mindestens 440', () {
      for (final w in <double>[1000, 1024, 1280, 1366, 1600, 2000]) {
        final p = paneWidths(w - kRailWidth);
        expect(p.calendar, greaterThanOrEqualTo(kPaneMinWidth), reason: 'Kalender bei $w');
        expect(p.chat, greaterThanOrEqualTo(kPaneMinWidth), reason: 'Chat bei $w');
        expect(p.calendar + kPaneDivider + p.chat, w - kRailWidth, reason: 'Summe bei $w');
      }
    });

    test('Werte aus E-92: 1000, 1024, 1366', () {
      expect(paneWidths(920).chat, 440);
      expect(paneWidths(920).calendar, 479);
      expect(paneWidths(944).chat, 440);
      expect(paneWidths(944).calendar, 503);
      expect(paneWidths(1286).chat.round(), 514);
      expect(paneWidths(1286).calendar.round(), 771);
    });

    test('Klemme: Chat wächst mit 0,4 bis 560, ab Inhaltsbreite 1400 gedeckelt', () {
      expect(paneWidths(1100).chat, 440, reason: '0,4 · 1100 = 440');
      expect(paneWidths(1200).chat, closeTo(480, 0.001));
      expect(paneWidths(1399).chat, closeTo(559.6, 0.001));
      expect(paneWidths(1400).chat, 560);
      expect(paneWidths(1401).chat, 560);
      expect(paneWidths(2000).chat, 560);
      expect(paneWidths(2000).calendar, 2000 - 560 - kPaneDivider);
    });
  });

  test('bubbleMaxWidth: 82 % der Spalte, höchstens 560', () {
    expect(bubbleMaxWidth(440), closeTo(360.8, 0.001));
    expect(bubbleMaxWidth(360), closeTo(295.2, 0.001));
    expect(bubbleMaxWidth(683), 560);
    expect(bubbleMaxWidth(1200), 560);
  });

  group('usableSize / windowClassIn', () {
    Future<WindowClass> classIn(
      WidgetTester tester, {
      required Size size,
      EdgeInsets viewPadding = EdgeInsets.zero,
      EdgeInsets viewInsets = EdgeInsets.zero,
    }) async {
      late WindowClass result;
      late Size usable;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, viewPadding: viewPadding, viewInsets: viewInsets, padding: viewPadding),
        child: Builder(builder: (context) {
          result = windowClassIn(context);
          usable = usableSize(context);
          return const SizedBox();
        }),
      ));
      expect(usable.width, size.width - viewPadding.horizontal);
      expect(usable.height, size.height - viewPadding.vertical);
      return result;
    }

    testWidgets('sichere Ränder (viewPadding) werden abgezogen', (tester) async {
      expect(await classIn(tester, size: const Size(1000, 900)), WindowClass.expanded);
      expect(await classIn(tester, size: const Size(1000, 900), viewPadding: const EdgeInsets.only(left: 1)), WindowClass.medium);
      expect(await classIn(tester, size: const Size(640, 900), viewPadding: const EdgeInsets.symmetric(horizontal: 21)), WindowClass.compact);
      expect(await classIn(tester, size: const Size(1000, 500), viewPadding: const EdgeInsets.only(top: 20, bottom: 1)), WindowClass.compact);
    });

    testWidgets('die Tastatur (viewInsets) zählt nicht mit', (tester) async {
      expect(await classIn(tester, size: const Size(1024, 768), viewInsets: const EdgeInsets.only(bottom: 350)), WindowClass.expanded);
      expect(await classIn(tester, size: const Size(800, 600), viewInsets: const EdgeInsets.only(bottom: 400)), WindowClass.medium);
    });
  });

  group('ContentWidth', () {
    testWidgets('begrenzt auf 720, zentriert, feste Höhe; 719 und 721', (tester) async {
      for (final (w, expected) in <(double, double)>[(719, 719), (720, 720), (721, 720), (1000, 720)]) {
        tester.view.physicalSize = Size(w, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: ContentWidth(child: SizedBox.expand(key: Key('inhalt'))),
        ));
        final r = tester.getRect(find.byKey(const Key('inhalt')));
        expect(r.width, expected, reason: 'Fenster $w');
        expect(r.height, 600, reason: 'volle Höhe');
        expect(r.center.dx, closeTo(w / 2, 0.001), reason: 'zentriert');
      }
    });

    testWidgets('maxWidth unendlich lässt die volle Breite (compact)', (tester) async {
      tester.view.physicalSize = const Size(900, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr,
        child: ContentWidth(maxWidth: double.infinity, child: SizedBox.expand(key: Key('inhalt'))),
      ));
      expect(tester.getSize(find.byKey(const Key('inhalt'))).width, 900);
    });

    testWidgets('Zustand bleibt, wenn nur maxWidth wechselt', (tester) async {
      Widget build(double max) => Directionality(
            textDirection: TextDirection.ltr,
            child: ContentWidth(maxWidth: max, child: const _Counter()),
          );
      await tester.pumpWidget(build(double.infinity));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      await tester.pumpWidget(build(kContentMaxWidth));
      expect(find.text('1'), findsOneWidget, reason: 'derselbe Elementtyp, kein Neuaufbau');
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: () => setState(() => n++), child: Text('$n', textDirection: TextDirection.ltr));
}
