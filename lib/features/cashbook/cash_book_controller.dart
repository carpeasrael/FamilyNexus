import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_log.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/file_access.dart';
import '../../data/sync/cash_book_receipts.dart';
import '../../data/sync/cash_book_sync.dart';
import '../../domain/book_policy.dart';
import '../../domain/cash_book.dart';
import '../../domain/cash_book_service.dart';
import '../../domain/cash_book_store.dart';
import '../../domain/cash_month.dart';
import '../../domain/cash_receipt_check.dart';
import '../../domain/family.dart';
import '../../domain/permissions.dart';
import '../../domain/receipt_photo_processing.dart';
import '../../domain/receipt_preview.dart';

/// Ein Buch in der Liste.
class CashBookView {
  const CashBookView({
    required this.meta,
    required this.mine,
    required this.isPlaceholder,
    required this.complete,
    required this.blocked,
    required this.pendingOwn,
    required this.monthTotalCents,
    required this.month,
  });

  final CashBookMeta meta;

  /// Ich habe das Buch angelegt (Ersteller).
  final bool mine;

  /// Platzhalter-Buch (Version 0): Das echte `bookmeta` fehlt (Titel „Kassenbuch“, Währung des Gebietsschemas).
  final bool isPlaceholder;

  /// Der Verlauf ist vollständig geladen; sonst stehen Summen unter Vorbehalt.
  final bool complete;

  /// Der Sendeschutz verhindert das Senden (jemand im Raum ist nicht berechtigt).
  final bool blocked;

  /// Eigene noch nicht gesendete Fassungen.
  final int pendingOwn;
  final int monthTotalCents;
  final CashMonth month;

  String get roomId => meta.roomId;
}

/// Ein Mitglied eines Buchs in der Mitgliederliste.
class CashBookMemberView {
  const CashBookMemberView({required this.userId, required this.name, required this.joined, required this.isCreator, required this.canRemove});
  final String userId;
  final String name;
  final bool joined;
  final bool isCreator;
  final bool canRemove;
}

/// Ergebnis des Ladens einer Bon-Datei für die Anzeige: Das Bild gibt es **nur** bei `ok`.
class CashReceiptView {
  const CashReceiptView(this.status, [this.preview]);
  final BookReceiptStatus status;
  final ReceiptPreview? preview;
}

Future<Uint8List> _prepareReceiptInIsolate(Uint8List input) => compute(_prepareReceipt, input);

Uint8List _prepareReceipt(Uint8List input) => ReceiptPhotoProcessing.prepare(input).bytes;

Future<ReceiptPreview?> _decodePreviewInIsolate(Uint8List bytes) => compute(ReceiptPreview.decode, bytes);

/// Steuerung des Kassenbuchs für die Oberfläche (#311, E-113): Bücher, Einträge, Mitglieder, Einladungen, Bon-Fotos.
///
/// * Alles hinter [enabled] (Sperre): ohne Freischaltung kein Zugriff auf Gateway oder Ablage, jede Aktion wirft
///   `CashBookException(notAllowed)`.
/// * **Nur Moderatoren** (Prüfung hier, der Dienst kennt keine Familie).
/// * Der Controller besitzt `sync.onChanged` (einziger Slot) und baut die Ansicht asynchron auf ([load]); nach jeder
///   lokalen Aktion stößt er den Sync an (`kick`).
/// * Verlassen nur über `gateway.leaveBook`, nie `store.deleteBook` (das Aufräumen gehört dem Sync). Der **Ersteller darf
///   nicht verlassen**; seine Bücher enden mit dem Familienwechsel (E-113).
class CashBookController extends ChangeNotifier {
  CashBookController({
    required this.gateway,
    required this.service,
    required this.store,
    required this.sync,
    required this.receipts,
    required this.enabled,
    required this._today,
    this.files,
    this.currencyFallback = 'EUR',
    Future<Uint8List> Function(Uint8List)? prepareReceipt,
    Future<ReceiptPreview?> Function(Uint8List)? decodePreview,
  })  : _prepareReceipt = prepareReceipt ?? _prepareReceiptInIsolate,
        _decodePreview = decodePreview ?? _decodePreviewInIsolate;

