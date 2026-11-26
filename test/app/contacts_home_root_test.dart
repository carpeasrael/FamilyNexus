import 'dart:async';
import 'dart:ui' show Size;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/domain/family.dart' show MemberStatus;
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/contacts/contacts_screen.dart' show ContactsHome;
import 'package:family_nexus/features/onboarding/onboarding_screen.dart';
import 'package:family_nexus/features/shell/home_shell.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/test_app.dart';

/// #119, K3c-3 (E-114): Die App-Hülle ohne Familie. Ohne Familie gibt es die schlanke `ContactsHome` nur nach dem ausdrücklichen
/// Knopf „Ohne Familie fortfahren (nur Kontakte)“ (`contactsOnly`) und nur bei freigeschalteten Kontakten; eine Familie
/// gewinnt immer; Familieneinladungen und Beitrittsanfragen werden dort nie automatisch angenommen.
void main() {
  const button = 'Ohne Familie fortfahren (nur Kontakte)';

  /// Konto ohne Familie: angemeldet, gesichert, Einrichtung einmal abgeschlossen, die Familie ist weg (entfernt).
  Future<TestApp> noFamily({bool contactsEnabled = true, bool contactsOnly = false}) async {
    final app = await buildTestApp(contactsEnabled: contactsEnabled);
    app.gateway.detachFamilyRoom();
    if (contactsOnly) await app.services.settings.update((c) => c.copyWith(contactsOnly: true));
    addTearDown(() {
      app.services.closeCalendar();
      app.services.closeContacts();
    });
    return app;
  }

  Future<void> start(WidgetTester tester, TestApp app) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FamilyNexusApp(services: app.services));
    await tester.pumpAndSettle();
  }

  group('Hülle ohne Familie', () {
    testWidgets('Flag aus: nie ContactsHome, auch nicht mit gemerktem contactsOnly; kein Knopf', (tester) async {
      final app = await noFamily(contactsEnabled: false, contactsOnly: true);
      await start(tester, app);
      expect(app.services.contacts, isNull);
      expect(find.byType(ContactsHome), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text(button), findsNothing);
    });

    testWidgets('ohne Familie und ohne contactsOnly: Einrichtung mit dem Knopf; kein automatischer Einstieg', (tester) async {
      final app = await noFamily();
      await start(tester, app);
      expect(app.services.contacts, isNotNull, reason: 'die Kontakt-Dienste sind offen, damit der Knopf erscheint');
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ContactsHome), findsNothing);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text(button), findsOneWidget);
      expect(app.services.settings.settings.contactsOnly, isFalse);
    });

    testWidgets('der Knopf merkt die Wahl lokal und zeigt die ContactsHome; kein Kalender, keine Tabs', (tester) async {
      final app = await noFamily();
      await start(tester, app);
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.byType(ContactsHome), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(find.byType(HomeShell), findsNothing);
      expect(app.services.calendar, isNull, reason: 'keine Familiendienste');
      expect(app.services.settings.settings.contactsOnly, isTrue);
      expect(app.store.data[AppSettings.contactsOnlyKey], 'true');
    });

    testWidgets('Neustart mit gemerkter Wahl: ContactsHome ohne Umweg über die Einrichtung', (tester) async {
      final app = await noFamily(contactsOnly: true);
      await start(tester, app);
      expect(find.byType(ContactsHome), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(app.services.contacts, isNotNull);
    });

    testWidgets('Familie gewinnt immer: mit Familie und gemerktem contactsOnly erscheint HomeShell, die Wahl wird aufgehoben', (tester) async {
      final app = await buildTestApp(contactsEnabled: true);
      await app.services.settings.update((c) => c.copyWith(contactsOnly: true));
      await start(tester, app);
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(ContactsHome), findsNothing);
      expect(app.services.settings.settings.contactsOnly, isFalse);
      expect(app.store.data.containsKey(AppSettings.contactsOnlyKey), isFalse);
      app.services.closeCalendar();
      app.services.closeContacts();
    });

    testWidgets('eine Familie, die in der ContactsHome entsteht, gewinnt: HomeShell statt ContactsHome', (tester) async {
      final app = await noFamily(contactsOnly: true);
      await start(tester, app);
      expect(find.byType(ContactsHome), findsOneWidget);
      app.gateway.attachFamilyRoom(app.server.addFamilyRoom('Familie Neu', '@anna:fake.test').id);
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.byType(ContactsHome), findsNothing);
      expect(app.services.settings.settings.contactsOnly, isFalse);
    });

    testWidgets('Karte „Familie gründen oder beitreten“ nimmt die Wahl zurück: Einrichtung', (tester) async {
      final app = await noFamily(contactsOnly: true);
      await start(tester, app);
      await tester.tap(find.text('Familie gründen oder beitreten'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ContactsHome), findsNothing);
      expect(app.services.settings.settings.contactsOnly, isFalse);
      expect(app.services.settings.settings.onboardingDone, isTrue);
    });
  });

  group('Karten ohne automatische Annahme', () {
    Future<FakeRoom> benInvitesAnna(TestApp app) async {
      final ben = app.server.newDevice();
      await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
      await ben.setUpSecurity();
      await ben.createFamily('Familie Ben');
      final room = app.server.rooms.values.firstWhere((r) => r.name == 'Familie Ben');
      app.server.invites['@anna:${app.server.host}'] = <String>[room.id];
      return room;
    }

    testWidgets('Familieneinladung: Karte mit Name und Einladendem, nie angenommen oder abgelehnt', (tester) async {
      final app = await noFamily(contactsOnly: true);
      final room = await benInvitesAnna(app);
      await start(tester, app);
      expect(find.byType(ContactsHome), findsOneWidget);
      expect(find.text('Einladung in eine Familie'), findsOneWidget);
      expect(find.textContaining('Familie Ben'), findsWidgets);
      expect(find.text('Einrichtung öffnen'), findsOneWidget);
      // Weder die Karte noch mehrere Aufbauten nehmen an.
      await tester.pump(const Duration(seconds: 5));
      expect(app.gateway.family, isNull, reason: 'nie automatisch angenommen');
      expect(app.server.invites['@anna:${app.server.host}'], <String>[room.id], reason: 'Einladung bleibt unbeantwortet');
      expect(room.membership['@anna:${app.server.host}'], isNot(MemberStatus.joined));
      expect(find.byType(HomeShell), findsNothing);
    });

    testWidgets('„Einrichtung öffnen“ führt in den Familienschritt; angenommen wird erst dort per Tipp', (tester) async {
      final app = await noFamily(contactsOnly: true);
      final room = await benInvitesAnna(app);
      await start(tester, app);
      await tester.tap(find.text('Einrichtung öffnen'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ContactsHome), findsNothing);
      expect(app.gateway.family, isNull, reason: 'auch der Weg in die Einrichtung nimmt nicht an');
      expect(room.membership['@anna:${app.server.host}'], isNot(MemberStatus.joined));
    });

    testWidgets('Beitrittsanfrage: Karte, Stand „wartet“, keine Annahme', (tester) async {
      final app = await noFamily(contactsOnly: true);
      final room = await benInvitesAnna(app);
      app.server.invites.clear();
      room.membership['@anna:${app.server.host}'] = MemberStatus.requested;
      await start(tester, app);
      expect(find.textContaining('Beitrittsanfrage wartet auf Bestätigung'), findsOneWidget);
      expect(app.gateway.family, isNull);
      expect(room.membership['@anna:${app.server.host}'], MemberStatus.requested);
    });
  });

  group('Kontakte in der Hülle', () {
    const carla = '@carla:fake.test';

    Future<void> enable(TestApp app) async {
      final c = app.services.contacts!.controller;
      await c.setEnabled(true);
      await c.idle();
    }

    testWidgets('ausgeschaltet: Erklärseite mit Einwilligung, keine Gespräche; erst die Taste schaltet ein', (tester) async {
      final app = await noFamily(contactsOnly: true);
      await start(tester, app);
      expect(find.text('Kontakte einschalten?'), findsOneWidget);
      expect(find.text('Kontakte einschalten'), findsOneWidget);
      expect(app.services.contacts!.controller.enabled, isFalse);
      await tester.ensureVisible(find.text('Kontakte einschalten'));
      await tester.tap(find.text('Kontakte einschalten'));
      await tester.pumpAndSettle();
      expect(app.services.contacts!.controller.enabled, isTrue);
      expect(find.text('Kontakte einschalten?'), findsNothing);
    });

    testWidgets('eingeschaltet: nur der Kontakte-Bereich, kein Familien-Umschalter; Gespräch mit Kontakt ist da', (tester) async {
      final app = await noFamily(contactsOnly: true);
      app.server.addAccount('carla', 'pw-carla', displayName: 'Carla');
      app.server.createContactRoom(carla, app.gateway.userId!, toJoined: true);
      await start(tester, app);
      await enable(app);
      await app.services.contacts!.sync.service.addAccepted(carla);
      await app.services.contacts!.sync.pushPolicyNow();
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.byType(ContactsHome), findsOneWidget);
      expect(find.text('Familie'), findsNothing, reason: 'kein Umschalter Familie | Kontakte');
      expect(find.textContaining('Carla'), findsWidgets, reason: 'das Gespräch mit dem Kontakt steht in der Liste');
      expect(app.gateway.threads.where((t) => t.isOutside), hasLength(1));
    });

    testWidgets('Kontaktanfrage: Karte mit Zahl, nie automatisch angenommen; „Anfragen ansehen“ öffnet die Verwaltung', (tester) async {
      final app = await noFamily(contactsOnly: true);
      app.server.addAccount('carla', 'pw-carla', displayName: 'Carla');
      await start(tester, app);
      await enable(app);
      final room = app.server.createContactRoom(carla, app.gateway.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(find.text('1 neue Kontaktanfrage'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(room.invitedUsers, contains(app.gateway.userId), reason: 'nie automatisch angenommen');
      expect(app.gateway.threads.where((t) => t.isOutside), isEmpty);
      await tester.tap(find.text('Anfragen ansehen'));
      await tester.pumpAndSettle();
      expect(find.text('Annehmen'), findsOneWidget, reason: 'Annahme nur mit ausdrücklichem Tipp und Bestätigung in der Verwaltung');
      expect(room.invitedUsers, contains(app.gateway.userId));
    });

    testWidgets('Abmelden in der Hülle: Wahl und Kontakt-Dienste enden, die Einrichtung (Anmeldung) erscheint', (tester) async {
      final app = await noFamily(contactsOnly: true);
      app.services.debugWipeAccountData = () async {};
      await start(tester, app);
      expect(find.byType(ContactsHome), findsOneWidget);
      await app.services.logout();
      await tester.pumpAndSettle();
      expect(find.byType(ContactsHome), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(app.services.contacts, isNull, reason: 'Kontakt-Dienste vor dem Löschen geschlossen');
      expect(app.services.settings.settings.contactsOnly, isFalse);
      expect(app.store.data.containsKey(AppSettings.contactsOnlyKey), isFalse);
    });

    testWidgets('Schriftfaktor 2,0 mit Einladung und Anfrage: kein Überlauf, Knöpfe erreichbar', (tester) async {
      final app = await noFamily(contactsOnly: true);
      app.server.addAccount('carla', 'pw-carla', displayName: 'Carla');
      final ben = app.server.newDevice();
      await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
      await ben.setUpSecurity();
      await ben.createFamily('Familie Ben');
      app.server.invites['@anna:${app.server.host}'] = <String>[app.server.rooms.values.firstWhere((r) => r.name == 'Familie Ben').id];
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(tester, app);
      await enable(app);
      app.server.createContactRoom(carla, app.gateway.userId!);
      app.server.notifyAll();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Einladung in eine Familie'), findsOneWidget);
      expect(find.byType(ContactsHome), findsOneWidget);
    });

    testWidgets('Einstellungen sind erreichbar, auch ohne Familie', (tester) async {
      final app = await noFamily(contactsOnly: true);
      await start(tester, app);
      await tester.tap(find.byTooltip('Einstellungen öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Einstellungen'), findsWidgets);
      expect(find.text('Konto'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Dienste ohne Familie (AppServices)', () {
    test('ohne Freigabe: kein Anspruch, kein Dienst, nichts in der Ablage (verhaltensgleich)', () async {
      final owners = <String>[];
      final app = await buildTestApp(familyDataClaim: (o) async => owners.add(o));
      app.gateway.detachFamilyRoom();
      await app.services.openContactsAccount();
      expect(app.services.contacts, isNull);
      expect(owners, isEmpty);
      expect(await app.services.enterContactsOnly(), isFalse);
      expect(app.services.settings.settings.contactsOnly, isFalse);
    });

    test('mit Freigabe: Anspruch für das Konto ohne Familie, dann Start; zweimal parallel gerufen: ein Dienst, ein Anspruch', () async {
      final owners = <String>[];
      var built = 0;
      final app = await buildTestApp(
        contactsEnabled: true,
        familyDataClaim: (o) async => owners.add(o),
        contactsDecorate: (c) {
          built++;
          return c;
        },
      );
      addTearDown(app.services.closeContacts);
      app.gateway.detachFamilyRoom();
      await Future.wait<void>(<Future<void>>[app.services.openContactsAccount(), app.services.openContactsAccount()]);
      expect(app.services.contacts, isNotNull);
      expect(owners, <String>['@anna:fake.test|']);
      expect(built, 1);
      await app.services.openContactsAccount();
      expect(built, 1, reason: 'idempotent');
      expect(owners, hasLength(1));
    });

    test('Abmelden während des Anspruchs: es öffnet nichts', () async {
      final gate = Completer<void>();
      final app = await buildTestApp(contactsEnabled: true, familyDataClaim: (o) => gate.future);
      app.gateway.detachFamilyRoom();
      final opening = app.services.openContactsAccount();
      await app.gateway.logout();
      gate.complete();
      await opening;
      expect(app.services.contacts, isNull);
    });

    test('enterContactsOnly: nur ohne Familie und mit offenen Diensten; merkt Wahl und Einrichtung, beansprucht das Konto ohne Familie', () async {
      final owners = <String>[];
      final app = await buildTestApp(contactsEnabled: true, familyDataClaim: (o) async => owners.add(o));
      addTearDown(app.services.closeContacts);
      expect(await app.services.enterContactsOnly(), isFalse, reason: 'Dienste noch nicht offen');
      app.gateway.detachFamilyRoom();
      await app.services.openContactsAccount();
      owners.clear();
      expect(await app.services.enterContactsOnly(), isTrue);
      expect(app.services.settings.settings.contactsOnly, isTrue);
      expect(owners, <String>['@anna:fake.test|'], reason: 'Daten einer früheren Familie werden mit dem Anspruch entfernt');
      app.gateway.attachFamilyRoom(app.server.addFamilyRoom('Neu', '@anna:fake.test').id);
      expect(await app.services.enterContactsOnly(), isFalse, reason: 'die Familie gewinnt');
    });

    testWidgets('Kein Anspruch vor dem ersten Abgleich: ein Familienkonto verliert beim Start nie seine Daten', (tester) async {
      final owners = <String>[];
      final app = await buildTestApp(contactsEnabled: true, familyDataClaim: (o) async => owners.add(o));
      addTearDown(() {
        app.services.closeCalendar();
        app.services.closeContacts();
      });
      app.gateway.detachFamilyRoom(); // Familie noch nicht bekannt
      app.gateway.syncDone = false;
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100)); // der Ladekreis des Familienschritts dreht ohne Ende
      }
      expect(owners, isEmpty, reason: 'ohne Abgleich ist „keine Familie“ nicht bekannt');
      expect(app.services.contacts, isNull);
      app.gateway.syncDone = true;
      app.gateway.attachFamilyRoom(app.server.addFamilyRoom('Familie', '@anna:fake.test').id);
      await tester.pumpAndSettle();
      expect(owners.where((o) => o.endsWith('|')), isEmpty, reason: 'mit Familie nie der Anspruch für ein Konto ohne Familie');
      expect(find.byType(HomeShell), findsOneWidget);
    });
  });
}
