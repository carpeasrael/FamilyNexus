import 'family.dart';

/// Mitgliedschaft in einem Buch-Raum, soweit sie für Rechte zählt.
enum BookMembership { joined, invited }

class BookMember {
  const BookMember(this.userId, this.membership);
  final String userId;
  final BookMembership membership;
}

/// Regeln des Kassenbuchs für Einladen, Annehmen, Senden und Abgleich (#311, E-113). Reine Logik, getrennt vom SDK.
/// Maßgeblich ist immer der Zustand der **Familie** (Rolle, Mitgliedschaft, Identität); das Feld `family` im
/// `m.room.create` des Buchs ist fälschbar und zählt hier nie.
class BookPolicy {
  const BookPolicy._();

  /// Darf [userId] eingeladen werden? Nur ein beigetretenes Familienmitglied mit Rolle Moderator, nicht man selbst,
  /// Identität nicht `changed` (geänderte Schlüssel erhalten keine Raumschlüssel).
  static bool canInvite(Family? family, String userId) {
    final m = family?.member(userId);
    if (family == null || m == null || userId == family.myUserId) return false;
    return m.status == MemberStatus.joined && m.role == Role.moderator && m.identity != IdentityStatus.changed;
  }

  /// Darf diese Einladung als Buch angenommen werden? Der Einladende muss der Ersteller des Raums (laut `m.room.create`)
  /// und beigetretener Moderator **meiner** Familie sein.
  static bool mayAccept(Family? family, {required String inviterId, required String? creatorId}) {
    if (family == null || creatorId == null || inviterId != creatorId) return false;
    final m = family.member(inviterId);
    return m != null && m.status == MemberStatus.joined && m.role == Role.moderator;
  }

  /// Mitglieder eines Buch-Raums (beigetreten oder eingeladen), die dort nicht sein dürfen: kein beigetretener Moderator
  /// der Familie oder geänderte Identität. [me] zählt nie.
  static List<String> unauthorized(Iterable<BookMember> members, Family family, {required String me}) => <String>[
        for (final b in members)
          if (b.userId != me && !_isAuthorized(family, b.userId)) b.userId,
      ];

  static bool _isAuthorized(Family family, String userId) {
    final m = family.member(userId);
    return m != null && m.status == MemberStatus.joined && m.role == Role.moderator && m.identity != IdentityStatus.changed;
  }
}

/// Zwei übereinstimmende Durchläufe vor dem Entfernen (E-113): Ein einzelner Abgleich auf einer Teilliste oder einem
/// veralteten Familienbild entfernt niemanden (ein `kick` ist nicht rückholbar). Gemerkt wird je Raum, wer beim
/// letzten Durchlauf auffiel.
class BookReconciler {
  final Map<String, Set<String>> _seen = <String, Set<String>>{};

  /// Meldet die aktuell Auffälligen eines Raums und liefert, wen auch der vorige Durchlauf schon meldete.
  Set<String> observe(String roomId, Iterable<String> candidates) {
    final now = candidates.toSet();
    final before = _seen[roomId] ?? const <String>{};
    _seen[roomId] = now;
    return now.intersection(before);
  }

  /// Ein abgebrochener Durchlauf (Familie oder Mitgliederliste nicht belastbar) verwirft das Gemerkte.
  void reset(String roomId) => _seen.remove(roomId);

  void clear() => _seen.clear();
}

/// Ein beigetretenes Buch der aktuellen Familie (Raum-ID und Ersteller laut `m.room.create`).
class BookRoomInfo {
  const BookRoomInfo({required this.roomId, required this.creatorId});
  final String roomId;
  final String creatorId;
}

/// Eine annehmbare Einladung in ein Buch: nur gültige (Einladender == Ersteller, Moderator meiner Familie).
class BookInvitationInfo {
  const BookInvitationInfo({required this.roomId, required this.inviterId, required this.inviterName});
  final String roomId;
  final String inviterId;
  final String inviterName;
}