  final MatrixGateway gateway;
  final CashBookService service;
  final CashBookStore store;
  final CashBookSync sync;
  final CashBookReceipts receipts;
  final bool enabled;
  final FileAccess? files;

  /// Währung für Bücher, deren Meta fehlt, und Vorgabe beim Anlegen.
  final String currencyFallback;
  final DateTime Function() _today;
  final Future<Uint8List> Function(Uint8List) _prepareReceipt;
  final Future<ReceiptPreview?> Function(Uint8List) _decodePreview;

  List<CashBookView> _books = const <CashBookView>[];
  List<BookInvitationInfo> _invitations = const <BookInvitationInfo>[];
  bool _started = false;
  bool _disposed = false;
  bool _busy = false;
  Future<void>? _loading;
  bool _loadAgain = false;
  final Set<String> _leaving = <String>{};
  Future<void> _tail = Future<void>.value();

  List<CashBookView> get books => _books;
  List<BookInvitationInfo> get invitations => _invitations;

  /// Eine schreibende Aktion läuft (Speichern sperren).
  bool get busy => _busy;

  String get me => service.myUserId;

  bool get isModerator {
    final f = gateway.family;
    return f != null && Permissions.isModerator(f);
  }

  /// Anzeigename eines Familienmitglieds (leer, wenn unbekannt).
  String nameOf(String userId) => gateway.family?.member(userId)?.displayName ?? '';

  /// Die Funktion ist freigeschaltet **und** ich bin Moderator: nur dann zeigt die Oberfläche Einstiege.
  bool get available => enabled && isModerator;

  /// Darf ich dieses Buch verlassen? Der Ersteller nicht. Maßgeblich ist der Ersteller laut Raum ([CashBookView.mine],
  /// `m.room.create`), nicht die Angabe in den Metadaten.
  bool canLeave(CashBookView b) => !b.mine;

