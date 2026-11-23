import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_log.dart';
import '../../domain/book_policy.dart';
import '../../domain/book_signal.dart';
import '../../domain/cash_book.dart';
import '../../domain/cash_book_service.dart';
import '../../domain/cash_book_store.dart';
import '../matrix/matrix_gateway.dart';
import 'cash_book_receipts.dart';
import 'send_backoff.dart';

/// Verbindet die Kassenbücher mit Matrix (#311, E-113), nach dem Muster der übrigen Sync-Klassen:
///
/// * eingehend: Signale der Buch-Räume streng prüfen ([CashBookCodec]), die **Annahmeregel** anwenden (Absender war im
///   Raum Mitglied: `join`, `leave`, `invite` oder `ban`, frisch vom Server), über [CashBookService] zusammenführen;
/// * ausgehend: eigene, noch nicht gesendete Buch-Metadaten und Einträge (Warteschlange mit Wiederholung, höchstens 50
///   je Raum und Durchlauf, vorher über 1 Tag alte Zeitstempel neu stempeln), Sendeschutz im Gateway;
/// * Resync: beim Beitritt eines Mitglieds die eigenen Einträge (und als Ersteller die Metadaten) erneut senden;
/// * Zeitgeber ([tick]): Vollständigkeit, Platzhalter-Buch, Aufräumen verlassener Bücher, Abgleich (Ersteller).
///
/// Solange [enabled] `false` ist (Sperre [CashBookFlags.enabled]), tut die Klasse nichts: Sie hört nicht zu, sendet
/// nichts, greift nie auf das Gateway oder die Ablage zu und startet keinen Zeitgeber.
class CashBookSync {
  CashBookSync({
    required this.gateway,
    required this.service,
    required this.store,
    required this.familyRoom,
    this.enabled = CashBookFlags.enabled,
    this.retryInterval = const Duration(seconds: 60),
    this.receipts,
    this.fallbackCurrency = 'EUR',
    this.memberFetchInterval = const Duration(seconds: 30),
    DateTime Function()? clock,
    Duration backoffBase = const Duration(seconds: 5),
    Duration backoffMax = const Duration(seconds: 60),
  })  : _clock = clock ?? DateTime.now,
        _backoff = SendBackoff(clock: clock, base: backoffBase, max: backoffMax);

  final MatrixGateway gateway;
  final CashBookService service;
  final CashBookStore store;

  /// Familienraum, zu dem der lokale Bestand gehört (#140); ein anderer lässt die Klasse ruhen.
  final String? familyRoom;
  final bool enabled;
  final Duration retryInterval;
  final String fallbackCurrency;

  /// Bon-Dateien (3b): Aufräumen im Zeitgeber und nach erfolgreichem Senden.
  final CashBookReceipts? receipts;
  final Duration memberFetchInterval;
  final DateTime Function() _clock;
  final SendBackoff _backoff;

  /// Wird nach jeder Änderung des lokalen Bestands aufgerufen (Anzeige neu aufbauen).
  void Function()? onChanged;

  /// Verworfene (ungültige, gefälschte oder unberechtigte) Ereignisse.
  int rejected = 0;

  /// Räume, in denen der Sendeschutz das Senden verhindert (Fremde im Raum); für die Oberfläche.
  final Set<String> blockedRooms = <String>{};

  static const int maxHeld = 2000;
  static const int maxBatch = 50;

  StreamSubscription<BookSignal>? _sub;
  Timer? _timer;
  Timer? _debounce;
  bool _publishing = false;
  bool _again = false;
  Future<void> _queue = Future<void>.value();

  final Map<String, Set<String>> _members = <String, Set<String>>{};
  final Map<String, DateTime> _lastFetch = <String, DateTime>{};
  final Map<(String, String, String), _Held> _held = <(String, String, String), _Held>{};
  final Map<String, int> _undecryptableSeen = <String, int>{};
  final Set<String> _seenInBooks = <String>{};
  final Map<String, ({DateTime first, int ticks})> _gone = <String, ({DateTime first, int ticks})>{};
  final Map<String, int> _stale = <String, int>{};

