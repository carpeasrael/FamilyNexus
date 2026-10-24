/// Rollen laut Concept: Mitglied (Power-Level 0), Moderator (50). Der Ersteller steht in Matrix auf
/// Administrator (100); in der App ist er ein Moderator wie jeder andere (E-61).
enum Role { member, moderator }

enum MemberStatus {
  joined,
  invited,

  /// Hat per Link/QR eine Beitrittsanfrage (Matrix „knock“) gestellt.
  requested,
}

/// Power-Levels (E-12).
class PowerLevels {
  const PowerLevels._();
  static const int member = 0;
  static const int moderator = 50;

  /// Administrator im Matrix-Raum (nur der Ersteller); in der App gleichrangig mit Moderatoren.
  static const int admin = 100;

  /// Für niemanden erreichbar (über dem Administrator).
  static const int unreachable = 101;

  static Role roleFor(int level) => level >= moderator ? Role.moderator : Role.member;
}

/// Vertrauensstatus der kryptografischen Identität (Cross-Signing-Hauptschlüssel) eines Mitglieds (S1).
enum IdentityStatus {
  /// Keine Cross-Signing-Schlüssel bekannt: es werden keine Raumschlüssel geteilt.
  unknown,

  /// Beim ersten Kontakt vermerkt („Trust on first use“), nicht persönlich geprüft.
  pinned,

  /// Persönlich per Emoji-Vergleich verifiziert.
  verified,

  /// Der Hauptschlüssel hat sich seit dem Vermerk geändert: Geräte sind gesperrt, bis ein
  /// Moderator/Mitglied die Änderung ausdrücklich akzeptiert.
  changed,
}

/// Prüfergebnis einer Beitrittsanfrage gegen die vom Moderator ausgegebenen Einladungslinks (S2).
enum RequestCheck {
  /// Anfrage nennt einen eigenen, gültigen und unverbrauchten Link.
  valid,
  expired,

  /// Link unbekannt (nicht von diesem Konto ausgegeben oder bereits verbraucht).
  unknown,
}

class FamilyMember {
  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.role,
    this.status = MemberStatus.joined,
    this.identity = IdentityStatus.unknown,
    this.request,
  });

  final String userId;
  final String displayName;
  final Role role;
  final MemberStatus status;
  final IdentityStatus identity;

  /// Nur für Beitrittsanfragen gesetzt.
  final RequestCheck? request;

  FamilyMember copyWith({Role? role, MemberStatus? status, String? displayName, IdentityStatus? identity, RequestCheck? request}) => FamilyMember(
        userId: userId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        status: status ?? this.status,
        identity: identity ?? this.identity,
        request: request ?? this.request,
      );

  @override
  bool operator ==(Object other) =>
      other is FamilyMember &&
      other.userId == userId &&
      other.displayName == displayName &&
      other.role == role &&
      other.status == status &&
      other.identity == identity &&
      other.request == request;

  @override
  int get hashCode => Object.hash(userId, displayName, role, status, identity, request);
}

class Family {
  const Family({
    required this.roomId,
    required this.name,
    required this.members,
    required this.myUserId,
  });

  final String roomId;
  final String name;
  final List<FamilyMember> members;
  final String myUserId;

  FamilyMember? member(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  Role get myRole => member(myUserId)?.role ?? Role.member;

  Iterable<FamilyMember> get joined => members.where((m) => m.status == MemberStatus.joined);
  Iterable<FamilyMember> get requests => members.where((m) => m.status == MemberStatus.requested);
  int get moderatorCount => joined.where((m) => m.role == Role.moderator).length;

  /// Concept: Empfehlung eines zweiten Moderators.
  bool get needsSecondModerator => moderatorCount < 2;
}

/// Einladung in einen Raum (noch nicht angenommen). Der Name stammt von einem
/// Fremden und ist bereits bereinigt; angenommen wird nur nach ausdrücklicher Zustimmung.
class PendingInvitation {
  const PendingInvitation({
    required this.roomId,
    required this.roomName,
    required this.inviterId,
    this.inviterName,
    this.requested = false,
  });
  final String roomId;

  /// `true`, wenn die Einladung zur eigenen wartenden Beitrittsanfrage gehört.
  final bool requested;
  final String roomName;
  final String inviterId;

  /// Anzeigename des Einladenden (bereinigt), `null` wenn unbekannt.
  final String? inviterName;

  /// Name für die Anzeige: Anzeigename, sonst der lokale Teil der ID (ohne `@…:server`).
  String get inviterLabel {
    final n = inviterName;
    if (n != null && n.isNotEmpty) return n;
    final i = inviterId.indexOf(':');
    return inviterId.startsWith('@') && i > 1 ? inviterId.substring(1, i) : inviterId;
  }
}
