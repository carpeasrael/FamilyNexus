import '../../domain/chat.dart';

/// Ein Eintrag im Chatverlauf (#254): Nachricht, Datumszeile oder Marke „Neue Nachrichten“.
sealed class ChatEntry {
  const ChatEntry();

  /// Schlüssel des Listeneintrags. Datumszeilen und Marke beginnen mit `~fn-`; Matrix-IDs beginnen mit `$`,
  /// lokale Sende-IDs nie mit `~`, damit kann nichts mit einer Nachricht zusammenfallen (#130).
  String get key;
}

class MessageEntry extends ChatEntry {
  const MessageEntry(this.message);
  final ChatMessage message;

  @override
  String get key => message.id;
}

class DayEntry extends ChatEntry {
  const DayEntry(this.day, {this.repeat = 0});

  /// Kalendertag in Ortszeit (00:00).
  final DateTime day;

  /// Wievielte weitere Datumszeile desselben Tages (0 = die erste). Die Zeitleiste ist nicht nach Zeit sortiert
  /// (Nachrichten verschiedener Homeserver um Mitternacht), derselbe Tag kann also mehrfach beginnen (#295).
  final int repeat;

  @override
  String get key => '~fn-day-${day.year}-${day.month}-${day.day}${repeat == 0 ? '' : '-r$repeat'}';
}

class UnreadMarkerEntry extends ChatEntry {
  const UnreadMarkerEntry();

  static const String markerKey = '~fn-unread';

  @override
  String get key => markerKey;
}

/// Art der Datumszeile.
enum ChatDay { today, yesterday, other }

/// Ordnet [day] (Ortszeit) relativ zu [now] (Ortszeit) ein. Gerechnet wird mit Kalendertagen, nicht mit 24 Stunden,
/// damit Zeitumstellungen nichts verschieben.
ChatDay chatDayOf(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return ChatDay.today;
  if (d == DateTime(today.year, today.month, today.day - 1)) return ChatDay.yesterday;
  return ChatDay.other;
}

/// Baut die Einträge des Verlaufs, älteste zuerst: vor der ersten Nachricht eines Kalendertags (Ortszeit) eine
/// Datumszeile, vor [unreadFromId] die Marke. Liegt [unreadFromId] nicht unter [messages] (z. B. Nachricht eines
/// blockierten Mitglieds), setzt die Marke vor der ersten Nachricht, die in [allIds] danach kommt; [allIds] ist die
/// ungefilterte Reihenfolge des Gesprächs, älteste zuerst. Ohne Nachfolger entfällt die Marke.
List<ChatEntry> chatEntries(List<ChatMessage> messages, {String? unreadFromId, List<String> allIds = const <String>[]}) {
  final markerAt = _markerTarget(messages, unreadFromId, allIds);
  final entries = <ChatEntry>[];
  DateTime? lastDay;
  final linesPerDay = <DateTime, int>{};
  for (final m in messages) {
    final t = m.time.toLocal();
    final day = DateTime(t.year, t.month, t.day);
    if (lastDay == null || day != lastDay) {
      final before = linesPerDay[day] ?? 0;
      linesPerDay[day] = before + 1;
      entries.add(DayEntry(day, repeat: before));
      lastDay = day;
    }
    if (m.id == markerAt) entries.add(const UnreadMarkerEntry());
    entries.add(MessageEntry(m));
  }
  return entries;
}

String? _markerTarget(List<ChatMessage> messages, String? unreadFromId, List<String> allIds) {
  if (unreadFromId == null) return null;
  final visible = <String>{for (final m in messages) if (!m.beforeJoin) m.id};
  if (visible.contains(unreadFromId)) return unreadFromId;
  final start = allIds.indexOf(unreadFromId);
  if (start < 0) return null;
  for (var i = start + 1; i < allIds.length; i++) {
    if (visible.contains(allIds[i])) return allIds[i];
  }
  return null;
}
