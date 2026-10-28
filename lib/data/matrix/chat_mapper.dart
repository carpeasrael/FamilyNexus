import 'package:matrix/matrix.dart';

import '../../core/app_log.dart';
import '../../domain/attachment_policy.dart';
import '../../domain/calendar_event.dart';
import '../../domain/chat.dart';
import '../../domain/text_sanitizer.dart';

/// Übersetzt SDK-Ereignisse in Domänenmodelle. Alle Eingaben stammen von
/// anderen Teilnehmern und gelten als nicht vertrauenswürdig: Typen werden
/// defensiv gelesen, Texte bereinigt, Anhänge gegen die [AttachmentPolicy] geprüft.
class ChatMapper {
  const ChatMapper._();

  static const int maxReactionKeys = 12;

  static const Set<String> _fileTypes = <String>{
    MessageTypes.Image,
    MessageTypes.File,
    MessageTypes.Audio,
    MessageTypes.Video,
  };

  /// Kennung des Sammelhinweises für nicht lesbare Ereignisse vor dem eigenen Beitritt.
  static const String beforeJoinId = 'before-join';

  /// Nachrichten der Zeitleiste, älteste zuerst. Ein einzelnes fehlerhaftes
  /// Ereignis wird übersprungen und darf die übrigen nie blockieren.
  ///
  /// Nicht entschlüsselbare Ereignisse aus der Zeit vor dem eigenen Beitritt (dafür gibt es keine
  /// Schlüssel; es können auch Kalender-, Einkaufs- oder Aufgabenänderungen sein) werden zu einem
  /// einzigen Hinweis zusammengefasst (#35).
  static List<ChatMessage> messages(Timeline timeline, {String? myUserId}) {
    final me = myUserId ?? timeline.room.client.userID;
    final joinedAt = me == null ? null : _joinedAt(timeline, me);
    final pastNames = _pastNames(timeline);
    final out = <ChatMessage>[];
    var hidden = 0;
    DateTime? firstHidden;
    for (final e in timeline.events.reversed) {
      try {
        final m = _map(timeline, e, pastNames);
        if (m == null) continue;
        if (m.undecryptable && joinedAt != null && m.time.isBefore(joinedAt)) {
          hidden++;
          firstHidden ??= m.time;
          continue;
        }
        out.add(m);
      } catch (err) {
        AppLog.e('chat', 'Ereignis konnte nicht dargestellt werden', err);
      }
    }
    if (hidden > 0) {
      out.insert(
        0,
        ChatMessage(id: beforeJoinId, senderId: '', senderName: '', time: firstHidden!, undecryptable: true, beforeJoin: true),
      );
    }
    return out;
  }

  /// Ungelesene **lesbare** Nachrichten anderer, höchstens [serverCount] (#65).
  ///
  /// Der Zähler des Servers (`notificationCount`) zählt auch verschlüsselte Ereignisse, die der Chat nicht
  /// als Nachricht zeigt: nicht entschlüsselbare (Sammelhinweis #35) sowie Kalender-, Einkaufs- und
  /// Aufgabenänderungen. Gezählt wird deshalb in der geladenen Zeitleiste, neueste zuerst, bis zur eigenen
  /// Lesemarke, eigenen Nachricht oder zum eigenen Beitritt. Der Server bleibt die Obergrenze; meldet er 0,
  /// ist alles gelesen.
  static int unreadReadable(Timeline timeline, {required int serverCount, String? myUserId}) {
    if (serverCount <= 0) return 0;
    final room = timeline.room;
    final me = myUserId ?? room.client.userID;
    final marker = room.fullyRead;
    final readAt = room.receiptState.global.latestOwnReceipt?.ts ?? 0;
    var n = 0;
    for (final e in timeline.events) {
      if (marker.isNotEmpty && e.eventId == marker) break;
      if (e.originServerTs.millisecondsSinceEpoch <= readAt) break;
      if (e.senderId == me) {
        if (e.type == EventTypes.Message || e.type == EventTypes.RoomMember) break;
        continue;
      }
      if (e.type != EventTypes.Message || e.relationshipType == RelationshipTypes.edit || e.redacted) continue;
      if (e.messageType.startsWith('m.key.verification.')) continue;
      if (++n >= serverCount) break;
    }
    return n;
  }

  /// Zeitpunkt des letzten eigenen Beitritts, sofern er in der geladenen Zeitleiste liegt.
  static DateTime? _joinedAt(Timeline timeline, String me) {
    for (final e in timeline.events) {
      if (e.type != EventTypes.RoomMember || e.stateKey != me) continue;
      if (e.content.tryGet<String>('membership') != 'join') continue;
      if (e.prevContent?.tryGet<String>('membership') == 'join') continue; // nur Namens-/Bildänderung
      return e.originServerTs;
    }
    return null;
  }

