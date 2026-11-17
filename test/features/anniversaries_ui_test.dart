import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/anniversaries_screen.dart';
import 'package:family_nexus/features/calendar/anniversary_dialog.dart';
import 'package:family_nexus/features/calendar/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';

AnniversaryDate date(int m, int day, [int? y]) => AnniversaryDate(month: m, day: day, year: y);

AnniversaryPerson person(String n, String name, {AnniversaryDate? birth, AnniversaryDate? death, String by = _ben}) => AnniversaryPerson(
      id: '00000000-0000-4000-8000-00000000000$n',
      name: name,
      birth: birth,
      death: death,
      by: by,
      updatedAt: DateTime.utc(2026, 3, 1),
    );

/// E-104: Oberfläche der Geburts- und Gedenktage: „Heute“-Karte, Kalender, Liste, Dialog. Feste Uhr (Berlin).
void main() {
  setUpAll(TimeZones.ensureInitialized);

  // 2026-03-20 10:00 UTC = 11:00 in Berlin.
  var now = DateTime.utc(2026, 3, 20, 10);
  TestApp? current;

  setUp(() => now = DateTime.utc(2026, 3, 20, 10));

  Future<TestApp> open(WidgetTester tester, {List<AnniversaryPerson> people = const <AnniversaryPerson>[], String lang = 'de', int? lead}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(clock: () => now, lang: lang);
    current = app;
    for (final p in people) {
      await app.anniversaryStore.put(p, publishedVersion: p.version);
    }
    if (lead != null) await app.services.settings.setAnniversaryLeadDays(lead);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await app.services.calendar!.load();
    await tester.pumpAndSettle();
    return app;
  }

  void ui(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
        try {
          await body(tester);
        } finally {
          await tester.pumpWidget(const SizedBox());
          current?.services.closeCalendar();
          current = null;
        }
      });

  final oma = person('1', 'Oma', birth: date(3, 23, 1936));

  group('Karte auf „Heute“', () {
    ui('zeigt Name, Alter und Tage bei Vorlauf 7 und entfällt bei Vorlauf 2; Einstellung baut die Karte neu', (tester) async {
      final app = await open(tester, people: [oma]);
      expect(find.text('Geburtstage und Gedenktage'), findsOneWidget);
      expect(find.text('Geburtstag von Oma'), findsOneWidget);
      expect(find.text('wird 90 · aktuell 89 Jahre · in 3 Tagen'), findsOneWidget);
      expect(find.byIcon(Icons.cake), findsWidgets, reason: 'Symbol und Text');
      await app.services.settings.setAnniversaryLeadDays(2);
      await tester.pumpAndSettle();
      expect(find.text('Geburtstage und Gedenktage'), findsNothing);
      expect(find.text('Geburtstag von Oma'), findsNothing);
    });

    ui('Vorlauf 0 zeigt nur den Tag selbst', (tester) async {
      final todayPerson = person('2', 'Opa', birth: date(3, 20, 1930));
      await open(tester, people: [oma, todayPerson], lead: 0);
      expect(find.text('Geburtstag von Opa'), findsOneWidget);
      expect(find.text('96 Jahre · heute'), findsOneWidget);
      expect(find.text('Geburtstag von Oma'), findsNothing);
    });

    ui('Tageswechsel ohne Datenänderung: Karte erscheint um Mitternacht', (tester) async {
      now = DateTime.utc(2026, 3, 19, 22, 59); // 23:59 in Berlin
      await open(tester, people: [person('2', 'Opa', birth: date(3, 20, 1930))], lead: 0);
      expect(find.text('Geburtstag von Opa'), findsNothing);
      now = DateTime.utc(2026, 3, 19, 23, 1); // 00:01 am 20.03.
      await tester.pump(const Duration(seconds: 31));
      await tester.pump();
      expect(find.text('Geburtstag von Opa'), findsOneWidget);
    });

    ui('ohne Einträge keine Karte; Link „Geburtstage“ öffnet die Liste', (tester) async {
      await open(tester);
      expect(find.text('Geburtstage und Gedenktage'), findsNothing);
    });

    ui('Link in der Karte öffnet die Liste', (tester) async {
      await open(tester, people: [oma]);
      await tester.tap(find.widgetWithText(TextButton, 'Geburtstage'));
      await tester.pumpAndSettle();
      expect(find.byType(AnniversariesScreen), findsOneWidget);
    });

    ui('en: Texte und Semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, people: [oma], lang: 'en');
      expect(find.text('Birthdays and memorial days'), findsOneWidget);
      expect(find.text('Birthday of Oma'), findsOneWidget);
      expect(find.text('turns 90 · currently 89 years old · in 3 days'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Birthday of Oma, turns 90, currently 89 years old, in 3 days')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Kalender', () {
    final hit = person('3', 'Tante', birth: date(3, 20, 1970));

    Future<void> calendarTab(WidgetTester tester) async {
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
    }

    ui('Monat: Marker, Semantics mit Anzahl und Treffer des gewählten Tages', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, people: [hit]);
      await calendarTab(tester);
      expect(find.byIcon(Icons.cake), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Freitag, 20\\. März 2026, Keine Termine, 1 Geburts- oder Gedenktag, Heute')), findsOneWidget);
      expect(find.text('Geburtstag von Tante'), findsOneWidget);
      expect(find.text('56 Jahre'), findsOneWidget);
      handle.dispose();
    });

    ui('Tag und Woche: Treffer vor den Terminen, „keine Termine“ erst ohne Treffer', (tester) async {
      await open(tester, people: [hit]);
      await calendarTab(tester);
      await tester.tap(find.text('Tag'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtstag von Tante'), findsOneWidget);
      expect(find.text('Keine Termine'), findsNothing);
      await tester.tap(find.text('Woche'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtstag von Tante'), findsOneWidget);
    });

    ui('Agenda ohne Termine, aber mit Treffer: zeigt die Treffer statt „keine Termine“', (tester) async {
      await open(tester, people: [hit]);
      await calendarTab(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtstag von Tante'), findsOneWidget);
      expect(find.text('Keine Termine'), findsNothing);
    });

    ui('Agenda ohne Termine und ohne Treffer: „keine Termine“ bleibt', (tester) async {
      await open(tester);
      await calendarTab(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Keine Termine'), findsOneWidget);
    });

    ui('29.2. im Nichtschaltjahr erscheint am 28.2.', (tester) async {
      now = DateTime.utc(2026, 2, 27, 10);
      await open(tester, people: [person('4', 'Schaltkind', birth: date(2, 29, 2000))]);
      await calendarTab(tester);
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('Geburtstag von Schaltkind'), findsOneWidget);
      expect(find.textContaining('28'), findsWidgets);
      expect(find.text('wird 26 · aktuell 25 Jahre'), findsOneWidget, reason: '29.2.2000 gilt 2026 am 28.2.: wird 26');
    });

    ui('Kopfzeile: Aktion „Geburtstage“ öffnet die Liste', (tester) async {
      await open(tester, people: [hit]);
      await calendarTab(tester);
      await tester.tap(find.byTooltip('Geburtstage'));
      await tester.pumpAndSettle();
      expect(find.byType(AnniversariesScreen), findsOneWidget);
      expect(find.byType(CalendarScreen), findsNothing);
    });

    ui('en: Semantics der Zelle', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, people: [hit], lang: 'en');
      await tester.tap(navTab('Calendar'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('1 birthday or memorial day')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Liste und Dialog', () {
    Future<void> openList(WidgetTester tester) async {
      await tester.tap(navTab('Kalender'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Geburtstage'));
      await tester.pumpAndSettle();
    }

    ui('Anlegen mit Geburts- und Todesdatum an einer Person', (tester) async {
      final app = await open(tester);
      await openList(tester);
      expect(find.text('Noch keine Einträge. Lege den ersten an.'), findsOneWidget);
      await tester.tap(find.text('Person anlegen'));
      await tester.pumpAndSettle();
      final days = find.widgetWithText(TextField, 'Tag');
      final months = find.widgetWithText(TextField, 'Monat');
      final years = find.widgetWithText(TextField, 'Jahr (optional)');
      await tester.enterText(find.widgetWithText(TextField, 'Name der Person'), 'Oma Erna');
      await tester.enterText(days.at(0), '15');
      await tester.enterText(months.at(0), '3');
      await tester.enterText(years.at(0), '1940');
      await tester.enterText(days.at(1), '5');
      await tester.enterText(months.at(1), '1');
      await tester.enterText(years.at(1), '2020');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final all = await app.anniversaryStore.all();
      expect(all, hasLength(1));
      expect((all.single.name, all.single.birth, all.single.death), ('Oma Erna', date(3, 15, 1940), date(1, 5, 2020)));
      expect(find.text('15.03.1940 · wäre 87 · in 360 Tagen'), findsOneWidget, reason: 'Geburtstag mit Todesdatum: wäre n');
      expect(find.textContaining('Todestag von Oma Erna'), findsOneWidget);
    });

    ui('Dialog zeigt Eingabefehler: leerer Name, kein Datum, 31.02., Zukunft, Todesdatum vor Geburtsdatum', (tester) async {
      final app = await open(tester);
      await openList(tester);
      await tester.tap(find.text('Person anlegen'));
      await tester.pumpAndSettle();
      Future<void> save(String expected) async {
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(await app.anniversaryStore.all(), isEmpty);
      }

      final days = find.widgetWithText(TextField, 'Tag');
      final months = find.widgetWithText(TextField, 'Monat');
      final years = find.widgetWithText(TextField, 'Jahr (optional)');
      await save('Bitte einen Namen eingeben.');
      await tester.enterText(find.widgetWithText(TextField, 'Name der Person'), 'X');
      await save('Bitte mindestens ein Datum angeben.');
      await tester.enterText(days.at(0), '31');
      await tester.enterText(months.at(0), '2');
      await save('Bitte ein gültiges Datum angeben (Tag, Monat, optional Jahr).');
      await tester.enterText(days.at(0), '1');
      await tester.enterText(months.at(0), '1');
      await tester.enterText(years.at(0), '2027');
      await save('Das Datum darf nicht in der Zukunft liegen.');
      await tester.enterText(years.at(0), '1990');
      await tester.enterText(days.at(1), '1');
      await tester.enterText(months.at(1), '1');
      await tester.enterText(years.at(1), '1989');
      await save('Das Todesdatum darf nicht vor dem Geburtsdatum liegen.');
    });

    ui('Bearbeiten eines Eintrags eines anderen Mitglieds und Löschen', (tester) async {
      final app = await open(tester, people: [oma]);
      await openList(tester);
      await tester.tap(find.text('Geburtstag von Oma'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name der Person'), 'Oma Erna');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final changed = (await app.anniversaryStore.get(oma.id))!;
      expect((changed.name, changed.by, changed.version), ('Oma Erna', _anna, 2));
      await tester.tap(find.text('Geburtstag von Oma Erna'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect((await app.anniversaryStore.get(oma.id))!.deleted, isTrue);
      expect(find.text('Geburtstag von Oma Erna'), findsNothing);
    });
  });

  group('Eingabeprüfung (reine Funktion) wie im Dienst', () {
    final today = DateTime.utc(2026, 3, 20);
    ({AnniversaryDate? date, bool invalid}) p(String d, String m, String y) => AnniversaryForm.parseDate(d, m, y);
    AnniversaryFormError? check({String name = 'X', String? b, String? d, AnniversaryPerson? existing}) {
      ({AnniversaryDate? date, bool invalid}) parse(String? s) {
        if (s == null) return p('', '', '');
        final parts = s.split('.');
        return p(parts[0], parts[1], parts.length > 2 ? parts[2] : '');
      }

      return AnniversaryForm.check(name: name, birth: parse(b), death: parse(d), today: today, existing: existing);
    }

    test('Fälle', () {
      expect(check(name: ' ', b: '1.1.1990'), AnniversaryFormError.nameEmpty);
      expect(check(), AnniversaryFormError.needDate);
      expect(check(b: '31.2'), AnniversaryFormError.dateInvalid);
      expect(check(b: '29.2.1900'), AnniversaryFormError.dateInvalid);
      expect(check(b: '29.2.2000'), isNull);
      expect(check(b: '29.2'), isNull);
      expect(check(b: '21.3.2026'), AnniversaryFormError.dateFuture);
      expect(check(b: '20.3.2026'), isNull);
      expect(check(b: '1.1.1990', d: '1.1.1989'), AnniversaryFormError.deathBeforeBirth);
      expect(check(b: '1.1.1990', d: '1.1.1990'), isNull);
      expect(check(d: '1.1.2000'), isNull, reason: 'nur ein Datum ist erlaubt');
      expect(p('1', '', ''), (date: null, invalid: true));
    });

    test('empfangener Eintrag mit Zukunftsjahr (bis 2100) lässt sich umbenennen; geändertes Zukunftsjahr nicht', () {
      final received = AnniversaryPerson(id: '00000000-0000-4000-8000-0000000000f1', name: 'Alt', birth: date(3, 15, 2090), by: _ben, updatedAt: DateTime.utc(2026, 3, 1));
      expect(check(b: '15.3.2090', existing: received), isNull);
      expect(check(b: '16.3.2090', existing: received), AnniversaryFormError.dateFuture);
      expect(check(b: '15.3.2090'), AnniversaryFormError.dateFuture, reason: 'neuer Eintrag: Zukunft abgelehnt');
    });
  });

  test('Ereignistyp-Konstanten: Kalender kennt CalendarEvent.maxDate als obere Jahresgrenze', () {
    expect(AnniversaryDate.maxYear, CalendarEvent.maxDate.year);
    expect(AnniversaryDate.minYear, 1000);
  });
}
