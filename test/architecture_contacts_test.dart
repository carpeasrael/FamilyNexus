import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #119, K2b (E-114): Bis die Verdrahtung und die Datenschutztexte (K2c, K6) vorliegen, erzeugt oder ruft kein
/// Produktionscode den Kontaktspeicher und -dienst auf, außer den Wipe-Pfaden. Die Aussage „`contact_records` bleibt
/// bis dahin leer“ in `store/privacy` und den App-Texten stützt sich darauf. K2c erweitert die Liste ausdrücklich.
void main() {
  test('nur die Wipe-Pfade und die Definitionen nutzen SqlContactStore und ContactService', () {
    const allowed = <String>{
      'lib/domain/contact_service.dart',
      'lib/domain/contact_store.dart',
      'lib/data/db/sql_contact_store.dart',
      'lib/app/app_services.dart', // Wipe-Pfade (wipeAccountDataIn, claimFamilyData)
    };
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (allowed.contains(f.path)) continue;
      final t = f.readAsStringSync();
      if (t.contains('SqlContactStore') || t.contains('ContactService') || t.contains('ContactStore')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('app_services.dart ruft SqlContactStore nur zum Wischen auf', () {
    final t = File('lib/app/app_services.dart').readAsStringSync();
    final uses = RegExp(r'SqlContactStore\(db\)\.(\w+)').allMatches(t).map((m) => m.group(1)).toList();
    expect(uses, isNotEmpty);
    expect(uses.toSet(), <String?>{'wipe'});
  });
}