  String get _me => service.myUserId;

  /// Merkt oder löscht den Sendeschutz eines Raums und meldet **nur eine tatsächliche Änderung** (für die Oberfläche).
  void _setBlocked(String room, bool blocked) {
    final changed = blocked ? blockedRooms.add(room) : blockedRooms.remove(room);
    if (changed) onChanged?.call();
  }

  @visibleForTesting
  SendBackoff get backoff => _backoff;

  @visibleForTesting
  int get heldCount => _held.length;

  bool get _sameFamily {
    final current = gateway.family?.roomId;
    return current == null || familyRoom == null || current == familyRoom;
  }

  bool get _canPublish =>
      gateway.session == SessionState.ready && gateway.initialSyncDone && gateway.family != null && _sameFamily;

  void _enqueue(Future<void> Function() task) {
    _queue = _queue.then((_) => task()).catchError((Object e) {
      AppLog.e('cashbook', 'Buch-Ereignis konnte nicht verarbeitet werden', e);
    });
  }

  /// Wartet, bis alle bisher eingegangenen Signale verarbeitet sind (Schließen der Familie, Tests).
  Future<void> idle() => _queue;

  void start() {
    if (!enabled) return;
    _sub ??= gateway.bookSignals.listen((s) => _enqueue(() => _onSignal(s)));
    _timer ??= Timer.periodic(retryInterval, (_) => tick().ignore());
    _backoff.changed(_gatewayState());
    gateway.addListener(_onGatewayChanged);
    kick();
  }

  Object _gatewayState() =>
      (gateway.session, gateway.userId, gateway.server, gateway.family?.roomId, gateway.initialSyncDone);

  /// Im Wartefenster nach einem Sendefehler löst eine Meldung des Gateways keinen neuen Versuch aus (#132).
  void _onGatewayChanged() {
    final changed = _backoff.changed(_gatewayState());
    if (!changed && _backoff.blocked) return;
    kick();
  }

  void dispose() {
    _stale.clear();
    _sub?.cancel().ignore();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _debounce?.cancel();
    if (enabled) gateway.removeListener(_onGatewayChanged);
  }

