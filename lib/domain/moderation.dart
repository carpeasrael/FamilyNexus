import 'chat.dart';
import 'server.dart';
import 'text_sanitizer.dart';

/// Gründe, die beim Melden einer Nachricht zur Auswahl stehen (E-48).
enum ReportCategory { spam, harassment, inappropriate, other }

/// Meldung einer fremden Nachricht an den Betreiber des Homeservers (Matrix `report`).
///
/// Der Server kann den Inhalt verschlüsselter Räume nicht lesen; übertragen werden nur Raum, Ereignis-ID und
/// der hier gebildete Grundtext. Der Freitext verlässt das Gerät unverschlüsselt und ist vom Nutzer
/// ausdrücklich zu bestätigen.
class ReportRequest {
  ReportRequest({required this.messageId, required this.category, String details = '', this.threadId = ChatThread.familyId})
      : details = TextSanitizer.clean(details, max: maxDetailsLength);

  static const int maxDetailsLength = 300;

  final String messageId;
  final String threadId;
  final ReportCategory category;

  /// Optionaler, bereinigter Freitext des Meldenden.
  final String details;

  /// Text für den Server, z. B. `harassment: Beleidigungen`.
  String get reason => details.isEmpty ? category.name : '${category.name}: $details';
}

/// Lokale Blockierliste: Nachrichten und Einzelchats blockierter Mitglieder werden ausgeblendet.
///
/// Die Liste liegt nur auf dem Gerät (verschlüsselte Datenbank), wird nicht synchronisiert und ändert nichts am
/// Raum: Wer blockiert wird, erfährt es nicht und bleibt Mitglied der Familie (E-48).
class BlockedUsers {
  const BlockedUsers._();

  static const int maxEntries = 200;
  static const String _separator = ',';

  /// Liest die gespeicherte Liste defensiv: ungültige IDs und Überlängen werden verworfen.
  static List<String> parse(String? raw) {
    if (raw == null || raw.isEmpty) return const <String>[];
    final out = <String>[];
    for (final part in raw.split(_separator)) {
      final id = part.trim();
      if (MatrixIds.isUserId(id) && !out.contains(id)) out.add(id);
      if (out.length >= maxEntries) break;
    }
    return List<String>.unmodifiable(out);
  }

  static String encode(Iterable<String> ids) => ids.join(_separator);

  /// Fügt [userId] hinzu; ungültige IDs, Dubletten und das Überschreiten der Obergrenze ändern nichts.
  static List<String> add(List<String> current, String userId) {
    if (!MatrixIds.isUserId(userId) || current.contains(userId) || current.length >= maxEntries) return current;
    return List<String>.unmodifiable(<String>[...current, userId]);
  }

  static List<String> remove(List<String> current, String userId) =>
      current.contains(userId) ? List<String>.unmodifiable(current.where((u) => u != userId)) : current;
}

/// Blendet Nachrichten blockierter Absender aus. Eigene Nachrichten bleiben immer sichtbar.
List<ChatMessage> visibleMessages(List<ChatMessage> messages, Iterable<String> blocked, {String? myUserId}) {
  final set = blocked.toSet();
  if (set.isEmpty) return messages;
  return <ChatMessage>[
    for (final m in messages)
      if (m.senderId == myUserId || !set.contains(m.senderId)) m,
  ];
}

/// Blendet Einzelchats mit blockierten Mitgliedern aus; der Familienchat bleibt immer erreichbar.
List<ChatThread> visibleThreads(List<ChatThread> threads, Iterable<String> blocked) {
  final set = blocked.toSet();
  if (set.isEmpty) return threads;
  return <ChatThread>[
    for (final t in threads)
      if (t.isFamily || t.peerId == null || !set.contains(t.peerId)) t,
  ];
}
