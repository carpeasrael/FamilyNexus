import 'package:matrix/matrix.dart';

import '../../core/app_log.dart';

/// Öffentliche Lesemarker anderer Mitglieder eines Raums, ausgewertet für eigene Nachrichten (#526, E-106).
///
/// Ein Marker steht für die Nachricht und alle davor (Matrix-Semantik). Die Position bestimmt die geladene Zeitleiste
/// über **alle** Ereignistypen; liegt das Ereignis des Markers nicht im Fenster, entscheidet der Zeitstempel des
/// Markers gegen den der Nachricht. Mitglied ist nur, wer laut Raumzustand beigetreten ist: Fehlt das
/// Member-Ereignis (Lazy Loading) oder ist es `leave`, `invite` oder `ban`, zählt der Marker nicht. Kein Netzwerkzugriff.
class ReadMarkers {
  ReadMarkers._(this._byUser, this._position);

  /// Nutzer-ID → seine Marker (Hauptzeitleiste und globale; der spätere gilt).
  final Map<String, List<LatestReceiptStateData>> _byUser;

  /// Ereignis-ID → Index in `timeline.events` (0 = neuestes).
  final Map<String, int> _position;

  static final ReadMarkers none = ReadMarkers._(const <String, List<LatestReceiptStateData>>{}, const <String, int>{});

  /// Ohne Marker beigetretener Mitglieder entsteht [none].
  static ReadMarkers of(Timeline timeline, String? me) {
    try {
      final room = timeline.room;
      final state = room.receiptState;
      final byUser = <String, List<LatestReceiptStateData>>{};
      void collect(LatestReceiptStateForTimeline? t) {
        if (t == null) return;
        for (final e in t.otherUsers.entries) {
          if (e.key == me) continue;
          if (room.getState(EventTypes.RoomMember, e.key)?.content['membership'] != 'join') continue;
          byUser.putIfAbsent(e.key, () => <LatestReceiptStateData>[]).add(e.value);
        }
      }

      collect(state.global);
      collect(state.mainThread);
      if (byUser.isEmpty) return none;
      final position = <String, int>{};
      final events = timeline.events;
      for (var i = 0; i < events.length; i++) {
        position.putIfAbsent(events[i].eventId, () => i);
      }
      return ReadMarkers._(byUser, position);
    } catch (err) {
      AppLog.e('chat', 'Lesemarker konnten nicht gelesen werden', err);
      return none;
    }
  }

  /// Mitglieder, die [e] gelesen haben.
  Set<String> readersOf(Event e) {
    if (_byUser.isEmpty) return const <String>{};
    final index = _position[e.eventId];
    final out = <String>{};
    for (final u in _byUser.entries) {
      for (final marker in u.value) {
        final at = _position[marker.eventId];
        final read = at != null && index != null ? at <= index : marker.ts >= e.originServerTs.millisecondsSinceEpoch;
        if (read) {
          out.add(u.key);
          break;
        }
      }
    }
    return out;
  }
}
