import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/data/matrix/server_probe.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/memory_stores.dart';
import '../support/sync_requests.dart';

/// #451: Der Sync-Loop des SDK meldet das Konto nicht als online. Ohne `set_presence` gilt ein Konto am Server als
/// online, auch wenn „Online-Status teilen“ aus ist; der Familienstatus läuft über Gerätenachrichten (E-38).
const String _me = '@n1:hs.example';

http.StreamedResponse _json(Object body, [int status = 200]) => http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(json.encode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

class _Hs {
  final Completer<void> _hold = Completer<void>();
  int _syncs = 0;

  /// Anfragen des SDK-Sync-Loops (ohne Ablehnungsabfragen), in der Reihenfolge des Eintreffens.
  final List<Uri> loopSyncs = <Uri>[];

  void release() {
    if (!_hold.isCompleted) _hold.complete();
  }

  http.Client get client => MockClient.streaming((req, body) async {
        final path = req.url.path;
        if (path == '/_matrix/client/versions') return _json(<String, Object?>{'versions': <String>['v1.1', 'v1.11']});
        if (path == '/_matrix/client/v3/login') {
          if (req.method == 'POST') return _json(<String, Object?>{'user_id': _me, 'access_token': 'tok', 'device_id': 'DEV1'});
          return _json(<String, Object?>{
            'flows': <Object?>[<String, Object?>{'type': 'm.login.password'}],
          });
        }
        if (path.endsWith('/filter')) return _json(<String, Object?>{'filter_id': '1'});
        if (path == '/_matrix/client/v3/sync') {
          if (isRejectionPoll(req.url)) return _json(<String, Object?>{'next_batch': 'p'});
          // Erfasst, bevor die Antwort angehalten wird: auch die Anfrage nach der ersten Antwort wird gezählt.
          loopSyncs.add(req.url);
          final n = _syncs++;
          if (n == 0) return _json(<String, Object?>{'next_batch': 's1'});
          await _hold.future;
          return _json(<String, Object?>{'next_batch': 's${n + 1}'});
        }
        if (req.method == 'PUT' || req.method == 'POST') return _json(<String, Object?>{});
        return _json(<String, Object?>{'errcode': 'M_UNRECOGNIZED', 'error': 'nicht vorhanden'}, 404);
      });
}

void main() {
  setUpAll(sqfliteFfiInit);

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('fn_presence');
    addTearDown(() => dir.delete(recursive: true));
  });

  test('Kontrolle: isRejectionPoll erkennt die Ablehnungsabfrage und nicht den SDK-Sync', () {
    final poll = Uri.parse('https://hs.example/_matrix/client/v3/sync').replace(queryParameters: <String, String>{
      'filter': SdkMatrixGateway.rejectionPollFilter('!r:hs.example', 1),
      'timeout': '0',
      'set_presence': 'offline',
    });
    expect(isRejectionPoll(poll), isTrue);
    // Erster SDK-Sync: `timeout=0`, aber nur die Filter-ID.
    expect(isRejectionPoll(Uri.parse('https://hs.example/_matrix/client/v3/sync?filter=1&timeout=0')), isFalse);
    expect(isRejectionPoll(Uri.parse('https://hs.example/_matrix/client/v3/sync?filter=1&since=s1&timeout=30000')), isFalse);
  });

  test('jeder Sync des SDK-Loops trägt set_presence=offline, auch die Folgeanfragen mit since', () async {
    final hs = _Hs();
    final g = SdkMatrixGateway(
      keyStore: MemoryKeyStore(),
      dbDirectory: dir.path,
      probe: ServerProbe(client: hs.client),
      databaseOpener: (path, key) => databaseFactoryFfi.openDatabase(path),
      httpClient: hs.client,
      ensureAvatarPermission: false,
    );
    addTearDown(() async {
      hs.release();
      await g.close();
    });
    await g.restore();
    await g.login(server: ServerUrl.tryParse('hs.example')!, username: 'n1', password: 'geheim123');
    final end = DateTime.now().add(const Duration(seconds: 8));
    while (hs.loopSyncs.length < 2) {
      if (DateTime.now().isAfter(end)) fail('weniger als zwei Sync-Anfragen des SDK: ${hs.loopSyncs}');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(hs.loopSyncs.any((u) => u.queryParameters.containsKey('since')), isTrue, reason: 'eine Folgeanfrage ist dabei');
    for (final u in hs.loopSyncs) {
      expect(u.queryParameters['set_presence'], 'offline', reason: '$u');
    }
  });
}
