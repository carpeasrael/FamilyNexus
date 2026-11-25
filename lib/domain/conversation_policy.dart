import 'family_invitation.dart';

/// Wie ein Raum eingestuft wird (#119, K2a, E-114): Eine Entscheidungsstelle für alle Räume des Kontos. Reine
/// Domäne, ohne SDK-Typen: Das Gateway liest die [RoomFacts] aus dem Raum und fragt [ConversationPolicy].
///
/// Unbekanntes ist immer [ignored] (I2: Positivliste). Die Klassen [contactDirect], [contactGroup] und [contactRequest]
/// gibt es ab K2c/K3 (Kontakte und Gruppen); [ConversationPolicy.classify] liefert sie in diesem Stand nie.
enum RoomClass { family, private, familyDirect, contactDirect, contactGroup, familyInvite, contactRequest, ignored }

/// Mitgliedschaft des eigenen Kontos im Raum; alles außer `join` und `invite` (`leave`, `ban`, `knock`) zählt nicht.
enum RoomMembership { join, invite, other }

/// Aus dem SDK-Raum gelesene Tatsachen (keine SDK-Typen). Bedeutung je Fall:
/// - [peerId]: bei **beigetretenen** Räumen das Gegenüber laut `m.direct` (Kontodaten), **nicht** `is_direct`.
/// - [inviterId], [inviteIsDirect]: bei **Einladungen** der Absender und `is_direct` im eigenen Mitgliedsereignis.
/// - [megolm]: Verschlüsselung ist verfügbar **und** der Raum ist Megolm-verschlüsselt (`_canEncryptIn`).
/// - [joinedCount], [invitedCount]: Zähler der Raumzusammenfassung, `null` = unbekannt.
/// - [joinRule]: `join_rule` des Raums, `null` = der Server lieferte keinen Zustand.
class RoomFacts {
  const RoomFacts({
    required this.id,
    required this.membership,
    this.isBook = false,
    this.megolm = false,
    this.peerId,
    this.inviterId,
    this.inviteIsDirect = false,
    this.joinedCount,
    this.invitedCount,
    this.joinRule,
  });

  final String id;
  final RoomMembership membership;
  final bool isBook;
  final bool megolm;
  final String? peerId;
  final String? inviterId;
  final bool inviteIsDirect;
  final int? joinedCount;
  final int? invitedCount;
  final String? joinRule;

  /// Höchstens zwei Personen (beigetreten oder eingeladen). **Fail-closed:** unbekannte beigetretene Zahl ist kein Paar;
  /// eine unbekannte Zahl eingeladener zählt als 0.
  bool get isPair => joinedCount != null && joinedCount! + (invitedCount ?? 0) <= 2;
}

/// Kontext der Einstufung. [myUserId] kommt vom Client und ist auch ohne Familie bekannt (Einrichtung).
class PolicyContext {
  const PolicyContext({
    required this.myUserId,
    this.familyRoomId,
    this.privateRoomId,
    this.joinedMembers = const <String>{},
    this.membersLoaded = false,
    this.identityChanged = const <String>{},
  });

  final String myUserId;
  final String? familyRoomId;
  final String? privateRoomId;

  /// Beigetretene Mitglieder der Familie.
  final Set<String> joinedMembers;

  /// Die Mitgliederliste der Familie ist vollständig geladen (Lazy Loading liefert anfangs nur Teile, B6).
  final bool membersLoaded;

  /// Mitglieder, deren Cross-Signing-Schlüssel sich geändert hat und noch nicht bestätigt wurde.
  final Set<String> identityChanged;
}

class ConversationPolicy {
  const ConversationPolicy._();

  /// Einstufung eines Raums. Reihenfolge: Mitgliedschaft, Familie und privater Raum (Vorrang), Einzelchat mit
  /// Mitglied, Familieneinladung; alles andere [RoomClass.ignored].
  static RoomClass classify(RoomFacts r, PolicyContext c) {
    switch (r.membership) {
      case RoomMembership.join:
        if (r.id == c.familyRoomId) return RoomClass.family;
        if (r.id == c.privateRoomId) return RoomClass.private;
        final peer = r.peerId;
        if (peer != null &&
            peer != c.myUserId &&
            c.membersLoaded &&
            c.joinedMembers.contains(peer) &&
            r.megolm &&
            r.isPair) {
          return RoomClass.familyDirect;
        }
        return RoomClass.ignored;
      case RoomMembership.invite:
        // Buch-Räume und Einladungen in Einzelchats sind nie eine Familieneinladung; Letztere entscheidet
        // [autoAcceptDirect]. Unabhängig von `membersLoaded` und von der Familie: Konten ohne Familie sehen in der
        // Einrichtung ihre Einladung (K1, B1).
        if (r.isBook || r.inviteIsDirect) return RoomClass.ignored;
        return isFamilyInvitation(joinRule: r.joinRule, isDirect: false, isBook: false) ? RoomClass.familyInvite : RoomClass.ignored;
      case RoomMembership.other:
        return RoomClass.ignored;
    }
  }

  /// Wird eine Einzelchat-Einladung automatisch angenommen (E-39)? Nur von einem beigetretenen Mitglied (nicht ich),
  /// ohne ungeklärte Identitätsänderung und nur bei vollständig geladener Mitgliederliste. Bewusst **keine** Prüfung auf
  /// `isBook` (wie bisher: Buch-Einladungen tragen kein `is_direct`; die Nachprüfung nach dem Beitritt verlässt unzulässige
  /// Räume sofort).
  static bool autoAcceptDirect(RoomFacts r, PolicyContext c) {
    if (r.membership != RoomMembership.invite || !r.inviteIsDirect || !c.membersLoaded) return false;
    final from = r.inviterId;
    if (from == null || from == c.myUserId) return false;
    return c.joinedMembers.contains(from) && !c.identityChanged.contains(from);
  }
}
