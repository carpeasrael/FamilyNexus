import 'dart:async';

import 'key_store.dart';
import 'web/web_vault_backend_stub.dart'
    if (dart.library.js_interop) 'web/web_vault_backend.dart' as web_backend;

/// Das Passwort des Browser-Tresors ist falsch (die Entschlüsselung schlägt fehl).
class WrongVaultPasswordException implements Exception {
  const WrongVaultPasswordException();
  @override
  String toString() => 'WrongVaultPasswordException';
}

/// Verschlüsselte Ablage für die Schlüsselliste (Browser, E-53). Das Passwort wird nie gespeichert;
/// aus ihm wird bei jedem Entsperren der Tresorschlüssel abgeleitet.
abstract class VaultBackend {
  /// Gibt es schon einen Tresor in diesem Browser?
  bool get exists;

  /// Legt einen neuen, leeren Tresor an und entsperrt ihn.
  Future<void> create(String password);

  /// Entsperrt den vorhandenen Tresor; wirft [WrongVaultPasswordException] bei falschem Passwort.
  Future<void> unlock(String password);

  Future<Map<String, String>> load();

  Future<void> save(Map<String, String> entries);

  /// Entfernt den Tresor samt aller Schlüssel.
  Future<void> destroy();
}

/// Tresor des Browsers; `null` auf Plattformen ohne Browser.
VaultBackend? createWebVaultBackend() => web_backend.createWebVaultBackend();

/// [KeyStore] über einen entsperrten [VaultBackend]. Die Schlüssel (Datenbank, Matrix-Datenbank) sind wie auf
/// den anderen Plattformen zufällig; sie liegen nur durch das Tresorpasswort geschützt im Browser.
class VaultKeyStore implements KeyStore {
  VaultKeyStore._(this._backend, this._entries);

  /// [backend] muss entsperrt sein.
  static Future<VaultKeyStore> open(VaultBackend backend) async => VaultKeyStore._(backend, await backend.load());

  final VaultBackend _backend;
  final Map<String, String> _entries;
  Future<void> _queue = Future<void>.value();

  /// Schreibzugriffe laufen nacheinander, damit parallele Aufrufe keine Einträge überschreiben.
  Future<T> _serial<T>(Future<T> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<String?> readKey(String name) async {
    final v = _entries[name];
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<String> getOrCreateKey(String name) => _serial(() async {
        final existing = await readKey(name);
        if (existing != null) return existing;
        final created = generateKey();
        await _backend.save(<String, String>{..._entries, name: created});
        _entries[name] = created;
        return created;
      });

  @override
  Future<void> deleteKey(String name) => _serial(() async {
        if (!_entries.containsKey(name)) return;
        await _backend.save(<String, String>{..._entries}..remove(name));
        _entries.remove(name);
      });

  @override
  Future<void> deleteAll() => _serial(() async {
        await _backend.destroy();
        _entries.clear();
      });
}
