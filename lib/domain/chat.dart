import 'contacts.dart' show ContactReachability;
import 'family.dart' show IdentityStatus;

enum MessageStatus { sending, sent, failed }

class AttachmentInfo {
  const AttachmentInfo({required this.name, required this.mimeType, required this.size});
  final String name;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.time,
    this.body = '',
    this.replyToId,
    this.reactions = const <String, Set<String>>{},
    this.attachment,
    this.status = MessageStatus.sent,
    this.retryable = false,
    this.sharedEventId,
    this.blockedAttachment = false,
    this.undecryptable = false,
    this.beforeJoin = false,
    this.readBy = const <String>{},
  });

  /// Höchstlänge eines Nachrichtentexts in UTF-16-Einheiten, wie `sendMessage` im Gateway prüft (#236).
  static const int maxBody = 8000;

  final String id;
  final String senderId;
  /// Leer, wenn das Konto gelöscht und kein früherer Name bekannt ist (Anzeige „Ehemaliges Mitglied“, #60).
  final String senderName;
  final DateTime time;
  final String body;
  final String? replyToId;

  /// Emoji → Absender-IDs.
  final Map<String, Set<String>> reactions;
  final AttachmentInfo? attachment;
  final MessageStatus status;

  /// Die Sendung einer gescheiterten Nachricht ist noch offen und lässt sich wiederholen. Nach einem Neustart gilt das
  /// nicht: Der Inhalt läge dann nur noch in der Zeitleiste, und die ist nicht vertrauenswürdig.
  final bool retryable;

  /// Gesetzt, wenn die Nachricht einen geteilten Termin als Karte referenziert.
  final String? sharedEventId;

  /// Ein eingehender Anhang wurde wegen Typ/Größe nicht zugelassen (E-19).
  final bool blockedAttachment;

  /// Die Nachricht konnte (noch) nicht entschlüsselt werden, z. B. weil das
  /// Gerät dem Raum später beigetreten ist.
  final bool undecryptable;

  /// Sammelhinweis statt einzelner, nicht lesbarer Ereignisse aus der Zeit vor dem eigenen Beitritt.
  final bool beforeJoin;

  /// Matrix-IDs der anderen beigetretenen Mitglieder, deren öffentlicher Lesemarker auf oder hinter dieser eigenen
  /// Nachricht liegt (#526, E-106). Leer, solange die Lesebestätigung aus ist oder niemand gelesen hat.
  final Set<String> readBy;

  ChatMessage copyWith({
    Map<String, Set<String>>? reactions,
    MessageStatus? status,
    bool? retryable,
    Set<String>? readBy,
  }) =>
      ChatMessage(
        id: id,
        senderId: senderId,
        senderName: senderName,
        time: time,
        body: body,
        replyToId: replyToId,
        reactions: reactions ?? this.reactions,
        attachment: attachment,
        status: status ?? this.status,
        retryable: retryable ?? this.retryable,
        sharedEventId: sharedEventId,
        blockedAttachment: blockedAttachment,
        undecryptable: undecryptable,
        beforeJoin: beforeJoin,
        readBy: readBy ?? this.readBy,
      );
}

/// [contact]: Einzelchat mit einer Person **außerhalb der Familie** (#119, K3a-2); nie mit Familientexten kennzeichnen.
/// [group]: Gruppe mit Personen außerhalb der Familie (#119, K4); wie [contact] nie mit Familientexten kennzeichnen.
enum ThreadKind { family, direct, contact, group }

/// Warum das Senden in einer Gruppe gesperrt ist (#119, K4-1, §3.3/§3.6). [keiner]: erlaubt. Die Räume-Gründe liefert
/// `GroupHealth`; [keineMitglieder] und [wechsel] setzt das Gateway aus seinem Zustand (K4-2). Die Gruppe bleibt in allen
/// Fällen sichtbar und verlassbar.
enum GroupSendLock { keiner, zuGross, groesseUnbekannt, unverschluesselt, regelGeaendert, verlaufGeoeffnet, keineMitglieder, wechsel }

/// Mitgliedschaft eines Gruppenmitglieds (nur beigetreten oder eingeladen zählen als Mitglied).
enum GroupMembership { join, invite }

