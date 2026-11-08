import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'text_norm.dart';

void main() {
  test('#325: posix macht aus Windows-Pfaden Pfade mit /', () {
    expect(posix(r'lib\data\platform\app_badge.dart'), 'lib/data/platform/app_badge.dart');
    expect(posix(r'lib\l10n\gen\x.dart').contains('/l10n/gen/'), isTrue);
    expect(posix('lib/a/b.dart'), 'lib/a/b.dart');
  });

  test('#325: readNormalized macht aus CRLF LF und lässt LF unverändert', () {
    final dir = Directory.systemTemp.createTempSync('fn_norm');
    addTearDown(() => dir.deleteSync(recursive: true));
    final crlf = File('${dir.path}/a.txt')..writeAsStringSync('x\r\nAUFGABEN\r\ny');
    final lf = File('${dir.path}/b.txt')..writeAsStringSync('x\nAUFGABEN\ny');
    expect(readNormalized(crlf.path), 'x\nAUFGABEN\ny');
    expect(readNormalized(lf.path), 'x\nAUFGABEN\ny');
  });
}
