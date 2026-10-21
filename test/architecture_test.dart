import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/gen/'))
    .toList();

List<String> _imports(File f) => f
    .readAsLinesSync()
    .where((l) => l.startsWith('import '))
    .toList();

void main() {
  test('Domäne ist reines Dart: kein Flutter, keine Daten-/UI-Schicht', () {
    for (final f in _dartFiles('lib/domain')) {
      for (final i in _imports(f)) {
        expect(i, isNot(contains('package:flutter/')), reason: f.path);
        expect(i, isNot(contains('../data/')), reason: f.path);
        expect(i, isNot(contains('family_nexus/data/')), reason: f.path);
        expect(i, isNot(contains('/features/')), reason: f.path);
        expect(i, isNot(contains('/ui/')), reason: f.path);
        expect(i, isNot(contains('package:matrix')), reason: f.path);
        expect(i, isNot(contains('sqflite')), reason: f.path);
      }
    }
  });

  test('Präsentation greift nicht direkt auf Datenbank, Schlüsselspeicher oder SDKs zu', () {
    const forbidden = <String>[
      'sqflite',
      'package:matrix',
      'flutter_secure_storage',
      'flutter_vodozemac',
      'file_picker',
      'flutter_local_notifications',
      'flutter_timezone',
      'package:http/',
      '/data/db/',
      '/data/platform/key_store.dart',
    ];
    for (final f in <File>[..._dartFiles('lib/features'), ..._dartFiles('lib/ui')]) {
      for (final i in _imports(f)) {
        for (final bad in forbidden) {
          expect(i, isNot(contains(bad)), reason: '${f.path}: $i');
        }
      }
    }
  });

  test('keine print/debugPrint-Aufrufe in lib/', () {
    final re = RegExp(r'\b(print|debugPrint)\(');
    for (final f in _dartFiles('lib')) {
      expect(re.hasMatch(f.readAsStringSync()), isFalse, reason: f.path);
    }
  });

  test('Android-spezifische Dart-Brücken liegen nur in data/platform', () {
    for (final f in _dartFiles('lib')) {
      if (f.path.contains('lib/data/platform/')) continue;
      expect(f.readAsStringSync(), isNot(contains('MethodChannel(')), reason: f.path);
    }
  });
}
