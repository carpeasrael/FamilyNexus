import 'dart:typed_data';

import 'package:family_nexus/data/platform/file_access.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

class _Picker extends FilePickerPlatform {
  _Picker(this.result);
  final Uri? result;

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
  }) async =>
      result;
}

void main() {
  late FilePickerPlatform original;

  setUp(() => original = FilePickerPlatform.instance);
  tearDown(() => FilePickerPlatform.instance = original);

  Future<bool> save() => SystemFileAccess().saveFile(name: 'a.txt', bytes: Uint8List(1), mimeType: 'text/plain');

  test('#136: ein abgebrochener Dialog gilt nicht als gespeichert', () async {
    FilePickerPlatform.instance = _Picker(null);
    expect(await save(), isFalse);
  });

  test('ein gewählter Speicherort gilt als gespeichert', () async {
    FilePickerPlatform.instance = _Picker(Uri.file('/tmp/a.txt'));
    expect(await save(), isTrue);
  });
}
