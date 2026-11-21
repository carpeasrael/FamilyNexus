import 'dart:convert';
import 'dart:typed_data';

import 'jpeg_header.dart';
import 'server.dart';

/// Technische Sperre für eigene Fotos als Avatar (#434, E-111). Solange der Wert `false` ist, senden und
/// verarbeiten Sync und Gateway keine Foto-Ereignisse, und die Oberfläche fehlt. Erst der letzte Teil-PR setzt ihn
/// auf `true`; Tests übergeben den Wert über den Konstruktor.
class AvatarPhotoFlags {
  const AvatarPhotoFlags._();
  static const bool enabled = false;
}

/// Grenzen des Foto-Formats (E-111).
class AvatarPhotoLimits {
  const AvatarPhotoLimits._();

  /// Kantenlänge des gesendeten Bildes und Obergrenze beim Empfang.
  static const int maxSide = 192;

  /// Größe des JPEG in Byte; Base64 daraus ergibt höchstens 21 848 Zeichen.
  static const int maxBytes = 16 * 1024;
  static const int maxBase64 = 22000;

  /// Ein Foto darf höchstens einen Tag in der Zukunft datiert sein (Uhr des Empfängers).
  static const Duration maxFuture = Duration(days: 1);

  static const String mime = 'image/jpeg';
}

final RegExp _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

bool isAvatarPhotoId(String s) => _uuid.hasMatch(s);

/// Ein Foto-Ereignis eines Mitglieds: ein JPEG oder eine Löschmarke ([cleared]) (E-111).
class AvatarPhoto {
  const AvatarPhoto({
    required this.owner,
    required this.id,
    required this.createdAt,
    required this.cleared,
    required this.width,
    required this.height,
    required this.bytes,
  });

  /// Löschmarke: neuestes Ereignis ohne Bild.
  factory AvatarPhoto.clearedMarker({required String owner, required String id, required int createdAt}) =>
      AvatarPhoto(owner: owner, id: id, createdAt: createdAt, cleared: true, width: 0, height: 0, bytes: Uint8List(0));

  final String owner;

  /// UUID dieses Fotos; bleibt bei Wiederholungen (Resync) gleich.
  final String id;

  /// Millisekunden seit Epoche (UTC); bleibt bei Wiederholungen gleich.
  final int createdAt;
  final bool cleared;
  final int width;
  final int height;
  final Uint8List bytes;

  /// `true`, wenn dieses Ereignis das [other] ablöst: größeres `createdAt`, bei Gleichstand die größere `id`.
  bool isNewerThan(AvatarPhoto other) =>
      createdAt != other.createdAt ? createdAt > other.createdAt : id.compareTo(other.id) > 0;

  /// Gründe, warum das Foto ungültig ist; leer, wenn es gültig ist.
  List<String> validate() {
    final p = <String>[];
    if (!MatrixIds.isUserId(owner)) p.add('owner');
    if (!isAvatarPhotoId(id)) p.add('id');
    if (createdAt <= 0) p.add('createdAt');
    if (cleared) {
      if (bytes.isNotEmpty || width != 0 || height != 0) p.add('cleared');
      return p;
    }
    if (bytes.isEmpty || bytes.length > AvatarPhotoLimits.maxBytes) p.add('bytes');
    final head = bytes.isEmpty ? null : JpegHeader.read(bytes, maxSide: AvatarPhotoLimits.maxSide);
    if (head == null) {
      p.add('jpeg');
    } else if (head.width != width || head.height != height) {
      p.add('size');
    }
    return p;
  }

  @override
  bool operator ==(Object other) =>
      other is AvatarPhoto &&
      other.owner == owner &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.cleared == cleared &&
      other.width == width &&
      other.height == height &&
      _same(other.bytes, bytes);

  @override
  int get hashCode => Object.hash(owner, id, createdAt, cleared, width, height, bytes.length);

