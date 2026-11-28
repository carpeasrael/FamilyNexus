import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_log.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/sync/contact_sync.dart';
import '../../domain/chat.dart';
import '../../domain/contact_service.dart';
import '../../domain/contacts.dart';
import '../../domain/family.dart' show FamilyMember;

/// Zustand eines Kontakts in der Liste (Text, nie nur Farbe).
enum ContactStateView {
  /// Der Raum steht, das Gegenüber ist noch nicht beigetreten.
  waiting,

  /// Beigetreten und bestätigt.
  confirmed,

  /// Datensatz `outgoing`, aber (noch) kein Raum: wurde nicht gesendet oder der Raum fehlt; „Erneut senden“ ist möglich.
  notSent,

  /// Datensatz `accepted`, aber noch kein Gespräch: Die Einladung wird angenommen oder ist nicht mehr da.
  searching,
  blocked,
}

/// Ein Kontakt für die Liste.
@immutable
class ContactEntry {
  const ContactEntry({required this.id, required this.title, required this.state, this.threadId, this.collides = false});

  final String id;

  /// Spitzname oder bereinigter „Name · server“.
  final String title;
  final ContactStateView state;
  final String? threadId;

  /// Der Name gleicht einem Familienmitglied (§9.1): Warnung „Nicht deine Familie“.
  final bool collides;

  @override
  bool operator ==(Object other) =>
      other is ContactEntry && other.id == id && other.title == title && other.state == state && other.threadId == threadId && other.collides == collides;

  @override
  int get hashCode => Object.hash(id, title, state, threadId, collides);
}

/// Ergebnis von [ContactController.check]: alle Fälle, in denen das Hinzufügen nicht möglich ist, mit eigenem Text; nur
/// [ready] erlaubt es.
enum ContactCheckOutcome {
  invalid,
  self,
  duplicate,
  blockedRecord,
  blockedLocal,
  familyMember,
  notFound,
  notReachable,
  identityChanged,
  unknown,
  rateLimited,
  notReady,
  busy,
  ready,
}

@immutable
class ContactCheck {
  const ContactCheck(this.outcome, {this.userId = '', this.displayName = '', this.title = '', this.collides = false});

  final ContactCheckOutcome outcome;
  final String userId;
  final String displayName;

  /// „Name · server“ (Name bereinigt, Server aus der Kennung).
  final String title;

  /// Der Name gleicht einem Familienmitglied (§9.1): Das Hinzufügen verlangt eine ausdrückliche Bestätigung.
  final bool collides;
}

/// Ergebnis einer Einladung beim Anlegen einer Gruppe ([ContactController.createGroup]): [error] ist `null`, wenn die Person
/// eingeladen wurde.
@immutable
class GroupInviteResult {
  const GroupInviteResult(this.userId, [this.error]);

  final String userId;
  final GatewayError? error;

  bool get ok => error == null;
}

/// Ergebnis von [ContactController.createGroup]: die neue Gruppe und je eingeladener Person ein Ergebnis (nie ein Abbruch bei
/// einem Fehler, #119, K4-3).
@immutable
class GroupCreation {
  const GroupCreation(this.roomId, this.invites);

  final String roomId;
  final List<GroupInviteResult> invites;
}

/// Oberfläche der Kontakte (#119, K3b-1, E-114): Dienst, Synchronisation und Gateway zu einer Ansicht. Die Reihenfolge der
/// Abläufe ist festgelegt: **Datensatz zuerst, dann Richtlinie schieben, dann Gateway**; Entfernen verlässt zuerst den Raum
/// und löscht dann den Datensatz; Blockieren verlässt nie einen Raum und beantwortet keine Einladung (§9.3).
class ContactController extends ChangeNotifier {
  ContactController({required this.gateway, required ContactSync sync, DateTime Function()? clock})
      : _sync = sync,
        _service = sync.service,
        _clock = clock ?? DateTime.now;

  final MatrixGateway gateway;
  final ContactSync _sync;
  final ContactService _service;
  final DateTime Function() _clock;

  static const Duration checkCooldown = Duration(seconds: 60);

  /// Entprellung des Aufräumens von Gruppen-Datensätzen (#119, K4-3, vom Nutzer bestätigt): erst nach so vielen Läufen **und** so
  /// langer Zeit in `leftGroupRooms` wird der Datensatz gelöscht (das SDK meldet „Raum fehlt“ auch bei kurzen Aussetzern).
  static const int pruneRuns = 3;
  static const Duration pruneAfter = Duration(minutes: 10);

