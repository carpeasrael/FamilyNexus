import 'contacts.dart' show ContactState;
import 'family_invitation.dart';

/// Wie ein Raum eingestuft wird (#119, K2a, E-114): Eine Entscheidungsstelle für alle Räume des Kontos. Reine
/// Domäne, ohne SDK-Typen: Das Gateway liest die [RoomFacts] aus dem Raum und fragt [ConversationPolicy].
///
/// Unbekanntes ist immer [ignored] (I2: Positivliste). [contactDirect] und [contactRequest] liefert [ConversationPolicy.classify]
/// ab K3a-1 nur bei eingeschaltetem Bereich ([PolicyContext.contactsEnabled]); [contactGroup] liefert sie ab K4-1 nur für
/// beigetretene Räume mit eigenem Gruppen-Datensatz ([PolicyContext.groups]) und [contactRequest] auch für Gruppeneinladungen.
enum RoomClass { family, private, familyDirect, contactDirect, contactGroup, familyInvite, contactRequest, ignored }

/// Mitgliedschaft des **Gegenübers** im Raum (aus `m.room.member`, nicht aus Zählern): [join] beigetreten, [invite] nur
/// eingeladen, [other] abgelehnt/verlassen/verbannt, [unknown] Zustand nicht geladen (Lazy Loading, Neustart). Nur sie
/// schließt aus, dass das Gegenüber ging und ein Dritter beitrat, während `m.direct` weiter auf das Gegenüber zeigt.
enum PeerMembership { join, invite, other, unknown }

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
    this.peerMembership = PeerMembership.unknown,
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

  /// Mitgliedschaft des Gegenübers ([peerId]); `unknown` ist der Standard und führt für Kontakte zu `ignored`.
  final PeerMembership peerMembership;

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
    this.contactsEnabled = false,
    this.contacts = const <String, ContactState>{},
    this.blockedUsers = const <String>{},
    this.familyIds = const <String>{},
    this.groups = const <String>{},
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

  /// Kontakte (#119, K3a-1): Der Bereich ist eingeschaltet. Standard aus: ohne ihn nie eine Kontaktklasse.
  final bool contactsEnabled;

  /// Aktive Kontakte mit Zustand (Löschmarken fehlen).
  final Map<String, ContactState> contacts;

  /// Blockierte Kennungen (lokale Liste und Datensätze).
  final Set<String> blockedUsers;

  /// Alle Mitglieder der Familie in jedem Status (beigetreten, eingeladen, angefragt): nie ein Kontakt. Entfernte
  /// Mitglieder gehören nicht dazu und gelten als Fremde (E-114).
  final Set<String> familyIds;

  /// Raum-IDs der Gruppen mit aktivem Datensatz (K4-1, #119, D4): ein eigener Datensatz bestimmt die Klasse eines
  /// beigetretenen Raums, nie ein Fremder.
  final Set<String> groups;
}

/// Wann die Mitgliederliste für Kontaktentscheidungen vollständig ist (B6, fail-closed). Mit Familie: erst wenn ihre Liste
/// geladen ist. **Ohne** Familie nur nach der Erstsynchronisation **und** abgeschlossener Familienermittlung; „keine
/// Familie“ darf nie mit „Familie noch nicht ermittelt“ verwechselt werden, sonst wäre ein Familienmitglied ein Kontakt.
/// In K3a-1 nur getestete reine Funktion; das Gateway bindet sie in K3a-2 an.
class ContactScope {
  const ContactScope._();

  static bool membersComplete({
    required bool hasFamily,
    required bool participantsLoaded,
    required bool syncedOnce,
    required bool familyResolved,
  }) =>
      hasFamily ? participantsLoaded : (syncedOnce && familyResolved);

