import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'avatar_photo.dart';
import 'avatar_photo_store.dart';
import 'jpeg_header.dart';

enum AvatarPhotoError { invalid, notAllowed, clock }

class AvatarPhotoException implements Exception {
  const AvatarPhotoException(this.error);
  final AvatarPhotoError error;

  @override
  String toString() => 'AvatarPhotoException(${error.name})';
}

/// Fachlogik der Avatar-Fotos (#434, E-111); kennt nur den [AvatarPhotoStore]-Port.
///
/// Zustand: je Mitglied zählt das **neueste** Foto-Ereignis (größtes `createdAt`, dann größte `id`); es gibt keinen
/// Rückfall auf ältere Fotos. Zurücksetzen durch Moderatoren ist eine wachsende Menge von Foto-IDs; sichtbar ist das
/// neueste Ereignis nur, wenn es kein Löschmarker ist und seine `id` nicht zurückgesetzt wurde. Das Ergebnis hängt
/// nicht von der Reihenfolge des Eintreffens ab. Schwärzen ist nur Aufräumen und beeinflusst den Zustand nie.
class AvatarPhotoService {
  AvatarPhotoService({
    required this.store,
    required this.roomId,
    required this.myUserId,
    required this.isModerator,
    required this.isMember,
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? (() => const Uuid().v4());

  final AvatarPhotoStore store;
  final String roomId;
  final String myUserId;

  /// Ob eine Person (Matrix-ID) aktuell Moderator der Familie ist (zum Zeitpunkt der Verarbeitung).
  final bool Function(String userId) isModerator;

  /// Ob eine Person (Matrix-ID) aktuell beigetretenes Mitglied der Familie ist.
  final bool Function(String userId) isMember;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(_clock().toUtc().millisecondsSinceEpoch, isUtc: true);

  /// Das Foto von [owner] oder `null`: kein Ereignis, Löschmarker oder zurückgesetzt.
  Future<AvatarPhoto?> visible(String owner) async {
    final stored = await store.photo(roomId, owner);
    if (stored == null || stored.photo.cleared) return null;
    if (await _isReset(owner, stored.photo.id)) return null;
    return stored.photo;
  }

  /// Das neueste Foto von [owner] ist zurückgesetzt (für den Hinweis an den Eigentümer).
  Future<bool> isResetFor(String owner) async {
    final stored = await store.photo(roomId, owner);
    return stored != null && !stored.photo.cleared && await _isReset(owner, stored.photo.id);
  }

  Future<bool> _isReset(String owner, String photoId) async {
    for (final r in await store.resets(roomId)) {
      if (r.reset.target == owner && r.reset.photoId == photoId) return true;
    }
    return false;
  }

  /// Nimmt ein empfangenes Foto-Ereignis an. `true`, wenn es den Stand geändert hat. Fremde Ereignisse von
  /// Nicht-Mitgliedern werden verworfen; Ereignisse mit gleicher oder älterer Reihenfolge ändern nichts.
  Future<bool> acceptPhoto(AvatarPhoto photo, {required String eventId}) => _serial(() async {
    if (photo.validate().isNotEmpty || !isMember(photo.owner)) return false;
    final own = photo.owner == myUserId;
    final current = await store.photo(roomId, photo.owner);
    if (current != null) {
      // Dasselbe Foto (Echo, Wiederholung) oder ein älteres Ereignis ändert nichts. Die Ereignis-ID eines eigenen,
      // gerade gesendeten Fotos trägt der Sync über `markPublished` nach.
      if (!photo.isNewerThan(current.photo)) return false;
    }
    await store.putPhoto(
      roomId,
      StoredAvatarPhoto(photo: photo, eventId: own ? eventId : '', published: true),
      queueRedactOfPrevious: own,
    );
    await store.pruneResets(roomId);
    return true;
  });

  /// Nimmt ein empfangenes Zurücksetzen an: nur von einem Moderator, nur für ein beigetretenes Mitglied.
  Future<bool> acceptReset(AvatarReset reset, {required String sender}) => _serial(() async {
    if (reset.validate().isNotEmpty) return false;
    if (!isModerator(sender) || !isMember(reset.target)) return false;
    await store.addReset(roomId, reset);
    await store.pruneResets(roomId);
    return true;
  });

  /// Setzt das eigene Foto (bereits zugeschnittenes JPEG, siehe `AvatarPhotoProcessing`).
  Future<AvatarPhoto> setOwn(Uint8List jpeg) => _serial(() async {
    if (jpeg.isEmpty || jpeg.length > AvatarPhotoLimits.maxBytes) {
      throw const AvatarPhotoException(AvatarPhotoError.invalid);
    }
    final head = JpegHeader.read(jpeg, maxSide: AvatarPhotoLimits.maxSide);
    if (head == null) throw const AvatarPhotoException(AvatarPhotoError.invalid);
    final photo = AvatarPhoto(
      owner: myUserId,
      id: _newId(),
      createdAt: await _nextCreatedAt(),
      cleared: false,
      width: head.width,
      height: head.height,
      bytes: jpeg,
    );
    if (photo.validate().isNotEmpty) throw const AvatarPhotoException(AvatarPhotoError.invalid);
    await store.putPhoto(roomId, StoredAvatarPhoto(photo: photo), queueRedactOfPrevious: true);
    await store.pruneResets(roomId);
    return photo;
  });

  /// Entfernt das eigene Foto: ein neues Ereignis „gelöscht“ löst das bisherige ab.
  Future<AvatarPhoto> clearOwn() => _serial(() async {
    final photo = AvatarPhoto.clearedMarker(owner: myUserId, id: _newId(), createdAt: await _nextCreatedAt());
    await store.putPhoto(roomId, StoredAvatarPhoto(photo: photo), queueRedactOfPrevious: true);
    await store.pruneResets(roomId);
    return photo;
  });

  /// `max(jetzt, letztes eigenes createdAt + 1)`; liegt das über der Obergrenze, wird nicht gesendet (Uhr falsch).
  Future<int> _nextCreatedAt() async {
    final nowMs = now.millisecondsSinceEpoch;
    final last = (await store.photo(roomId, myUserId))?.photo.createdAt ?? 0;
    final next = last + 1 > nowMs ? last + 1 : nowMs;
    if (next > now.add(AvatarPhotoLimits.maxFuture).millisecondsSinceEpoch) {
      throw const AvatarPhotoException(AvatarPhotoError.clock);
    }
    return next;
  }

  /// Ein Moderator setzt das angezeigte Foto von [target] zurück.
  Future<AvatarReset> reset(String target) => _serial(() async {
    if (!isModerator(myUserId)) throw const AvatarPhotoException(AvatarPhotoError.notAllowed);
    if (!isMember(target) || target == myUserId) throw const AvatarPhotoException(AvatarPhotoError.invalid);
    final shown = await store.photo(roomId, target);
    if (shown == null || shown.photo.cleared) throw const AvatarPhotoException(AvatarPhotoError.invalid);
    final r = AvatarReset(target: target, photoId: shown.photo.id, photoCreatedAt: shown.photo.createdAt);
    await store.addReset(roomId, r, published: false);
    return r;
  });

  /// Entfernt die Foto-Zeile eines Mitglieds, das nicht mehr in der Familie ist (Zurücksetzen bleiben, siehe Store).
  Future<void> removeMember(String userId) => _serial(() => store.removeOwner(roomId, userId));
}
