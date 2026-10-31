/// Regeln für Anhänge (E-19). Eingehende wie ausgehende Dateien gelten als
/// nicht vertrauenswürdig.
class AttachmentPolicy {
  const AttachmentPolicy._();

  static const int maxBytes = 25 * 1024 * 1024;

  /// Erlaubte MIME-Typen (Allowlist). Nichts davon wird automatisch ausgeführt.
  static const Set<String> allowedMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'application/pdf',
    'text/plain',
    'text/csv',
    'text/calendar',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  static const Map<String, String> _extToMime = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'ics': 'text/calendar',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Entfernt Pfadanteile, Steuer- und Sonderzeichen (dieselben unsichtbaren Zeichen wie
  /// `TextSanitizer`, E-28), begrenzt die Länge.
  static String sanitizeFileName(String raw) {
    var name = raw.split(RegExp(r'[\\/]')).last;
    name = name.replaceAll(RegExp('[\\x00-\\x1F\\x7F-\\x9F<>:"|?*\\u061C\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]'), '_').trim();
    name = name.replaceAll(RegExp(r'^\.+'), '');
    if (name.isEmpty) name = 'datei';
    if (name.length > 100) {
      final dot = name.lastIndexOf('.');
      final ext = (dot > 0 && name.length - dot <= 10) ? name.substring(dot) : '';
      name = name.substring(0, 100 - ext.length) + ext;
    }
    return name;
  }

  /// MIME-Typ aus der Dateiendung (nicht vom Absender behauptet), `null` = nicht erlaubt.
  static String? mimeForName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return null;
    return _extToMime[fileName.substring(dot + 1).toLowerCase()];
  }

  /// Magic-Byte-Prüfung für Bilder/PDF, damit Endung und Inhalt zusammenpassen.
  static bool contentMatches(String mime, List<int> bytes) {
    bool starts(List<int> sig) =>
        bytes.length >= sig.length && List<int>.generate(sig.length, (i) => bytes[i]).toString() == sig.toString();
    switch (mime) {
      case 'image/jpeg':
        return starts(<int>[0xFF, 0xD8, 0xFF]);
      case 'image/png':
        return starts(<int>[0x89, 0x50, 0x4E, 0x47]);
      case 'image/gif':
        return starts(<int>[0x47, 0x49, 0x46, 0x38]);
      case 'image/webp':
        return starts(<int>[0x52, 0x49, 0x46, 0x46]);
      case 'application/pdf':
        return starts(<int>[0x25, 0x50, 0x44, 0x46]);
      default:
        return true;
    }
  }

  /// Gesamtprüfung. Liefert `null` bei Erfolg, sonst einen Fehlercode.
  static AttachmentRejection? check({
    required String fileName,
    required List<int> bytes,
  }) {
    if (bytes.isEmpty) return AttachmentRejection.empty;
    if (bytes.length > maxBytes) return AttachmentRejection.tooLarge;
    final mime = mimeForName(fileName);
    if (mime == null || !allowedMimeTypes.contains(mime)) return AttachmentRejection.typeNotAllowed;
    if (!contentMatches(mime, bytes)) return AttachmentRejection.contentMismatch;
    return null;
  }

  /// Prüft Metadaten eingehender Anhänge (Inhalt noch nicht geladen).
  static bool incomingAllowed({required String mimeType, required int size}) =>
      size >= 0 && size <= maxBytes && allowedMimeTypes.contains(mimeType.toLowerCase());
}

enum AttachmentRejection { empty, tooLarge, typeNotAllowed, contentMismatch }
