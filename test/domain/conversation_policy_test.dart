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

    test('keine Prüfung auf Buch (wie bisher: Buch-Einladungen tragen kein is_direct)', () {
      expect(ConversationPolicy.autoAcceptDirect(invite(direct: true, book: true), ctx), isTrue);
    });
  });

  test('Kontakt-Klassen liefert die Einstufung in K2a nie, für keine Kombination', () {
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
}
