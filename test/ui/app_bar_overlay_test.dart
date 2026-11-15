import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// #501: Die AppBar überstimmte die Statusleiste der App; auf hellem Design waren die Symbole weiß.
void main() {
  Future<SystemUiOverlayStyle> overlayOf(WidgetTester tester, Brightness b) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(b), home: Scaffold(appBar: AppBar(title: const Text('x')))));
    final region = find.descendant(of: find.byType(AppBar), matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>));
    return tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(region.first).value;
  }

  testWidgets('helles Design: dunkle Symbole (Android und iOS), Leisten durchsichtig', (tester) async {
    final s = await overlayOf(tester, Brightness.light);
    expect(s.statusBarIconBrightness, Brightness.dark);
    expect(s.statusBarBrightness, Brightness.light, reason: 'iOS: Brightness der Leiste = Hintergrund, Symbole dunkel');
    expect(s.statusBarColor, Colors.transparent);
    expect(s.systemNavigationBarColor, Colors.transparent);
  });

  testWidgets('dunkles Design: helle Symbole', (tester) async {
    final s = await overlayOf(tester, Brightness.dark);
    expect(s.statusBarIconBrightness, Brightness.light);
    expect(s.statusBarBrightness, Brightness.dark);
    expect(s.statusBarColor, Colors.transparent);
  });

  test('overlayStyleFor gibt für beide Helligkeiten den gleichen Stil wie die AppBar des Themes', () {
    for (final b in Brightness.values) {
      expect(buildTheme(b).appBarTheme.systemOverlayStyle, overlayStyleFor(b));
    }
  });
}
