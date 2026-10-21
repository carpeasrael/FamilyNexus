// Vorschau mit ERFUNDENEN Beispieldaten (Fake-Matrix, kein Netzwerk) für Store-Screenshots und Demos.
// Start: flutter run -t tool/preview/preview_main.dart -d <Gerät>   (siehe tool/preview/README.md)
import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';

import 'preview_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(FamilyNexusApp(services: await buildPreviewServices()));
}
