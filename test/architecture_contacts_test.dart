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

  test('K3c-3: die drei Freigabemarken stehen als eigene Zeile in docs/ENTSCHEIDUNGEN.md (die Freigabe selbst bleibt ein eigener PR)', () {
    final doc = File('docs/ENTSCHEIDUNGEN.md').readAsStringSync();
    expect(missingReleaseMarkers(doc), isEmpty);
    for (final m in <String>['K3c Pin-Sackgasse gelöst', 'K3c abgeschlossen']) {
      expect(RegExp('^MARKE: ${RegExp.escape(m)}\\s*\$', multiLine: true).allMatches(doc).length, 1, reason: 'genau eine eigene Zeile: $m');
    }
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

  // K4-2b: ersetzt „Kontakt-Räume: keine App-Ereignisse hinein (Reaktion verweigert, …)“ AUSDRÜCKLICH: die Pauschalsperre für
  // Reaktionen ist durch Nutzerentscheidung (§3.5) entfallen; Reaktionen gehen durch dieselben Tore wie der Text. Geblieben ist
  // der Kontakt-Pfad für Texte.
  test('Kontakt-Räume (K4-2b): Reaktionen laufen über das Tor des Raums (keine Pauschalsperre mehr), Kontakt-Pfad für Text unverändert', () {
    final c = code(File('lib/data/matrix/gateway/chat.dart').readAsStringSync());
    expect(c, isNot(contains('_contacts.peers.containsKey(threadId)) {\n      throw const GatewayException(GatewayError.notAllowed);')));
    expect(c, contains('return _requireContactRoom(threadId, room);'));
    final r = c.substring(c.indexOf('Future<void> sendReaction('), c.indexOf('Future<void> reportMessage('));
    expect(r, contains('_requireEncryptedRoom(threadId)'));
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

  test('K3c-3 (Textwächter, folgen aus der Umsetzung): Hülle nur nach ausdrücklicher Wahl, Familie gewinnt, Karten nehmen nie an, Taste nur für identityChanged', () {
    final all = <String, String>{for (final f in libFiles()) f.path: code(f.readAsStringSync())};
    final root = all['lib/features/shell/app_root.dart']!;
    // Hülle ohne Familie: nur mit Sitzung, Sicherheit, Einrichtung, ohne Familie, gewählt und mit freigeschalteten Kontakten.
    expect(root, contains('final contactsOnlyWanted = !ready && services.settings.settings.onboardingDone && session && secure && family == null && services.settings.settings.contactsOnly;'));
    expect(root, contains('final readyContactsOnly = contactsOnlyWanted && services.contacts != null;'));
    expect(RegExp(r'ready \? const HomeShell\(\) : \(readyContactsOnly \? const ContactsHome\(\) : const OnboardingScreen\(\)\)').hasMatch(root), isTrue, reason: 'Familie gewinnt immer');
    // Die Wahl wird nur an einer Stelle gesetzt (ausdrücklicher Knopf), nie automatisch.
    final setters = <String>[
      for (final e in all.entries)
        if (e.key != 'lib/domain/app_settings.dart' && RegExp(r'copyWith\([^)]*contactsOnly:\s*true').hasMatch(e.value)) e.key,
    ];
    expect(setters, <String>['lib/app/app_services.dart']);
    expect(all['lib/app/app_services.dart']!, contains('Future<bool> enterContactsOnly()'));
    expect('enterContactsOnly('.allMatches(all.values.join('\n')).length, 2, reason: 'Definition und genau ein Aufruf (Knopf in der Einrichtung)');
    expect(all['lib/features/onboarding/onboarding_screen.dart']!, contains('if (_s.contacts == null || _s.gateway.family != null) return family;'));
    // Karten der Hülle: Familie, Einladung, Beitrittsanfrage werden nie angenommen, abgelehnt oder zurückgezogen.
    final home = all['lib/features/contacts/contacts_home.dart']!;
    for (final banned in <String>['acceptInvitation', 'declineInvitation', 'cancelJoinRequest', 'requestToJoin', 'createFamily', 'acceptBookInvitation', '.accept(', '.decline(']) {
      expect(home, isNot(contains(banned)), reason: 'contacts_home.dart nennt $banned');
    }
    // Taste „Trotzdem hinzufügen“: nur im Zweig identityChanged; der Controller erlaubt sie nur nach genau diesem Prüfergebnis.
    final add = all['lib/features/contacts/add_contact_screen.dart']!;
    expect(RegExp(r'l\.contactsAddAnyway\b').allMatches(add).length, 2, reason: 'Taste und Dialog-Bestätigung');
    expect(RegExp(r'if \(r\.outcome == ContactCheckOutcome\.identityChanged && r\.userId\.isNotEmpty\) \.\.\.<Widget>\[[\s\S]*?l\.contactsAddAnyway\)\)').hasMatch(add), isTrue);
    expect(add, contains('r.outcome != ContactCheckOutcome.identityChanged || _busy'));
    final ctl = all['lib/features/contacts/contact_controller.dart']!;
    expect('_identityChecked.add('.allMatches(ctl).length, 1);
    expect(RegExp(r'ContactReachability\.identityChanged => \(\) \{\s*_identityChecked\.add\(id\);').hasMatch(ctl), isTrue, reason: 'nur im Zweig identityChanged');
    expect(ctl, contains('if (!_identityChecked.contains(id)) throw const ContactException(ContactError.notAllowed);'));
    expect(ctl, contains('if (_identityChecked.contains(id)) throw const GatewayException(GatewayError.notAllowed);'), reason: 'der normale Weg bleibt gesperrt');
    // Keine neue Oberflächen-Datei importiert material.dart (Analyse-Basis): die Hülle ist ein `part` von contacts_screen.dart.
    expect(File('lib/features/contacts/contacts_home.dart').readAsStringSync(), startsWith('part of \'contacts_screen.dart\';'));
  });

  test('die Sperre ist an (Freigabe-PR ändert diesen Test bewusst)', () {
    final t = File('lib/domain/contacts.dart').readAsStringSync();
    expect(RegExp(r'class ContactFlags \{[^}]*static const bool enabled = false;').hasMatch(t), isTrue);
  });

  test('K4-1 (Textwächter): ContactGroupSpec liegt nur in seiner Datei; keine neue createRoom-Stelle für Gruppen', () {
    final users = <String>[
      for (final f in libFiles())
        if (f.path != 'lib/data/matrix/contact_group_spec.dart' && code(f.readAsStringSync()).contains('ContactGroupSpec')) f.path,
    ];
    expect(users, <String>['lib/data/matrix/gateway/contact_groups.dart'], reason: 'K4-2a: die Spec hat genau einen Verbraucher, die Gruppenanlage');
    final creators = <String>[
      for (final f in libFiles())
        if (code(f.readAsStringSync()).contains('createRoom(')) f.path,
    ]..sort();
    expect(creators, <String>[
      'lib/data/matrix/gateway/books.dart',
      'lib/data/matrix/gateway/calendar_data.dart',
      'lib/data/matrix/gateway/contact_groups.dart',
      'lib/data/matrix/gateway/family.dart',
    ], reason: 'K4-2a: genau eine Gruppenanlage, in contact_groups.dart (Spec-gebunden)');
  });

  test('K4-1 (Textwächter): die Gruppen-Domäne bleibt reine Domäne ohne SDK und ohne data/', () {
    for (final path in <String>['lib/domain/group_rights.dart', 'lib/domain/conversation_policy.dart', 'lib/domain/chat.dart']) {
      final imports = code(File(path).readAsStringSync()).split('\n').where((l) => l.startsWith('import '));
      for (final i in imports) {
        expect(i, isNot(contains('package:matrix')), reason: path);
        expect(i, isNot(contains('data/')), reason: path);
        expect(i, isNot(contains('features/')), reason: path);
      }
    }
  });

  test('K4-1 (Textwächter): das Gateway reicht die Gruppen im PolicyContext durch, beide Kontexte (mit und ohne Familie)', () {
    final a = code(File('lib/data/matrix/gateway/direct_chats.dart').readAsStringSync());
    final b = code(File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync());
    expect(a, contains('groups: _contactPolicy.groups'));
    expect(b, contains('groups: _contactPolicy.groups'));
  });

  // ---- K4-2a: Gruppen im Gateway (Textwächter) ----

  test('K4-2a (Textwächter): _scanForSignals hat genau die drei bekannten Aufrufe, jeder auf _timeline oder _privateTimeline, nie auf Kontakt-/Gruppenzeitleisten', () {
    final calls = <String>[];
    for (final f in libFiles()) {
      final t = code(f.readAsStringSync());
      for (final m in RegExp(r'(?<!void )_scanForSignals\(([^,)]*)').allMatches(t)) {
        calls.add('${f.path}|${m.group(1)!.trim()}');
      }
    }
    calls.sort();
    expect(calls.length, 3, reason: 'ein vierter Aufruf lässt den Wächter rot werden (alle drei Aufrufstellen erfasst)');
    for (final c in calls) {
      expect(<String>['_timeline', '_privateTimeline'].contains(c.split('|').last), isTrue, reason: c);
    }
    expect(calls.where((c) => c.startsWith('lib/data/matrix/sdk_matrix_gateway.dart|')), hasLength(3));
  });

  test('K4-2a (Textwächter): acceptGroupInvite nennt familyAccountData nie und nimmt nie über acceptInvitation oder _joinContact an', () {
    final t = code(File('lib/data/matrix/gateway/contact_groups.dart').readAsStringSync());
    final a = t.indexOf('Future<void> acceptGroupInvite(String roomId) async {');
    expect(a, greaterThan(0));
    final body = t.substring(a, t.indexOf('\n  }\n', a));
    expect(body, isNot(contains('familyAccountData')));
    expect(body, isNot(contains('acceptInvitation')));
    expect(body, isNot(contains('_joinContact')));
    expect(t, isNot(contains('familyAccountData')), reason: 'das Gruppenmodul schreibt nie die Familienzuordnung');
    expect(t, isNot(contains('setAccountData')), reason: 'kein Datensatz, keine Zuordnung (das tut der Controller, K4-3)');
    expect(t, isNot(contains('.peers')), reason: 'Gruppen sind kein Einzelchat-Zustand (eigener Halter)');
    expect(t, contains('ContactGroupSpec.verifyJoined('), reason: 'Nachprüfung nach dem Beitritt');
  });

  test('K4-2a (Textwächter): Gruppenanfragen werden nie automatisch angenommen; Beitritt nur in acceptGroupInvite', () {
    final chats = code(File('lib/data/matrix/gateway/contact_chats.dart').readAsStringSync());
    expect(chats, contains('if (!meta.direct || from == null || !_contactPolicy.contacts.containsKey(from)) continue;'), reason: 'Auto-Annahme nur für is_direct');
    final joiners = <String>[
      for (final f in libFiles())
        if (RegExp(r'joinRoomById\(').hasMatch(code(f.readAsStringSync()))) f.path,
    ];
    expect(joiners, contains('lib/data/matrix/gateway/contact_groups.dart'));
    final groups = code(File('lib/data/matrix/gateway/contact_groups.dart').readAsStringSync());
    expect('joinRoomById('.allMatches(groups).length, 1);
    expect(groups.contains('.join('), isFalse, reason: 'kein room.join(waitForSync:) wie bei der Auto-Annahme');
  });

  test('K4-2a (Textwächter): kein AppLog im Gruppenmodul nennt Raum-ID, Kennung, Name oder die Ausnahme-Texte (nur Fehlerart)', () {
    final t = code(File('lib/data/matrix/gateway/contact_groups.dart').readAsStringSync());
    final logs = RegExp(r"AppLog\.[dwe]\('gateway', '([^']*)'").allMatches(t).map((m) => m.group(1)!).toList();
    expect(logs, isNotEmpty);
    for (final l in logs) {
      expect(l.replaceAll(r'${e.runtimeType}', ''), isNot(contains(r'$')), reason: l);
    }
  });

  // K4-2b: ersetzt den K4-2a-Wächter „Senden in Gruppen ist gesperrt (Platzhalter wirft immer)“ und „Reaktions-Pauschalsperre bleibt“
  // AUSDRÜCKLICH durch Wächter für das volle Tor und die entfallene Pauschalsperre (nicht abgeschwächt).
  test('K4-2b (Textwächter): das Tor liegt vor dem Kontakt-Pfad, ist kein Platzhalter mehr, und alle Sendewege bereiten die Gruppe vor', () {
    final g = code(File('lib/data/matrix/gateway/contact_groups.dart').readAsStringSync());
    expect(g, isNot(contains('Room _requireGroupRoom(String threadId, Room room) => throw')), reason: 'kein Platzhalter mehr');
    final a = g.indexOf('Room _requireGroupRoom(String threadId, Room room) {');
    expect(a, greaterThan(0));
    final body = g.substring(a, g.indexOf('\n  }\n', a));
    for (final need in <String>['groupOps.contains', 'pendingWipe.contains', '_canEncryptIn(room)', '_stillGroup(room)', '_groupHealthOf(room)', 'listFreshFor', '_otherMembers(room)', 'GroupSendLock.keineMitglieder', 'ContactReachability.reachable']) {
      expect(body, contains(need), reason: 'Zeile des Tors: $need');
    }
    final c = code(File('lib/data/matrix/gateway/chat.dart').readAsStringSync());
    expect(c, contains('_groups.groups.containsKey(threadId)) return _requireGroupRoom(threadId, room);'));
    expect(c.indexOf('_requireGroupRoom(threadId, room)'), lessThan(c.indexOf('_requireContactRoom(threadId, room)')));
    // Text, Anhang, Reaktion und Wiederholen bereiten die Gruppe vor (Liste, Schlüssel), bevor das Tor entscheidet.
    expect('await _prepareGroupSend(threadId);'.allMatches(c).length, 4);
    // Die Reaktions-Pauschalsperre für Kontakt-Threads (K3a-2a) ist weg.
    expect(c, isNot(contains('_contacts.peers.containsKey(threadId)) {\n      throw const GatewayException(GatewayError.notAllowed);')));
    final r = c.substring(c.indexOf('Future<void> sendReaction('), c.indexOf('Future<void> reportMessage('));
    expect(r, contains('_requireEncryptedRoom(threadId)'));
    expect(r, isNot(contains('_contacts.peers')), reason: 'keine Pauschalsperre mehr');
    expect(r, contains('_contactPolicy.blocked.contains(target.senderId)'));
  });

  test('K4-2b (Textwächter): clearOrUseOutboundGroupSession steht nur im Port, dort mit loadOutboundGroupSession davor; getOutboundGroupSession nur im Port', () {
    const port = 'lib/data/matrix/outbound_session_port.dart';
    for (final name in <String>['clearOrUseOutboundGroupSession(', 'getOutboundGroupSession(', 'loadOutboundGroupSession(']) {
      final users = <String>[for (final f in libFiles()) if (code(f.readAsStringSync()).contains(name)) f.path];
      expect(users, <String>[port], reason: '$name nur im Port');
    }
    final t = code(File(port).readAsStringSync());
    final wipe = t.indexOf('Future<void> wipe(String roomId) async {');
    final body = t.substring(wipe, t.indexOf('\n  }\n', wipe));
    expect(body.indexOf('loadOutboundGroupSession('), greaterThan(0));
    expect(body.indexOf('loadOutboundGroupSession('), lessThan(body.indexOf('clearOrUseOutboundGroupSession(roomId, wipe: true)')));
    // Das Gateway wischt nur über den Port, mit Laden und Beleg; der Rückgabewert des SDK wird nie ausgewertet.
    final g = code(File('lib/data/matrix/gateway/contact_groups.dart').readAsStringSync());
    final w = g.substring(g.indexOf('Future<_WipeResult> _wipeOutbound('), g.indexOf('Future<void> _prepareGroupSend('));
    expect(w.indexOf('_loadedRecipients(roomId)'), lessThan(w.indexOf('port.wipe(roomId)')));
    expect(w, contains('port.recipients(roomId) == null ? _WipeResult.wiped : _WipeResult.failed'));
    expect(w, isNot(contains('= await port.wipe')));
    expect(g, isNot(contains('clearOrUseOutboundGroupSession')));
  });

  test('K4-2a (Textwächter): der Verlauf steht in importantStateEvents, die Datenübersicht kennt die Gruppe, der Gruppenzustand wird mit den Kontakten geräumt', () {
    final main = code(File('lib/data/matrix/sdk_matrix_gateway.dart').readAsStringSync());
    expect(main, contains('client.importantStateEvents.add(EventTypes.HistoryVisibility);'));
    expect(main, contains('client.importantStateEvents.add(EventTypes.RoomJoinRules);'));
    expect(main, contains('_groups.clearAll();'));
    expect(main, contains('_groups.cancelTimelines();'));
    expect(code(File('lib/data/matrix/gateway/data_inventory.dart').readAsStringSync()), contains('isGroup: _groups.groups.containsKey(r.id),'));
    final d = code(File('lib/data/matrix/gateway/direct_chats.dart').readAsStringSync());
    expect(d, contains('_groups.clearAll();'));
    expect(d, contains('_groups.clearRooms();'));
    // Familienwechsel und Bereich aus räumen nur Räume: clearAll steht nur im Zweig `full`.
    expect(RegExp(r'if \(full\) \{\s*_groups\.clearAll\(\);\s*\} else \{\s*_groups\.clearRooms\(\);').hasMatch(d), isTrue);
  });
}
