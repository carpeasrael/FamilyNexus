import 'package:family_nexus/domain/anniversary_calc.dart';
import 'package:family_nexus/features/calendar/widgets/anniversary_day_marker.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #579 (E-104): Der Marker zeichnet je Art ein Symbol, in fester Reihenfolge Torte, dann Blume.
void main() {
  Future<void> pump(WidgetTester tester, Set<AnniversaryKind> kinds) =>
      tester.pumpWidget(MaterialApp(theme: buildTheme(Brightness.light), home: Center(child: AnniversaryDayMarker(kinds: kinds))));

  testWidgets('nur Geburt: Torte, keine Blume', (tester) async {
    await pump(tester, {AnniversaryKind.birth});
    expect(find.byIcon(Icons.cake), findsOneWidget);
    expect(find.byIcon(Icons.local_florist), findsNothing);
  });

  testWidgets('nur Tod: Blume, keine Torte', (tester) async {
    await pump(tester, {AnniversaryKind.death});
    expect(find.byIcon(Icons.local_florist), findsOneWidget);
    expect(find.byIcon(Icons.cake), findsNothing);
  });

  testWidgets('beide Arten: beide Symbole, Torte links der Blume, unabhängig von der Mengenreihenfolge', (tester) async {
    await pump(tester, {AnniversaryKind.death, AnniversaryKind.birth});
    expect(find.byIcon(Icons.cake), findsOneWidget);
    expect(find.byIcon(Icons.local_florist), findsOneWidget);
    expect(tester.getCenter(find.byIcon(Icons.cake)).dx, lessThan(tester.getCenter(find.byIcon(Icons.local_florist)).dx));
  });

  testWidgets('leere Menge: nichts', (tester) async {
    await pump(tester, <AnniversaryKind>{});
    expect(find.byType(Icon), findsNothing);
  });
}
