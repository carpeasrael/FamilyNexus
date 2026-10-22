// Erzeugt Store-Screenshots mit erfundenen Beispieldaten (tool/preview). Nicht Teil der Gerätetests.
// iOS:     flutter test integration_test/store_screenshots_test.dart -d <Simulator>
// Android: flutter test integration_test/store_screenshots_test.dart -d <Emulator> --no-dds
// macOS:   flutter test integration_test/store_screenshots_test.dart -d macos (rendert 2560×1600 ohne Fensterrahmen; PNGs als "PNG <name> <base64>" auf stdout, kein Bildschirmaufnahme-Recht nötig)
// Die PNG-Dateien liegen danach im temporären Ordner der App (…/store_shots), siehe tool/preview/README.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:family_nexus/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/preview/preview_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Store-Screenshots', (tester) async {
    final services = await buildPreviewServices();
    // macOS hat kein takeScreenshot: Die Oberfläche wird in Mac-App-Store-Größe (2560×1600, Faktor 2) selbst gerendert.
    final rootKey = GlobalKey();
    if (Platform.isMacOS) {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(2560, 1600);
      addTearDown(tester.view.reset);
    }
    final app = FamilyNexusApp(services: services);
    await tester.pumpWidget(Platform.isMacOS ? RepaintBoundary(key: rootKey, child: app) : app);
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
    if (!Platform.isMacOS) await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      if (Platform.isMacOS) {
        final boundary = rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final png = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        });
        // Die Sandbox der macOS-App ist von außen nicht lesbar: Bild als Base64 auf stdout (Zeile "PNG <name> <base64>").
        // ignore: avoid_print
        print('PNG $name ${base64Encode(png!)}');
        return;
      }
      final bytes = await binding.takeScreenshot(name);
      File('${dir.path}/$name.png').writeAsBytesSync(bytes);
    }

    Future<void> tab(String label) async {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
      await tester.pumpAndSettle();
    }

    await shot('1-heute');
    await tab('Kalender');
    if (Platform.isMacOS) {
      // Auf der breiten Fläche zeigt die Monatsansicht die heutigen Termine nicht im Bild.
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
    }
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