  bool _loaded = false;
  bool _enabled = false;
  bool _disposed = false;
  bool _started = false;
  List<ContactEntry> _contacts = const <ContactEntry>[];
  List<ContactRequest> _requests = const <ContactRequest>[];
  Set<String> _collidingRequests = const <String>{};
  int _hidden = 0;
  DateTime? _checkBlockedUntil;
  final Set<String> _busy = <String>{};
  bool _checking = false;

  /// Gruppen-Datensätze, deren Raum in `leftGroupRooms` steht: erste Sichtung und Zahl der Läufe (Entprellung). Nur Speicher.
  final Map<String, ({DateTime since, int seen})> _pruneSeen = <String, ({DateTime since, int seen})>{};

  /// Kennungen, deren letzte Prüfung `identityChanged` ergab (Schlüssel geändert oder Geräte von der App gesperrt, K3c-3):
  /// nur für sie gilt [addAnyway]. Jede neue Prüfung derselben Kennung ersetzt den Eintrag.
  final Set<String> _identityChecked = <String>{};

  // Neuladung: ein Lauf, Anstöße fassen zusammen.
  bool _reloading = false;
  bool _again = false;
  Future<void> _reloadDone = Future<void>.value();

  /// Die Kontakt-Kennung des eigenen Kontos (zum Kopieren).
  String get myContactId => _service.myUserId;

  /// Der Zustand ist gelesen (bis dahin zeigt die Oberfläche einen Ladeanzeiger).
  bool get loaded => _loaded;
  bool get enabled => _enabled;
  List<ContactEntry> get contacts => _contacts;
  List<ContactRequest> get requests => _requests;
  int get requestsHidden => _hidden;

  /// Gleicht der Name der Anfrage [roomId] einem Familienmitglied (§9.1)? Wird bei jedem Neuaufbau berechnet.
  bool requestCollides(String roomId) => _collidingRequests.contains(roomId);

  /// Gleicht [name] dem Anzeigenamen eines Familienmitglieds (§9.1)? Live aus der Familie des Gateways, nie gespeichert.
  bool collides(String? name) => ContactNames.collides(name, <String>[for (final m in gateway.family?.members ?? const <FamilyMember>[]) m.displayName]);

  /// Bis dahin sind „Prüfen“ und „Erneut prüfen“ gesperrt (nach `rateLimited`).
  DateTime? get checkBlockedUntil => _checkBlockedUntil;

  void start() {
    if (_started || _disposed) return;
    _started = true;
    _sync.revision.addListener(_onChanged);
    gateway.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _disposed = true;
    _pruneSeen.clear();
    if (_started) {
      _sync.revision.removeListener(_onChanged);
      gateway.removeListener(_onChanged);
    }
    super.dispose();
  }

  /// Wartet auf die laufende Neuladung (Tests).
  Future<void> idle() => _reloadDone;

  void _onChanged() {
    if (_disposed) return;
    if (_reloading) {
      _again = true;
      return;
    }
    _reloading = true;
    _reloadDone = _reload();
  }

  Future<void> _reload() async {
    try {
      do {
        _again = false;
        final enabled = await _service.isEnabled();
        final records = await _service.contacts();
        if (_disposed) return;
        await _pruneGroups(enabled);
        if (_disposed) return;
        final entries = <ContactEntry>[for (final c in records) _entryOf(c)]..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        final requests = enabled ? gateway.contactRequests : const <ContactRequest>[];
        final hidden = enabled ? gateway.contactRequestsHidden : 0;
        final colliding = <String>{for (final r in requests) if (collides(r.name)) r.roomId};
        final changed = !_loaded ||
            !setEquals(colliding, _collidingRequests) ||
            enabled != _enabled ||
            hidden != _hidden ||
            !listEquals(entries, _contacts) ||
            requests.length != _requests.length ||
            <bool>[for (var i = 0; i < requests.length; i++) requests[i].roomId != _requests[i].roomId || requests[i].fromName != _requests[i].fromName].any((b) => b);
        _loaded = true;
        _enabled = enabled;
        _contacts = entries;
        _requests = List<ContactRequest>.unmodifiable(requests);
        _collidingRequests = colliding;
        _hidden = hidden;
        if (changed) notifyListeners();
      } while (_again && !_disposed);
    } catch (e) {
      AppLog.e('contacts', 'Kontaktansicht konnte nicht geladen werden', e);
    } finally {
      _reloading = false;
    }
  }

