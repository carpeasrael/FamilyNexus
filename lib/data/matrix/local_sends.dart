/// Ein Sendeversuch. Liefert die Kennung des Servers oder `null`, wenn das SDK aufgegeben hat.
typedef SendAttempt = Future<String?> Function();

class _OpenSend {
  _OpenSend({
    required this.threadId,
    required this.roomId,
    required this.tail,
    required this.bytes,
    required this.send,
  });

  final String threadId;
  final String roomId;
  final String tail;
  final int bytes;
  final SendAttempt send;
  bool running = true;
  int autoRetries = 0;
}

/// Offene Chat-Sendungen dieses Prozesses (nur `m.room.message`), nach Transaktions-ID.
///
/// Wiederholt wird der ursprüngliche Aufruf, nie der Inhalt eines Zeitleisten-Ereignisses: `Event.sendAgain` sendete
/// sonst, was der Server in die Zeitleiste gestellt hat, verschlüsselt im eigenen Namen. Der Thread und der geprüfte
/// Raum gehören zur Sendung; `event_id`, `transaction_id` und Status eines Ereignisses kennt der Server und können
/// höchstens den echten Inhalt in derselben Zeitleiste erneut auslösen. Kalender, Einkauf, Aufgaben und Vermerke
/// wiederholen über ihre eigene Warteschlange.
class LocalSends {
  LocalSends({
    this.maxRetries = 5,
    this.maxOpen = 50,
    this.maxOpenBytes = 100 * 1024 * 1024,
    this.maxSentIds = 2000,
  });

  final int maxRetries;
  final int maxOpen;
  final int maxOpenBytes;
  final int maxSentIds;

  final Map<String, _OpenSend> _open = <String, _OpenSend>{}; // behält die Einfügereihenfolge
  final Map<String, String> _sent = <String, String>{};
  int _openBytes = 0;

  int get openCount => _open.length;

  /// Merkt die Sendung und führt sie aus. Bei einer Kennung des Servers ist sie erledigt; bei `null` oder einer
  /// Ausnahme bleibt sie offen. [tail] ist der Text, mit dem `body` enden muss: Antworten stellen das Zitat voran.
  Future<String?> run({
    required String txid,
    required String threadId,
    required String roomId,
    required String tail,
    int bytes = 0,
    required SendAttempt send,
  }) {
    final s = _OpenSend(threadId: threadId, roomId: roomId, tail: tail, bytes: bytes, send: send);
    _open[txid] = s;
    _openBytes += bytes;
    _enforceLimits();
    return _attempt(txid, s);
  }

  /// Wiederholt den ursprünglichen Aufruf, sofern [canRetry] gilt; sonst `null` ohne Versuch.
  Future<String?> retry(String txid, String threadId, String roomId) async {
    if (!canRetry(txid, threadId, roomId)) return null;
    final s = _open[txid]!..running = true;
    return _attempt(txid, s);
  }

  Future<String?> _attempt(String txid, _OpenSend s) async {
    try {
      final id = await s.send();
      // `clear` während des Laufs: Die Sendung gehört nicht mehr hierher, nichts wird nachgetragen.
      if (id != null && identical(_open[txid], s)) {
        _drop(txid);
        _sent[id] = s.tail;
        if (_sent.length > maxSentIds) _sent.remove(_sent.keys.first);
      }
      return id;
    } finally {
      s.running = false;
      _enforceLimits();
    }
  }

  /// Sendung vorhanden, auch laufend.
  bool isOpen(String? txid) => _open.containsKey(txid);

  /// Sendung läuft gerade.
  bool isRunning(String? txid) => _open[txid]?.running ?? false;

  /// Vorhanden, nicht laufend, gleicher Thread und gleicher Raum.
  bool canRetry(String txid, String threadId, String roomId) {
    final s = _open[txid];
    return s != null && !s.running && s.threadId == threadId && s.roomId == roomId;
  }

  /// Zählt einen automatischen Versuch, höchstens [maxRetries] je Sendung. Der Zähler endet nur mit einer echten
  /// Antwort des Servers; kein Ereignis der Zeitleiste setzt ihn zurück.
  bool takeAutoRetry(String txid) {
    final s = _open[txid];
    if (s == null || s.autoRetries >= maxRetries) return false;
    s.autoRetries++;
    return true;
  }

  /// Hat der Server [id] für eine eigene Sendung geliefert, und passt [body] dazu?
  bool sentMatches(String id, String body) {
    final tail = _sent[id];
    return tail != null && body.endsWith(tail);
  }

  void clear() {
    _open.clear();
    _sent.clear();
    _openBytes = 0;
  }

  void _drop(String txid) {
    final s = _open.remove(txid);
    if (s != null) _openBytes -= s.bytes;
  }

  /// Der älteste nicht laufende fällt heraus; laufende bleiben.
  void _enforceLimits() {
    while (_open.length > maxOpen || _openBytes > maxOpenBytes) {
      final String? oldest = _open.keys.where((id) => !_open[id]!.running).firstOrNull;
      if (oldest == null) return;
      _drop(oldest);
    }
  }
}
