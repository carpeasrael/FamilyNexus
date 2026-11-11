import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/security.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/settings/settings_actions.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_matrix.dart';
import '../support/memory_stores.dart';
import '../support/test_app.dart';

/// AP-6a: Die Aktionen der Einstellungen, ohne Widget. Der Zustand selbst liegt im `SettingsController`.
class _Setup {
  _Setup(this.server, this.gateway, this.settings, this.store);
  final FakeMatrixServer server;
  final FakeMatrixGateway gateway;
  final SettingsController settings;
  final MemoryKeyValueStore store;
  final List<String> log = <String>[];
  late SettingsActions actions;
}

Future<_Setup> _setup({bool withCallbacks = true, LocalDataInventory? inventory}) async {
  final server = FakeMatrixServer()
    ..addAccount('anna', 'geheim123', displayName: 'Anna')
    ..addAccount('ben', 'geheim456', displayName: 'Ben');
  final gateway = server.newDevice();
  await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'geheim123');
  final store = MemoryKeyValueStore();
  final s = _Setup(server, gateway, SettingsController(store), store);
  s.actions = SettingsActions(
    settings: s.settings,
    gateway: gateway,
    inventory: inventory,
    requestNotifications: withCallbacks
        ? () async => s.log.add('berechtigung(gespeichert: chat=${s.store.data['notifyChat']}, einkauf=${s.store.data['notifyShopping']})')
        : null,
    reschedule: withCallbacks ? () async => s.log.add('planen') : null,
  );
  return s;
}

void main() {
  group('Standard-Erinnerungen', () {
    test('einschalten ergänzt die Minute, gespeichert wird absteigend sortiert', () async {
      final s = await _setup();
      final start = s.settings.settings.defaultReminderMinutes;
      await s.actions.setDefaultReminder(5, on: true);
      await s.actions.setDefaultReminder(1440, on: true);
      final now = s.settings.settings.defaultReminderMinutes;
      expect(now, containsAll(<int>[5, 1440, ...start]));
      expect(now, orderedEquals(<int>[...now]..sort((a, b) => b.compareTo(a))), reason: 'absteigend');
    });

    test('ausschalten entfernt die Minute, die übrigen bleiben', () async {
      final s = await _setup();
      await s.actions.setDefaultReminder(5, on: true);
      await s.actions.setDefaultReminder(30, on: true);
      await s.actions.setDefaultReminder(5, on: false);
      expect(s.settings.settings.defaultReminderMinutes, contains(30));
      expect(s.settings.settings.defaultReminderMinutes, isNot(contains(5)));
    });

    test('dieselbe Minute zweimal einschalten ändert nichts', () async {
      final s = await _setup();
      await s.actions.setDefaultReminder(15, on: true);
      final once = List<int>.of(s.settings.settings.defaultReminderMinutes);
      await s.actions.setDefaultReminder(15, on: true);
      expect(s.settings.settings.defaultReminderMinutes, once);
    });

    test('alle ausschalten ergibt eine leere Liste', () async {
      final s = await _setup();
      for (final m in List<int>.of(s.settings.settings.defaultReminderMinutes)) {
        await s.actions.setDefaultReminder(m, on: false);
      }
      expect(s.settings.settings.defaultReminderMinutes, isEmpty);
    });
  });

  group('Meldungen zu Chat und Einkauf', () {
    test('Chat einschalten: erst speichern, dann Berechtigung anfragen, dann neu planen', () async {
      final s = await _setup();
      await s.actions.setNotifyChat(on: false); // Standard ist „an“: erst ausschalten
      s.log.clear();
      await s.actions.setNotifyChat(on: true);
      expect(s.settings.settings.notifyChat, isTrue);
      expect(s.log, <String>['berechtigung(gespeichert: chat=true, einkauf=${s.store.data['notifyShopping']})', 'planen']);
    });

    test('Einkauf einschalten: dieselbe Reihenfolge', () async {
      final s = await _setup();
      await s.actions.setNotifyShopping(on: false);
      s.log.clear();
      await s.actions.setNotifyShopping(on: true);
      expect(s.settings.settings.notifyShopping, isTrue);
      expect(s.log, <String>['berechtigung(gespeichert: chat=${s.store.data['notifyChat']}, einkauf=true)', 'planen']);
    });

    test('ausschalten speichert nur: keine Anfrage, keine neue Planung', () async {
      final s = await _setup();
      await s.actions.setNotifyChat(on: false);
      expect(s.settings.settings.notifyChat, isFalse);
      expect(s.log, isEmpty);
    });

    test('ohne Plattform-Meldungen (Rückrufe fehlen): speichert, ohne Fehler', () async {
      final s = await _setup(withCallbacks: false);
      await s.actions.setNotifyChat(on: false);
      await s.actions.setNotifyShopping(on: false);
      await s.actions.setNotifyChat(on: true);
      await s.actions.setNotifyShopping(on: true);
      expect(s.settings.settings.notifyChat, isTrue);
      expect(s.settings.settings.notifyShopping, isTrue);
    });

    test('der eine Schalter lässt den anderen unberührt', () async {
      final s = await _setup();
      await s.actions.setNotifyChat(on: false);
      expect((s.settings.settings.notifyChat, s.settings.settings.notifyShopping), (false, true));
    });
  });

  group('Speicherorte', () {
    test('ohne Bestandsabfrage (Browser) gibt es nichts', () async {
      final s = await _setup();
      expect(s.actions.storageLocations(), isNull);
    });

    test('mit Bestandsabfrage: die Orte kommen von dort', () async {
      final s = await _setup(inventory: FakeLocalDataInventory());
      final loc = await s.actions.storageLocations()!;
      expect(loc.appDatabase, isNotEmpty);
    });
  });

  group('Gerätesicherheit', () {
    test('refreshSecurity wirft nicht', () async {
      final s = await _setup();
      s.actions.refreshSecurity();
    });

    test('verifyDevice: unbekanntes Gerät ergibt den Fehler des Gateways', () async {
      final s = await _setup();
      final error = await s.actions.verifyDevice(const DeviceEntry(userId: '@niemand:fake.test', deviceId: 'X', name: 'X', verified: false, isCurrent: false));
      expect(error, isA<GatewayException>());
      expect((error! as GatewayException).error, GatewayError.notFound);
    });

    test('verifyDevice: vorhandenes zweites Gerät startet die Verifizierung, ohne Fehler', () async {
      final s = await _setup();
      final second = s.server.newDevice();
      await second.login(server: ServerUrl.tryParse(s.server.host)!, username: 'anna', password: 'geheim123');
      final device = s.gateway.devices.firstWhere((d) => !d.isCurrent);
      expect(await s.actions.verifyDevice(device), isNull);
      expect(s.server.verification, isNotNull);
    });

    test('verifyDevice: läuft schon eine Verifizierung, kommt der Fehler zurück statt zu werfen', () async {
      final s = await _setup();
      final second = s.server.newDevice();
      await second.login(server: ServerUrl.tryParse(s.server.host)!, username: 'anna', password: 'geheim123');
      final device = s.gateway.devices.firstWhere((d) => !d.isCurrent);
      await s.actions.verifyDevice(device);
      final again = await s.actions.verifyDevice(device);
      expect((again! as GatewayException).error, GatewayError.alreadyExists);
    });
  });
}
