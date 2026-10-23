// Selbsttest der Web-Version (E-53): Läuft im Browser und prüft, was sich ohne Browser nicht prüfen lässt.
//   tool/web_selftest.sh   baut diese Datei als Web-App, startet sie in Chrome (headless) und wertet das Ergebnis aus.
// Das Ergebnis steht als `SELFTEST PASS`/`SELFTEST FAIL …` im Seitentext und in der Konsole.
import 'dart:convert';

import 'package:family_nexus/app/bootstrap.dart' show ensureCryptoInitialized;
import 'package:family_nexus/data/db/encrypted_db.dart';
import 'package:family_nexus/data/platform/vault_key_store.dart';
import 'package:flutter/widgets.dart';
import 'package:vodozemac/vodozemac.dart' as vodozemac;
import 'package:web/web.dart' as web;

final List<String> _log = <String>[];

Future<void> _step(String name, Future<void> Function() body) async {
  try {
    await body();
    _log.add('ok   $name');
  } catch (e, st) {
    _log.add('FAIL $name: $e\n$st');
    rethrow;
  }
}

/// Zweiter Seitenaufruf mit demselben Browserprofil: Daten aus IndexedDB und Tresor aus localStorage müssen den
/// Neustart überstehen (`?phase=write`, danach `?phase=read`).
Future<void> _persistence(String phase) async {
  const path = 'persist.db';
  const key = 'persistenter-schluessel-0123456789';
  const password = 'tresor-passwort-0123456789';
  if (phase == 'write') {
    await _step('Persistenz schreiben: Datenbank und Tresor', () async {
      await EncryptedDb.delete(path);
      final db = await EncryptedDb.open(path, password: key, version: 1, onCreate: (d, v) async {
        await d.execute('CREATE TABLE t (v TEXT NOT NULL)');
      });
      await db.insert('t', <String, Object?>{'v': 'UEBERLEBT-NEUSTART'});
      await db.close();
      final backend = createWebVaultBackend()!;
      await backend.destroy();
      await backend.create(password);
      await (await VaultKeyStore.open(backend)).getOrCreateKey('persist');
    });
  } else {
    await _step('Persistenz lesen: Datenbank und Tresor nach Neustart', () async {
      final db = await EncryptedDb.open(path, password: key, version: 1);
      final rows = await db.query('t');
      await db.close();
      if (rows.length != 1 || rows.first['v'] != 'UEBERLEBT-NEUSTART') throw StateError('Daten fehlen: $rows');
      final backend = createWebVaultBackend()!;
      if (!backend.exists) throw StateError('Tresor fehlt');
      await backend.unlock(password);
      if (await (await VaultKeyStore.open(backend)).readKey('persist') == null) throw StateError('Tresorschlüssel fehlt');
    });
  }
}

Future<void> _run() async {
  final phase = Uri.base.queryParameters['phase'];
  if (phase == 'write' || phase == 'read') return _persistence(phase!);
  const path = 'selftest.db';
  const key = 'correct-horse-battery-staple-0123456789';
  await EncryptedDb.delete(path);

  await _step('sqlite3mc: verschlüsselte Datenbank anlegen und lesen', () async {
    final db = await EncryptedDb.open(path, password: key, version: 1, onCreate: (d, v) async {
      await d.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT NOT NULL)');
    });
    await db.insert('t', <String, Object?>{'v': 'GEHEIMER-WERT'});
    await db.close();
    final again = await EncryptedDb.open(path, password: key, version: 1);
    final rows = await again.query('t');
    await again.close();
    if (rows.length != 1 || rows.first['v'] != 'GEHEIMER-WERT') throw StateError('Zeile nicht lesbar: $rows');
  });

  await _step('sqlite3mc: falscher Schlüssel wird abgelehnt', () async {
    var rejected = false;
    try {
      final db = await EncryptedDb.open(path, password: 'falscher-schluessel', version: 1);
      await db.close();
    } catch (_) {
      rejected = true;
    }
    if (!rejected) throw StateError('Datenbank mit falschem Schlüssel geöffnet');
  });

  await _step('Datenbank löschen und exists()', () async {
    if (!await EncryptedDb.exists(path)) throw StateError('exists() meldet fehlend');
    await EncryptedDb.delete(path);
    if (await EncryptedDb.exists(path)) throw StateError('Datenbank nach delete noch vorhanden');
  });

  await _step('Tresor: anlegen, Schlüssel erzeugen, neu entsperren, falsches Passwort', () async {
    final backend = createWebVaultBackend()!;
    await backend.destroy();
    if (backend.exists) throw StateError('Tresor nach destroy vorhanden');
    await backend.create('ein-langes-passwort');
    final keys = await VaultKeyStore.open(backend);
    final a = await keys.getOrCreateKey('db.app');
    final b = await keys.getOrCreateKey('db.app');
    if (a != b || a.length < 40) throw StateError('Schlüssel unbeständig');
    final stored = (await keys.readKey('db.app'))!;
    final raw = jsonEncode(await Future<Object?>.value(web.window.localStorage.getItem('fn.vault.v1')));
    if (raw.contains(stored)) throw StateError('Schlüssel im Klartext im Speicher');
    final fresh = createWebVaultBackend()!;
    var wrong = false;
    try {
      await fresh.unlock('falsches-passwort');
    } on WrongVaultPasswordException {
      wrong = true;
    }
    if (!wrong) throw StateError('Falsches Passwort akzeptiert');
    await fresh.unlock('ein-langes-passwort');
    final reopened = await VaultKeyStore.open(fresh);
    if (await reopened.readKey('db.app') != a) throw StateError('Schlüssel nach Entsperren anders');
    await reopened.deleteAll();
    if (fresh.exists) throw StateError('Tresor nach deleteAll vorhanden');
  });

  await _step('vodozemac (WebAssembly): initialisieren und Konto erzeugen', () async {
    await ensureCryptoInitialized();
    final account = vodozemac.Account();
    final id = account.identityKeys;
    if (id.curve25519.toBase64().isEmpty) throw StateError('Leerer Identitätsschlüssel');
  });

  await _step('bootstrap: ensureCryptoInitialized ist wiederholbar', () async {
    await ensureCryptoInitialized();
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String result;
  try {
    await _run();
    result = 'SELFTEST PASS';
  } catch (e) {
    result = 'SELFTEST FAIL $e';
  }
  final text = '$result\n${_log.join('\n')}';
  // ignore: avoid_print
  print(text);
  final pre = web.document.createElement('pre')..textContent = text;
  web.document.body!.append(pre);
  web.document.title = result;
}
