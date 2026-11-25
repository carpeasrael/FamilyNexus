import 'dart:io';

import 'package:family_nexus/domain/contacts.dart' show ContactFlags;
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

  // ---- K3a-1: Kontaktrichtlinie. Nur `ContactSync` baut und setzt sie, das Gateway liest sie nur. ----

  String code(String t) => t.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('setContactPolicy( wird nur von ContactSync gerufen; sonst nur Deklaration und Umsetzung im Gateway', () {
    const declared = <String>{'lib/data/matrix/matrix_gateway.dart', 'lib/data/matrix/gateway/direct_chats.dart'};
    final callers = <String>[];
    for (final f in libFiles()) {
      final t = code(f.readAsStringSync());
      if (!t.contains('setContactPolicy(')) continue;
      if (declared.contains(f.path)) continue;
      callers.add(f.path);
    }
    expect(callers, <String>['lib/data/sync/contact_sync.dart']);
  });

  test('ContactPolicy.of( nur in der Definition und in ContactSync (das Gateway baut sie nie)', () {
    final offenders = <String>[];
    for (final f in libFiles()) {
      if (f.path == 'lib/domain/contacts.dart' || f.path == 'lib/data/sync/contact_sync.dart') continue;
      if (code(f.readAsStringSync()).contains('ContactPolicy.of(')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('die Einstufung kennt ContactPolicy nicht (nur Werte im PolicyContext)', () {
    expect(code(File('lib/domain/conversation_policy.dart').readAsStringSync()), isNot(contains('ContactPolicy')));
  });

  test('das Gateway setzt die Richtlinie nur in _resetLocal zurück, nie beim Familienwechsel (Kontakte gehören zum Konto)', () {
    final t = File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync();
    String body(String sig) {
      final i = t.indexOf(sig);
      expect(i, greaterThan(0), reason: sig);
      return t.substring(i, t.indexOf('\n  }\n', i));
    }

    expect(body('void _resetLocal() {'), contains('_contactPolicy = ContactPolicy.off;'));
    expect(body('void _leaveFamilyScope() {'), isNot(contains('_contactPolicy')));
    final d = File('lib/data/matrix/gateway/direct_chats.dart').readAsStringSync();
    final i = d.indexOf('void _resetDirectChats()');
    expect(i, greaterThan(0));
    expect(d.substring(i, d.indexOf('\n  }\n', i)), isNot(contains('_contactPolicy')));
    expect(RegExp(r'_contactPolicy\s*=').allMatches(t + d).length, 3, reason: 'Feld, setContactPolicy und _resetLocal');
    expect(d, contains('ContactPolicy _contactPolicy = ContactPolicy.off;'), reason: 'Standard ohne Anmeldung ist aus');
  });

  // ---- K3a-2: Kontakt-Einzelchats im Gateway ----

  test('Freigabebedingung: ContactFlags.enabled nur, wenn K3b-2 (B8) und K3c (Kontakte ohne Familie) abgeschlossen sind', () {
    if (!ContactFlags.enabled) return; // Der Freigabe-PR setzt die Marken bewusst in docs/ENTSCHEIDUNGEN.md.
    final doc = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();
    expect(doc, contains('K3b-2 abgeschlossen'));
    expect(doc, contains('K3c abgeschlossen'));
  });

  test('Kontakt-Räume werden nur über ConversationPolicy eingestuft; die Test-Naht des Mitgliedszustands liegt nur dort', () {
    final t = code(File('lib/data/matrix/gateway/contact_chats.dart').readAsStringSync());
    expect(t, contains('RoomClass.contactDirect'));
    expect(t, contains('RoomClass.contactRequest'));
    expect(t, contains('ConversationPolicy.autoAcceptContact('));
    final offenders = <String>[];
    for (final f in libFiles()) {
      if (f.path != 'lib/data/matrix/gateway/contact_chats.dart' && code(f.readAsStringSync()).contains('debugPeerMembershipLoader')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
  });

  test('Gateway: Lesebestätigung für Kontakte nie öffentlich; Kontakt-Zeitleisten in Wiederholung, close und dispose; Zurücksetzen leert sie', () {
    final t = code(File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync());
    expect(t, contains('public: !outside && _shareReadReceipts()'));
    expect(t, contains('for (final e in _contacts.timelines.entries) (e.key, e.value),'));
    expect('_contacts.clearAll();'.allMatches(t).length, 1, reason: 'close');
    expect('_contacts.cancelTimelines();'.allMatches(t).length, 1, reason: 'dispose');
    final d = code(File('lib/data/matrix/gateway/direct_chats.dart').readAsStringSync());
    expect(d, contains('_contacts.clearAll();'));
  });

  test('Kontakt-Räume: keine App-Ereignisse hinein (Reaktion verweigert, Terminverweise nur im Familienraum, Lesebestätigung privat)', () {
    final c = code(File('lib/data/matrix/gateway/chat.dart').readAsStringSync());
    expect(c, contains('_contacts.peers.containsKey(threadId)) {\n      throw const GatewayException(GatewayError.notAllowed);'));
    expect(c, contains('return _requireContactRoom(threadId, room);'));
  });

  test('bootstrap reicht den Blockierlisten-Adapter an die Factory durch', () {
    final t = File('lib/app/bootstrap.dart').readAsStringSync();
    expect(t, contains('blockedList: SettingsBlockedList(settings),'));
    expect(t, contains('contactStore: SqlContactStore(database.db),'));
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
