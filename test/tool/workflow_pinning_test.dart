import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #568: Jede Action in `.github/workflows/` ist auf eine Commit-SHA festgenagelt, der Tag steht als Kommentar
/// dahinter (`uses: owner/repo@<40 Hex> # v6`). Ein beweglicher Tag ließe fremden Code ungeprüft in `release.yml`
/// laufen (semgrep: github-actions-mutable-action-tag). Dependabot hält die SHAs aktuell.
final _uses = RegExp(r'''^\s*(?:-\s+)?uses:\s*['"]?([^\s'"#]+)['"]?\s*(?:#\s*(\S+))?''');
final _sha = RegExp(r'^[^@]+@[0-9a-f]{40}$');

/// Liefert je Verstoß eine Beschreibung mit Zeilennummer; lokale Actions (`./…`) und Kommentarzeilen zählen nicht.
List<String> pinningViolations(String yaml) {
  final out = <String>[];
  final lines = yaml.split('\n');
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('#')) continue;
    final m = _uses.firstMatch(lines[i]);
    if (m == null) continue;
    final ref = m.group(1)!;
    if (ref.startsWith('./')) continue;
    if (!_sha.hasMatch(ref)) {
      out.add('Zeile ${i + 1}: "$ref" ist nicht auf eine Commit-SHA festgenagelt');
    } else if (m.group(2) == null || !m.group(2)!.startsWith('v')) {
      out.add('Zeile ${i + 1}: "$ref" ohne Tag-Kommentar (# v…)');
    }
  }
  return out;
}

void main() {
  const sha = 'd23441a48e516b6c34aea4fa41551a30e30af803';

  group('pinningViolations erkennt Verstöße (Selbsttest)', () {
    test('Tag statt SHA', () {
      expect(pinningViolations('      - uses: actions/checkout@v6\n'), hasLength(1));
    });

    test('Zweig statt SHA, ohne Listenstrich und mit Anführungszeichen', () {
      expect(pinningViolations('  uses: "actions/cache@main"\n'), hasLength(1));
    });

    test('SHA ohne Tag-Kommentar', () {
      expect(pinningViolations('      - uses: actions/checkout@$sha\n'), hasLength(1));
    });

    test('zu kurze SHA', () {
      expect(pinningViolations('      - uses: actions/checkout@d23441a # v6\n'), hasLength(1));
    });

    test('SHA mit Tag-Kommentar ist in Ordnung', () {
      expect(pinningViolations('      - uses: actions/checkout@$sha # v6\n'), isEmpty);
    });

    test('lokale Action und Kommentarzeile zählen nicht', () {
      expect(pinningViolations('      - uses: ./.github/actions/x\n      # uses: actions/checkout@v6\n'), isEmpty);
    });
  });

  group('.github/workflows', () {
    final files = Directory('.github/workflows')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    test('Workflows gefunden', () => expect(files, isNotEmpty));

    for (final f in files) {
      test('${f.uri.pathSegments.last}: alle Actions auf Commit-SHA festgenagelt', () {
        expect(pinningViolations(f.readAsStringSync()), isEmpty);
      });
    }
  });

  test('dependabot.yml hält die GitHub-Actions aktuell', () {
    final f = File('.github/dependabot.yml');
    expect(f.existsSync(), isTrue, reason: '.github/dependabot.yml fehlt');
    expect(f.readAsStringSync(), matches(RegExp(r'''package-ecosystem:\s*['"]?github-actions['"]?''')));
  });
}
