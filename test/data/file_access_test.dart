import 'dart:async';
import 'dart:typed_data';

import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/domain/attachment_policy.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Attrappe einer ausgewählten Datei.
final class _File extends PlatformFile {
  _File({required this.size, this.readError, this.onRead});
  final int size;
  final Object? readError;

  /// Läuft beim Einlesen, vor dem Ergebnis.
  final void Function()? onRead;

  @override
  String get name => 'a.txt';
  @override
  Uri get uri => Uri.parse('file:///tmp/a.txt');
  @override
  int? lengthSync() => size;
  @override
  Future<int> length() async => size;
  @override
  Future<Uint8List> readAsBytes() async {
    onRead?.call();
    if (readError != null) throw readError!;
    return Uint8List(size);
  }

  @override
  Stream<Uint8List> readAsByteStream() => Stream<Uint8List>.value(Uint8List(size));
  @override
  Never get xFile => throw UnimplementedError();
}

class _Picker extends FilePickerPlatform {
  _Picker({this.result, this.saveError, this.pickResult, this.pickError, this.clearError, this.clearThrowsSync = false});
  final Uri? result;
  final Object? saveError;
  final PlatformFile? pickResult;
  final Object? pickError;
  final Object? clearError;
  final bool clearThrowsSync;

  /// Wartet ein Speichervorgang hierauf, bleibt er offen.
  Completer<void>? hold;
  int clears = 0;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    dynamic Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    final h = hold;
    hold = null; // Nur der erste Aufruf bleibt offen, der zweite scheitert wie `multiple_request`.
    if (h != null) {
      await h.future;
      return result;
    }
    if (saveError != null) throw saveError!;
    return result;
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (pickError != null) throw pickError!;
    return pickResult;
  }

  @override
  Future<void> clearTemporaryFiles() {
    clears++;
    if (clearThrowsSync) throw StateError('clear');
    if (clearError != null) return Future<void>.error(clearError!);
    return Future<void>.value();
  }
}

void main() {
  late FilePickerPlatform original;

  setUp(() => original = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = original);

  Future<bool> save() => SystemFileAccess().saveFile(name: 'a.txt', bytes: Uint8List(1), mimeType: 'text/plain');

  group('Speichern', () {
    test('#136: ein abgebrochener Dialog gilt nicht als gespeichert', () async {
      FilePickerPlatform.instance = _Picker();
      expect(await save(), isFalse);
    });

    test('ein gewählter Speicherort gilt als gespeichert', () async {
      FilePickerPlatform.instance = _Picker(result: Uri.file('/tmp/a.txt'));
      expect(await save(), isTrue);
    });

    test('#141: räumt nach Erfolg auf', () async {
      final p = _Picker(result: Uri.file('/tmp/a.txt'));
      FilePickerPlatform.instance = p;
      await save();
      expect(p.clears, 1);
    });

    test('#141: räumt nach Abbruch auf', () async {
      final p = _Picker();
      FilePickerPlatform.instance = p;
      await save();
      expect(p.clears, 1);
    });

    test('#141: räumt nach einem Fehler auf und reicht ihn weiter', () async {
      final p = _Picker(saveError: StateError('kaputt'));
      FilePickerPlatform.instance = p;
      await expectLater(save(), throwsStateError);
      expect(p.clears, 1);
    });

    for (final sync in <bool>[true, false]) {
      test('#141: ein Fehler beim Aufräumen ändert das Ergebnis nicht (synchron: $sync)', () async {
        final p = _Picker(result: Uri.file('/tmp/a.txt'), clearThrowsSync: sync, clearError: sync ? null : StateError('clear'));
        FilePickerPlatform.instance = p;
        expect(await save(), isTrue);
        expect(p.clears, 1);
      });
    }
  });

  group('Auswählen', () {
    Future<PickedFile?> pick() => SystemFileAccess().pickFile();

    test('liefert die Datei und räumt auf', () async {
      final p = _Picker(pickResult: _File(size: 3));
      FilePickerPlatform.instance = p;
      final f = await pick();
      expect(f!.bytes.length, 3);
      expect(p.clears, 1);
    });

    test('#141: räumt erst nach dem Einlesen auf, sonst wäre die Kopie unter iOS schon weg', () async {
      late _Picker p;
      var clearsAtRead = -1;
      p = _Picker(pickResult: _File(size: 3, onRead: () => clearsAtRead = p.clears));
      FilePickerPlatform.instance = p;
      await pick();
      expect(clearsAtRead, 0);
      expect(p.clears, 1);
    });

    test('#141: räumt bei einer zu großen Datei auf', () async {
      final p = _Picker(pickResult: _File(size: AttachmentPolicy.maxBytes + 1));
      FilePickerPlatform.instance = p;
      await expectLater(pick(), throwsA(isA<FileTooLargeException>()));
      expect(p.clears, 1);
    });

    test('#141: räumt bei einem Lesefehler auf', () async {
      final p = _Picker(pickResult: _File(size: 3, readError: StateError('lesen')));
      FilePickerPlatform.instance = p;
      await expectLater(pick(), throwsStateError);
      expect(p.clears, 1);
    });

    test('#141: räumt bei einem Fehler des Dialogs auf', () async {
      final p = _Picker(pickError: StateError('dialog'));
      FilePickerPlatform.instance = p;
      await expectLater(pick(), throwsStateError);
      expect(p.clears, 1);
    });

    test('ein Fehler beim Aufräumen ändert das Ergebnis nicht', () async {
      final p = _Picker(pickResult: _File(size: 3), clearThrowsSync: true);
      FilePickerPlatform.instance = p;
      expect((await pick())!.bytes.length, 3);
    });
  });

  group('#141: überlappende Vorgänge', () {
    test('der scheiternde zweite Aufruf löscht den offenen Export nicht', () async {
      final open = Completer<void>();
      addTearDown(() {
        if (!open.isCompleted) open.complete();
      });
      final p = _Picker(result: Uri.file('/tmp/a.txt'), saveError: StateError('multiple_request'))..hold = open;
      FilePickerPlatform.instance = p;

      final first = save();
      await expectLater(save(), throwsStateError);
      expect(p.clears, 0, reason: 'der erste Export läuft noch');

      open.complete();
      expect(await first, isTrue);
      expect(p.clears, 1);
    });

    test('clearTemporary wartet auf den letzten Vorgang', () async {
      final open = Completer<void>();
      addTearDown(() {
        if (!open.isCompleted) open.complete();
      });
      final p = _Picker(result: Uri.file('/tmp/a.txt'))..hold = open;
      FilePickerPlatform.instance = p;

      final first = save();
      await SystemFileAccess().clearTemporary();
      expect(p.clears, 0);

      open.complete();
      await first;
      expect(p.clears, 1);
    });
  });

  test('clearTemporary räumt ohne laufenden Vorgang sofort auf und wirft nie', () async {
    final p = _Picker(clearThrowsSync: true);
    FilePickerPlatform.instance = p;
    await SystemFileAccess().clearTemporary();
    expect(p.clears, 1);
  });
}
