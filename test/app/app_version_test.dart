import 'dart:io';

import 'package:family_nexus/app/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('appVersion entspricht der Version in pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    final version = line.substring('version:'.length).trim().split('+').first;
    expect(appVersion, version);
  });
}
