import 'package:flutter/foundation.dart';

import '../../core/app_log.dart';
import '../../domain/app_settings.dart';
import '../../domain/key_value_store.dart';

/// Hält die [AppSettings] im Speicher und schreibt Änderungen atomar in den Store.
class SettingsController extends ChangeNotifier {
  SettingsController(this._store, [AppSettings initial = const AppSettings()])
      : _settings = initial;

  final KeyValueStore _store;
  AppSettings _settings;

  AppSettings get settings => _settings;

  static Future<SettingsController> load(KeyValueStore store) async =>
      SettingsController(store, AppSettings.fromMap(await store.readAll()));

  /// Wendet [change] an. Schlägt das Speichern fehl, wird der vorherige Zustand
  /// wiederhergestellt; Rückgabe `false`.
  Future<bool> update(AppSettings Function(AppSettings) change) async {
    final previous = _settings;
    final next = change(previous);
    if (next == previous) return true;
    final before = previous.toMap();
    final after = next.toMap();
    _settings = next;
    notifyListeners();
    try {
      await _store.apply(
        writes: <String, String>{
          for (final e in after.entries)
            if (before[e.key] != e.value) e.key: e.value,
        },
        deletes: before.keys.where((k) => !after.containsKey(k)),
      );
      return true;
    } catch (e) {
      AppLog.e('settings', 'Einstellungen konnten nicht gespeichert werden', e);
      _settings = previous;
      notifyListeners();
      return false;
    }
  }
}
