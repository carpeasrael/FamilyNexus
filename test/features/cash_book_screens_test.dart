import 'dart:async';
import 'dart:typed_data';

import 'package:family_nexus/app/app_scope.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/data/sync/cash_book_receipts.dart';
import 'package:family_nexus/data/sync/cash_book_sync.dart';
import 'package:family_nexus/domain/book_policy.dart';
import 'package:family_nexus/domain/cash_book.dart';
import 'package:family_nexus/domain/cash_book_service.dart';
import 'package:family_nexus/domain/cash_month.dart';
import 'package:family_nexus/domain/cash_receipt_check.dart';
import 'package:family_nexus/domain/receipt_preview.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/cashbook/cash_book_controller.dart';
import 'package:family_nexus/features/cashbook/cash_book_entry_points.dart';
import 'package:family_nexus/features/cashbook/cash_book_members_screen.dart';
import 'package:family_nexus/features/cashbook/cash_book_screen.dart';
import 'package:family_nexus/features/cashbook/cash_books_screen.dart';
import 'package:family_nexus/features/cashbook/cash_entry_detail_screen.dart';
import 'package:family_nexus/features/cashbook/cash_entry_editor_screen.dart';
import 'package:family_nexus/features/settings/settings_screen.dart';
import 'package:family_nexus/features/today/today_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/cash_books.dart';
import '../support/fake_matrix.dart';
import '../support/memory_cash_book_store.dart';
import '../support/test_app.dart';

const String _cara = '@cara:fake.test';
const String _ben = '@ben:fake.test';

