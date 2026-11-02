import 'package:family_nexus/domain/shopping.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/memory_shopping_store.dart';

const String _anna = '@anna:example.org';
const String _ben = '@ben:example.org';
const String _id = '11111111-1111-4111-8111-111111111111';
final DateTime _t0 = DateTime.utc(2026, 10, 21, 12);

ShoppingItem _item({String id = _id, String title = 'Milch', String by = _anna, int version = 1, DateTime? at, bool checked = false, bool deleted = false, String quantity = '', String group = ''}) =>
    ShoppingItem(id: id, title: title, by: by, version: version, updatedAt: at ?? _t0, checked: checked, deleted: deleted, quantity: quantity, group: group);

void main() {
  group('ShoppingItem.validate', () {
    test('gültiger Eintrag', () => expect(_item().validate(), isEmpty));

    test('lehnt ungültige Felder ab', () {
      expect(_item(id: 'x').validate(), contains('id'));
      expect(_item(by: 'anna').validate(), contains('by'));
      expect(_item(version: 0).validate(), contains('version'));
      expect(_item(version: ShoppingItem.maxVersion + 1).validate(), contains('version'));
      expect(_item(title: '   ').validate(), contains('title'));
      expect(_item(title: 'a' * 101).validate(), contains('length'));
      expect(_item(quantity: 'b' * 31).validate(), contains('length'));
      expect(_item(title: 'Mi\u0000lch').validate(), contains('text'));
      expect(_item(title: 'Mi\u202Elch').validate(), contains('text'));
      expect(_item(quantity: '2\n').validate(), contains('text'));
      for (final bad in <String>['\u200B', '\u200E', '\u200F', '\u2060', '\uFEFF', '\u061C']) {
        expect(_item(title: 'a${bad}b').validate(), contains('text'), reason: bad.codeUnits.toString());
        expect(_item(quantity: '2$bad').validate(), contains('text'), reason: bad.codeUnits.toString());
      }
      expect(_item(at: DateTime(2026)).validate(), contains('time'), reason: 'nicht UTC');
      expect(_item(at: DateTime.utc(1999)).validate(), contains('time'));
    });

    test('#161: zusammengesetzte Emojis und ZWNJ sind erlaubt, ein Titel nur aus Verbindern nicht', () {
      expect(_item(title: '👨\u200D👩\u200D👧 Familienessen').validate(), isEmpty);
      expect(_item(title: 'می\u200Cخواهم', quantity: '2\u200D').validate(), isEmpty);
      expect(_item(title: '\u200D\u200C').validate(), contains('title'));
      expect(_item(title: ' \u200D ').validate(), contains('title'));
    });

    test('#161: Rundlauf des Codecs mit ZWJ-Titel', () {
      final i = _item(title: '👨\u200D👩\u200D👧 Eis', quantity: '2\u200C');
      expect(ShoppingCodec.decode(ShoppingCodec.encode(i), sender: _anna), i);
    });

    test('Löschmarken tragen keinen Inhalt', () {
      expect(_item(title: '', deleted: true).validate(), isEmpty);
      expect(_item(title: 'Milch', deleted: true).validate(), contains('tombstone'));
      expect(_item(title: '', deleted: true, checked: true).validate(), contains('tombstone'));
    });
  });

  group('ShoppingCodec', () {
    test('Hin- und Rückweg', () {
      final i = _item(quantity: '2 Liter', checked: true, version: 3);
      expect(ShoppingCodec.decode(ShoppingCodec.encode(i), sender: _anna), i);
    });

    test('„by“ muss dem Absender entsprechen', () {
      expect(ShoppingCodec.decode(ShoppingCodec.encode(_item()), sender: _ben), isNull);
    });

    test('verwirft Fremdformate und Grenzfälle', () {
      final ok = ShoppingCodec.encode(_item());
      Map<String, Object?> with_(String k, Object? v) => <String, Object?>{...ok, k: v};
      final bad = <Map<String, Object?>>[
        with_('v', 2),
        with_('id', 5),
        with_('version', '1'),
        with_('deleted', 'nein'),
        with_('title', 5),
        with_('qty', null),
        with_('checked', 1),
        with_('ts', 'heute'),
        with_('ts', -1),
        with_('ts', 99999999999999999),
        with_('title', 'x' * 500),
        with_('title', ''),
      ];
      for (final c in bad) {
        expect(ShoppingCodec.decode(c, sender: _anna), isNull, reason: '$c');
      }
      expect(() => ShoppingCodec.encode(_item(title: '')), throwsStateError);
    });
  });

  group('ShoppingMerge', () {
    test('höhere Version gewinnt, dann Zeit, dann Absender', () {
      final base = _item(version: 2);
      expect(ShoppingMerge.incomingWins(null, base), isTrue);
      expect(ShoppingMerge.incomingWins(base, _item(version: 3, title: 'A')), isTrue);
      expect(ShoppingMerge.incomingWins(base, _item(version: 1, title: 'A', at: _t0.add(const Duration(days: 1)))), isFalse);
      final later = _item(version: 2, title: 'B', at: _t0.add(const Duration(seconds: 1)));
      expect(ShoppingMerge.incomingWins(base, later), isTrue);
      expect(ShoppingMerge.incomingWins(later, base), isFalse);
      final byBen = _item(version: 2, title: 'C', by: _ben);
      expect(ShoppingMerge.incomingWins(base, byBen), isTrue);
      expect(ShoppingMerge.incomingWins(byBen, base), isFalse);
    });

    test('identische Fassung ersetzt nichts, völliger Gleichstand ist symmetrisch', () {
      expect(ShoppingMerge.incomingWins(_item(), _item()), isFalse);
      final a = _item(title: 'A');
      final b = _item(title: 'B');
      expect(ShoppingMerge.incomingWins(a, b) != ShoppingMerge.incomingWins(b, a), isTrue);
    });

    test('Reihenfolge der Zustellung ist egal (Konvergenz)', () {
      final versions = <ShoppingItem>[
        _item(version: 1),
        _item(version: 2, title: 'Milch 2', at: _t0.add(const Duration(seconds: 5))),
        _item(version: 2, title: 'Milch 3', by: _ben, at: _t0.add(const Duration(seconds: 5))),
        _item(version: 3, title: '', deleted: true, at: _t0.add(const Duration(seconds: 9))),
      ];
      ShoppingItem? fold(List<ShoppingItem> order) {
        ShoppingItem? cur;
        for (final i in order) {
          if (ShoppingMerge.incomingWins(cur, i)) cur = i;
        }
        return cur;
      }

      final expected = fold(versions);
      expect(expected!.deleted, isTrue);
      expect(fold(versions.reversed.toList()), expected);
      expect(fold(<ShoppingItem>[versions[2], versions[0], versions[3], versions[1]]), expected);
    });
  });

  group('ShoppingService', () {
    late MemoryShoppingStore store;
    late ShoppingService service;
    var n = 0;
    DateTime now = _t0;

    setUp(() {
      store = MemoryShoppingStore();
      n = 0;
      now = _t0;
      service = ShoppingService(
        store: store,
        myUserId: _anna,
        clock: () => now = now.add(const Duration(seconds: 1)),
        idGenerator: () => '00000000-0000-4000-8000-${(++n).toString().padLeft(12, '0')}',
      );
    });

    test('Anlegen normalisiert Leerraum und merkt den Eintrag zum Senden vor', () async {
      final i = await service.add('  Milch   fettarm ', quantity: ' 2  Liter ');
      expect(i.title, 'Milch fettarm');
      expect(i.quantity, '2 Liter');
      expect(i.by, _anna);
      expect(i.version, 1);
      expect((await store.pendingPublish()).single.id, i.id);
    });

    test('ungültige Eingaben werden abgelehnt', () async {
      await expectLater(service.add('   '), throwsA(isA<ShoppingException>().having((e) => e.error, 'error', ShoppingError.invalid)));
      await expectLater(service.add('x' * 101), throwsA(isA<ShoppingException>()));
      await expectLater(service.add('ok', quantity: 'q' * 31), throwsA(isA<ShoppingException>()));
    });

    test('Abhaken, Bearbeiten, Löschen erhöhen die Version und setzen den Bearbeiter', () async {
      final i = await service.add('Brot');
      await store.markPublished(i.id, 1);
      final c = await service.setChecked(i.id, true);
      expect((c.version, c.checked, c.by), (2, true, _anna));
      final e = await service.edit(i.id, title: 'Vollkornbrot', quantity: '1');
      expect((e.version, e.title, e.checked), (3, 'Vollkornbrot', true));
      await service.remove(i.id);
      final d = (await store.get(i.id))!;
      expect((d.version, d.deleted, d.title, d.checked), (4, true, '', false));
      expect(d.validate(), isEmpty);
      await expectLater(service.setChecked(i.id, true), throwsA(isA<ShoppingException>().having((e) => e.error, 'error', ShoppingError.notFound)));
      expect((await store.pendingPublish()).single.version, 4);
    });

    test('„Erledigte entfernen“ löscht nur abgehakte Einträge', () async {
      final a = await service.add('A');
      final b = await service.add('B');
      final c = await service.add('C');
      await service.setChecked(a.id, true);
      await service.setChecked(c.id, true);
      expect(await service.clearChecked(), 2);
      expect((await store.get(a.id))!.deleted, isTrue);
      expect((await store.get(b.id))!.deleted, isFalse);
      expect((await store.get(c.id))!.deleted, isTrue);
      expect((await store.get(a.id))!.version, 3);
      expect(await service.clearChecked(), 0);
    });

    test('Obergrenzen: aktive Einträge und Gesamtzahl', () async {
      for (var i = 0; i < ShoppingItem.maxActive; i++) {
        await store.put(_item(id: '00000000-0000-4000-8000-${(1000 + i).toString().padLeft(12, '0')}', title: 'x$i'), publishedVersion: 1);
      }
      await expectLater(service.add('zu viel'), throwsA(isA<ShoppingException>().having((e) => e.error, 'error', ShoppingError.limit)));
      // Eingehende neue Einträge über der Grenze werden verworfen, Aktualisierungen bekannter nicht.
      expect(await service.applyIncoming(_item(id: '00000000-0000-4000-8000-999999999999', title: 'fremd', by: _ben)), isFalse);
      final known = '00000000-0000-4000-8000-${1000.toString().padLeft(12, '0')}';
      expect(await service.applyIncoming(_item(id: known, title: 'neu', by: _ben, version: 2)), isTrue);
    });

    test('Eingehendes: neuer Eintrag, Aktualisierung, veraltet, Duplikat', () async {
      expect(await service.applyIncoming(_item(by: _ben, title: 'Äpfel')), isTrue);
      expect((await store.pendingPublish()), isEmpty, reason: 'Empfangenes wird nicht zurückgesendet');
      expect(await service.applyIncoming(_item(by: _ben, title: 'Äpfel')), isFalse);
      expect(await service.applyIncoming(_item(by: _ben, title: 'Birnen', version: 2)), isTrue);
      expect(await service.applyIncoming(_item(by: _ben, title: 'Alt', version: 1)), isFalse);
      expect((await store.get(_id))!.title, 'Birnen');
    });

    test('Löschmarken werden auch dann übernommen, wenn die aktive Grenze erreicht ist', () async {
      for (var i = 0; i < ShoppingItem.maxActive; i++) {
        await store.put(_item(id: '00000000-0000-4000-8000-${(1000 + i).toString().padLeft(12, '0')}', title: 'x$i'), publishedVersion: 1);
      }
      expect(await service.applyIncoming(_item(id: '00000000-0000-4000-8000-999999999999', title: '', deleted: true, by: _ben)), isTrue);
    });

    test('Löschmarken verstopfen die Liste nicht: bei voller Ablage werden alte veröffentlichte aufgeräumt', () async {
      for (var i = 0; i < ShoppingItem.maxTotal; i++) {
        await store.put(_item(id: '00000000-0000-4000-8000-${(5000 + i).toString().padLeft(12, '0')}', title: '', deleted: true, version: 2), publishedVersion: 2);
      }
      expect((await store.counts()).total, ShoppingItem.maxTotal);
      final i = await service.add('Neu trotz vieler Löschmarken');
      expect(i.title, 'Neu trotz vieler Löschmarken');
      final c = await store.counts();
      expect(c.active, 1);
      expect(c.total, lessThanOrEqualTo(ShoppingItem.keepTombstones + 1));
      // Ebenso beim Empfang.
      for (var k = 0; k < ShoppingItem.maxTotal; k++) {
        await store.put(_item(id: '00000000-0000-4000-8000-${(9000 + k).toString().padLeft(12, '0')}', title: '', deleted: true, version: 2), publishedVersion: 2);
      }
      expect(await service.applyIncoming(_item(id: '00000000-0000-4000-8000-0000000000bb', by: _ben, title: 'Von Ben')), isTrue);
    });

    test('unveröffentlichte Löschmarken werden nie aufgeräumt; eine volle Ablage lehnt dann neue ab', () async {
      for (var i = 0; i < ShoppingItem.maxTotal; i++) {
        await store.put(_item(id: '00000000-0000-4000-8000-${(5000 + i).toString().padLeft(12, '0')}', title: '', deleted: true, version: 2), publishedVersion: 0);
      }
      await expectLater(service.add('x'), throwsA(isA<ShoppingException>().having((e) => e.error, 'error', ShoppingError.limit)));
      expect((await store.counts()).total, ShoppingItem.maxTotal);
    });

    test('übertriebene Versionssprünge werden verworfen (kein „unveränderbar“ machen)', () async {
      expect(await service.applyIncoming(_item(by: _ben, version: ShoppingItem.maxVersion)), isFalse);
      expect(await service.applyIncoming(_item(by: _ben, version: ShoppingItem.maxFirstVersion + 1)), isFalse);
      expect(await service.applyIncoming(_item(by: _ben, version: 5)), isTrue);
      expect(await service.applyIncoming(_item(by: _ben, version: 5 + ShoppingItem.maxVersionJump + 1)), isFalse);
      expect(await service.applyIncoming(_item(by: _ben, version: 5 + ShoppingItem.maxVersionJump)), isTrue);
    });
  });

  group('Gruppen (#211)', () {
    Map<String, Object?> json(ShoppingItem i) => ShoppingCodec.encode(i);

    test('validate: Länge, gesperrte Zeichen, nur Leerraum, Löschmarke', () {
      expect(_item(group: 'Aldi').validate(), isEmpty);
      expect(_item(group: 'c' * 30).validate(), isEmpty);
      expect(_item(group: 'c' * 31).validate(), contains('length'));
      expect(_item(group: 'Al\u202Edi').validate(), contains('text'));
      expect(_item(group: 'Al\ndi').validate(), contains('text'));
      expect(_item(group: '   ').validate(), contains('group'));
      expect(_item(group: '‌‍').validate(), contains('group'));
      expect(_item(group: '👨‍👩').validate(), isEmpty, reason: 'ZWJ bleibt erlaubt');
      expect(_item(title: '', deleted: true, group: 'Aldi').validate(), contains('tombstone'));
    });

    test('Codec: Rundreise; ohne Gruppe entsteht kein Schlüssel, das Ereignis bleibt bytegleich', () {
      expect(json(_item(group: 'Aldi'))['grp'], 'Aldi');
      expect(ShoppingCodec.decode(json(_item(group: 'Aldi')), sender: _anna)!.group, 'Aldi');
      expect(json(_item()).containsKey('grp'), isFalse);
      expect(ShoppingCodec.decode(json(_item()), sender: _anna)!.group, '');
    });

    test('Codec: falscher Typ, Überlänge und gesperrte Zeichen werden abgelehnt', () {
      Map<String, Object?> withGrp(Object? g) => <String, Object?>{...json(_item()), 'grp': g};
      expect(ShoppingCodec.decode(withGrp(1), sender: _anna), isNull);
      expect(ShoppingCodec.decode(withGrp(null), sender: _anna), isNull);
      expect(ShoppingCodec.decode(withGrp('x' * 31), sender: _anna), isNull);
      expect(ShoppingCodec.decode(withGrp('x' * 100000), sender: _anna), isNull);
      expect(ShoppingCodec.decode(withGrp('a\u202Eb'), sender: _anna), isNull);
      expect(ShoppingCodec.decode(withGrp('a‍b'), sender: _anna)!.group, 'a‍b');
    });

    test('Merge: mit Gruppe gewinnt gegen ohne, in beiden Reihenfolgen', () {
      final plain = _item();
      final grouped = _item(group: 'Aldi');
      expect(ShoppingMerge.incomingWins(plain, grouped), isTrue);
      expect(ShoppingMerge.incomingWins(grouped, plain), isFalse);
      expect(ShoppingMerge.incomingWins(grouped, grouped), isFalse);
    });

    test('Merge: zwei verschiedene Gruppen ergeben in beiden Reihenfolgen dieselbe Fassung', () {
      final a = _item(group: 'Aldi');
      final b = _item(group: 'Rewe');
      expect(ShoppingMerge.incomingWins(a, b), isNot(ShoppingMerge.incomingWins(b, a)));
    });

    test('Merge: Titel und Menge entscheiden wie bisher vor der Gruppe', () {
      final a = _item(quantity: '2', group: 'Zoo');
      final b = _item(quantity: '2 Liter');
      expect(ShoppingMerge.incomingWins(a, b), isTrue, reason: 'alte Apps entscheiden genauso');
      expect(ShoppingMerge.incomingWins(b, a), isFalse);
    });

    test('Service: add normalisiert, edit mit null behält, mit Leertext entfernt die Gruppe', () async {
      final s = ShoppingService(store: MemoryShoppingStore(), myUserId: _anna, clock: () => _t0);
      final i = await s.add('Milch', group: '  Rewe   Süd ');
      expect(i.group, 'Rewe Süd');
      expect((await s.edit(i.id, title: 'Hafermilch')).group, 'Rewe Süd');
      expect((await s.edit(i.id, title: 'Hafermilch', group: 'Aldi')).group, 'Aldi');
      expect((await s.setChecked(i.id, true)).group, 'Aldi');
      expect((await s.edit(i.id, title: 'Hafermilch', group: '  ')).group, '');
    });

    test('Service: remove und clearChecked leeren die Gruppe', () async {
      final store = MemoryShoppingStore();
      final s = ShoppingService(store: store, myUserId: _anna, clock: () => _t0);
      final a = await s.add('Eier', group: 'Aldi');
      await s.remove(a.id);
      expect((await store.get(a.id))!.group, '');
      final b = await s.add('Mehl', group: 'Aldi');
      await s.setChecked(b.id, true);
      expect(await s.clearChecked(), 1);
      expect((await store.get(b.id))!.group, '');
    });

    test('Service: Gruppe nur aus Verbindern wird abgelehnt', () async {
      final s = ShoppingService(store: MemoryShoppingStore(), myUserId: _anna, clock: () => _t0);
      expect(s.add('Milch', group: '‍'), throwsA(isA<ShoppingException>()));
    });

    test('shoppingGroupKey: Leerraum, Schreibweise und Verbinder zählen nicht', () {
      expect(shoppingGroupKey('  ALDI   Süd '), 'aldi süd');
      expect(shoppingGroupKey('Al‍di'), shoppingGroupKey('Aldi'));
      expect(shoppingGroupKey(' ‌ '), '');
    });

    group('groupShoppingItems', () {
      ShoppingItem it(String title, String group) => _item(title: title, group: group);

      test('sortiert nach Schlüssel, ohne Gruppe zuletzt, Reihenfolge innerhalb bleibt', () {
        final g = groupShoppingItems(<ShoppingItem>[it('1', ''), it('2', 'rewe'), it('3', 'Aldi'), it('4', 'Rewe'), it('5', '')]);
        expect(g.map((e) => e.label), <String?>['Aldi', 'Rewe', null]);
        expect(g[1].items.map((e) => e.title), <String>['2', '4']);
        expect(g[2].items.map((e) => e.title), <String>['1', '5']);
      });

      test('Schreibweise hängt nicht von der Eingangsreihenfolge ab', () {
        final a = it('1', 'aldi');
        final b = it('2', 'ALDI');
        expect(groupShoppingItems(<ShoppingItem>[a, b]).single.label, 'ALDI');
        expect(groupShoppingItems(<ShoppingItem>[b, a]).single.label, 'ALDI');
      });

      test('ZWJ-Variante ist dieselbe Gruppe, Roh-Leerraum ergibt ein sauberes Label', () {
        expect(groupShoppingItems(<ShoppingItem>[it('1', 'Al‍di'), it('2', 'Aldi')]).length, 1);
        expect(groupShoppingItems(<ShoppingItem>[it('1', '  Al   di ')]).single.label, 'Al di');
      });

      test('leere Eingabe', () => expect(groupShoppingItems(const <ShoppingItem>[]), isEmpty));
    });

    group('groupSuggestions', () {
      const names = <String>['Aldi', 'Baumarkt', 'Rewe'];

      test('leerer Text zeigt alle', () {
        expect(groupSuggestions(names, ''), names);
        expect(groupSuggestions(names, '  '), names);
      });

      test('Teiltreffer filtert ohne Rücksicht auf die Schreibweise', () {
        expect(groupSuggestions(names, 'AR'), <String>['Baumarkt']);
        expect(groupSuggestions(names, 'xyz'), isEmpty);
      });

      test('genauer Treffer zeigt die übrigen, auch in anderer Schreibweise', () {
        expect(groupSuggestions(names, 'aldi'), <String>['Baumarkt', 'Rewe']);
      });
    });
  });
}
