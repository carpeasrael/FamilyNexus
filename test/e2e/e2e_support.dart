// Ende-zu-Ende-Tests gegen einen echten, lokalen Synapse (tool/synapse/up.sh)
// mit der echten vodozemac-Bibliothek (tool/e2e.sh baut sie für den Host).
// Ohne FN_E2E=1 werden sie übersprungen, damit `flutter test` ohne Docker läuft.
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vodozemac/vodozemac.dart' as vod;

import '../support/memory_stores.dart';

/// Datenbankverzeichnis und Schlüsselspeicher eines Geräts.
typedef E2eDevice = ({String dir, MemoryKeyStore keys});

class E2e {
  static final bool enabled = Platform.environment['FN_E2E'] == '1';
  static const String skipReason = 'Setze FN_E2E=1 und starte tool/synapse/up.sh (siehe tool/e2e.sh)';
  static final String vodLib = Platform.environment['FN_VOD_LIB'] ?? '/tmp/vod-target/release/';
  static final ServerUrl server = ServerUrl.tryParse('https://localhost:18448')!;

  static bool _ready = false;
  static int _n = 0;
  static final String _run = DateTime.now().millisecondsSinceEpoch.toRadixString(36);

  /// Selbstsigniertes Testzertifikat nur hier akzeptieren; die App selbst tut das nie.
  static http.Client lenientClient() {
    final c = HttpClient()..badCertificateCallback = (cert, host, port) => host == 'localhost';
    return IOClient(c);
  }

  static Future<void> init() async {
    if (_ready) return;
    sqfliteFfiInit();
    await vod.init(libraryPath: vodLib);
    _ready = true;
  }

  /// Legt ein Konto an (offene Registrierung des Testservers) und liefert Benutzername/Passwort.
  static Future<({String user, String password})> registerUser(String prefix) async {
    final user = '$prefix-$_run-${_n++}';
    final password = 'pw-$user-12345';
    final c = lenientClient();
    final res = await c.post(
      Uri.parse('${server.uri}/_matrix/client/v3/register'),
      headers: <String, String>{'content-type': 'application/json'},
      body: json.encode(<String, Object?>{
        'username': user,
        'password': password,
        'auth': <String, String>{'type': 'm.login.dummy'},
        'inhibit_login': true,
      }),
    );
    if (res.statusCode != 200) throw StateError('Registrierung fehlgeschlagen: ${res.statusCode} ${res.body}');
    c.close();
    return (user: user, password: password);
  }

  /// [httpClient] statt des Testclients für [server], z. B. für einen anderen Testserver.
  /// Mit [device] nutzt ein zweites Gateway Datenbank und Schlüssel des ersten: wie ein Neustart der App.
  static Future<SdkMatrixGateway> newGateway({
    http.Client? httpClient,
    E2eDevice? device,
    Duration joinPollInterval = SdkMatrixGateway.rejectionPollInterval,
  }) async {
    final d = device ?? await newDevice();
    return SdkMatrixGateway(
      keyStore: d.keys,
      dbDirectory: d.dir,
      probe: ServerProbe(client: lenientClient()),
      databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
      httpClient: httpClient ?? lenientClient(),
      joinPollInterval: joinPollInterval,
    );
  }

  static Future<E2eDevice> newDevice() async =>
      (dir: (await Directory.systemTemp.createTemp('fn_e2e')).path, keys: MemoryKeyStore());

  /// Registriert ein Konto und meldet ein neues Gerät an.
  static Future<({SdkMatrixGateway gateway, String user, String password})> loggedIn(
    String prefix, {
    E2eDevice? device,
    Duration joinPollInterval = SdkMatrixGateway.rejectionPollInterval,
  }) async {
    await init();
    final acc = await registerUser(prefix);
    final g = await newGateway(device: device, joinPollInterval: joinPollInterval);
    await g.restore();
    await g.login(server: server, username: acc.user, password: acc.password);
    return (gateway: g, user: acc.user, password: acc.password);
  }

  /// Meldet ein weiteres Gerät eines bestehenden Kontos an.
  static Future<SdkMatrixGateway> loginAs(String user, String password) async {
    await init();
    final g = await newGateway();
    await g.restore();
    await g.login(server: server, username: user, password: password);
    await until(() => g.initialSyncDone, what: 'Sync neues Gerät');
    return g;
  }

  /// Wartet, bis [cond] wahr ist (Sync läuft im Hintergrund).
  static Future<void> until(bool Function() cond, {Duration timeout = const Duration(seconds: 30), String? what}) async {
    final end = DateTime.now().add(timeout);
    while (!cond()) {
      if (DateTime.now().isAfter(end)) throw StateError('Zeitüberschreitung${what == null ? '' : ': $what'}');
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// [until] für eine Bedingung, die erst den Server oder die Ablage fragen muss.
  static Future<void> untilAsync(Future<bool> Function() cond, {Duration timeout = const Duration(seconds: 30), String? what}) async {
    final end = DateTime.now().add(timeout);
    while (!await cond()) {
      if (DateTime.now().isAfter(end)) throw StateError('Zeitüberschreitung${what == null ? '' : ': $what'}');
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }
}
