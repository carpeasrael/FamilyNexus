import 'package:family_nexus/domain/cash_book.dart';

const String kBookRoom = '!buch:fake.test';
const String kBookOwner = '@anna:fake.test';
const String kBookMember = '@cara:fake.test';
const String kEntryId1 = '11111111-1111-4111-8111-111111111111';
const String kEntryId2 = '22222222-2222-4222-8222-222222222222';
const String kHash = 'a3f5c0de9b1d4e7f8a6b2c1d0e9f8a7b6c5d4e3f2a1b0c9d8e7f6a5b4c3d2e1f';

CashBookMeta bookMeta({String room = kBookRoom, String title = 'Haushalt', String currency = 'EUR', String owner = kBookOwner, int version = 1}) =>
    CashBookMeta(roomId: room, title: title, currency: currency, owner: owner, version: version);

CashEntry cashEntry({
  String id = kEntryId1,
  String author = kBookOwner,
  int version = 1,
  bool deleted = false,
  DateTime? date,
  String store = 'Edeka',
  int cents = 1250,
  String note = '',
  CashReceipt? receipt,
  DateTime? updatedAt,
}) =>
    CashEntry(
      id: id,
      author: author,
      version: version,
      deleted: deleted,
      date: date ?? DateTime.utc(2026, 11, 20),
      store: store,
      amountCents: cents,
      note: note,
      receipt: receipt,
      updatedAt: updatedAt ?? DateTime.utc(2026, 11, 20, 12),
    );
