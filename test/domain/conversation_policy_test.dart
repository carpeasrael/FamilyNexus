import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/conversation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K2a (E-114): Jede Zeile der Einstufung einzeln. Die Verwendung im Gateway belegen die Tests in
/// `test/data/book_gateway_sync_test.dart` („Einzelchat-Einstufung“) und `book_invitation_test.dart`.
void main() {
  const me = '@ich:hs.example';
  const ben = '@ben:hs.example';
  const fremd = '@fremd:hs.example';
  const family = '!familie:hs.example';
  const priv = '!privat:hs.example';
  const ctx = PolicyContext(
    myUserId: me,
    familyRoomId: family,
    privateRoomId: priv,
    joinedMembers: <String>{me, ben},
    membersLoaded: true,
  );

  RoomFacts joined({
    String id = '!dm:hs.example',
    String? peer = ben,
    bool megolm = true,
    int? joinedCount = 2,
    int? invitedCount = 0,
    PeerMembership peerMembership = PeerMembership.join,
  }) =>
      RoomFacts(
        id: id,
        membership: RoomMembership.join,
        peerId: peer,
        megolm: megolm,
        joinedCount: joinedCount,
        invitedCount: invitedCount,
        peerMembership: peerMembership,
      );

  RoomFacts invite({String? from = ben, bool direct = false, bool book = false, String? rule}) => RoomFacts(
        id: '!x:hs.example',
        membership: RoomMembership.invite,
        inviterId: from,
        inviteIsDirect: direct,
        isBook: book,
        joinRule: rule,
      );

  group('beigetretene Räume', () {
    test('Kontrollfall: m.direct mit beigetretenem Mitglied, Megolm, zwei Personen: Einzelchat der Familie', () {
      expect(ConversationPolicy.classify(joined(), ctx), RoomClass.familyDirect);
    });

    test('Familienraum und privater Raum haben Vorrang, auch mit m.direct auf Mitglied', () {
      expect(ConversationPolicy.classify(joined(id: family), ctx), RoomClass.family);
      expect(ConversationPolicy.classify(joined(id: priv), ctx), RoomClass.private);
    });

    test('jede Einzelbedingung verhindert den Einzelchat', () {
      final cases = <String, RoomFacts>{
        'kein m.direct': joined(peer: null),
        'Gegenüber ich selbst': joined(peer: me),
        'Gegenüber kein Mitglied': joined(peer: fremd),
        'kein Megolm': joined(megolm: false),
        'drei Personen': joined(joinedCount: 3),
        'zwei und ein Eingeladener': joined(invitedCount: 1),
        'beigetretene Zahl unbekannt (fail-closed)': joined(joinedCount: null),
      };
      for (final e in cases.entries) {
        expect(ConversationPolicy.classify(e.value, ctx), RoomClass.ignored, reason: e.key);
      }
    });

    test('unbekannte Zahl Eingeladener zählt als 0; eine Person allein ist ein Paar', () {
      expect(ConversationPolicy.classify(joined(invitedCount: null), ctx), RoomClass.familyDirect);
      expect(ConversationPolicy.classify(joined(joinedCount: 1), ctx), RoomClass.familyDirect);
    });

    test('Mitgliederliste unvollständig: kein Einzelchat (B6)', () {
      const partial = PolicyContext(myUserId: me, joinedMembers: <String>{me, ben}, membersLoaded: false);
      expect(ConversationPolicy.classify(joined(), partial), RoomClass.ignored);
    });

    test('ein Gegenüber, das nur eingeladen oder entfernt ist, ist kein Mitglied: kein Einzelchat', () {
      const noBen = PolicyContext(myUserId: me, joinedMembers: <String>{me}, membersLoaded: true);
      expect(ConversationPolicy.classify(joined(), noBen), RoomClass.ignored);
    });

    test('verlassene, gebannte oder angeklopfte Räume zählen nie', () {
      const other = RoomFacts(id: '!x', membership: RoomMembership.other, peerId: ben, megolm: true, joinedCount: 2);
      expect(ConversationPolicy.classify(other, ctx), RoomClass.ignored);
    });
  });

  group('Einladungen', () {
    test('knock und fehlende Angabe: Familieneinladung (unabhängig von Liste und Familie)', () {
      const noFamily = PolicyContext(myUserId: me);
      for (final rule in <String?>['knock', null]) {
        expect(ConversationPolicy.classify(invite(rule: rule), noFamily), RoomClass.familyInvite, reason: '$rule');
        expect(ConversationPolicy.classify(invite(rule: rule), ctx), RoomClass.familyInvite, reason: '$rule');
      }
    });

    test('jede andere Beitrittsregel ist keine Familieneinladung (in K2a auch keine Kontaktanfrage)', () {
      for (final rule in <String>['invite', 'public', 'restricted', 'knock_restricted', 'Knock', '']) {
        expect(ConversationPolicy.classify(invite(rule: rule), ctx), RoomClass.ignored, reason: rule);
      }
    });

    test('Buch-Einladung und Einladung in einen Einzelchat sind nie eine Familieneinladung, auch mit knock', () {
      expect(ConversationPolicy.classify(invite(book: true, rule: 'knock'), ctx), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(direct: true, rule: 'knock'), ctx), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(book: true), ctx), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(direct: true), ctx), RoomClass.ignored);
    });
  });

  group('automatische Annahme von Einzelchat-Einladungen', () {
    test('Kontrollfall: is_direct von einem beigetretenen Mitglied bei geladener Liste', () {
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true), ctx), isTrue);
    });

    test('nie: ohne is_direct, Fremder, ich selbst, ohne Absender, Identitätswechsel, Liste unvollständig, beigetretener Raum', () {
      expect(ConversationPolicy.autoAcceptDirect(invite(), ctx), isFalse, reason: 'ohne is_direct');
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true, from: fremd), ctx), isFalse, reason: 'Fremder');
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true, from: me), ctx), isFalse, reason: 'ich selbst');
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true, from: null), ctx), isFalse, reason: 'ohne Absender');
      const changed = PolicyContext(myUserId: me, joinedMembers: <String>{me, ben}, membersLoaded: true, identityChanged: <String>{ben});
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true), changed), isFalse, reason: 'Identitätswechsel');
      const partial = PolicyContext(myUserId: me, joinedMembers: <String>{me, ben}, membersLoaded: false);
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true), partial), isFalse, reason: 'Liste unvollständig');
      expect(ConversationPolicy.autoAcceptDirect(joined(), ctx), isFalse, reason: 'kein Einladungszustand');
    });

    test('nur Einladungen: ein beigetretener Raum mit gesetztem is_direct wird nie „angenommen“', () {
      const j = RoomFacts(id: '!x', membership: RoomMembership.join, inviterId: ben, inviteIsDirect: true);
      expect(ConversationPolicy.autoAcceptDirect(j, ctx), isFalse);
    });

    test('keine Prüfung auf Buch (wie bisher: Buch-Einladungen tragen kein is_direct)', () {
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true, book: true), ctx), isTrue);
    });
  });

  test('Kontakt-Klassen liefert die Einstufung bei ausgeschaltetem Bereich nie, für keine Kombination', () {
    final facts = <RoomFacts>[
      for (final m in RoomMembership.values)
        for (final peer in <String?>[null, ben, fremd, me])
          for (final megolm in <bool>[true, false])
            for (final count in <int?>[null, 1, 2, 3])
              for (final rule in <String?>[null, 'knock', 'invite', 'public'])
                for (final direct in <bool>[true, false])
                  for (final book in <bool>[true, false])
                    RoomFacts(
                      id: '!r',
                      membership: m,
                      peerId: peer,
                      megolm: megolm,
                      joinedCount: count,
                      joinRule: rule,
                      inviteIsDirect: direct,
                      isBook: book,
                      inviterId: peer,
                    ),
    ];
    const contact = <RoomClass>{RoomClass.contactDirect, RoomClass.contactGroup, RoomClass.contactRequest};
    for (final f in facts) {
      expect(contact.contains(ConversationPolicy.classify(f, ctx)), isFalse);
    }
  });

  // ----------------------------------------------------------------------------- K3a-1: Kontaktklassen
  const carla = '@carla:other.example';
  const dora = '@dora:other.example';

  PolicyContext cc({
    bool enabled = true,
    bool loaded = true,
    Map<String, ContactState> contacts = const <String, ContactState>{carla: ContactState.accepted},
    Set<String> blocked = const <String>{},
    Set<String> family = const <String>{me, ben},
    Set<String> identity = const <String>{},
    Set<String> joinedMembers = const <String>{me, ben},
  }) =>
      PolicyContext(
        myUserId: me,
        familyRoomId: '!familie:hs.example',
        privateRoomId: priv,
        joinedMembers: joinedMembers,
        membersLoaded: loaded,
        identityChanged: identity,
        contactsEnabled: enabled,
        contacts: contacts,
        blockedUsers: blocked,
        familyIds: family,
      );

  group('contactDirect', () {
    test('mit Bereich, eigenem Datensatz, Megolm und zwei Personen', () {
      expect(ConversationPolicy.classify(joined(peer: carla), cc()), RoomClass.contactDirect);
      expect(ConversationPolicy.classify(joined(peer: carla), cc(contacts: {carla: ContactState.outgoing})), RoomClass.contactDirect,
          reason: 'wartet auf Annahme (§8.2, bewusste Abweichung von §6.2)');
    });

    test('jede Bedingung einzeln', () {
      final cases = <String, PolicyContext>{
        'Bereich aus': cc(enabled: false),
        'Liste unvollständig': cc(loaded: false),
        'kein Datensatz': cc(contacts: const <String, ContactState>{}),
        'Datensatz blockiert': cc(contacts: {carla: ContactState.blocked}),
        'lokal blockiert': cc(blocked: {carla}),
        'Familienmitglied (beigetreten, mit Datensatz)': cc(contacts: {ben: ContactState.accepted}),
      };
      for (final e in cases.entries) {
        final peer = e.key.startsWith('Familienmitglied') ? ben : carla;
        expect(ConversationPolicy.classify(joined(peer: peer), e.value), isNot(RoomClass.contactDirect), reason: e.key);
      }
      expect(ConversationPolicy.classify(joined(peer: carla, megolm: false), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(joined(peer: carla, joinedCount: 3), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(joined(peer: carla, joinedCount: null), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(joined(peer: me), cc(contacts: {me: ContactState.accepted})), RoomClass.ignored);
      expect(ConversationPolicy.classify(joined(peer: null), cc()), RoomClass.ignored);
    });

    test('Gegenüber muss im Raum sein: beigetreten ja, abgelehnt/verlassen (other) und unbekannt nie', () {
      expect(ConversationPolicy.classify(joined(peer: carla, peerMembership: PeerMembership.join), cc()), RoomClass.contactDirect);
      expect(ConversationPolicy.classify(joined(peer: carla, peerMembership: PeerMembership.other), cc()), RoomClass.ignored,
          reason: 'Gegenüber ging, ein Dritter ist beigetreten (m.direct zeigt weiter auf das Gegenüber)');
      expect(ConversationPolicy.classify(joined(peer: carla, peerMembership: PeerMembership.unknown), cc()), RoomClass.ignored,
          reason: 'Zustand nicht geladen: fail-closed');
    });

    test('Gegenüber nur eingeladen: wartend nur bei outgoing, nie bei accepted', () {
      expect(ConversationPolicy.classify(joined(peer: carla, peerMembership: PeerMembership.invite, joinedCount: 1, invitedCount: 1), cc(contacts: {carla: ContactState.outgoing})),
          RoomClass.contactDirect);
      expect(ConversationPolicy.classify(joined(peer: carla, peerMembership: PeerMembership.invite, joinedCount: 1, invitedCount: 1), cc()), RoomClass.ignored,
          reason: 'accepted verlangt ein beigetretenes Gegenüber');
    });

    test('Standard von RoomFacts.peerMembership ist unknown (fail-closed)', () {
      const f = RoomFacts(id: '!x', membership: RoomMembership.join, peerId: carla, megolm: true, joinedCount: 2, invitedCount: 0);
      expect(f.peerMembership, PeerMembership.unknown);
      expect(ConversationPolicy.classify(f, cc()), RoomClass.ignored);
    });

    test('ich selbst bin nie ein Kontakt, auch wenn ich nicht in familyIds stehe', () {
      final c = cc(family: {ben}, contacts: {me: ContactState.accepted});
      expect(ConversationPolicy.classify(joined(peer: me), c), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: me, direct: true), cc(family: {ben})), RoomClass.ignored);
      expect(ConversationPolicy.autoAcceptContact(invite(from: me, direct: true), c), isFalse);
    });

    test('Vorrang der Familie unabhängig von familyIds: beigetretenes Mitglied mit Kontaktdatensatz ist familyDirect', () {
      final c = cc(family: const <String>{}, contacts: {ben: ContactState.outgoing});
      expect(ConversationPolicy.classify(joined(peer: ben), c), RoomClass.familyDirect);
    });

    test('die Familie hat Vorrang: Mitglied mit Kontaktdatensatz bleibt familyDirect; ohne Megolm ignoriert', () {
      final ctxBen = cc(contacts: {ben: ContactState.blocked});
      expect(ConversationPolicy.classify(joined(peer: ben), ctxBen), RoomClass.familyDirect);
      expect(ConversationPolicy.classify(joined(peer: ben, megolm: false), ctxBen), RoomClass.ignored);
    });

    test('eingeladenes oder angefragtes Familienmitglied ist nie ein Kontakt', () {
      final c = cc(family: {me, ben, dora}, contacts: {dora: ContactState.accepted});
      expect(ConversationPolicy.classify(joined(peer: dora), c), RoomClass.ignored);
    });

    test('ein entferntes Mitglied (nicht in familyIds) gilt als Fremder: nur mit ausdrücklichem Datensatz', () {
      final c = cc(contacts: {dora: ContactState.accepted});
      expect(ConversationPolicy.classify(joined(peer: dora), c), RoomClass.contactDirect);
      expect(ConversationPolicy.classify(joined(peer: dora), cc()), RoomClass.ignored);
    });
  });

  group('contactRequest', () {
    test('Einladung mit is_direct von einem Fremden ohne Datensatz', () {
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), cc()), RoomClass.contactRequest);
    });

    test('jede Bedingung einzeln', () {
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), cc(enabled: false)), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), cc(loaded: false)), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), cc(blocked: {dora})), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), cc(contacts: {dora: ContactState.blocked})), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: me, direct: true), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: null, direct: true), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: dora, direct: true, book: true), cc()), RoomClass.ignored);
      // K4-1: ohne is_direct und mit Regel invite ist es eine Gruppenanfrage (vorher ignored); ohne Regel nie eine Anfrage.
      expect(ConversationPolicy.classify(invite(from: dora, rule: 'invite'), cc()), RoomClass.contactRequest, reason: 'Gruppenanfrage (K4-1)');
      expect(ConversationPolicy.classify(invite(from: dora), cc()), isNot(RoomClass.contactRequest));
    });

    test('bekannter Kontakt: keine Anfrage (die Annahme übernimmt autoAcceptContact)', () {
      expect(ConversationPolicy.classify(invite(from: carla, direct: true), cc()), RoomClass.ignored);
    });

    test('Familienmitglied in jedem Status ist keine Anfrage', () {
      final c = cc(family: {me, ben, dora});
      expect(ConversationPolicy.classify(invite(from: dora, direct: true), c), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: ben, direct: true), c), RoomClass.ignored);
    });

    test('bei bekannter Zählung nur ein Paar', () {
      const big = RoomFacts(id: '!g', membership: RoomMembership.invite, inviterId: dora, inviteIsDirect: true, joinedCount: 3);
      const pair = RoomFacts(id: '!g', membership: RoomMembership.invite, inviterId: dora, inviteIsDirect: true, joinedCount: 1);
      expect(ConversationPolicy.classify(big, cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(pair, cc()), RoomClass.contactRequest);
    });

    test('ein gelöschter Kontakt (Löschmarke fehlt in contacts) wird wieder zur Anfrage', () {
      expect(ConversationPolicy.classify(invite(from: carla, direct: true), cc(contacts: const <String, ContactState>{})), RoomClass.contactRequest);
    });

    // K4-1 (Planung §5a): vor K4 war eine Einladung ohne is_direct und mit join_rule invite `ignored`. Seit K4-1 ist sie eine
    // Gruppenanfrage (Anhang A Z. 7, Wahrheitstafel unten); die Aussage „nie Annahme“ (D1: Gruppen nie automatisch) und
    // „ohne Regel keine Anfrage“ bleiben unverändert.
    test('Einladung ohne is_direct von einem eigenen Kontakt wird nie automatisch angenommen (Gruppenanfrage, K4-1)', () {
      expect(ConversationPolicy.classify(invite(from: carla, rule: 'invite'), cc()), RoomClass.contactRequest);
      expect(ConversationPolicy.classify(invite(from: carla), cc()), isNot(RoomClass.contactRequest), reason: 'ohne Regel keine Anfrage');
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla), cc()), isFalse);
    });
  });

  group('autoAcceptContact', () {
    test('nur für einen eigenen Datensatz outgoing/accepted', () {
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc()), isTrue);
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(contacts: {carla: ContactState.outgoing})), isTrue);
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(contacts: {carla: ContactState.blocked})), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: dora, direct: true), cc()), isFalse, reason: 'ohne Datensatz nie ohne Tipp (I6)');
    });

    test('jede Bedingung einzeln', () {
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(enabled: false)), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(loaded: false)), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(blocked: {carla})), isFalse);
      // K3c-1 (Revision K3b-1, bewusst gedreht, ersetzt durch den Gatewaytest 7B „Einladung der Gegenseite bei identityChanged“):
      // ein geänderter Schlüssel verhindert die Annahme nicht mehr (Pin-Sackgasse Variante B); die Sendesperre trägt den Schutz.
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(identity: {carla})), isTrue,
          reason: 'identityChanged hindert die Annahme eines eigenen Kontakts nicht mehr');
      expect(ConversationPolicy.autoAcceptContact(invite(from: dora, direct: true), cc(identity: {dora})), isFalse, reason: 'ohne Datensatz weiter nie');
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(identity: {carla}, blocked: {carla})), isFalse, reason: 'blockiert weiter nie');
      expect(ConversationPolicy.autoAcceptContact(invite(from: ben, direct: true), cc(contacts: {ben: ContactState.accepted}, identity: {ben})), isFalse,
          reason: 'Familienmitglied nie, auch mit identityChanged (dort gilt autoAcceptDirect, E-37)');
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true, book: true), cc()), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: null, direct: true), cc()), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: me, direct: true), cc(contacts: {me: ContactState.accepted})), isFalse);
      expect(ConversationPolicy.autoAcceptContact(invite(from: ben, direct: true), cc(contacts: {ben: ContactState.accepted})), isFalse,
          reason: 'Familienmitglied nie');
      const joinedRoom = RoomFacts(id: '!x', membership: RoomMembership.join, inviterId: carla, inviteIsDirect: true);
      expect(ConversationPolicy.autoAcceptContact(joinedRoom, cc()), isFalse);
    });
  });

  test('ohne eingeschalteten Bereich nie eine Kontaktklasse und nie eine Annahme, auch nicht mit allen Daten', () {
    final c = cc(enabled: false, contacts: {carla: ContactState.accepted, dora: ContactState.outgoing});
    for (final m in RoomMembership.values) {
      for (final peer in <String?>[null, ben, carla, dora, me]) {
        for (final direct in <bool>[true, false]) {
          final f = RoomFacts(
            id: '!r',
            membership: m,
            peerId: peer,
            inviterId: peer,
            inviteIsDirect: direct,
            megolm: true,
            joinedCount: 2,
          );
          final k = ConversationPolicy.classify(f, c);
          expect(k == RoomClass.contactDirect || k == RoomClass.contactRequest || k == RoomClass.contactGroup, isFalse);
          expect(ConversationPolicy.autoAcceptContact(f, c), isFalse);
        }
      }
    }
  });

  test('mit Bereich: Familienmitglieder werden nie zu einer Kontaktklasse, in keiner Kombination', () {
    final c = cc(contacts: {ben: ContactState.accepted, dora: ContactState.outgoing}, family: {me, ben, dora});
    for (final m in RoomMembership.values) {
      for (final peer in <String>[ben, dora]) {
        for (final direct in <bool>[true, false]) {
          final f = RoomFacts(id: '!r', membership: m, peerId: peer, inviterId: peer, inviteIsDirect: direct, megolm: true, joinedCount: 2);
          final k = ConversationPolicy.classify(f, c);
          expect(k == RoomClass.contactDirect || k == RoomClass.contactRequest, isFalse, reason: '$m $peer $direct');
          expect(ConversationPolicy.autoAcceptContact(f, c), isFalse);
        }
      }
    }
  });

  test('bei unvollständiger Liste (familyIds leer, membersLoaded falsch) nie eine Kontaktklasse', () {
    final c = cc(loaded: false, family: const <String>{});
    expect(ConversationPolicy.classify(joined(peer: carla), c), RoomClass.ignored);
    expect(ConversationPolicy.classify(invite(from: dora, direct: true), c), RoomClass.ignored);
    expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), c), isFalse);
  });

  group('ContactScope.membersComplete', () {
    test('Wahrheitstabelle (alle 16 Kombinationen)', () {
      for (final hasFamily in <bool>[true, false]) {
        for (final loaded in <bool>[true, false]) {
          for (final synced in <bool>[true, false]) {
            for (final resolved in <bool>[true, false]) {
              final expected = hasFamily ? loaded : (synced && resolved);
              expect(
                ContactScope.membersComplete(hasFamily: hasFamily, participantsLoaded: loaded, syncedOnce: synced, familyResolved: resolved),
                expected,
                reason: 'Familie=$hasFamily geladen=$loaded sync=$synced ermittelt=$resolved',
              );
            }
          }
        }
      }
    });

    test('ohne Familie nie vollständig, solange die Familie nicht ermittelt oder nicht synchronisiert ist', () {
      expect(ContactScope.membersComplete(hasFamily: false, participantsLoaded: true, syncedOnce: false, familyResolved: true), isFalse);
      expect(ContactScope.membersComplete(hasFamily: false, participantsLoaded: true, syncedOnce: true, familyResolved: false), isFalse);
      expect(ContactScope.membersComplete(hasFamily: false, participantsLoaded: false, syncedOnce: true, familyResolved: true), isTrue);
    });
  });

  group('ContactScope.familyResolved (K3c-1)', () {
    // (Zeiger, Raum bekannt, Mitgliedschaft, gebaut, row2Settled) je Tabellenzeile; Erwartung für fresh true / false.
    final rows = <String, (bool, bool, RoomMembership?, bool, bool?, bool, bool)>{
      '1 Zeiger fehlt': (false, false, null, false, null, true, false),
      '2 Zeiger gesetzt, Raum unbekannt, nicht settled': (true, false, null, false, false, false, false),
      '2 Zeiger gesetzt, Raum unbekannt, settled': (true, false, null, false, true, true, false),
      '3 Raum bekannt, Einladung': (true, true, RoomMembership.invite, false, null, true, false),
      '4 Raum bekannt, verlassen/verbannt/angeklopft': (true, true, RoomMembership.other, false, null, true, false),
      '5 beigetreten, Familie nicht gebaut': (true, true, RoomMembership.join, false, null, false, false),
      '6 beigetreten, Familie gebaut': (true, true, RoomMembership.join, true, null, true, true),
    };
    for (final e in rows.entries) {
      final (pointer, known, membership, built, settled, whenFresh, whenStale) = e.value;
      for (final fresh in <bool>[true, false]) {
        test('${e.key}, fresh=$fresh', () {
          expect(
            ContactScope.familyResolved(
              pointerSet: pointer,
              roomKnown: known,
              membership: membership,
              familyBuilt: built,
              accountDataFresh: fresh,
              row2Settled: settled ?? false,
            ),
            fresh ? whenFresh : whenStale,
          );
        });
      }
    }

    test('row2Settled wirkt nur in Zeile 2 und nur mit fresh', () {
      for (final settled in <bool>[true, false]) {
        expect(ContactScope.familyResolved(pointerSet: false, roomKnown: false, membership: null, familyBuilt: false, accountDataFresh: true, row2Settled: settled), isTrue);
        expect(ContactScope.familyResolved(pointerSet: true, roomKnown: true, membership: RoomMembership.join, familyBuilt: false, accountDataFresh: true, row2Settled: settled), isFalse);
        expect(ContactScope.familyResolved(pointerSet: true, roomKnown: false, membership: null, familyBuilt: false, accountDataFresh: false, row2Settled: settled), isFalse);
      }
    });
  });


  // ----------------------------------------------------------------------------- K4-1: Gruppen (Anhang A der Planung)
  const grp = '!gruppe:hs.example';
  const gruppenCtx = PolicyContext(
    myUserId: me,
    familyRoomId: '!familie:hs.example',
    privateRoomId: priv,
    joinedMembers: <String>{me, ben},
    membersLoaded: true,
    contactsEnabled: true,
    familyIds: <String>{me, ben},
    groups: <String>{grp},
  );

  PolicyContext gc({
    bool enabled = true,
    bool loaded = true,
    Set<String> groups = const <String>{grp},
    Set<String> blocked = const <String>{},
    Set<String> family = const <String>{me, ben},
  }) =>
      PolicyContext(
        myUserId: me,
        familyRoomId: '!familie:hs.example',
        privateRoomId: priv,
        joinedMembers: const <String>{me, ben},
        membersLoaded: loaded,
        contactsEnabled: enabled,
        blockedUsers: blocked,
        familyIds: family,
        groups: groups,
      );

  RoomFacts groupJoined({
    String id = grp,
    String? peer,
    bool megolm = true,
    int? joinedCount = 3,
    int? invitedCount = 0,
    String? rule = 'invite',
    PeerMembership peerMembership = PeerMembership.unknown,
  }) =>
      RoomFacts(
        id: id,
        membership: RoomMembership.join,
        peerId: peer,
        megolm: megolm,
        joinedCount: joinedCount,
        invitedCount: invitedCount,
        joinRule: rule,
        peerMembership: peerMembership,
      );

  RoomFacts groupInvite({String id = grp, String? from = carla, String? rule = 'invite', bool direct = false, bool book = false}) => RoomFacts(
        id: id,
        membership: RoomMembership.invite,
        inviterId: from,
        inviteIsDirect: direct,
        isBook: book,
        joinRule: rule,
      );

  group('Gruppen (K4-1, Wahrheitstafel Anhang A, jede Zeile ein Test)', () {
    RoomClass k(RoomFacts f, PolicyContext c) => ConversationPolicy.classify(f, c);

    test('Z. 1: Familienraum und privater Raum haben Vorrang vor der Gruppe, auch mit Datensatz', () {
      final c = gc(groups: const <String>{grp, '!familie:hs.example', priv});
      expect(k(groupJoined(id: '!familie:hs.example'), c), RoomClass.family);
      expect(k(groupJoined(id: priv), c), RoomClass.private);
    });

    test('Z. 2: beigetreten mit Datensatz ist contactGroup, unabhängig von Größe, Regel, Verlauf, Megolm und peerId', () {
      expect(k(groupJoined(), gc()), RoomClass.contactGroup);
      for (final f in <String, RoomFacts>{
        'zu groß (51)': groupJoined(joinedCount: 51),
        '40 + 30 eingeladen': groupJoined(joinedCount: 40, invitedCount: 30),
        'Größe unbekannt': groupJoined(joinedCount: null, invitedCount: null),
        'Regel public': groupJoined(rule: 'public'),
        'Regel knock': groupJoined(rule: 'knock'),
        'Regel null': groupJoined(rule: null),
        'unverschlüsselt': groupJoined(megolm: false),
        'allein (nur ich)': groupJoined(joinedCount: 1),
      }.entries) {
        expect(k(f.value, gc()), RoomClass.contactGroup, reason: f.key);
      }
    });

    test('Z. 3: ohne Datensatz bleibt der Einzelchat mit Familienmitglied familyDirect', () {
      final f = RoomFacts(id: '!dm:hs.example', membership: RoomMembership.join, peerId: ben, megolm: true, joinedCount: 2, invitedCount: 0);
      expect(k(f, gc()), RoomClass.familyDirect);
      expect(k(f, gc(groups: const <String>{})), RoomClass.familyDirect);
    });

    test('Z. 4: ohne Datensatz bleibt der Kontakt-Einzelchat contactDirect', () {
      final f = RoomFacts(
        id: '!dm:hs.example',
        membership: RoomMembership.join,
        peerId: carla,
        megolm: true,
        joinedCount: 2,
        invitedCount: 0,
        peerMembership: PeerMembership.join,
      );
      final c = PolicyContext(
        myUserId: me,
        membersLoaded: true,
        contactsEnabled: true,
        contacts: const <String, ContactState>{carla: ContactState.accepted},
        familyIds: const <String>{me, ben},
        groups: const <String>{grp},
      );
      expect(k(f, c), RoomClass.contactDirect);
    });

    test('Z. 5: ohne Datensatz ist ein beigetretener Mehrpersonenraum ignored (nie von selbst eine Gruppe)', () {
      expect(k(groupJoined(), gc(groups: const <String>{})), RoomClass.ignored);
      expect(k(groupJoined(id: '!andere:hs.example'), gc()), RoomClass.ignored);
    });

    test('Z. 6: der Datensatz gewinnt gegen m.direct (peerId), auch gegen Familie und Kontakt als Gegenüber', () {
      for (final peer in <String>[ben, carla, fremd]) {
        expect(k(groupJoined(peer: peer, joinedCount: 2, peerMembership: PeerMembership.join), gc()), RoomClass.contactGroup, reason: peer);
      }
    });

    test('Z. 7: Einladung mit join_rule invite ist eine Gruppenanfrage, auch von einem Familienmitglied (D5)', () {
      expect(k(groupInvite(), gc()), RoomClass.contactRequest);
      expect(k(groupInvite(from: ben), gc()), RoomClass.contactRequest, reason: 'Familienmitglied darf einladen');
    });

    test('Z. 7b: Einladung mit Datensatz (Absturzfall D2) bleibt Anfrage, nie ignored und nie beigetreten', () {
      expect(k(groupInvite(), gc(groups: const <String>{grp})), RoomClass.contactRequest);
      expect(k(groupInvite(), gc(groups: const <String>{})), RoomClass.contactRequest, reason: 'der Datensatz ändert bei Einladungen nichts');
      expect(k(groupInvite(from: me), gc()), RoomClass.ignored, reason: '7b mit Einladendem ich: wie Z. 8');
      expect(k(groupInvite(from: carla), gc(blocked: const <String>{carla})), RoomClass.ignored, reason: '7b mit Blockiertem: wie Z. 8');
    });

    test('Z. 8: Einladender blockiert, ich oder unbekannt ⇒ ignored', () {
      expect(k(groupInvite(from: carla), gc(blocked: const <String>{carla})), RoomClass.ignored);
      expect(k(groupInvite(from: me), gc()), RoomClass.ignored);
      expect(k(groupInvite(from: null), gc()), RoomClass.ignored);
    });

    test('Z. 9: knock bleibt familyInvite, nie eine Gruppenanfrage', () {
      expect(k(groupInvite(rule: 'knock'), gc()), RoomClass.familyInvite);
      expect(k(groupInvite(rule: 'knock', from: carla), gc(groups: const <String>{})), RoomClass.familyInvite);
    });

    test('Z. 10: fehlende Regel bleibt familyInvite, mit und ohne Familie (Nutzerentscheidung 5)', () {
      expect(k(groupInvite(rule: null), gc()), RoomClass.familyInvite);
      expect(k(groupInvite(rule: null), gc(family: const <String>{})), RoomClass.familyInvite);
      expect(k(groupInvite(rule: null), const PolicyContext(myUserId: me)), RoomClass.familyInvite);
    });

    test('Z. 11: andere Regeln (public, restricted, …) ⇒ ignored', () {
      for (final rule in <String>['public', 'restricted', 'knock_restricted', 'Invite', '']) {
        expect(k(groupInvite(rule: rule), gc()), RoomClass.ignored, reason: rule);
      }
    });

    test('Z. 12: Buch-Einladung ist nie eine Gruppenanfrage', () {
      expect(k(groupInvite(book: true), gc()), RoomClass.ignored);
    });

    test('Z. 13: Einladung in einen Einzelchat bleibt wie K3 (nie eine Gruppenanfrage über die Gruppenzeile)', () {
      expect(k(groupInvite(direct: true, rule: 'invite', from: carla), gc()), RoomClass.contactRequest, reason: 'Einzelchat-Anfrage wie K3');
      expect(k(groupInvite(direct: true, rule: 'invite', from: ben), gc()), RoomClass.ignored, reason: 'Einzelchat: Familie nie (K3)');
      expect(k(groupInvite(direct: true, rule: 'knock'), gc()), RoomClass.contactRequest, reason: 'die Regel ist bei Einzelchats unerheblich (K3)');
    });

    test('Bereich aus oder Liste unvollständig: nie eine Gruppenklasse (I1, B6)', () {
      for (final c in <PolicyContext>[gc(enabled: false), gc(loaded: false)]) {
        expect(k(groupJoined(), c), RoomClass.ignored);
        expect(k(groupJoined(peer: carla), c), isNot(RoomClass.contactGroup));
        expect(k(groupInvite(), c), RoomClass.ignored, reason: 'Gruppenanfrage nur mit Bereich und Liste');
      }
    });

    test('ohne Bereich nie eine Gruppenklasse in keiner Kombination', () {
      final c = gc(enabled: false);
      for (final m in RoomMembership.values) {
        for (final rule in <String?>[null, 'invite', 'knock', 'public']) {
          final f = RoomFacts(id: grp, membership: m, inviterId: carla, megolm: true, joinedCount: 3, joinRule: rule);
          final r = ConversationPolicy.classify(f, c);
          expect(r == RoomClass.contactGroup || r == RoomClass.contactRequest, isFalse, reason: '$m $rule');
        }
      }
    });

    test('eine Gruppeneinladung ist nie eine Familieneinladung, wenn der Server join_rules liefert (Abnahme 9)', () {
      for (final c in <PolicyContext>[gc(), gc(enabled: false), gc(loaded: false), gc(family: const <String>{})]) {
        expect(k(groupInvite(rule: 'invite'), c), isNot(RoomClass.familyInvite));
      }
    });

    test('PolicyContext.groups hat den Standard leer (Bestandscode unverändert)', () {
      expect(const PolicyContext(myUserId: me).groups, isEmpty);
      expect(gruppenCtx.groups, <String>{grp});
    });
  });

}
