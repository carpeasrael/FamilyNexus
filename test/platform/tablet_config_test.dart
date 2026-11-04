import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// #274, REQ-TABLET-01, E-92: Plattformkonfiguration für Tablets (Quelltexte, kein Gerät nötig).
void main() {
  final pbxproj = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('iOS: iPhone und iPad in allen drei Konfigurationen (Debug, Release, Profile)', () {
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);').allMatches(pbxproj).map((m) => m.group(1)).toList();
    expect(families, hasLength(3), reason: 'Debug, Release, Profile');
    for (final f in families) {
      expect(f, '"1,2"');
    }
    expect(pbxproj, isNot(contains('TARGETED_DEVICE_FAMILY = 1;')), reason: 'nicht mehr nur iPhone');
  });

  test('iOS: iPad unterstützt alle vier Ausrichtungen, iPhone behält seine drei', () {
    String arrayOf(String key) {
      final m = RegExp('<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>', dotAll: true).firstMatch(plist);
      expect(m, isNotNull, reason: key);
      return m!.group(1)!;
    }

    final ipad = arrayOf('UISupportedInterfaceOrientations~ipad');
    for (final o in <String>['Portrait', 'PortraitUpsideDown', 'LandscapeLeft', 'LandscapeRight']) {
      expect(ipad, contains('<string>UIInterfaceOrientation$o</string>'), reason: 'iPad $o');
    }
    final iphone = arrayOf('UISupportedInterfaceOrientations');
    expect(iphone, contains('UIInterfaceOrientationPortrait</string>'));
    expect(iphone, contains('UIInterfaceOrientationLandscapeLeft'));
    expect(iphone, contains('UIInterfaceOrientationLandscapeRight'));
    expect(iphone, isNot(contains('PortraitUpsideDown')), reason: 'iPhone wie bisher');
  });

  test('iOS: kein UIRequiresFullScreen, sonst gäbe es kein Split View und keine Fenstergrößen', () {
    expect(plist, isNot(contains('UIRequiresFullScreen')));
  });

  test('Android: Fenstergröße ist veränderbar, keine feste Ausrichtung', () {
    expect(manifest, contains('android:resizeableActivity="true"'));
    expect(manifest, isNot(contains('screenOrientation')), reason: 'Rotationssperre des Systems wird respektiert');
    expect(manifest, contains('screenSize'), reason: 'Größenänderung ohne Neustart der Activity');
    expect(manifest, contains('smallestScreenSize'));
    expect(manifest, contains('orientation'));
    expect(manifest, contains('density'));
  });
}
