import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../vault_key_store.dart';

VaultBackend? createWebVaultBackend() => WebVaultBackend();

/// Tresor im `localStorage` des Browsers: Die Schlüsselliste liegt mit AES-256-GCM verschlüsselt darin, der
/// Schlüssel wird mit PBKDF2-SHA256 aus dem Passwort abgeleitet (WebCrypto, nicht exportierbar).
class WebVaultBackend implements VaultBackend {
  static const String storageKey = 'fn.vault.v1';
  static const int iterations = 600000;

  web.SubtleCrypto get _subtle => web.window.crypto.subtle;
  web.CryptoKey? _key;
  Uint8List? _salt;
  int _iterations = iterations;

  @override
  bool get exists => web.window.localStorage.getItem(storageKey) != null;

  JSObject _params(Map<String, JSAny?> values) {
    final o = JSObject();
    values.forEach((k, v) => o.setProperty(k.toJS, v));
    return o;
  }

  JSArray<JSString> _usages(List<String> v) => v.map((e) => e.toJS).toList().toJS;

  Uint8List _random(int n) {
    final bytes = Uint8List(n);
    web.window.crypto.getRandomValues(bytes.toJS);
    return bytes;
  }

  Future<web.CryptoKey> _derive(String password, Uint8List salt, int rounds) async {
    final base = await _subtle
        .importKey('raw', Uint8List.fromList(utf8.encode(password)).toJS, 'PBKDF2'.toJS, false, _usages(<String>['deriveKey']))
        .toDart;
    final derived = await _subtle
        .deriveKey(
          _params(<String, JSAny?>{'name': 'PBKDF2'.toJS, 'salt': salt.toJS, 'iterations': rounds.toJS, 'hash': 'SHA-256'.toJS}),
          base,
          _params(<String, JSAny?>{'name': 'AES-GCM'.toJS, 'length': 256.toJS}),
          false,
          _usages(<String>['encrypt', 'decrypt']),
        )
        .toDart;
    return derived as web.CryptoKey;
  }

  Future<Uint8List> _encrypt(Uint8List iv, Uint8List plain) async {
    final out = await _subtle
        .encrypt(_params(<String, JSAny?>{'name': 'AES-GCM'.toJS, 'iv': iv.toJS}), _key!, plain.toJS)
        .toDart as JSArrayBuffer;
    return out.toDart.asUint8List();
  }

  Future<Uint8List> _decrypt(Uint8List iv, Uint8List cipher) async {
    final out = await _subtle
        .decrypt(_params(<String, JSAny?>{'name': 'AES-GCM'.toJS, 'iv': iv.toJS}), _key!, cipher.toJS)
        .toDart as JSArrayBuffer;
    return out.toDart.asUint8List();
  }

  @override
  Future<void> create(String password) async {
    _salt = _random(16);
    _iterations = iterations;
    _key = await _derive(password, _salt!, _iterations);
    await save(<String, String>{});
  }

  @override
  Future<void> unlock(String password) async {
    final raw = web.window.localStorage.getItem(storageKey);
    if (raw == null) throw const WrongVaultPasswordException();
    final Map<String, dynamic> m;
    try {
      m = jsonDecode(raw) as Map<String, dynamic>;
      _salt = base64Decode(m['s'] as String);
      _iterations = (m['i'] as num).toInt();
    } catch (_) {
      throw const WrongVaultPasswordException();
    }
    // Obergrenze: ein manipulierter Eintrag darf den Browser nicht mit einer riesigen Rundenzahl blockieren.
    if (_iterations < 1 || _iterations > 5000000) throw const WrongVaultPasswordException();
    _key = await _derive(password, _salt!, _iterations);
    try {
      await load();
    } catch (_) {
      _key = null;
      throw const WrongVaultPasswordException();
    }
  }

  @override
  Future<Map<String, String>> load() async {
    final raw = web.window.localStorage.getItem(storageKey);
    if (raw == null || _key == null) throw const WrongVaultPasswordException();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final plain = await _decrypt(base64Decode(m['n'] as String), base64Decode(m['c'] as String));
    final entries = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return entries.map((k, v) => MapEntry(k, v as String));
  }

  @override
  Future<void> save(Map<String, String> entries) async {
    if (_key == null || _salt == null) throw const WrongVaultPasswordException();
    final iv = _random(12);
    final cipher = await _encrypt(iv, Uint8List.fromList(utf8.encode(jsonEncode(entries))));
    web.window.localStorage.setItem(
      storageKey,
      jsonEncode(<String, Object>{'v': 1, 'i': _iterations, 's': base64Encode(_salt!), 'n': base64Encode(iv), 'c': base64Encode(cipher)}),
    );
  }

  @override
  Future<void> destroy() async {
    web.window.localStorage.removeItem(storageKey);
    _key = null;
    _salt = null;
  }
}
