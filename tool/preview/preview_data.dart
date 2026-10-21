// Vorschau mit ERFUNDENEN Beispieldaten (Fake-Matrix, kein Netzwerk) für Store-Screenshots und Demos.
// Nicht Teil der App; nutzt die Testhilfen unter test/support.
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/time_zones.dart';

import '../../test/support/fake_matrix.dart';
import '../../test/support/test_app.dart';

/// Baut die Dienste mit erfundenen Beispieldaten.
Future<AppServices> buildPreviewServices() async {
  TimeZones.ensureInitialized();
  final server = FakeMatrixServer();
  server.addAccount('anna', 'geheim123', displayName: 'Anna');
  server.addAccount('ben', 'geheim456', displayName: 'Ben');
  server.addAccount('clara', 'x', displayName: 'Clara');
  final app = await buildTestApp(server: server, secureScreen: false, screenProtection: PlatformScreenProtection());
  await app.gateway.renameFamily('Familie Berger');
  final room = app.gateway.familyRoom!;
  final ben = server.newDevice();
  await ben.login(server: ServerUrl.tryParse(server.host)!, username: 'ben', password: 'geheim456');
  final clara = server.newDevice();
  await clara.login(server: ServerUrl.tryParse(server.host)!, username: 'clara', password: 'x');
  server.addMember(room, ben.userId!);
  server.addMember(room, clara.userId!);
  ben.attachFamilyRoom(room.id);
  clara.attachFamilyRoom(room.id);
  await ben.announcePresence(online: true);
  await clara.announcePresence(online: false);
  await ben.sendMessage('Wer holt Lena heute vom Training ab?');
  await app.gateway.sendMessage('Ich übernehme das, ich bin um 16 Uhr dort.');
  await clara.sendMessage('Danke! Ich bringe das Abendessen mit 🍝');
  final dm = await ben.startDirectChat(app.gateway.userId!);
  await ben.sendMessage('Kannst du auf dem Heimweg Milch mitbringen?', threadId: dm);

  final s = app.services;
  await s.openCalendar();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  Future<void> ev(String title, int dayOffset, int hour, int minutes, {String? place, int color = 0}) =>
      s.calendar!.create(
        title: title,
        start: today.add(Duration(days: dayOffset, hours: hour)).toUtc(),
        end: today.add(Duration(days: dayOffset, hours: hour, minutes: minutes)).toUtc(),
        visibility: EventVisibility.shared,
        location: place ?? '',
        colorIndex: color,
      ).then((_) {});
  await ev('Elternabend Grundschule', 0, 19, 90, place: 'Aula', color: 1);
  await ev('Zahnarzt Lena', 1, 9, 45, place: 'Praxis Dr. Berg', color: 2);
  await ev('Fußballtraining', 2, 16, 90, place: 'Sportplatz', color: 3);
  await ev('Familienessen bei Oma', 4, 12, 180, color: 0);
  await ev('Geburtstag Ben', 6, 15, 120, color: 5);

  for (final t in <(String, String)>[('Milch', '2 Liter'), ('Vollkornbrot', ''), ('Äpfel', '1 kg'), ('Nudeln', '500 g'), ('Tomaten', '6 Stück')]) {
    await s.shopping!.add(t.$1, quantity: t.$2);
  }
  await s.shopping!.setChecked(s.shopping!.items.last.id, true);
  return s;
}
