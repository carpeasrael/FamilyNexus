import 'dart:io';

import 'package:family_nexus/app/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion und appBuild entsprechen der Version in pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect('$appVersion+$appBuild', line.substring('version:'.length).trim());
    expect(appVersionWithBuild, '$appVersion ($appBuild)');
  });
}
