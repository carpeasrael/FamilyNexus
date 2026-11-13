import 'package:family_nexus/domain/event_theme_store.dart';
import 'package:family_nexus/domain/event_themes.dart';

/// [EventThemeStore] im Speicher für Tests ohne SQL (E-99).
class MemoryEventThemeStore implements EventThemeStore {
  final Map<String, EventTheme> themesById = <String, EventTheme>{};
  final Map<String, int> _published = <String, int>{};

  @override
  Future<EventTheme?> get(String id) async => themesById[id];

  @override
  Future<List<EventTheme>> all() async => themesById.values.toList();

  @override
  Future<({int active, int total})> counts() async =>
      (active: themesById.values.where((t) => !t.deleted).length, total: themesById.length);

  @override
  Future<void> put(EventTheme theme, {int? publishedVersion}) async {
    themesById[theme.id] = theme;
    if (publishedVersion != null) {
      _published[theme.id] = publishedVersion;
    } else {
      _published.putIfAbsent(theme.id, () => 0);
    }
  }

  @override
  Future<List<EventTheme>> pending() async =>
      themesById.values.where((t) => t.version > (_published[t.id] ?? 0)).toList();

  @override
  Future<void> markPublished(String id, int version) async {
    if ((_published[id] ?? 0) < version) _published[id] = version;
  }

  @override
  Future<void> pruneTombstones({required int keep}) async {
    final dead = themesById.values.where((t) => t.deleted).toList();
    final removable = dead.take((dead.length - keep).clamp(0, dead.length)).where((t) => (_published[t.id] ?? 0) >= t.version);
    for (final t in removable.toList()) {
      themesById.remove(t.id);
      _published.remove(t.id);
    }
  }

  @override
  Future<void> requeueLastEditedBy(String userId) async {
    for (final t in themesById.values) {
      if (t.by == userId && !t.deleted) _published[t.id] = 0;
    }
  }

  @override
  Future<void> wipe() async {
    themesById.clear();
    _published.clear();
  }
}
