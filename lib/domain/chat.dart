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
    this.sharedEventId,
    this.blockedAttachment = false,
    this.undecryptable = false,
    this.beforeJoin = false,
  });

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

  /// Gesetzt, wenn die Nachricht einen geteilten Termin als Karte referenziert.
  final String? sharedEventId;

  /// Ein eingehender Anhang wurde wegen Typ/Größe nicht zugelassen (E-19).
  final bool blockedAttachment;

  /// Die Nachricht konnte (noch) nicht entschlüsselt werden, z. B. weil das
  /// Gerät dem Raum später beigetreten ist.
  final bool undecryptable;

  /// Sammelhinweis statt einzelner, nicht lesbarer Ereignisse aus der Zeit vor dem eigenen Beitritt.
  final bool beforeJoin;

  ChatMessage copyWith({
    Map<String, Set<String>>? reactions,
    MessageStatus? status,
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
        sharedEventId: sharedEventId,
        blockedAttachment: blockedAttachment,
        undecryptable: undecryptable,
        beforeJoin: beforeJoin,
      );
}

enum ThreadKind { family, direct }

/// Ein Gespräch: der Familienchat oder ein Einzelchat mit einem Mitglied (E-39).
class ChatThread {
  const ChatThread({
    required this.id,
    required this.kind,
    required this.title,
    this.peerId,
    this.unread = 0,
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

  bool get isFamily => kind == ThreadKind.family;
}
