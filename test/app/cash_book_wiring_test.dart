import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/fake_matrix.dart';
import '../support/memory_cash_book_store.dart';
import '../support/memory_event_store.dart';

/// #311, E-113 (Teil 2c): Verdrahtung des Kassenbuch-Syncs in `buildCalendarController`. Die Sperre gilt auch hier.
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gateway;
  late MemoryCashBookStore store;
  late String roomId;

  setUp(() async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    gateway = server.newDevice();
    await gateway.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gateway.createFamily('Familie');
    roomId = gateway.familyRoom!.id;
    store = MemoryCashBookStore();
  });

  CalendarController build({MemoryCashBookStore? cash, String? room, bool? enabled}) {
    return buildCalendarController(
      store: MemoryEventStore(),
      gateway: gateway,
      userId: gateway.userId!,
      zoneName: 'UTC',
      retryInterval: const Duration(hours: 1),
      familyRoom: room,
      cashBookStore: cash,
      cashBooksEnabled: enabled ?? CashBookFlags.enabled,
    );
  }

  test('ohne Ablage oder ohne Familie entstehen weder Dienst noch Sync', () {
    final noStore = build(room: roomId);
    final noRoom = build(cash: store);
    for (final c in <CalendarController>[noStore, noRoom]) {
      expect(c.cashBooks, isNull);
      expect(c.cashBookSync, isNull);
    }
  });

  test('Standard: gesperrt; Start, Senden und Schließen greifen nie auf Gateway oder Ablage zu', () async {
    final c = build(cash: store, room: roomId);
    expect(c.cashBookSync, isNotNull);
    expect(c.cashBookSync!.enabled, isFalse);
    gateway.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: kBookRoom, creatorId: kBookOwner)];
    await store.putBook(bookMeta(owner: gateway.userId!), published: false);
    gateway.bookCalls = 0;
    c.start(familyRoom: roomId);
    await c.cashBookSync!.publishPending();
    await c.idle();
    c.dispose();
    expect(gateway.bookCalls, 0);
    expect(gateway.bookPublished, isEmpty);
    expect((await store.pendingBooks(gateway.userId!)), hasLength(1));
  });

  test('freigeschaltet: der Sync läuft, sendet die Metadaten und endet mit dem Controller', () async {
    final c = build(cash: store, room: roomId, enabled: true);
    expect(c.cashBookSync!.enabled, isTrue);
    expect(c.cashBooks!.myUserId, gateway.userId);
    gateway.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: kBookRoom, creatorId: gateway.userId!)];
    await store.putBook(bookMeta(owner: gateway.userId!), published: false);
    c.start(familyRoom: roomId);
    await c.cashBookSync!.publishPending();
    expect(gateway.bookPublished.single.events.single.type, CashBookCodec.metaType);
    c.dispose();
  });
}
