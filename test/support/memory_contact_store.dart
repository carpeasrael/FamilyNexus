import 'package:family_nexus/domain/contact_store.dart';
import 'package:family_nexus/domain/contacts.dart';

/// Speicher im Arbeitsspeicher für Tests (#119).
class MemoryContactStore implements ContactStore {
  final Map<(ContactKind, String), ContactRecord> _rows = <(ContactKind, String), ContactRecord>{};
  final Map<(ContactKind, String), int> _published = <(ContactKind, String), int>{};

  @override
  Future<ContactRecord?> get(ContactKind kind, String id) async => _rows[(kind, id)];

  @override
  Future<List<ContactRecord>> all([ContactKind? kind]) async => <ContactRecord>[
        for (final e in _rows.entries)
          if (kind == null || e.key.$1 == kind) e.value,
      ]..sort((a, b) {
          final k = a.kind.index.compareTo(b.kind.index);
          return k != 0 ? k : a.id.compareTo(b.id);
        });

  @override
  Future<void> put(ContactRecord record, {int? publishedVersion}) async {
    final key = (record.kind, record.id);
    _rows[key] = record;
    _published[key] = publishedVersion ?? _published[key] ?? 0;
  }

  @override
  Future<List<ContactRecord>> pending() async => <ContactRecord>[
        for (final e in _rows.entries)
          if (e.value.version > (_published[e.key] ?? 0)) e.value,
      ];

  @override
  Future<void> markPublished(ContactKind kind, String id, int version) async {
    final key = (kind, id);
    if (_rows.containsKey(key) && (_published[key] ?? 0) < version) _published[key] = version;
  }

  @override
  Future<int> pruneTombstones({required int keep}) async {
    final dead = <MapEntry<(ContactKind, String), ContactRecord>>[
      for (final e in _rows.entries)
        if (e.value.deleted && e.value.version <= (_published[e.key] ?? 0)) e,
    ]..sort((a, b) => b.value.updatedAt.compareTo(a.value.updatedAt));
    if (dead.length <= keep) return 0;
    final drop = dead.skip(keep).toList();
    for (final e in drop) {
      _rows.remove(e.key);
      _published.remove(e.key);
    }
    return drop.length;
  }

  @override
  Future<void> requeueAll() async {
    for (final e in _rows.entries) {
      if (!e.value.deleted) _published[e.key] = 0;
    }
  }

  @override
  Future<void> wipe() async {
    _rows.clear();
    _published.clear();
  }
}
