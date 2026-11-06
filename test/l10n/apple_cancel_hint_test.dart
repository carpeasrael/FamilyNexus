import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #297: Die Hinweise zum Schließen der Anbieterseite über „Abbrechen“ (ASWebAuthenticationSession, E-91)
/// nennen alle Apple-Geräte mit dieser Sitzung, seit E-92 auch das iPad.
void main() {
  Map<String, dynamic> arb(String name) =>
      json.decode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;

  const devices = <String, String>{'app_de': 'iPhone, iPad und Mac', 'app_en': 'iPhone, iPad and Mac'};
  final withoutIpad = RegExp(r'iPhone (und|and) Mac');

  for (final MapEntry(key: name, value: phrase) in devices.entries) {
    test('$name: regCaptchaBody und accountDeleteBrowserWait nennen „$phrase“', () {
      final values = arb(name);
      for (final key in ['regCaptchaBody', 'accountDeleteBrowserWait']) {
        expect(values[key], isA<String>(), reason: key);
        expect(values[key] as String, contains(phrase), reason: key);
      }
    });

    test('$name: kein Text nennt nur „iPhone und Mac“ ohne iPad', () {
      final offenders = <String>[
        for (final e in arb(name).entries)
          if (!e.key.startsWith('@') && e.value is String && withoutIpad.hasMatch(e.value as String)) e.key,
      ];
      expect(offenders, isEmpty);
    });
  }
}
