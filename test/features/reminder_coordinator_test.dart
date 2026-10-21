import 'dart:ui';

import 'package:family_nexus/data/platform/reminder_scheduler.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/time_zones.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:family_nexus/features/reminders/reminder_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_scheduler.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(TimeZones.ensureInitialized);

  final now = DateTime.utc(2026, 3, 20, 10);
  late TestApp app;
  late CalendarController cal;
  late FakeReminderScheduler sched;
  late ReminderCoordinator coord;

  Future<void> setUpApp({String? lang = 'de'}) async {
    app = await buildTestApp(lang: lang, clock: () => now);
    cal = await app.services.calendarBuilder!('@anna:fake.test');
    sched = FakeReminderScheduler();
    coord = ReminderCoordinator(
      calendar: cal,
      scheduler: sched,
      settings: app.services.settings,
      deviceLocale: () => const Locale('fr'),
      clock: () => now,
    );
  }

  tearDown(() {
    coord.dispose();
    cal.dispose();
  });

  Future<CalendarEvent> make(String title, {DateTime? start, List<int>? reminders}) => cal.create(
        title: title,
        start: start ?? DateTime.utc(2026, 3, 21, 9),
        end: (start ?? DateTime.utc(2026, 3, 21, 9)).add(const Duration(hours: 1)),
        visibility: EventVisibility.private,
        reminders: reminders,
      );

  test('plant die Standard-Erinnerung mit generischem Text (de)', () async {
    await setUpApp();
    await make('Zahnarzt Dr. Müller, Praxis am Markt');
    await coord.reschedule();
    expect(sched.last, hasLength(1));
    expect(sched.texts.single.title, 'Erinnerung');
    expect(sched.texts.single.body, 'Termin in 10 Minuten');
  });

  test('Datenschutz: kein Titel, Ort oder Notiz in irgendeinem Benachrichtigungstext', () async {
    await setUpApp();
    final e = await cal.create(
      title: 'GEHEIMER-TITEL',
      start: DateTime.utc(2026, 3, 23, 9),
      end: DateTime.utc(2026, 3, 23, 10),
      visibility: EventVisibility.shared,
      location: 'GEHEIMER-ORT',
      note: 'GEHEIME-NOTIZ',
      reminders: <int>[0, 10, 60, 1440],
    );
    await coord.reschedule();
    expect(sched.last, hasLength(4));
    final all = sched.texts.map((t) => '${t.title}|${t.body}').join('\n');
    for (final secret in <String>['GEHEIM', e.title, e.location, e.note, e.id]) {
      expect(all, isNot(contains(secret)));
    }
    expect(sched.texts.map((t) => t.body).toSet(), <String>{
      'Termin in 0 Minuten',
      'Termin in 10 Minuten',
      'Termin in 1 Stunde',
      'Termin in 1 Tag',
    });
  });

  test('englische Texte, wenn die App-Sprache Englisch ist; sonst Gerätesprache (fr → en)', () async {
    await setUpApp(lang: 'en');
    await make('x', reminders: <int>[60]);
    await coord.reschedule();
    expect(sched.texts.single.body, 'Event in 1 hour');
    expect(sched.texts.single.title, 'Reminder');
    await app.services.settings.update((s) => s.copyWith(languageCode: null));
    await coord.reschedule();
    expect(sched.texts.single.body, 'Event in 1 hour');
  });

  test('persönliche Erinnerungen ersetzen den Standard; Löschen leert die Planung', () async {
    await setUpApp();
    final e = await make('A', start: DateTime.utc(2026, 3, 23, 9));
    await cal.setReminders(e.id, <int>[1440, 60]);
    await coord.reschedule();
    expect(sched.last.map((r) => r.minutesBefore), <int>[1440, 60]);
    await cal.delete(e.id);
    await coord.reschedule();
    expect(sched.last, isEmpty);
  });

  test('Änderung des Standards in den Einstellungen plant neu', () async {
    await setUpApp();
    await make('A');
    coord.start();
    await app.services.settings.update((s) => s.copyWith(defaultReminderMinutes: <int>[5, 30]));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    expect(sched.last.map((r) => r.minutesBefore).toSet(), <int>{5, 30});
  });

  test('Serie: jedes Vorkommen wird geplant, vergangene nicht', () async {
    await setUpApp();
    await cal.create(
      title: 'Serie',
      start: DateTime.utc(2026, 3, 1, 9),
      end: DateTime.utc(2026, 3, 1, 10),
      visibility: EventVisibility.private,
    );
    await coord.reschedule();
    expect(sched.last, isEmpty, reason: 'einmaliger Termin in der Vergangenheit');
  });

  test('Berechtigungsstatus wird weitergegeben und kann angefragt werden', () async {
    await setUpApp();
    sched.current = ReminderPermission.notificationsDenied;
    await coord.reschedule();
    expect(coord.permission, ReminderPermission.notificationsDenied);
    await coord.requestPermission();
    expect(coord.permission, ReminderPermission.granted);
    expect(sched.requested, 1);
  });

  test('Neuplanung nach Neustart: frischer Koordinator plant aus dem gespeicherten Bestand', () async {
    await setUpApp();
    await make('A', reminders: <int>[10]);
    coord.dispose();
    final sched2 = FakeReminderScheduler();
    final coord2 = ReminderCoordinator(
      calendar: cal,
      scheduler: sched2,
      settings: app.services.settings,
      deviceLocale: () => const Locale('de'),
      clock: () => now,
    );
    await coord2.reschedule();
    expect(sched2.last, hasLength(1));
    coord2.dispose();
    coord = ReminderCoordinator(calendar: cal, scheduler: sched, settings: app.services.settings, clock: () => now);
  });
}

