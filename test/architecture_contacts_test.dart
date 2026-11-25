import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #119, K2b/K2c (E-114): Bis zur Freigabe (K6) und den Datenschutztexten erzeugt oder nutzt kein Produktionscode den
/// Kontaktspeicher und -dienst, außer dort, wo es nötig ist. Die Aussage „`contact_records` bleibt bis dahin leer“ in
/// `store/privacy` und den App-Texten stützt sich darauf. Der Freigabe-PR ändert diese Liste und die Sperre bewusst.
void main() {
  List<File> libFiles() => Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

  test('nur die Definitionen, die Factory, bootstrap und die Wipe-Pfade nennen SqlContactStore, ContactService und ContactStore', () {
    const allowed = <String>{
      'lib/domain/contact_service.dart',
      'lib/domain/contact_store.dart',
      'lib/data/db/sql_contact_store.dart',
      'lib/data/sync/contact_sync.dart', // ContactService, ContactStore
      'lib/app/calendar_factory.dart', // erzeugt den Dienst (hinter der Sperre)
      'lib/app/bootstrap.dart', // reicht SqlContactStore durch
      'lib/app/app_services.dart', // Wipe-Pfade (wipeAccountDataIn, claimFamilyData)
    };
    final offenders = <String>[];
    for (final f in libFiles()) {
      if (allowed.contains(f.path)) continue;
      final t = f.readAsStringSync();
      if (t.contains('SqlContactStore') || t.contains('ContactService') || t.contains('ContactStore')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('Erzeugung: ContactSync( und ContactService( nur in der Factory, SqlContactStore( nur in bootstrap und app_services', () {
    final offenders = <String>[];
    for (final f in libFiles()) {
      final t = f.readAsStringSync();
      final p = f.path;
      if (RegExp(r'(?<![\w.])ContactSync\(').hasMatch(t) && p != 'lib/data/sync/contact_sync.dart' && p != 'lib/app/calendar_factory.dart') offenders.add('$p ContactSync(');
      if (RegExp(r'(?<![\w.])ContactService\(').hasMatch(t) && p != 'lib/domain/contact_service.dart' && p != 'lib/app/calendar_factory.dart') offenders.add('$p ContactService(');
      if (RegExp(r'(?<![\w.])SqlContactStore\(').hasMatch(t) && p != 'lib/data/db/sql_contact_store.dart' && p != 'lib/app/bootstrap.dart' && p != 'lib/app/app_services.dart') {
        offenders.add('$p SqlContactStore(');
      }
    }
    expect(offenders, isEmpty);
  });

  test('app_services.dart ruft SqlContactStore nur zum Wischen auf', () {
    final t = File('lib/app/app_services.dart').readAsStringSync();
    final uses = RegExp(r'SqlContactStore\(db\)\.(\w+)').allMatches(t).map((m) => m.group(1)).toList();
    expect(uses, isNotEmpty);
    expect(uses.toSet(), <String?>{'wipe'});
  });

  test('bootstrap.dart legt den Speicher nur an und reicht ihn durch (kein Aufruf seiner Methoden)', () {
    final t = File('lib/app/bootstrap.dart').readAsStringSync();
    expect(RegExp(r'SqlContactStore\(database\.db\)\.\w+').hasMatch(t), isFalse);
    expect('SqlContactStore(database.db)'.allMatches(t).length, 1);
  });

  test('die Factory erzeugt ContactSync nur hinter der Sperre (contactsEnabled)', () {
    final t = File('lib/app/calendar_factory.dart').readAsStringSync();
    final at = t.indexOf('ContactSync(');
    expect(at, greaterThan(0));
    expect(t.substring(at - 120, at), contains('contactsEnabled'));
    expect('ContactSync('.allMatches(t).length, 1);
  });

  test('die Sperre ist an (Freigabe-PR ändert diesen Test bewusst)', () {
    final t = File('lib/domain/contacts.dart').readAsStringSync();
    expect(RegExp(r'class ContactFlags \{[^}]*static const bool enabled = false;').hasMatch(t), isTrue);
  });
}
