import 'package:family_nexus/data/sync/activity_notifier.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

class _Platform implements ActivityPlatform {
  final List<({ActivityKind kind, bool alert, int count})> shown = <({ActivityKind kind, bool alert, int count})>[];
  final List<ActivityKind> cancelled = <ActivityKind>[];

  List<ActivityKind> get kinds => <ActivityKind>[for (final s in shown) s.kind];

  @override
  Future<void> show(ActivityKind kind, {required bool alert, int count = 0}) async =>
      shown.add((kind: kind, alert: alert, count: count));

  @override
  Future<void> cancel(ActivityKind kind) async => cancelled.add(kind);
}

class _Badge implements AppBadge {
  final List<int> values = <int>[];

  @override
  void update(int count) => values.add(count);
}

typedef _Setup = ({TestApp app, _Platform platform, _Badge badge, FakeMatrixGateway ben});

Future<_Setup> _setUp() async {
  final platform = _Platform();
  final badge = _Badge();
  final app = await buildTestApp(activity: platform, badge: badge);
  final ben = app.server.newDevice();
  await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
  final room = app.gateway.familyRoom!;
  room.membership['@ben:${app.server.host}'] = MemberStatus.joined;
  ben.attachFamilyRoom(room.id);
  await app.services.openCalendar();
  expect(app.services.activity, isNotNull);
  return (app: app, platform: platform, badge: badge, ben: ben);
}

/// Setzt die Grundlinie wie der erste echte Sync und meldet die Änderung.
void _live(TestApp app, DateTime? since) {
  app.gateway.liveSince = since;
  app.server.notifyAll();
}

