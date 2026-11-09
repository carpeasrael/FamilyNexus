import 'dart:async';
import 'dart:convert';

import 'package:family_nexus/data/matrix/local_identity_pins.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_stores.dart';

/// #142: Die lokale Kopie der Identitätsvermerke. Der Homeserver kann die Kontodaten ändern oder löschen, die Kopie
/// im verschlüsselten Speicher des Geräts nicht.
const String _me = '@anna:hs.test';
const String _ben = '@ben:hs.test';
const String _cara = '@cara:hs.test';
const String _key = LocalIdentityPins.storeKey;

String _entry(String owner, Map<String, String> pins) => json.encode(<String, Object?>{'user_id': owner, 'pins': pins});

Map<String, Object?> _stored(MemoryKeyValueStore kv) => json.decode(kv.data[_key]!) as Map<String, Object?>;

class _FlakyStore extends MemoryKeyValueStore {
  bool failReads = false;

  @override
  Future<Map<String, String>> readAll() {
    if (failReads) throw StateError('Lesefehler (Test)');
    return super.readAll();
  }
}

/// Schreiben, das erst beim Freigeben fertig wird (für Wettläufe).
class _SlowStore extends MemoryKeyValueStore {
  Completer<void>? gate;
  int writes = 0;

  @override
  Future<void> apply({Map<String, String> writes = const <String, String>{}, Iterable<String> deletes = const <String>[]}) async {
    if (writes.isNotEmpty) {
      this.writes++;
      await gate?.future;
    }
    return super.apply(writes: writes, deletes: deletes);
  }
}

