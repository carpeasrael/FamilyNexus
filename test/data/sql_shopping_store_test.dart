import 'dart:convert';

import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_shopping_store.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String _anna = '@anna:fake.test';
const String _id = '00000000-0000-4000-8000-000000000001';

ShoppingItem _item({String group = ''}) =>
    ShoppingItem(id: _id, title: 'Eier', group: group, by: _anna, updatedAt: DateTime.utc(2026, 11, 2, 12));

void main() {
  late SqlShoppingStore store;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlShoppingStore(db);
  });

  tearDown(() => db.close());

  test('#211 Rundreise: Die Gruppe übersteht die Datenbank', () async {
    await store.put(_item(group: 'Aldi'), publishedVersion: 0);
    expect((await store.get(_id))!.group, 'Aldi');
    expect((await store.all()).single.group, 'Aldi');
  });

  test('#211 Vorhandener Datensatz ohne grp bleibt lesbar', () async {
    await store.put(_item(), publishedVersion: 0);
    final row = (await db.query('shopping_items')).single;
    expect(json.decode(row['data']! as String), isNot(contains('grp')));
    expect((await store.get(_id))!.group, '');
  });
}