  /// Räumt Datensätze von Gruppen auf, die verlassen oder entfernt wurden (`leftGroupRooms`), **mit Entprellung im Controller**
  /// (das Gateway meldet sofort): erst bei [pruneRuns] Läufen und [pruneAfter] Zeit, nie ohne Versionsvergleich
  /// ([ContactService.removeGroupIfVersion]), nie für unbekannte Räume (`leftGroupRooms` nennt nur Gruppen mit Datensatz, die diese
  /// Sitzung als Gruppe kannte), nie bei ausgeschaltetem Bereich und nie, solange für die Gruppe gerade [acceptGroup] läuft. Kehrt
  /// die Gruppe zurück (ID verschwindet aus der Menge), beginnt die Entprellung neu. **Folge:** auch ein echtes Entfernen durch
  /// andere bereinigt den Datensatz erst nach etwa 10 Minuten, und das Löschen gilt über den Kontodaten-Spiegel für alle Geräte.
  Future<void> _pruneGroups(bool enabled) async {
    if (!enabled) {
      _pruneSeen.clear();
      return;
    }
    final left = gateway.leftGroupRooms;
    _pruneSeen.removeWhere((id, _) => !left.contains(id));
    if (left.isEmpty) return;
    final groups = await _service.groups();
    if (_disposed) return;
    final now = _clock();
    var removed = false;
    for (final g in groups) {
      if (!left.contains(g.id) || _busy.contains(g.id)) continue;
      final seen = _pruneSeen[g.id];
      final next = (since: seen?.since ?? now, seen: (seen?.seen ?? 0) + 1);
      _pruneSeen[g.id] = next;
      if (next.seen < pruneRuns || now.difference(next.since) < pruneAfter) continue;
      if (await _service.removeGroupIfVersion(g.id, version: g.version)) {
        _pruneSeen.remove(g.id);
        removed = true;
      }
      if (_disposed) return;
    }
    if (removed) await _pushPolicy();
  }

  ChatThread? _threadOf(String id) {
    ChatThread? waiting;
    for (final t in gateway.threads) {
      if (t.kind != ThreadKind.contact || t.peerId != id) continue;
      if (!t.pending) return t;
      waiting ??= t;
    }
    return waiting;
  }

  ContactEntry _entryOf(Contact c) {
    final thread = _threadOf(c.id);
    final title = c.nick.isNotEmpty ? c.nick : (thread?.title ?? ContactNames.title(null, c.id));
    final state = switch (c.state) {
      ContactState.blocked => ContactStateView.blocked,
      ContactState.outgoing => thread == null ? ContactStateView.notSent : (thread.pending ? ContactStateView.waiting : ContactStateView.confirmed),
      ContactState.accepted => thread == null ? ContactStateView.searching : (thread.pending ? ContactStateView.waiting : ContactStateView.confirmed),
    };
    return ContactEntry(id: c.id, title: title, state: state, threadId: thread?.id, collides: thread != null && collides(thread.peerName));
  }

  Future<void> _pushPolicy() => _sync.pushPolicyNow();

  // ------------------------------------------------------------------ Einstellung

  /// Schaltet den Bereich ein oder aus. Ausschalten verbirgt Bereich und Anfragen, **löscht nichts**.
  Future<void> setEnabled(bool value) async {
    await _service.setEnabled(value);
    await _pushPolicy();
    _onChanged();
  }

  // ---------------------------------------------------------------------- Prüfen

  bool _isFamily(String id) => gateway.family?.member(id) != null;

