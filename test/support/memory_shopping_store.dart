import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/shopping_store.dart';

class MemoryShoppingStore implements ShoppingStore {
  final Map<String, ShoppingItem> items = <String, ShoppingItem>{};
  final Map<String, int> _published = <String, int>{};

  @override
  Future<ShoppingItem?> get(String id) async => items[id];

  @override
  Future<List<ShoppingItem>> all() async => items.values.toList();

  @override
  Future<({int active, int total})> counts() async =>
      (active: items.values.where((i) => !i.deleted).length, total: items.length);

  @override
  Future<void> put(ShoppingItem item, {int? publishedVersion}) async {
    items[item.id] = item;
    if (publishedVersion != null) {
      _published[item.id] = publishedVersion;
    } else {
      _published.putIfAbsent(item.id, () => 0);
    }
  }

  @override
  Future<List<ShoppingItem>> pendingPublish() async =>
      items.values.where((i) => i.version > (_published[i.id] ?? 0)).toList();

  @override
  Future<void> markPublished(String id, int version) async {
    if ((_published[id] ?? 0) < version) _published[id] = version;
  }

  @override
  Future<void> requeueLastEditedBy(String userId) async {
    for (final i in items.values) {
      if (i.by == userId && !i.deleted) _published[i.id] = 0;
    }
  }

  @override
  Future<void> pruneTombstones({required int keep}) async {
    final dead = items.values.where((i) => i.deleted).toList();
    final removable = dead.take((dead.length - keep).clamp(0, dead.length)).where((i) => (_published[i.id] ?? 0) >= i.version);
    for (final i in removable.toList()) {
      items.remove(i.id);
      _published.remove(i.id);
    }
  }

  @override
  Future<void> wipe() async {
    items.clear();
    _published.clear();
  }
}