  static bool _same(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Ein Zurücksetzen durch einen Moderator: das Foto [photoId] von [target] gilt nicht (E-111).
class AvatarReset {
  const AvatarReset({required this.target, required this.photoId, required this.photoCreatedAt});

  final String target;
  final String photoId;

  /// `createdAt` des zurückgesetzten Fotos; nur zum Aufräumen.
  final int photoCreatedAt;

  List<String> validate() => <String>[
    if (!MatrixIds.isUserId(target)) 'target',
    if (!isAvatarPhotoId(photoId)) 'photoId',
    if (photoCreatedAt <= 0) 'photoCreatedAt',
  ];

  @override
  bool operator ==(Object other) =>
      other is AvatarReset &&
      other.target == target &&
      other.photoId == photoId &&
      other.photoCreatedAt == photoCreatedAt;

  @override
  int get hashCode => Object.hash(target, photoId, photoCreatedAt);
}

/// Ereignisformat des Fotos: ein verschlüsseltes Raumereignis je Änderung im Familienraum (E-111).
///
/// Streng: Felder und Typen werden geprüft, `owner` muss der authentische Absender sein, das Bild wird
/// vor jeder Dekodierung gegen die Grenzen und den JPEG-Kopf geprüft, Base64 muss kanonisch sein.
class AvatarPhotoCodec {
  const AvatarPhotoCodec._();

  static const String type = 'de.inneso.familynexus.avatarphoto';
  static const int schema = 1;

  static Map<String, Object?> encode(AvatarPhoto p) {
    final problems = p.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiges Foto: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'owner': p.owner,
      'id': p.id,
      'created_at': p.createdAt,
      'cleared': p.cleared,
      'mime': AvatarPhotoLimits.mime,
      'w': p.width,
      'h': p.height,
      'data': p.cleared ? '' : base64.encode(p.bytes),
    };
  }

  /// `null` bei ungültigem Inhalt. `owner` muss mit [sender] übereinstimmen, `createdAt` darf höchstens
  /// [AvatarPhotoLimits.maxFuture] nach [now] liegen.
  static AvatarPhoto? decode(Map<String, Object?> c, {required String sender, required DateTime now}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final owner = c['owner'];
    final id = c['id'];
    final createdAt = c['created_at'];
    final cleared = c['cleared'];
    final mime = c['mime'];
    final w = c['w'];
    final h = c['h'];
    final data = c['data'];
    if (owner is! String || id is! String || createdAt is! int || cleared is! bool) return null;
    if (mime is! String || w is! int || h is! int || data is! String) return null;
    if (owner != sender || mime != AvatarPhotoLimits.mime) return null;
    if (createdAt > now.add(AvatarPhotoLimits.maxFuture).millisecondsSinceEpoch) return null;
    if (data.length > AvatarPhotoLimits.maxBase64) return null;
    final Uint8List bytes;
    try {
      bytes = Uint8List.fromList(base64.decode(data));
    } on FormatException {
      return null;
    }
    if (base64.encode(bytes) != data) return null; // nur kanonisches Base64 (mit Padding)
    final photo = AvatarPhoto(
      owner: owner,
      id: id,
      createdAt: createdAt,
      cleared: cleared,
      width: w,
      height: h,
      bytes: bytes,
    );
    return photo.validate().isEmpty ? photo : null;
  }
}

/// Ereignisformat des Zurücksetzens (E-111). Ob der Absender Moderator ist, prüft `AvatarPhotoService`.
class AvatarResetCodec {
  const AvatarResetCodec._();

  static const String type = 'de.inneso.familynexus.avatarreset';
  static const int schema = 1;

  static Map<String, Object?> encode(AvatarReset r) {
    final problems = r.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiges Zurücksetzen: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'target': r.target,
      'photo_id': r.photoId,
      'photo_created_at': r.photoCreatedAt,
    };
  }

  static AvatarReset? decode(Map<String, Object?> c, {required String sender}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final target = c['target'];
    final photoId = c['photo_id'];
    final at = c['photo_created_at'];
    if (target is! String || photoId is! String || at is! int) return null;
    final reset = AvatarReset(target: target, photoId: photoId, photoCreatedAt: at);
    return reset.validate().isEmpty ? reset : null;
  }
}
