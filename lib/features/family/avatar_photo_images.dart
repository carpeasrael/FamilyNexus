import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../core/app_log.dart';
import '../../domain/avatar_photo_decode.dart';
import '../../domain/avatar_photo_service.dart';

/// Zwischenspeicher der Avatar-Fotos als Bilder (#434, E-111). Hält je Mitglied das sichtbare Foto als [ui.Image]
/// aus Rohpixeln; die geprüften JPEG-Bytes werden im speichersicheren Dart-Paket dekodiert und erreichen nie einen
/// nativen Decoder. Der Zwischenspeicher meldet jede Änderung, damit die Anzeige neu aufbaut.
///
/// [imageOf] liefert synchron das zwischengespeicherte Bild (oder `null`) und stößt bei Bedarf das Nachladen an. Nach
/// [invalidate] gilt jeder Eintrag als veraltet und wird beim nächsten Zugriff mit dem Dienst abgeglichen; dasselbe
/// Foto (gleiche `id`) wird dabei nicht erneut dekodiert.
class AvatarPhotoImages extends ChangeNotifier {
  AvatarPhotoImages(this.service);

  final AvatarPhotoService service;

  final Map<String, _Entry> _entries = <String, _Entry>{};
  final Set<String> _loading = <String>{};
  int _epoch = 0;
  bool _disposed = false;

  /// Das Bild von [userId], wenn es schon geladen ist; sonst `null` (kein Foto oder noch nicht geladen).
  ui.Image? imageOf(String userId) {
    final e = _entries[userId];
    if (e == null || e.epoch != _epoch) _load(userId);
    return e?.image;
  }

  /// Der Bestand (Foto, Zurücksetzen, Mitglieder) hat sich geändert: Einträge neu abgleichen.
  void invalidate() {
    if (_disposed) return;
    _epoch++;
    notifyListeners();
  }

  void _load(String userId) {
    if (_disposed || !_loading.add(userId)) return;
    final epoch = _epoch;
    unawaited(() async {
      try {
        final photo = await service.visible(userId);
        final old = _entries[userId];
        ui.Image? image;
        if (photo != null) {
          if (old != null && old.photoId == photo.id && old.image != null) {
            image = old.image; // dasselbe Foto: nicht erneut dekodieren
          } else {
            final px = AvatarPhotoDecoder.decode(photo.bytes);
            if (px != null) image = await _toImage(px);
          }
        }
        if (_disposed) {
          if (image != null && image != old?.image) image.dispose();
          return;
        }
        final changed = old?.image != image || old?.photoId != photo?.id;
        // Das vorige Bild wird nicht sofort freigegeben: Es kann noch in einem laufenden Bild der Oberfläche stehen.
        _entries[userId] = _Entry(photo?.id, image, epoch);
        if (changed) notifyListeners();
      } catch (e) {
        AppLog.w('avatarphoto', 'Avatar-Foto konnte nicht angezeigt werden (${e.runtimeType})');
        _entries[userId] = _Entry(null, null, epoch);
      } finally {
        _loading.remove(userId);
        // Ein Abgleich lief schon mit einem neueren Stand: noch einmal laden.
        if (!_disposed && _entries[userId]?.epoch != _epoch) _load(userId);
      }
    }());
  }

  static Future<ui.Image> _toImage(AvatarPixels px) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromPixels(px.rgba, px.width, px.height, ui.PixelFormat.rgba8888, c.complete);
    return c.future;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _entries.values) {
      e.image?.dispose();
    }
    _entries.clear();
    super.dispose();
  }
}

class _Entry {
  const _Entry(this.photoId, this.image, this.epoch);
  final String? photoId;
  final ui.Image? image;
  final int epoch;
}
