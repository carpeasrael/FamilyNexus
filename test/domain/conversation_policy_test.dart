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
  }) =>
      RoomFacts(id: id, membership: RoomMembership.join, peerId: peer, megolm: megolm, joinedCount: joinedCount, invitedCount: invitedCount);

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
      expect(ConversationPolicy.classify(invite(from: dora, rule: 'invite'), cc()), RoomClass.ignored, reason: 'ohne is_direct (Gruppe, K4)');
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

    test('Einladung ohne is_direct von einem eigenen Kontakt ist nie Anfrage und nie Annahme', () {
      expect(ConversationPolicy.classify(invite(from: carla, rule: 'invite'), cc()), RoomClass.ignored);
      expect(ConversationPolicy.classify(invite(from: carla), cc()), isNot(RoomClass.contactRequest));
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
      expect(ConversationPolicy.autoAcceptContact(invite(from: carla, direct: true), cc(identity: {carla})), isFalse);
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
}
