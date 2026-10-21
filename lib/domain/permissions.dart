import 'family.dart';

/// Rechte nach Concept (Tabelle „Rollen und Rechte“) und E-10. Reine Logik;
/// zusätzlich zur UI prüfen auch das Gateway und letztlich der Matrix-Server.
class Permissions {
  const Permissions._();

  static bool isModerator(Family f) => f.myRole == Role.moderator;

  /// Neue Mitglieder einladen und Beitrittsanfragen entscheiden.
  static bool canInvite(Family f) => isModerator(f);

  static bool canConfigure(Family f) => isModerator(f);

  /// Zum Moderator ernennen: nur Moderatoren, nur gegenüber beigetretenen Mitgliedern.
  static bool canPromote(Family f, FamilyMember target) =>
      isModerator(f) &&
      target.status == MemberStatus.joined &&
      target.role == Role.member &&
      target.userId != f.myUserId;

  /// Entfernen: nur Moderatoren, nur Mitglieder (Moderatoren sind gleichrangig und
  /// können einander nicht entfernen, E-10), nicht sich selbst.
  static bool canRemove(Family f, FamilyMember target) =>
      isModerator(f) && target.userId != f.myUserId && target.role == Role.member;

  /// Beitrittsanfragen bestätigen oder ablehnen.
  static bool canDecideRequest(Family f, FamilyMember target) =>
      isModerator(f) && target.status == MemberStatus.requested;

  /// Geteilte Termine ändern/löschen darf nur der Besitzer, auch kein Moderator (E-10).
  static bool canEditEvent({required String ownerId, required String me, required bool deleted}) =>
      !deleted && ownerId == me;
}
