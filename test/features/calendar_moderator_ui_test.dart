import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/calendar_service.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

final DateTime _now = DateTime.utc(2026, 3, 20, 10);

/// #431, E-112: Oberfläche für Moderatoren. Anna ist Familienersteller und damit Moderatorin; Bens geteilter Termin ist
/// fremd. Mit `roleFromFamily: false` (Standard der Test-App) sieht Anna ihn schreibgeschützt (calendar_flow_test).
void main() {
  Future<TestApp> start(WidgetTester tester, {bool moderator = true}) async {
    final app = await buildTestApp(clock: () => _now, roleFromFamily: moderator);
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    await tester.tap(navTab('Kalender'));
    await tester.pumpAndSettle();
    return app;
  }

  CalendarEvent bens({Recurrence recurrence = Recurrence.none, EventVisibility v = EventVisibility.shared}) => CalendarEvent(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ownerId: '@ben:fake.test',
        title: 'Bens Termin',
        start: DateTime.utc(2026, 3, 20, 15),
        end: DateTime.utc(2026, 3, 20, 16),
        timeZone: 'Europe/Berlin',
        updatedAt: DateTime.utc(2026, 3, 1),
        visibility: v,
        recurrence: recurrence,
      );

  Future<void> open(WidgetTester tester, TestApp app, CalendarEvent e) async {
    final cal = app.services.calendar!;
    await cal.service.applyIncoming(e);
    await cal.load();
    await tester.pumpAndSettle();
    await tester.tap(find.text(e.title));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester, TestApp app) async {
    await tester.pumpWidget(const SizedBox());
    app.services.closeCalendar();
  }

  testWidgets('Moderatorin: Bearbeiten ja, Löschen nein bei Einzeltermin, kein „Im Chat teilen“, kein Lesehinweis', (tester) async {
    final app = await start(tester);
    await open(tester, app, bens());
    expect(find.byTooltip('Termin bearbeiten'), findsOneWidget);
    expect(find.byTooltip('Termin löschen'), findsNothing);
    expect(find.text('Im Chat teilen'), findsNothing);
    expect(find.text('Nur der Ersteller und Moderatoren können diesen Termin ändern.'), findsNothing);
    await close(tester, app);
  });

  testWidgets('ohne bekannte Rolle (Standard): schreibgeschützt wie bisher', (tester) async {
    final app = await start(tester, moderator: false);
    await open(tester, app, bens());
    expect(find.byTooltip('Termin bearbeiten'), findsNothing);
    expect(find.text('Nur der Ersteller und Moderatoren können diesen Termin ändern.'), findsOneWidget);
    await close(tester, app);
  });

  testWidgets('Bearbeiten: kein Sichtbarkeitsfeld; Speichern erzeugt eine Moderatorfassung mit Anzeige und Verlauf', (tester) async {
    final app = await start(tester);
    await open(tester, app, bens());
    await tester.tap(find.byTooltip('Termin bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Privat'), findsNothing, reason: 'die Sichtbarkeit bleibt beim Besitzer');
    await tester.enterText(find.byType(TextFormField).first, 'Bens Termin 16 Uhr');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final cal = app.services.calendar!;
    final saved = (await cal.store.get('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'))!;
    expect(saved.title, 'Bens Termin 16 Uhr');
    expect(saved.editorId, app.gateway.userId);
    expect(saved.ownerId, '@ben:fake.test');
    expect(saved.visibility, EventVisibility.shared);
    expect(find.textContaining('Zuletzt geändert von'), findsOneWidget);
    expect(find.textContaining('(laut Absender)'), findsWidgets);
    expect(find.textContaining('Letzte Änderungen auf diesem Gerät'), findsOneWidget);
    await close(tester, app);
  });

  testWidgets('Serie: Moderatorin sieht Löschen, der Dialog bietet nur „Nur dieses“; die Serie bleibt, das Vorkommen fällt aus', (tester) async {
    final app = await start(tester);
    final series = bens(recurrence: const Recurrence(frequency: Frequency.weekly));
    await open(tester, app, series);
    await tester.tap(find.byTooltip('Termin löschen'));
    await tester.pumpAndSettle();
    expect(find.text('Dieses Vorkommen aus der Serie nehmen? Die Serie bleibt bestehen.'), findsOneWidget);
    expect(find.text('Nur dieses'), findsOneWidget);
    expect(find.text('Alle'), findsNothing);
    await tester.tap(find.text('Nur dieses'));
    await tester.pumpAndSettle();
    final got = (await app.services.calendar!.store.get(series.id))!;
    expect(got.deleted, isFalse);
    expect(got.recurrence.exdates, isNotEmpty);
    expect(got.editorId, app.gateway.userId);
    await close(tester, app);
  });

  testWidgets('Controller: Moderatorin kann weder im Chat teilen noch die Sichtbarkeit wechseln noch löschen', (tester) async {
    final app = await start(tester);
    final e = bens();
    await open(tester, app, e);
    final cal = app.services.calendar!;
    await expectLater(cal.shareInChat(e), throwsA(isA<CalendarException>()));
    await expectLater(cal.update(e, visibility: EventVisibility.private), throwsA(isA<CalendarException>()));
    await expectLater(cal.delete(e.id), throwsA(isA<CalendarException>()));
    final got = (await cal.store.get(e.id))!;
    expect(got.visibility, EventVisibility.shared);
    expect(got.deleted, isFalse);
    expect(got.editorId, isNull, reason: 'nichts wurde geändert');
    await close(tester, app);
  });

  testWidgets('Verlauf (aufgeklappt): je Fassung Bearbeiter und Zeitpunkt laut Absender, Moderator vor Besitzer', (tester) async {
    final app = await start(tester);
    await open(tester, app, bens());
    final cal = app.services.calendar!;
    await cal.update(bens().copyWith(title: 'Bens Termin 2'));
    await cal.update(bens().copyWith(title: 'Bens Termin 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Letzte Änderungen auf diesem Gerät'));
    await tester.pumpAndSettle();
    // Fassung 2 stammt von der Moderatorin (Du), Fassung 1 vom Besitzer (nicht mehr in der Familie).
    expect(find.textContaining('Du · '), findsWidgets);
    expect(find.textContaining('Ehemaliges Mitglied · '), findsOneWidget);
    expect(find.textContaining('(laut Absender)'), findsWidgets);
    await close(tester, app);
  });
}
