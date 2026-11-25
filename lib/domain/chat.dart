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
enum ThreadKind { family, direct, contact }

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

  bool get isFamily => kind == ThreadKind.family;

  /// Gespräch mit einer Person außerhalb der Familie: kein Online-Status, kein Familientext.
  bool get isOutside => kind == ThreadKind.contact;
}

/// Eingehende Kontaktanfrage (#119, K3a-2): nur Absender und Server, **kein** Rauminhalt vor der Annahme.
class ContactRequest {
  const ContactRequest({required this.roomId, required this.fromUserId, required this.fromName, this.name = ''});

  final String roomId;
  final String fromUserId;

  /// Bereinigter Anzeigename **ohne** Server (für den Vergleich mit Familiennamen, §9.1).
  final String name;

  /// Bereinigter Anzeigename mit Server („Name · server“, [ContactNames.title]).
  final String fromName;
}
