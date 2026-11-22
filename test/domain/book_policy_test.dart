import 'package:family_nexus/data/matrix/book_room_spec.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';

/// #311, E-113: Regeln für Einladen, Annehmen, Sendeschutz und Abgleich, Raumbeschreibung und Nachprüfung.
void main() {
  const me = '@anna:hs.test';
  const cara = '@cara:hs.test';
  const ben = '@ben:hs.test';
  const dora = '@dora:hs.test';

  FamilyMember member(String id, {Role role = Role.member, MemberStatus status = MemberStatus.joined, IdentityStatus identity = IdentityStatus.pinned}) =>
      FamilyMember(userId: id, displayName: id, role: role, status: status, identity: identity);

  Family family(List<FamilyMember> m) => Family(roomId: '!f:hs.test', name: 'F', members: m, myUserId: me);

  final f = family(<FamilyMember>[
    member(me, role: Role.moderator),
    member(cara, role: Role.moderator),
    member(ben),
    member(dora, role: Role.moderator, status: MemberStatus.invited),
    member('@eva:hs.test', role: Role.moderator, identity: IdentityStatus.changed),
  ]);

  group('canInvite', () {
    test('nur beigetretene Moderatoren der Familie, nicht ich selbst, Identität nicht geändert', () {
      expect(BookPolicy.canInvite(f, cara), isTrue);
      expect(BookPolicy.canInvite(f, ben), isFalse, reason: 'Mitglied');
      expect(BookPolicy.canInvite(f, dora), isFalse, reason: 'nur eingeladen');
      expect(BookPolicy.canInvite(f, '@eva:hs.test'), isFalse, reason: 'Identität geändert');
      expect(BookPolicy.canInvite(f, me), isFalse, reason: 'ich selbst');
      expect(BookPolicy.canInvite(f, '@fremd:hs.test'), isFalse, reason: 'nicht in der Familie');
      expect(BookPolicy.canInvite(null, cara), isFalse, reason: 'Familie unbekannt');
    });
  });

  group('mayAccept', () {
    test('Einladender == Ersteller und beigetretener Moderator meiner Familie', () {
      expect(BookPolicy.mayAccept(f, inviterId: cara, creatorId: cara), isTrue);
      expect(BookPolicy.mayAccept(f, inviterId: cara, creatorId: me), isFalse, reason: 'Einladender nicht Ersteller');
      expect(BookPolicy.mayAccept(f, inviterId: ben, creatorId: ben), isFalse, reason: 'Mitglied');
      expect(BookPolicy.mayAccept(f, inviterId: '@fremd:hs.test', creatorId: '@fremd:hs.test'), isFalse, reason: 'Fremder');
      expect(BookPolicy.mayAccept(f, inviterId: cara, creatorId: null), isFalse, reason: 'Ersteller unbekannt');
      expect(BookPolicy.mayAccept(null, inviterId: cara, creatorId: cara), isFalse, reason: 'Familie unbekannt');
    });
  });

  group('unauthorized', () {
    test('beigetretene und eingeladene Mitglieder, die kein Moderator der Familie sind; ich zähle nie', () {
      final bad = BookPolicy.unauthorized(<BookMember>[
        const BookMember(me, BookMembership.joined),
        const BookMember(cara, BookMembership.joined),
        const BookMember(ben, BookMembership.joined),
        const BookMember(dora, BookMembership.invited),
        const BookMember('@eva:hs.test', BookMembership.joined),
        const BookMember('@fremd:hs.test', BookMembership.invited),
      ], f, me: me);
      expect(bad, <String>[ben, dora, '@eva:hs.test', '@fremd:hs.test']);
    });

    test('leer, wenn alle berechtigt sind', () {
      expect(BookPolicy.unauthorized(<BookMember>[const BookMember(me, BookMembership.joined), const BookMember(cara, BookMembership.joined)], f, me: me), isEmpty);
    });
  });

  test('unauthorized: ich selbst zähle nie, auch wenn ich in der Familie kein Moderator bin', () {
    final asMember = family(<FamilyMember>[member(me), member(cara, role: Role.moderator)]);
    expect(BookPolicy.unauthorized(<BookMember>[const BookMember(me, BookMembership.joined)], asMember, me: me), isEmpty);
    expect(BookPolicy.unauthorized(<BookMember>[const BookMember(ben, BookMembership.joined)], asMember, me: me), <String>[ben]);
  });

  group('BookReconciler', () {
    test('erst der zweite übereinstimmende Durchlauf bestätigt', () {
      final r = BookReconciler();
      expect(r.observe('!b', <String>[ben, dora]), isEmpty);
      expect(r.observe('!b', <String>[ben]), <String>{ben}, reason: 'nur wer in beiden Durchläufen auffiel');
      expect(r.observe('!b', <String>[ben, dora]), <String>{ben});
    });

    test('wer zwischendurch nicht auffiel, beginnt von vorn; Räume sind unabhängig; reset und clear', () {
      final r = BookReconciler();
      r.observe('!b', <String>[ben]);
      expect(r.observe('!b', <String>[]), isEmpty);
      expect(r.observe('!b', <String>[ben]), isEmpty);
      r.observe('!c', <String>[ben]);
      expect(r.observe('!b', <String>[ben]), <String>{ben});
      r.reset('!b');
      expect(r.observe('!b', <String>[ben]), isEmpty);
      r.clear();
      expect(r.observe('!c', <String>[ben]), isEmpty);
    });
  });

  group('BookRoomSpec', () {
    const creator = '@anna:hs.test';

    test('Beschreibung: neutraler Name, invite, verschlüsselt, nur Ersteller lädt ein und ändert Zustand', () {
      expect(BookRoomSpec.name, 'FamilyNexus');
      final init = {for (final s in BookRoomSpec.initialState()) s.type: s.content};
      expect(init['m.room.encryption'], <String, Object?>{'algorithm': 'm.megolm.v1.aes-sha2'});
      expect(init['m.room.join_rules'], <String, Object?>{'join_rule': 'invite'});
      expect(init['m.room.history_visibility'], <String, Object?>{'history_visibility': 'shared'});
      final pl = BookRoomSpec.powerLevels(creator);
      expect(pl['users'], <String, int>{creator: 100});
      for (final k in <String>['invite', 'kick', 'ban', 'redact', 'state_default']) {
        expect(pl[k], 100, reason: k);
      }
      expect(pl['events_default'], 0);
      expect(pl['users_default'], 0);
      final events = pl['events']! as Map<String, int>;
      expect(events['m.room.tombstone'], 101, reason: 'unerreichbar');
      expect(events['m.room.server_acl'], 101);
      for (final k in <String>['m.room.power_levels', 'm.room.encryption', 'm.room.join_rules', 'm.room.history_visibility', 'm.room.name']) {
        expect(events[k], 100, reason: k);
      }
    });

    Map<String, Object?> goodPl() => BookRoomSpec.powerLevels(creator);

    bool verify({String? enc = 'm.megolm.v1.aes-sha2', String? hist = 'shared', String? rule = 'invite', Map<String, Object?>? pl, String c = creator}) =>
        BookRoomSpec.verifyJoined(
          encryptionAlgorithm: enc,
          historyVisibility: hist,
          joinRule: rule,
          powerLevels: pl ?? goodPl(),
          creatorId: c,
        );

    test('Nachprüfung nach dem Beitritt: der selbst erzeugte Zustand besteht', () {
      expect(verify(), isTrue);
    });

    test('jede Abweichung fällt durch', () {
      expect(verify(enc: null), isFalse);
      expect(verify(enc: 'm.olm.v1'), isFalse);
      expect(verify(hist: 'world_readable'), isFalse);
      expect(verify(rule: 'public'), isFalse);
      expect(verify(rule: 'knock'), isFalse);
      expect(verify(c: '@anderer:hs.test'), isFalse, reason: 'Ersteller hat nicht 100');
      expect(verify(pl: goodPl()..['users'] = <String, int>{creator: 50}), isFalse, reason: 'Ersteller nur Moderator');
      expect(verify(pl: goodPl()..['users'] = <String, int>{creator: 0}), isFalse, reason: 'Ersteller ohne Rechte');
      expect(verify(pl: goodPl()..['users'] = <String, int>{}), isFalse, reason: 'Ersteller fehlt in users');
      expect(verify(pl: goodPl()..['users'] = <String, Object?>{creator: 100, '@x:hs.test': 'viel'}), isFalse, reason: 'Wert kein int');
      expect(verify(pl: goodPl()..remove('users')), isFalse, reason: 'users fehlt');
      expect(
        BookRoomSpec.verifyJoined(
          encryptionAlgorithm: BookRoomSpec.megolm,
          historyVisibility: 'shared',
          joinRule: 'invite',
          powerLevels: null,
          creatorId: creator,
        ),
        isFalse,
      );
      for (final k in <String>['invite', 'kick', 'state_default']) {
        expect(verify(pl: goodPl()..[k] = 50), isFalse, reason: '$k nicht 100');
        expect(verify(pl: goodPl()..remove(k)), isFalse, reason: '$k fehlt');
      }
      expect(verify(pl: goodPl()..['events_default'] = 50), isFalse);
      expect(verify(pl: goodPl()..['users'] = <String, int>{creator: 100, '@zweit:hs.test': 100}), isFalse, reason: 'heimlicher Zweitverwalter');
      expect(verify(pl: goodPl()..['users'] = <String, int>{creator: 100, '@mod:hs.test': 50}), isFalse, reason: 'heimlicher Moderator');
      expect(verify(pl: goodPl()..['users'] = <String, int>{creator: 100, '@mitglied:hs.test': 0}), isTrue, reason: 'Mitglied mit 0 ist harmlos');
    });
  });
}