  /// Prüft eine Eingabe. **Nur auf ausdrücklichen Tipp aufrufen** (nie je Tastendruck): Vor der Netzabfrage laufen die lokalen
  /// Prüfungen (ungültig, eigene Kennung, schon Kontakt, blockiert); erst dann fragt das Gateway den eigenen und den
  /// Fremd-Homeserver.
  Future<ContactCheck> check(String raw) async {
    final id = ContactId.parse(raw);
    if (id == null) return const ContactCheck(ContactCheckOutcome.invalid);
    _identityChecked.remove(id);
    if (id == myContactId) return ContactCheck(ContactCheckOutcome.self, userId: id);
    final existing = await _service.contact(id);
    if (existing != null && !existing.deleted) {
      return ContactCheck(existing.state == ContactState.blocked ? ContactCheckOutcome.blockedRecord : ContactCheckOutcome.duplicate, userId: id);
    }
    final family = _isFamily(id);
    if (!family && _sync.isLocallyBlocked(id)) return ContactCheck(ContactCheckOutcome.blockedLocal, userId: id);
    final until = _checkBlockedUntil;
    if (until != null && _clock().isBefore(until)) return ContactCheck(ContactCheckOutcome.rateLimited, userId: id);
    if (_checking) return ContactCheck(ContactCheckOutcome.busy, userId: id);
    _checking = true;
    try {
      final ContactProbe probe;
      try {
        probe = await gateway.probeContact(id);
      } on GatewayException catch (e) {
        switch (e.error) {
          case GatewayError.rateLimited:
            _checkBlockedUntil = _clock().add(checkCooldown);
            notifyListeners();
            return ContactCheck(ContactCheckOutcome.rateLimited, userId: id);
          case GatewayError.notAllowed:
            return ContactCheck(ContactCheckOutcome.notReady, userId: id);
          default:
            return ContactCheck(ContactCheckOutcome.unknown, userId: id);
        }
      }
      final title = ContactNames.title(probe.displayName, id);
      ContactCheck result(ContactCheckOutcome o) =>
          ContactCheck(o, userId: id, displayName: probe.displayName, title: title, collides: collides(probe.displayName));
      if (probe.isFamilyMember) return result(ContactCheckOutcome.familyMember);
      if (probe.existence == ContactExistence.no) return result(ContactCheckOutcome.notFound);
      return switch (probe.reachability) {
        ContactReachability.reachable => result(ContactCheckOutcome.ready),
        ContactReachability.notReachable => result(ContactCheckOutcome.notReachable),
        ContactReachability.identityChanged => () {
            _identityChecked.add(id);
            return result(ContactCheckOutcome.identityChanged);
          }(),
        ContactReachability.unknown => result(ContactCheckOutcome.unknown),
      };
    } finally {
      _checking = false;
    }
  }

  // ------------------------------------------------------------------ Hinzufügen

  /// Verweigert vor jedem Datensatz: Bereich aus, eigene Kennung, Familienmitglied, blockiert.
  void _requireAddable(String id) {
    if (!_enabled || id == myContactId || _isFamily(id) || _sync.isLocallyBlocked(id)) {
      throw const ContactException(ContactError.notAllowed);
    }
  }

  /// Legt den Kontakt an und den Raum: Datensatz `outgoing` → Richtlinie → `startContactChat`. Scheitert das Anlegen, wird der
  /// Datensatz zurückgenommen, **aber nur**, wenn er noch genau der von diesem Aufruf ist (Version, Zustand `outgoing`), kein
  /// Kontakt-Thread dieser Person existiert und das Anlegen nicht parallel lief (`alreadyExists`). Jede Rücknahme veröffentlicht
  /// eine Löschmarke (Version +1) im privaten Raum.
  Future<void> add(String rawId, {String nick = ''}) async {
    final id = ContactId.parse(rawId);
    if (id == null) throw const ContactException(ContactError.invalid);
    // Geänderter Schlüssel oder gesperrte Geräte: nie auf dem normalen Weg, nur über [addAnyway] (mit Bestätigung, K3c-3).
    if (_identityChecked.contains(id)) throw const GatewayException(GatewayError.notAllowed);
    await _add(id, nick: nick);
  }

  Future<void> _add(String id, {String nick = ''}) async {
    _requireAddable(id);
    if (!_busy.add(id)) return; // Doppeltipp
    try {
      final record = await _service.addOutgoing(id, nick: nick);
      await _pushPolicy();
      try {
        await gateway.startContactChat(id);
      } catch (e) {
        await _rollback(record, e);
        rethrow;
      }
    } finally {
      _busy.remove(id);
      _onChanged();
    }
  }

  /// „Trotzdem hinzufügen“ (#119, K3c-3, Pin-Sackgasse): Wie [add], aber **nur** für eine Kennung, deren letzte Prüfung
  /// `identityChanged` ergab (Schlüssel geändert oder Geräte gesperrt). Für alles andere (nicht erreichbar, unbekannt,
  /// Familienmitglied, nie geprüft) gilt `notAllowed`. Das Gateway legt den Raum an (K3c-1); **Senden bleibt gesperrt**, bis
  /// die Person geprüft und die Änderung akzeptiert ist. Scheitert das Anlegen, nimmt [add] den Datensatz zurück.
  Future<void> addAnyway(String rawId, {String nick = ''}) async {
    final id = ContactId.parse(rawId);
    if (id == null) throw const ContactException(ContactError.invalid);
    if (!_identityChecked.contains(id)) throw const ContactException(ContactError.notAllowed);
    try {
      await _add(id, nick: nick);
    } finally {
      _identityChecked.remove(id);
    }
  }

