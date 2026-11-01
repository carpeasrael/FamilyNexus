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

  /// `true` = gespeichert, `false` = im Dialog abgebrochen.
  Future<bool> saveFile({required String name, required Uint8List bytes, required String mimeType});

  /// Entfernt Klartext-Kopien, die die Systemdialoge im temporären Ordner hinterlassen (#141). Wirft nie.
  Future<void> clearTemporary();
}

class FileTooLargeException implements Exception {
  const FileTooLargeException();
}

class SystemFileAccess implements FileAccess {
  /// Laufende Dialogvorgänge. Statisch, weil Start und Löschen eigene Instanzen bauen. iOS leert mit `clear` den
  /// ganzen temporären Ordner und prüft dabei nicht auf offene Anfragen (`IOSFilePickerHandler.swift`): Solange ein
  /// Vorgang läuft, würde das seine Quelldatei löschen, etwa beim Doppeltipp auf „Als Datei speichern“.
  static int _active = 0;

  /// Führt einen Dialogvorgang aus; der letzte beendete Vorgang räumt auf, auch bei Abbruch und Fehlern.
  Future<T> _guarded<T>(Future<T> Function() op) async {
    _active++;
    try {
      return await op();
    } finally {
      _active--;
      await clearTemporary();
    }
  }

  @override
  Future<PickedFile?> pickFile() => _guarded(() async {
        final file = await FilePicker.pickFile();
        if (file == null) return null;
        // Browser: kein Dateipfad, `lengthSync` steht dort nicht zur Verfügung.
        final size = kIsWeb ? await file.length() : (file.lengthSync() ?? await file.length());
        if (size == null || size > AttachmentPolicy.maxBytes) throw const FileTooLargeException();
        return PickedFile(name: file.name, bytes: await file.readAsBytes());
      });

  @override
  Future<bool> saveFile({required String name, required Uint8List bytes, required String mimeType}) => _guarded(() async {
        final saved = await FilePicker.saveFile(fileName: name, bytes: bytes, mimeType: mimeType);
        // Browser: Der Download liefert immer `null`, ein Abbruch ist dort nicht erkennbar.
        return kIsWeb || saved != null;
      });

  @override
  Future<void> clearTemporary() async {
    if (_active > 0) return; // Der letzte Vorgang räumt auf.
    try {
      await FilePicker.clearTemporaryFiles();
    } catch (_) {
      // Aufräumen ist Bestpreis: Es ändert kein Ergebnis und hält weder Start noch Löschen auf.
    }
  }
}
