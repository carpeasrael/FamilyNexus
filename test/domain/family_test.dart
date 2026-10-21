import 'package:family_nexus/domain/family.dart';
import 'package:flutter_test/flutter_test.dart';

Family _family(List<FamilyMember> m, {String me = '@a:x.org'}) =>
    Family(roomId: '!r:x.org', name: 'F', members: m, myUserId: me);

FamilyMember _m(String id, Role r, [MemberStatus s = MemberStatus.joined]) =>
    FamilyMember(userId: id, displayName: id, role: r, status: s);

void main() {
  test('Power-Levels → Rollen', () {
    expect(PowerLevels.roleFor(0), Role.member);
    expect(PowerLevels.roleFor(49), Role.member);
    expect(PowerLevels.roleFor(50), Role.moderator);
    expect(PowerLevels.roleFor(100), Role.moderator);
  });

  test('eigene Rolle, Anfragen, Moderatorenzahl', () {
    final f = _family(<FamilyMember>[
      _m('@a:x.org', Role.moderator),
      _m('@b:x.org', Role.member),
      _m('@c:x.org', Role.member, MemberStatus.requested),
      _m('@d:x.org', Role.moderator, MemberStatus.invited),
    ]);
    expect(f.myRole, Role.moderator);
    expect(f.requests.map((e) => e.userId), <String>['@c:x.org']);
    expect(f.moderatorCount, 1, reason: 'Eingeladene zählen nicht');
    expect(f.needsSecondModerator, isTrue);
  });

  test('unbekannter Nutzer ist Mitglied (geringste Rechte)', () {
    expect(_family(<FamilyMember>[], me: '@z:x.org').myRole, Role.member);
  });
}
