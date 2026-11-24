import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/app_log.dart';
import '../../domain/cash_book.dart';
import '../../domain/cash_book_service.dart';
import '../../domain/cash_book_store.dart';
import '../../domain/cash_receipt_check.dart';
import '../matrix/matrix_gateway.dart';

/// Bon-Fotos im Kassenbuch (#311, E-113, Teil 3b): senden, geprüft laden, aufräumen. Ohne Oberfläche.
///
/// * **Zuerst die Datei, dann der Eintrag** ([createWithReceipt], [updateWithReceipt]); scheitert der Eintrag, kommt die
///   gerade gesendete Datei in die Aufräumwarteschlange.
/// * **Aufräumen nach bestem Bemühen, nie Zustandsträger** (E-111): Ersetzen, Entfernen und Löschen eines Bons löst über
///   [CashBookService.onReceiptReleased] einen Auftrag aus. Er wird **erst fällig, wenn die neue Fassung des Eintrags
///   veröffentlicht ist** (nicht mehr in `store.pending`), und nur, wenn **kein Eintrag** mehr auf die Datei verweist.
///   Höchstens [maxJobs] Aufträge, je Auftrag höchstens [maxAttempts] vorläufige Fehlversuche (mit Backoff), nur im
///   Speicher: Nach einem Neustart oder Absturz wird nicht erneut geschwärzt (eine verwaiste Datei wird nie angezeigt).
///
/// Solange [enabled] `false` ist (Sperre [CashBookFlags.enabled]), tut die Klasse nichts: keine Verdrahtung des Rückrufs,
/// kein Zugriff auf Gateway oder Ablage.
class CashBookReceipts {
  CashBookReceipts({
    required this.gateway,
    required this.service,
    required this.store,
    this.enabled = CashBookFlags.enabled,
    this.backoffBase = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (enabled) service.onReceiptReleased = _released;
  }

  final MatrixGateway gateway;
  final CashBookService service;
  final CashBookStore store;
  final bool enabled;
  final Duration backoffBase;
  final DateTime Function() _clock;

  static const int maxJobs = 100;
  static const int maxAttempts = 8;

  final List<_Job> _jobs = <_Job>[];
  bool _flushing = false;

  /// Anzahl der offenen Aufräumaufträge (Tests).
  int get jobCount => _jobs.length;

  void _released(String roomId, String entryId, String eventId) => _enqueue(_Job(roomId, entryId, eventId));

  void _enqueue(_Job job) {
    if (_jobs.any((j) => j.roomId == job.roomId && j.eventId == job.eventId)) return;
    _jobs.add(job);
    if (_jobs.length > maxJobs) {
      _jobs.removeAt(0);
      AppLog.w('cashbook', 'Aufräumaufträge über der Grenze: ältester verworfen');
    }
  }

  void dispose() {
    if (enabled && service.onReceiptReleased == _released) service.onReceiptReleased = null;
  }

  void _requireEnabled() {
    if (!enabled) throw const CashBookException(CashBookError.notAllowed);
  }

  /// Sendet das JPEG als Datei und liefert den Verweis für den Eintrag. Wirft [GatewayException].
  Future<CashReceipt> attach(String roomId, Uint8List jpeg) async {
    _requireEnabled();
    final id = await gateway.sendBookReceipt(roomId, jpeg);
    return CashReceipt(eventId: id, sha256: ReceiptCheck.sha256Hex(jpeg), size: jpeg.length);
  }

  /// Datei zuerst, dann der neue Eintrag. Scheitert der Eintrag, wird die Datei aufgeräumt.
  Future<CashEntry> createWithReceipt(
    String roomId, {
    required DateTime date,
    required String store,
    required int amountCents,
    String note = '',
    required Uint8List jpeg,
  }) async {
    final receipt = await attach(roomId, jpeg);
    try {
      return await service.create(roomId, date: date, store: store, amountCents: amountCents, note: note, receipt: receipt);
    } catch (_) {
      _enqueue(_Job(roomId, null, receipt.eventId));
      rethrow;
    }
  }

  /// Datei zuerst, dann die geänderte Fassung (mit dem neuen Bon). Die frühere Datei räumt der Rückruf des Dienstes auf.
  Future<CashEntry> updateWithReceipt(String roomId, CashEntry edited, Uint8List jpeg) async {
    final receipt = await attach(roomId, jpeg);
    try {
      return await service.update(roomId, edited.copyWith(receipt: receipt));
    } catch (_) {
      _enqueue(_Job(roomId, null, receipt.eventId));
      rethrow;
    }
  }

  /// Lädt und prüft die Bon-Datei eines Eintrags. Jeder Zustand außer `ok` heißt für die Oberfläche: Platzhalter.
  Future<BookReceiptLoad> load(String roomId, CashEntry entry) async {
    final receipt = entry.receipt;
    if (!enabled || receipt == null || entry.deleted) return const BookReceiptLoad(BookReceiptStatus.missing);
    try {
      return await gateway.loadBookReceipt(roomId, receipt.eventId, receipt: receipt, author: entry.author);
    } on GatewayException catch (e) {
      AppLog.w('cashbook', 'Bon-Datei nicht geladen (${e.error.name})');
      return const BookReceiptLoad(BookReceiptStatus.unavailable);
    }
  }

  bool get _canRun => gateway.session == SessionState.ready && gateway.initialSyncDone && gateway.family != null;

  static bool _permanent(GatewayError e) =>
      e == GatewayError.notAllowed || e == GatewayError.notFound || e == GatewayError.invalidInput;

  /// Arbeitet fällige Aufräumaufträge ab. Läuft nie parallel.
  Future<void> flushCleanup() async {
    if (!enabled || _jobs.isEmpty || _flushing || !_canRun) return;
    _flushing = true;
    try {
      final me = service.myUserId;
      final waiting = <(String, String)>{for (final p in await store.pending(me)) (p.roomId, p.entry.id)};
      final now = _clock();
      for (final job in List<_Job>.of(_jobs)) {
        final due = job.nextTry;
        if (due != null && now.isBefore(due)) continue;
        final entryId = job.entryId;
        if (entryId != null) {
          // Buch lokal entfernt: der Auftrag entfällt. Neue Fassung noch nicht veröffentlicht: warten (kein Fehlversuch).
          if (await store.getEntry(job.roomId, me, entryId) == null) {
            _jobs.remove(job);
            continue;
          }
          if (waiting.contains((job.roomId, entryId))) continue;
        }
        // Gegenlesen: Verweist noch ein Eintrag auf die Datei, bleibt sie.
        if ((await store.entries(job.roomId)).any((e) => e.receipt?.eventId == job.eventId)) {
          _jobs.remove(job);
          continue;
        }
        try {
          await gateway.redactBookReceipt(job.roomId, job.eventId);
          _jobs.remove(job);
        } on GatewayException catch (e) {
          if (_permanent(e.error)) {
            AppLog.w('cashbook', 'Aufräumen einer Bon-Datei entfällt (${e.error.name})');
            _jobs.remove(job);
          } else {
            job.attempts++;
            if (job.attempts >= maxAttempts) {
              AppLog.w('cashbook', 'Aufräumen einer Bon-Datei aufgegeben');
              _jobs.remove(job);
            } else {
              job.nextTry = now.add(backoffBase * math.pow(2, job.attempts - 1).toInt());
            }
          }
        }
      }
    } catch (e) {
      AppLog.e('cashbook', 'Aufräumen der Bon-Dateien gescheitert', e);
    } finally {
      _flushing = false;
    }
  }
}

class _Job {
  _Job(this.roomId, this.entryId, this.eventId);
  final String roomId;

  /// `null`: verwaiste neue Datei (kein Eintrag verweist darauf), sofort fällig.
  final String? entryId;
  final String eventId;
  int attempts = 0;
  DateTime? nextTry;
}
