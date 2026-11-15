import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #297, angepasst für #441 (E-102): Die Hinweise zum Schließen der Anbieterseite nannten die „Abbrechen“-Taste der
/// Anmeldesitzung des Systems (E-91, seit E-92 auch iPad). Auf iOS, macOS und Android zeigt die App die Seite jetzt
/// in einer eingebetteten Ansicht, die Kontoseiten und Captcha mit „Fertig“ schließt; im Browser (Linux, Windows,
/// Rückfall) schließt man das Fenster. Die Hinweise nennen deshalb diese beiden Wege und tragen den echten Wortlaut
/// der Schaltfläche (`embeddedDone`), damit Hinweis und Schaltfläche nicht auseinanderlaufen.
void main() {
  Map<String, dynamic> arb(String name) =>
      json.decode(File('lib/l10n/$name.arb').readAsStringSync()) as Map<String, dynamic>;

  const phrases = <String, String>{
    'app_de': 'in der App über „Fertig“, im Browser einfach das Fenster',
    'app_en': 'in the app with “Done”, in the browser simply the window',
  };
  final withoutIpad = RegExp(r'iPhone (und|and) Mac');

  for (final MapEntry(key: name, value: phrase) in phrases.entries) {
    test('$name: regCaptchaBody und accountDeleteBrowserWait nennen „$phrase“', () {
      final values = arb(name);
      for (final key in ['regCaptchaBody', 'accountDeleteBrowserWait']) {
        expect(values[key], isA<String>(), reason: key);
        expect(values[key] as String, contains(phrase), reason: key);
      }
    });

    test('$name: die genannte Schaltfläche heißt wirklich so (embeddedDone)', () {
      final values = arb(name);
      expect(phrase, contains(values['embeddedDone'] as String));
    });

    test('$name: kein Text nennt die „Abbrechen“-Taste der Systemsitzung („auf iPhone, iPad und Mac“)', () {
      final offenders = <String>[
        for (final e in arb(name).entries)
          if (!e.key.startsWith('@') && e.value is String && RegExp(r'(auf|on) iPhone, iPad (und|and) Mac').hasMatch(e.value as String)) e.key,
      ];
      expect(offenders, isEmpty);
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
