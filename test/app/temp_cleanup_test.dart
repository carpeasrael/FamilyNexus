import 'package:family_nexus/app/bootstrap.dart';
import 'package:family_nexus/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_stores.dart';
import '../support/test_app.dart';

void main() {
  group('#141: temporäre Dateien', () {
    test('wipeAccountData räumt auf, auch wenn die Familiendaten bleiben (#134)', () async {
      final app = await buildTestApp();
      final files = app.services.files as FakeFileAccess;
      var wiped = 0;
      app.services.debugWipeAccountData = () async => wiped++;
      app.services.keepAccountData = true;
      await app.services.wipeAccountData();
      expect(files.cleared, 1);
      expect(wiped, 0);
    });

    test('wipeAccountData räumt auf und löscht ohne Vermerk', () async {
      final app = await buildTestApp();
      final files = app.services.files as FakeFileAccess;
      var wiped = 0;
      app.services.debugWipeAccountData = () async => wiped++;
      await app.services.wipeAccountData();
      expect(files.cleared, 1);
      expect(wiped, 1);
    });

    test('der Vermerk gilt so, wie er vor dem Aufräumen stand', () async {
      final app = await buildTestApp();
      final files = app.services.files as FakeFileAccess;
      var wiped = 0;
      app.services.debugWipeAccountData = () async => wiped++;
      app.services.keepAccountData = true;
      files.onClear = () async => app.services.keepAccountData = false;
      await app.services.wipeAccountData();
      expect(wiped, 0, reason: 'eine Bestätigung während des Aufräumens löscht die behaltenen Daten nicht');
    });

    test('resetLocalData räumt zuerst auf, auch wenn das Löschen scheitert', () async {
      final files = FakeFileAccess();
      await expectLater(
        resetLocalData(keyStore: MemoryKeyStore(), files: files, destroyAll: () async => throw StateError('voll')),
        throwsStateError,
      );
      expect(files.cleared, 1);
    });

    test('resetLocalData führt das Löschen aus', () async {
      final files = FakeFileAccess();
      var destroyed = 0;
      await resetLocalData(keyStore: MemoryKeyStore(), files: files, destroyAll: () async => destroyed++);
      expect(destroyed, 1);
    });

    test('bootstrap räumt vor dem Öffnen der Datenbank auf, auch wenn der Start scheitert', () async {
      final files = FakeFileAccess();
      var clearedAtOpen = -1;
      await expectLater(
        bootstrap(
          keyStore: MemoryKeyStore(),
          files: files,
          openDatabase: (_) {
            clearedAtOpen = files.cleared;
            return Future<AppDatabase>.error(StateError('Schlüssel fehlt'));
          },
        ),
        throwsStateError,
      );
      expect(clearedAtOpen, 1);
    });
  });
}
