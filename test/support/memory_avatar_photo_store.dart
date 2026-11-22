import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_store.dart';

/// [AvatarPhotoStore] im Speicher für Oberflächentests ohne SQL (#434). Gleiche Regeln wie `SqlAvatarPhotoStore`
/// (eine Zeile je Eigentümer, Zurücksetzen als Menge, Aufräumen nur mit existierender, neuerer Zeile).
class MemoryAvatarPhotoStore implements AvatarPhotoStore {
  final Map<String, StoredAvatarPhoto> _photos = <String, StoredAvatarPhoto>{};
  final Map<String, StoredAvatarReset> _resets = <String, StoredAvatarReset>{};

  String _pk(String room, String owner) => '$room|$owner';
  String _rk(String room, String target, String id) => '$room|$target|$id';

  @override
  Future<StoredAvatarPhoto?> photo(String roomId, String owner) async => _photos[_pk(roomId, owner)];

  @override
  Future<List<StoredAvatarPhoto>> photos(String roomId) async =>
      <StoredAvatarPhoto>[for (final e in _photos.entries) if (e.key.startsWith('$roomId|')) e.value];

  @override
  Future<void> putPhoto(String roomId, StoredAvatarPhoto stored, {bool queueRedactOfPrevious = false}) async {
    var redact = stored.redactIds;
    final prev = _photos[_pk(roomId, stored.photo.owner)];
    if (queueRedactOfPrevious && prev != null) {
      redact = <String>{...prev.redactIds, if (prev.eventId.isNotEmpty) prev.eventId, ...redact}.toList();
    }
    _photos[_pk(roomId, stored.photo.owner)] = stored.copyWith(redactIds: redact);
  }

  @override
  Future<List<StoredAvatarPhoto>> pendingPhotos(String roomId) async =>
      <StoredAvatarPhoto>[for (final p in await photos(roomId)) if (!p.published) p];

  @override
  Future<void> markPublished(String roomId, String owner, String photoId, String eventId) async {
    final cur = _photos[_pk(roomId, owner)];
    if (cur == null || cur.photo.id != photoId) return;
    final redact = <String>{...cur.redactIds, if (cur.eventId.isNotEmpty && cur.eventId != eventId) cur.eventId}.toList();
    _photos[_pk(roomId, owner)] = cur.copyWith(published: true, eventId: eventId, redactIds: redact);
  }

  @override
  Future<void> requeueOwnPhoto(String roomId, String owner) async {
    final cur = _photos[_pk(roomId, owner)];
    if (cur != null) _photos[_pk(roomId, owner)] = cur.copyWith(published: false);
  }

  @override
  Future<void> requeueResets(String roomId) async {
    for (final k in _resets.keys.where((k) => k.startsWith('$roomId|')).toList()) {
      _resets[k] = StoredAvatarReset(reset: _resets[k]!.reset, published: false);
    }
  }

  @override
  Future<List<StoredAvatarPhoto>> redactQueue(String roomId) async =>
      <StoredAvatarPhoto>[for (final p in await photos(roomId)) if (p.redactIds.isNotEmpty) p];

  @override
  Future<void> clearRedacted(String roomId, String owner, String eventId) async {
    final cur = _photos[_pk(roomId, owner)];
    if (cur == null) return;
    _photos[_pk(roomId, owner)] = cur.copyWith(redactIds: <String>[for (final id in cur.redactIds) if (id != eventId) id]);
  }

  @override
  Future<List<StoredAvatarReset>> resets(String roomId) async =>
      <StoredAvatarReset>[for (final e in _resets.entries) if (e.key.startsWith('$roomId|')) e.value];

  @override
  Future<void> addReset(String roomId, AvatarReset reset, {bool published = true}) async {
    _resets.putIfAbsent(_rk(roomId, reset.target, reset.photoId), () => StoredAvatarReset(reset: reset, published: published));
  }

  @override
  Future<List<StoredAvatarReset>> pendingResets(String roomId) async =>
      <StoredAvatarReset>[for (final r in await resets(roomId)) if (!r.published) r];

  @override
  Future<void> markResetPublished(String roomId, String target, String photoId) async {
    final k = _rk(roomId, target, photoId);
    final cur = _resets[k];
    if (cur != null) _resets[k] = StoredAvatarReset(reset: cur.reset, published: true);
  }

  @override
  Future<void> pruneResets(String roomId) async {
    for (final e in _resets.entries.toList()) {
      if (!e.key.startsWith('$roomId|') || !e.value.published) continue;
      final row = _photos[_pk(roomId, e.value.reset.target)];
      if (row != null && row.photo.createdAt > e.value.reset.photoCreatedAt) _resets.remove(e.key);
    }
  }

  @override
  Future<void> removeOwner(String roomId, String owner) async => _photos.remove(_pk(roomId, owner));

  @override
  Future<void> wipe() async {
    _photos.clear();
    _resets.clear();
  }
}
