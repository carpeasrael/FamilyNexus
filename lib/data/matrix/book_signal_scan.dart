import 'package:matrix/matrix.dart';

import '../../domain/book_signal.dart';
import '../../domain/cash_book.dart';
import 'event_trust.dart';

/// Ausgang der Prüfung eines Ereignisses aus einem Buch-Raum.
enum BookScanOutcome {
  /// Gültiges Signal.
  signal,

  /// Nicht verschlüsselt angekommen, aber ein Buchtyp: löst nie ein Signal aus (nur Warnung).
  plaintext,

  /// Noch nicht entschlüsselt (`m.room.encrypted`): später erneut betrachten, zählt für die Vollständigkeit.
  undecrypted,

  /// Gelöscht, Fehlerstatus, fremder Typ oder `bookmeta` eines Nicht-Erstellers.
  ignored,
}

class BookScanResult {
  const BookScanResult(this.outcome, [this.signal]);
  final BookScanOutcome outcome;
  final BookSignal? signal;
}

/// Reine Prüfung eines SDK-Ereignisses aus einem Buch-Raum (#311, E-113). Der Raum ist durch die Karte des Gateways
/// bekannt, nie durch den Inhalt; `bookmeta` zählt nur vom Ersteller [creatorId].
class BookSignalScan {
  const BookSignalScan._();

  static const Set<String> types = <String>{CashBookCodec.metaType, CashBookCodec.entryType};

  static BookScanResult scan(Event e, {required String roomId, required String creatorId}) {
    if (e.redacted || e.status.isError) return const BookScanResult(BookScanOutcome.ignored);
    if (e.type == EventTypes.Encrypted) return const BookScanResult(BookScanOutcome.undecrypted);
    if (!types.contains(e.type)) return const BookScanResult(BookScanOutcome.ignored);
    if (!arrivedEncrypted(e)) return const BookScanResult(BookScanOutcome.plaintext);
    final isMeta = e.type == CashBookCodec.metaType;
    if (isMeta && e.senderId != creatorId) return const BookScanResult(BookScanOutcome.ignored);
    return BookScanResult(
      BookScanOutcome.signal,
      BookSignal(
        roomId: roomId,
        creatorId: creatorId,
        kind: isMeta ? BookSignalKind.meta : BookSignalKind.entry,
        sender: e.senderId,
        timestamp: e.originServerTs,
        content: e.content,
        eventId: e.eventId,
      ),
    );
  }
}
