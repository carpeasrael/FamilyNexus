import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #147: Die englische Datenschutzerklärung ist eine Übersetzung der deutschen (Deutsch ist maßgeblich). Der Test
/// sichert nur die **Struktur** (Abschnitte, Tabellen, Listenpunkte, Adressen, Zahlen), nicht die Bedeutungstreue:
/// Die Übersetzung muss vor einer Veröffentlichung gelesen und freigegeben werden.
void main() {
  final de = File('store/privacy/privacy-policy.de.md').readAsStringSync();
  final en = File('store/privacy/privacy-policy.en.md').readAsStringSync();

  /// Text je Abschnitt `## n. …` (Schlüssel: Nummer); der Kopf vor dem ersten Abschnitt hat die Nummer 0.
  Map<int, List<String>> sections(String text) {
    final out = <int, List<String>>{0: <String>[]};
    var current = 0;
    for (final line in text.split('\n')) {
      final m = RegExp(r'^## (\d+)\.').firstMatch(line);
      if (m != null) {
        current = int.parse(m.group(1)!);
        out[current] = <String>[line];
      } else {
        out[current]!.add(line);
      }
    }
    return out;
  }

  int count(List<String> lines, RegExp re) => lines.where(re.hasMatch).length;
  final table = RegExp(r'^\|');
  final bullet = RegExp(r'^\s*[-*] ');
  Iterable<String> tokens(String text, RegExp re) => re.allMatches(text).map((m) => m.group(0)!);
  List<String> sorted(Iterable<String> i) => i.toList()..sort();

  final sd = sections(de);
  final se = sections(en);

  test('gleiche Abschnitte in gleicher Reihenfolge', () {
    expect(sd.keys.where((k) => k > 0).length, 14);
    expect(se.keys.toList(), sd.keys.toList());
  });

  test('je Abschnitt gleich viele Tabellenzeilen und Aufzählungspunkte', () {
    for (final k in sd.keys) {
      expect(count(se[k]!, table), count(sd[k]!, table), reason: 'Abschnitt $k: Tabellenzeilen');
      expect(count(se[k]!, bullet), count(sd[k]!, bullet), reason: 'Abschnitt $k: Aufzählungspunkte');
    }
  });

  test('gleiche Anzahl Absätze und fetter Passagen je Abschnitt', () {
    int paragraphs(List<String> l) {
      var n = 0;
      var inParagraph = false;
      for (final line in l.skip(1)) {
        final text = line.trim().isNotEmpty && !table.hasMatch(line) && !bullet.hasMatch(line);
        if (text && !inParagraph) n++;
        inParagraph = text;
      }
      return n;
    }

    int bold(List<String> l) => RegExp(r'\*\*[^*]+\*\*').allMatches(l.join('\n')).length;
    for (final k in sd.keys) {
      // Im Kopf (Abschnitt 0) hat die Übersetzung genau einen zusätzlichen, fett gesetzten Hinweisabsatz.
      final extra = k == 0 ? 1 : 0;
      expect(paragraphs(se[k]!), paragraphs(sd[k]!) + extra, reason: 'Abschnitt $k: Absätze');
      expect(bold(se[k]!), bold(sd[k]!) + extra, reason: 'Abschnitt $k: fette Passagen');
    }
  });

  test('gleiche E-Mail-Adressen, Links und Zahlen', () {
    final mail = RegExp(r'[\w.+-]+@[\w-]+(\.[\w-]+)+');
    expect(sorted(tokens(en, mail)), sorted(tokens(de, mail)));
    // Linkziele: Gesetzes- und Rechtstexte dürfen in der Sprache der Leser verlinkt sein (z. B. EUR-Lex DE/EN).
    String normalize(String u) => u.replaceAll(RegExp(r'/(DE|EN)/TXT'), '/XX/TXT').replaceAll(RegExp(r'[.,;:]+$'), '');
    final url = RegExp(r'https?://[^)\s>`]+');
    expect(sorted(tokens(en, url).map(normalize)), sorted(tokens(de, url).map(normalize)));
    // Ziffernfolgen (ohne Datumsformat-Unterschiede „31. Oktober 2026“ / „31 October 2026“, beide enthalten 31 und 2026).
    final numbers = RegExp(r'\d+');
    expect(sorted(tokens(en, numbers)), sorted(tokens(de, numbers)));
  });

  test('Kopf: Hinweis auf die Übersetzung, Stand, keine Platzhalter und keine Altaussagen', () {
    expect(en, contains('translation of the German original'));
    expect(en, contains('prevails'));
    expect(en, contains('31 October 2026'));
    expect(en, isNot(contains('<NAME')));
    expect(RegExp(r'^<[A-ZÄÖÜ]', multiLine: true).hasMatch(en), isFalse);
    expect(en.toLowerCase(), isNot(contains('recovery key')));
    expect(en, isNot(contains('Use your own server to avoid')));
  });
}
