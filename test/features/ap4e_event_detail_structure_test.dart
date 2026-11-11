import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/event_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/semantics_snapshot.dart';
import '../support/test_app.dart';

/// AP-4e: Die Zerlegung von `EventDetailScreen.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

Future<void> _start(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String title) async {
  await tester.tap(navTab('Kalender'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Termin-Detail: privat, einmalig, ohne Zusatzangaben', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(clock: () => _now);
    await _start(tester, app);
    await app.services.calendar!.create(
      title: 'Zahnarzt',
      start: DateTime.utc(2026, 3, 20, 14),
      end: DateTime.utc(2026, 3, 20, 15),
      visibility: EventVisibility.private,
    );
    await _open(tester, 'Zahnarzt');
    final snap = semanticsSnapshot(tester, find.byType(EventDetailScreen));
    expect(snap, _expectedPrivate);
    handle.dispose();
  });

  testWidgets('Termin-Detail: geteilt, wöchentlich, mit Ort, Notiz, Teilnehmer und Zusage', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(clock: () => _now);
    final ben = app.server.newDevice();
    await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
    final room = app.gateway.familyRoom!;
    app.server.addMember(room, '@ben:fake.test');
    ben.attachFamilyRoom(room.id);
    await _start(tester, app);
    final c = app.services.calendar!;
    final e = await c.create(
      title: 'Elternabend',
      start: DateTime.utc(2026, 3, 20, 17),
      end: DateTime.utc(2026, 3, 20, 18),
      visibility: EventVisibility.shared,
      location: 'Schule',
      note: 'Bitte Unterlagen mitbringen',
      recurrence: const Recurrence(frequency: Frequency.weekly, interval: 1, weekdays: <int>{5}),
      attendees: <String>['@ben:fake.test'],
    );
    await c.respond(e.id, RsvpStatus.accepted);
    await _open(tester, 'Elternabend');
    final snap = semanticsSnapshot(tester, find.byType(EventDetailScreen));
    expect(snap, _expectedShared);
    handle.dispose();
  });
}

const List<String> _expectedPrivate = <String>[
  'L=Zahnarzt | hh:mm – hh:mm | Freitag, 20. März 2026 | Privat | Von dir',
  'L=Deine Erinnerungen',
  'L=Zur Startzeit button tap',
  'L=5 Minuten vorher button tap',
  'L=10 Minuten vorher button selected tap',
  'L=15 Minuten vorher button tap',
  'L=30 Minuten vorher button tap',
  'L=1 Stunde vorher button tap',
  'L=2 Stunden vorher button tap',
  'L=1 Tag vorher button tap',
  'L=2 Tage vorher button tap',
  'L=Zurück T=Zurück button tap',
  'L=Termin',
  'T=Termin bearbeiten button tap',
  'T=Termin löschen button tap',
];
const List<String> _expectedShared = <String>[
  'L=Elternabend | hh:mm – hh:mm | Freitag, 20. März 2026 | Geteilt | Wöchentlich | Schule | Bitte Unterlagen mitbringen | Von dir',
  'L=Antwort | Du | Zugesagt | Teilnehmer',
  'L=Zusagen button selected tap',
  'L=Vielleicht button tap',
  'L=Absagen button tap',
  'L=Ben',
  'L=Im Chat teilen button tap',
  'L=Deine Erinnerungen',
  'L=Zur Startzeit button tap',
  'L=5 Minuten vorher button tap',
  'L=10 Minuten vorher button selected tap',
  'L=15 Minuten vorher button tap',
  'L=30 Minuten vorher button tap',
  'L=1 Stunde vorher button tap',
  'L=2 Stunden vorher button tap',
  'L=1 Tag vorher button tap',
  'L=2 Tage vorher button tap',
  'L=Zurück T=Zurück button tap',
  'L=Termin',
  'T=Termin bearbeiten button tap',
  'T=Termin löschen button tap',
];
