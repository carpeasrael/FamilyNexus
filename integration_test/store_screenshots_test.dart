// Erzeugt Store-Screenshots mit erfundenen Beispieldaten (tool/preview). Nicht Teil der Gerätetests.
// iOS:     flutter test integration_test/store_screenshots_test.dart -d <Simulator> [--dart-define=SHOTS_LANG=en]
//          (PNG-Dateien nach /tmp/fn_store_shots_<sprache>, der Simulator darf auf den Mac schreiben)
// Android: flutter test integration_test/store_screenshots_test.dart -d <Emulator> --no-dds --dart-define=SHOTS_LANG=de|en > log.txt
//          (takeScreenshot der Flutter-Fläche; die App-Dateien verschwinden mit der Deinstallation am Laufende, deshalb
//          PNGs als "PNG <name> <base64>" auf stdout; dekodieren mit tool/preview/decode_shots.py <log> <ordner>.
//          Der Lauf endet mit "+1 -1" durch einen Werkzeugfehler (VmServiceProxyGoldenFileComparator), maßgeblich sind die PNG-Zeilen.)
// macOS:   flutter test integration_test/store_screenshots_test.dart -d macos (rendert 2560×1600 ohne Fensterrahmen; PNGs als "PNG <name> <base64>" auf stdout, kein Bildschirmaufnahme-Recht nötig)
// Aufnahmen: 1-heute … 6-familie, danach 7-datenschutz (Menü → Datenschutzerklärung; nur statischer App-Text, keine Nutzerdaten).
// Siehe store/screenshots/README.md und tool/preview/README.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/ui/widgets/glass.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/shell_finders.dart';
import '../tool/preview/preview_data.dart';

// Sprache der Aufnahmen: --dart-define=SHOTS_LANG=en (Standard de); die Dateien landen dann in .../fn_store_shots_<sprache>.
const _lang = String.fromEnvironment('SHOTS_LANG', defaultValue: 'de');

void main() {
  const en = _lang == 'en';
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Store-Screenshots', (tester) async {
    final services = await buildPreviewServices(lang: _lang);
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
    // Nur iOS schreibt Dateien: Im Simulator darf die App auf den Mac schreiben (dort liegen sie nach dem Lauf),
    // sonst in den temporären Ordner der App. macOS und Android geben die Bilder als Base64 auf stdout aus.
    Directory? dir;
    if (Platform.isIOS) {
      try {
        dir = Directory('/tmp/fn_store_shots_$_lang')..createSync(recursive: true);
      } catch (_) {
        dir = Directory('${Directory.systemTemp.path}/store_shots_$_lang')..createSync(recursive: true);
      }
    }
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
      if (Platform.isAndroid) {
        // Auf Android löscht Flutter die App (samt Dateien) am Laufende: Bild als Zeile "PNG <name> <base64>" auf stdout.
        // ignore: avoid_print
        print('PNG $name ${base64Encode(bytes)}');
        return;
      }
      File('${dir!.path}/$name.png').writeAsBytesSync(bytes);
    }

    Future<void> tab(String label) async {
      await tester.tap(navTab(label));
      await tester.pumpAndSettle();
    }

    await shot('1-heute');
    await tab(en ? 'Calendar' : 'Kalender');
    if (Platform.isMacOS) {
      // Auf der breiten Fläche zeigt die Monatsansicht die heutigen Termine nicht im Bild.
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
    }
    await shot('2-kalender');
    await tab('Chat');
    // Der Chat-Tab beginnt mit der Gesprächsliste (#423): „3-chat“ zeigt weiter den Familienchat, „4-einzelchat“
    // danach das Gespräch mit Ben (über den Zurück-Pfeil und seine Zeile).
    await tester.tap(find.byKey(const ValueKey<String>('thread-family')));
    await tester.pumpAndSettle();
    await shot('3-chat');
    await tester.tap(find.byTooltip(en ? 'Back to conversations' : 'Zurück zu den Gesprächen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ben'));
    await tester.pumpAndSettle();
    await shot('4-einzelchat');
    await tab(en ? 'Shopping' : 'Einkauf');
    await shot('5-einkauf');
    await tab(en ? 'Family' : 'Familie');
    await shot('6-familie');
    // Datenschutz zuletzt, damit die Reihenfolge der übrigen Motive unberührt bleibt: Menü → Datenschutzerklärung.
    // Der Bildschirm besteht nur aus App-Text (auf Android mit der Android-Variante des Schlüsselspeicher-Textes).
    await tester.tap(find.byTooltip(en ? 'Open menu' : 'Menü öffnen').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en ? 'Privacy policy' : 'Datenschutzerklärung'));
    await tester.pumpAndSettle();
    // Gestaltung: Der Anfang der Seite ist eine Textwand mit Anbieter-Beispiel („matrix.org“) und endet mitten im Satz.
    // Gezeigt wird deshalb ab dem zweiten Abschnitt („Welche Daten gibt es?“, mit Schlüsselspeicher-Satz und Verschlüsselung):
    // Der Kartenanfang liegt oben, Karten werden am unteren Bildrand wie in jeder Liste angeschnitten.
    await Scrollable.ensureVisible(tester.element(find.byType(GlassCard).at(1)), alignment: 0);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 8)); // kleiner Abstand zur Titelleiste, ohne den Rand der Vorgängerkarte (12 px Abstand) zu zeigen
    await tester.pumpAndSettle();
    await shot('7-datenschutz');
    if (dir != null) {
      // ignore: avoid_print
      print('SHOTS_DIR=${dir.path}');
    }
  });
}
