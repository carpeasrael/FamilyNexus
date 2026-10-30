// Pen-Test 2026-10-30 – I-02: Rechte des Datenverzeichnisses unter Linux.
// Aufruf mit eigenem XDG_DATA_HOME, z. B. XDG_DATA_HOME=/tmp/x flutter test pen-Test/tests/pt_permissions_test.dart
import 'dart:io';

import 'package:family_nexus/data/db/encrypted_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PT-L1: Datenverzeichnis und vorhandene Dateien nur für den eigenen Benutzer', () async {
    final xdg = Platform.environment['XDG_DATA_HOME'];
    if (xdg == null || !xdg.contains('pt-perm')) {
      markTestSkipped('nur mit XDG_DATA_HOME=…/pt-perm…');
      return;
    }
    final app = Directory('$xdg/de.inneso.familynexus/databases')..createSync(recursive: true);
    final old = File('${app.path}/alt.db')..writeAsStringSync('x');
    await Process.run('chmod', <String>['-R', '755', '$xdg/de.inneso.familynexus']);
    await Process.run('chmod', <String>['644', old.path]);
    await EncryptedDb.databasesPath();
    String mode(String p) => (Process.runSync('stat', <String>['-c', '%a', p]).stdout as String).trim();
    // ignore: avoid_print
    print('PT-L1: app=${mode('$xdg/de.inneso.familynexus')} databases=${mode(app.path)} alt.db=${mode(old.path)}');
    expect(mode('$xdg/de.inneso.familynexus'), '700');
    expect(mode(app.path), '700');
    expect(mode(old.path), '600');
  });
}
