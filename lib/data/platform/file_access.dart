import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../domain/attachment_policy.dart';

class PickedFile {
  const PickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Dateiauswahl und -speicherung über die Systemdialoge (Storage Access
/// Framework; keine Speicherberechtigung nötig). Plattform-Plugin nur hier.
abstract class FileAccess {
  /// `null` = abgebrochen. Wirft [FileTooLargeException] vor dem Einlesen, wenn
  /// die Datei das Limit überschreitet.
  Future<PickedFile?> pickFile();

  Future<void> saveFile({required String name, required Uint8List bytes, required String mimeType});
}

class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

class SystemFileAccess implements FileAccess {
  @override
  Future<PickedFile?> pickFile() async {
    final file = await FilePicker.pickFile();
    if (file == null) return null;
    // Browser: kein Dateipfad, `lengthSync` steht dort nicht zur Verfügung.
    final size = kIsWeb ? await file.length() : (file.lengthSync() ?? await file.length());
    if (size == null || size > AttachmentPolicy.maxBytes) throw const FileTooLargeException();
    final bytes = await file.readAsBytes();
    // Der Auswahldialog kopiert die Datei in den App-Cache: Kopie sofort entfernen.
    await FilePicker.clearTemporaryFiles().catchError((Object _) {});
    return PickedFile(name: file.name, bytes: bytes);
  }

  @override
  Future<void> saveFile({required String name, required Uint8List bytes, required String mimeType}) async {
    await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mimeType);
  }
}