  void start() {
    if (!enabled || _started || _disposed) return;
    _started = true;
    sync.onChanged = _onSyncChanged;
    gateway.addListener(_onGatewayChanged);
    load().ignore();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      gateway.removeListener(_onGatewayChanged);
      if (sync.onChanged == _onSyncChanged) sync.onChanged = null;
    }
    super.dispose();
  }

  void _onSyncChanged() => load().ignore();
  void _onGatewayChanged() => load().ignore();

  void _guard() {
    if (!enabled || !isModerator) throw const CashBookException(CashBookError.notAllowed);
  }

  // ------------------------------------------------------------------ Ansicht

  /// Baut die Ansicht neu auf. Nie parallel: ein Aufruf während eines Laufs löst genau einen weiteren aus.
  Future<void> load() {
    final running = _loading;
    if (running != null) {
      _loadAgain = true;
      return running;
    }
    final done = () async {
      try {
        do {
          _loadAgain = false;
          await _loadOnce();
        } while (_loadAgain && !_disposed);
      } catch (e) {
        AppLog.e('cashbook', 'Kassenbuch-Ansicht konnte nicht aufgebaut werden', e);
      } finally {
        _loading = null;
      }
    }();
    _loading = done;
    return done;
  }

  Future<void> _loadOnce() async {
    if (!available) {
      _set(const <CashBookView>[], const <BookInvitationInfo>[]);
      return;
    }
    // Schnittmenge: ein verlassenes Buch ist auch nach einem Neustart weg, weil das Gateway es nicht mehr listet.
    final present = <String, BookRoomInfo>{for (final b in gateway.books) b.roomId: b};
    _leaving.removeWhere((id) => !present.containsKey(id));
    final month = CashMonth.of(_today());
    final pending = await store.pending(me);
    final out = <CashBookView>[];
    for (final meta in await store.books()) {
      if (!present.containsKey(meta.roomId) || _leaving.contains(meta.roomId)) continue;
      final entries = await store.entries(meta.roomId);
      out.add(CashBookView(
        meta: meta,
        mine: present[meta.roomId]!.creatorId == me,
        isPlaceholder: meta.version == 0,
        complete: await store.isComplete(meta.roomId),
        blocked: sync.blockedRooms.contains(meta.roomId),
        pendingOwn: pending.where((p) => p.roomId == meta.roomId).length,
        monthTotalCents: CashTotals.month(entries, month.year, month.month),
        month: month,
      ));
    }
    out.sort((a, b) => a.meta.title.toLowerCase().compareTo(b.meta.title.toLowerCase()));
    _set(out, List<BookInvitationInfo>.of(gateway.bookInvitations));
  }

  void _set(List<CashBookView> books, List<BookInvitationInfo> invitations) {
    if (_disposed) return;
    _books = books;
    _invitations = invitations;
    notifyListeners();
  }

  /// Nicht gelöschte Einträge des Buchs im Monat [month], neueste zuerst.
  Future<List<CashEntry>> entriesOf(String roomId, CashMonth month) async {
    if (!available) return const <CashEntry>[];
    return month.entriesOf(await store.entries(roomId));
  }

  /// Summe des Monats in Cent (nur dieses Buch, nie über Währungen addiert).
  Future<int> monthTotal(String roomId, CashMonth month) async =>
      available ? CashTotals.month(await store.entries(roomId), month.year, month.month) : 0;

  /// Mitglieder des Buchs (frisch vom Server) mit Namen aus der Familie.
  Future<List<CashBookMemberView>> members(CashBookView book) async {
    _guard();
    final family = gateway.family!;
    final list = await gateway.bookMembers(book.roomId);
    return <CashBookMemberView>[
      for (final m in list)
        CashBookMemberView(
          userId: m.userId,
          name: family.member(m.userId)?.displayName ?? '',
          joined: m.membership == BookMembership.joined,
          isCreator: m.userId == book.meta.owner,
          canRemove: book.mine && m.userId != me,
        ),
    ];
  }

  /// Beigetretene Moderatoren der Familie, die eingeladen werden dürfen und noch nicht im Buch sind.
  Future<List<FamilyMember>> inviteCandidates(CashBookView book) async {
    _guard();
    final family = gateway.family!;
    if (!book.mine) return const <FamilyMember>[];
    final inBook = <String>{for (final m in await gateway.bookMembers(book.roomId)) m.userId};
    return <FamilyMember>[
      for (final m in family.joined)
        if (!inBook.contains(m.userId) && BookPolicy.canInvite(family, m.userId)) m,
    ];
  }

  // ----------------------------------------------------------------- Aktionen

  /// Führt eine schreibende Aktion nacheinander aus und setzt [busy].
  Future<T> _run<T>(Future<T> Function() op) {
    final next = _tail.then((_) async {
      _busy = true;
      if (!_disposed) notifyListeners();
      try {
        return await op();
      } finally {
        _busy = false;
        if (!_disposed) notifyListeners();
      }
    });
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  void _afterAction() {
    sync.kick();
    load().ignore();
  }

  /// Legt ein Buch an (eigener verschlüsselter Raum); die Metadaten warten auf das Senden. Liefert die Raum-ID.
  Future<String> createBook({required String title, required String currency}) => _run(() async {
        _guard();
        final t = title.trim();
        final probe = CashBookMeta(roomId: '!x', title: t, currency: currency, owner: me);
        if (probe.validate().isNotEmpty) throw const CashBookException(CashBookError.invalid);
        final roomId = await gateway.createBook();
        await service.applyBook(CashBookMeta(roomId: roomId, title: t, currency: currency, owner: me), published: false);
        _afterAction();
        return roomId;
      });

  Future<void> inviteMember(CashBookView book, String userId) => _run(() async {
        _guard();
        if (!book.mine) throw const CashBookException(CashBookError.notAllowed);
        await gateway.inviteToBook(book.roomId, userId);
        _afterAction();
      });

  Future<void> removeMember(CashBookView book, String userId) => _run(() async {
        _guard();
        if (!book.mine || userId == me) throw const CashBookException(CashBookError.notAllowed);
        await gateway.removeFromBook(book.roomId, userId);
        _afterAction();
      });

  /// Verlässt ein Buch (nie der Ersteller). Scheitert das Gateway, ändert sich nichts.
  Future<void> leaveBook(CashBookView book) => _run(() async {
        _guard();
        if (!canLeave(book)) throw const CashBookException(CashBookError.notAllowed);
        _leaving.add(book.roomId);
        try {
          await gateway.leaveBook(book.roomId);
        } catch (_) {
          _leaving.remove(book.roomId);
          rethrow;
        }
        load().ignore();
      });

  /// Nimmt eine Einladung an (nur auf ausdrückliche Bestätigung der Oberfläche, nie automatisch).
  Future<void> acceptInvitation(String roomId) => _run(() async {
        _guard();
        await gateway.acceptBookInvitation(roomId);
        _afterAction();
      });

  Future<void> declineInvitation(String roomId) => _run(() async {
        _guard();
        await gateway.declineBookInvitation(roomId);
        _afterAction();
      });

  /// Wählt ein Bild (Dateidialog). `null` = abgebrochen. Wirft [FileTooLargeException].
  Future<Uint8List?> pickPhoto() async {
    _guard();
    final f = files;
    if (f == null) throw const CashBookException(CashBookError.notAllowed);
    return (await f.pickImage())?.bytes;
  }

  /// Legt einen eigenen Eintrag an, optional mit Foto (zuerst aufbereitet, dann Datei, dann Eintrag).
  Future<CashEntry> addEntry(
    String roomId, {
    required DateTime date,
    required String store,
    required int amountCents,
    String note = '',
    Uint8List? photo,
  }) =>
      _run(() async {
        _guard();
        final CashEntry e;
        if (photo == null) {
          e = await service.create(roomId, date: date, store: store, amountCents: amountCents, note: note);
        } else {
          final jpeg = await _prepareReceipt(photo);
          e = await receipts.createWithReceipt(roomId, date: date, store: store, amountCents: amountCents, note: note, jpeg: jpeg);
        }
        _afterAction();
        return e;
      });

  /// Ändert einen eigenen Eintrag: mit [newPhoto] ersetzt, mit [removePhoto] entfernt, sonst bleibt der Bon.
  Future<CashEntry> editEntry(String roomId, CashEntry edited, {Uint8List? newPhoto, bool removePhoto = false}) => _run(() async {
        _guard();
        final CashEntry e;
        if (newPhoto != null) {
          final jpeg = await _prepareReceipt(newPhoto);
          e = await receipts.updateWithReceipt(roomId, edited, jpeg);
        } else {
          e = await service.update(roomId, removePhoto ? edited.copyWith(clearReceipt: true) : edited);
        }
        _afterAction();
        return e;
      });

  Future<void> deleteEntry(String roomId, String id) => _run(() async {
        _guard();
        await service.delete(roomId, id);
        _afterAction();
      });

  /// Lädt und prüft den Bon eines Eintrags. Ein Bild gibt es **nur** bei `ok`; dekodiert wird in einem Isolate.
  Future<CashReceiptView> loadReceipt(String roomId, CashEntry entry) async {
    if (!available) return const CashReceiptView(BookReceiptStatus.missing);
    final l = await receipts.load(roomId, entry);
    if (l.status != BookReceiptStatus.ok) return CashReceiptView(l.status);
    // „ok“ ohne Bytes darf es nicht geben; ein Bild gibt es nur mit geprüften Bytes.
    if (l.bytes == null) return const CashReceiptView(BookReceiptStatus.invalid);
    final preview = await _decodePreview(l.bytes!);
    // Bytes, die geprüft sind, sich aber nicht anzeigen lassen, gelten als ungültig (nie ein Absturz).
    return preview == null ? const CashReceiptView(BookReceiptStatus.invalid) : CashReceiptView(BookReceiptStatus.ok, preview);
  }
}
