import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quelltextprüfung der Anmeldesitzung auf iOS und macOS (#268, E-91). Übersetzt wird der Swift-Code im
/// CI-Job `apple` (`.github/workflows/dart.yml`); das Verhalten belegt nur das Gerät.
void main() {
  const channel = 'de.inneso.familynexus/webauth';
  final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final mac = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
  final swift = <String, String>{'AppDelegate.swift': ios, 'MainFlutterWindow.swift': mac};

  /// Rumpf der Swift-Funktion [name] (bis zur nächsten Deklaration auf derselben Ebene).
  String body(String src, String name) {
    final start = src.indexOf('private func $name(');
    expect(start, greaterThanOrEqualTo(0), reason: name);
    final end = src.indexOf(RegExp(r'\n  (?:private |override )?(?:func|var|let|// MARK)|\n}'), start + 1);
    return src.substring(start, end < 0 ? src.length : end);
  }

  test('Kanalname ist in Dart, iOS und macOS identisch', () {
    expect(File('lib/data/platform/web_auth_session.dart').readAsStringSync(), contains("'$channel'"));
    for (final e in swift.entries) {
      expect(e.value, contains('"$channel"'), reason: e.key);
    }
  });

  test('ephemere Sitzung, nur https, Schema mit #available', () {
    for (final e in swift.entries) {
      expect(e.value, contains('import AuthenticationServices'), reason: e.key);
      expect(e.value, contains('prefersEphemeralWebBrowserSession = true'), reason: e.key);
      expect(e.value, contains('target.scheme?.lowercased() == "https"'), reason: e.key);
      expect(e.value, contains('.customScheme('), reason: e.key);
      expect(e.value, contains('DispatchQueue.main.async'), reason: e.key);
    }
    expect(ios, contains('#available(iOS 17.4, *)'));
    expect(mac, contains('#available(macOS 14.4, *)'));
  });

  test('iOS: kein Sichtschutz über dem Anmeldeblatt', () {
    expect(ios, contains('guard secure, cover == nil, current == nil, let window = keyWindow else { return }'));
  });

  test('current = nil steht vor .cancel() (cancel und Ersetzen in start), damit ended nur einmal kommt', () {
    for (final e in swift.entries) {
      for (final name in <String>['webAuthStart', 'webAuthCancel']) {
        final b = body(e.value, name);
        final reset = b.indexOf('current = nil');
        final cancel = b.indexOf('.cancel()');
        expect(cancel, greaterThan(0), reason: '${e.key} $name');
        expect(reset, inInclusiveRange(0, cancel), reason: '${e.key} $name: current = nil vor .cancel()');
      }
    }
  });

  test('macOS: network.server nur noch im Debug (kein Loopback im Release)', () {
    expect(File('macos/Runner/Release.entitlements').readAsStringSync(), isNot(contains('com.apple.security.network.server')));
    expect(File('macos/Runner/DebugProfile.entitlements').readAsStringSync(), contains('com.apple.security.network.server'));
  });
}
