import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/invite_link.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #450: Blockierliste und vorgemerkter Einladungslink bleiben nicht auf dem Gerät, wenn die Sitzung endet. Der
/// Speicher der Einstellungen wird gezielt bereinigt (kein Neulesen: `AppRoot` ruft `wipeAccountData` bei jedem
/// Aufbau ohne Sitzung auf, auch in der Einrichtung vor der Anmeldung, E-56).
String _link() => InviteLink.create(
      roomId: '!fam:fake.test',
      via: 'fake.test',
      inviter: '@anna:fake.test',
      now: DateTime.now(),
      nonce: '0123456789abcdef0123456789abcdef',
    );

void main() {
  group('AppServices', () {
    test('wipeAccountData leert die Blockierliste im Speicher und in der Ablage, Link und Server bleiben', () async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(blockedUsers: <String>['@ben:fake.test'], pendingInvite: _link(), serverUrl: 'https://hs.example'));
      expect(app.store.data, contains(AppSettings.blockedUsersKey));
      s.debugWipeAccountData = () async {};
      await s.wipeAccountData();
      expect(s.settings.settings.blockedUsers, isEmpty);
      expect(app.store.data, isNot(contains(AppSettings.blockedUsersKey)));
      expect(s.settings.settings.pendingInvite, isNotNull, reason: 'Einladungslink eines Neulings (E-56) bleibt');
      expect(s.settings.settings.serverUrl, 'https://hs.example');
    });

    test('wipeAccountData (#516): gemerktes Gespräch weg, Schalter bleibt', () async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(restoreLastChat: true, lastChatThread: '!dm:fake.test'));
      expect(app.store.data, contains(AppSettings.lastChatThreadKey));
      s.debugWipeAccountData = () async {};
      await s.wipeAccountData();
      expect(s.settings.settings.lastChatThread, isNull);
      expect(app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
      expect(s.settings.settings.restoreLastChat, isTrue);
      expect(app.store.data['restoreLastChat'], 'true');
    });

    test('wiederholter Aufruf ohne Blockierliste benachrichtigt niemanden (keine Schleife über AppRoot)', () async {
      final app = await buildTestApp();
      final s = app.services;
      s.debugWipeAccountData = () async {};
      var notified = 0;
      s.settings.addListener(() => notified++);
      await s.wipeAccountData();
      await s.wipeAccountData();
      expect(notified, 0);
    });

    test('keepAccountData (#134): die Blockierliste bleibt', () async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(blockedUsers: <String>['@ben:fake.test']));
      s.debugWipeAccountData = () async {};
      s.keepAccountData = true;
      await s.wipeAccountData();
      expect(s.settings.settings.blockedUsers, <String>['@ben:fake.test']);
    });

    test('forgetPendingInvite verwirft Link in Speicher und Ablage', () async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(pendingInvite: _link()));
      s.pendingInvite.value = InviteLink.check(_link(), now: DateTime.now()).link;
      expect(s.pendingInvite.value, isNotNull);
      await s.forgetPendingInvite();
      expect(s.pendingInvite.value, isNull);
      expect(s.settings.settings.pendingInvite, isNull);
      expect(app.store.data, isNot(contains('pendingInvite')));
    });
  });

  group('AppRoot', () {
    Future<void> pump(WidgetTester tester, TestApp app) async {
      tester.view.physicalSize = const Size(900, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
    }

    testWidgets('Ende der Sitzung: vorgemerkter Link und Blockierliste sind weg', (tester) async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(blockedUsers: <String>['@ben:fake.test']));
      await pump(tester, app);
      // Erst nach dem Aufbau: Beim Start verwirft `AppRoot` einen Link, solange schon eine Familie besteht.
      await s.settings.update((c) => c.copyWith(pendingInvite: _link()));
      s.pendingInvite.value = InviteLink.check(_link(), now: DateTime.now()).link;
      await tester.pumpAndSettle();
      expect(s.settings.settings.pendingInvite, isNotNull, reason: 'Vorbedingung: Der Link steht');
      expect(s.pendingInvite.value, isNotNull);
      await app.gateway.logout();
      await tester.pumpAndSettle();
      expect(s.settings.settings.pendingInvite, isNull);
      expect(s.pendingInvite.value, isNull);
      expect(s.settings.settings.blockedUsers, isEmpty);
    });

    testWidgets('Ende der Sitzung (#516): gemerktes Gespräch weg, Schalter bleibt', (tester) async {
      final app = await buildTestApp();
      final s = app.services;
      await s.settings.update((c) => c.copyWith(restoreLastChat: true, lastChatThread: '!dm:fake.test'));
      await pump(tester, app);
      await app.gateway.logout();
      await tester.pumpAndSettle();
      expect(s.settings.settings.lastChatThread, isNull);
      expect(app.store.data, isNot(contains(AppSettings.lastChatThreadKey)));
      expect(s.settings.settings.restoreLastChat, isTrue);
    });

    testWidgets('Einrichtung vor der Anmeldung (E-56): der vorgemerkte Link bleibt trotz Aufbau ohne Sitzung', (tester) async {
      final app = await buildTestApp(loggedIn: false);
      final s = app.services;
      await s.settings.update((c) => c.copyWith(pendingInvite: _link()));
      await pump(tester, app);
      await tester.pumpAndSettle();
      expect(s.settings.settings.pendingInvite, isNotNull);
      expect(s.pendingInvite.value, isNotNull);
    });
  });
}
