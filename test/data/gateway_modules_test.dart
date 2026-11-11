import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/text_norm.dart';

/// AP-5 (#363): Beim Auslagern der Gateway-Module werden Klassen-Statics im verschobenen Text als
/// `SdkMatrixGateway.<name>` qualifiziert. In einer String-Interpolation ist `'$SdkMatrixGateway.knockReasonPrefix'`
/// aber kein Zugriff auf das Static, sondern `$SdkMatrixGateway` plus Literaltext; der Analyzer meldet das nicht.
/// Richtig ist `'${SdkMatrixGateway.knockReasonPrefix}'`.
void main() {
  test('kein ungeklammertes \$SdkMatrixGateway in einer String-Interpolation in lib/', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = posix(f.path);
      if (!path.endsWith('.dart') || path.contains('/l10n/gen/')) continue;
      final lines = readNormalized(f.path).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\$SdkMatrixGateway\b').hasMatch(lines[i])) found.add('$path:${i + 1}');
      }
    }
    expect(found, isEmpty, reason: r'Interpolation mit $SdkMatrixGateway ohne geschweifte Klammern');
  });
}
