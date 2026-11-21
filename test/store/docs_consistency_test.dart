import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #505: Dokumente und Entscheidungen bleiben beieinander.
void main() {
  final decisions = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();

  test('ENTSCHEIDUNGEN.md hält die Entscheidung zu #485 fest (Nachtrag zu E-102)', () {
    final e102 = RegExp(r'## E-102 .*?(?=\n## E-\d+ |$)', dotAll: true).firstMatch(decisions)!.group(0)!;
    expect(e102, contains('#485'));
  });

  test('„Gesprächsleiste“ gilt nicht mehr als Gegenwartsbegriff (E-100 ersetzt sie)', () {
    expect(File('docs/KONTAKTE.md').readAsStringSync(), isNot(contains('Gesprächsleiste')));
    for (final line in decisions.split('\n').where((l) => l.contains('Gesprächsleiste'))) {
      expect(line, contains('E-100'), reason: 'nur als historischer Verweis auf E-100: $line');
    }
  });

  test('E-95 beschreibt „Überspringen“ der Tour genau (#502): nicht auf dem letzten Schritt', () {
    final e95 = RegExp(r'## E-95 .*?(?=\n## E-\d+ |$)', dotAll: true).firstMatch(decisions)!.group(0)!;
    expect(e95, isNot(contains('Überspringen jederzeit')));
    expect(e95, contains('#502'));
  });

  test('E-55 verweist auf den Schritt „Anbieter wählen“ (#545, E-108), E-108 nennt den Merker und das Zurücksetzen', () {
    final e55 = RegExp(r'## E-55 .*?(?=\n## E-\d+ |$)', dotAll: true).firstMatch(decisions)!.group(0)!;
    expect(e55, contains('E-108'));
    expect(e55, contains('#545'));
    final e108 = RegExp(r'## E-108 .*?(?=\n## E-\d+ |$)', dotAll: true).firstMatch(decisions)!.group(0)!;
    expect(e108, contains('_withServerStep'));
    expect(e108, contains('resetToStandard'));
    expect(e108, contains('ändert E-55'));
  });

  test('README nennt Geburts- und Gedenktage und die öffentliche Lesebestätigung (#578, E-104, E-106)', () {
    // Whitespace normalisieren, Markdown-Sternchen entfernen, ohne Groß-/Kleinschreibung vergleichen.
    final readme = File('README.md')
        .readAsStringSync()
        .replaceAll('*', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    for (final term in <String>[
      'birthdays and memorial days',
      'read receipts',
      'on by default',
      'Settings → Privacy → Send read receipts',
      'not end-to-end encrypted',
      'cannot be taken back',
    ]) {
      expect(readme, contains(term.toLowerCase()), reason: 'README.md nennt "$term" nicht');
    }
  });
}
