import 'dart:io';
import 'dart:typed_data';

import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/key_value_store.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show getDatabasesPath;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_db');
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  testWidgets('Keystore liefert stabile, namensgetrennte Schlüssel', (tester) async {
    final ks = SecureKeyStore();
    await ks.deleteAll();
    final a1 = await ks.getOrCreateKey('t.a');
    final a2 = await ks.getOrCreateKey('t.a');
    final b = await ks.getOrCreateKey('t.b');
    expect(a1, a2);
    expect(a1, isNot(b));
    expect(a1.length, greaterThanOrEqualTo(43));
    await ks.deleteAll();
  });

  testWidgets('DB ist verschlüsselt: ohne/falscher Schlüssel unlesbar', (tester) async {
    final ks = SecureKeyStore();
    await ks.deleteAll();
    const secretValue = 'GEHEIMER-TERMINTITEL-12345';

    final db = await AppDatabase.open(keyStore: ks, directory: dir.path);
    await SqlKeyValueStore(db.db).write('probe', secretValue);
    await db.close();

    final file = File(p.join(dir.path, AppDatabase.fileName));
    final bytes = file.readAsBytesSync();
    // 1. Kein SQLite-Klartext-Header.
    final header = String.fromCharCodes(bytes.sublist(0, 15));
    expect(header, isNot('SQLite format 3'));
    // 2. Kein Klartext des Werts und nicht der Schlüssel in der Datei.
    final asText = String.fromCharCodes(bytes);
    expect(asText.contains(secretValue), isFalse);
    final key = await ks.getOrCreateKey(AppDatabase.keyName);
    expect(asText.contains(key), isFalse);

    // 3. Richtiger Schlüssel: lesbar.
    final again = await AppDatabase.open(keyStore: ks, directory: dir.path);
    expect((await SqlKeyValueStore(again.db).readAll())['probe'], secretValue);
    await again.close();

    // 4. Falscher Schlüssel: Zugriff schlägt fehl.
    await expectLater(() async {
      final bad = await AppDatabase.openWithKey(path: file.path, key: 'falscher-schluessel');
      await SqlKeyValueStore(bad.db).readAll();
    }(), throwsA(anything));
  });

  testWidgets('Fehlender Schlüssel bei vorhandener DB: kein stiller Neuschlüssel', (tester) async {
    final ks = SecureKeyStore();
    await ks.deleteAll();
    final db = await AppDatabase.open(keyStore: ks, directory: dir.path);
    await db.close();
    await ks.deleteAll(); // Schlüssel „verloren“
    await expectLater(
      AppDatabase.open(keyStore: ks, directory: dir.path),
      throwsA(isA<KeyLostException>()),
    );
    expect(await ks.readKey(AppDatabase.keyName), isNull, reason: 'es darf kein neuer Schlüssel entstehen');
  });

  testWidgets('Parallele Schlüsselanforderungen liefern denselben Schlüssel', (tester) async {
    final ks = SecureKeyStore();
    await ks.deleteAll();
    final keys = await Future.wait(<Future<String>>[
      for (var i = 0; i < 8; i++) ks.getOrCreateKey('t.parallel'),
    ]);
    expect(keys.toSet().length, 1);
    await ks.deleteAll();
  });

  testWidgets('Datenbank liegt im app-internen Speicher, Schlüssel nicht in Dateien', (tester) async {
    final ks = SecureKeyStore();
    await AppDatabase.destroy();
    await ks.deleteAll();
    final db = await AppDatabase.open(keyStore: ks);
    expect(db.db.path, startsWith((await getApplicationDocumentsDirectory()).parent.path));
    await db.close();
    final key = await ks.getOrCreateKey(AppDatabase.keyName);
    final docs = await getApplicationDocumentsDirectory();
    final appRoot = docs.parent; // /data/user/0/<pkg>
    final needle = Uint8List.fromList(key.codeUnits);
    var hits = 0;
    for (final f in appRoot.listSync(recursive: true, followLinks: false).whereType<File>()) {
      // Auch die Datei des Keystore-Wrappers wird gescannt: dort darf der
      // Schlüssel nur AES-verschlüsselt (nicht im Klartext) stehen.
      try {
        final data = f.readAsBytesSync();
        if (_contains(data, needle)) hits++;
      } on FileSystemException {
        continue;
      }
    }
    expect(hits, 0, reason: 'Klartext-Schlüssel in Dateien gefunden');
    await AppDatabase.destroy();
  });

  testWidgets('Vollständige Löschung entfernt Datenbankdatei, Schlüssel und Erinnerungen', (tester) async {
    final ks = SecureKeyStore();
    final db = await AppDatabase.open(keyStore: ks);
    await SqlKeyValueStore(db.db).write('probe', 'x');
    await db.close();
    final path = p.join(await getDatabasesPath(), AppDatabase.fileName);
    expect(File(path).existsSync(), isTrue);
    expect(await ks.readKey(AppDatabase.keyName), isNotNull);

    await resetLocalData(keyStore: ks);

    expect(File(path).existsSync(), isFalse);
    expect(await ks.readKey(AppDatabase.keyName), isNull);
  });
}

bool _contains(Uint8List hay, Uint8List needle) {
  if (needle.isEmpty || hay.length < needle.length) return false;
  outer:
  for (var i = 0; i <= hay.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}
