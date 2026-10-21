import 'package:family_nexus/data/platform/key_store.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/key_value_store.dart';

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = <String, String>{};
  bool failWrites = false;

  @override
  Future<Map<String, String>> readAll() async => Map<String, String>.of(data);

  @override
  Future<void> write(String key, String value) => apply(writes: <String, String>{key: value});

  @override
  Future<void> delete(String key) => apply(deletes: <String>[key]);

  @override
  Future<void> apply({
    Map<String, String> writes = const <String, String>{},
    Iterable<String> deletes = const <String>[],
  }) async {
    if (failWrites) throw StateError('Schreibfehler (Test)');
    data.addAll(writes);
    deletes.forEach(data.remove);
  }
}

class MemoryKeyStore implements KeyStore {
  final Map<String, String> keys = <String, String>{};

  @override
  Future<String?> readKey(String name) async => keys[name];

  @override
  Future<String> getOrCreateKey(String name) async => keys.putIfAbsent(name, generateKey);

  @override
  Future<void> deleteKey(String name) async => keys.remove(name);

  @override
  Future<void> deleteAll() async => keys.clear();
}

class NoopScreenProtection implements ScreenProtection {
  bool? last;

  @override
  Future<void> setSecure(bool secure) async => last = secure;
}
