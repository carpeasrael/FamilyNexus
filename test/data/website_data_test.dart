import 'dart:async';

import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/data/platform/website_data.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_stores.dart';
import '../support/test_app.dart';

/// #486: Website-Datenspeicher der Systemansicht (iOS, macOS) über den Fensterkanal löschen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('de.inneso.familynexus/window');
  late List<String> calls;

  void mock(Future<Object?>? Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return handler(call);
    });
  }

  setUp(() => calls = <String>[]);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  group('ChannelWebsiteData', () {
    test('iOS und macOS senden clearWebsiteData', () async {
      mock((_) async => null);
      await const ChannelWebsiteData(platform: TargetPlatform.iOS, isWeb: false).clear();
      await const ChannelWebsiteData(platform: TargetPlatform.macOS, isWeb: false).clear();
      expect(calls, <String>['clearWebsiteData', 'clearWebsiteData']);
    });

    test('Android, Linux, Windows und Browser senden nichts', () async {
      mock((_) async => null);
      for (final p in <TargetPlatform>[TargetPlatform.android, TargetPlatform.linux, TargetPlatform.windows, TargetPlatform.fuchsia]) {
        await ChannelWebsiteData(platform: p, isWeb: false).clear();
      }
      // Im Browser meldet `defaultTargetPlatform` iOS oder macOS: trotzdem nichts senden.
      await const ChannelWebsiteData(platform: TargetPlatform.iOS, isWeb: true).clear();
      expect(calls, isEmpty);
    });

    test('Kanalfehler und fehlender Adapter werfen nicht', () async {
      mock((_) async => throw PlatformException(code: 'x'));
      await const ChannelWebsiteData(platform: TargetPlatform.iOS, isWeb: false).clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      await const ChannelWebsiteData(platform: TargetPlatform.macOS, isWeb: false).clear();
      expect(calls, <String>['clearWebsiteData']);
    });

  });

  group('resetLocalData', () {
    test('löscht den Website-Datenspeicher (iOS), vor dem Löschen der Datenbanken', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      mock((_) async => null);
      final order = <String>[];
      await resetLocalData(
        keyStore: MemoryKeyStore(),
        files: FakeFileAccess(),
        destroyAll: () async => order.add('destroyAll:${calls.length}'),
      );
      expect(calls, <String>['clearWebsiteData']);
      expect(order, <String>['destroyAll:1'], reason: 'der Aufruf kam vor dem Löschen der Daten');
    });

    test('Android sendet nichts', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mock((_) async => null);
      await resetLocalData(keyStore: MemoryKeyStore(), files: FakeFileAccess(), destroyAll: () async {});
      expect(calls, isEmpty);
    });
  });

  testWidgets('ein stummer Kanal hält clear() höchstens kWebsiteDataTimeout auf', (tester) async {
    mock((_) => Completer<Object?>().future);
    var done = false;
    unawaited(const ChannelWebsiteData(platform: TargetPlatform.iOS, isWeb: false).clear().then((_) => done = true));
    await tester.pump(kWebsiteDataTimeout - const Duration(milliseconds: 1));
    expect(done, isFalse, reason: 'vor Ablauf der Frist noch offen');
    await tester.pump(const Duration(milliseconds: 2));
    expect(done, isTrue, reason: 'nach der Frist zurück, ohne Wurf');
  });

  testWidgets('ein stummer Kanal blockiert das lokale Löschen höchstens kWebsiteDataTimeout', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    mock((_) => Completer<Object?>().future);
    var destroyed = false;
    try {
      unawaited(resetLocalData(keyStore: MemoryKeyStore(), files: FakeFileAccess(), destroyAll: () async => destroyed = true));
      await tester.pump(kWebsiteDataTimeout - const Duration(milliseconds: 1));
      expect(destroyed, isFalse);
      await tester.pump(const Duration(milliseconds: 2));
      expect(destroyed, isTrue, reason: 'die lokale Löschung läuft trotz hängendem Aufruf weiter');
    } finally {
      // Die Bindung prüft die Debug-Variablen vor dem tearDown.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
