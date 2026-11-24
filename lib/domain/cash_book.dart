import 'server.dart';
import 'text_sanitizer.dart';

/// Schalter des Kassenbuchs (#311, E-113). Mit `false` verhalten sich Gateway, Sync und Oberfläche wie vor dem Kassenbuch
/// (nur die ungesperrten Sicherheitspfade der Einladungstrennung greifen). Freigegeben mit dem Freigabe-PR (`true`).
class CashBookFlags {
  const CashBookFlags._();
  static const bool enabled = true;
}

/// Grenzen des Kassenbuchs (E-113).
class CashBookLimits {
  const CashBookLimits._();

  static const int maxTitle = 60;
  static const int maxStore = 60;
  static const int maxNote = 200;

  /// Höchstbetrag eines Eintrags in Cent (999 999,99); Pfand und Erstattungen (negativ) sind ausgeschlossen.
  static const int maxAmountCents = 99999999;
  static const int maxVersion = 0x7fffffff;

  /// Größter Versionssprung eines empfangenen Eintrags über der gespeicherten Fassung.
  static const int maxVersionStep = 1000;

  static const int maxEntriesPerAuthor = 3000;
  static const int maxBooksPerFamily = 10;
  static const int maxMembersPerBook = 10;

  /// Größte Abweichung zwischen `updated_at` und der Serverzeit des Ereignisses.
  static const Duration maxSkew = Duration(days: 2);

  /// Obergrenze des Bon-Fotos (Datei).
  static const int maxReceiptBytes = 1024 * 1024;

  static final DateTime minDate = DateTime.utc(2000);
  static final DateTime maxDate = DateTime.utc(2100, 12, 31);
}

/// Titel und Währung eines Buchs (`de.inneso.familynexus.bookmeta`). Gültig nur vom Ersteller des Buch-Raums.
class CashBookMeta {
  const CashBookMeta({
    required this.roomId,
    required this.title,
    required this.currency,
    required this.owner,
    this.version = 1,
  });

  final String roomId;
  final String title;

  /// ISO-4217 (drei Großbuchstaben).
  final String currency;

  /// Ersteller des Buch-Raums (Matrix-ID).
  final String owner;
  final int version;

  /// Rückfall, wenn kein `bookmeta` bekannt ist (Ersteller gelöscht, Verlauf unvollständig).
  static const String fallbackTitle = 'Kassenbuch';

  static final RegExp _currency = RegExp(r'^[A-Z]{3}$');

  List<String> validate() {
    final p = <String>[];
    if (roomId.isEmpty) p.add('room');
    if (!MatrixIds.isUserId(owner)) p.add('owner');
    final t = title.trim();
    if (t.isEmpty || title.length > CashBookLimits.maxTitle || TextSanitizer.clean(title, max: 1000) != t) p.add('title');
    if (!_currency.hasMatch(currency)) p.add('currency');
    if (version < 1 || version > CashBookLimits.maxVersion) p.add('version');
    return p;
  }

  CashBookMeta copyWith({String? title, String? currency, int? version}) => CashBookMeta(
        roomId: roomId,
        title: title ?? this.title,
        currency: currency ?? this.currency,
        owner: owner,
        version: version ?? this.version,
      );

  @override
  bool operator ==(Object other) =>
      other is CashBookMeta &&
      other.roomId == roomId &&
      other.title == title &&
      other.currency == currency &&
      other.owner == owner &&
      other.version == version;

  @override
  int get hashCode => Object.hash(roomId, title, currency, owner, version);
}

/// Verweis auf das Bon-Foto eines Eintrags: Ereignis der Datei, Hash und Größe der Bytes (E-113).
class CashReceipt {
  const CashReceipt({required this.eventId, required this.sha256, required this.size});

  final String eventId;

  /// SHA-256 der Dateibytes als 64 Kleinbuchstaben-Hexzeichen.
  final String sha256;
  final int size;

  static final RegExp _hex = RegExp(r'^[0-9a-f]{64}$');

  List<String> validate() {
    final p = <String>[];
    if (eventId.isEmpty || eventId.length > 255 || !eventId.startsWith(r'$')) p.add('receipt-event');
    if (!_hex.hasMatch(sha256)) p.add('receipt-hash');
    if (size < 1 || size > CashBookLimits.maxReceiptBytes) p.add('receipt-size');
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is CashReceipt && other.eventId == eventId && other.sha256 == sha256 && other.size == size;

  @override
  int get hashCode => Object.hash(eventId, sha256, size);
}

/// Ein Eintrag im Kassenbuch (`de.inneso.familynexus.cashentry`). Der Schlüssel ist `(Raum, [author], [id])`.
class CashEntry {
  const CashEntry({
    required this.id,
    required this.author,
    required this.date,
    required this.store,
    required this.amountCents,
    required this.updatedAt,
    this.version = 1,
    this.note = '',
    this.receipt,
    this.deleted = false,
  });

