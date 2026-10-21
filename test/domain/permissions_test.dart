import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:flutter_test/flutter_test.dart';

FamilyMember _m(String id, Role r, [MemberStatus s = MemberStatus.joined]) =>
    FamilyMember(userId: id, displayName: id, role: r, status: s);

Family _f(String me, List<FamilyMember> members) =>
    Family(roomId: '!r:x.org', name: 'F', members: members, myUserId: me);

void main() {
  final mod = _m('@mod:x.org', Role.moderator);
  final mod2 = _m('@mod2:x.org', Role.moderator);
  final kid = _m('@kid:x.org', Role.member);
  final asked = _m('@new:x.org', Role.member, MemberStatus.requested);
  final invited = _m('@inv:x.org', Role.member, MemberStatus.invited);

  group('Mitglied', () {
    final f = _f(kid.userId, <FamilyMember>[mod, kid]);
    test('hat keine Verwaltungsrechte (Tabelle im Concept)', () {
      expect(Permissions.canInvite(f), isFalse);
      expect(Permissions.canConfigure(f), isFalse);
      expect(Permissions.canPromote(f, kid), isFalse);
      expect(Permissions.canRemove(f, mod), isFalse);
      expect(Permissions.canDecideRequest(f, asked), isFalse);
    });
  });

  group('Moderator', () {
    final f = _f(mod.userId, <FamilyMember>[mod, mod2, kid, asked, invited]);
    test('darf einladen und konfigurieren', () {
      expect(Permissions.canInvite(f), isTrue);
      expect(Permissions.canConfigure(f), isTrue);
    });
    test('darf Mitglieder ernennen, aber keine Moderatoren, Eingeladene oder sich selbst', () {
      expect(Permissions.canPromote(f, kid), isTrue);
      expect(Permissions.canPromote(f, mod2), isFalse);
      expect(Permissions.canPromote(f, mod), isFalse);
      expect(Permissions.canPromote(f, invited), isFalse);
      expect(Permissions.canPromote(f, asked), isFalse);
    });
    test('darf Mitglieder entfernen, aber keine Moderatoren und nicht sich selbst', () {
      expect(Permissions.canRemove(f, kid), isTrue);
      expect(Permissions.canRemove(f, invited), isTrue, reason: 'Einladung zurückziehen');
      expect(Permissions.canRemove(f, mod2), isFalse);
      expect(Permissions.canRemove(f, mod), isFalse);
    });
    test('entscheidet nur über Beitrittsanfragen', () {
      expect(Permissions.canDecideRequest(f, asked), isTrue);
      expect(Permissions.canDecideRequest(f, kid), isFalse);
    });
  });

  test('geteilte Termine: nur der Besitzer, auch nicht der Moderator (E-10)', () {
    expect(Permissions.canEditEvent(ownerId: '@a:x.org', me: '@a:x.org', deleted: false), isTrue);
    expect(Permissions.canEditEvent(ownerId: '@a:x.org', me: '@mod:x.org', deleted: false), isFalse);
    expect(Permissions.canEditEvent(ownerId: '@a:x.org', me: '@a:x.org', deleted: true), isFalse);
  });

  test('unbekannter Nutzer gilt als Mitglied (keine Rechte)', () {
    final f = _f('@ghost:x.org', <FamilyMember>[mod]);
    expect(Permissions.canInvite(f), isFalse);
  });
}
