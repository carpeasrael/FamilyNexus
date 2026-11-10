// Wächter für die Größe des App-Codes (#360): meldet Dateien über [maxFileLines] Zeilen und `build`-Methoden über
// [maxBuildLines] Zeilen in `lib/` (ohne `lib/l10n/gen`). Bekannte Überschreitungen stehen in
// `tool/lib_size_exceptions.txt`; die Liste wird mit jedem Refactoring kürzer: Eine Ausnahme, die nicht mehr nötig
// ist, lässt den Wächter ebenfalls fehlschlagen.
//
//   dart tool/check_lib_size.dart        Exit 1 mit Liste der Verstöße
//
// Bewusst nur `dart:io`: Das Skript läuft ohne Flutter und wird von `test/tool/check_lib_size_test.dart` importiert.
import 'dart:io';

/// Höchstens so viele Zeilen je Datei (gezählt wie `wc -l`). Anpassung bewusst per PR.
const int maxFileLines = 1000;

/// Höchstens so viele Zeilen je `build`-Methode, erste bis letzte Zeile eingeschlossen.
const int maxBuildLines = 150;

/// Ausnahmeliste, relativ zum Repository.
const String exceptionsFile = 'tool/lib_size_exceptions.txt';

const String kindFile = 'datei';
const String kindBuild = 'build';

class LibSizeResult {
  LibSizeResult(this.problems);
  final List<String> problems;
  bool get ok => problems.isEmpty;
}

/// `<pfad relativ zu lib> datei|build`, Zeilen mit `#` und Leerzeilen werden übergangen.
Map<String, Set<String>> parseExceptions(String text) {
  final result = <String, Set<String>>{};
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length != 2 || (parts[1] != kindFile && parts[1] != kindBuild)) {
      throw FormatException('Ungültige Zeile in $exceptionsFile: "$line"');
    }
    result.putIfAbsent(parts[0], () => <String>{}).add(parts[1]);
  }
  return result;
}

int countLines(String text) {
  if (text.isEmpty) return 0;
  final n = '\n'.allMatches(text).length;
  return text.endsWith('\n') ? n : n + 1;
}

/// Prüft alle Dateien unter [lib]. [exceptions]: Pfad relativ zu [lib] (mit `/`) → Arten.
LibSizeResult checkLibSize(
  Directory lib, {
  int maxFile = maxFileLines,
  int maxBuild = maxBuildLines,
  Map<String, Set<String>> exceptions = const <String, Set<String>>{},
}) {
  final problems = <String>[];
  final usedFile = <String>{};
  final usedBuild = <String>{};
  final base = lib.path.replaceAll(r'\', '/');
  final files = lib.listSync(recursive: true).whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final path = f.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart') || path.contains('/l10n/gen/')) continue;
    final rel = path.startsWith('$base/') ? path.substring(base.length + 1) : path;
    final text = f.readAsStringSync().replaceAll('\r\n', '\n');
    final lines = countLines(text);
    if (lines > maxFile) {
      if (exceptions[rel]?.contains(kindFile) ?? false) {
        usedFile.add(rel);
      } else {
        problems.add('$rel: $lines Zeilen (Grenze $maxFile)');
      }
    }
    for (final b in buildMethods(text)) {
      if (b.lines <= maxBuild) continue;
      if (exceptions[rel]?.contains(kindBuild) ?? false) {
        usedBuild.add(rel);
      } else {
        problems.add('$rel:${b.startLine}: build mit ${b.lines} Zeilen (Grenze $maxBuild)');
      }
    }
  }
  exceptions.forEach((rel, kinds) {
    if (!File('$base/$rel').existsSync()) {
      problems.add('$rel: Ausnahme für eine Datei, die es nicht gibt');
      return;
    }
    if (kinds.contains(kindFile) && !usedFile.contains(rel)) {
      problems.add('$rel: Ausnahme "$kindFile" nicht mehr nötig, bitte aus $exceptionsFile streichen');
    }
    if (kinds.contains(kindBuild) && !usedBuild.contains(rel)) {
      problems.add('$rel: Ausnahme "$kindBuild" nicht mehr nötig, bitte aus $exceptionsFile streichen');
    }
  });
  return LibSizeResult(problems);
}

class BuildMethod {
  BuildMethod(this.startLine, this.lines);
  final int startLine;
  final int lines;
}

