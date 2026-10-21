// Erzeugt Store-Screenshots mit erfundenen Beispieldaten (tool/preview). Nicht Teil der Gerätetests.
// iOS:     flutter test integration_test/store_screenshots_test.dart -d <Simulator>
// Android: flutter test integration_test/store_screenshots_test.dart -d <Emulator> --no-dds
// Die PNG-Dateien liegen danach im temporären Ordner der App (…/store_shots), siehe tool/preview/README.md.
import 'dart:io';

import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/preview/preview_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Store-Screenshots', (tester) async {
    final services = await buildPreviewServices();
    await tester.pumpWidget(FamilyNexusApp(services: services));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Im iOS-Simulator darf die App auf den Mac schreiben (dort liegen die Dateien nach dem Lauf);
    // sonst in den temporären Ordner der App.
    Directory dir = Directory('${Directory.systemTemp.path}/store_shots');
    if (Platform.isIOS) {
      try {
        dir = Directory('/tmp/fn_store_shots')..createSync(recursive: true);
      } catch (_) {
        dir = Directory('${Directory.systemTemp.path}/store_shots');
      }
    }
    dir.createSync(recursive: true);
    await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      final bytes = await binding.takeScreenshot(name);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
    }

    Future<void> tab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await shot('1-heute');
    await tab('Kalender');
    await shot('2-kalender');
    await tab('Chat');
    await shot('3-chat');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Ben'));
    await tester.pumpAndSettle();
    await shot('4-einzelchat');
    await tab('Einkauf');
    await shot('5-einkauf');
    await tab('Familie');
    await shot('6-familie');
    // ignore: avoid_print
    print('SHOTS_DIR=${dir.path}');
  });
}