  /// Ist „keine Familie“ gesichert (K3c-1, I2)? Wahrheitstabelle (jede Zeile mit [accountDataFresh] `true` und `false`):
  ///
  /// | # | Zeiger | Raum im Client | Mitgliedschaft | Familie gebaut | fresh | nicht fresh |
  /// |---|--------|----------------|----------------|----------------|-------|-------------|
  /// | 1 | fehlt | – | – | nein | wahr | falsch |
  /// | 2 | gesetzt | unbekannt | – | nein | [row2Settled] | falsch |
  /// | 3, 4 | gesetzt | bekannt | Einladung, verlassen, verbannt, angeklopft | nein | wahr | falsch |
  /// | 5 | gesetzt | bekannt | beigetreten | nein (Zwischenzustand) | falsch | falsch |
  /// | 6 | gesetzt | bekannt | beigetreten | ja | wahr | wahr (die gebaute Familie belegt den Stand) |
  ///
  /// [accountDataFresh]: die erste Serverantwort dieser Sitzung ist da, die Kontodaten (Zeiger) sind auf dem Stand des
  /// Servers. [row2Settled] ist die Außenregel des Gateways (60 s **und** 3 zählende Syncs) für ein Zeiger-Relikt; die Zeit
  /// ist kein Begriff dieser reinen Funktion.
  static bool familyResolved({
    required bool pointerSet,
    required bool roomKnown,
    required RoomMembership? membership,
    required bool familyBuilt,
    required bool accountDataFresh,
    required bool row2Settled,
  }) {
    if (familyBuilt) return true; // Zeile 6
    if (!accountDataFresh) return false;
    if (!pointerSet) return true; // Zeile 1
    if (!roomKnown) return row2Settled; // Zeile 2
    return membership != RoomMembership.join; // Zeilen 3 und 4 wahr, Zeile 5 falsch
  }
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
        // Gruppe (K4-1, D4, Anhang A Z. 2 und 6): nur mit eigenem Datensatz, vor den Zweier-Zeilen (der Datensatz gewinnt
        // gegen `m.direct`). Größe, Regel, Verlauf und Verschlüsselung gehören nicht zur Einstufung, sondern zu
        // `GroupHealth`: eine unsichere Gruppe bleibt sichtbar, sendegesperrt und verlassbar.
        if (c.contactsEnabled && c.membersLoaded && c.groups.contains(r.id)) return RoomClass.contactGroup;
        final peer = r.peerId;
        if (peer != null &&
            peer != c.myUserId &&
            c.membersLoaded &&
            c.joinedMembers.contains(peer) &&
            r.megolm &&
            r.isPair) {
          return RoomClass.familyDirect;
        }
        // Kontakt-Einzelchat (K3a-1): nur mit eigenem Datensatz, nie für Familienmitglieder (jeder Status).
        // Das Gegenüber muss im Raum **beigetreten** sein (oder bei `outgoing` noch eingeladen: wartet auf Annahme).
        if (peer != null && _contactPeerOk(peer, c) && r.megolm && r.isPair) {
          final state = c.contacts[peer];
          final joinedPeer = r.peerMembership == PeerMembership.join;
          final waiting = r.peerMembership == PeerMembership.invite && state == ContactState.outgoing;
          if ((state == ContactState.outgoing || state == ContactState.accepted) && (joinedPeer || waiting)) {
            return RoomClass.contactDirect;
          }
        }
        return RoomClass.ignored;
      case RoomMembership.invite:
        // Buch-Räume und Einladungen in Einzelchats sind nie eine Familieneinladung; Letztere entscheidet
        // [autoAcceptDirect]. Unabhängig von `membersLoaded` und von der Familie: Konten ohne Familie sehen in der
        // Einrichtung ihre Einladung (K1, B1).
        if (r.isBook) return RoomClass.ignored;
        if (r.inviteIsDirect) {
          // Anfrage nur von Fremden ohne aktiven Datensatz; Kontakte nimmt [autoAcceptContact] an, Blockierte sind unsichtbar.
          final from = r.inviterId;
          if (from == null || !_contactPeerOk(from, c) || !(r.joinedCount == null || r.isPair)) return RoomClass.ignored;
          return c.contacts.containsKey(from) ? RoomClass.ignored : RoomClass.contactRequest;
        }
        // Gruppenanfrage (K4-1, Anhang A Z. 7 und 7b): nicht-direkte Einladung mit `join_rule == invite`, Einladender
        // bekannt, nicht ich, nicht blockiert; ein Familienmitglied darf einladen (D5). `id ∈ groups` ändert nichts
        // (Absturzfall D2: Datensatz da, Einladung noch offen, bleibt Anfrage). `null` und `knock` bleiben Familieneinladung.
        if (r.joinRule == 'invite') {
          final from = r.inviterId;
          final ok = c.contactsEnabled && c.membersLoaded && from != null && from != c.myUserId && !c.blockedUsers.contains(from);
          return ok ? RoomClass.contactRequest : RoomClass.ignored;
        }
        return isFamilyInvitation(joinRule: r.joinRule, isDirect: false, isBook: false) ? RoomClass.familyInvite : RoomClass.ignored;
      case RoomMembership.other:
        return RoomClass.ignored;
    }
  }

  /// Gemeinsame Vorbedingung der Kontaktklassen: Bereich an, Liste vollständig, nicht ich, nicht Familie, nicht blockiert.
  static bool _contactPeerOk(String peer, PolicyContext c) =>
      c.contactsEnabled && c.membersLoaded && peer != c.myUserId && !c.familyIds.contains(peer) && !c.blockedUsers.contains(peer);

  /// Wird eine Einzelchat-Einladung eines **Kontakts** automatisch angenommen (K3a-1)? Nur für einen eigenen Datensatz
  /// `outgoing`/`accepted`, nie für Familienmitglieder oder Blockierte. Eine ungeklärte Identitätsänderung hindert die
  /// Annahme seit K3c-1 nicht mehr (der Raum entsteht, Senden bleibt gesperrt).
  static bool autoAcceptContact(RoomFacts r, PolicyContext c) {
    if (r.membership != RoomMembership.invite || !r.inviteIsDirect || r.isBook) return false;
    final from = r.inviterId;
    // Kein Ausschluss bei `identityChanged` (K3c-1, Revision K3b-1): sonst bliebe die Einladung des Gegenübers nach einem
    // Schlüsselwechsel liegen (Pin-Sackgasse, Variante B). Die Sendesperre (`changed`) trägt den Schutz.
    if (from == null || !_contactPeerOk(from, c)) return false;
    final state = c.contacts[from];
    return state == ContactState.outgoing || state == ContactState.accepted;
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
