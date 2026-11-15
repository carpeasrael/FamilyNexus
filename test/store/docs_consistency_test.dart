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
}
