import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_calc.dart';
import 'package:family_nexus/features/calendar/widgets/anniversary_tile.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

AnniversaryPerson person({AnniversaryDate? birth, AnniversaryDate? death, String name = 'Oma'}) => AnniversaryPerson(
      id: '00000000-0000-4000-8000-000000000001',
      name: name,
      birth: birth,
      death: death,
      by: '@anna:fake.test',
      updatedAt: DateTime.utc(2026, 1, 1),
    );

AnniversaryHit hit(AnniversaryPerson p, AnniversaryKind kind, DateTime today) => AnniversaryCalc.hitsOf(p, today).firstWhere((h) => h.kind == kind);

/// E-104: Text, Symbol und Semantics der Kachel; die Texte bildet die Oberfläche über l10n (de und en).
void main() {
  Future<void> pump(WidgetTester tester, AnniversaryHit h, {String lang = 'de', bool showWhen = false, bool showDate = false}) => tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        home: Scaffold(body: AnniversaryTile(hit: h, showWhen: showWhen, showDate: showDate)),
      ));

  final today = DateTime.utc(2026, 3, 14);
  final alive = person(birth: date(3, 15, 1990));

  testWidgets('de: Geburtstag lebend: wird 36 · aktuell 35 Jahre · morgen, Symbol Kuchen, Semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, hit(alive, AnniversaryKind.birth, today), showWhen: true);
    expect(find.text('Geburtstag von Oma'), findsOneWidget);
    expect(find.text('wird 36 · aktuell 35 Jahre · morgen'), findsOneWidget);
    expect(find.byIcon(Icons.cake), findsOneWidget);
    expect(find.bySemanticsLabel('Geburtstag von Oma, wird 36, aktuell 35 Jahre, morgen'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('de: heute: „36 Jahre · heute“, Datum numerisch mit führender Null', (tester) async {
    await pump(tester, hit(alive, AnniversaryKind.birth, DateTime.utc(2026, 3, 15)), showWhen: true, showDate: true);
    expect(find.text('15.03.1990 · 36 Jahre · heute'), findsOneWidget);
  });

  testWidgets('de: mit Todesdatum: wäre 36; Todestag: 5. Todestag · vor 4 Jahren · in 3 Tagen, Symbol Blume', (tester) async {
    final dead = person(birth: alive.birth, death: date(3, 17, 2021));
    await pump(tester, hit(dead, AnniversaryKind.birth, today), showWhen: true);
    expect(find.text('wäre 36 · morgen'), findsOneWidget);
    await pump(tester, hit(dead, AnniversaryKind.death, today), showWhen: true);
    expect(find.text('Todestag von Oma'), findsOneWidget);
    expect(find.text('5. Todestag · vor 4 Jahren · in 3 Tagen'), findsOneWidget);
    expect(find.byIcon(Icons.local_florist), findsOneWidget);
  });

  testWidgets('en: turns 36, currently 35 years old, tomorrow; would be; death anniversary; date ohne Jahr', (tester) async {
    await pump(tester, hit(alive, AnniversaryKind.birth, today), lang: 'en', showWhen: true);
    expect(find.text('Birthday of Oma'), findsOneWidget);
    expect(find.text('turns 36 · currently 35 years old · tomorrow'), findsOneWidget);
    final dead = person(birth: alive.birth, death: date(3, 17, 2021));
    await pump(tester, hit(dead, AnniversaryKind.birth, today), lang: 'en');
    expect(find.text('would be 36'), findsOneWidget);
    await pump(tester, hit(dead, AnniversaryKind.death, today), lang: 'en', showWhen: true);
    expect(find.text('Anniversary of death of Oma'), findsOneWidget);
    expect(find.text('Death anniversary no. 5 · 4 years ago · in 3 days'), findsOneWidget);
    await pump(tester, hit(person(birth: date(3, 15)), AnniversaryKind.birth, today), lang: 'en', showDate: true);
    expect(find.text('03/15'), findsOneWidget, reason: 'ohne Jahr: nur Tag und Monat, nie ein Alter');
  });

  testWidgets('ohne Jahr nur der Name, keine Alterszeile', (tester) async {
    await pump(tester, hit(person(birth: date(3, 15)), AnniversaryKind.birth, today));
    expect(find.text('Geburtstag von Oma'), findsOneWidget);
    expect(find.textContaining('wird'), findsNothing);
    expect(find.textContaining('aktuell'), findsNothing);
  });
}