/// Ein Mitglied einer Gruppe für Liste und Verwaltung (#119, K4-1). [power] ist die Stufe aus dem Raumzustand.
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.membership,
    this.power = 0,
    this.reachability = ContactReachability.unknown,
    this.identity = IdentityStatus.unknown,
    this.isFamily = false,
    this.isMe = false,
  });

  final String userId;

  /// Bereinigter Anzeigename (Fremdtext).
  final String displayName;
  final GroupMembership membership;
  final int power;
  final ContactReachability reachability;
  final IdentityStatus identity;

  /// Beigetretenes oder eingeladenes Familienmitglied (Kennzeichen „Familie“).
  final bool isFamily;
  final bool isMe;
}

/// Ein Gespräch: der Familienchat oder ein Einzelchat mit einem Mitglied (E-39).
class ChatThread {
  const ChatThread({
    required this.id,
    required this.kind,
    required this.title,
    this.peerId,
    this.unread = 0,
    this.pending = false,
    this.reachable = true,
    this.peerName = '',
    this.identity = IdentityStatus.unknown,
    this.memberCount = 0,
    this.unreachableCount = 0,
    this.canManage = false,
    this.identityChangedCount = 0,
    this.sendLock = GroupSendLock.keiner,
  });

  /// Feste Kennung des Familienchats; Einzelchats tragen ihre Raum-ID.
  static const String familyId = 'family';

  final String id;
  final ThreadKind kind;

  /// Familienname bzw. Anzeigename des Gegenübers (bereinigt).
  final String title;

  /// Matrix-ID des Gegenübers (nur Einzelchats).
  final String? peerId;
  final int unread;

  /// Nur [ThreadKind.contact]: Das Gegenüber ist noch nicht beigetreten (wartet auf Annahme); Senden ist gesperrt.
  final bool pending;

  /// Nur [ThreadKind.contact]: Das Gegenüber kann Nachrichten entschlüsseln (K3a-2b; bis dahin `true`).
  final bool reachable;

  /// Nur [ThreadKind.contact]: bereinigter Anzeigename des Gegenübers **ohne** Server (für den Vergleich mit Familiennamen,
  /// §9.1); leer, wenn keiner bekannt ist.
  final String peerName;

  /// Nur [ThreadKind.contact]: Zustand der kryptografischen Identität des Gegenübers (K3b-2b, B8). `changed`: Der
  /// Hauptschlüssel hat sich geändert, Senden ist gesperrt, bis die Änderung akzeptiert wird.
  final IdentityStatus identity;

  /// Nur [ThreadKind.group]: Zahl der Mitglieder (beigetreten und eingeladen); sonst 0.
  final int memberCount;

  /// Nur [ThreadKind.group]: Mitglieder, die nach bekannten Schlüsseln nicht mitlesen können; sonst 0.
  final int unreachableCount;

  /// Nur [ThreadKind.group]: Ich darf die Gruppe verwalten (Stufe laut Raumzustand).
  final bool canManage;

  /// Nur [ThreadKind.group]: Mitglieder mit ungeklärtem Schlüsselwechsel; sonst 0.
  final int identityChangedCount;

  /// Nur [ThreadKind.group]: Sperrgrund für das Senden; [GroupSendLock.keiner] heißt erlaubt.
  final GroupSendLock sendLock;

  bool get isFamily => kind == ThreadKind.family;

  /// Gespräch mit Personen außerhalb der Familie (Einzelkontakt oder Gruppe): kein Online-Status, kein Familientext.
  bool get isOutside => kind == ThreadKind.contact || kind == ThreadKind.group;
}

/// Eingehende Kontaktanfrage (#119, K3a-2): nur Absender und Server, **kein** Rauminhalt vor der Annahme.
class ContactRequest {
  const ContactRequest({
    required this.roomId,
    required this.fromUserId,
    required this.fromName,
    this.name = '',
    this.groupName,
    this.isGroup = false,
    this.inviterIsFamily = false,
  });

  final String roomId;
  final String fromUserId;

  /// Bereinigter Anzeigename **ohne** Server (für den Vergleich mit Familiennamen, §9.1).
  final String name;

  /// Bereinigter Anzeigename mit Server („Name · server“, [ContactNames.title]).
  final String fromName;

  /// Nur Gruppenanfragen (K4): bereinigter Gruppenname ([ContactNames.groupTitle]); sonst `null`.
  final String? groupName;

  /// Die Anfrage betrifft eine Gruppe (K4), nicht einen Einzelchat.
  final bool isGroup;

  /// Der Einladende ist ein Familienmitglied (K4, D5): steuert nur die Anzeige („Familie“ an der Anfragekarte), nie die
  /// Einstufung. Ohne geladene Familie `false`.
  final bool inviterIsFamily;
}
