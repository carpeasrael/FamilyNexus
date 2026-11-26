import 'dart:io';

import 'package:family_nexus/app/contact_factory.dart';
import 'package:family_nexus/domain/contact_service.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/contact_peer.dart';
import '../support/fake_matrix.dart';
import '../support/memory_contact_store.dart';
import '../support/test_app.dart';

/// #119, K2c und K3c-2 (E-114): Verdrahtung der Kontakt-Dienste. Sie gehören zum Konto, nicht zum Kalender und nicht zur
/// Familie; `AppServices.openContacts`/`closeContacts` steuern den Lebenszyklus. Die Sperre gilt auch hier.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late MemoryContactStore store;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    store = MemoryContactStore();
  });

  ContactServices? build({MemoryContactStore? contacts, bool? enabled, MemoryBlockedList? blocked}) => buildContactServices(
        gateway: gateway,
        userId: gateway.userId!,
        retryInterval: const Duration(hours: 1),
        contactStore: contacts,
        contactsEnabled: enabled ?? ContactFlags.enabled,
        blockedList: blocked,
      );

  group('Fabrik', () {
    test('Standard: die Sperre ist an, es entsteht kein Dienst und der Speicher bleibt unberührt', () async {
      expect(ContactFlags.enabled, isFalse);
      expect(build(contacts: store), isNull);
      expect(await store.all(), isEmpty);
    });

    test('freigeschaltet, aber ohne Ablage: kein Dienst', () {
      expect(build(enabled: true), isNull);
    });

    test('freigeschaltet mit Ablage: der Dienst entsteht auch ohne Familie, startet und endet mit seinem Lebenszyklus', () async {
      final blocked = MemoryBlockedList();
      final c = build(contacts: store, enabled: true, blocked: blocked)!;
      expect(gateway.family, isNull, reason: 'Kontakte gehören zum Konto, nicht zur Familie');
      await c.sync.service.block('@ben:example.org');
      c.start();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await c.idle();
      expect(blocked.list, <String>['@ben:example.org'], reason: 'der Start gleicht die Blockierliste ab');
      expect(server.log.where((e) => e.type == ContactCodec.type), hasLength(1), reason: 'der Datensatz wurde gesendet');
      c.dispose();
    });

    test('Lebenszyklus: idle wartet auf eingehende Datensätze, dispose beendet Synchronisation und Controller', () async {
      final c = build(contacts: store, enabled: true)!;
      c.start();
      final other = server.newDevice();
      await other.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
      await other.publishContactRecord(Contact(id: '@carla:example.org', state: ContactState.accepted, version: 1, updatedAt: server.now()));
      await c.idle();
      expect(await store.get(ContactKind.contact, '@carla:example.org'), isNotNull, reason: 'idle wartet auf die Verarbeitung');
      // ignore: invalid_use_of_protected_member
      expect(gateway.hasListeners, isTrue);
      c.dispose();
      // ignore: invalid_use_of_protected_member
      expect(gateway.hasListeners, isFalse, reason: 'dispose beendet die Synchronisation');
    });

    test('Reihenfolge: Start erst Synchronisation, dann Controller; Ende erst Controller, dann Synchronisation (Textwächter)', () {
      final t = File('lib/app/contact_factory.dart').readAsStringSync();
      expect(t.indexOf('sync.start();'), lessThan(t.indexOf('controller.start();')));
      expect(t.indexOf('controller.dispose();'), lessThan(t.indexOf('sync.dispose();')));
    });
  });

  group('App-Dienste', () {
    test('ohne Freigabe entsteht kein Dienst (auch nach dem Öffnen der Familiendienste)', () async {
      final app = await buildTestApp();
      addTearDown(app.services.closeCalendar);
      await app.services.openCalendar();
      expect(app.services.calendar, isNotNull);
      expect(app.services.contacts, isNull);
      expect(app.contactStore, isNull);
    });

    test('mit Freigabe öffnet openCalendar die Kontakt-Dienste einmal je Konto; idempotent', () async {
      final app = await buildTestApp(contactsEnabled: true);
      addTearDown(() {
        app.services.closeCalendar();
        app.services.closeContacts();
      });
      await app.services.openCalendar();
      final first = app.services.contacts;
      expect(first, isNotNull);
      app.services.openContacts(app.gateway.userId!);
      expect(identical(app.services.contacts, first), isTrue);
    });

    test('der Dienst überlebt den Familienwechsel: kein Neuaufbau, kein Schließen', () async {
      final app = await buildTestApp(contactsEnabled: true);
      addTearDown(() {
        app.services.closeCalendar();
        app.services.closeContacts();
      });
      await app.services.openCalendar();
      final first = app.services.contacts!;
      final roomA = app.services.openFamilyRoom!;
      final roomB = app.server.addFamilyRoom('Familie B', app.gateway.userId!).id;
      app.services.closeCalendar(); // wie beim Wechsel: AppRoot schließt, HomeShell öffnet neu
      expect(identical(app.services.contacts, first), isTrue, reason: 'closeCalendar schließt die Kontakt-Dienste nicht');
      app.gateway.attachFamilyRoom(roomB);
      await app.services.openCalendar();
      expect(app.services.openFamilyRoom, roomB);
      expect(roomB, isNot(roomA));
      expect(identical(app.services.contacts, first), isTrue, reason: 'kein Neuaufbau beim Familienwechsel');
      // ignore: invalid_use_of_protected_member
      expect(app.gateway.hasListeners, isTrue, reason: 'der Dienst läuft weiter');
    });

    test('closeContacts beendet Controller und Synchronisation (idle beim Abmelden) und lässt beim zweiten Aufruf nichts zurück', () async {
      final app = await buildTestApp(contactsEnabled: true);
      addTearDown(app.services.closeCalendar);
      await app.services.openCalendar();
      await app.services.contacts!.sync.idle();
      app.services.closeCalendar();
      // ignore: invalid_use_of_protected_member
      expect(app.gateway.hasListeners, isTrue, reason: 'Kontakt-Dienste lauschen noch');
      app.services.closeContacts();
      app.services.closeContacts();
      expect(app.services.contacts, isNull);
      // ignore: invalid_use_of_protected_member
      expect(app.gateway.hasListeners, isFalse);
    });

    test('Abmelden schließt die Kontakt-Dienste vor wipeAccountData', () async {
      final app = await buildTestApp(contactsEnabled: true);
      addTearDown(app.services.closeCalendar);
      await app.services.openCalendar();
      expect(app.services.contacts, isNotNull);
      bool? closedAtWipe;
      bool? listeningAtWipe;
      app.services.debugWipeAccountData = () async {
        closedAtWipe = app.services.contacts == null;
        // ignore: invalid_use_of_protected_member
        listeningAtWipe = app.gateway.hasListeners;
      };
      app.services.closeCalendar(cancelReminders: true);
      await app.services.wipeAccountData();
      expect(closedAtWipe, isTrue);
      expect(listeningAtWipe, isFalse, reason: 'kein Dienst hört beim Löschen noch zu');
    });

    test('blockedUsers-Wiederherstellung nach dem Anspruch der Familiendaten, auch für einen Besitzer ohne Familie', () async {
      final contacts = MemoryContactStore();
      final blocked = MemoryBlockedList(<String>['@alt:fake.test']);
      await ContactService(store: contacts, myUserId: '@anna:fake.test').block('@ben:fake.test');
      late TestApp app;
      String? claimedOwner;
      app = await buildTestApp(
        loggedIn: false,
        contactsEnabled: true,
        contactItems: contacts,
        contactBlocked: blocked,
        // Wie `bootstrap`: Ein Kontowechsel/Anspruch räumt die lokale Blockierliste; die Kontakt-Datensätze bleiben.
        familyDataClaim: (owner) async {
          claimedOwner = owner;
          blocked.list.clear();
        },
      );
      addTearDown(() {
        app.services.closeCalendar();
        app.services.closeContacts();
      });
      await app.gateway.login(server: ServerUrl.tryParse(app.server.host)!, username: 'anna', password: 'geheim123');
      expect(app.gateway.family, isNull, reason: 'Besitzer ohne Familie');
      await app.services.openCalendar();
      expect(claimedOwner, endsWith('|'), reason: 'Besitz ohne Familie: Raumteil leer');
      await app.services.contacts!.sync.idle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await app.services.contacts!.sync.idle();
      expect(blocked.list, <String>['@ben:fake.test'], reason: 'aus den blocked-Datensätzen wiederhergestellt, nach dem Anspruch');
    });
  });

  test('Wächter: kein Verbraucher liest die Kontakt-Dienste noch über den Kalender', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final t = f.readAsStringSync();
      if (RegExp(r'calendar\??\.\s*contact(Controller|Sync)').hasMatch(t)) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
    final cc = File('lib/features/calendar/calendar_controller.dart').readAsStringSync();
    expect(cc, isNot(contains('contactSync')));
    expect(cc, isNot(contains('contactController')));
    expect(File('lib/app/calendar_factory.dart').readAsStringSync(), isNot(contains('Contact')));
  });
}
