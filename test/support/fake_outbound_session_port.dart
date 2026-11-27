import 'dart:async';

import 'package:family_nexus/data/matrix/outbound_session_port.dart';

/// Nachbildung der Außensitzung des SDK 14.2.0 für den Test des Schlüsselwischs (#119, K4-2b, §3.3a), **nach den gelesenen
/// Zeilen** von `key_manager.dart`, nicht nach einem Lauf des echten SDK (vodozemac braucht native Bibliotheken; dieser
/// Fake belegt nur die **Ablauflogik** des Gateways: Laden, Wisch, Beleg, Entsperren):
///
///  * Eine „persistierte“ Sitzung ([persisted], die Datenbank) ist erst nach [load] im Speicher sichtbar ([recipients]).
///  * [load] wirkt **einmal je Raum**, auch nach einer Ausnahme (`_loadedOutboundGroupSessions`, `key_manager.dart:616-621`):
///    nach einem Fehler bleibt die persistierte Sitzung für den Rest des Prozesses unsichtbar.
///  * [wipe] wirkt **nur auf Geladenes**; sonst ist es ein No-op ohne Fehler (`key_manager.dart:324-326`, die SDK-Methode gibt
///    dort `true` zurück). Der Fake lädt in [wipe] **nicht** selbst: das Laden ist Sache des Aufrufers (Gateway).
class FakeOutboundSessionPort implements OutboundSessionPort {
  /// „Datenbank“: Raum-ID → Nutzer, denen die Sitzung Schlüssel gegeben hat.
  final Map<String, Set<String>> persisted = <String, Set<String>>{};

  final Map<String, Set<String>> _memory = <String, Set<String>>{};
  final Set<String> _loaded = <String>{};

  /// Aufrufe in der Reihenfolge, z. B. `load:!r`, `wipe:!r`.
  final List<String> log = <String>[];

  /// Gesetzt: [load] wirft beim **ersten** Laden des Raums diese Ausnahme (danach wirkt es nie wieder, wie im SDK).
  Object? loadError;

  /// [wipe] wirft.
  Object? wipeError;

  /// Gesetzt: [wipe] wartet, bis die Zukunft endet (Wechsel läuft, Fenster-Test).
  Completer<void>? holdWipe;

  /// [wipe] bleibt ohne Wirkung (Sitzung bleibt im Speicher), ohne Fehler: das SDK sah `room == null` oder legte neu an.
  bool wipeIneffective = false;

  int get wipes => log.where((l) => l.startsWith('wipe:')).length;
  int get loads => log.where((l) => l.startsWith('load:')).length;

  /// Wie ein Senden im SDK: legt (im Speicher und in der Datenbank) eine Sitzung für [users] an.
  void createSession(String roomId, Set<String> users) {
    persisted[roomId] = users.toSet();
    _memory[roomId] = users.toSet();
    _loaded.add(roomId);
  }

  @override
  Future<void> load(String roomId) async {
    log.add('load:$roomId');
    if (_loaded.contains(roomId) || _memory.containsKey(roomId)) return;
    _loaded.add(roomId);
    final err = loadError;
    if (err != null) {
      loadError = null;
      throw err;
    }
    final p = persisted[roomId];
    if (p != null) _memory[roomId] = p.toSet();
  }

  @override
  Set<String>? recipients(String roomId) => _memory[roomId]?.toSet();

  @override
  Future<void> wipe(String roomId) async {
    log.add('wipe:$roomId');
    await holdWipe?.future;
    final err = wipeError;
    if (err != null) throw err;
    if (wipeIneffective) return;
    if (!_memory.containsKey(roomId)) return; // nichts geladen: No-op ohne Fehler
    _memory.remove(roomId);
    persisted.remove(roomId);
  }
}
