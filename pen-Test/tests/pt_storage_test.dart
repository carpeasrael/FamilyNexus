// Pen-Test 2026-10-30 – lokale Datenablage (Data at Rest).
// Läuft gegen die echte SQLCipher-Bibliothek (LD_LIBRARY_PATH auf libsqlcipher.so).
// Prüft: Datei verschlüsselt, keine Klartextreste (auch nicht in -journal/-wal), falscher Schlüssel
// abgewiesen, kein neuer Schlüssel bei fehlendem Schlüssel, Löschung vollständig, Dateirechte.
import 'dart:io';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/encrypted_db.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test/support/memory_stores.dart';

const String _sentinel = 'PENTEST-SENTINEL-Geheimtermin-Arzt-7f3a';

bool _contains(List<int> hay, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= hay.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (hay[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('fn_pt_storage'));
  tearDown(() async => dir.delete(recursive: true));

  test('PT-L1: Datenbankdatei ist verschlüsselt, Klartext nirgends auf der Platte (auch nicht in Nebendateien)', () async {
    final keys = MemoryKeyStore();
    final db = await AppDatabase.open(keyStore: keys, directory: dir.path);
    await db.db.insert('settings', <String, Object?>{'key': 'pt', 'value': _sentinel});
    // Während die Datenbank offen ist, alle Dateien im Verzeichnis prüfen (Journal/WAL inklusive).
    for (final f in dir.listSync().whereType<File>()) {
      final bytes = f.readAsBytesSync();
      expect(_contains(bytes, _sentinel.codeUnits), isFalse, reason: 'Klartext in ${p.basename(f.path)} (offen)');
    }
    await db.close();
    final file = File(p.join(dir.path, AppDatabase.fileName));
    final bytes = file.readAsBytesSync();
    expect(String.fromCharCodes(bytes.take(15)), isNot('SQLite format 3'), reason: 'kein SQLite-Klartextkopf');
    for (final f in dir.listSync().whereType<File>()) {
      expect(_contains(f.readAsBytesSync(), _sentinel.codeUnits), isFalse, reason: 'Klartext in ${p.basename(f.path)}');
    }
    // Schlüsselformat: 32 Zufallsbytes, base64url.
    final key = keys.keys[AppDatabase.keyName]!;
    expect(key.length, 44);
    // ignore: avoid_print
    print('PT-L1: Dateien=${dir.listSync().map((e) => p.basename(e.path)).toList()} Kopf=${bytes.take(8).toList()}');
  });

  test('PT-L2: Falscher Schlüssel wird abgewiesen, kein stilles Neuanlegen', () async {
    final keys = MemoryKeyStore();
    final db = await AppDatabase.open(keyStore: keys, directory: dir.path);
    await db.db.insert('settings', <String, Object?>{'key': 'pt', 'value': _sentinel});
    await db.close();
    final path = p.join(dir.path, AppDatabase.fileName);
    await expectLater(AppDatabase.openWithKey(path: path, key: generateKey()), throwsA(anything));
    // Schlüssel weg (z. B. Keystore zurückgesetzt): KeyLostException, Datei bleibt unangetastet.
    final before = File(path).readAsBytesSync();
    await expectLater(AppDatabase.open(keyStore: MemoryKeyStore(), directory: dir.path), throwsA(isA<KeyLostException>()));
    expect(File(path).readAsBytesSync(), before);
  });

  test('PT-L3: Unverschlüsselte (untergeschobene) Klartext-Datenbank wird nicht geöffnet', () async {
    final path = p.join(dir.path, AppDatabase.fileName);
    // Angreifer legt eine Klartext-SQLite-Datei mit präparierten Einstellungen ab.
    sqfliteFfiInit();
    final plain = await databaseFactoryFfi.openDatabase(path);
    await plain.execute('CREATE TABLE settings (key TEXT PRIMARY KEY NOT NULL, value TEXT NOT NULL)');
    await plain.insert('settings', <String, Object?>{'key': 'pt', 'value': 'evil'});
    await plain.close();
    final keys = MemoryKeyStore()..keys[AppDatabase.keyName] = generateKey();
    await expectLater(AppDatabase.open(keyStore: keys, directory: dir.path), throwsA(anything));
  });

  test('PT-L4: Brute-Force-Parameter von SQLCipher (KDF, Cipher) entsprechen v4-Standard', () async {
    final keys = MemoryKeyStore();
    final db = await AppDatabase.open(keyStore: keys, directory: dir.path);
    final ver = await db.db.rawQuery('PRAGMA cipher_version');
    final kdf = await db.db.rawQuery('PRAGMA kdf_iter');
    final hmac = await db.db.rawQuery('PRAGMA cipher_hmac_algorithm');
    final kdfAlg = await db.db.rawQuery('PRAGMA cipher_kdf_algorithm');
    final page = await db.db.rawQuery('PRAGMA cipher_page_size');
    final provider = await db.db.rawQuery('PRAGMA cipher_provider');
    // ignore: avoid_print
    print('PT-L4: version=$ver kdf_iter=$kdf hmac=$hmac kdf=$kdfAlg page=$page provider=$provider');
    expect(int.parse('${kdf.first.values.first}'), greaterThanOrEqualTo(256000));
    await db.close();
  });

  test('PT-L5: Löschen entfernt die Datei vollständig; Dateirechte dokumentieren', () async {
    final keys = MemoryKeyStore();
    final db = await AppDatabase.open(keyStore: keys, directory: dir.path);
    await db.close();
    final path = p.join(dir.path, AppDatabase.fileName);
    final mode = (await File(path).stat()).modeString();
    // ignore: avoid_print
    print('PT-L5: Dateirechte der DB (Test-Umask): $mode');
    await AppDatabase.destroy(directory: dir.path);
    expect(File(path).existsSync(), isFalse);
    expect(await EncryptedDb.exists(path), isFalse);
  });
}
