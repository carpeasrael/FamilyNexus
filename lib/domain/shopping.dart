import 'package:uuid/uuid.dart';

import 'calendar_event.dart';
import 'server.dart';
import 'shopping_store.dart';

/// Ein Eintrag der gemeinsamen Einkaufsliste (E-40).
///
/// Jedes Familienmitglied darf jeden Eintrag ändern. Gleichzeitige Änderungen konvergieren über
/// [ShoppingMerge]: höhere Version, dann späterer Zeitstempel, dann größere Absender-ID.
class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.title,
    required this.by,
    required this.updatedAt,
    this.quantity = '',
    this.checked = false,
    this.deleted = false,
    this.version = 1,
  });

  static const int maxTitle = 100;
  static const int maxQuantity = 30;
  static const int maxVersion = 1000000;

  /// Höchstzahl aktiver Einträge und aller Datensätze (inkl. Löschmarken), Speicherschutz.
  static const int maxActive = 300;
  static const int maxTotal = 1000;

  /// Beim Erreichen von [maxTotal] bleiben höchstens so viele (neueste) veröffentlichte Löschmarken.
  static const int keepTombstones = 200;

  /// Größte Version eines erstmals empfangenen Eintrags und größter Sprung gegenüber der bekannten.
  static const int maxFirstVersion = 10000;
  static const int maxVersionJump = 1000;

  final String id;
  final String title;
  final String quantity;
  final bool checked;
  final bool deleted;
  final int version;

  /// Letzter Bearbeiter (Matrix-ID); beim Empfang muss er dem authentischen Absender entsprechen.
  final String by;
  final DateTime updatedAt;

  static final RegExp _bad = RegExp(
    '[\\u0000-\\u001F\\u007F-\\u009F\\u061C\\u200B-\\u200F\\u202A-\\u202E\\u2060-\\u2064\\u2066-\\u2069\\uFEFF]',
  );

  /// Fachliche Prüfung; leer = gültig.
  List<String> validate() {
    final p = <String>[];
    if (!CalendarEvent.isValidId(id)) p.add('id');
    if (!MatrixIds.isUserId(by)) p.add('by');
    if (version < 1 || version > maxVersion) p.add('version');
    if (!updatedAt.isUtc || updatedAt.isBefore(CalendarEvent.minDate) || updatedAt.isAfter(CalendarEvent.maxDate)) p.add('time');
    if (title.runes.length > maxTitle || quantity.runes.length > maxQuantity) p.add('length');
    if (_bad.hasMatch(title) || _bad.hasMatch(quantity)) p.add('text');
    if (deleted) {
      // Löschmarken tragen keinen Inhalt.
      if (title.isNotEmpty || quantity.isNotEmpty || checked) p.add('tombstone');
    } else if (title.trim().isEmpty) {
      p.add('title');
    }
    return p;
  }

  ShoppingItem copyWith({
    String? title,
    String? quantity,
    bool? checked,
    bool? deleted,
    int? version,
    String? by,
    DateTime? updatedAt,
  }) =>
      ShoppingItem(
        id: id,
        title: title ?? this.title,
        quantity: quantity ?? this.quantity,
        checked: checked ?? this.checked,
        deleted: deleted ?? this.deleted,
        version: version ?? this.version,
        by: by ?? this.by,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is ShoppingItem &&
      other.id == id &&
      other.title == title &&
      other.quantity == quantity &&
      other.checked == checked &&
      other.deleted == deleted &&
      other.version == version &&
      other.by == by &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, quantity, checked, deleted, version, by, updatedAt);
}

/// Ereignisformat v1 der Einkaufsliste: verschlüsseltes Raumereignis im Familienraum.
class ShoppingCodec {
  const ShoppingCodec._();

  static const String type = 'de.inneso.familynexus.shopping';
  static const int schema = 1;

  static Map<String, Object?> encode(ShoppingItem i) {
    final problems = i.validate();
    if (problems.isNotEmpty) throw StateError('Ungültiger Eintrag: ${problems.join(',')}');
    return <String, Object?>{
      'v': schema,
      'id': i.id,
      'by': i.by,
      'version': i.version,
      'deleted': i.deleted,
      'title': i.title,
      'qty': i.quantity,
      'checked': i.checked,
      'ts': i.updatedAt.millisecondsSinceEpoch,
    };
  }

  /// `null` bei ungültigem Inhalt. Das Feld `by` muss mit [sender] übereinstimmen
  /// (kein Schreiben in fremdem Namen).
  static ShoppingItem? decode(Map<String, Object?> c, {required String sender}) {
    if (!MatrixIds.isUserId(sender) || c['v'] != schema) return null;
    final id = c['id'];
    final by = c['by'];
    final version = c['version'];
    final deleted = c['deleted'];
    final title = c['title'];
    final qty = c['qty'];
    final checked = c['checked'];
    final ts = c['ts'];
    if (id is! String || by is! String || version is! int || deleted is! bool) return null;
    if (title is! String || qty is! String || checked is! bool || ts is! int) return null;
    if (by != sender) return null;
    // Vor dem Umrechnen begrenzen (kein Überlauf bei absurden Zahlen).
    if (ts < CalendarEvent.minDate.millisecondsSinceEpoch || ts > CalendarEvent.maxDate.millisecondsSinceEpoch) return null;
    if (title.length > ShoppingItem.maxTitle * 2 || qty.length > ShoppingItem.maxQuantity * 2) return null;
    final item = ShoppingItem(
      id: id,
      title: title,
      quantity: qty,
      checked: checked,
      deleted: deleted,
      version: version,
      by: by,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
    );
    return item.validate().isEmpty ? item : null;
  }
}