  final String id;

  /// Ersteller des Eintrags (Matrix-ID); beim Empfang gleich dem authentischen Absender.
  final String author;
  final int version;
  final bool deleted;

  /// Kalendertag des Einkaufs (UTC-Mitternacht des Tages).
  final DateTime date;
  final String store;

  /// Betrag in Cent, nie negativ.
  final int amountCents;
  final String note;
  final CashReceipt? receipt;
  final DateTime updatedAt;

  static final RegExp _idRe = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  static bool isValidId(String s) => _idRe.hasMatch(s);

  /// Fachliche Prüfung; leer = gültig.
  List<String> validate() {
    final p = <String>[];
    if (!isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(author)) p.add('author');
    if (version < 1 || version > CashBookLimits.maxVersion) p.add('version');
    if (!date.isUtc ||
        date.hour != 0 ||
        date.minute != 0 ||
        date.second != 0 ||
        date.millisecond != 0 ||
        date.isBefore(CashBookLimits.minDate) ||
        date.isAfter(CashBookLimits.maxDate)) {
      p.add('date');
    }
    if (!updatedAt.isUtc) p.add('utc');
    if (amountCents < 0 || amountCents > CashBookLimits.maxAmountCents) p.add('amount');
    final s = store.trim();
    if (s.isEmpty || store.length > CashBookLimits.maxStore || TextSanitizer.clean(store, max: 1000) != s) p.add('store');
    if (note.length > CashBookLimits.maxNote || TextSanitizer.clean(note, max: 1000) != note.trim()) p.add('note');
    final r = receipt;
    if (r != null) p.addAll(r.validate());
    if (deleted && receipt != null) p.add('receipt');
    return p;
  }

  CashEntry copyWith({
    int? version,
    bool? deleted,
    DateTime? date,
    String? store,
    int? amountCents,
    String? note,
    CashReceipt? receipt,
    bool clearReceipt = false,
    DateTime? updatedAt,
  }) =>
      CashEntry(
        id: id,
        author: author,
        version: version ?? this.version,
        deleted: deleted ?? this.deleted,
        date: date ?? this.date,
        store: store ?? this.store,
        amountCents: amountCents ?? this.amountCents,
        note: note ?? this.note,
        receipt: clearReceipt ? null : (receipt ?? this.receipt),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Löschmarke: behält Kennung und Autor, erhöht die Version, verrät sonst nichts.
  CashEntry tombstone(DateTime now) => CashEntry(
        id: id,
        author: author,
        version: version + 1,
        deleted: true,
        date: CashBookLimits.minDate,
        store: '–',
        amountCents: 0,
        updatedAt: now.toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is CashEntry &&
      other.id == id &&
      other.author == author &&
      other.version == version &&
      other.deleted == deleted &&
      other.date == date &&
      other.store == store &&
      other.amountCents == amountCents &&
      other.note == note &&
      other.receipt == receipt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, author, version, deleted, date, amountCents, updatedAt);
}

/// Ereignisformat des Kassenbuchs (E-113). Beide Typen sind verschlüsselte Ereignisse im Buch-Raum.
///
/// Sicherheitsregeln: strenge Typprüfung und [CashEntry.validate]/[CashBookMeta.validate]; `author` muss dem
/// authentischen Absender entsprechen (kein Schreiben in fremdem Namen), `bookmeta` nur vom Ersteller des Raums.
/// Ob der Absender je Mitglied des Raums war, prüft der Sync (Mitgliedschaft aus dem Raumzustand).
class CashBookCodec {
  const CashBookCodec._();

  static const String metaType = 'de.inneso.familynexus.bookmeta';
  static const String entryType = 'de.inneso.familynexus.cashentry';
  static const int schema = 1;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Map<String, Object?> encodeMeta(CashBookMeta m) {
    final problems = m.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiges Buch: ${problems.join(',')}');
    return <String, Object?>{'v': schema, 'title': m.title, 'currency': m.currency, 'version': m.version};
  }

  /// `null` bei ungültigem Inhalt oder wenn [sender] nicht der Ersteller [creator] des Buch-Raums ist.
  static CashBookMeta? decodeMeta(Map<String, Object?> c, {required String roomId, required String sender, required String creator}) {
    if (!MatrixIds.isUserId(sender) || sender != creator || c['v'] != schema) return null;
    final title = c['title'];
    final currency = c['currency'];
    final version = c['version'];
    if (title is! String || currency is! String || version is! int) return null;
    if (title.length > CashBookLimits.maxTitle * 2) return null;
    final m = CashBookMeta(roomId: roomId, title: title, currency: currency, owner: creator, version: version);
    return m.validate().isEmpty ? m : null;
  }