/// #311, E-113 (Teil 4a-2): Bildschirme des Kassenbuchs gegen Fake-Gateway und Memory-Ablage. Foto-Aufbereitung und
/// Dekodierung sind injiziert (kein Isolate, keine Datei).
void main() {
  late FakeMatrixServer server;
  late FakeMatrixGateway gw;
  late MemoryCashBookStore store;
  late CashBookService service;
  late CashBookReceipts receipts;
  late CashBookSync sync;
  late CashBookController c;
  late FakeFileAccess files;
  late String me;
  var previews = 0;
  Completer<void>? prepareGate;
  final jpeg = Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4, 5, 6]);
  final today = DateTime.utc(2026, 11, 22);
  const room = kBookRoom;

  Future<void> build({bool enabled = true, bool moderator = true}) async {
    server = FakeMatrixServer();
    server.addAccount('anna', 'pw1', displayName: 'Anna');
    server.addAccount('cara', 'pw2', displayName: 'Cara');
    server.addAccount('ben', 'pw3', displayName: 'Ben');
    gw = server.newDevice();
    await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'anna', password: 'pw1');
    await gw.createFamily('Familie');
    final fr = gw.familyRoom!;
    server.addMember(fr, _cara, power: 50);
    server.addMember(fr, _ben);
    if (!moderator) {
      gw = server.newDevice();
      await gw.login(server: ServerUrl.tryParse(server.host)!, username: 'ben', password: 'pw3');
      gw.attachFamilyRoom(fr.id);
    }
    me = gw.userId!;
    store = MemoryCashBookStore();
    service = CashBookService(store: store, myUserId: me, clock: () => DateTime.utc(2026, 11, 22, 12));
    receipts = CashBookReceipts(gateway: gw, service: service, store: store, enabled: enabled);
    sync = CashBookSync(gateway: gw, service: service, store: store, familyRoom: fr.id, enabled: enabled, receipts: receipts, retryInterval: const Duration(hours: 1));
    files = FakeFileAccess();
    previews = 0;
    prepareGate = null;
    c = CashBookController(
      gateway: gw,
      service: service,
      store: store,
      sync: sync,
      receipts: receipts,
      enabled: enabled,
      today: () => today,
      files: files,
      prepareReceipt: (b) async {
        await prepareGate?.future;
        return jpeg;
      },
      decodePreview: (b) async {
        previews++;
        return ReceiptPreview(width: 2, height: 2, rgba: Uint8List.fromList(List<int>.filled(16, 200)));
      },
    );
    gw.nextBookRoom = room;
    gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me)];
    await store.putBook(bookMeta(room: room, owner: me, title: 'Haushalt'));
  }

  CashEntry own({String id = kEntryId1, int cents = 1250, String storeName = 'Edeka', DateTime? date, CashReceipt? receipt}) =>
      cashEntry(id: id, author: me, cents: cents, store: storeName, date: date ?? DateTime.utc(2026, 11, 20), receipt: receipt);

  Widget host(Widget child, {String lang = 'de', double textScale = 1}) => MaterialApp(
        locale: Locale(lang),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: buildTheme(Brightness.light),
        builder: (context, app) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: app!),
        home: child,
      );

  Future<void> show(WidgetTester tester, Widget screen, {String lang = 'de', double textScale = 1}) async {
    c.start();
    await tester.pumpWidget(host(screen, lang: lang, textScale: textScale));
    await tester.pumpAndSettle();
  }

  /// Der Bildschirm liegt **über** einer Startseite (wie in der App), damit Zurück und Schließen möglich sind.
  Future<void> showPushed(WidgetTester tester, Widget Function() screen, {String lang = 'de'}) async {
    c.start();
    await tester.pumpWidget(host(Builder(builder: (context) => TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen())), child: const Text('auf'))), lang: lang));
    await tester.tap(find.text('auf'));
    await tester.pumpAndSettle();
  }

  /// Wie [show], aber ohne `pumpAndSettle`: Das Bild des Bons entsteht im Motor und braucht echte Zeit.
  Future<void> showReal(WidgetTester tester, Widget screen) async {
    c.start();
    await tester.pumpWidget(host(screen));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Jeder Test baut seine Objekte **im Test** auf (nicht in `setUp`): Sonst liegen ihre Futures in der echten Zone und
  /// laufen im Widget-Test nie weiter.
  void ui(String name, Future<void> Function(WidgetTester tester) body) => testWidgets(name, (tester) async {
        await build();
        await body(tester);
      });

  tearDown(() {
    c.dispose();
    sync.dispose();
    receipts.dispose();
  });

  ui('Bücherliste: leer, dann mit Büchern, Summen und Kennzeichnungen', (tester) async {
    await store.deleteBook(room);
    await show(tester, CashBooksScreen(controller: c));
    expect(find.text('Noch kein Kassenbuch. Lege eines an oder warte auf eine Einladung.'), findsOneWidget);
    await store.putBook(bookMeta(room: room, owner: me, title: 'Haushalt'));
    await store.setComplete(room, true);
    await store.putEntry(room, own(), publishedVersion: 1);
    await c.load();
    await tester.pumpAndSettle();
    expect(find.text('Haushalt'), findsOneWidget);
    expect(find.text('12,50 €'), findsOneWidget);
    expect(find.text('Von dir'), findsOneWidget);
    expect(find.text('Verlauf unvollständig – Summen unter Vorbehalt'), findsNothing);
  });

  ui('unvollständiger Verlauf, Sendeschutz und Platzhalter werden in der Liste und im Buch angezeigt', (tester) async {
    await store.putBook(bookMeta(room: room, owner: _cara, title: 'Kassenbuch', version: 0));
    gw.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: room, creatorId: _cara)];
    sync.blockedRooms.add(room);
    await store.putEntry(room, own(), publishedVersion: 0);
    await show(tester, CashBooksScreen(controller: c));
    expect(find.text('Verlauf unvollständig – Summen unter Vorbehalt'), findsOneWidget);
    expect(find.textContaining('Im Buch ist jemand, der nicht berechtigt ist'), findsOneWidget);
    expect(find.text('Der Name dieses Buchs ist noch nicht bekannt.'), findsOneWidget);
    expect(find.text('Von Cara'), findsOneWidget);
    await tester.tap(find.text('Kassenbuch').first);
    await tester.pumpAndSettle();
    expect(find.text('1 Eintrag noch nicht gesendet'), findsOneWidget);
    expect(find.textContaining('Im Buch ist jemand, der nicht berechtigt ist'), findsOneWidget);
  });

  ui('Einladung: Annehmen verlangt die Bestätigung des Hinweises; Abbrechen nimmt nichts an; erst Bestätigen tritt bei', (tester) async {
    gw.fakeInvitations = <BookInvitationInfo>[const BookInvitationInfo(roomId: '!einl:fake.test', inviterId: _cara, inviterName: 'Cara')];
    await show(tester, CashBooksScreen(controller: c));
    expect(find.text('Einladung zum Kassenbuch von Cara'), findsOneWidget);
    expect(gw.acceptedBooks, isEmpty, reason: 'nie automatisch');
    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alle Mitglieder des Buchs sehen alle Einträge und Bons'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(gw.acceptedBooks, isEmpty);
    await tester.tap(find.text('Annehmen'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Annehmen')));
    await tester.pumpAndSettle();
    expect(gw.acceptedBooks, <String>['!einl:fake.test']);
  });

  ui('Einladung ablehnen geht ohne Hinweis und ruft nur das Ablehnen auf', (tester) async {
    gw.fakeInvitations = <BookInvitationInfo>[const BookInvitationInfo(roomId: '!einl:fake.test', inviterId: _cara, inviterName: 'Cara')];
    await show(tester, CashBooksScreen(controller: c));
    await tester.tap(find.text('Ablehnen'));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    expect(gw.declinedBooks, <String>['!einl:fake.test']);
    expect(gw.acceptedBooks, isEmpty);
  });

  ui('Neues Buch: leerer Name wird abgefangen, dann angelegt (Meta lokal, ungesendet)', (tester) async {
    await store.deleteBook(room);
    gw.nextBookRoom = '!neu:fake.test';
    gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: '!neu:fake.test', creatorId: me)];
    await show(tester, CashBooksScreen(controller: c));
    await tester.tap(find.byTooltip('Neues Kassenbuch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte die Eingaben prüfen.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Urlaub');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    final meta = (await store.getBook('!neu:fake.test'))!;
    expect((meta.title, meta.currency, meta.owner), ('Urlaub', 'EUR', me));
    expect(
      (await store.pendingBooks(me)).map((b) => b.roomId).contains('!neu:fake.test') || gw.bookPublished.any((p) => p.events.any((e) => e.type == CashBookCodec.metaType)),
      isTrue,
      reason: 'die Metadaten warten auf das Senden oder wurden vom angestoßenen Sync schon gesendet',
    );
  });

  ui('Buch: Monatswahl ändert Summe und Liste; fremder Eintrag öffnet nur die Ansicht, eigener den Editor', (tester) async {
    await store.putEntry(room, own(cents: 1000), publishedVersion: 1);
    await store.putEntry(room, own(id: kEntryId2, cents: 500, storeName: 'Rewe', date: DateTime.utc(2026, 10, 15)), publishedVersion: 1);
    await store.putEntry(room, cashEntry(id: '33333333-3333-4333-8333-333333333333', author: _cara, store: 'Aldi', cents: 300, date: DateTime.utc(2026, 11, 2)), publishedVersion: 1);
    await show(tester, CashBookScreen(controller: c, roomId: room));
    expect(find.text('Summe: 13,00 €'), findsOneWidget);
    expect(find.text('Edeka'), findsOneWidget);
    expect(find.text('Aldi'), findsOneWidget);
    expect(find.text('Rewe'), findsNothing);
    await tester.tap(find.byTooltip('Vorheriger Monat'));
    await tester.pumpAndSettle();
    expect(find.text('Summe: 5,00 €'), findsOneWidget);
    expect(find.text('Rewe'), findsOneWidget);
    await tester.tap(find.byTooltip('Nächster Monat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aldi'));
    await tester.pumpAndSettle();
    expect(find.byType(CashEntryDetailScreen), findsOneWidget);
    expect(find.text('Eintrag bearbeiten'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edeka'));
    await tester.pumpAndSettle();
    expect(find.byType(CashEntryEditorScreen), findsOneWidget);
  });

  ui('Buch: leerer Monat, Verlassen für Nicht-Ersteller mit Bestätigung, für den Ersteller kein Menü', (tester) async {
    await show(tester, CashBookScreen(controller: c, roomId: room));
    expect(find.text('Keine Einträge in diesem Monat.'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing, reason: 'der Ersteller kann nicht verlassen');
    c.dispose();
    await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara, title: 'Urlaub'));
    gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
    await build();
    await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara, title: 'Urlaub'));
    gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
    await show(tester, CashBookScreen(controller: c, roomId: '!zwei:fake.test'));
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buch verlassen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ungesendete Einträge gehen verloren'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(gw.leftBooks, isEmpty);
  });

  ui('Buch verschwindet (Familienwechsel): Hinweis statt Absturz', (tester) async {
    await show(tester, CashBookScreen(controller: c, roomId: room));
    gw.fakeBooks = const <BookRoomInfo>[];
    await c.load();
    await tester.pumpAndSettle();
    expect(find.text('Das Kassenbuch ist nicht mehr verfügbar.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Editor', () {
    ui('Pflichtfelder: Geschäft und Betrag werden geprüft, nichts gespeichert', (tester) async {
      await show(tester, CashEntryEditorScreen(controller: c, roomId: room));
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte ein Geschäft eingeben.'), findsOneWidget);
      expect(find.textContaining('Bitte einen Betrag größer als 0'), findsOneWidget);
      expect(await store.entries(room), isEmpty);
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag'), 'abc');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bitte einen Betrag größer als 0'), findsOneWidget);
      expect(await store.entries(room), isEmpty);
    });

    ui('Speichern: deutscher Betrag „12,50“ wird zu 1250 Cent; Englisch „12.50“ ebenso', (tester) async {
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room));
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag'), '12,50');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect((await store.entries(room)).single.amountCents, 1250);
      c.dispose();
      await store.wipe();
      await build();
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room), lang: 'en');
      await tester.enterText(find.widgetWithText(TextField, 'Store'), 'Edeka');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '12.50');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await store.entries(room)).single.amountCents, 1250);
    });

    ui('Foto: erst der Datenschutz-Hinweis (Abbrechen wählt nichts), dann Auswahl, Speichern sendet zuerst die Datei', (tester) async {
      files.nextImage = PickedFile(name: 'bon.jpg', bytes: jpeg);
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room));
      await tester.tap(find.text('Foto hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Bons können Karten- oder Personendaten zeigen'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(files.imagePicks, 0);
      await tester.tap(find.text('Foto hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto wählen'));
      await tester.pumpAndSettle();
      expect(files.imagePicks, 1);
      expect(find.text('Bon angehängt'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag'), '5');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(gw.sentReceipts.single.bytes, jpeg);
      expect((await store.entries(room)).single.receipt, isNotNull);
    });

    ui('Foto zu groß: Fehlertext, nichts angehängt', (tester) async {
      files.imageTooLarge = true;
      await show(tester, CashEntryEditorScreen(controller: c, roomId: room));
      await tester.tap(find.text('Foto hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto wählen'));
      await tester.pumpAndSettle();
      expect(find.text('Die Datei ist zu groß (höchstens 15 MiB).'), findsOneWidget);
      expect(find.text('Bon angehängt'), findsNothing);
    });

    ui('Speichern ist gesperrt, solange die Aufbereitung läuft (kein Doppelspeichern)', (tester) async {
      prepareGate = Completer<void>();
      files.nextImage = PickedFile(name: 'bon.jpg', bytes: jpeg);
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room));
      await tester.tap(find.text('Foto hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto wählen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag'), '5');
      await tester.tap(find.text('Speichern'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Foto wird vorbereitet …'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern'));
      expect(button.onPressed, isNull);
      prepareGate!.complete();
      await tester.pumpAndSettle();
      expect((await store.entries(room)), hasLength(1));
    });

    ui('Zurück mit Änderungen fragt nach (nichts geht still verloren); Weiter bearbeiten bleibt, Verwerfen geht', (tester) async {
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room));
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      await tester.pump(); // erst nach dem Bild kennt die Seite ihre ungespeicherten Änderungen
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Änderungen verwerfen?'), findsOneWidget);
      await tester.tap(find.text('Weiter bearbeiten'));
      await tester.pumpAndSettle();
      expect(find.byType(CashEntryEditorScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Verwerfen'));
      await tester.pumpAndSettle();
      expect(find.byType(CashEntryEditorScreen), findsNothing);
    });

    ui('Zurück ohne Änderungen: kein Dialog', (tester) async {
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Änderungen verwerfen?'), findsNothing);
      expect(find.byType(CashEntryEditorScreen), findsNothing);
    });

    ui('Löschen: Bestätigung mit ehrlichem Text, dann Löschmarke', (tester) async {
      await store.putEntry(room, own(), publishedVersion: 1);
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room, entry: own()));
      expect(find.text('12,50'), findsOneWidget, reason: 'Betrag im Gebietsschema, ohne Tausendertrenner');
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('sobald ihr Gerät ihn empfängt'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect((await store.getEntry(room, me, kEntryId1))!.deleted, isFalse);
      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Löschen')));
      await tester.pumpAndSettle();
      expect((await store.getEntry(room, me, kEntryId1))!.deleted, isTrue);
    });

    ui('verschwindet das Buch während der Eingabe: Hinweis, Speichern gesperrt, der Entwurf bleibt', (tester) async {
      await show(tester, CashEntryEditorScreen(controller: c, roomId: room));
      await tester.enterText(find.widgetWithText(TextField, 'Geschäft'), 'Edeka');
      gw.fakeBooks = const <BookRoomInfo>[];
      await c.load();
      await tester.pumpAndSettle();
      expect(find.text('Das Kassenbuch ist nicht mehr verfügbar.'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Speichern')).onPressed, isNull);
      expect(find.text('Edeka'), findsOneWidget, reason: 'der Entwurf bleibt sichtbar');
    });

    ui('Eintrag mit Bon: ändern ohne Foto-Änderung lässt den Bon; „Foto entfernen“ entfernt ihn', (tester) async {
      c.start();
      final e = await c.addEntry(room, date: today, store: 'Edeka', amountCents: 100, photo: jpeg);
      gw.loadReceiptHandler = (r, ev, rc, a) => const BookReceiptLoad(BookReceiptStatus.missing);
      await showPushed(tester, () => CashEntryEditorScreen(controller: c, roomId: room, entry: e));
      await tester.tap(find.text('Foto entfernen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect((await store.getEntry(room, me, e.id))!.receipt, isNull);
    });
  });

  group('Bon im Detail', () {
    Future<CashEntry> foreignWithReceipt() async {
      final e = cashEntry(id: kEntryId2, author: _cara, store: 'Aldi').copyWith(receipt: const CashReceipt(eventId: r'$bon', sha256: kHash, size: 10));
      await store.putEntry(room, e, publishedVersion: 1);
      return e;
    }

    ui('ok: das Bild wird aus Rohpixeln gezeichnet (RawImage), nie Image.memory', (tester) async {
      final e = await foreignWithReceipt();
      gw.loadReceiptHandler = (r, ev, rc, a) => BookReceiptLoad(BookReceiptStatus.ok, jpeg);
      await showReal(tester, CashEntryDetailScreen(controller: c, roomId: room, entry: e));
      expect(find.byType(RawImage), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(previews, 1);
    });

    ui('missing, invalid, unavailable: Platzhalter ohne Bild und ohne Dekodierung; unavailable mit „Erneut versuchen“', (tester) async {
      final e = await foreignWithReceipt();
      final texts = <BookReceiptStatus, String>{
        BookReceiptStatus.missing: 'Bon nicht verfügbar',
        BookReceiptStatus.invalid: 'Bon konnte nicht geprüft werden',
        BookReceiptStatus.unavailable: 'Bon momentan nicht abrufbar',
      };
      for (final s in texts.keys) {
        gw.loadReceiptHandler = (r, ev, rc, a) => BookReceiptLoad(s, jpeg);
        await tester.pumpWidget(const SizedBox());
        await show(tester, CashEntryDetailScreen(controller: c, roomId: room, entry: e));
        expect(find.text(texts[s]!), findsOneWidget, reason: s.name);
        expect(find.byType(RawImage), findsNothing);
        expect(find.text('Erneut versuchen'), s == BookReceiptStatus.unavailable ? findsOneWidget : findsNothing);
      }
      expect(previews, 0);
    });

    ui('„Erneut versuchen“ lädt neu', (tester) async {
      final e = await foreignWithReceipt();
      var calls = 0;
      gw.loadReceiptHandler = (r, ev, rc, a) {
        calls++;
        return BookReceiptLoad(calls == 1 ? BookReceiptStatus.unavailable : BookReceiptStatus.invalid);
      };
      await show(tester, CashEntryDetailScreen(controller: c, roomId: room, entry: e));
      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Bon konnte nicht geprüft werden'), findsOneWidget);
    });
  });

  group('Mitglieder', () {
    ui('Ersteller: Mitglieder mit Namen; Einladen verlangt den Hinweis (Abbrechen lädt nicht ein); Entfernen mit Bestätigung', (tester) async {
      gw.bookMemberList[room] = <BookMember>[BookMember(me, BookMembership.joined), const BookMember(_ben, BookMembership.invited)];
      await show(tester, CashBookMembersScreen(controller: c, roomId: room));
      expect(find.text('Anna'), findsOneWidget);
      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('Ersteller · Beigetreten'), findsOneWidget);
      expect(find.text('Eingeladen'), findsOneWidget);
      expect(find.textContaining('Als Ersteller kannst du das Buch nicht verlassen'), findsOneWidget);
      await tester.tap(find.text('Mitglied einladen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cara'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Alle Mitglieder des Buchs sehen alle Einträge und Bons'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(gw.invitedToBook, isEmpty);
      await tester.tap(find.text('Mitglied einladen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cara'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einladen'));
      await tester.pumpAndSettle();
      expect(gw.invitedToBook, <(String, String)>[(room, _cara)]);
      await tester.tap(find.text('Entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('Ben aus dem Buch entfernen?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Entfernen')));
      await tester.pumpAndSettle();
      expect(gw.removedFromBook, <(String, String)>[(room, _ben)]);
    });

    ui('Nicht-Ersteller: kein Einladen, kein Entfernen', (tester) async {
      await store.putBook(bookMeta(room: '!zwei:fake.test', owner: _cara, title: 'Urlaub'));
      gw.fakeBooks = <BookRoomInfo>[const BookRoomInfo(roomId: '!zwei:fake.test', creatorId: _cara)];
      gw.bookMemberList['!zwei:fake.test'] = <BookMember>[const BookMember(_cara, BookMembership.joined), BookMember(me, BookMembership.joined)];
      await show(tester, CashBookMembersScreen(controller: c, roomId: '!zwei:fake.test'));
      expect(find.text('Mitglied einladen'), findsNothing);
      expect(find.text('Entfernen'), findsNothing);
    });

    ui('Mitgliederliste nicht abrufbar: Fehlertext statt leerer Liste', (tester) async {
      gw.bookMembersError = const GatewayException(GatewayError.serverUnreachable);
      await show(tester, CashBookMembersScreen(controller: c, roomId: room));
      expect(find.byType(Text), findsWidgets);
      expect(find.text('Mitglied einladen'), findsNothing);
    });
  });

  group('Einstiege und Sperre', () {
    ui('Karte „Heute“: je Buch die Monatssumme in der Währung des Buchs; mit „Öffnen“ in die Liste', (tester) async {
      await store.putEntry(room, own(cents: 1250), publishedVersion: 1);
      await store.putBook(bookMeta(room: '!usd:fake.test', owner: _cara, title: 'Reise', currency: 'USD'));
      await store.putEntry('!usd:fake.test', cashEntry(id: kEntryId2, author: _cara, cents: 500, date: DateTime.utc(2026, 11, 2)), publishedVersion: 1);
      gw.fakeBooks = <BookRoomInfo>[BookRoomInfo(roomId: room, creatorId: me), const BookRoomInfo(roomId: '!usd:fake.test', creatorId: _cara)];
      c.start();
      await tester.pumpWidget(host(Scaffold(body: SingleChildScrollView(child: CashBookTodayCard(controller: c)))));
      await tester.pumpAndSettle();
      expect(find.text('Haushalt: 12,50 € in diesem Monat'), findsOneWidget);
      expect(find.text('Reise: 5,00 \$ in diesem Monat'), findsOneWidget, reason: 'Summen nie über Währungen addiert');
      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.byType(CashBooksScreen), findsOneWidget);
    });

    ui('gesperrt oder Nicht-Moderator: weder Karte noch Einstellungseintrag', (tester) async {
      for (final locked in <bool>[true, false]) {
        c.dispose();
        await build(enabled: !locked, moderator: locked);
        c.start();
        await tester.pumpWidget(host(Scaffold(body: Column(children: <Widget>[CashBookTodayCard(controller: c), CashBookSettingsTile(controller: c)]))));
        await tester.pumpAndSettle();
        expect(find.text('Kassenbuch'), findsNothing, reason: locked ? 'gesperrt' : 'Nicht-Moderator');
        expect(find.byType(ListTile), findsNothing);
      }
    });

    ui('Einstellungseintrag öffnet die Liste', (tester) async {
      c.start();
      await tester.pumpWidget(host(Scaffold(body: CashBookSettingsTile(controller: c))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kassenbuch'));
      await tester.pumpAndSettle();
      expect(find.byType(CashBooksScreen), findsOneWidget);
    });

    ui('Liste bei gesperrtem Kassenbuch: Hinweis statt Bücher, kein „Neues Buch“, keine Gateway-Aufrufe', (tester) async {
      c.dispose();
      await build(enabled: false);
      gw.bookCalls = 0;
      await show(tester, CashBooksScreen(controller: c));
      expect(find.text('Das Kassenbuch ist nicht mehr verfügbar.'), findsOneWidget);
      expect(find.byTooltip('Neues Kassenbuch'), findsNothing);
      expect(gw.bookCalls, 0);
    });
  });

  group('Barrierefreiheit und Textgröße', () {
    ui('Liste und Buch: beschriftete Tippflächen und Kontrast', (tester) async {
      final handle = tester.ensureSemantics();
      await store.putEntry(room, own(), publishedVersion: 1);
      await show(tester, CashBooksScreen(controller: c));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.text('Haushalt'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    ui('Editor bei 200 % Schrift: kein Überlauf', (tester) async {
      await store.putEntry(room, own(), publishedVersion: 1);
      await show(tester, CashEntryEditorScreen(controller: c, roomId: room, entry: own()), textScale: 2);
      expect(tester.takeException(), isNull);
      await show(tester, CashBookScreen(controller: c, roomId: room), textScale: 2);
      expect(tester.takeException(), isNull);
      await show(tester, CashBooksScreen(controller: c), textScale: 2);
      expect(tester.takeException(), isNull);
    });

    ui('Buch: Betrag, Geschäft und Datum eines Eintrags stehen in der Bezeichnung für Sprachausgabe', (tester) async {
      final handle = tester.ensureSemantics();
      await store.putEntry(room, own(), publishedVersion: 1);
      await show(tester, CashBookScreen(controller: c, roomId: room));
      expect(find.bySemanticsLabel(RegExp('Edeka, 12,50.*€, 20.11.2026')), findsOneWidget);
      handle.dispose();
    });
  });

  group('Einbindung in „Heute“ und Einstellungen', () {
    ui('mit freigeschaltetem Kassenbuch zeigt „Heute“ die Karte, die Einstellungen den Eintrag; gesperrt nicht', (tester) async {
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final enabled in <bool>[true, false]) {
        final app = await buildTestApp(cashBookItems: MemoryCashBookStore(), cashBooksEnabled: enabled);
        addTearDown(app.services.closeCalendar);
        await app.services.openCalendar();
        final cb = app.services.calendar!.cashBookController!;
        expect(cb.enabled, enabled);
        Widget wrap(Widget child) => AppScope(services: app.services, child: host(child));
        await tester.pumpWidget(wrap(TodayScreen(onOpenChat: () {}, onOpenShopping: () {}, onOpenTasks: () {}, onOpenAgenda: () {})));
        await tester.pump();
        await tester.pump();
        expect(find.text('Noch kein Kassenbuch.'), enabled ? findsOneWidget : findsNothing, reason: 'Heute, enabled=$enabled');
        await tester.pumpWidget(wrap(const SettingsScreen()));
        await tester.pump();
        await tester.pump();
        expect(find.text('Gemeinsame Ausgaben mit anderen Moderatoren, Ende-zu-Ende-verschlüsselt'), enabled ? findsOneWidget : findsNothing, reason: 'Einstellungen, enabled=$enabled');
        await tester.pumpWidget(const SizedBox());
        app.services.closeCalendar();
      }
    });
  });

  test('der gesperrte Standard bleibt', () {
    expect(CashBookFlags.enabled, isFalse);
    expect(CashMonth.of(today), const CashMonth(2026, 11));
  });
}
