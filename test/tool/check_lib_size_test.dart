import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_lib_size.dart';

/// #360: Der Wächter für Dateigröße und `build`-Länge.
String _lines(int n, {bool trailingNewline = true}) => List<String>.generate(n, (i) => '// $i').join('\n') + (trailingNewline ? '\n' : '');

/// Eine Klasse mit einem `build` von genau [n] Zeilen (erste bis letzte Zeile eingeschlossen).
String _blockBuild(int n) {
  final body = List<String>.generate(n - 2, (i) => '    final a$i = $i;').join('\n');
  return 'class A {\n  Widget build(BuildContext context) {\n$body\n  }\n}\n';
}

void main() {
  late Directory dir;
  late Directory lib;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lib_size_');
    lib = Directory('${dir.path}/lib')..createSync();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  File put(String name, String text) => File('${lib.path}/$name')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  group('Dateigröße', () {
    test('genau 1000 Zeilen sind erlaubt, mit und ohne abschließende Zeilenschaltung', () {
      put('a.dart', _lines(1000));
      put('b.dart', _lines(1000, trailingNewline: false));
      expect(checkLibSize(lib).problems, isEmpty);
    });

    test('1001 Zeilen werden gemeldet', () {
      put('a.dart', _lines(1001));
      put('b.dart', _lines(1001, trailingNewline: false));
      final p = checkLibSize(lib).problems;
      expect(p, hasLength(2));
      expect(p.first, contains('a.dart: 1001 Zeilen'));
    });

    test('lib/l10n/gen wird übergangen', () {
      put('l10n/gen/app_localizations.dart', _lines(2000));
      expect(checkLibSize(lib).problems, isEmpty);
    });

    test('Ausnahme unterdrückt die Meldung, eine nicht mehr nötige Ausnahme wird gemeldet', () {
      put('gross.dart', _lines(1001));
      put('klein.dart', _lines(10));
      final r = checkLibSize(lib, exceptions: <String, Set<String>>{
        'gross.dart': <String>{kindFile},
        'klein.dart': <String>{kindFile},
      });
      expect(r.problems, hasLength(1));
      expect(r.problems.single, contains('klein.dart'));
      expect(r.problems.single, contains('nicht mehr nötig'));
    });

    test('Ausnahme für eine Datei, die es nicht gibt, wird gemeldet', () {
      final r = checkLibSize(lib, exceptions: <String, Set<String>>{
        'weg.dart': <String>{kindFile},
      });
      expect(r.problems.single, contains('weg.dart'));
    });
  });

  group('build-Länge', () {
    test('150 Zeilen sind erlaubt, 151 werden gemeldet', () {
      put('a.dart', _blockBuild(150));
      expect(checkLibSize(lib).problems, isEmpty);
      put('b.dart', _blockBuild(151));
      final p = checkLibSize(lib).problems;
      expect(p.single, contains('b.dart:2: build mit 151 Zeilen'));
    });

    test('Ausdruckskörper (=>) wird bis zum Semikolon gezählt', () {
      final inner = List<String>.generate(150, (i) => '    Text("$i"),').join('\n');
      put('lang.dart', 'class A {\n  Widget build(BuildContext context) => Column(\n    children: [\n$inner\n    ],\n  );\n}\n');
      put('kurz.dart', 'class B {\n  Widget build(BuildContext context) => const Text("x");\n  void other() {\n    var a = 1;\n  }\n}\n');
      final p = checkLibSize(lib).problems;
      expect(p, hasLength(1));
      expect(p.single, contains('lang.dart:2: build mit 154 Zeilen'));
    });

    test('Klammern in Strings, Kommentaren, Raw- und Triple-Strings und \${}-Interpolation verfälschen die Länge nicht', () {
      final filler = List<String>.generate(142, (i) => '    final a$i = $i;').join('\n');
      put('a.dart', '''
class A {
  Widget build(BuildContext context) {
    final s = '}';
    final t = "{ \${a.map((e) => '}').join('{')} }";
    final r = r'}}}';
    final m = \'\'\'
}
\'\'\';
    // } in einem Kommentar
    /* } */
$filler
    return const SizedBox();
  }
}
''');
      final p = checkLibSize(lib).problems;
      expect(p, hasLength(1), reason: 'die Methode ist 153 Zeilen lang, ein „}“ in Text darf sie nicht verkürzen');
      expect(p.single, contains('build mit 153 Zeilen'));
    });

    test('mehrere build in einer Datei werden einzeln gezählt', () {
      put('a.dart', '${_blockBuild(160)}${_blockBuild(20)}');
      final p = checkLibSize(lib).problems;
      expect(p, hasLength(1));
      expect(p.single, contains('a.dart:2'));
    });

    test('Ausnahme für build unterdrückt, nicht mehr nötige wird gemeldet', () {
      put('lang.dart', _blockBuild(160));
      put('kurz.dart', _blockBuild(20));
      final r = checkLibSize(lib, exceptions: <String, Set<String>>{
        'lang.dart': <String>{kindBuild},
        'kurz.dart': <String>{kindBuild},
      });
      expect(r.problems.single, contains('kurz.dart: Ausnahme "build" nicht mehr nötig'));
    });
  });

  group('Ausnahmeliste', () {
    test('lesen: Kommentare und Leerzeilen werden übergangen', () {
      final e = parseExceptions('# Kopf\n\na.dart datei\na.dart build\nb/c.dart build\n');
      expect(e['a.dart'], <String>{kindFile, kindBuild});
      expect(e['b/c.dart'], <String>{kindBuild});
    });

    test('ungültige Zeile ist ein Fehler', () {
      expect(() => parseExceptions('a.dart zeilen\n'), throwsFormatException);
      expect(() => parseExceptions('nur-ein-wort\n'), throwsFormatException);
    });
  });

  test('der App-Code liegt innerhalb der Grenzen (Ausnahmen aus tool/lib_size_exceptions.txt)', () {
    final exceptions = parseExceptions(File(exceptionsFile).readAsStringSync());
    final r = checkLibSize(Directory('lib'), exceptions: exceptions);
    expect(r.problems, isEmpty);
  });
}
