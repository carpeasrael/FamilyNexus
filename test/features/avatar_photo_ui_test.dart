import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/domain/avatar_photo.dart';
import 'package:family_nexus/domain/avatar_photo_processing.dart';
import 'package:family_nexus/domain/avatar_photo_store.dart';
import 'package:family_nexus/domain/calendar_signal.dart';
import 'package:family_nexus/domain/family.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/family/avatar_photo_crop_screen.dart';
import 'package:family_nexus/features/family/avatar_screen.dart';
import 'package:family_nexus/features/family/member_avatar_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/avatar_photo_fixtures.dart';
import '../support/memory_avatar_photo_store.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

/// #434, E-111: Foto-Abschnitt, Zuschnitt, Anzeige und Zurücksetzen in der Oberfläche. Die Bildaufbereitung läuft direkt
/// (ohne Isolate); Rohpixel-Bilder entstehen über den Motor und brauchen echte Zeit (`runAsync`).
const String _anna = '@anna:fake.test';
const String _ben = '@ben:fake.test';

Future<void> _settle(WidgetTester tester, {int rounds = 3}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Quellbild: links rot, rechts blau (Querformat).
Uint8List _source({int w = 400, int h = 300}) {
  final image = img.Image(width: w, height: h);
  for (final p in image) {
    if (p.x < w ~/ 2) {
      p
        ..r = 220
        ..g = 20
        ..b = 20;
    } else {
      p
        ..r = 20
        ..g = 20
        ..b = 220;
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Future<AvatarPreview> _preview(Uint8List b) async => AvatarPhotoProcessing.preview(b);

/// Direkte Aufbereitung; merkt sich den Ausschnitt, mit dem gespeichert wurde.
class _Prepare {
  AvatarCrop? last;
  Future<Uint8List> call(Uint8List b, AvatarCrop crop) async {
    last = crop;
    return AvatarPhotoProcessing.prepare(b, crop: crop);
  }
}

Widget _screen(TestApp app, _Prepare prepare) => AppScope(
  services: app.services,
  child: MaterialApp(
    locale: const Locale('de'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: buildTheme(Brightness.light),
    home: AvatarScreen(services: app.services, photoPreview: _preview, photoPrepare: prepare.call),
  ),
);

extension on TestApp {
  FakeFileAccess get files => services.files as FakeFileAccess;
}

AvatarPhoto _photo(String owner, {String id = '00000000-0000-4000-8000-0000000000a1', int createdAt = 1000}) =>
    AvatarPhoto(owner: owner, id: id, createdAt: createdAt, cleared: false, width: 64, height: 48, bytes: jpegBytes());

/// Geöffnete Test-Apps; ihre Kalender-Controller haben Zeitgeber, die vor dem Ende des Tests enden müssen. Flutter 3.47
/// (CI) prüft offene Zeitgeber vor `addTearDown`, deshalb räumt der Test selbst auf: erst den Widget-Baum entfernen, dann
/// den Kalender schließen.
final List<TestApp> _opened = <TestApp>[];

void uiTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    try {
      await body(tester);
    } finally {
      await tester.pumpWidget(const SizedBox());
      for (final app in _opened) {
        app.services.closeCalendar();
      }
      _opened.clear();
    }
  });
}

void main() {
  late MemoryAvatarPhotoStore store;
  late _Prepare prepare;

  setUp(() {
    store = MemoryAvatarPhotoStore();
    prepare = _Prepare();
  });

  Future<TestApp> app0({bool enabled = true, bool withStore = true}) async {
    final app = await buildTestApp(avatarPhotoItems: withStore ? store : null, avatarPhotosEnabled: enabled);
    await app.services.openCalendar();
    _opened.add(app);
    return app;
  }

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  String room(TestApp app) => app.gateway.familyRoom!.id;

  group('Foto-Abschnitt im Avatar-Bildschirm', () {
    uiTest('gesperrt oder ohne Ablage erscheint kein Foto-Abschnitt', (tester) async {
      bigView(tester);
      for (final (enabled, withStore) in <(bool, bool)>[(false, true), (true, false)]) {
        final app = await app0(enabled: enabled, withStore: withStore);
        await tester.pumpWidget(_screen(app, prepare));
        await tester.pumpAndSettle();
        expect(find.text('Initialen (kein Avatar)'), findsWidgets, reason: 'der Bildschirm selbst ist da');
        expect(
          find.byKey(const ValueKey<String>('avatar-photo-choose')),
          findsNothing,
          reason: 'enabled=$enabled, Ablage=$withStore',
        );
        await tester.pumpWidget(const SizedBox());
      }
    });

    uiTest('freigegeben: „Foto wählen“ zeigt zuerst den Pflicht-Hinweis; Abbrechen ruft die Auswahl nie auf', (
      tester,
    ) async {
      bigView(tester);
      final app = await app0();
      app.files.nextImage = PickedFile(name: 'a.png', bytes: _source());
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      expect(find.text('Foto als Avatar'), findsOneWidget);
      expect(find.textContaining('Alle Familienmitglieder sehen dieses Foto'), findsOneWidget);
      expect(find.textContaining('Sorgeberechtigte'), findsOneWidget);
      expect(app.files.imagePicks, 0, reason: 'erst nach der Bestätigung');
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(app.files.imagePicks, 0);
      expect(find.byKey(const ValueKey<String>('avatar-crop-viewer')), findsNothing);
    });

    Future<void> chooseAndSave(WidgetTester tester, TestApp app) async {
      app.files.nextImage = PickedFile(name: 'a.png', bytes: _source());
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden, weiter'));
      await tester.pump();
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(app.files.imagePicks, 1);
      expect(find.byKey(const ValueKey<String>('avatar-crop-viewer')), findsOneWidget);
      expect(find.text('Ausschnitt wählen'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey<String>('avatar-crop-save')));
      await _settle(tester);
      await tester.pumpAndSettle();
    }

    uiTest('Foto wählen, zuschneiden, speichern: das Foto wird gespeichert und über den Sync gesendet', (tester) async {
      bigView(tester);
      final app = await app0();
      await chooseAndSave(tester, app);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = (await store.photo(room(app), _anna))!;
      expect(saved.photo.cleared, isFalse);
      expect(saved.photo.width, 192);
      expect(saved.photo.height, 192);
      expect(saved.published, isTrue, reason: 'der Sync hat es gesendet');
      expect(saved.eventId, isNotEmpty);
      expect(app.server.log.where((e) => e.type == AvatarPhotoCodec.type), hasLength(1));
      expect(find.text('Foto gespeichert'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('avatar-crop-viewer')),
        findsNothing,
        reason: 'zurück im Avatar-Bildschirm',
      );
    });

    uiTest('ohne Verbindung bleibt das Foto ungesendet, der Hinweis erscheint', (tester) async {
      bigView(tester);
      final app = await app0();
      app.gateway.failPublishes = true;
      await chooseAndSave(tester, app);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final saved = (await store.photo(room(app), _anna))!;
      expect(saved.published, isFalse);
      expect(find.textContaining('wird an die Familie gesendet'), findsOneWidget);
      expect(app.server.log.where((e) => e.type == AvatarPhotoCodec.type), isEmpty);
    });

    uiTest('zu große Datei und abgebrochene Auswahl', (tester) async {
      bigView(tester);
      final app = await app0();
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      app.files.imageTooLarge = true;
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden, weiter'));
      await tester.pumpAndSettle();
      expect(find.text('Die Datei ist zu groß (höchstens 15 MiB).'), findsOneWidget);
      app.files.imageTooLarge = false;
      app.files.nextImage = null;
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden, weiter'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('avatar-crop-viewer')), findsNothing, reason: 'Auswahl abgebrochen');
      expect(await store.photos(room(app)), isEmpty);
    });

    uiTest('nicht unterstütztes Format (HEIC): Hinweis, zurück im Avatar-Bildschirm, nichts gespeichert', (
      tester,
    ) async {
      bigView(tester);
      final app = await app0();
      final heic = Uint8List.fromList(<int>[
        0,
        0,
        0,
        24,
        0x66,
        0x74,
        0x79,
        0x70,
        0x68,
        0x65,
        0x69,
        0x63,
        ...List<int>.filled(32, 0),
      ]);
      app.files.nextImage = PickedFile(name: 'a.heic', bytes: heic);
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden, weiter'));
      await tester.pump();
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(find.text('Dieses Format wird nicht unterstützt. Bitte JPEG, PNG oder WebP wählen.'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('avatar-crop-viewer')), findsNothing);
      expect(await store.photos(room(app)), isEmpty);
    });

    uiTest('Entfernen: Rückfrage, dann Löschmarke; ohne Bestätigung bleibt das Foto', (tester) async {
      bigView(tester);
      final app = await app0();
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: _photo(_anna), published: true, eventId: r'$e1'));
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.text('Foto ändern'), findsOneWidget, reason: 'es gibt ein Foto');
      final remove = find.byKey(const ValueKey<String>('avatar-photo-remove'));
      expect(remove, findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Abbrechen')));
      await tester.pumpAndSettle();
      expect((await store.photo(room(app), _anna))!.photo.cleared, isFalse);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Foto entfernen')),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final after = (await store.photo(room(app), _anna))!;
      expect(after.photo.cleared, isTrue);
      expect(after.published, isTrue, reason: 'der Sync hat die Löschmarke gesendet');
      final events = app.server.log.where((e) => e.type == AvatarPhotoCodec.type).toList();
      expect(events.single.content['cleared'], isTrue);
      expect(app.gateway.redactedEvents, <String>[r'$e1'], reason: 'die frühere Kopie wird aufgeräumt');
      expect(after.redactIds, isEmpty, reason: 'der Auftrag ist erledigt');
      expect(find.text('Foto entfernt'), findsOneWidget);
    });

    uiTest('ist das eigene Foto zurückgesetzt, steht der Hinweis da; ein neues Foto ist weiter möglich', (
      tester,
    ) async {
      bigView(tester);
      final app = await app0();
      final p = _photo(_anna);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: p, published: true));
      await store.addReset(room(app), AvatarReset(target: _anna, photoId: p.id, photoCreatedAt: p.createdAt));
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await _settle(tester);
      expect(find.byKey(const ValueKey<String>('avatar-photo-reset-note')), findsOneWidget);
      expect(
        find.text('Dein Foto wurde von einem Moderator zurückgesetzt. Du kannst ein neues Foto wählen.'),
        findsOneWidget,
      );
      expect(find.text('Foto wählen'), findsOneWidget, reason: 'das zurückgesetzte Foto zeigt keinen „Entfernen“-Weg');
      expect(find.byKey(const ValueKey<String>('avatar-photo-remove')), findsNothing);
    });
  });

  group('Zuschnitt', () {
    Future<void> openCrop(WidgetTester tester, TestApp app) async {
      app.files.nextImage = PickedFile(name: 'a.png', bytes: _source());
      await tester.pumpWidget(_screen(app, prepare));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-photo-choose')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verstanden, weiter'));
      await tester.pump();
      await _settle(tester);
      await tester.pumpAndSettle(); // die Ausblendung des Hinweises ist beendet, nichts liegt mehr über der Fläche
    }

    uiTest('Standard: die Mitte des Bildes, Zoom 1', (tester) async {
      bigView(tester);
      final app = await app0();
      await openCrop(tester, app);
      await tester.tap(find.byKey(const ValueKey<String>('avatar-crop-save')));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(prepare.last!.zoom, 1);
      expect(prepare.last!.centerX, closeTo(0.5, 0.01));
      expect(prepare.last!.centerY, closeTo(0.5, 0.01));
    });

    uiTest('Verschieben ändert den Ausschnitt', (tester) async {
      bigView(tester);
      final app = await app0();
      await openCrop(tester, app);
      await tester.drag(find.byKey(const ValueKey<String>('avatar-crop-viewer')), const Offset(-100, 0));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-crop-save')));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(prepare.last!.centerX, greaterThan(0.55), reason: 'nach links gezogen zeigt der rechte Teil');
      expect(prepare.last!.zoom, 1);
    });

    uiTest('der Zoom-Regler ersetzt die Geste (Tastatur, Screenreader)', (tester) async {
      bigView(tester);
      final app = await app0();
      await openCrop(tester, app);
      final slider = find.byKey(const ValueKey<String>('avatar-crop-zoom'));
      expect(slider, findsOneWidget);
      await tester.drag(slider, const Offset(400, 0));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('avatar-crop-save')));
      await _settle(tester);
      await tester.pumpAndSettle();
      expect(prepare.last!.zoom, greaterThan(4), reason: 'zum Ende gezogen');
      final r = prepare.last!.rect(400, 300);
      expect(r.side, lessThan(100), reason: 'ein kleiner Ausschnitt');
      expect(r.x, inInclusiveRange(0, 400 - r.side));
    });

    uiTest('Abbrechen im Zuschnitt speichert nichts', (tester) async {
      bigView(tester);
      final app = await app0();
      await openCrop(tester, app);
      await tester.tap(
        find.descendant(of: find.byType(AvatarPhotoCropScreen), matching: find.widgetWithText(TextButton, 'Abbrechen')),
      );
      await tester.pumpAndSettle();
      expect(await store.photos(room(app)), isEmpty);
      expect(prepare.last, isNull);
      expect(find.byType(SnackBar), findsNothing, reason: 'weder „gespeichert“ noch ein Fehler');
    });
  });

  group('AvatarFace mit Foto', () {
    /// Das Bild entsteht im Motor; der Aufruf muss in `runAsync` stehen, sonst läuft der Abschluss in der Fake-Zeit nie.
    Future<ui.Image> tinyImage(WidgetTester tester) async {
      final image = await tester.runAsync(() {
        final c = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          Uint8List.fromList(List<int>.filled(4 * 4 * 4, 200)),
          4,
          4,
          ui.PixelFormat.rgba8888,
          c.complete,
        );
        return c.future;
      });
      return image!;
    }

    Widget host(Widget child) => MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    );

    uiTest('das Foto füllt den Kreis; mit Ring ist es um die Randbreite kleiner, damit der Ring sichtbar bleibt', (
      tester,
    ) async {
      final image = await tinyImage(tester);
      await tester.pumpWidget(host(AvatarFace(preset: null, photo: image, letter: 'A', size: 40, colorIndex: 1)));
      expect(tester.widget<RawImage>(find.byType(RawImage)).width, 40);
      await tester.pumpWidget(
        host(AvatarFace(preset: null, photo: image, letter: 'A', size: 40, colorIndex: 1, ring: true)),
      );
      expect(tester.widget<RawImage>(find.byType(RawImage)).width, 36, reason: '40 - 2 x 2 (Randbreite)');
      expect(find.text('A'), findsNothing, reason: 'das Foto verdrängt den Buchstaben');
    });

    uiTest('das Foto hat Vorrang vor dem Avatar; ohne Foto gilt der Avatar, dann der Buchstabe', (tester) async {
      final image = await tinyImage(tester);
      await tester.pumpWidget(host(AvatarFace(preset: 'p01', photo: image, letter: 'A', size: 48, colorIndex: 0)));
      expect(find.byType(RawImage), findsOneWidget);
      expect(find.byType(Icon), findsNothing, reason: 'der eingebaute Avatar ist verdeckt');
      await tester.pumpWidget(host(const AvatarFace(preset: 'p01', letter: 'A', size: 48, colorIndex: 0)));
      expect(find.byType(RawImage), findsNothing);
      expect(find.byType(Icon), findsOneWidget);
      await tester.pumpWidget(host(const AvatarFace(preset: null, letter: 'A', size: 48, colorIndex: 0)));
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('Foto nur für beigetretene Mitglieder', () {
    uiTest('eine Person, die nicht in der Familie steht, zeigt kein Foto, auch wenn eines in der Ablage liegt', (
      tester,
    ) async {
      final app = await app0();
      const ghost = '@ghost:fake.test';
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: _photo(ghost), published: true));
      await tester.pumpWidget(
        AppScope(
          services: app.services,
          child: MaterialApp(
            locale: const Locale('de'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: buildTheme(Brightness.light),
            home: Scaffold(
              body: MemberAvatarView(userId: ghost, size: 40, colorIndex: 0, fallbackName: 'Gast'),
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('G'), findsOneWidget, reason: 'Rückfall: Buchstabe');
    });
  });

  group('Anzeige und Zurücksetzen in der Familie', () {
    Future<void> openFamilyPage(WidgetTester tester, TestApp app) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await openFamily(tester);
    }

    Future<void> joinBen(TestApp app) async {
      final ben = app.server.newDevice();
      await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
      final r = app.gateway.familyRoom!;
      r.membership[_ben] = MemberStatus.joined;
      ben.attachFamilyRoom(r.id);
    }

    Finder avatarOf(String userId) => find.byKey(ValueKey<String>('avatar-$userId'));

    uiTest('ein Foto ersetzt den Avatar in der Mitgliederliste; ohne Foto bleibt der Rückfall', (tester) async {
      final app = await app0();
      await joinBen(app);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: _photo(_ben), published: true));
      await openFamilyPage(tester, app);
      await _settle(tester);
      expect(
        find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)),
        findsOneWidget,
        reason: 'Ben hat ein Foto',
      );
      expect(
        find.descendant(of: avatarOf(_anna), matching: find.byType(RawImage)),
        findsNothing,
        reason: 'Anna hat keins',
      );
      expect(
        find.descendant(of: avatarOf(_anna), matching: find.text('A')),
        findsOneWidget,
        reason: 'Buchstabe als Rückfall',
      );
    });

    uiTest('ein zurückgesetztes oder entferntes Foto wird nicht angezeigt', (tester) async {
      final app = await app0();
      await joinBen(app);
      final p = _photo(_ben);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: p, published: true));
      await store.addReset(room(app), AvatarReset(target: _ben, photoId: p.id, photoCreatedAt: p.createdAt));
      await openFamilyPage(tester, app);
      await _settle(tester);
      expect(find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)), findsNothing);
    });

    uiTest('Moderator: „Foto zurücksetzen“ mit Rückfrage legt ein ungesendetes Zurücksetzen an', (tester) async {
      final app = await app0();
      await joinBen(app);
      final p = _photo(_ben);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: p, published: true));
      await openFamilyPage(tester, app);
      await _settle(tester);
      await tester.tap(find.byTooltip('Aktionen für Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Foto zurücksetzen'), findsOneWidget);
      await tester.tap(find.text('Foto zurücksetzen'));
      await tester.pumpAndSettle();
      expect(find.text('Foto von Ben zurücksetzen?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await tester.pumpAndSettle();
      expect(await store.resets(room(app)), isEmpty, reason: 'ohne Bestätigung nichts');
      await tester.tap(find.byTooltip('Aktionen für Ben'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto zurücksetzen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Foto zurücksetzen'));
      await tester.pumpAndSettle();
      await _settle(tester);
      final resets = await store.resets(room(app));
      expect(resets.single.reset.photoId, p.id);
      expect(resets.single.reset.target, _ben);
      expect(find.text('Foto zurückgesetzt'), findsOneWidget);
      expect(
        find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)),
        findsNothing,
        reason: 'sofort ausgeblendet',
      );
    });

    uiTest('ein Mitglied ohne Moderatorrolle sieht „Foto zurücksetzen“ nie, auch wenn das Foto sichtbar ist', (
      tester,
    ) async {
      final app = await app0();
      await joinBen(app);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: _photo(_ben), published: true));
      // Anna ist hier nur Mitglied (Stufe 0), nicht Moderatorin.
      app.gateway.familyRoom!.power[_anna] = 0;
      await openFamilyPage(tester, app);
      await _settle(tester);
      expect(
        find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)),
        findsOneWidget,
        reason: 'das Foto ist sichtbar',
      );
      await tester.tap(find.byTooltip('Aktionen für Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Foto zurücksetzen'), findsNothing, reason: 'nur Moderatoren dürfen zurücksetzen');
      expect(find.text('Verifizieren'), findsWidgets, reason: 'das Menü selbst ist offen (anderer Eintrag vorhanden)');
    });

    uiTest('ein Foto, das über den Sync eintrifft, erscheint ohne Neuaufbau der Seite in der Anzeige', (tester) async {
      final app = await app0();
      await joinBen(app);
      await openFamilyPage(tester, app);
      await _settle(tester);
      expect(
        find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)),
        findsNothing,
        reason: 'noch kein Foto',
      );
      final photo = AvatarPhoto(
        owner: _ben,
        id: '00000000-0000-4000-8000-0000000000b1',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        cleared: false,
        width: 64,
        height: 48,
        bytes: jpegBytes(),
      );
      app.gateway.injectSignal(AvatarPhotoSignal(_ben, DateTime.now(), AvatarPhotoCodec.encode(photo), eventId: r'$x'));
      await _settle(tester, rounds: 4);
      expect((await store.photo(room(app), _ben))!.photo.id, photo.id, reason: 'der Sync hat es gespeichert');
      expect(
        find.descendant(of: avatarOf(_ben), matching: find.byType(RawImage)),
        findsOneWidget,
        reason: 'die Anzeige wurde erneuert',
      );
    });

    uiTest('beim Schließen des Kalenders wird der Bilder-Zwischenspeicher freigegeben', (tester) async {
      final app = await app0();
      final images = app.services.calendar!.avatarPhotoImages!;
      app.services.closeCalendar();
      expect(() => images.addListener(() {}), throwsFlutterError, reason: 'nach dispose nicht mehr benutzbar');
    });

    uiTest('kein Eintrag „Foto zurücksetzen“ ohne Foto, bei gesperrter Funktion und ohne Moderatorrolle', (
      tester,
    ) async {
      // Ohne Foto
      var app = await app0();
      await joinBen(app);
      await openFamilyPage(tester, app);
      await _settle(tester);
      await tester.tap(find.byTooltip('Aktionen für Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Foto zurücksetzen'), findsNothing, reason: 'Ben hat kein Foto');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());

      // Gesperrt
      store = MemoryAvatarPhotoStore();
      app = await app0(enabled: false);
      await joinBen(app);
      await store.putPhoto(room(app), StoredAvatarPhoto(photo: _photo(_ben), published: true));
      await openFamilyPage(tester, app);
      await _settle(tester);
      await tester.tap(find.byTooltip('Aktionen für Ben'));
      await tester.pumpAndSettle();
      expect(find.text('Foto zurücksetzen'), findsNothing, reason: 'gesperrt');
    });
  });
}
