import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:family_nexus/data/platform/app_badge.dart';
import 'package:family_nexus/data/platform/linux_launcher_badge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('#254: Zahl am App-Symbol', () {
    test('entprellt, nur der letzte Wert; gleiche Werte nicht doppelt; nie negativ', () async {
      final sent = <int>[];
      final b = PlatformAppBadge(
        debounce: const Duration(milliseconds: 20),
        supportedOverride: true,
        sink: (c) async => sent.add(c),
      );
      b
        ..update(1)
        ..update(2)
        ..update(3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent, <int>[3]);
      b.update(3);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent, <int>[3], reason: 'unverändert');
      b.update(-4);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(sent, <int>[3, 0], reason: 'nie negativ');
    });

    test('nicht unterstützt (Android, Browser): nichts', () async {
      final sent = <int>[];
      final b = PlatformAppBadge(debounce: Duration.zero, supportedOverride: false, sink: (c) async => sent.add(c));
      b.update(4);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(sent, isEmpty);
    });

    test('Fehler beim Setzen bleibt folgenlos', () async {
      final b = PlatformAppBadge(debounce: Duration.zero, supportedOverride: true, sink: (_) async => throw StateError('kein Bus'));
      b.update(1);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
  });

  test('#254: Linux sendet LauncherEntry.Update mit Desktop-ID, Zahl und Sichtbarkeit', () async {
    final dir = await Directory.systemTemp.createTemp('fn_dbus');
    final server = DBusServer();
    final address = await server.listenAddress(DBusAddress.unix(dir: dir));
    // dbus 0.8.0 kennt die EXTERNAL-Anmeldung nur unter Linux und Windows und wirft sonst (macOS: Test hängt, #322).
    // Der Testserver prüft die uid nicht; eine feste uid macht den Test plattformunabhängig. Je Client eine eigene Instanz.
    final listener = DBusClient(address, authClient: DBusAuthClient(uid: '1000'));
    final sender = DBusClient(address, authClient: DBusAuthClient(uid: '1000'));
    addTearDown(() async {
      await listener.close();
      await server.close();
      await dir.delete(recursive: true);
    });
    final signals = DBusSignalStream(listener, interface: 'com.canonical.Unity.LauncherEntry', name: 'Update');
    final received = <DBusSignal>[];
    final sub = signals.listen(received.add);
    addTearDown(sub.cancel);
    await listener.ping();
    // Kurz warten, bis die Match-Regel auf dem Bus liegt.
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final badge = LinuxLauncherBadge(client: sender);
    await badge.set(3);
    await badge.set(0);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await badge.close();

    expect(received, hasLength(2));
    expect(received.first.values.first, const DBusString('application://de.inneso.familynexus.desktop'));
    final props = received.first.values[1].asStringVariantDict();
    expect(props['count'], const DBusInt64(3));
    expect(props['count-visible'], const DBusBoolean(true));
    expect(received.last.values[1].asStringVariantDict()['count-visible'], const DBusBoolean(false));
  });
}