void main() {
  test('ohne gespeicherten Eintrag: leer, nichts geschrieben, bis es etwas zu merken gibt', () async {
    final kv = MemoryKeyValueStore();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.pins, isEmpty);
    await p.flushIfDirty();
    expect(kv.data, isEmpty);
  });

  test('Übernehmen und Speichern; nach einem „Neustart“ liest eine neue Instanz den Stand', () async {
    final kv = MemoryKeyValueStore();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.adopt(_ben, 'KEY-B'), isTrue);
    await p.flushIfDirty();
    expect(_stored(kv), <String, Object?>{
      'user_id': _me,
      'pins': <String, String>{_ben: 'KEY-B'},
    });
    final neu = LocalIdentityPins(kv);
    await neu.load();
    neu.bind(_me);
    expect(neu.pins, <String, String>{_ben: 'KEY-B'});
  });

  test('adopt ersetzt nie einen vorhandenen Vermerk, accept schon', () async {
    final kv = MemoryKeyValueStore()..data[_key] = _entry(_me, <String, String>{_ben: 'ALT'});
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.adopt(_ben, 'SERVER-NEU'), isFalse);
    expect(p.pins[_ben], 'ALT');
    p.accept(_ben, 'NEU');
    expect(p.pins[_ben], 'NEU');
    await p.flushIfDirty();
    expect((_stored(kv)['pins']! as Map<String, Object?>)[_ben], 'NEU');
  });

  test('Eintrag eines anderen Kontos wird verworfen und beim Speichern ersetzt', () async {
    final kv = MemoryKeyValueStore()..data[_key] = _entry('@jemand:hs.test', <String, String>{_ben: 'FREMD'});
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.pins, isEmpty);
    expect(p.isDirty, isTrue);
    await p.flushIfDirty();
    expect(_stored(kv), <String, Object?>{'user_id': _me, 'pins': <String, String>{}});
  });

  test('#352 Kontowechsel im selben Prozess ohne forget verwirft die Vermerke des alten Kontos', () async {
    final kv = MemoryKeyValueStore();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.adopt(_ben, 'KEY-B'), isTrue);
    await p.flushIfDirty();
    p.bind('@jemand:hs.test');
    expect(p.pins, isEmpty);
    expect(p.isDirty, isTrue);
    await p.flushIfDirty();
    expect(_stored(kv), <String, Object?>{'user_id': '@jemand:hs.test', 'pins': <String, String>{}});
  });

  test('#352 erneutes bind mit demselben Konto behält die Vermerke', () async {
    final kv = MemoryKeyValueStore();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    p.adopt(_ben, 'KEY-B');
    p.bind(_me);
    expect(p.pins, <String, String>{_ben: 'KEY-B'});
  });

  test('Lesefehler: unzuverlässig, nichts übernommen, nichts überschrieben', () async {
    final kv = _FlakyStore()
      ..data[_key] = _entry(_me, <String, String>{_ben: 'ALT'})
      ..failReads = true;
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    expect(p.active, isFalse);
    expect(p.adopt(_cara, 'K'), isFalse);
    p.accept(_ben, 'NEU');
    await p.flushIfDirty();
    expect((_stored(kv)['pins']! as Map<String, Object?>)[_ben], 'ALT', reason: 'vorhandener Eintrag bleibt');
    expect(p.pins, isEmpty);
  });

  test('beschädigter Inhalt gilt als leer; der nächste Schreibvorgang ersetzt ihn', () async {
    for (final raw in <String>['{kaputt', '[]', '{"user_id": 3, "pins": {}}', '{"user_id": "@a:b", "pins": []}']) {
      final kv = MemoryKeyValueStore()..data[_key] = raw;
      final p = LocalIdentityPins(kv);
      await p.load();
      p.bind(_me);
      expect(p.pins, isEmpty, reason: raw);
      expect(p.adopt(_ben, 'KEY-B'), isTrue, reason: raw);
      await p.flushIfDirty();
      expect(_stored(kv)['pins'], <String, String>{_ben: 'KEY-B'}, reason: raw);
    }
  });

  test('ohne Ablage: inaktiv, kein Absturz, nichts vorgetäuscht', () async {
    final p = LocalIdentityPins(null);
    await p.load();
    p.bind(_me);
    expect(p.active, isFalse);
    expect(p.adopt(_ben, 'K'), isFalse);
    p.accept(_ben, 'K');
    await p.flushIfDirty();
    await p.forget();
    expect(p.pins, isEmpty);
  });

  test('load liest nur einmal: ein zweiter Aufruf überschreibt weder Stand noch Markierung', () async {
    final kv = MemoryKeyValueStore()..data[_key] = _entry(_me, <String, String>{_ben: 'A'});
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    p.accept(_cara, 'C');
    kv.data[_key] = _entry(_me, <String, String>{_ben: 'ANDERS'});
    await p.load();
    expect(p.pins, <String, String>{_ben: 'A', _cara: 'C'});
    expect(p.isDirty, isTrue);
  });

  test('Schreiben ist serialisiert; eine Änderung während des Schreibens wird nachgetragen (Schnappschuss beim Schreiben)', () async {
    final kv = _SlowStore()..gate = Completer<void>();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    p.adopt(_ben, 'B');
    final first = p.flushIfDirty();
    await Future<void>.delayed(Duration.zero);
    p.adopt(_cara, 'C');
    final second = p.flushIfDirty();
    expect(kv.writes, 1, reason: 'nie parallel');
    kv.gate!.complete();
    await Future.wait(<Future<void>>[first, second]);
    expect(kv.writes, 2, reason: 'die Änderung während des Schreibens wird nachgetragen');
    expect(_stored(kv)['pins'], <String, String>{_ben: 'B', _cara: 'C'});
    expect(p.isDirty, isFalse);
  });

  test('Schreibfehler: Markierung bleibt, der nächste Aufruf versucht es erneut; ohne Änderung kein Schreiben', () async {
    final kv = MemoryKeyValueStore()..failWrites = true;
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    p.adopt(_ben, 'B');
    await p.flushIfDirty();
    expect(p.isDirty, isTrue);
    expect(kv.data, isEmpty);
    kv.failWrites = false;
    await p.flushIfDirty();
    expect(p.isDirty, isFalse);
    expect(_stored(kv)['pins'], <String, String>{_ben: 'B'});
    kv.data.remove(_key);
    await p.flushIfDirty();
    expect(kv.data, isEmpty, reason: 'unverändert: nichts zu schreiben');
  });

  test('forget löscht auch ohne vorherigen Eintrag und versiegelt bis zur nächsten Bindung', () async {
    final kv = MemoryKeyValueStore();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    await p.forget();
    expect(kv.data, isEmpty);
    expect(p.adopt(_ben, 'B'), isFalse, reason: 'verspäteter Abgleich nach dem Abmelden legt nichts neu an');
    await p.flushIfDirty();
    expect(kv.data, isEmpty);
    p.bind(_me);
    expect(p.adopt(_ben, 'B'), isTrue, reason: 'die nächste Anmeldung entsiegelt');
  });

  test('forget wartet ein laufendes Schreiben ab und legt den Eintrag danach nicht neu an', () async {
    final kv = _SlowStore()..gate = Completer<void>();
    final p = LocalIdentityPins(kv);
    await p.load();
    p.bind(_me);
    p.adopt(_ben, 'B');
    final flush = p.flushIfDirty();
    await Future<void>.delayed(Duration.zero);
    final forget = p.forget();
    kv.gate!.complete();
    await Future.wait(<Future<void>>[flush, forget]);
    expect(kv.data.containsKey(_key), isFalse);
    expect(p.pins, isEmpty);
  });

  test('nach forget ist die Ablage wieder zuverlässig, auch nach einem früheren Lesefehler', () async {
    final kv = _FlakyStore()
      ..data[_key] = _entry(_me, <String, String>{_ben: 'ALT'})
      ..failReads = true;
    final p = LocalIdentityPins(kv);
    await p.load();
    await p.forget();
    expect(kv.data.containsKey(_key), isFalse);
    p.bind(_me);
    expect(p.adopt(_ben, 'NEU'), isTrue);
  });
}
