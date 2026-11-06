import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #296: Die Store-Datenschutzerklärung muss die Meldungen zu Chat und Einkauf und die Zahl am App-Symbol nennen
/// (E-88), wie die In-App-Fassung (`privacy5Body`). Der Paritätstest vergleicht nur de gegen en, nicht Store gegen App.
///
/// Geprüft werden feste Begriffe, nicht die Bedeutungstreue; der Wortlaut des Textes bleibt Sache der Freigabe.
void main() {
  String read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

  /// Text von `## 6.` bis vor `## 7.`.
  String section6(String text) {
    final start = RegExp(r'^## 6\.', multiLine: true).firstMatch(text)!.start;
    final end = RegExp(r'^## 7\.', multiLine: true).firstMatch(text)!.start;
    return text.substring(start, end);
  }

  /// Absatz, der mit [marker] beginnt (bis zur Leerzeile).
  String paragraph(String text, String marker) {
    final start = text.indexOf(marker);
    expect(start, isNonNegative, reason: 'Absatz „$marker“ fehlt');
    final end = text.indexOf('\n\n', start);
    return text.substring(start, end < 0 ? text.length : end);
  }

  String tableRow(String section, String firstCell) =>
      section.split('\n').firstWhere((l) => l.startsWith('| $firstCell |'), orElse: () => fail('Zeile „$firstCell“ fehlt'));

  final langs = <String, Map<String, Object>>{
    'de': {
      'file': 'store/privacy/privacy-policy.de.md',
      'arb': 'lib/l10n/app_de.arb',
      // Nur im Store-Text (die In-App-Fassung sagt „solange sie läuft“).
      'store': ['solange die App läuft', 'abschalten'],
      // Muss in `privacy5Body` UND im Store-Abschnitt 6 stehen.
      'shared': ['Neue Nachrichten', 'Einkaufszettel', 'ohne Absender', 'App-Symbol'],
      'cell': 'Benachrichtigungen',
      'row': 'Einkaufseinträge',
      'signout': '**Abmelden:**',
      'signoutWord': 'Meldungen',
    },
    'en': {
      'file': 'store/privacy/privacy-policy.en.md',
      'arb': 'lib/l10n/app_en.arb',
      'store': ['while the app is running', 'switched off'],
      'shared': ['New messages', 'shopping list', 'without sender', 'app icon'],
      'cell': 'Notifications',
      'row': 'shopping items',
      'signout': '**Signing out:**',
      'signoutWord': 'notifications',
    },
  };

  for (final entry in langs.entries) {
    final lang = entry.key;
    final cfg = entry.value;
    final text = read(cfg['file']! as String);
    final s6 = section6(text);
    final arb = jsonDecode(read(cfg['arb']! as String)) as Map<String, dynamic>;

    group('Store-Datenschutz ($lang), #296', () {
      test('Abschnitt 6 nennt die Meldungen zu Chat und Einkauf und die Zahl am App-Symbol', () {
        for (final term in [...(cfg['store']! as List<String>), ...(cfg['shared']! as List<String>)]) {
          expect(s6, contains(term), reason: 'Abschnitt 6 ($lang) fehlt: $term');
        }
      });

      test('Begriffe der In-App-Fassung (privacy5Body) stehen auch im Store-Abschnitt 6', () {
        final body = arb['privacy5Body']! as String;
        for (final term in cfg['shared']! as List<String>) {
          expect(body, contains(term), reason: 'privacy5Body ($lang) enthält nicht mehr: $term (Testliste anpassen)');
          expect(s6, contains(term), reason: 'Store-Abschnitt 6 ($lang) fehlt: $term');
        }
      });

      test('Tabellenzeile „Benachrichtigungen“ nennt Einkaufseinträge, nicht nur Terminerinnerungen', () {
        expect(tableRow(s6, cfg['cell']! as String), contains(cfg['row']! as String));
      });

      test('Abmelden-Absatz nennt auch die Meldungen', () {
        expect(paragraph(text, cfg['signout']! as String), contains(cfg['signoutWord']! as String));
      });
    });
  }
}