DateTime _t(int seconds) => DateTime.utc(2026, 10, 21, 12).add(Duration(seconds: seconds));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed));

  group('#254: Chat-Meldung', () {
    test('ohne Grundlinie keine Meldung und nichts gemerkt; danach entscheidet nur der Zeitstempel', () async {
      final s = await _setUp();
      s.app.server.nextTime = _t(10);
      await s.ben.sendMessage('kam bei geschlossener App');
      expect(s.platform.shown, isEmpty, reason: 'liveSince ist null');

      _live(s.app, _t(10));
      expect(s.platform.shown, isEmpty, reason: 'Zeitstempel = liveSince ist nicht neu');

      s.app.server.nextTime = _t(20);
      await s.ben.sendMessage('neu');
      expect(s.platform.shown, hasLength(1));
      expect(s.platform.shown.single.kind, ActivityKind.chat);
      expect(s.platform.shown.single.alert, isTrue);
      expect(s.platform.shown.single.count, s.app.gateway.unreadCount);
    });

    test('zuerst abgebildet, dann Grundlinie gesetzt: Altes bleibt stumm (Reihenfolge egal)', () async {
      final s = await _setUp();
      s.app.server.nextTime = _t(5);
      await s.ben.sendMessage('Rückstand');
      // Erst danach kommt der erste echte Sync mit dem größeren Zeitstempel.
      _live(s.app, _t(5));
      s.app.server.notifyAll();
      expect(s.platform.shown, isEmpty);
    });

    test('Grundlinie fällt weg (Abmelden): gemerkte Nachrichten werden vergessen', () async {
      final s = await _setUp();
      _live(s.app, _t(0));
      s.app.server.nextTime = _t(10);
      await s.ben.sendMessage('einmal');
      expect(s.platform.shown, hasLength(1));
      _live(s.app, null);
      // Neue Sitzung mit früherer Grundlinie: Ohne Vergessen bliebe die Nachricht still.
      _live(s.app, _t(5));
      expect(s.platform.shown, hasLength(2));
    });

    test('nachgeladener älterer Verlauf meldet nichts', () async {
      final s = await _setUp();
      _live(s.app, _t(100));
      s.app.server.nextTime = _t(50);
      await s.ben.sendMessage('alt, nachgeladen');
      expect(s.platform.shown, isEmpty);
    });

    test('eigene Nachricht und blockiertes Mitglied melden nichts', () async {
      final s = await _setUp();
      _live(s.app, _t(0));
      await s.app.gateway.sendMessage('von mir');
      expect(s.platform.shown, isEmpty);
      await s.app.services.settings.update((c) => c.copyWith(blockedUsers: <String>[s.ben.userId!]));
      await s.ben.sendMessage('blockiert');
      expect(s.platform.shown, isEmpty);
    });

    test('nicht Entschlüsseltes wird nicht gemerkt: lesbar geworden ist es neu', () async {
      final s = await _setUp();
      s.app.server.nextTime = _t(10);
      await s.ben.sendMessage('geheim'); // ohne Grundlinie: weder gemeldet noch gemerkt
      final id = s.app.gateway.messages.last.id;
      s.app.gateway.undecryptable.add(id);
      _live(s.app, _t(5));
      expect(s.platform.shown, isEmpty, reason: 'nicht entschlüsselbar');
      s.app.gateway.undecryptable.remove(id);
      s.app.server.notifyAll();
      expect(s.platform.kinds, <ActivityKind>[ActivityKind.chat], reason: 'später entschlüsselt, jünger als die Grundlinie');
    });

    test('sichtbares Gespräch meldet nichts, im Hintergrund schon', () async {
      final s = await _setUp();
      _live(s.app, _t(0));
      s.app.services.visibleChatThread = ChatThread.familyId;
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await s.ben.sendMessage('sichtbar');
      expect(s.platform.shown, isEmpty);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await s.ben.sendMessage('inaktiv, Fenster sichtbar');
      expect(s.platform.shown, isEmpty);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await s.ben.sendMessage('im Hintergrund');
      expect(s.platform.kinds, <ActivityKind>[ActivityKind.chat]);
    });

    test('gelesen (auch auf einem anderen Gerät): Meldung wird entfernt', () async {
      final s = await _setUp();
      _live(s.app, _t(0));
      await s.ben.sendMessage('hallo');
      expect(s.platform.kinds, <ActivityKind>[ActivityKind.chat]);
      await s.app.gateway.markChatRead();
      expect(s.platform.cancelled, <ActivityKind>[ActivityKind.chat]);
    });

    test('Schalter aus: keine Chat-Meldung', () async {
      final s = await _setUp();
      await s.app.services.settings.update((c) => c.copyWith(notifyChat: false));
      _live(s.app, _t(0));
      await s.ben.sendMessage('hallo');
      expect(s.platform.shown, isEmpty);
    });

    test('Zahl am App-Symbol folgt dem Ungelesen-Zähler', () async {
      final s = await _setUp();
      await s.ben.sendMessage('eins');
      await s.ben.sendMessage('zwei');
      expect(s.badge.values.last, 2);
      await s.app.gateway.markChatRead();
      expect(s.badge.values.last, 0);
    });

    test('Abmelden: Dienste zu, Zahl am App-Symbol auf 0', () async {
      final s = await _setUp();
      await s.ben.sendMessage('eins');
      s.app.services.closeCalendar(cancelReminders: true);
      expect(s.app.services.activity, isNull);
      expect(s.badge.values.last, 0);
      expect(s.app.scheduler.cancelled, 1, reason: 'cancelAll entfernt auch Chat- und Einkaufsmeldungen');
    });
  });

  group('#254: Hinweis höchstens alle 30 s, dazwischen still ersetzt', () {
    test('drei Nachrichten in 10 s: ein Hinweis, danach still; nach 30 s wieder mit Hinweis', () async {
      final platform = _Platform();
      final app = await buildTestApp();
      final ben = app.server.newDevice();
      await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
      app.gateway.familyRoom!.membership['@ben:${app.server.host}'] = MemberStatus.joined;
      ben.attachFamilyRoom(app.gateway.familyRoom!.id);
      var now = DateTime.utc(2026, 11, 3, 10);
      final n = ActivityNotifier(
        gateway: app.gateway,
        platform: platform,
        settings: () => const AppSettings(),
        isThreadVisible: (_) => false,
        clock: () => now,
      )..start();
      addTearDown(n.dispose);
      _live(app, _t(0));
      await ben.sendMessage('1');
      now = now.add(const Duration(seconds: 5));
      await ben.sendMessage('2');
      now = now.add(const Duration(seconds: 5));
      await ben.sendMessage('3');
      expect(platform.shown.map((e) => e.alert), <bool>[true, false, false]);
      expect(platform.shown.last.count, 3);
      now = now.add(const Duration(seconds: 30));
      await ben.sendMessage('4');
      expect(platform.shown.last.alert, isTrue);
    });
  });

  group('#254: Einkaufsmeldung', () {
    ShoppingItem item(String by, {String id = '00000000-0000-4000-8000-000000000001', bool checked = false}) =>
        ShoppingItem(id: id, title: 'Milch', by: by, version: 1, updatedAt: DateTime.utc(2026, 11, 3), checked: checked);

    Future<void> deliver(_Setup s, ShoppingItem i, DateTime ts, {String? sender}) async {
      s.app.gateway.injectSignal(ShoppingSignal(sender ?? i.by, ts, ShoppingCodec.encode(i)));
      await s.app.services.shopping!.sync.idle();
    }

    test('neuer Eintrag eines anderen nach der Grundlinie: Meldung', () async {
      final s = await _setUp();
      _live(s.app, _t(0));
      await deliver(s, item(s.ben.userId!), _t(10));
      expect(s.platform.kinds, <ActivityKind>[ActivityKind.shopping]);
      s.app.services.activity!.clearShopping();
      expect(s.platform.cancelled, <ActivityKind>[ActivityKind.shopping]);
    });

    test('Verlauf, ohne Grundlinie, eigener, blockierter oder abgehakter Eintrag: keine Meldung', () async {
      final s = await _setUp();
      final ben = s.ben.userId!;
      await deliver(s, item(ben, id: '00000000-0000-4000-8000-000000000011'), _t(10));
      expect(s.platform.shown, isEmpty, reason: 'liveSince null (Neuanmeldung, Wiedergabe der Historie)');
      _live(s.app, _t(20));
      await deliver(s, item(ben, id: '00000000-0000-4000-8000-000000000012'), _t(20));
      await deliver(s, item(ben, id: '00000000-0000-4000-8000-000000000013'), _t(5));
      expect(s.platform.shown, isEmpty, reason: 'Zeitstempel ≤ liveSince (Rückstand, Verlauf)');
      await deliver(s, item(s.app.gateway.userId!, id: '00000000-0000-4000-8000-000000000014'), _t(30));
      await deliver(s, item(ben, id: '00000000-0000-4000-8000-000000000015', checked: true), _t(31));
      await s.app.services.settings.update((c) => c.copyWith(blockedUsers: <String>[ben]));
      await deliver(s, item(ben, id: '00000000-0000-4000-8000-000000000016'), _t(32));
      expect(s.platform.shown, isEmpty);
    });

    test('verspätet verarbeitet: Signal aus dem ersten Sync kommt nach dem Setzen der Grundlinie an', () async {
      final s = await _setUp();
      s.app.gateway.injectSignal(ShoppingSignal(s.ben.userId!, _t(10), ShoppingCodec.encode(item(s.ben.userId!))));
      _live(s.app, _t(10)); // Grundlinie steht, bevor die Warteschlange das Signal verarbeitet
      await s.app.services.shopping!.sync.idle();
      expect(s.platform.shown, isEmpty);
    });

    test('Schalter aus: keine Einkaufsmeldung', () async {
      final s = await _setUp();
      await s.app.services.settings.update((c) => c.copyWith(notifyShopping: false));
      _live(s.app, _t(0));
      await deliver(s, item(s.ben.userId!), _t(10));
      expect(s.platform.shown, isEmpty);
    });
  });
}
