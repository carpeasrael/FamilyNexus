import 'package:uuid/uuid.dart';

import 'anniversaries.dart';
import 'anniversary_store.dart';

enum AnniversaryError { invalid, notFound, limit }

class AnniversaryException implements Exception {
  const AnniversaryException(this.error);
  final AnniversaryError error;

  @override
  String toString() => 'AnniversaryException(${error.name})';
}

/// Fachlogik der Geburts- und Gedenktage (E-104); kennt nur den [AnniversaryStore]-Port.
///
/// Der Dienst kennt keine Mitglieder: Jedes beigetretene Mitglied darf anlegen, ändern und löschen (E-40);
/// beim Empfang prüft der Codec den authentischen Absender, Format und Grenzen. [today] liefert den heutigen
/// Kalendertag (UTC-Datum) in der Zeitzone des Betrachters, dieselbe Quelle wie `CalendarController.today`.
class AnniversaryService {
  AnniversaryService({
    required this.store,
    required this.myUserId,
    required this.today,
    DateTime Function()? clock,
    String Function()? idGenerator,
  })  : _clock = clock ?? DateTime.now,
        _newId = idGenerator ?? (() => const Uuid().v4());

  final AnniversaryStore store;
  final String myUserId;
  /// Heutiger Kalendertag (UTC-Datum) des Betrachters.
  final DateTime Function() today;
  final DateTime Function() _clock;
  final String Function() _newId;

  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  DateTime get now => DateTime.fromMillisecondsSinceEpoch(_clock().toUtc().millisecondsSinceEpoch, isUtc: true);

  static String _norm(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  void _check(AnniversaryPerson p) {
    if (p.validate().isNotEmpty) throw const AnniversaryException(AnniversaryError.invalid);
  }

  /// Beim Anlegen und Ändern darf ein angegebenes volles Datum nicht in der Zukunft liegen; beim Ändern nur,
  /// wenn das Feld geändert wurde (ein empfangener Eintrag mit Zukunftsjahr bleibt umbenennbar).
  void _checkNotFuture(AnniversaryDate? now, AnniversaryDate? before) {
    if (now == null || now == before) return;
    final t = today();
    if (now.isAfter(DateTime.utc(t.year, t.month, t.day))) throw const AnniversaryException(AnniversaryError.invalid);
  }

  Future<AnniversaryPerson> create({required String name, AnniversaryDate? birth, AnniversaryDate? death}) => _serial(() async {
        final person = AnniversaryPerson(
          id: _newId(),
          name: _norm(name),
          birth: birth,
          death: death,
          by: myUserId,
          updatedAt: now,
        );
        _check(person);
        _checkNotFuture(birth, null);
        _checkNotFuture(death, null);
        var c = await store.counts();
        if (c.total >= AnniversaryPerson.maxTotal) {
          await store.pruneTombstones(keep: AnniversaryPerson.keepTombstones);
          c = await store.counts();
        }
        if (c.active >= AnniversaryPerson.maxActive || c.total >= AnniversaryPerson.maxTotal) {
          throw const AnniversaryException(AnniversaryError.limit);
        }
        await store.put(person, publishedVersion: 0);
        return person;
      });

  /// Ändert Name und Daten (eine neue Version); `birth`/`death` null entfernt das Datum.
  Future<AnniversaryPerson> update(String id, {required String name, AnniversaryDate? birth, AnniversaryDate? death}) => _serial(() async {
        final current = await store.get(id);
        if (current == null || current.deleted) throw const AnniversaryException(AnniversaryError.notFound);
        if (current.version >= AnniversaryPerson.maxVersion) throw const AnniversaryException(AnniversaryError.limit);
        final next = current.copyWith(
          name: _norm(name),
          birth: birth,
          death: death,
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        _checkNotFuture(birth, current.birth);
        _checkNotFuture(death, current.death);
        await store.put(next);
        return next;
      });

  Future<void> delete(String id) => _serial(() async {
        final current = await store.get(id);
        if (current == null || current.deleted) throw const AnniversaryException(AnniversaryError.notFound);
        if (current.version >= AnniversaryPerson.maxVersion) throw const AnniversaryException(AnniversaryError.limit);
        final next = current.copyWith(
          name: '',
          birth: null,
          death: null,
          deleted: true,
          version: current.version + 1,
          by: myUserId,
          updatedAt: now,
        );
        _check(next);
        await store.put(next);
      });

  /// Nimmt einen empfangenen (dekodierten) Eintrag an; `true`, wenn sich der Bestand geändert hat. Keine
  /// Mitgliedsprüfung (E-40): Der Codec hat `by == Absender`, Format und Grenzen geprüft.
  Future<bool> applyIncoming(AnniversaryPerson incoming) => _serial(() async {
        final current = await store.get(incoming.id);
        if (current == null) {
          if (incoming.version > AnniversaryPerson.maxFirstVersion) return false;
          var c = await store.counts();
          if (c.total >= AnniversaryPerson.maxTotal) {
            await store.pruneTombstones(keep: AnniversaryPerson.keepTombstones);
            c = await store.counts();
          }
          if (c.total >= AnniversaryPerson.maxTotal || (!incoming.deleted && c.active >= AnniversaryPerson.maxActive)) return false;
        } else if (incoming.version > current.version + AnniversaryPerson.maxVersionJump) {
          return false;
        }
        if (!AnniversaryMerge.incomingWins(current, incoming)) return false;
        await store.put(incoming, publishedVersion: incoming.version);
        return true;
      });
}
