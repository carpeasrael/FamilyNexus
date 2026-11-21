import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quelltextprüfung der Startfarbe unter macOS (#554, E-94): Ohne gesetzte Farbe ist der `FlutterView` bis zum
/// ersten Frame schwarz. Das ist eine Textprüfung und kein Verhaltensbeleg: Übersetzt wird der Swift-Code im CI-Job
/// `apple`, das Verhalten (kein schwarzer Rahmen beim Kaltstart) belegt nur der Geräteschritt (Testplan A-01).
void main() {
  final swift = File('macos/Runner/MainFlutterWindow.swift').readAsStringSync();
  final tokens = File('lib/ui/theme/tokens.dart').readAsStringSync();

  /// `bgBody`-Hexwert (RRGGBB) des Aurora-Tokensatzes [name] (`dark` oder `light`).
  String bgBody(String name) {
    final m = RegExp('static const AuroraTokens $name = AuroraTokens\\(\\s*bgBody: Color\\(0xFF([0-9A-Fa-f]{6})\\)').firstMatch(tokens);
    expect(m, isNotNull, reason: 'bgBody von $name in tokens.dart');
    return m!.group(1)!.toUpperCase();
  }

  String launch(String name) {
    final m = RegExp('launch$name = 0x([0-9A-Fa-f]{6})').firstMatch(swift);
    expect(m, isNotNull, reason: 'launch$name in MainFlutterWindow.swift');
    return m!.group(1)!.toUpperCase();
  }

  test('Flutter-Fläche und Fenster bekommen die Startfarbe', () {
    expect(swift, contains('flutterViewController.backgroundColor = launchColor'));
    expect(swift, contains('self.backgroundColor = launchColor'));
  });

  test('Die Farbe folgt der Systemdarstellung, aufgelöst aus der Appearance der App', () {
    expect(swift, contains('NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua'));
  });

  test('Hexwerte stimmen mit AuroraTokens.bgBody überein (hell und dunkel)', () {
    expect(launch('Dark'), bgBody('dark'));
    expect(launch('Light'), bgBody('light'));
  });
}