  /// Letzter bekannter Anzeigename je Person aus den Mitglieds-Ereignissen der Zeitleiste (neueste zuerst).
  static Map<String, String> _pastNames(Timeline timeline) {
    final out = <String, String>{};
    for (final e in timeline.events) {
      final id = e.stateKey;
      if (e.type != EventTypes.RoomMember || id == null || out.containsKey(id)) continue;
      final n = TextSanitizer.clean(
        e.content.tryGet<String>('displayname') ?? e.prevContent?.tryGet<String>('displayname') ?? '',
      );
      if (n.isNotEmpty) out[id] = n;
    }
    return out;
  }

  /// Anzeigename des Absenders. Wer sein Konto gelöscht hat, hat keinen Namen mehr (der Server leert ihn vor
  /// dem Austritt). Dann gilt der letzte Name aus der Zeitleiste; ist keiner geladen, bleibt der Name leer
  /// und die Oberfläche zeigt „Ehemaliges Mitglied“ statt der Matrix-ID (#60).
  static String _senderName(Event e, Map<String, String> pastNames) {
    final u = e.senderFromMemoryOrFallback;
    final current = TextSanitizer.clean(u.displayName ?? '');
    if (current.isNotEmpty) return current;
    final past = pastNames[e.senderId];
    if (past != null) return past;
    final gone = u.membership == Membership.leave || u.membership == Membership.ban;
    return gone ? '' : TextSanitizer.displayName(null, e.senderId);
  }

  static ChatMessage? _map(Timeline timeline, Event e, Map<String, String> pastNames) {
    final name = _senderName(e, pastNames);
    final status = e.status.isError
        ? MessageStatus.failed
        : (e.status.isSent ? MessageStatus.sent : MessageStatus.sending);

    // Nicht entschlüsselbare Nachrichten sichtbar machen, statt sie zu verschlucken.
    if (e.type == EventTypes.Encrypted) {
      return ChatMessage(
        id: e.eventId,
        senderId: e.senderId,
        senderName: name,
        time: e.originServerTs,
        undecryptable: true,
        status: status,
      );
    }
    if (e.type != EventTypes.Message || e.relationshipType == RelationshipTypes.edit || e.redacted) {
      return null;
    }

    // Geräte-Verifizierung (`m.key.verification.request` als Raumnachricht) ist kein Chat-Inhalt (#29).
    if (e.messageType.startsWith('m.key.verification.')) return null;

    final d = e.getDisplayEvent(timeline);
    final isFile = _fileTypes.contains(d.messageType);
    AttachmentInfo? attachment;
    var blocked = false;
    if (isFile) {
      final info = d.content.tryGetMap<String, Object?>('info');
      final size = info?.tryGet<int>('size');
      final mime = d.attachmentMimetype.toLowerCase();
      final rawName = d.content.tryGet<String>('filename') ?? d.body;
      final fileName = AttachmentPolicy.sanitizeFileName(rawName);
      // Größe muss bekannt sein; Endung und behaupteter Typ müssen zusammenpassen.
      if (size != null &&
          AttachmentPolicy.incomingAllowed(mimeType: mime, size: size) &&
          AttachmentPolicy.mimeForName(fileName) == mime) {
        attachment = AttachmentInfo(name: fileName, mimeType: mime, size: size);
      } else {
        blocked = true;
      }
    }

    final reactions = <String, Set<String>>{};
    for (final r in e.aggregatedEvents(timeline, RelationshipTypes.reaction)) {
      final key = r.content.tryGetMap<String, Object?>('m.relates_to')?.tryGet<String>('key');
      if (key == null || !TextSanitizer.isReactionKey(key)) continue;
      if (!reactions.containsKey(key) && reactions.length >= maxReactionKeys) continue;
      reactions.putIfAbsent(key, () => <String>{}).add(r.senderId);
    }

    final ref = d.content.tryGet<String>('de.inneso.familynexus.event_ref');
    return ChatMessage(
      id: e.eventId,
      senderId: e.senderId,
      senderName: name,
      time: e.originServerTs,
      sharedEventId: (ref != null && CalendarEvent.isValidId(ref)) ? ref : null,
      body: isFile ? '' : d.calcUnlocalizedBody(hideReply: true),
      replyToId: e.inReplyToEventId(includingFallback: false),
      reactions: reactions,
      attachment: attachment,
      blockedAttachment: blocked,
      status: status,
    );
  }
}