  Future<void> _rollback(Contact record, Object error) async {
    if (error is GatewayException && error.error == GatewayError.alreadyExists) return;
    if (_threadOf(record.id) != null) return; // der Raum existiert: „Erneut senden“ findet ihn
    final removed = await _service.removeIfVersion(record.id, version: record.version, state: ContactState.outgoing);
    if (removed) await _pushPolicy();
  }

  /// „Erneut senden“ für einen `outgoing`-Kontakt ohne Kontakt-Thread (nach Abbruch, auch auf einem Gerät, das den Datensatz
  /// über den privaten Raum erhielt). Idempotent: ein vorhandener Raum wird wiederverwendet.
  Future<void> retry(String id) async {
    _requireAddable(id);
    final c = await _service.contact(id);
    if (c == null || c.deleted || c.state != ContactState.outgoing) throw const ContactException(ContactError.notFound);
    if (!_busy.add(id)) return;
    try {
      await _pushPolicy();
      await gateway.startContactChat(id);
    } finally {
      _busy.remove(id);
      _onChanged();
    }
  }

  // --------------------------------------------------------------------- Anfragen

  ContactRequest? _request(String roomId) {
    for (final r in _requests) {
      if (r.roomId == roomId) return r;
    }
    return null;
  }

  /// Nimmt eine Anfrage an: Datensatz `accepted` → Richtlinie; die Auto-Annahme des Gateways tritt dann bei (mit allen
  /// Grenzen und Nachprüfung). Scheitert sie, bleibt ein Eintrag „Gespräch wird gesucht“, den man entfernen kann.
  Future<void> accept(String roomId) async {
    final r = _request(roomId);
    if (r == null) throw const ContactException(ContactError.notFound);
    // Eine Gruppenanfrage macht den Einladenden nie zum bestätigten Kontakt (I6): sie wird über [acceptGroup] angenommen.
    if (r.isGroup) throw const ContactException(ContactError.notAllowed);
    await _service.addAccepted(r.fromUserId);
    await _pushPolicy();
    _onChanged();
  }

  /// Lehnt eine Anfrage ab (verlässt die Einladung). Ist sie inzwischen weg (`notAllowed`), ist das kein Fehler.
  Future<void> decline(String roomId) async {
    try {
      await gateway.declineContactRequest(roomId);
    } on GatewayException catch (e) {
      if (e.error != GatewayError.notAllowed) rethrow;
    }
    _onChanged();
  }

  // ------------------------------------------------------------------- Gruppen (K4-3)

  /// Legt eine Gruppe an: Raum ([MatrixGateway.createGroup]) → Datensatz → Richtlinie → Einladungen. Scheitert das Schreiben des
  /// Datensatzes, verlässt der Controller den Raum wieder (D3). Die Einladungen laufen erst **nach** dem Datensatz, einzeln; ein
  /// Fehler bei einer Person bricht nie ab, jede bekommt ein Ergebnis.
  Future<GroupCreation> createGroup(String name, {List<String> invite = const <String>[]}) async {
    if (!_enabled) throw const ContactException(ContactError.notAllowed);
    final roomId = await gateway.createGroup(name);
    try {
      await _service.addGroup(roomId);
    } catch (_) {
      try {
        await gateway.leaveConversation(roomId);
      } catch (e) {
        AppLog.e('contacts', 'Gruppe konnte nach einem Fehler nicht verlassen werden (${e.runtimeType})', null);
      }
      rethrow;
    }
    await _pushPolicy();
    _onChanged();
    final results = <GroupInviteResult>[];
    for (final id in invite) {
      try {
        await gateway.inviteToGroup(roomId, id);
        results.add(GroupInviteResult(id));
      } on GatewayException catch (e) {
        results.add(GroupInviteResult(id, e.error));
      } catch (_) {
        results.add(GroupInviteResult(id, GatewayError.unknown));
      }
    }
    _onChanged();
    return GroupCreation(roomId, results);
  }

