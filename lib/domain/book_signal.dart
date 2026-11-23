/// Art eines Signals aus einem Buch-Raum (#311, E-113).
enum BookSignalKind { meta, entry, memberJoined }

/// Nicht vertrauenswürdige Rohdaten eines Ereignisses aus einem **Buch-Raum**. Eigener Typ und eigener Strom: Die
/// Familiendienste sehen Buch-Ereignisse nie, und die Historie der Familiensignale wird davon nicht verdrängt.
/// [creatorId] setzt das Gateway beim Auslösen (Ersteller laut `m.room.create`); [sender] ist der vom Server und der
/// Verschlüsselung gelieferte Absender; [content] prüft erst der `CashBookCodec`.
class BookSignal {
  const BookSignal({
    required this.roomId,
    required this.creatorId,
    required this.kind,
    required this.sender,
    required this.timestamp,
    this.content = const <String, Object?>{},
    this.eventId = '',
  });

  final String roomId;
  final String creatorId;
  final BookSignalKind kind;
  final String sender;
  final DateTime timestamp;
  final Map<String, Object?> content;
  final String eventId;
}

/// Ereignis, das ein Buch-Raum senden soll (`bookmeta` oder `cashentry`).
class BookOutgoing {
  const BookOutgoing(this.type, this.content);
  final String type;
  final Map<String, Object?> content;
}

/// Ergebnis je gesendetem Ereignis ([BookOutgoing]):
/// * `sent`: gesendet;
/// * `invalid`: dauerhaft nicht sendbar (Typ, Autor, Größe), nichts gesendet;
/// * `blocked`: Sendeschutz (Raum hat nicht berechtigte Mitglieder), nichts gesendet, Eintrag bleibt in der Warteschlange;
/// * `failed`: vorläufiger Fehler (Netz, Server, Mitgliederliste nicht belastbar), später erneut.
enum BookSendResult { sent, invalid, blocked, failed }
