import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ablage für Datenbankschlüssel. Produktiv: Android Keystore bzw. iOS-Schlüsselbund (über
/// `flutter_secure_storage`). Schlüssel stehen nie im Code oder in Dateien.
abstract class KeyStore {
  /// Liest den Schlüssel, ohne einen neuen zu erzeugen (`null` = nicht vorhanden).
  Future<String?> readKey(String name);

  /// Liefert den Schlüssel zu [name]; erzeugt ihn beim ersten Aufruf zufällig.
  /// Parallele Aufrufe für denselben Namen liefern denselben Schlüssel.
  Future<String> getOrCreateKey(String name);

  Future<void> deleteKey(String name);

  /// Löscht alle Schlüssel (Konto-/Datenlöschung).
  Future<void> deleteAll();
}

String generateKey({Random? random, int bytes = 32}) {
  final rnd = random ?? Random.secure();
  return base64UrlEncode(List<int>.generate(bytes, (_) => rnd.nextInt(256)));
}

class SecureKeyStore implements KeyStore {
  /// `resetOnError: false`: Das Plugin darf bei Entschlüsselungsfehlern nicht
  /// stillschweigend alles löschen; der Fehler soll sichtbar werden
  /// (Wiederherstellungsdialog statt Datenverlust).
  SecureKeyStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: false),
              // iOS: nur nach dem ersten Entsperren lesbar und nie in Sicherungen oder auf andere Geräte übertragbar.
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
              // macOS: klassischer Schlüsselbund (läuft ohne Entwicklerkonto/Gruppen-Berechtigung); nie iCloud-synchronisiert.
              mOptions: MacOsOptions(
                usesDataProtectionKeychain: false,
                accessibility: KeychainAccessibility.first_unlock_this_device,
                synchronizable: false,
              ),
            );

  final FlutterSecureStorage _storage;
  static const String _prefix = 'fn.key.';
  final Map<String, Future<String>> _pending = <String, Future<String>>{};

  @override
  Future<String?> readKey(String name) async {
    final v = await _storage.read(key: '$_prefix$name');
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<String> getOrCreateKey(String name) =>
      _pending.putIfAbsent(name, () async {
        try {
          final existing = await readKey(name);
          if (existing != null) return existing;
          final created = generateKey();
          await _storage.write(key: '$_prefix$name', value: created);
          return created;
        } finally {
          // Nach Abschluss nicht cachen: nächster Aufruf liest erneut.
          unawaited(_pending.remove(name));
        }
      });

  @override
  Future<void> deleteKey(String name) => _storage.delete(key: '$_prefix$name');

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
