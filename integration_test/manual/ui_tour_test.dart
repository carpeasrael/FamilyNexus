// Visuelle Rundreise für manuelle Prüfung (Screenshots per adb). Nutzt die
// Fake-Matrix aus test/support; nicht Teil der automatischen Gates.
import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/recurrence.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../test/support/test_app.dart';

Future<void> _hold(WidgetTester t, [int s = 7]) async {
  await t.pumpAndSettle();
  await t.pump(const Duration(seconds: 1));
  await Future<void>.delayed(Duration(seconds: s));
}

Future<void> _back(WidgetTester t) async {
  t.state<NavigatorState>(find.byType(Navigator).last).pop();
  await t.pumpAndSettle();
}

Future<void> _tab(WidgetTester t, String name) async {
  await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(name)));
  await t.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Rundreise', (tester) async {
    final now = DateTime.now().toUtc();
    final app = await buildTestApp(
      lang: 'de',
      clock: () => now,
      screenProtection: PlatformScreenProtection(),
      secureScreen: false,
    );
    final ben = app.server.newDevice();
    await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
    final room = app.gateway.familyRoom!;
    app.server.addMember(room, '@ben:fake.test');
    ben.attachFamilyRoom(room.id);
    await ben.sendMessage('Wer kauft heute ein?');
    await app.gateway.sendMessage('Ich übernehme das 🛒');

    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
    final cal = app.services.calendar!;
    final base = DateTime.utc(now.year, now.month, now.day, 15);
    final e1 = await cal.create(title: 'Elternabend Grundschule', start: base.add(const Duration(days: 1)), end: base.add(const Duration(days: 1, hours: 2)), visibility: EventVisibility.shared, location: 'Aula', colorIndex: 1);
    await cal.create(title: 'Zahnarzt', start: base.add(const Duration(hours: 3)), end: base.add(const Duration(hours: 4)), visibility: EventVisibility.private, colorIndex: 2);
    await cal.create(title: 'Turnen', start: base.add(const Duration(days: 2)), end: base.add(const Duration(days: 2, hours: 1)), visibility: EventVisibility.shared, recurrence: const Recurrence(frequency: Frequency.weekly), colorIndex: 3);
    await cal.create(title: 'Urlaub', start: DateTime.utc(now.year, now.month, now.day + 4), end: DateTime.utc(now.year, now.month, now.day + 6), allDay: true, visibility: EventVisibility.shared, colorIndex: 4);
    await cal.shareInChat(e1);
    await cal.load();
    await tester.pumpAndSettle();

    await _hold(tester); // 1 Heute
    await _tab(tester, 'Kalender');
    await _hold(tester); // 2 Monat
    await tester.tap(find.text('Woche'));
    await _hold(tester); // 3 Woche
    await tester.tap(find.text('Agenda'));
    await _hold(tester); // 4 Agenda
    await tester.ensureVisible(find.text('Elternabend Grundschule').first);
    await tester.tap(find.text('Elternabend Grundschule').first);
    await _hold(tester); // 5 Detail
    await _back(tester);
    await tester.tap(find.byTooltip('Neuer Termin'));
    await _hold(tester); // 6 Editor
    await _back(tester);
    await _tab(tester, 'Chat');
    await _hold(tester); // 7 Chat
    app.gateway.familyRoom!.membership['@cara:fake.test'] = MemberStatus.requested;
    app.server.notifyAll();
    await _tab(tester, 'Familie');
    await _hold(tester); // 8 Familie
    await tester.tap(find.text('Jemanden einladen'));
    await _hold(tester); // 8b Einladungs-QR
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();
    await _tab(tester, 'Einstellungen');
    await _hold(tester); // 9 Einstellungen dunkel
    await tester.drag(find.byType(ListView).last, const Offset(0, -900));
    await _hold(tester); // 9b Sicherheit/Erinnerungen
    await app.services.settings.update((s) => s.copyWith(themeMode: AppThemeMode.light));
    await _tab(tester, 'Kalender');
    await _hold(tester); // 10 hell
    await app.services.settings.update((s) => s.copyWith(reduceEffects: true));
    await _tab(tester, 'Heute');
    await _hold(tester); // 11 hell, reduziert
    expect(app.gateway.family!.myRole, Role.moderator);
  });
}