/// Konfliktregel (E-40).
class ShoppingMerge {
  const ShoppingMerge._();

  /// `true`, wenn [incoming] die gespeicherte Fassung [current] ersetzen soll.
  static bool incomingWins(ShoppingItem? current, ShoppingItem incoming) {
    if (current == null) return true;
    if (incoming.version != current.version) return incoming.version > current.version;
    final byTime = incoming.updatedAt.compareTo(current.updatedAt);
    if (byTime != 0) return byTime > 0;
    final byAuthor = incoming.by.compareTo(current.by);
    if (byAuthor != 0) return byAuthor > 0;
    return _tie(incoming).compareTo(_tie(current)) > 0;
  }

  static String _tie(ShoppingItem i) => '${i.deleted}|${i.checked}|${i.title}|${i.quantity}';
}

enum ShoppingError { invalid, notFound, limit }

class ShoppingException implements Exception {
  const ShoppingException(this.error);
  final ShoppingError error;

  @override
  String toString() => 'ShoppingException(${error.name})';
}

/// Fachlogik der Einkaufsliste; kennt nur den [ShoppingStore]-Port.
class ShoppingService {
  ShoppingService({
    required this.store,
    required this.myUserId,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final ShoppingStore store;
  final String myUserId;
  final DateTime Function() _clock;
  final String Function() _newId;

  // Alle schreibenden Abläufe laufen nacheinander (Eingänge, lokale Änderungen).
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  DateTime get _now => DateTime.fromMillisecondsSinceEpoch(_clock().toUtc().millisecondsSinceEpoch, isUtc: true);

  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<ShoppingItem> add(String title, {String quantity = ''}) => _serial(() async {
        final item = ShoppingItem(
          id: _newId(),
          title: _norm(title),
          quantity: _norm(quantity),
          by: myUserId,
          updatedAt: _now,
        );
        _check(item);
        var c = await store.counts();
        if (c.total >= ShoppingItem.maxTotal) {
          await store.pruneTombstones(keep: ShoppingItem.keepTombstones);
          c = await store.counts();
        }
        if (c.active >= ShoppingItem.maxActive || c.total >= ShoppingItem.maxTotal) {
          throw const ShoppingException(ShoppingError.limit);
        }
        await store.put(item, publishedVersion: 0);
        return item;
      });

  Future<ShoppingItem> setChecked(String id, bool checked) => _change(id, (c) => c.copyWith(checked: checked));

  Future<ShoppingItem> edit(String id, {required String title, String quantity = ''}) =>
      _change(id, (c) => c.copyWith(title: _norm(title), quantity: _norm(quantity)));

  Future<void> remove(String id) => _change(id, _tombstone);

  /// Löscht alle abgehakten Einträge; liefert deren Anzahl.
  Future<int> clearChecked() => _serial(() async {
        var n = 0;
        for (final c in await store.all()) {
          if (c.deleted || !c.checked) continue;
          if (c.version >= ShoppingItem.maxVersion) continue;
          final next = _bump(_tombstone(c), c);
          _check(next);
          await store.put(next);
          n++;
        }
        return n;
      });

  ShoppingItem _tombstone(ShoppingItem c) =>
      c.copyWith(title: '', quantity: '', checked: false, deleted: true);

  ShoppingItem _bump(ShoppingItem changed, ShoppingItem from) =>
      changed.copyWith(version: from.version + 1, by: myUserId, updatedAt: _now);

  Future<ShoppingItem> _change(String id, ShoppingItem Function(ShoppingItem current) f) => _serial(() async {
        final current = await store.get(id);
        if (current == null || current.deleted) throw const ShoppingException(ShoppingError.notFound);
        if (current.version >= ShoppingItem.maxVersion) throw const ShoppingException(ShoppingError.limit);
        final next = _bump(f(current), current);
        _check(next);
        await store.put(next);
        return next;
      });

  /// Nimmt einen empfangenen (bereits dekodierten und geprüften) Eintrag an.
  /// `true`, wenn sich der lokale Bestand geändert hat.
  Future<bool> applyIncoming(ShoppingItem incoming) => _serial(() async {
        final current = await store.get(incoming.id);
        if (current == null) {
          if (incoming.version > ShoppingItem.maxFirstVersion) return false;
          var c = await store.counts();
          if (c.total >= ShoppingItem.maxTotal) {
            await store.pruneTombstones(keep: ShoppingItem.keepTombstones);
            c = await store.counts();
          }
          if (c.total >= ShoppingItem.maxTotal || (!incoming.deleted && c.active >= ShoppingItem.maxActive)) return false;
        } else if (incoming.version > current.version + ShoppingItem.maxVersionJump) {
          // Kein Hochsetzen der Version, das den Eintrag für alle unveränderbar machte.
          return false;
        }
        if (!ShoppingMerge.incomingWins(current, incoming)) return false;
        await store.put(incoming, publishedVersion: incoming.version);
        return true;
      });

  void _check(ShoppingItem i) {
    if (i.validate().isNotEmpty) throw const ShoppingException(ShoppingError.invalid);
  }
}
