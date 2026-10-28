import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

final DateTime _now = DateTime.utc(2026, 3, 20, 10); // 11:00 in Berlin

Future<TestApp> _app() => buildTestApp(clock: () => _now);

Future<void> _start(WidgetTester tester, TestApp app, {String? tab}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
    await tester.pumpAndSettle();
  }
}

Future<FakeMatrixGateway> _joinBen(TestApp app) async {
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  app.server.addMember(room, '@ben:fake.test');
  ben.attachFamilyRoom(room.id);
  return ben;
}

void main() {
  testWidgets('Schließen der Oberfläche entfernt geplante Erinnerungen NICHT (nur Abmeldung)', (tester) async {
    final app = await _app();
    await _start(tester, app);
    await app.services.calendar!.create(
      title: 'Bleibt',
      start: DateTime.utc(2026, 3, 22, 9),
      end: DateTime.utc(2026, 3, 22, 10),
      visibility: EventVisibility.private,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(app.scheduler.cancelled, 0);
    expect(app.scheduler.last, isNotEmpty);
  });

  group('Termin anlegen über das Formular', () {
    testWidgets('geteilter Termin erscheint im Kalender und wird in den Familienraum gesendet', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      expect(find.text('Neuer Termin'), findsWidgets);
      await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Elternabend');
      // Standard ist privat; Teilen ist eine bewusste Entscheidung.
      expect(find.text('Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.'), findsOneWidget);
      await tester.tap(find.text('Geteilt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Elternabend'), findsOneWidget);
      expect(find.text('Geteilt'), findsWidgets, reason: 'Sichtbarkeit als Text, nicht nur Farbe');
      final stored = (await app.events.all()).single;
      expect(stored.title, 'Elternabend');
      expect(stored.isShared, isTrue);
      expect(stored.start, DateTime.utc(2026, 3, 20, 11)); // 12:00 Berlin = 11:00Z
      await tester.pump(const Duration(seconds: 1));
      await app.services.calendar!.sync.publishPending();
      expect(app.server.log.where((e) => e.type == 'de.inneso.familynexus.event'), hasLength(1));
    });

    testWidgets('privater Termin wird nur in den privaten Raum gesendet', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Arzt');
      expect(find.text('Nur auf deinen eigenen Geräten. Wird nie an die Familie gesendet.'), findsOneWidget);
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await app.services.calendar!.sync.publishPending();
      expect(app.server.log.where((e) => e.type == 'de.inneso.familynexus.event'), isEmpty);
      expect(app.server.log.where((e) => e.type == 'de.inneso.familynexus.private_event'), hasLength(1));
      expect(find.text('Privat'), findsWidgets);
    });

    testWidgets('leerer Titel und Ende vor Beginn werden abgelehnt', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte einen Titel eingeben.'), findsOneWidget);
      expect(await app.events.all(), isEmpty);
    });

    group('#34: Ende wandert mit dem Beginn; Fehler am Zeitfeld', () {
      /// Uhrzeit über die Tastatureingabe des Zeitwählers setzen.
      Future<void> pickTime(WidgetTester tester, String current, int hour, int minute) async {
        await tester.tap(find.widgetWithText(OutlinedButton, current));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        await tester.enterText(fields.at(0), hour.toString().padLeft(2, '0'));
        await tester.enterText(fields.at(1), minute.toString().padLeft(2, '0'));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
      }

      /// 24-Stunden-Anzeige wie auf deutsch eingestellten Geräten (sonst arbeitet der Zeitwähler mit AM/PM).
      void use24h(WidgetTester tester) {
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = true;
        addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
      }

      testWidgets('Beginn verschoben: Dauer bleibt, auch über Mitternacht hinweg', (tester) async {
        use24h(tester);
        final app = await _app();
        await _start(tester, app, tab: 'Kalender');
        await tester.tap(find.byTooltip('Neuer Termin'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Spieleabend');
        // Vorschlag 12:00–13:00 (jetzt 11:00 Berlin).
        await pickTime(tester, '12:00', 23, 0);
        expect(find.widgetWithText(OutlinedButton, '00:00'), findsOneWidget, reason: 'Ende 00:00 am Folgetag');
        await pickTime(tester, '23:00', 21, 0);
        expect(find.widgetWithText(OutlinedButton, '22:00'), findsOneWidget);
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        final e = (await app.events.all()).single;
        expect((e.start, e.end), (DateTime.utc(2026, 3, 20, 20), DateTime.utc(2026, 3, 20, 21)), reason: '21–22 Uhr, nicht bis Mitternacht');
      });

      testWidgets('#64: 12-Stunden-Gerät, App deutsch: Texteingabe nimmt 21 an', (tester) async {
        tester.platformDispatcher.alwaysUse24HourFormatTestValue = false;
        addTearDown(tester.platformDispatcher.clearAlwaysUse24HourTestValue);
        final app = await _app();
        await _start(tester, app, tab: 'Kalender');
        await tester.tap(find.byTooltip('Neuer Termin'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Abends');
        await pickTime(tester, '12:00', 21, 0);
        expect(find.text('Geben Sie eine gültige Uhrzeit ein'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, '21:00'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, '22:00'), findsOneWidget);
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        final e = (await app.events.all()).single;
        expect(e.start, DateTime.utc(2026, 3, 20, 20), reason: '21:00 Berlin');
      });

      testWidgets('#56: Ende = Beginn wird nicht gespeichert; danach wandert das Ende mit einer Stunde', (tester) async {
        use24h(tester);
        final app = await _app();
        await _start(tester, app, tab: 'Kalender');
        await tester.tap(find.byTooltip('Neuer Termin'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Ohne Dauer');
        await pickTime(tester, '13:00', 12, 0); // Ende = Beginn 12:00
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text('Das Ende muss nach dem Beginn liegen.'), findsOneWidget);
        expect(await app.events.all(), isEmpty);
        // Beginn und Ende zeigen jetzt beide 12:00; das erste Feld ist der Beginn.
        await tester.tap(find.widgetWithText(OutlinedButton, '12:00').first);
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();
        final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
        await tester.enterText(fields.at(0), '15');
        await tester.enterText(fields.at(1), '00');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(OutlinedButton, '16:00'), findsOneWidget, reason: 'Ende wandert mit, eine Stunde');
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        final e = (await app.events.all()).single;
        expect(e.end.difference(e.start), const Duration(hours: 1));
      });

      testWidgets('#63: Detailseite zeigt nach dem Bearbeiten die neue Uhrzeit', (tester) async {
        use24h(tester);
        final app = await _app();
        await _start(tester, app, tab: 'Kalender');
        await app.services.calendar!.create(
          title: 'Sport',
          start: DateTime.utc(2026, 3, 20, 17), // 18:00 Berlin
          end: DateTime.utc(2026, 3, 20, 18),
          visibility: EventVisibility.private,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sport'));
        await tester.pumpAndSettle();
        expect(find.text('18:00 – 19:00'), findsOneWidget);
        await tester.tap(find.byTooltip('Termin bearbeiten'));
        await tester.pumpAndSettle();
        await pickTime(tester, '18:00', 20, 0);
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text('20:00 – 21:00'), findsOneWidget);
        expect(find.text('18:00 – 19:00'), findsNothing);
        // Ganztägig: Detail zeigt „Ganztägig“ statt der Uhrzeit.
        await tester.tap(find.byTooltip('Termin bearbeiten'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ganztägig'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        expect(find.text('20:00 – 21:00'), findsNothing);
        expect(find.text('Ganztägig'), findsWidgets);
      });

      testWidgets('Ende vor Beginn: Meldung direkt bei den Zeitfeldern', (tester) async {
        use24h(tester);
        final app = await _app();
        await _start(tester, app, tab: 'Kalender');
        await tester.tap(find.byTooltip('Neuer Termin'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Falsch herum');
        await pickTime(tester, '13:00', 10, 0);
        await tester.tap(find.text('Speichern'));
        await tester.pumpAndSettle();
        final msg = find.text('Das Ende muss nach dem Beginn liegen.');
        expect(msg, findsOneWidget);
        expect(await app.events.all(), isEmpty);
        expect(tester.getTopLeft(msg).dy, lessThan(tester.getTopLeft(find.text('Sichtbarkeit')).dy),
            reason: 'nicht erst am Formularende');
      });
    });

    testWidgets('Wiederholung: wöchentlich mit Anzahl', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      await tester.tap(find.byTooltip('Neuer Termin'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Titel'), 'Turnen');
      await tester.ensureVisible(find.text('Wöchentlich'));
      await tester.tap(find.text('Wöchentlich'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nach Anzahl'));
      await tester.tap(find.text('Nach Anzahl'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'Anzahl'), '3');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      final e = (await app.events.all()).single;
      expect(e.recurrence.frequency, Frequency.weekly);
      expect(e.recurrence.count, 3);
    });
  });

  group('Ansichten', () {
    Future<CalendarEvent> seed(TestApp app) => app.services.calendarBuilder!('@anna:fake.test').then((c) async {
          final e = await c.service.create(
            title: 'Zahnarzt',
            start: DateTime.utc(2026, 3, 20, 13),
            end: DateTime.utc(2026, 3, 20, 14),
            timeZone: 'Europe/Berlin',
            visibility: EventVisibility.shared,
          );
          c.dispose();
          return e;
        });

    for (final view in <String>['Tag', 'Woche', 'Monat', 'Agenda']) {
      testWidgets('Ansicht „$view“ zeigt den Termin von heute', (tester) async {
        final app = await _app();
        await seed(app);
        await _start(tester, app, tab: 'Kalender');
        await tester.tap(find.widgetWithText(ButtonSegment<Object?>, view).evaluate().isEmpty ? find.text(view).first : find.text(view).first);
        await tester.pumpAndSettle();
        expect(find.text('Zahnarzt'), findsOneWidget, reason: view);
        expect(find.textContaining('14:00 – 15:00'), findsOneWidget);
      });
    }

    testWidgets('Personenfilter blendet Termine anderer aus', (tester) async {
      final app = await _app();
      final ben = await _joinBen(app);
      await seed(app);
      final room = app.gateway.familyRoom!;
      expect(room.membership['@ben:fake.test'], MemberStatus.joined);
      // Bens Termin per Signal-Pfad einspielen
      final c = await app.services.calendarBuilder!('@anna:fake.test');
      c.dispose();
      await _start(tester, app, tab: 'Kalender');
      final cal = app.services.calendar!;
      await cal.service.applyIncoming(CalendarEvent(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ownerId: '@ben:fake.test',
        title: 'Fußball',
        start: DateTime.utc(2026, 3, 20, 15),
        end: DateTime.utc(2026, 3, 20, 16),
        timeZone: 'Europe/Berlin',
        updatedAt: DateTime.utc(2026, 3, 1),
        visibility: EventVisibility.shared,
      ));
      await cal.load();
      await tester.pumpAndSettle();
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(find.text('Fußball'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Zahnarzt'), findsNothing);
      expect(find.text('Fußball'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Alle'));
      await tester.pumpAndSettle();
      expect(find.text('Zahnarzt'), findsOneWidget);
      expect(ben.userId, '@ben:fake.test');
    });
  });

  group('Detail, Zusage, Löschen', () {
    testWidgets('Zusage wird lokal gespeichert und an die Familie gesendet', (tester) async {
      final app = await _app();
      await _joinBen(app);
      await _start(tester, app, tab: 'Kalender');
      final cal = app.services.calendar!;
      final e = await cal.create(
        title: 'Grillen',
        start: DateTime.utc(2026, 3, 20, 16),
        end: DateTime.utc(2026, 3, 20, 18),
        visibility: EventVisibility.shared,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grillen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zusagen'));
      await tester.pumpAndSettle();
      expect(cal.myRsvp(e.id), RsvpStatus.accepted);
      await cal.sync.publishPending();
      expect(app.server.log.where((x) => x.type == 'de.inneso.familynexus.rsvp'), hasLength(1));
      await tester.tap(find.text('Vielleicht'));
      await tester.pumpAndSettle();
      expect(cal.myRsvp(e.id), RsvpStatus.maybe);
    });

    testWidgets('Fremde Termine sind schreibgeschützt', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      final cal = app.services.calendar!;
      await cal.service.applyIncoming(CalendarEvent(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        ownerId: '@ben:fake.test',
        title: 'Bens Termin',
        start: DateTime.utc(2026, 3, 20, 15),
        end: DateTime.utc(2026, 3, 20, 16),
        timeZone: 'Europe/Berlin',
        updatedAt: DateTime.utc(2026, 3, 1),
        visibility: EventVisibility.shared,
      ));
      await cal.load();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bens Termin'));
      await tester.pumpAndSettle();
      expect(find.text('Nur der Ersteller kann diesen Termin ändern.'), findsOneWidget);
      expect(find.byTooltip('Termin bearbeiten'), findsNothing);
      expect(find.byTooltip('Termin löschen'), findsNothing);
    });

    testWidgets('Einzelnes Vorkommen einer Serie löschen erzeugt eine Ausnahme', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      final cal = app.services.calendar!;
      final e = await cal.create(
        title: 'Chor',
        start: DateTime.utc(2026, 3, 20, 17),
        end: DateTime.utc(2026, 3, 20, 18),
        visibility: EventVisibility.private,
        recurrence: const Recurrence(frequency: Frequency.weekly, count: 3),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chor'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Termin löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nur dieses'));
      await tester.pumpAndSettle();
      final after = (await app.events.get(e.id))!;
      expect(after.deleted, isFalse);
      expect(after.recurrence.exdates, <String>{'2026-03-20'});
      expect(after.version, 2);
    });

    testWidgets('Löschen entfernt den Termin und bietet Rückmeldung', (tester) async {
      final app = await _app();
      await _start(tester, app, tab: 'Kalender');
      final cal = app.services.calendar!;
      await cal.create(
        title: 'Einmalig',
        start: DateTime.utc(2026, 3, 20, 17),
        end: DateTime.utc(2026, 3, 20, 18),
        visibility: EventVisibility.shared,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einmalig'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Termin löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('Einmalig'), findsNothing);
      expect((await app.events.all()).single.deleted, isTrue);
    });
  });

  group('Chat-Karte', () {
    testWidgets('geteilter Termin als Karte im Chat mit direkter Zu-/Absage', (tester) async {
      final app = await _app();
      await _start(tester, app);
      final cal = app.services.calendar!;
      final e = await cal.create(
        title: 'Pizzaabend',
        start: DateTime.utc(2026, 3, 21, 17),
        end: DateTime.utc(2026, 3, 21, 19),
        visibility: EventVisibility.shared,
      );
      await cal.shareInChat(e);
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Chat')));
      await tester.pumpAndSettle();
      expect(find.text('Pizzaabend'), findsWidgets);
      await tester.tap(find.text('Absagen').last);
      await tester.pumpAndSettle();
      expect(cal.myRsvp(e.id), RsvpStatus.declined);
    });

    testWidgets('private Termine lassen sich nicht im Chat teilen', (tester) async {
      final app = await _app();
      await _start(tester, app);
      final cal = app.services.calendar!;
      final e = await cal.create(
        title: 'Geheim',
        start: DateTime.utc(2026, 3, 21, 17),
        end: DateTime.utc(2026, 3, 21, 19),
        visibility: EventVisibility.private,
      );
      await expectLater(cal.shareInChat(e), throwsA(anything));
      expect(app.gateway.messages, isEmpty);
    });
  });

  group('Heute', () {
    testWidgets('zeigt nächste Termine, geplante Erinnerungen und ungelesene Nachrichten', (tester) async {
      final app = await _app();
      final ben = await _joinBen(app);
      await _start(tester, app);
      final cal = app.services.calendar!;
      await cal.create(
        title: 'Schwimmen',
        start: DateTime.utc(2026, 3, 21, 8),
        end: DateTime.utc(2026, 3, 21, 9),
        visibility: EventVisibility.shared,
      );
      await ben.sendMessage('Hallo');
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Schwimmen'), findsOneWidget);
      expect(find.text('1 ungelesene Nachricht'), findsOneWidget);
      expect(find.text('1 Erinnerung geplant'), findsOneWidget);
      await tester.tap(find.text('Chat öffnen'));
      await tester.pumpAndSettle();
      expect(app.gateway.unreadCount, 0);
    });

    testWidgets('Hinweis und „Erlauben“, wenn Benachrichtigungen blockiert sind', (tester) async {
      final app = await _app();
      app.scheduler.current = ReminderPermission.notificationsDenied;
      await _start(tester, app);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Benachrichtigungen sind blockiert. Ohne sie erscheinen keine Erinnerungen.'), findsOneWidget);
      await tester.tap(find.text('Erlauben'));
      await tester.pumpAndSettle();
      expect(app.scheduler.requested, 1);
    });

    testWidgets('#57: „Erlauben“ ohne Wirkung → „Einstellungen öffnen“; nach der Rückkehr verschwindet der Hinweis', (tester) async {
      final app = await _app();
      app.scheduler
        ..current = ReminderPermission.notificationsDenied
        ..grantOnRequest = false; // System zeigt keinen Dialog
      await _start(tester, app);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erlauben'));
      await tester.pumpAndSettle();
      expect(find.textContaining('in den Systemeinstellungen ausgeschaltet'), findsOneWidget);
      await tester.tap(find.text('Einstellungen öffnen'));
      await tester.pumpAndSettle();
      expect(app.scheduler.settingsOpened, 1);

      app.scheduler.current = ReminderPermission.granted; // dort erlaubt
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Einstellungen öffnen'), findsNothing);
      expect(find.text('Erlauben'), findsNothing);
    });

    testWidgets('#57: ohne Weg in die Einstellungen (z. B. Android) bleibt „Erlauben“', (tester) async {
      final app = await _app();
      app.scheduler
        ..current = ReminderPermission.notificationsDenied
        ..grantOnRequest = false
        ..settingsAvailable = false;
      await _start(tester, app);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erlauben'));
      await tester.pumpAndSettle();
      expect(find.text('Erlauben'), findsOneWidget);
      expect(find.text('Einstellungen öffnen'), findsNothing);
    });
  });
}
