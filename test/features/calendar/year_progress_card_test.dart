import 'package:family_nexus/features/calendar/year_progress_card.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #337: Die Karte nennt Tag, verbleibende Tage und Prozent (de und en) und hat einen grafischen Balken.
Widget _app(Locale locale) => MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: YearProgressCard(today: DateTime.utc(2026, 7, 2))),
    );

void main() {
  testWidgets('deutsch: Text, Balken, Semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const Locale('de')));
    expect(find.text('Tag 183 von 365 · noch 182 Tage · 50 % des Jahres verstrichen'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(find.byKey(const Key('yearProgressBar')));
    expect(bar.value, closeTo(183 / 365, 1e-9));
    expect(find.bySemanticsLabel('Jahresfortschritt: 50 Prozent verstrichen'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('englisch: Text und Semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const Locale('en')));
    expect(find.text('Day 183 of 365 · 182 days left · 50% of the year elapsed'), findsOneWidget);
    expect(find.bySemanticsLabel('Year progress: 50 percent elapsed'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('große Schrift (200 %) und schmale Breite: kein Überlauf', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: _app(const Locale('de')),
    ));
    expect(tester.takeException(), isNull);
  });
}