  void kick() {
    if (!enabled) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => publishPending().ignore());
  }

  // ------------------------------------------------------------------ Eingang

  Future<void> _onSignal(BookSignal s) async {
    if (!_sameFamily) return;
    try {
      switch (s.kind) {
        case BookSignalKind.meta:
          final meta = CashBookCodec.decodeMeta(s.content, roomId: s.roomId, sender: s.sender, creator: s.creatorId);
          if (meta == null) {
            rejected++;
            AppLog.w('cashbook', 'Ungültige Buch-Metadaten verworfen');
            return;
          }
          if (await service.applyBook(meta)) onChanged?.call();
          await _retryHeld();
        case BookSignalKind.entry:
          final entry = CashBookCodec.decodeEntry(s.content, sender: s.sender, serverTime: s.timestamp);
          if (entry == null) {
            rejected++;
            AppLog.w('cashbook', 'Ungültigen Eintrag verworfen');
            return;
          }
          await _deliver(_Held(s.roomId, entry));
        case BookSignalKind.memberJoined:
          if (s.sender == _me) return;
          _members.remove(s.roomId);
          await store.requeueOwn(s.roomId, _me);
          if (s.creatorId == _me) await store.requeueBook(s.roomId);
          kick();
      }
    } catch (e) {
      AppLog.e('cashbook', 'Buch-Ereignis konnte nicht verarbeitet werden', e);
    }
  }

  /// `true`: Absender war Mitglied; `false`: war es nachweislich nie; `null`: noch unbekannt (warten).
  Future<bool?> _knownSender(String room, String sender) async {
    if (_members[room]?.contains(sender) ?? false) return true;
    final now = _clock();
    final last = _lastFetch[room];
    if (last != null && now.difference(last) < memberFetchInterval) return null;
    _lastFetch[room] = now; // auch nach einem Fehler: höchstens ein Abruf je Fenster und Raum
    try {
      final set = await gateway.bookKnownMembers(room);
      _members[room] = set;
      return set.contains(sender);
    } on GatewayException catch (e) {
      AppLog.w('cashbook', 'Mitglieder des Buchs nicht geladen (${e.error.name})');
      return null;
    }
  }

  Future<void> _deliver(_Held h) async {
    final known = await _knownSender(h.roomId, h.entry.author);
    if (known == null) {
      _hold(h);
      return;
    }
    if (!known) {
      rejected++;
      AppLog.w('cashbook', 'Eintrag eines Nichtmitglieds verworfen');
      return;
    }
    if (await store.getBook(h.roomId) == null) {
      _hold(h);
      return;
    }
    _held.remove(h.key);
    final r = await service.applyEntry(h.roomId, h.entry);
    if (r == null) {
      rejected++;
    } else if (r == CashResolution.insert || r == CashResolution.replace) {
      onChanged?.call();
    }
  }

  /// Wartende Einträge (nur im Speicher; das Gateway spielt die Historie nach einem Neustart neu ein): je Eintrag die
  /// höchste Version, insgesamt höchstens [maxHeld]; bei Überlauf fällt der älteste weg und das Buch gilt als unvollständig.
  void _hold(_Held h) {
    final old = _held[h.key];
    if (old != null && old.entry.version > h.entry.version) return;
    _held[h.key] = h;
    if (_held.length > maxHeld) {
      final dropped = _held.remove(_held.keys.first)!;
      AppLog.w('cashbook', 'Wartende Einträge über der Grenze: ältester verworfen');
      store.setComplete(dropped.roomId, false).ignore();
    }
  }

  Future<void> _retryHeld() async {
    if (_held.isEmpty) return;
    for (final h in List<_Held>.of(_held.values)) {
      _held.remove(h.key);
      await _deliver(h);
    }
  }

  // ------------------------------------------------------------------- Ausgang

  /// Sendet alle noch nicht gesendeten eigenen Ereignisse. Läuft nie parallel. Unerwartete Fehler werden protokolliert
  /// und zählen als Fehlversuch. Der sichtbare Stand hängt nie vom Ausgang ab.
  Future<void> publishPending() async {
    if (!enabled) return;
    if (_publishing) {
      _again = true;
      return;
    }
    _publishing = true;
    try {
      do {
        _again = false;
        if (!_canPublish) break;
        await _retryHeld();
        final books = <String, BookRoomInfo>{for (final b in gateway.books) b.roomId: b};
        _seenInBooks.addAll(books.keys);
        if (!await _publishMetas(books)) return;
        if (!await _publishEntries(books)) return;
        _backoff.success();
        await receipts?.flushCleanup();
      } while (_again);
    } catch (e) {
      AppLog.e('cashbook', 'Sendedurchlauf gescheitert', e);
      _backoff.failure();
    } finally {
      _publishing = false;
    }
  }

  /// `false`: Durchlauf beenden (Fehlversuch gezählt).
  Future<bool> _publishMetas(Map<String, BookRoomInfo> books) async {
    for (final meta in await store.pendingBooks(_me)) {
      if (!books.containsKey(meta.roomId)) continue;
      if (!_canPublish) return false;
      final Map<String, Object?> content;
      try {
        content = CashBookCodec.encodeMeta(meta);
      } on StateError {
        AppLog.w('cashbook', 'Buch-Metadaten nicht sendbar, Warteschlange bereinigt');
        await store.markBookPublished(meta);
        continue;
      }
      final r = await _send(meta.roomId, <BookOutgoing>[BookOutgoing(CashBookCodec.metaType, content)]);
      if (r == null) return false;
      switch (r.single) {
        case BookSendResult.sent || BookSendResult.invalid:
          await store.markBookPublished(meta);
        case BookSendResult.blocked:
          _setBlocked(meta.roomId, true);
        case BookSendResult.failed:
          _backoff.failure();
          return false;
      }
    }
    return true;
  }

  Future<bool> _publishEntries(Map<String, BookRoomInfo> books) async {
    final byRoom = <String, List<CashEntry>>{};
    for (final p in await store.pending(_me)) {
      if (books.containsKey(p.roomId)) byRoom.putIfAbsent(p.roomId, () => <CashEntry>[]).add(p.entry);
    }
    for (final room in byRoom.keys) {
      if (!_canPublish) return false;
      final queued = byRoom[room]!..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      final batch = <CashEntry>[];
      final out = <BookOutgoing>[];
      for (final e in queued.take(maxBatch)) {
        // Neu lesen und gegebenenfalls neu stempeln: nie die Kopie aus der Warteschlange senden.
        final fresh = await service.restamp(room, e.id, expectedVersion: e.version, expectedDeleted: e.deleted);
        if (fresh == null) continue;
        try {
          out.add(BookOutgoing(CashBookCodec.entryType, CashBookCodec.encodeEntry(fresh)));
          batch.add(fresh);
        } on StateError {
          AppLog.w('cashbook', 'Eintrag nicht sendbar, Warteschlange bereinigt');
          await store.markPublished(room, _me, fresh.id, fresh.version);
        }
      }
      if (out.isEmpty) continue;
      final results = await _send(room, out);
      if (results == null) return false;
      var allSent = true;
      var failed = false;
      for (var i = 0; i < batch.length; i++) {
        final e = batch[i];
        switch (results[i]) {
          case BookSendResult.sent:
            _setBlocked(room, false);
            await store.markPublished(room, _me, e.id, e.version);
          case BookSendResult.invalid:
            AppLog.w('cashbook', 'Eintrag nicht sendbar, Warteschlange bereinigt');
            await store.markPublished(room, _me, e.id, e.version);
          case BookSendResult.blocked:
            allSent = false;
            _setBlocked(room, true);
          case BookSendResult.failed:
            allSent = false;
            failed = true;
        }
      }
      if (failed) {
        _backoff.failure();
        return false;
      }
      if (allSent && queued.length > maxBatch) _again = true;
    }
    return true;
  }

  /// `null`: Gateway-Fehler (Fehlversuch gezählt, Durchlauf endet).
  Future<List<BookSendResult>?> _send(String room, List<BookOutgoing> events) async {
    try {
      return await gateway.publishBookEvents(room, events);
    } on GatewayException catch (e) {
      AppLog.w('cashbook', 'Senden verschoben (${e.error.name})');
      _backoff.failure();
      return null;
    }
  }

  // ---------------------------------------------------------------- Zeitgeber

  /// Ein Zeitgeberlauf: Vollständigkeit und Platzhalter-Buch, Aufräumen, Abgleich (nur als Ersteller), danach Senden.
  /// Nie aus [kick]: Der Abgleich verlangt zwei **aufeinanderfolgende** Durchläufe über Zeit.
  Future<void> tick() async {
    if (!enabled) return;
    final done = Completer<void>();
    _enqueue(() async {
      try {
        await _completeness();
        await _cleanup();
        await _leaveStale();
        await _reconcile();
      } finally {
        done.complete();
      }
    });
    await done.future;
    await publishPending();
    await receipts?.flushCleanup();
  }

  Future<void> _completeness() async {
    if (!_canPublish) return;
    for (final b in gateway.books) {
      if (!gateway.bookHistoryComplete(b.roomId)) {
        _undecryptableSeen.remove(b.roomId);
        continue;
      }
      final count = gateway.bookUndecryptableCount(b.roomId);
      if (await store.getBook(b.roomId) == null) {
        // Kein Meta im Verlauf: nur bei stabilem Stand (nichts mehr zu entschlüsseln oder unverändert über zwei Läufe).
        if (count == 0 || _undecryptableSeen[b.roomId] == count) {
          if (await service.applyFallback(b.roomId, owner: b.creatorId, currency: fallbackCurrency)) onChanged?.call();
          await _retryHeld();
        }
        _undecryptableSeen[b.roomId] = count;
      }
      if (count == 0 && await store.getBook(b.roomId) != null && !await store.isComplete(b.roomId)) {
        await store.setComplete(b.roomId, true);
        onChanged?.call();
      }
    }
  }

  /// Ein lokales Buch wird nur gelöscht, wenn es in dieser Sitzung in `gateway.books` stand, das Gateway es als nicht
  /// mehr beigetreten meldet und das über mindestens zwei Zeitgeberläufe mit Abstand so bleibt.
  Future<void> _cleanup() async {
    if (!_canPublish) return;
    final present = <String>{for (final b in gateway.books) b.roomId};
    _seenInBooks.addAll(present);
    final now = _clock();
    for (final b in await store.books()) {
      final room = b.roomId;
      if (!_seenInBooks.contains(room) || present.contains(room) || !gateway.bookRoomGone(room)) {
        _gone.remove(room);
        continue;
      }
      final g = _gone[room];
      if (g == null) {
        _gone[room] = (first: now, ticks: 1);
        continue;
      }
      final ticks = g.ticks + 1;
      if (ticks >= 2 && now.difference(g.first) >= retryInterval ~/ 2) {
        await store.deleteBook(room);
        _gone.remove(room);
        _seenInBooks.remove(room);
        _members.remove(room);
        _lastFetch.remove(room);
        _held.removeWhere((k, _) => k.$1 == room);
        blockedRooms.remove(room);
        AppLog.w('cashbook', 'Verlassenes Buch lokal entfernt');
        onChanged?.call();
      } else {
        _gone[room] = (first: g.first, ticks: ticks);
      }
    }
  }

  /// Familienwechsel: Ein beigetretener Buch-Raum einer **anderen** Familie wird nach zwei aufeinanderfolgenden Läufen
  /// verlassen (auch als Ersteller; der lokale Speicher ist beim Wechsel schon geleert, `claimFamilyData`). Ohne
  /// belastbare Familie (kein Sync, `staleBooks` leer) geschieht nichts: Austritt ohne Nachfolgefamilie ist eine
  /// dokumentierte Grenze (E-113). Die Zähler werden bei jedem Lauf ohne Treffer, ohne Voraussetzungen und in [dispose] gelöscht.
  Future<void> _leaveStale() async {
    if (!_canPublish) {
      _stale.clear();
      return;
    }
    final stale = gateway.staleBooks.toSet();
    _stale.removeWhere((room, _) => !stale.contains(room));
    for (final room in stale) {
      final n = (_stale[room] ?? 0) + 1;
      _stale[room] = n;
      if (n < 2) continue;
      try {
        await gateway.leaveBook(room);
        _stale.remove(room);
        AppLog.w('cashbook', 'Buch einer früheren Familie verlassen');
      } on GatewayException catch (e) {
        AppLog.w('cashbook', 'Verlassen eines früheren Buchs verschoben (${e.error.name})');
      }
    }
  }

  Future<void> _reconcile() async {
    if (!_canPublish) return;
    for (final b in gateway.books) {
      if (b.creatorId != _me) continue;
      try {
        final removed = await gateway.reconcileBook(b.roomId);
        if (removed.isNotEmpty) {
          AppLog.w('cashbook', '${removed.length} nicht berechtigte Mitglieder aus dem Buch entfernt');
          _members.remove(b.roomId);
          onChanged?.call();
        }
      } on GatewayException catch (e) {
        AppLog.w('cashbook', 'Abgleich verschoben (${e.error.name})');
      }
    }
  }
}

/// Ein dekodierter Eintrag, der auf Mitgliedschaftsprüfung oder Buch-Metadaten wartet.
class _Held {
  _Held(this.roomId, this.entry);
  final String roomId;
  final CashEntry entry;
  (String, String, String) get key => (roomId, entry.author, entry.id);
}
