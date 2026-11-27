import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/contacts.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/group_rights.dart';
import 'package:flutter_test/flutter_test.dart';

/// #119, K4-1 (§3.6): Sendefähigkeit einer Gruppe aus dem Raumzustand und die Rechte-Regel. Reine Funktionen.
void main() {
  GroupSendLock health({
    bool megolm = true,
    String? rule = 'invite',
    String? history = 'invited',
    int? joined = 3,
    int? invited = 0,
  }) =>
      GroupHealth.evaluate(megolm: megolm, joinRule: rule, historyVisibility: history, joined: joined, invited: invited);

  group('GroupHealth (Größenmaß G = beigetreten + eingeladen)', () {
    test('Grenze: G = 50 ok, G = 51 gesperrt', () {
      expect(health(joined: 50, invited: 0), GroupSendLock.keiner);
      expect(health(joined: 51, invited: 0), GroupSendLock.zuGross);
      expect(health(joined: 1, invited: 0), GroupSendLock.keiner);
    });

    test('Eingeladene zählen mit: 40 + 30 gesperrt, 50 + 0 ok, 49 + 2 gesperrt, 48 + 2 ok', () {
      expect(health(joined: 40, invited: 30), GroupSendLock.zuGross);
      expect(health(joined: 50, invited: 0), GroupSendLock.keiner);
      expect(health(joined: 49, invited: 2), GroupSendLock.zuGross);
      expect(health(joined: 48, invited: 2), GroupSendLock.keiner);
    });

    test('unbekannte Einladungszahl zählt 0 (bewusst), unbekannte Beitrittszahl ist „Größe unbekannt“ (fail-closed)', () {
      expect(health(joined: 50, invited: null), GroupSendLock.keiner);
      expect(health(joined: 51, invited: null), GroupSendLock.zuGross);
      expect(health(joined: null, invited: 0), GroupSendLock.groesseUnbekannt);
      expect(health(joined: null, invited: null), GroupSendLock.groesseUnbekannt);
      expect(health(joined: null, invited: 30), GroupSendLock.groesseUnbekannt);
    });

    test('unverschlüsselt', () {
      expect(health(megolm: false), GroupSendLock.unverschluesselt);
    });

    test('Regel: alles außer invite sperrt (knock, public, restricted, null)', () {
      for (final r in <String?>['knock', 'public', 'restricted', 'knock_restricted', '', null]) {
        expect(health(rule: r), GroupSendLock.regelGeaendert, reason: '$r');
      }
    });

    test('Verlauf: alles außer invited sperrt (shared, world_readable, joined, null, unbekannt)', () {
      for (final h in <String?>['shared', 'world_readable', 'joined', 'irgendwas', '', null]) {
        expect(health(history: h), GroupSendLock.verlaufGeoeffnet, reason: '$h');
      }
    });

    test('Grund-Reihenfolge: Verschlüsselung, Regel, Verlauf, Größe unbekannt, zu groß', () {
      expect(health(megolm: false, rule: 'public', history: 'shared', joined: null), GroupSendLock.unverschluesselt);
      expect(health(rule: 'public', history: 'shared', joined: null), GroupSendLock.regelGeaendert);
      expect(health(history: 'shared', joined: null), GroupSendLock.verlaufGeoeffnet);
      expect(health(joined: null), GroupSendLock.groesseUnbekannt);
      expect(health(joined: 99), GroupSendLock.zuGross);
    });

    test('GroupHealth kennt keineMitglieder und wechsel nicht (setzt das Gateway)', () {
      final all = <GroupSendLock>{
        for (final j in <int?>[null, 1, 50, 51, 500])
          for (final m in <bool>[true, false])
            for (final r in <String?>['invite', 'public', null])
              for (final h in <String?>['invited', 'shared', null]) health(joined: j, megolm: m, rule: r, history: h),
      };
      expect(all, isNot(contains(GroupSendLock.keineMitglieder)));
      expect(all, isNot(contains(GroupSendLock.wechsel)));
      expect(GroupSendLock.values, hasLength(8));
      expect(GroupSendLock.values.first, GroupSendLock.keiner, reason: 'Standard „keiner“ = erlaubt');
    });

    test('size: G wie die Einladegrenze, null bei unbekannter Beitrittszahl', () {
      expect(GroupHealth.size(joined: 3, invited: 2), 5);
      expect(GroupHealth.size(joined: 3, invited: null), 3);
      expect(GroupHealth.size(joined: null, invited: 2), isNull);
    });
  });

  group('GroupRights', () {
    const me = '@ich:hs.example';
    const other = '@anna:hs.example';
    GroupRights r(int level, {int invite = 50, int kick = 50, int name = 50, int pl = 50}) =>
        GroupRights(myUserId: me, myLevel: level, inviteLevel: invite, kickLevel: kick, nameLevel: name, powerLevelsLevel: pl);

    test('Admin ab 50; Mitglied darf nichts davon', () {
      expect(r(0).isAdmin, isFalse);
      expect(r(49).isAdmin, isFalse);
      expect(r(50).isAdmin, isTrue);
      expect(r(100).isAdmin, isTrue);
      for (final lv in <int>[0, 49]) {
        expect(r(lv).canInvite, isFalse);
        expect(r(lv).canRename, isFalse);
        expect(r(lv).canRemove(other, 0), isFalse);
        expect(r(lv).canSetAdmin(other, 0, admin: true), isFalse);
      }
      expect(r(50).canInvite, isTrue);
      expect(r(50).canRename, isTrue);
    });

    test('Schwellen kommen aus dem Raumzustand (Umbenennen nur mit der Schwelle von m.room.name)', () {
      expect(r(50, name: 100).canRename, isFalse);
      expect(r(100, name: 100).canRename, isTrue);
      expect(r(50, invite: 100).canInvite, isFalse);
      expect(r(50, kick: 100).canRemove(other, 0), isFalse);
      expect(r(50, pl: 100).canSetAdmin(other, 0, admin: true), isFalse);
    });

    test('Entfernen: nie ich selbst, nie jemand mit Stufe ≥ meiner', () {
      expect(r(50).canRemove(other, 0), isTrue);
      expect(r(50).canRemove(other, 49), isTrue);
      expect(r(50).canRemove(other, 50), isFalse);
      expect(r(50).canRemove(other, 100), isFalse);
      expect(r(100).canRemove(other, 50), isTrue);
      expect(r(100).canRemove(me, 0), isFalse, reason: 'sich selbst nie entfernen (dafür Verlassen)');
    });

    test('Admin ernennen und entziehen: nur unter meiner Stufe, Selbstabstufung erlaubt, Selbstbeförderung nie', () {
      expect(r(50).canSetAdmin(other, 0, admin: true), isTrue);
      expect(r(50).canSetAdmin(other, 50, admin: true), isFalse, reason: 'schon Admin');
      expect(r(50).canSetAdmin(other, 50, admin: false), isFalse, reason: 'ein 50er entmachtet keinen anderen 50er');
      expect(r(100).canSetAdmin(other, 50, admin: false), isTrue);
      expect(r(100).canSetAdmin(other, 0, admin: false), isFalse, reason: 'kein Admin, nichts zu entziehen');
      expect(r(50).canSetAdmin(me, 50, admin: false), isTrue, reason: 'Selbstabstufung');
      expect(r(50).canSetAdmin(me, 50, admin: true), isFalse);
      expect(r(100).canSetAdmin(me, 100, admin: true), isFalse);
    });

    test('Zielstufe: Ernennen 50 (nie 100), Entziehen 0', () {
      expect(GroupRights.levelFor(admin: true), PowerLevels.moderator);
      expect(GroupRights.levelFor(admin: true), isNot(PowerLevels.admin));
      expect(GroupRights.levelFor(admin: false), PowerLevels.member);
    });

    test('letzter Admin: nur beigetretene Mitglieder mit Stufe ≥ 50 zählen', () {
      GroupMember m(String id, int power, {bool me = false, GroupMembership ms = GroupMembership.join}) =>
          GroupMember(userId: id, displayName: id, membership: ms, power: power, isMe: me);
      expect(GroupRights.isLastAdmin(<GroupMember>[m(me, 100, me: true), m(other, 0)]), isTrue);
      expect(GroupRights.isLastAdmin(<GroupMember>[m(me, 100, me: true), m(other, 50)]), isFalse);
      expect(GroupRights.isLastAdmin(<GroupMember>[m(me, 100, me: true), m(other, 50, ms: GroupMembership.invite)]), isTrue,
          reason: 'ein eingeladener Admin ist (noch) keiner');
      expect(GroupRights.isLastAdmin(<GroupMember>[m(me, 0, me: true), m(other, 50)]), isFalse);
      expect(GroupRights.isLastAdmin(<GroupMember>[m(me, 0, me: true), m(other, 0)]), isFalse, reason: 'ich bin kein Admin');
      expect(GroupRights.isLastAdmin(const <GroupMember>[]), isFalse);
    });
  });

  group('Chat-Typen für Gruppen (K4-1)', () {
    test('ThreadKind.group ist „außerhalb“ wie contact, nie Familie; Standardwerte der neuen Felder', () {
      const g = ChatThread(id: '!g:hs.example', kind: ThreadKind.group, title: 'Skat');
      expect(g.isOutside, isTrue);
      expect(g.isFamily, isFalse);
      expect(g.peerId, isNull);
      expect((g.memberCount, g.unreachableCount, g.identityChangedCount, g.canManage, g.sendLock), (0, 0, 0, false, GroupSendLock.keiner));
      expect(const ChatThread(id: 'x', kind: ThreadKind.contact, title: 'C').isOutside, isTrue);
      expect(const ChatThread(id: 'x', kind: ThreadKind.direct, title: 'D').isOutside, isFalse);
      expect(const ChatThread(id: ChatThread.familyId, kind: ThreadKind.family, title: 'F').isOutside, isFalse);
    });

    test('ContactRequest: neue Felder haben Standardwerte (Einzelchat-Anfrage unverändert)', () {
      const r = ContactRequest(roomId: '!r:hs.example', fromUserId: '@a:hs.example', fromName: 'A · hs.example');
      expect(r.inviterIsFamily, isFalse);
      expect(r.isGroup, isFalse);
      expect(r.groupName, isNull);
      const g = ContactRequest(
        roomId: '!r:hs.example',
        fromUserId: '@a:hs.example',
        fromName: 'A',
        groupName: 'Skat',
        isGroup: true,
        inviterIsFamily: true,
      );
      expect((g.groupName, g.isGroup, g.inviterIsFamily), ('Skat', true, true));
    });

    test('GroupMember: Standardwerte', () {
      const m = GroupMember(userId: '@a:hs.example', displayName: 'A', membership: GroupMembership.invite);
      expect((m.power, m.reachability, m.identity, m.isFamily, m.isMe), (0, ContactReachability.unknown, IdentityStatus.unknown, false, false));
    });
  });
}
