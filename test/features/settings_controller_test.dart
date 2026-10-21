import '../support/memory_stores.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Änderungen werden persistiert und wieder geladen', () async {
    final store = MemoryKeyValueStore();
    final c = await SettingsController.load(store);
    var notified = 0;
    c.addListener(() => notified++);
    await c.update((s) => s.copyWith(languageCode: 'en', reduceEffects: true));
    expect(notified, 1);
    final reloaded = await SettingsController.load(store);
    expect(reloaded.settings.languageCode, 'en');
    expect(reloaded.settings.reduceEffects, isTrue);
  });

  test('Rücksetzen auf Gerätesprache löscht den Schlüssel', () async {
    final store = MemoryKeyValueStore();
    final c = await SettingsController.load(store);
    await c.update((s) => s.copyWith(languageCode: 'de'));
    await c.update((s) => s.copyWith(languageCode: null));
    expect(store.data.containsKey('language'), isFalse);
  });

  test('Schreibfehler stellt den vorherigen Zustand wieder her', () async {
    final store = MemoryKeyValueStore();
    final c = await SettingsController.load(store);
    store.failWrites = true;
    final ok = await c.update((s) => s.copyWith(reduceEffects: true));
    expect(ok, isFalse);
    expect(c.settings.reduceEffects, isFalse);
  });

  test('unveränderte Einstellungen lösen nichts aus', () async {
    final c = await SettingsController.load(MemoryKeyValueStore());
    var notified = 0;
    c.addListener(() => notified++);
    await c.update((s) => s);
    expect(notified, 0);
  });
}
