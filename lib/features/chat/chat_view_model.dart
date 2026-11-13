import '../../domain/chat.dart';

/// Was der Chat-Tab zeigt (#423, E-100).
enum ChatViewKind {
  /// Ein angefordertes Gespräch ist noch nicht erschienen (#31): Ladeanzeige ohne Eingabefeld.
  opening,

  /// Die Gesprächsliste (Startseite des Tabs, kein Gespräch geöffnet).
  list,

  /// Ein Gespräch mit Verlauf und Eingabefeld.
  conversation,
}

/// Ergebnis von [resolveChatView]: die Ansicht und was der Aufbau daraus ableitet.
class ChatView {
  const ChatView({
    required this.kind,
    this.shownId,
    this.current,
    this.showHeader = false,
    this.followFamily = false,
    this.pin = false,
    this.endWaiting = false,
  });

  final ChatViewKind kind;

  /// Gezeigte Gesprächs-ID: nur bei [ChatViewKind.conversation]. Verlauf, Senden, Lesen und Nachladen nutzen
  /// sie, nie den Wunsch des Nutzers (`_open`), damit im Frame eines verschwindenden Gesprächs nie die alte ID
  /// geladen oder gelesen markiert wird.
  final String? shownId;

  /// Das gezeigte Gespräch aus der sichtbaren Gesprächsmenge (kann bei fehlendem Familienraum `null` sein).
  final ChatThread? current;

  /// Kopfzeile mit Zurück-Pfeil: nur bei mehreren Gesprächen.
  final bool showHeader;

  /// Das geöffnete Gespräch ist verschwunden: `_open` wird auf den Familienchat gesetzt.
  final bool followFamily;

  /// Das einzige Gespräch (Familienchat) wird als geöffnet festgehalten, damit ein später hinzukommender
  /// Einzelchat den Nutzer nicht aus dem Familienchat reißt.
  final bool pin;

  /// Das gewartete Gespräch ist erschienen: Warten und Timer beenden.
  final bool endWaiting;
}

/// Leitet die Ansicht aus den sichtbaren Gesprächen [threads], dem gewünschten Gespräch [open] (`null` = keines
/// geöffnet) und dem Warten ab. Feste Rangfolge, die erste zutreffende Zeile gilt:
/// 1. angefordertes Gespräch noch nicht erschienen: Warten (auch ohne weitere Gespräche, #31),
/// 2. geöffnetes Gespräch verschwunden: Familienchat,
/// 3. nur ein Gespräch: Familienchat ohne Kopfzeile,
/// 4. mehrere Gespräche, keines geöffnet: Liste,
/// 5. mehrere Gespräche, eines geöffnet: das Gespräch mit Kopfzeile.
ChatView resolveChatView({
  required List<ChatThread> threads,
  required String? open,
  required String? waitingFor,
  required bool active,
  required bool initialSyncDone,
}) {
  final multi = threads.length > 1;
  final inThreads = open != null && threads.any((t) => t.id == open);
  final family = threads.where((t) => t.isFamily).firstOrNull;
  if (waitingFor != null && waitingFor == open && !inThreads) {
    return ChatView(kind: ChatViewKind.opening, showHeader: multi);
  }
  if (open != null && open != ChatThread.familyId && !inThreads) {
    return ChatView(
      kind: ChatViewKind.conversation,
      shownId: ChatThread.familyId,
      current: family,
      showHeader: multi,
      followFamily: true,
    );
  }
  if (!multi) {
    return ChatView(
      kind: ChatViewKind.conversation,
      shownId: ChatThread.familyId,
      current: family,
      pin: active && initialSyncDone && waitingFor == null && open == null,
    );
  }
  if (!inThreads) return const ChatView(kind: ChatViewKind.list);
  final current = threads.firstWhere((t) => t.id == open);
  return ChatView(
    kind: ChatViewKind.conversation,
    shownId: current.id,
    current: current,
    showHeader: true,
    endWaiting: waitingFor == open,
  );
}
