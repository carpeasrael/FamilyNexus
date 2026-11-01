import 'package:family_nexus/data/db/app_database.dart';
import 'package:family_nexus/data/db/sql_event_store.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// #131: `putRsvp` meldet, ob die Zusage wirklich geschrieben wurde (nur dann lädt der Kalender neu).
void main() {
  late Database db;
  late SqlEventStore store;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(singleInstance: false));
    for (final m in AppDatabase.migrations) {
      await m(db);
    }
    store = SqlEventStore(db);
  });

  tearDown(() => db.close());

  test('true bei neuer und neuerer Zusage, false bei gleichem und älterem Zeitstempel', () async {
    final t = DateTime.utc(2026, 11, 1, 10);
    expect(await store.putRsvp('e1', '@ben:fake.test', RsvpStatus.accepted, t), isTrue);
    expect(await store.putRsvp('e1', '@ben:fake.test', RsvpStatus.declined, t), isFalse, reason: 'gleicher Zeitstempel');
    expect(await store.putRsvp('e1', '@ben:fake.test', RsvpStatus.declined, t.subtract(const Duration(seconds: 1))), isFalse,
        reason: 'älter');
    expect((await store.rsvps())['e1']!['@ben:fake.test'], RsvpStatus.accepted, reason: 'unverändert');
    expect(await store.putRsvp('e1', '@ben:fake.test', RsvpStatus.declined, t.add(const Duration(seconds: 1))), isTrue);
    expect((await store.rsvps())['e1']!['@ben:fake.test'], RsvpStatus.declined);
  });

  test('andere Personen und andere Termine sind unabhängig', () async {
    final t = DateTime.utc(2026, 11, 1, 10);
    expect(await store.putRsvp('e1', '@ben:fake.test', RsvpStatus.accepted, t), isTrue);
    expect(await store.putRsvp('e1', '@cara:fake.test', RsvpStatus.accepted, t), isTrue);
    expect(await store.putRsvp('e2', '@ben:fake.test', RsvpStatus.accepted, t), isTrue);
  });
}
