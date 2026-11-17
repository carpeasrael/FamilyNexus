import 'package:family_nexus/domain/anniversaries.dart';
import 'package:family_nexus/domain/anniversary_store.dart';

/// [AnniversaryStore] im Speicher für Tests ohne SQL (E-104).
class MemoryAnniversaryStore implements AnniversaryStore {
  final Map<String, AnniversaryPerson> peopleById = <String, AnniversaryPerson>{};
  final Map<String, int> _published = <String, int>{};

  @override
  Future<AnniversaryPerson?> get(String id) async => peopleById[id];

  @override
  Future<List<AnniversaryPerson>> all() async => peopleById.values.toList();

  @override
  Future<({int active, int total})> counts() async =>
      (active: peopleById.values.where((t) => !t.deleted).length, total: peopleById.length);

  @override
  Future<void> put(AnniversaryPerson person, {int? publishedVersion}) async {
    peopleById[person.id] = person;
    if (publishedVersion != null) {
      _published[person.id] = publishedVersion;
    } else {
      _published.putIfAbsent(person.id, () => 0);
    }
  }

  @override
  Future<List<AnniversaryPerson>> pending() async =>
      peopleById.values.where((t) => t.version > (_published[t.id] ?? 0)).toList();

  @override
  Future<void> markPublished(String id, int version) async {
    if ((_published[id] ?? 0) < version) _published[id] = version;
  }

  @override
  Future<void> pruneTombstones({required int keep}) async {
    final dead = peopleById.values.where((t) => t.deleted).toList();
    final removable = dead.take((dead.length - keep).clamp(0, dead.length)).where((t) => (_published[t.id] ?? 0) >= t.version);
    for (final t in removable.toList()) {
      peopleById.remove(t.id);
      _published.remove(t.id);
    }
  }

  @override
  Future<void> requeueLastEditedBy(String userId) async {
    for (final t in peopleById.values) {
      if (t.by == userId && !t.deleted) _published[t.id] = 0;
    }
  }

  @override
  Future<void> wipe() async {
    peopleById.clear();
    _published.clear();
  }
}
