// Vorschau mit ERFUNDENEN Beispieldaten (Fake-Matrix, kein Netzwerk) für Store-Screenshots und Demos.
// Nicht Teil der App; nutzt die Testhilfen unter test/support.
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/time_zones.dart';

import '../../test/support/fake_matrix.dart';
import '../../test/support/test_app.dart';

/// Baut die Dienste mit erfundenen Beispieldaten ([lang]: `de` oder `en`, Oberfläche und Beispieltexte).
Future<AppServices> buildPreviewServices({String lang = 'de'}) async {
  final en = lang == 'en';
  String t(String de, String enText) => en ? enText : de;
  TimeZones.ensureInitialized();
  final server = FakeMatrixServer();
  server.addAccount('anna', 'geheim123', displayName: 'Anna');
  server.addAccount('ben', 'geheim456', displayName: 'Ben');
  server.addAccount('clara', 'x', displayName: 'Clara');
  final app = await buildTestApp(lang: lang, server: server, secureScreen: false, screenProtection: PlatformScreenProtection());
  await app.gateway.renameFamily(t('Familie Berger', 'Berger Family'));
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
  await ben.sendMessage(t('Wer holt Lena heute vom Training ab?', 'Who is picking Lena up from practice today?'));
  await app.gateway.sendMessage(t('Ich übernehme das, ich bin um 16 Uhr dort.', 'I will do it, I will be there at 4 pm.'));
  await clara.sendMessage(t('Danke! Ich bringe das Abendessen mit 🍝', 'Thanks! I will bring dinner 🍝'));
  final dm = await ben.startDirectChat(app.gateway.userId!);
  await ben.sendMessage(t('Kannst du auf dem Heimweg Milch mitbringen?', 'Can you pick up milk on your way home?'), threadId: dm);

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
  await ev(t('Elternabend Grundschule', 'Parent evening'), 0, 19, 90, place: t('Aula', 'Assembly hall'), color: 1);
  await ev(t('Zahnarzt Lena', 'Lena dentist'), 1, 9, 45, place: t('Praxis Dr. Berg', 'Dr. Berg Practice'), color: 2);
  await ev(t('Fußballtraining', 'Soccer practice'), 2, 16, 90, place: t('Sportplatz', 'Sports field'), color: 3);
  await ev(t('Familienessen bei Oma', 'Family dinner at Grandma’s'), 4, 12, 180, color: 0);
  await ev(t('Geburtstag Ben', 'Ben’s birthday'), 6, 15, 120, color: 5);

  for (final t in <(String, String)>[(t('Milch', 'Milk'), t('2 Liter', '2 liters')), (t('Vollkornbrot', 'Whole-grain bread'), ''), (t('Äpfel', 'Apples'), '1 kg'), (t('Nudeln', 'Pasta'), '500 g'), (t('Tomaten', 'Tomatoes'), t('6 Stück', '6 pieces'))]) {
    await s.shopping!.add(t.$1, quantity: t.$2);
  }
  await s.shopping!.setChecked(s.shopping!.items.last.id, true);
  return s;
}
