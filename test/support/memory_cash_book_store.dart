import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_store.dart';

/// Speicher im Arbeitsspeicher für Tests (#311).
class MemoryCashBookStore implements CashBookStore {
  final Map<String, CashBookMeta> _books = <String, CashBookMeta>{};
  final Set<String> _complete = <String>{};
  final Map<(String, String, String), CashEntry> _entries = <(String, String, String), CashEntry>{};
  final Map<(String, String, String), int> _published = <(String, String, String), int>{};

  @override
  Future<CashBookMeta?> getBook(String roomId) async => _books[roomId];

  @override
  Future<List<CashBookMeta>> books() async => _books.values.toList();

  @override
  Future<void> putBook(CashBookMeta meta, {bool published = true}) async => _books[meta.roomId] = meta;

  @override
  Future<void> deleteBook(String roomId) async {
    _books.remove(roomId);
    _complete.remove(roomId);
    _entries.removeWhere((k, _) => k.$1 == roomId);
    _published.removeWhere((k, _) => k.$1 == roomId);
  }

  @override
  Future<bool> isComplete(String roomId) async => _complete.contains(roomId);

  @override
  Future<void> setComplete(String roomId, bool complete) async => complete ? _complete.add(roomId) : _complete.remove(roomId);

  @override
  Future<CashEntry?> getEntry(String roomId, String author, String id) async => _entries[(roomId, author, id)];

  @override
  Future<List<CashEntry>> entries(String roomId) async => <CashEntry>[
        for (final en in _entries.entries)
          if (en.key.$1 == roomId) en.value,
      ];

  @override
  Future<int> countByAuthor(String roomId, String author) async =>
      _entries.keys.where((k) => k.$1 == roomId && k.$2 == author).length;

  @override
  Future<void> putEntry(String roomId, CashEntry entry, {int? publishedVersion}) async {
    final k = (roomId, entry.author, entry.id);
    _entries[k] = entry;
    if (publishedVersion != null || !_published.containsKey(k)) _published[k] = publishedVersion ?? 0;
  }

  @override
  Future<List<({String roomId, CashEntry entry})>> pending(String author) async => <({String roomId, CashEntry entry})>[
        for (final en in _entries.entries)
          if (en.key.$2 == author && en.value.version > (_published[en.key] ?? 0)) (roomId: en.key.$1, entry: en.value),
      ];

  @override
  Future<void> markPublished(String roomId, String author, String id, int version) async {
    final k = (roomId, author, id);
    if (version > (_published[k] ?? 0)) _published[k] = version;
  }

  @override
  Future<void> requeueOwn(String roomId, String author) async {
    for (final en in _entries.entries) {
      if (en.key.$1 == roomId && en.key.$2 == author && !en.value.deleted) _published[en.key] = 0;
    }
  }

  @override
  Future<void> wipe() async {
    _books.clear();
    _complete.clear();
    _entries.clear();
    _published.clear();
  }
}
