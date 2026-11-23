import 'package:uuid/uuid.dart';

import 'cash_book.dart';
import 'cash_book_store.dart';

enum CashBookError { invalid, notAllowed, notFound, limit }

class CashBookException implements Exception {
  const CashBookException(this.error);
  final CashBookError error;

  @override
  String toString() => 'CashBookException(${error.name})';
}

/// Fachlogik des Kassenbuchs (E-113). Kennt nur den [CashBookStore]-Port, weder Matrix noch Oberfläche. Ob ein
/// Absender je Mitglied des Buch-Raums war, entscheidet der Sync vor dem Aufruf von [applyEntry].
class CashBookService {
  CashBookService({
    required this.store,
    required this.myUserId,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final CashBookStore store;
  final String myUserId;
  final DateTime Function() _clock;
  final String Function() _newId;

  DateTime get _now => _clock().toUtc();

  // Alle schreibenden Abläufe laufen nacheinander (Eingänge, lokale Änderungen).
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  // ------------------------------------------------------------------ Bücher

  /// Nimmt Titel und Währung eines Buchs an (lokal angelegt oder empfangen). Höchstens
  /// [CashBookLimits.maxBooksPerFamily] Bücher; bei gleicher Version entscheidet der Vergleich der Felder
  /// deterministisch (größerer Titel, dann größere Währung), damit alle Geräte konvergieren. `true`, wenn gespeichert.
  Future<bool> applyBook(CashBookMeta incoming, {bool published = true}) => _serial(() async {
        if (incoming.validate().isNotEmpty) return false;
        final current = await store.getBook(incoming.roomId);
        if (current == null) {
          if ((await store.books()).length >= CashBookLimits.maxBooksPerFamily) return false;
        } else {
          if (current.owner != incoming.owner) return false;
          if (incoming == current) return false;
          final newer = incoming.version != current.version
              ? incoming.version > current.version
              : '${incoming.title}\u0000${incoming.currency}'.compareTo('${current.title}\u0000${current.currency}') > 0;
          if (!newer) return false;
        }
        await store.putBook(incoming, published: published);
        return true;
      });

  /// Legt das **Platzhalter-Buch** an (Version 0, nie gesendet), wenn der Verlauf keine Metadaten liefert (Ersteller
  /// gelöscht, Schlüssel fehlen). Nur wenn noch kein Buch existiert; jedes echte `bookmeta` (Version ≥ 1) ersetzt es über
  /// [applyBook], unabhängig von der Feldordnung.
  Future<bool> applyFallback(String roomId, {required String owner, required String currency}) => _serial(() async {
        if (await store.getBook(roomId) != null) return false;
        if ((await store.books()).length >= CashBookLimits.maxBooksPerFamily) return false;
        final m = CashBookMeta(roomId: roomId, title: CashBookMeta.fallbackTitle, currency: currency, owner: owner, version: 0);
        if (m.validate().any((p) => p != 'version')) return false;
        await store.putBook(m, published: true);
        return true;
      });

  // ---------------------------------------------------------------- Einträge

  /// Legt einen eigenen Eintrag an; er wartet auf das Senden.
  Future<CashEntry> create(
    String roomId, {
    required DateTime date,
    required String store,
    required int amountCents,
    String note = '',
    CashReceipt? receipt,
  }) =>
      _serial(() async {
        if (await this.store.getBook(roomId) == null) throw const CashBookException(CashBookError.notFound);
        if (await this.store.countByAuthor(roomId, myUserId) >= CashBookLimits.maxEntriesPerAuthor) {
          throw const CashBookException(CashBookError.limit);
        }
        final e = CashEntry(
          id: _newId(),
          author: myUserId,
          date: DateTime.utc(date.year, date.month, date.day),
          store: store.trim(),
          amountCents: amountCents,
          note: note.trim(),
          receipt: receipt,
          updatedAt: _now,
        );
        _check(e);
        await this.store.putEntry(roomId, e, publishedVersion: 0);
        return e;
      });

  /// Ändert einen eigenen Eintrag: Version +1, `updated_at` neu. Nur der Autor.
  Future<CashEntry> update(String roomId, CashEntry edited) => _serial(() async {
        final current = await store.getEntry(roomId, edited.author, edited.id);
        if (current == null) throw const CashBookException(CashBookError.notFound);
        if (current.author != myUserId || current.deleted) throw const CashBookException(CashBookError.notAllowed);
        final next = current.copyWith(
          version: current.version + 1,
          date: DateTime.utc(edited.date.year, edited.date.month, edited.date.day),
          store: edited.store.trim(),
          amountCents: edited.amountCents,
          note: edited.note.trim(),
          receipt: edited.receipt,
          clearReceipt: edited.receipt == null,
          updatedAt: _now,
        );
        _check(next);
        await store.putEntry(roomId, next);
        return next;
      });

  /// Löscht einen eigenen Eintrag (Löschmarke). Nur der Autor.
  Future<void> delete(String roomId, String id) => _serial(() async {
        final current = await store.getEntry(roomId, myUserId, id);
        if (current == null) throw const CashBookException(CashBookError.notFound);
        if (current.deleted) return;
        await store.putEntry(roomId, current.tombstone(_now));
      });

  /// Stempelt einen **eigenen** Eintrag (Version unverändert) neu, wenn sein `updated_at` mehr als einen Tag von jetzt
  /// abweicht: Der Empfänger verwirft Abweichungen über [CashBookLimits.maxSkew], und ein erneut gesendeter oder lange
  /// wartender Eintrag trüge sonst einen alten Zeitstempel. Liest den Eintrag **neu** (innerhalb der Serialisierung) und
  /// stempelt nur, wenn Version und Löschmarke noch dem erwarteten Stand entsprechen; sonst `null` (zwischenzeitlich
  /// geändert, der Aufrufer liest neu). Der Eintrag bleibt in der Warteschlange. Gibt die gespeicherte Fassung zurück.
  Future<CashEntry?> restamp(String roomId, String id, {required int expectedVersion, required bool expectedDeleted}) =>
      _serial(() async {
        final current = await store.getEntry(roomId, myUserId, id);
        if (current == null || current.author != myUserId) return null;
        if (current.version != expectedVersion || current.deleted != expectedDeleted) return null;
        final now = _now;
        if (current.updatedAt.difference(now).abs() <= const Duration(days: 1)) return current;
        final next = current.copyWith(updatedAt: now);
        await store.putEntry(roomId, next);
        return next;
      });

  /// Nimmt einen empfangenen Eintrag an (bereits dekodiert, Autor == Absender, Absender war Mitglied). Schlüssel
  /// `(Raum, Autor, ID)`: Ein Eintrag mit fremder `id` verdrängt nie den eines anderen Autors. Verworfen wird, wenn das
  /// Buch unbekannt ist, der Versionssprung über [CashBookLimits.maxVersionStep] liegt oder der Autor am Limit ist.
  Future<CashResolution?> applyEntry(String roomId, CashEntry incoming) => _serial(() async {
        if (incoming.validate().isNotEmpty) return null;
        if (await store.getBook(roomId) == null) return null;
        final current = await store.getEntry(roomId, incoming.author, incoming.id);
        if (current == null) {
          if (await store.countByAuthor(roomId, incoming.author) >= CashBookLimits.maxEntriesPerAuthor) return null;
        } else if (incoming.version > current.version + CashBookLimits.maxVersionStep) {
          return null;
        }
        final r = CashEntryResolver.resolve(current, incoming);
        if (r == CashResolution.insert || r == CashResolution.replace) {
          await store.putEntry(roomId, incoming, publishedVersion: incoming.version);
        }
        return r;
      });

  // ----------------------------------------------------------------- Summen

  Future<int> monthTotal(String roomId, int year, int month) async => CashTotals.month(await store.entries(roomId), year, month);

  Future<int> yearTotal(String roomId, int year) async => CashTotals.year(await store.entries(roomId), year);

  void _check(CashEntry e) {
    if (e.validate().isNotEmpty) throw const CashBookException(CashBookError.invalid);
  }
}
