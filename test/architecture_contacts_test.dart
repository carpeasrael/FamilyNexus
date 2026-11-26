import 'dart:io';

import 'package:family_nexus/domain/contacts.dart' show ContactFlags;
import 'package:flutter_test/flutter_test.dart';

import 'support/release_markers.dart';

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
      'lib/features/contacts/contact_controller.dart', // Oberfläche (K3b-1): Dienst über ContactSync, nur hier
      'lib/app/contact_factory.dart', // erzeugt den Dienst (hinter der Sperre; K3c-2: nicht mehr im Kalender)
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
      if (RegExp(r'(?<![\w.])ContactSync\(').hasMatch(t) && p != 'lib/data/sync/contact_sync.dart' && p != 'lib/app/contact_factory.dart') offenders.add('$p ContactSync(');
      if (RegExp(r'(?<![\w.])ContactService\(').hasMatch(t) && p != 'lib/domain/contact_service.dart' && p != 'lib/app/contact_factory.dart') offenders.add('$p ContactService(');
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
    // K3c-1: `_resetDirectChats` ist in `_resetFamilyChats` und `_resetContacts` aufgeteilt; beide setzen die Richtlinie nie.
    for (final sig in <String>['void _resetFamilyChats()', 'void _resetContacts(']) {
      final i = d.indexOf(sig);
      expect(i, greaterThan(0), reason: sig);
      expect(d.substring(i, d.indexOf('\n  }\n', i)), isNot(contains('_contactPolicy')), reason: sig);
    }
    expect(RegExp(r'_contactPolicy\s*=').allMatches(t + d).length, 3, reason: 'Feld, setContactPolicy und _resetLocal');
    expect(d, contains('ContactPolicy _contactPolicy = ContactPolicy.off;'), reason: 'Standard ohne Anmeldung ist aus');
  });

  // ---- K3a-2: Kontakt-Einzelchats im Gateway ----

  test('K3b-1: ContactController( nur in der Factory und hinter contactsEnabled; die Bildschirme kennen nur den Controller', () {
    final factory = code(File('lib/app/contact_factory.dart').readAsStringSync());
    expect(RegExp(r'if \(contactStore == null \|\| !contactsEnabled\) return null;[\s\S]*?ContactController\(').hasMatch(factory), isTrue);
    final offenders = <String>[];
    for (final f in libFiles()) {
      if (f.path == 'lib/features/contacts/contact_controller.dart' || f.path == 'lib/app/contact_factory.dart') continue;
      if (RegExp(r'(?<![\w.])ContactController\(').hasMatch(code(f.readAsStringSync()))) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
    // Bildschirme: weder Dienst noch Speicher noch Gateway-Methoden noch ContactSync.
    for (final name in <String>['contacts_screen.dart', 'add_contact_screen.dart', 'contact_entry_points.dart']) {
      final t = code(File('lib/features/contacts/$name').readAsStringSync());
      for (final banned in <String>['ContactService', 'ContactStore', 'ContactSync', 'probeContact', 'startContactChat', 'declineContactRequest', 'leaveConversation', 'MatrixGateway']) {
        expect(t.contains(banned), isFalse, reason: '$name nennt $banned');
      }
    }
    // `ContactSync.service`/`.store` liest in lib/features nur der Controller.
    for (final f in libFiles().where((f) => f.path.startsWith('lib/features/') && f.path != 'lib/features/contacts/contact_controller.dart')) {
      final t = code(f.readAsStringSync());
      expect(RegExp(r'ontactSync\??\.(service|store)\b').hasMatch(t), isFalse, reason: f.path);
    }
  });

  test('K3b-2a: Chat-Bildschirm kennt nur den Controller; openThread rufen nur Bildschirme; Familien-Bereich filtert Kontakt-Threads', () {
    final chatFiles = <File>[
      File('lib/features/chat/chat_screen.dart'),
      ...Directory('lib/features/chat/widgets').listSync().whereType<File>(),
    ];
    for (final f in chatFiles) {
      final t = code(f.readAsStringSync());
      for (final banned in <String>['ContactSync', 'ContactService', 'ContactStore', 'probeContact', 'startContactChat', 'ContactController(']) {
        expect(t.contains(banned), isFalse, reason: '${f.path} nennt $banned');
      }
    }
    final screen = code(File('lib/features/chat/chat_screen.dart').readAsStringSync());
    expect(screen, contains('if (!t.isOutside) t'), reason: 'Familien-Bereich ohne Kontakt-Threads');
    expect(screen, isNot(contains('_persistLast(_openContact')), reason: 'Kontakt-Gespräche werden nie gemerkt');
    final callers = <String>[
      for (final f in libFiles())
        if (RegExp(r'(?<!Future<void> )(?<![\w])openThread\(').hasMatch(code(f.readAsStringSync()))) f.path,
    ];
    expect(callers, <String>['lib/features/chat/chat_screen.dart'], reason: 'openThread nur im Chat-Bildschirm (nie im Gateway selbst)');
  });

  test('Freigabebedingung: ContactFlags.enabled nur, wenn K3b-2 (B8) und K3c (Kontakte ohne Familie) abgeschlossen sind', () {
    if (!ContactFlags.enabled) return; // Der Freigabe-PR setzt die Marken bewusst in docs/ENTSCHEIDUNGEN.md.
    // Die Marken stehen als eigene Zeile `MARKE: …`; eine Erwähnung im Fließtext zählt nicht (`missingReleaseMarkers`, eigene Tests).
    final doc = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();
    expect(missingReleaseMarkers(doc), isEmpty);
  });

  test('K3b-2b: Verifizierung und Akzeptieren laufen über VerificationPolicy; Kontakte nutzen nie die SDK-Raumwahl; Spiegel nur mit Mitgliedern', () {
    final v = code(File('lib/data/matrix/gateway/security_verification.dart').readAsStringSync());
    expect(v, contains('_incomingAllowed(v.userId, v.room?.id)'), reason: 'Raum der eingehenden Anfrage wird geprüft');
    expect(v, contains('VerificationPolicy.allowed('));
    expect(v, contains('_verificationAllowed(userId, null)'), reason: 'startVerification prüft für jede ID vor encryptionUnavailable');
    expect(v.indexOf('_verificationAllowed(userId, null)'), lessThan(v.indexOf('GatewayError.encryptionUnavailable')));
    final contactBranch = v.substring(v.indexOf('_family?.member(userId) == null'), v.indexOf('v = await list.startVerification();'));
    expect(contactBranch, contains('KeyVerification('));
    expect(contactBranch, contains('room: room'));
    expect(contactBranch, contains('_contactRoomOf(userId)'));
    expect(contactBranch, isNot(contains('list.startVerification()')), reason: 'Kontakte: nie die SDK-Raumwahl');
    final i = code(File('lib/data/matrix/gateway/identities.dart').readAsStringSync());
    expect(i, contains('VerificationPolicy.contactAllowed('));
    expect(i, contains('local: _memberPins()'), reason: 'Kontakt-Pins gelangen nie in den Spiegel der Kontodaten');
    expect(i, isNot(contains('local: _localPins.pins')));
    final c = code(File('lib/data/matrix/gateway/contact_chats.dart').readAsStringSync());
    expect(c, contains('_identityOf(e.key, me, mirror: false)'));
    expect(c, contains('_identityOf(peer, me, mirror: false)'));
    final g = code(File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync());
    expect(g, contains('_contactSessionPins.clear();'));
    expect(g, contains('_contactAcceptedPins.clear();'));
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
    // K3c-1: genau ein `clearAll()` in direct_chats.dart, in `_resetContacts(full: true)`; `full: false` ruft es nie
    // (Scope-Wechsel darf `failed`/`creating` nicht löschen).
    expect('_contacts.clearAll();'.allMatches(d).length, 1);
    expect(RegExp(r'if \(full\) \{\s*_contacts\.clearAll\(\);\s*return;\s*\}').hasMatch(d), isTrue);
  });

  test('probeContact/startContactChat nur im Gateway; Profil über den direkten Endpunkt, nie über den SDK-Cache (kein Fremdprofil in der Datenbank)', () {
    // K3b-1: genau der Controller ruft beide auf (ausdrücklich, nach Tipp); die Oberfläche (Screens) nie.
    const allowed = <String>{'lib/data/matrix/matrix_gateway.dart', 'lib/data/matrix/gateway/contact_add.dart', 'lib/features/contacts/contact_controller.dart'};
    final offenders = <String>[];
    for (final f in libFiles()) {
      if (allowed.contains(f.path)) continue;
      final t = code(f.readAsStringSync());
      if (t.contains('probeContact(') || t.contains('startContactChat(')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
    final t = code(File('lib/data/matrix/gateway/contact_add.dart').readAsStringSync());
    expect(t, contains("RequestType.GET, '/client/v3/profile/\${Uri.encodeComponent(userId)}'"));
    expect(t, isNot(contains('getProfileFromUserId')));
    expect(t, isNot(contains('getUserProfile')));
    // Fehler nur als Art und errcode, nie die Ausnahme, Kennung, Name oder Raum-ID.
    expect(RegExp(r"AppLog\.[dwe]\('gateway',[^;]*\$userId").hasMatch(t), isFalse);
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
    final t = File('lib/app/contact_factory.dart').readAsStringSync();
    final at = t.indexOf('ContactSync(');
    expect(at, greaterThan(0));
    expect(t.substring(0, at), contains('!contactsEnabled) return null;'));
    expect('ContactSync('.allMatches(t).length, 1);
  });

  test('K3c-1 (Textwächter, folgen aus der Umsetzung): Kontaktpfad ohne Familie, kein _dmEpoch, me nie aus _family, Kontakt-Epoche nur in _resetLocal, Gate im Abgleich', () {
    final all = <String, String>{for (final f in libFiles()) f.path: code(f.readAsStringSync())};
    final add = all['lib/data/matrix/gateway/contact_add.dart']!;
    final chats = all['lib/data/matrix/gateway/contact_chats.dart']!;
    final main = all['lib/data/matrix/sdk_matrix_gateway.dart']!;
    expect(add, isNot(contains('_requireFamily')), reason: 'Kontakte brauchen keine Familie');
    expect(chats, isNot(contains('_requireFamily')));
    // Kein `_dmEpoch` im Kontaktpfad (auch nicht als Getter-Deklaration): contact_add.dart und contact_chats.dart.
    for (final e in <String, String>{'contact_add.dart': add, 'contact_chats.dart': chats}.entries) {
      expect(e.value, isNot(contains('_dmEpoch')), reason: e.key);
      expect(e.value, contains('_contactEpoch'), reason: e.key);
    }
    // `me` nie aus der Familie: weder `_family` noch `f.myUserId` in den Kontaktpfaden.
    for (final e in <String, String>{'contact_add.dart': add, 'contact_chats.dart': chats}.entries) {
      expect(e.value, isNot(contains('_family')), reason: e.key);
      expect(e.value, isNot(contains('myUserId')), reason: e.key);
    }
    expect(chats, contains('final me = _client?.userID;'));
    // `_resetDirectChats` gibt es nicht mehr; `_resetFamilyChats` räumt keinen Kontaktzustand.
    for (final e in all.entries) {
      expect(e.value, isNot(contains('_resetDirectChats')), reason: e.key);
    }
    final d = all['lib/data/matrix/gateway/direct_chats.dart']!;
    final fam = d.substring(d.indexOf('void _resetFamilyChats()'), d.indexOf('void _resetContacts('));
    expect(fam, isNot(contains('_contacts')));
    // Die Kontakt-Epoche steigt genau einmal, in `_resetLocal`.
    expect('_contactEpoch++'.allMatches(all.values.join('\n')).length, 1);
    final reset = main.substring(main.indexOf('void _resetLocal() {'), main.indexOf('\n  }\n', main.indexOf('void _resetLocal() {')));
    expect(reset, contains('_contactEpoch++;'));
    // Gate: der Kontaktpfad im `room == null`-Zweig und die Auslöser (Übergangs-Abgleich, Zähler) nur bei eingeschaltetem Bereich.
    expect(RegExp(r'if \(_contactPolicy\.enabled\) \{[^}]*_threads = _contactThreads\(\);[^}]*_syncContactsOnly\(client\)').hasMatch(main), isTrue);
    expect(RegExp(r'if \(_contactPolicy\.enabled\) \{[^}]*_trackContactRow2\(countSync: relevant\);[^}]*if \(firstAnswer\) _scheduleRefresh\(\);').hasMatch(main), isTrue);
    expect(main, contains('_accountDataFresh = true;'));
    expect(main.indexOf('_accountDataFresh = true;'), lessThan(main.indexOf('_trackLive(client, update);')), reason: 'erste Anweisung im Listener');
  });

  test('die Sperre ist an (Freigabe-PR ändert diesen Test bewusst)', () {
    final t = File('lib/domain/contacts.dart').readAsStringSync();
    expect(RegExp(r'class ContactFlags \{[^}]*static const bool enabled = false;').hasMatch(t), isTrue);
  });
}
