import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// #359: Kein stilles `catch (_)` in `lib/`. Jeder Block sagt, warum er den Fehler ignoriert (`//`-Kommentar),
/// protokolliert ihn (`AppLog.`) oder reicht ihn unverändert weiter (`rethrow`). Ein neues `throw` genügt nicht: Es
/// verliert die Ursache.

/// Der Text des Blocks nach `catch (_)`, ohne die äußeren Klammern; `null`, wenn kein Block folgt.
String? _blockAfter(String src, int from) {
  final open = src.indexOf('{', from);
  if (open < 0) return null;
  var depth = 0;
  String? quote;
  for (var i = open; i < src.length; i++) {
    final c = src[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      final end = src.indexOf('\n', i);
      if (end < 0) return src.substring(open + 1);
      i = end;
    } else if (c == '{') {
      depth++;
    } else if (c == '}') {
      depth--;
      if (depth == 0) return src.substring(open + 1, i);
    }
  }
  return null;
}

/// Ob [block] einen Kommentar enthält; `//` innerhalb eines Strings zählt nicht.
bool _hasComment(String block) {
  String? quote;
  for (var i = 0; i < block.length; i++) {
    final c = block[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
      }
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '/' && i + 1 < block.length && block[i + 1] == '/') {
      return true;
    }
  }
  return false;
}

bool _isExplained(String block) {
  if (block.contains('AppLog.')) return true;
  if (RegExp(r'(^|[\s;{}])rethrow\s*;').hasMatch(block)) return true;
  return _hasComment(block);
}

/// Die Stellen (1-basiert) mit `catch (_)`, deren Block nichts erklärt.
List<int> silentCatches(String src) {
  final found = <int>[];
  for (final m in RegExp(r'catch\s*\(\s*_\s*\)').allMatches(src)) {
    final block = _blockAfter(src, m.end);
    if (block == null || !_isExplained(block)) {
      found.add('\n'.allMatches(src.substring(0, m.start)).length + 1);
    }
  }
  return found;
}

void main() {
  group('Scanner', () {
    test('leerer Einzeiler wird gemeldet', () {
      expect(silentCatches('try {\n  a();\n} catch (_) {}\n'), <int>[3]);
    });

    test('Kommentar, AppLog und nacktes rethrow genügen', () {
      expect(silentCatches('try {} catch (_) {\n  // warum\n}\n'), isEmpty);
      expect(silentCatches("try {} catch (_) { AppLog.w('t', 'm'); }\n"), isEmpty);
      expect(silentCatches('try {} catch (_) {\n  cleanup();\n  rethrow;\n}\n'), isEmpty);
    });

    test('throw ohne Kommentar genügt nicht', () {
      expect(silentCatches('try {} catch (_) {\n  throw const X();\n}\n'), <int>[1]);
      expect(silentCatches('try {} catch (_) {\n  throw const X(); // Ursache egal\n}\n'), isEmpty);
    });

    test('„//“ in einem String ist kein Kommentar', () {
      expect(silentCatches("try {} catch (_) {\n  x = 'https://a';\n}\n"), <int>[1]);
    });

    test('Klammern in Strings und verschachtelte Blöcke stören die Blockgrenze nicht', () {
      expect(silentCatches("try {} catch (_) {\n  if (a) { b = '}'; }\n  // ok\n}\n"), isEmpty);
    });

    test('catch (e) wird nicht erfasst', () {
      expect(silentCatches('try {} catch (e) {}\n'), isEmpty);
    });
  });

  test('kein stilles catch (_) in lib/', () {
    final problems = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = posix(f.path);
      if (!path.endsWith('.dart') || path.contains('/l10n/gen/')) continue;
      for (final line in silentCatches(readNormalized(f.path))) {
        problems.add('$path:$line');
      }
    }
    expect(problems, isEmpty, reason: 'catch (_) ohne Kommentar, AppLog oder rethrow');
  });
}