final RegExp _buildStart = RegExp(r'Widget build\(BuildContext');

/// Alle `Widget build(BuildContext …)` im Text mit Startzeile (1-basiert) und Länge in Zeilen.
List<BuildMethod> buildMethods(String src) {
  final result = <BuildMethod>[];
  for (final m in _buildStart.allMatches(src)) {
    final open = src.indexOf('(', m.start + 'Widget build'.length - 1);
    if (open < 0) continue;
    final afterParams = _skipGroup(src, open);
    if (afterParams < 0) continue;
    var i = afterParams;
    while (i < src.length && ' \n\t'.contains(src[i])) {
      i++;
    }
    final end = src.startsWith('=>', i) ? _expressionEnd(src, i + 2) : (i < src.length && src[i] == '{' ? _skipGroup(src, i) - 1 : -1);
    if (end < 0) continue;
    final startLine = '\n'.allMatches(src.substring(0, m.start)).length + 1;
    final endLine = '\n'.allMatches(src.substring(0, end)).length + 1;
    result.add(BuildMethod(startLine, endLine - startLine + 1));
  }
  return result;
}

bool _isIdentifierChar(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Ende von Kommentar oder String, der bei [i] beginnt (Index dahinter); sonst -1.
int _skipTrivia(String s, int i) {
  final c = s[i];
  if (c == '/' && i + 1 < s.length) {
    if (s[i + 1] == '/') {
      final nl = s.indexOf('\n', i);
      return nl < 0 ? s.length : nl;
    }
    if (s[i + 1] == '*') {
      final close = s.indexOf('*/', i + 2);
      return close < 0 ? s.length : close + 2;
    }
  }
  var j = i;
  var raw = false;
  if (c == 'r' && i + 1 < s.length && (s[i + 1] == "'" || s[i + 1] == '"') && (i == 0 || !_isIdentifierChar(s[i - 1]))) {
    raw = true;
    j = i + 1;
  }
  if (s[j] != "'" && s[j] != '"') return -1;
  final q = s[j];
  final triple = s.startsWith(q * 3, j);
  final close = triple ? q * 3 : q;
  j += triple ? 3 : 1;
  while (j < s.length) {
    final ch = s[j];
    if (!raw && ch == r'\') {
      j += 2;
      continue;
    }
    if (!raw && ch == r'$' && j + 1 < s.length && s[j + 1] == '{') {
      final after = _skipGroup(s, j + 1);
      j = after < 0 ? s.length : after;
      continue;
    }
    if (s.startsWith(close, j)) return j + close.length;
    if (!triple && ch == '\n') return j;
    j++;
  }
  return s.length;
}

/// Index hinter der Klammer, die bei [open] (`(`, `[` oder `{`) aufgeht; -1, wenn sie nicht schließt.
int _skipGroup(String s, int open) {
  var depth = 0;
  var i = open;
  while (i < s.length) {
    final skipped = _skipTrivia(s, i);
    if (skipped >= 0) {
      i = skipped;
      continue;
    }
    final c = s[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
    i++;
  }
  return -1;
}

/// Index des `;`, das den Ausdruck ab [from] auf Klammertiefe 0 beendet; -1, wenn keines folgt.
int _expressionEnd(String s, int from) {
  var depth = 0;
  var i = from;
  while (i < s.length) {
    final skipped = _skipTrivia(s, i);
    if (skipped >= 0) {
      i = skipped;
      continue;
    }
    final c = s[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (c == ';' && depth == 0) {
      return i;
    }
    i++;
  }
  return -1;
}

void main() {
  final file = File(exceptionsFile);
  final exceptions = file.existsSync() ? parseExceptions(file.readAsStringSync()) : <String, Set<String>>{};
  final result = checkLibSize(Directory('lib'), exceptions: exceptions);
  if (result.ok) {
    stdout.writeln('lib/: Dateigröße und build-Länge innerhalb der Grenzen (Dateien $maxFileLines, build $maxBuildLines Zeilen).');
    return;
  }
  stderr.writeln('Verstöße gegen die Größengrenzen in lib/:');
  for (final p in result.problems) {
    stderr.writeln('  $p');
  }
  stderr.writeln('Behebung: Datei bzw. build zerlegen oder (nur nach Absprache) in $exceptionsFile eintragen.');
  exit(1);
}