  /// Nimmt eine Gruppenanfrage an: **Datensatz zuerst**, dann Richtlinie, dann [MatrixGateway.acceptGroupInvite]. Ist schon ein
  /// aktiver Datensatz da (Absturz oder gescheiterte Richtlinie nach dem Schreiben), gilt das als gültiger Zustand und die
  /// Annahme läuft weiter. Scheitert sie, wird der Datensatz **nur zurückgenommen, wenn dieser Aufruf ihn geschrieben hat** (und
  /// nur mit dessen Version); sonst bleibt er und die Anfrage sichtbar.
  Future<void> acceptGroup(String roomId) async {
    final r = _request(roomId);
    if (r == null) throw const ContactException(ContactError.notFound);
    if (!r.isGroup) throw const ContactException(ContactError.notAllowed);
    if (!_busy.add(roomId)) return; // Doppeltipp
    try {
      GroupRecord? wrote;
      try {
        wrote = await _service.addGroup(roomId);
      } on ContactException catch (e) {
        if (e.error != ContactError.duplicate) rethrow;
      }
      _pruneSeen.remove(roomId);
      await _pushPolicy();
      try {
        await gateway.acceptGroupInvite(roomId);
      } catch (_) {
        if (wrote != null && await _service.removeGroupIfVersion(roomId, version: wrote.version)) await _pushPolicy();
        rethrow;
      }
    } finally {
      _busy.remove(roomId);
      _onChanged();
    }
  }

  /// Lehnt eine Gruppenanfrage ab (verlässt die Einladung), ohne Datensatz. Ist sie inzwischen weg (`notAllowed`), ist das kein
  /// Fehler.
  Future<void> declineGroup(String roomId) async {
    final r = _request(roomId);
    if (r == null) throw const ContactException(ContactError.notFound);
    if (!r.isGroup) throw const ContactException(ContactError.notAllowed);
    await decline(roomId);
  }

  /// Verlässt eine Gruppe: **erst den Raum verlassen**, dann den Datensatz löschen (mit Versionsvergleich). Scheitert das
  /// Verlassen, bleibt der Datensatz.
  Future<void> leaveGroup(String roomId) async {
    final record = (await _service.groups()).where((g) => g.id == roomId).firstOrNull;
    if (record == null) throw const ContactException(ContactError.notFound);
    await gateway.leaveConversation(roomId);
    _pruneSeen.remove(roomId);
    if (await _service.removeGroupIfVersion(roomId, version: record.version)) await _pushPolicy();
    _onChanged();
  }

  /// Blockiert den Absender einer Anfrage: **nur** der Datensatz; die Einladung bleibt unbeantwortet, der Absender erfährt
  /// nichts (§9.3).
  Future<void> blockRequest(String roomId) async {
    final r = _request(roomId);
    if (r == null) throw const ContactException(ContactError.notFound);
    await _service.block(r.fromUserId);
    await _sync.reconcileBlocked();
    await _pushPolicy();
    _onChanged();
  }

  // ------------------------------------------------------------- Kontakt verwalten

  ContactEntry? _entry(String id) {
    for (final e in _contacts) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Entfernt einen Kontakt (`outgoing`/`accepted`): **erst den Raum verlassen** (nur wenn ein Kontakt-Thread existiert),
  /// dann den Datensatz löschen. Scheitert das Verlassen, bleibt alles unverändert.
  Future<void> remove(String id) async {
    final entry = _entry(id);
    if (entry == null) throw const ContactException(ContactError.notFound);
    if (entry.state == ContactStateView.blocked) throw const ContactException(ContactError.notAllowed);
    final thread = entry.threadId;
    if (thread != null) await gateway.leaveConversation(thread);
    await _service.remove(id);
    await _pushPolicy();
    _onChanged();
  }

  /// Blockiert einen Kontakt: **nur** der Datensatz (der Einzelchat wird ausgeblendet, der Raum bleibt bestehen).
  Future<void> block(String id) async {
    await _service.block(id);
    await _sync.reconcileBlocked();
    await _pushPolicy();
    _onChanged();
  }

  /// Hebt eine Blockierung auf: Löschmarke und Entfernen aus der lokalen Blockierliste (nicht für Familienmitglieder).
  Future<void> unblock(String id) async {
    await _service.unblock(id);
    await _sync.forgetBlocked(id);
    await _pushPolicy();
    _onChanged();
  }

  /// Hebt eine lokale Blockierung ohne Datensatz auf (früheres Mitglied aus E-48 oder Rest eines Laufs); nie für
  /// Familienmitglieder.
  Future<void> unblockLocal(String rawId) async {
    final id = ContactId.parse(rawId);
    if (id == null) throw const ContactException(ContactError.invalid);
    if (_isFamily(id)) throw const ContactException(ContactError.notAllowed);
    await _sync.forgetBlocked(id);
    await _pushPolicy();
    _onChanged();
  }
}
