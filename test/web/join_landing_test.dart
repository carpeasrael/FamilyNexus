import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Prüft die Auswertung der Landingpage (`web/join/join.js`) mit Node; ohne Node wird übersprungen.
void main() {
  final node = Process.runSync('which', <String>['node']);
  test('Landingpage setzt nur streng geprüfte Einladungen zu einem App-Link zusammen', () {
    final r = Process.runSync('node', <String>['test/web/join_landing_test.js']);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
  }, skip: node.exitCode == 0 ? false : 'Node nicht installiert');
}
