import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #569: Umgebungswerte dürfen nicht ungeprüft in subprocess-Argumente der Python-Hilfsskripte fließen
/// (semgrep: dangerous-subprocess-use-tainted-env-args). `WEB_SMOKE_BROWSER_LANG` wird gegen ein Sprachmuster
/// geprüft, der `adb`-Pfad aus `ANDROID_SDK_ROOT` wird beim Aufruf aufgelöst und geprüft.
void main() {
  final root = Directory.current.path;
  final python = _python();

  const loader = 'import importlib.util, sys\n'
      'spec = importlib.util.spec_from_file_location("m", sys.argv[1])\n'
      'm = importlib.util.module_from_spec(spec)\n'
      'spec.loader.exec_module(m)\n';

  ProcessResult py(String call, String script, Map<String, String> env) =>
      Process.runSync(python!, ['-I', '-c', '$loader$call', '$root/$script'], environment: env);

  group('tool/web_smoke.py: browser_lang', () {
    ProcessResult lang(String? value) => py(
          'print(m.browser_lang())',
          'tool/web_smoke.py',
          {'WEB_SMOKE_BROWSER_LANG': ?value},
        );

    test('ohne Wert gilt de-DE', () {
      final r = lang(null);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      expect((r.stdout as String).trim(), 'de-DE');
    });

    for (final ok in ['de-DE', 'de', 'en-US', 'fil']) {
      test('gültig: $ok', () {
        final r = lang(ok);
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect((r.stdout as String).trim(), ok);
      });
    }

    for (final bad in ['de-DE --remote-allow-origins=*', '', 'de_DE', 'DE-de', 'de-DE\n--x']) {
      test('ungültig bricht ab: ${bad.replaceAll('\n', r'\n')}', () {
        final r = lang(bad);
        expect(r.exitCode, isNot(0));
        expect('${r.stderr}', contains('WEB_SMOKE_BROWSER_LANG'));
      });
    }
  }, skip: python == null ? 'python3 nicht gefunden' : false);

  for (final script in [
    'User E2E Test/Default_test_G1-G2/sandbox/ui.py',
    'User E2E Test Report/2026-11-18_36_macOS-Android_Build31/logs/helfer/ui.py',
  ]) {
    group('$script: _adb_path', () {
      late Directory sdk;
      setUp(() => sdk = Directory.systemTemp.createTempSync('adb_sdk_'));
      tearDown(() => sdk.deleteSync(recursive: true));

      Map<String, String> env() => {'ANDROID_SDK_ROOT': sdk.path};

      test('Import ohne SDK bricht nicht ab', () {
        final r = py('print("ok")', script, env());
        expect(r.exitCode, 0, reason: '${r.stderr}');
      });

      test('ohne adb bricht der Aufruf mit Meldung ab', () {
        final r = py('m._adb_path()', script, env());
        expect(r.exitCode, isNot(0));
        expect('${r.stderr}', contains('adb nicht gefunden'));
      });

      test('nicht ausführbares adb wird abgelehnt', () {
        Directory('${sdk.path}/platform-tools').createSync();
        File('${sdk.path}/platform-tools/adb').writeAsStringSync('#!/bin/sh\n');
        Process.runSync('chmod', ['-x', '${sdk.path}/platform-tools/adb']);
        final r = py('m._adb_path()', script, env());
        expect(r.exitCode, isNot(0));
        expect('${r.stderr}', contains('adb nicht gefunden'));
      });

      test('ausführbares adb liefert den aufgelösten Pfad', () {
        Directory('${sdk.path}/platform-tools').createSync();
        final adb = File('${sdk.path}/platform-tools/adb')..writeAsStringSync('#!/bin/sh\n');
        Process.runSync('chmod', ['+x', adb.path]);
        final r = py('print(m._adb_path())', script, env());
        expect(r.exitCode, 0, reason: '${r.stderr}');
        expect((r.stdout as String).trim(), adb.resolveSymbolicLinksSync());
      });
    }, skip: python == null || Platform.isWindows ? 'python3 nicht gefunden oder Windows' : false);
  }
}

String? _python() {
  for (final c in ['python3', 'python']) {
    try {
      if (Process.runSync(c, ['--version']).exitCode == 0) return c;
    } on ProcessException {
      // nächster Kandidat
    }
  }
  return null;
}
