import '../../domain/chat.dart';

/// Die Nachricht, die die Gesprächsliste als letzte zeigt (#423): die sichtbare mit dem **größten Zeitstempel**,
/// nicht die an letzter Stelle (die Zeitleiste ist nicht nach Zeit sortiert, #295). Bei gleichem Zeitstempel gewinnt
/// die spätere Position. Nachrichten blockierter Absender (außer eigenen) und der Sammelhinweis `beforeJoin` zählen
/// nicht; eigene, gerade gesendete und fehlgeschlagene zählen. Ein Durchlauf, keine Kopie.
ChatMessage? lastPreviewMessage(List<ChatMessage> messages, Set<String> blocked, String? myUserId) {
  ChatMessage? best;
  for (final m in messages) {
    if (m.beforeJoin) continue;
    if (m.senderId != myUserId && blocked.contains(m.senderId)) continue;
    if (best == null || !m.time.isBefore(best.time)) best = m;
  }
  return best;
}

/// Zeile der Gesprächsliste: Gespräch und seine letzte Nachricht (oder `null`).
class ThreadRow {
  const ThreadRow(this.thread, this.last);
  final ChatThread thread;
  final ChatMessage? last;
}

/// Reihenfolge der Liste: Familienchat zuerst, danach nach dem größten Zeitstempel der Vorschau absteigend,
/// Gespräche ohne Nachricht zuletzt nach Titel, dann Raum-ID (stabil).
List<ThreadRow> orderedThreadRows(
  List<ChatThread> threads,
  List<ChatMessage> Function(String threadId) messagesOf,
  Set<String> blocked,
  String? myUserId,
) {
  final rows = <ThreadRow>[
    for (final t in threads) ThreadRow(t, lastPreviewMessage(messagesOf(t.id), blocked, myUserId)),
  ];
  int byTitle(ThreadRow a, ThreadRow b) {
    final c = a.thread.title.toLowerCase().compareTo(b.thread.title.toLowerCase());
    return c != 0 ? c : a.thread.id.compareTo(b.thread.id);
  }

  rows.sort((a, b) {
    if (a.thread.isFamily != b.thread.isFamily) return a.thread.isFamily ? -1 : 1;
    final at = a.last?.time;
    final bt = b.last?.time;
    if (at != null && bt != null) {
      final c = bt.compareTo(at);
      return c != 0 ? c : byTitle(a, b);
    }
    if (at != null) return -1;
    if (bt != null) return 1;
    return byTitle(a, b);
  });
  return rows;
}
