import 'package:family_nexus/data/platform/vault_key_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Speicher im Arbeitsspeicher; das Passwort wird nur verglichen (die echte Verschlüsselung prüft
/// `tool/web_selftest.sh` im Browser).
class _FakeVault implements VaultBackend {
  String? _password;
  Map<String, String> _stored = <String, String>{};
  bool unlocked = false;
  int saves = 0;
  bool failNextSave = false;

  @override
  bool get exists => _password != null;

  @override
  Future<void> create(String password) async {
    _password = password;
    _stored = <String, String>{};
    unlocked = true;
  }

  @override
  Future<void> unlock(String password) async {
    if (password != _password) throw const WrongVaultPasswordException();
    unlocked = true;
  }

  @override
  Future<Map<String, String>> load() async {
    if (!unlocked) throw const WrongVaultPasswordException();
    return Map<String, String>.of(_stored);
  }

  @override
  Future<void> save(Map<String, String> entries) async {
    if (!unlocked) throw const WrongVaultPasswordException();
    if (failNextSave) {
      failNextSave = false;
      throw StateError('Speichern fehlgeschlagen');
    }
    saves++;
    await Future<void>.delayed(Duration.zero);
    _stored = Map<String, String>.of(entries);
  }

  @override
  Future<void> destroy() async {
    _password = null;
    _stored = <String, String>{};
    unlocked = false;
  }
}

void main() {
  test('Schlüssel werden einmal zufällig erzeugt und bleiben nach erneutem Entsperren gleich', () async {
    final vault = _FakeVault();
    await vault.create('geheimes-passwort');
    final keys = await VaultKeyStore.open(vault);
    expect(await keys.readKey('db.app'), isNull, reason: 'readKey erzeugt nichts');
    final first = await keys.getOrCreateKey('db.app');
    expect(first.length, greaterThanOrEqualTo(40));
    expect(await keys.getOrCreateKey('db.app'), first);

    final again = _FakeVault().._password = 'geheimes-passwort';
    again._stored = await vault.load();
    await again.unlock('geheimes-passwort');
    expect(await (await VaultKeyStore.open(again)).readKey('db.app'), first);
  });

  test('Parallele Aufrufe liefern denselben Schlüssel und verlieren keine Einträge', () async {
    final vault = _FakeVault();
    await vault.create('pw-pw-pw-pw-pw');
    final keys = await VaultKeyStore.open(vault);
    final results = await Future.wait(<Future<String>>[
      keys.getOrCreateKey('a'),
      keys.getOrCreateKey('a'),
      keys.getOrCreateKey('b'),
    ]);
    expect(results[0], results[1]);
    expect(results[2], isNot(results[0]));
    expect((await vault.load()).keys.toSet(), <String>{'a', 'b'});
  });

  test('Fehlgeschlagenes Speichern erzeugt keinen Schlüssel im Speicher und blockiert nichts', () async {
    final vault = _FakeVault();
    await vault.create('pw-pw-pw-pw-pw');
    final keys = await VaultKeyStore.open(vault);
    vault.failNextSave = true;
    await expectLater(keys.getOrCreateKey('x'), throwsStateError);
    expect(await keys.readKey('x'), isNull);
    expect(await keys.getOrCreateKey('x'), isNotEmpty, reason: 'nächster Versuch klappt');
  });

  test('deleteKey und deleteAll entfernen Schlüssel; deleteAll zerstört den Tresor', () async {
    final vault = _FakeVault();
    await vault.create('pw-pw-pw-pw-pw');
    final keys = await VaultKeyStore.open(vault);
    await keys.getOrCreateKey('a');
    await keys.getOrCreateKey('b');
    await keys.deleteKey('a');
    expect(await keys.readKey('a'), isNull);
    expect(await keys.readKey('b'), isNotNull);
    await keys.deleteAll();
    expect(vault.exists, isFalse);
    expect(await keys.readKey('b'), isNull);
  });

  test('Falsches Passwort entsperrt nicht', () async {
    final vault = _FakeVault();
    await vault.create('richtig-richtig');
    vault.unlocked = false;
    await expectLater(vault.unlock('falsch-falsch'), throwsA(isA<WrongVaultPasswordException>()));
    await expectLater(VaultKeyStore.open(vault), throwsA(isA<WrongVaultPasswordException>()));
  });

  test('Außerhalb des Browsers gibt es keinen Web-Tresor', () {
    expect(createWebVaultBackend(), isNull);
  });
}
