import 'package:family_nexus/features/onboarding/embedded_browser_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final redirect = Uri.parse('io.github.carpeasrael.familynexus:/oauth');
  NavDecision d(String u, {bool main = true}) => decideNavigation(u, isMainFrame: main, redirectUri: redirect);

  test('decideNavigation: Hauptframe', () {
    expect(d('https://a.test/x'), NavDecision.allow);
    expect(d('http://a.test/x'), NavDecision.block);
    expect(d('file:///etc/passwd'), NavDecision.block);
    expect(d('intent://x#Intent;end'), NavDecision.block);
    expect(d('https://u:p@a.test/x'), NavDecision.block);
    expect(d('io.github.carpeasrael.familynexus:/oauth?code=1&state=s'), NavDecision.redirect);
    expect(d('io.github.carpeasrael.familynexus:/evil'), NavDecision.block);
    expect(d('io.github.carpeasrael.familynexus://host/oauth'), NavDecision.block);
    expect(d('io.github.carpeasrael.familynexus:/oauth?x=${'a' * 2100}'), NavDecision.block);
  });

  test('decideNavigation: Unterframes', () {
    expect(d('https://a.test/x', main: false), NavDecision.allow);
    expect(d('about:blank', main: false), NavDecision.allow);
    expect(d('about:srcdoc', main: false), NavDecision.allow);
    expect(d('about:other', main: false), NavDecision.block);
    expect(d('http://a.test/', main: false), NavDecision.block);
    expect(d('io.github.carpeasrael.familynexus:/oauth', main: false), NavDecision.block);
  });

  group('NavigationLoopGuard', () {
    final t0 = DateTime(2026, 11, 15, 12);
    test('3 erlaubt, 4. im Fenster blockiert, blockierte zählen nicht', () {
      var now = t0;
      final g = NavigationLoopGuard(clock: () => now);
      expect([for (var i = 0; i < 4; i++) g.check('https://a.test/x')], <bool>[true, true, true, false]);
      expect(g.check('https://a.test/x'), isFalse);
      // Nach Ablauf des ersten Eintrags (5 s) darf wieder eine durch.
      now = t0.add(const Duration(seconds: 6));
      expect(g.check('https://a.test/x'), isTrue);
    });
    test('Fenster läuft ab', () {
      var now = t0;
      final g = NavigationLoopGuard(clock: () => now);
      for (var i = 0; i < 3; i++) {
        expect(g.check('https://a.test/x'), isTrue);
        now = now.add(const Duration(seconds: 2));
      }
      expect(g.check('https://a.test/x'), isTrue, reason: 'nur die letzten beiden liegen im 5-s-Fenster');
    });
    test('andere URL zählt getrennt, Fragment zählt nicht als andere URL', () {
      final g = NavigationLoopGuard(clock: () => t0);
      expect([for (var i = 0; i < 3; i++) g.check('https://a.test/x#$i')], <bool>[true, true, true]);
      expect(g.check('https://a.test/x#9'), isFalse);
      expect(g.check('https://a.test/y'), isTrue);
    });
    test('reset setzt den Zähler zurück', () {
      final g = NavigationLoopGuard(clock: () => t0);
      for (var i = 0; i < 3; i++) {
        g.check('https://a.test/x');
      }
      expect(g.check('https://a.test/x'), isFalse);
      g.reset();
      expect(g.check('https://a.test/x'), isTrue);
    });
  });
}
