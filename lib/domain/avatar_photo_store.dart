import 'avatar_photo.dart';

/// Ein gespeichertes Foto-Ereignis samt lokalem Sendestand (nicht Teil des Ereignisformats).
class StoredAvatarPhoto {
  const StoredAvatarPhoto({
    required this.photo,
    this.eventId = '',
    this.published = false,
    this.redactIds = const <String>[],
  });

  final AvatarPhoto photo;

  /// Matrix-ID des Ereignisses: bei eigenen nach erfolgreichem Senden, sonst leer.
  final String eventId;

  /// `true`, wenn das Ereignis dem Server bekannt ist (eingehend immer, eigene nach dem Senden).
  final bool published;

  /// Noch zu schwärzende **eigene** Ereignisse (Aufräumen nach bestem Bemühen, E-111).
  final List<String> redactIds;

  StoredAvatarPhoto copyWith({String? eventId, bool? published, List<String>? redactIds}) => StoredAvatarPhoto(
    photo: photo,
    eventId: eventId ?? this.eventId,
    published: published ?? this.published,
    redactIds: redactIds ?? this.redactIds,
  );
}

/// Ein gespeichertes Zurücksetzen samt Sendestand.
class StoredAvatarReset {
  const StoredAvatarReset({required this.reset, this.published = true});
  final AvatarReset reset;

  /// `false` für eigene, noch nicht gesendete Zurücksetzen.
  final bool published;
}

/// Port: lokale, verschlüsselte Ablage der Avatar-Fotos (#434, E-111). Alles ist je Familienraum getrennt.
abstract class AvatarPhotoStore {
  /// Das neueste bekannte Ereignis des Eigentümers (eine Zeile je Eigentümer).
  Future<StoredAvatarPhoto?> photo(String roomId, String owner);

  Future<List<StoredAvatarPhoto>> photos(String roomId);

  /// Ersetzt die Zeile des Eigentümers. Mit [queueRedactOfPrevious] wandert die `eventId` der bisherigen **eigenen**
  /// Zeile in `redactIds` der neuen (Aufräumen).
  Future<void> putPhoto(String roomId, StoredAvatarPhoto stored, {bool queueRedactOfPrevious = false});

  /// Eigene Ereignisse, die noch nicht gesendet sind.
  Future<List<StoredAvatarPhoto>> pendingPhotos(String roomId);

  /// Merkt das Senden: nur wenn die Zeile des Eigentümers noch dieses Foto ([photoId]) hält.
  Future<void> markPublished(String roomId, String owner, String photoId, String eventId);

  /// Eigene Zeilen mit offenen Schwärz-Aufträgen.
  Future<List<StoredAvatarPhoto>> redactQueue(String roomId);

  /// Entfernt einen erledigten Schwärz-Auftrag.
  Future<void> clearRedacted(String roomId, String owner, String eventId);

  Future<List<StoredAvatarReset>> resets(String roomId);

  Future<void> addReset(String roomId, AvatarReset reset, {bool published = true});

  Future<List<StoredAvatarReset>> pendingResets(String roomId);

  Future<void> markResetPublished(String roomId, String target, String photoId);

  /// Entfernt Zurücksetzen, deren Ziel schon ein **neueres** Foto hat (die Zeile des Ziels muss existieren).
  Future<void> pruneResets(String roomId);

  /// Entfernt die Foto-Zeile eines Mitglieds (Austritt, Entfernen). Zurücksetzen bleiben erhalten, damit ein altes,
  /// zurückgesetztes Foto nach einem Wiedereintritt nicht wieder auftaucht; sie fallen mit einem neueren Foto weg.
  Future<void> removeOwner(String roomId, String owner);

  /// Entfernt endgültig alle Daten.
  Future<void> wipe();
}
