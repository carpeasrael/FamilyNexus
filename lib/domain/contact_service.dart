import 'contact_store.dart';
import 'contacts.dart';
import 'moderation.dart';

enum ContactError { invalid, notAllowed, notFound, limit, duplicate }

class ContactException implements Exception {
  const ContactException(this.error);
  final ContactError error;

  @override
  String toString() => 'ContactException(${error.name})';
}

/// Fachlogik der Kontakte (#119, E-114): Regeln, Versionen, Grenzen. Kennt nur den [ContactStore]-Port, weder Matrix noch
/// Oberfläche. Ob eine Einladung eines Familienmitglieds als Kontakt zulässig ist, entscheidet das Gateway (K2c).
class ContactService {
  ContactService({required this.store, required this.myUserId, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final ContactStore store;
  final String myUserId;
  final DateTime Function() _clock;

  DateTime get _now => _clock().toUtc();

  /// Wird nach jeder **inhaltlichen** Änderung des Bestands gerufen (lokale Schreibvorgänge und angenommene Empfänge),
  /// nicht nach [restamp] und nicht nach abgelehnten Empfängen. Der Rückruf des Besitzers darf nicht werfen (der
  /// `ContactSync` setzt darin nur ein Flag und plant einen Lauf).
  void Function()? onChanged;

  void _changed() => onChanged?.call();

  // Alle schreibenden Abläufe laufen nacheinander (Eingänge, lokale Änderungen).
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() op) {
    final next = _tail.then((_) => op());
    _tail = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  // ------------------------------------------------------------------ Lesen

  /// Ist der Bereich eingeschaltet? Standard: aus.
  Future<bool> isEnabled() async => ((await store.get(ContactKind.prefs, ContactPrefs.prefsId)) as ContactPrefs?)?.enabled ?? false;

  /// Aktive Kontakte (ohne Löschmarken), nach Kennung sortiert.
  Future<List<Contact>> contacts() async => <Contact>[
        for (final r in await store.all(ContactKind.contact))
          if (!r.deleted) r as Contact,
      ]..sort((a, b) => a.id.compareTo(b.id));

  Future<List<GroupRecord>> groups() async => <GroupRecord>[
        for (final r in await store.all(ContactKind.group))
          if (!r.deleted) r as GroupRecord,
      ]..sort((a, b) => a.id.compareTo(b.id));

  Future<Contact?> contact(String id) async => (await store.get(ContactKind.contact, id)) as Contact?;

  // ---------------------------------------------------------------- Ändern

  Future<void> setEnabled(bool enabled) => _serial(() async {
        final current = (await store.get(ContactKind.prefs, ContactPrefs.prefsId)) as ContactPrefs?;
        if ((current?.enabled ?? false) == enabled) return; // ohne Datensatz gilt „aus“
        final next = ContactPrefs(enabled: enabled, version: _nextVersion(current), updatedAt: _now);
        await store.put(next);
        _changed();
      });

  /// Legt einen ausgehenden Kontakt an (Datensatz `outgoing`). [rawId]: `@name:server` oder `matrix.to`-Link.
  Future<Contact> addOutgoing(String rawId, {String nick = ''}) => _serial(() async {
        final id = _requireId(rawId);
        final current = (await store.get(ContactKind.contact, id)) as Contact?;
        if (current != null && !current.deleted) {
          throw ContactException(current.state == ContactState.blocked ? ContactError.notAllowed : ContactError.duplicate);
        }
        await _checkRoom(current, ContactKind.contact);
        final next = Contact(id: id, state: ContactState.outgoing, nick: nick, version: _nextVersion(current), updatedAt: _now, room: current?.room);
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  /// Nimmt eine Kontaktanfrage an (K3a-2, Datensatz **zuerst**): legt `accepted` an oder stuft einen vorhandenen
  /// `outgoing`-Kontakt hoch. Ein Blockierter bleibt blockiert (`notAllowed`), ein bereits bestätigter Kontakt ist
  /// `duplicate`. Ob [rawId] ein Familienmitglied ist, weiß der Dienst nicht: Das Gateway stuft solche Datensätze nie als
  /// Kontakt ein, und der Controller prüft es vorab. Danach schiebt `ContactSync` die Richtlinie, und die Auto-Annahme des
  /// Gateways tritt dem Raum bei.
  Future<Contact> addAccepted(String rawId, {String nick = ''}) => _serial(() async {
        final id = _requireId(rawId);
        final current = (await store.get(ContactKind.contact, id)) as Contact?;
        if (current != null && !current.deleted) {
          if (current.state == ContactState.blocked) throw const ContactException(ContactError.notAllowed);
          if (current.state == ContactState.accepted) throw const ContactException(ContactError.duplicate);
          final next = current.copyWith(state: ContactState.accepted, version: _nextVersion(current), updatedAt: _now);
          _requireValid(next);
          await store.put(next);
          _changed();
          return next;
        }
        await _checkRoom(current, ContactKind.contact);
        final next = Contact(id: id, state: ContactState.accepted, nick: nick, version: _nextVersion(current), updatedAt: _now, room: current?.room);
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  /// `outgoing` → `accepted` (die Gegenseite ist beigetreten); [room] ist der Einzelchat.
  Future<Contact> markAccepted(String id, {String? room}) => _serial(() async {
        final current = await _active(id);
        if (current.state != ContactState.outgoing) throw const ContactException(ContactError.notAllowed);
        final next = current.copyWith(state: ContactState.accepted, room: room ?? current.room, version: _nextVersion(current), updatedAt: _now);
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  /// Blockiert [rawId], auch ohne bestehenden Kontakt (blockierte Anfrage ohne Raum). Höchstens
  /// [BlockedUsers.maxEntries] blockierte Datensätze.
  Future<Contact> block(String rawId) => _serial(() async {
        final id = _requireId(rawId);
        final current = (await store.get(ContactKind.contact, id)) as Contact?;
        if (current != null && !current.deleted && current.state == ContactState.blocked) return current;
        if (id == myUserId) throw const ContactException(ContactError.notAllowed);
        final wasActive = current != null && !current.deleted;
        if (!wasActive) await _checkRoom(current, ContactKind.contact);
        if (await _blockedCount() >= BlockedUsers.maxEntries) throw const ContactException(ContactError.limit);
        final next = Contact(
          id: id,
          state: ContactState.blocked,
          nick: current?.nick ?? '',
          room: current?.room,
          version: _nextVersion(current),
          updatedAt: _now,
        );
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  /// Hebt eine Blockierung auf: Der Datensatz wird zur Löschmarke (kein Kontakt mehr); ein bekannter Raum bleibt auf dem
  /// Server, „Erneut hinzufügen“ nutzt ihn.
  Future<void> unblock(String id) => _serial(() async {
        final current = await _active(id);
        if (current.state != ContactState.blocked) throw const ContactException(ContactError.notAllowed);
        await store.put(current.copyWith(version: _nextVersion(current), updatedAt: _now, deleted: true));
        _changed();
      });

  Future<Contact> rename(String id, String nick) => _serial(() async {
        final current = await _active(id);
        if (current.state == ContactState.blocked) throw const ContactException(ContactError.notAllowed);
        final next = current.copyWith(nick: nick, version: _nextVersion(current), updatedAt: _now);
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  /// Entfernt einen Kontakt (`outgoing` oder `accepted`): Löschmarke.
  Future<void> remove(String id) => _serial(() async {
        final current = await _active(id);
        if (current.state == ContactState.blocked) throw const ContactException(ContactError.notAllowed);
        await store.put(current.copyWith(version: _nextVersion(current), updatedAt: _now, deleted: true));
        _changed();
      });

  /// Bedingte Löschung für die Rücknahme eines gescheiterten Hinzufügens (K3b-1): löscht (Löschmarke) **nur**, wenn der
  /// Datensatz aktiv ist und genau diese [version] und diesen [state] hat; sonst `false`. Ein Empfang oder eine
  /// Bestätigung dazwischen macht die Rücknahme damit zu einem No-op (innerhalb der Serialisierung des Dienstes).
  Future<bool> removeIfVersion(String id, {required int version, required ContactState state}) => _serial(() async {
        final canonical = ContactId.parse(id);
        final current = canonical == null ? null : (await store.get(ContactKind.contact, canonical)) as Contact?;
        if (current == null || current.deleted || current.version != version || current.state != state) return false;
        await store.put(current.copyWith(version: _nextVersion(current), updatedAt: _now, deleted: true));
        _changed();
        return true;
      });

  Future<GroupRecord> addGroup(String roomId) => _serial(() async {
        final current = (await store.get(ContactKind.group, roomId)) as GroupRecord?;
        if (current != null && !current.deleted) throw const ContactException(ContactError.duplicate);
        await _checkRoom(current, ContactKind.group);
        final next = GroupRecord(id: roomId, version: _nextVersion(current), updatedAt: _now);
        _requireValid(next);
        await store.put(next);
        _changed();
        return next;
      });

  Future<void> removeGroup(String roomId) => _serial(() async {
        final current = (await store.get(ContactKind.group, roomId)) as GroupRecord?;
        if (current == null || current.deleted) throw const ContactException(ContactError.notFound);
        await store.put(current.copyWith(version: _nextVersion(current), updatedAt: _now, deleted: true));
        _changed();
      });

  // --------------------------------------------------------------- Empfang

  /// Nimmt einen empfangenen Datensatz an (bereits dekodiert, Absender == eigenes Konto, geprüft vom Codec). `true`,
  /// wenn gespeichert. Verworfen wird bei Gleichstand oder älterer Fassung (Konfliktregel), bei einem Versionssprung
  /// über [ContactLimits.maxVersionStep] und an den Grenzen (Kontakte, Gruppen, Blockierte, alle Zeilen).
  Future<bool> applyIncoming(ContactRecord incoming) => _serial(() async {
        if (incoming.validate().isNotEmpty) return false;
        final current = await store.get(incoming.kind, incoming.id);
        if (current != null) {
          if (incoming.version > current.version + ContactLimits.maxVersionStep) return false;
          if (!Contacts.supersedes(incoming, current)) return false;
        }
        final becomesActive = !incoming.deleted && (current == null || current.deleted);
        if (current == null) {
          if (!await _roomForNewRow()) return false;
        }
        if (becomesActive) {
          if (!await _withinActiveLimits(incoming)) return false;
        } else if (!incoming.deleted && incoming is Contact && incoming.state == ContactState.blocked && current is Contact && current.state != ContactState.blocked) {
          if (await _blockedCount() >= BlockedUsers.maxEntries) return false;
        }
        await store.put(incoming, publishedVersion: incoming.version);
        _changed();
        return true;
      });

  /// Stempelt einen **eigenen** wartenden Datensatz (Version unverändert) neu, wenn sein `ts` mehr als einen Tag von
  /// jetzt abweicht: Der Empfänger verwirft Abweichungen über [ContactLimits.maxSkew], und ein erneut gesendeter oder lange
  /// wartender Datensatz trüge sonst einen alten Zeitstempel. Liest neu (innerhalb der Serialisierung) und stempelt nur,
  /// wenn Version und Löschmarke noch dem erwarteten Stand entsprechen; sonst `null`. Der Datensatz bleibt in der
  /// Warteschlange. Gibt die gespeicherte Fassung zurück.
  Future<ContactRecord?> restamp(ContactKind kind, String id, {required int expectedVersion, required bool expectedDeleted}) => _serial(() async {
        final current = await store.get(kind, id);
        if (current == null || current.version != expectedVersion || current.deleted != expectedDeleted) return null;
        final now = _now;
        if (current.updatedAt.difference(now).abs() <= const Duration(days: 1)) return current;
        final next = _withTime(current, now);
        await store.put(next);
        return next;
      });

  // -------------------------------------------------------------- Hilfsmittel

  static ContactRecord _withTime(ContactRecord r, DateTime at) => switch (r) {
        final Contact c => c.copyWith(updatedAt: at),
        final GroupRecord g => g.copyWith(updatedAt: at),
        final ContactPrefs p => p.copyWith(updatedAt: at),
        _ => r,
      };

  String _requireId(String raw) {
    final id = ContactId.parse(raw);
    if (id == null) throw const ContactException(ContactError.invalid);
    if (id == myUserId) throw const ContactException(ContactError.notAllowed);
    return id;
  }

  void _requireValid(ContactRecord r) {
    if (r.validate().isNotEmpty) throw const ContactException(ContactError.invalid);
  }

  Future<Contact> _active(String id) async {
    final canonical = ContactId.parse(id);
    final current = canonical == null ? null : (await store.get(ContactKind.contact, canonical)) as Contact?;
    if (current == null || current.deleted) throw const ContactException(ContactError.notFound);
    return current;
  }

  int _nextVersion(ContactRecord? current) {
    final v = (current?.version ?? 0) + 1;
    if (v > ContactLimits.maxVersion) throw const ContactException(ContactError.limit);
    return v;
  }

  Future<int> _blockedCount() async => (await store.all(ContactKind.contact)).where((r) => !r.deleted && (r as Contact).state == ContactState.blocked).length;

  /// Für einen **lokal** neu aktiven Datensatz: Grenze der Art und Platz in der Ablage.
  Future<void> _checkRoom(ContactRecord? current, ContactKind kind) async {
    final records = await store.all();
    final active = records.where((r) => r.kind == kind && !r.deleted).length;
    final max = kind == ContactKind.group ? ContactLimits.maxGroups : ContactLimits.maxContacts;
    if (active >= max) throw const ContactException(ContactError.limit);
    if (current == null && !await _roomForNewRow()) throw const ContactException(ContactError.limit);
  }

  /// Platz für eine **neue** Zeile; räumt vorher veröffentlichte Löschmarken auf. Unveröffentlichte bleiben.
  Future<bool> _roomForNewRow() async {
    if ((await store.all()).length < ContactLimits.maxRecords) return true;
    await store.pruneTombstones(keep: ContactLimits.keepTombstones);
    return (await store.all()).length < ContactLimits.maxRecords;
  }

  Future<bool> _withinActiveLimits(ContactRecord incoming) async {
    final records = await store.all();
    switch (incoming.kind) {
      case ContactKind.contact:
        final active = records.where((r) => r.kind == ContactKind.contact && !r.deleted).length;
        if (active >= ContactLimits.maxContacts) return false;
        if (incoming is Contact && incoming.state == ContactState.blocked && await _blockedCount() >= BlockedUsers.maxEntries) return false;
        return true;
      case ContactKind.group:
        return records.where((r) => r.kind == ContactKind.group && !r.deleted).length < ContactLimits.maxGroups;
      case ContactKind.prefs:
        return true;
    }
  }
}
