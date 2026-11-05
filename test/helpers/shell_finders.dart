import 'dart:ui' show Size;

import 'package:family_nexus/features/shell/home_shell.dart' show mainNavigationKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hauptnavigation, unabhängig von der Fensterklasse: untere `NavigationBar` (schmal) oder seitliche
/// `NavigationRail` (ab 600 dp). Beide tragen denselben Schlüssel (#274, E-92).
Finder findNavigation() => find.byKey(mainNavigationKey);

/// Ziel [label] in der Hauptnavigation (Leiste oder Rail).
Finder navTab(String label) => find.descendant(of: findNavigation(), matching: find.text(label));

/// Setzt nur die Fensterbreite auf 400 dp (einspaltig mit unterer Leiste), die Höhe bleibt.
/// Für Tests, die das Smartphone-Layout brauchen. Gesetzt wird bei Gerätepixelverhältnis 1.
Future<void> useCompactWidth(WidgetTester tester, {double width = 400, double? height}) async {
  final view = tester.view;
  final h = height ?? view.physicalSize.height / view.devicePixelRatio;
  view.devicePixelRatio = 1;
  view.physicalSize = Size(width, h);
  addTearDown(view.reset);
  await tester.pump();
}