  static Map<String, Object?> encodeEntry(CashEntry e) {
    final problems = e.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Eintrag: ${problems.join(',')}');
    final r = e.receipt;
    return <String, Object?>{
      'v': schema,
      'id': e.id,
      'author': e.author,
      'version': e.version,
      'deleted': e.deleted,
      'date': _day(e.date),
      'store': e.store,
      'amount_cents': e.amountCents,
      'note': e.note,
      if (r != null) 'receipt': <String, Object?>{'event_id': r.eventId, 'sha256': r.sha256, 'size': r.size},
      'updated_at': e.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// Speicherformat der lokalen Ablage: gleich dem Ereignisformat. Wird nie gesendet.
  static Map<String, Object?> encodeStored(CashEntry e) => encodeEntry(e);

  /// `null` bei ungültigem Inhalt. `author` muss mit [sender] übereinstimmen. [serverTime]: Serverzeit des Ereignisses;
  /// `updated_at` darf höchstens [CashBookLimits.maxSkew] davon abweichen (beim Lesen aus der Ablage: `null`, keine Prüfung).
  static CashEntry? decodeEntry(Map<String, Object?> c, {required String sender, DateTime? serverTime}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final id = c['id'];
    final author = c['author'];
    final version = c['version'];
    final deleted = c['deleted'];
    final date = c['date'];
    final store = c['store'];
    final amount = c['amount_cents'];
    final note = c['note'];
    final ts = c['updated_at'];
    if (id is! String || author is! String || version is! int || deleted is! bool) return null;
    if (date is! String || store is! String || amount is! int || note is! String || ts is! int) return null;
    if (author != sender) return null;
    if (store.length > CashBookLimits.maxStore * 2 || note.length > CashBookLimits.maxNote * 2) return null;
    final day = _parseDay(date);
    if (day == null) return null;
    if (ts.abs() > 8640000000000000) return null;
    final updated = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    if (serverTime != null && updated.difference(serverTime.toUtc()).abs() > CashBookLimits.maxSkew) return null;
    CashReceipt? receipt;
    if (c.containsKey('receipt')) {
      final r = c['receipt'];
      if (r is! Map<String, Object?>) return null;
      final eventId = r['event_id'];
      final hash = r['sha256'];
      final size = r['size'];
      if (eventId is! String || hash is! String || size is! int) return null;
      receipt = CashReceipt(eventId: eventId, sha256: hash, size: size);
    }
    final e = CashEntry(
      id: id,
      author: author,
      version: version,
      deleted: deleted,
      date: day,
      store: store,
      amountCents: amount,
      note: note,
      receipt: receipt,
      updatedAt: updated,
    );
    return e.validate().isEmpty ? e : null;
  }

  static DateTime? _parseDay(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    final dt = DateTime.utc(y, mo, d);
    // DateTime.utc rollt ungültige Tage (31. Februar) in den Folgemonat: nur der unveränderte Tag ist gültig.
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }
}

/// Konfliktauflösung der Einträge (E-113): lexikografische Totalordnung `(gelöscht, Version, updated_at, kanonisch)`,
/// größer gewinnt. Eine Löschmarke schlägt jede lebende Fassung, alle Geräte konvergieren bei jeder Reihenfolge.
enum CashResolution { insert, replace, ignoreStale, ignoreDuplicate }

class CashEntryResolver {
  const CashEntryResolver._();

  static CashResolution resolve(CashEntry? current, CashEntry incoming) {
    if (current == null) return CashResolution.insert;
    if (incoming == current) return CashResolution.ignoreDuplicate;
    return _compare(incoming, current) > 0 ? CashResolution.replace : CashResolution.ignoreStale;
  }

  static int _compare(CashEntry a, CashEntry b) {
    if (a.deleted != b.deleted) return a.deleted ? 1 : -1;
    if (a.version != b.version) return a.version.compareTo(b.version);
    final byTime = a.updatedAt.compareTo(b.updatedAt);
    if (byTime != 0) return byTime;
    return _canonical(a).compareTo(_canonical(b));
  }

  static String _canonical(CashEntry e) {
    final m = CashBookCodec.encodeEntry(e);
    final keys = m.keys.toList()..sort();
    return keys.map((k) => '$k=${m[k]}').join('|');
  }
}

/// Summen eines Buchs (abgeleitet, nie gesendet).
class CashTotals {
  const CashTotals._();

  /// Summe der nicht gelöschten Einträge im Monat ([year], [month]) in Cent.
  static int month(Iterable<CashEntry> entries, int year, int month) => entries
      .where((e) => !e.deleted && e.date.year == year && e.date.month == month)
      .fold<int>(0, (sum, e) => sum + e.amountCents);

  static int year(Iterable<CashEntry> entries, int year) =>
      entries.where((e) => !e.deleted && e.date.year == year).fold<int>(0, (sum, e) => sum + e.amountCents);
}
