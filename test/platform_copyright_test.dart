import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #166: Das Copyright der macOS-App muss zu E-02 (AGPL-3.0-or-later) und zur
/// Windows-Angabe passen.
void main() {
  String ownerOf(String line) {
    final m = RegExp(r'Copyright (?:\(C\)|©) \d{4} (\S+?)\.').firstMatch(line);
    expect(m, isNotNull, reason: 'Kein Copyright-Inhaber in: $line');
    return m!.group(1)!;
  }

  test('macOS-Copyright nennt AGPL und denselben Inhaber wie Windows', () {
    final xcconfig = File('macos/Runner/Configs/AppInfo.xcconfig')
        .readAsLinesSync()
        .firstWhere((l) => l.trimLeft().startsWith('PRODUCT_COPYRIGHT'));
    final rc = File('windows/runner/Runner.rc')
        .readAsLinesSync()
        .firstWhere((l) => l.contains('"LegalCopyright"'));

    expect(xcconfig, contains('AGPL-3.0-or-later'));
    expect(xcconfig, isNot(contains('All rights reserved')));
    expect(ownerOf(xcconfig), ownerOf(rc));
  });
}
