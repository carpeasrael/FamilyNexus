import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/page_transitions.dart';
import 'package:family_nexus/ui/widgets/glass.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #525: Beim Seitenwechsel (iOS-Wischgeste) schien die Seite darunter durch, weil alle Seiten durchsichtig sind.
/// Jede Seite liegt jetzt auf einem eigenen deckenden Hintergrund; der Übergang selbst bleibt der des Frameworks.
Widget _app({Brightness brightness = Brightness.dark, bool reduce = false}) => MaterialApp(
      theme: buildTheme(brightness, reduceEffects: reduce),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(
            children: <Widget>[
              const Text('UNTEN'),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('OBEN')))),
                child: const Text('push'),
              ),
            ],
          ),
        ),
      ),
    );

Finder get _obenBackground => find.ancestor(of: find.text('OBEN'), matching: find.byType(AuroraBackground));

void main() {
  test('Theme: jede Plattform nutzt den Standard-Übergang des Frameworks, mit deckendem Hintergrund', () {
    final defaults = const PageTransitionsTheme().builders;
    final themed = buildTheme(Brightness.dark).pageTransitionsTheme;
    for (final p in TargetPlatform.values) {
      final b = themed.builders[p];
      expect(b, isA<OpaquePageTransitionsBuilder>(), reason: '$p');
      final inner = (b! as OpaquePageTransitionsBuilder).inner;
      expect(inner.runtimeType, (defaults[p] ?? const ZoomPageTransitionsBuilder()).runtimeType, reason: 'Standard-Übergang bleibt: $p');
      expect(b.delegatedTransition == null, inner.delegatedTransition == null, reason: 'Versatz der Seite darunter bleibt: $p');
      expect(b.transitionDuration, inner.transitionDuration, reason: '$p');
    }
    expect((themed.builders[TargetPlatform.iOS]! as OpaquePageTransitionsBuilder).inner, isA<CupertinoPageTransitionsBuilder>());
    expect((themed.builders[TargetPlatform.android]! as OpaquePageTransitionsBuilder).inner, isA<PredictiveBackPageTransitionsBuilder>());
  });

  testWidgets('gepushte Seite hat einen eigenen deckenden Hintergrund, auch mitten im Übergang', (tester) async {
    await tester.pumpWidget(_app());
    expect(_obenBackground, findsNothing);
    await tester.tap(find.text('push'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_obenBackground, findsOneWidget, reason: 'mitten im Übergang');
    await tester.pumpAndSettle();
    expect(_obenBackground, findsOneWidget);
    expect(find.text('UNTEN', skipOffstage: false), findsOneWidget, reason: 'die Seite darunter bleibt im Baum');
  }, variant: const TargetPlatformVariant(<TargetPlatform>{TargetPlatform.iOS, TargetPlatform.android, TargetPlatform.macOS, TargetPlatform.windows, TargetPlatform.linux}));

  testWidgets('iOS: Rückwisch mitten in der Geste, die oberste Seite ist deckend', (tester) async {
    await tester.pumpWidget(_app());
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    final g = await tester.startGesture(const Offset(2, 300));
    await g.moveBy(const Offset(200, 0));
    await tester.pump();
    expect(_obenBackground, findsOneWidget, reason: 'während der Wischgeste');
    await g.up();
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final brightness in Brightness.values) {
    for (final reduce in <bool>[false, true]) {
      testWidgets('Hintergrund ist deckend: $brightness, reduzierte Effekte $reduce', (tester) async {
        await tester.pumpWidget(_app(brightness: brightness, reduce: reduce));
        await tester.tap(find.text('push'));
        await tester.pumpAndSettle();
        final box = tester.widget<DecoratedBox>(find.descendant(of: _obenBackground, matching: find.byType(DecoratedBox)).first);
        final d = box.decoration as BoxDecoration;
        expect(d.color!.a, 1.0);
        final g = d.gradient;
        if (g != null) {
          for (final c in g.colors) {
            expect(c.a, 1.0, reason: 'jede Verlaufsfarbe deckend');
          }
        }
      });
    }
  }
}
