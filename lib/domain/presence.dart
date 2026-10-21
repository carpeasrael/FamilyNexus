import 'server.dart';

/// Zuletzt gemeldeter Zustand eines Mitglieds mit Zeitpunkt auf der Uhr des Absenders.
class PresenceStamp {
  const PresenceStamp({required this.online, required this.at});
  final bool online;
  final DateTime at;
}

enum PresenceStatus {
  online,
  offline,

  /// Es liegt (noch) keine Meldung vor.
  unknown,
}

/// Ausgewerteter Zustand zu einem Zeitpunkt.
class PresenceInfo {
  const PresenceInfo(this.status, [this.lastSeen]);
  final PresenceStatus status;

  /// Zeitpunkt der letzten Meldung, solange das Mitglied nicht online ist.
  final DateTime? lastSeen;

  static const PresenceInfo unknown = PresenceInfo(PresenceStatus.unknown);
}

/// Ereignisformat v1 des Online-Status (E-38).
///
/// Wird ausschließlich als Ende-zu-Ende-verschlüsselte Gerätenachricht gesendet; der Inhalt ist
/// nicht vertrauenswürdig und wird streng geprüft.
class PresenceCodec {
  const PresenceCodec._();

  static const String type = 'de.inneso.familynexus.presence';
  static const int schema = 1;

  /// Abstand der Lebenszeichen im Vordergrund.
  static const Duration heartbeat = Duration(seconds: 120);

  /// So lange gilt „online“ ohne neues Lebenszeichen.
  static const Duration validity = Duration(seconds: 300);

  /// Toleranz für Uhren, die der Absender vorausgeht.
  static const Duration maxFutureSkew = Duration(seconds: 60);

  static Map<String, Object?> encode({required bool online, required DateTime now, bool ask = false}) =>
      <String, Object?>{
        'v': schema,
        'state': online ? 'online' : 'offline',
        'ts': now.toUtc().millisecondsSinceEpoch,
        // Die Bitte um Antwort gibt es nur zusammen mit „online“.
        if (online && ask) 'ask': true,
      };

  /// `null` bei ungültigem, zu altem oder zu weit in der Zukunft liegendem Inhalt.
  static ({bool online, DateTime at, bool ask})? decode(Map<String, Object?> c, {required DateTime now}) {
    if (c['v'] != schema) return null;
    final state = c['state'];
    final ts = c['ts'];
    final ask = c['ask'];
    if (state != 'online' && state != 'offline') return null;
    if (ts is! int) return null;
    if (ask != null && ask is! bool) return null;
    final online = state == 'online';
    if (ask == true && !online) return null;
    // Vor dem Umrechnen begrenzen (kein Überlauf bei absurden Zahlen).
    if (ts < 0 || ts > 4102444800000) return null;
    final at = DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true);
    final n = now.toUtc();
    if (at.isBefore(n.subtract(validity)) || at.isAfter(n.add(maxFutureSkew))) return null;
    return (online: online, at: at, ask: ask == true);
  }
}

/// Letzter bekannter Zustand je Mitglied und Gerät (nur im Arbeitsspeicher). Ein Mitglied mit
/// mehreren Geräten gilt als online, solange irgendein Gerät aktuell „online“ meldet.
class PresenceBoard {
  final Map<String, Map<String, PresenceStamp>> _stamps = <String, Map<String, PresenceStamp>>{};

  /// Höchstzahl beobachteter Absender und Geräte je Absender (Speicherschutz).
  static const int maxEntries = 200;
  static const int maxDevicesPerUser = 20;

  /// Gesamtzustand eines Mitglieds zum Zeitpunkt [now] (oder `null`).
  PresenceStamp? stampOf(String userId, DateTime now) {
    final devices = _stamps[userId];
    if (devices == null || devices.isEmpty) return null;
    PresenceStamp? bestOnline;
    PresenceStamp? latest;
    for (final s in devices.values) {
      if (latest == null || s.at.isAfter(latest.at)) latest = s;
      if (s.online && now.toUtc().difference(s.at) <= PresenceCodec.validity && (bestOnline == null || s.at.isAfter(bestOnline.at))) {
        bestOnline = s;
      }
    }
    return bestOnline ?? latest;
  }

  PresenceStamp? operator [](String userId) => stampOf(userId, DateTime.now());

  Map<String, PresenceStamp> snapshot([DateTime? now]) {
    final n = now ?? DateTime.now();
    return <String, PresenceStamp>{
      for (final u in _stamps.keys) u: ?stampOf(u, n),
    };
  }

  /// Übernimmt eine Meldung von [deviceId], wenn sie neuer ist als die bekannte dieses Geräts.
  /// `true` bei Änderung.
  bool apply(String userId, {String deviceId = '', required bool online, required DateTime at}) {
    if (!MatrixIds.isUserId(userId) || deviceId.length > 100) return false;
    if (!_stamps.containsKey(userId) && _stamps.length >= maxEntries) return false;
    final devices = _stamps.putIfAbsent(userId, () => <String, PresenceStamp>{});
    final old = devices[deviceId];
    if (old == null && devices.length >= maxDevicesPerUser) return false;
    if (old != null && !at.isAfter(old.at)) return false;
    devices[deviceId] = PresenceStamp(online: online, at: at);
    return true;
  }

  /// Entfernt Einträge von Personen, die nicht (mehr) zur Familie gehören. `true` bei Änderung.
  bool retainOnly(Set<String> userIds) {
    final before = _stamps.length;
    _stamps.removeWhere((k, _) => !userIds.contains(k));
    return _stamps.length != before;
  }

  void clear() => _stamps.clear();

  /// Wertet eine Meldung zum Zeitpunkt [now] aus: „online“ gilt nur [PresenceCodec.validity] lang.
  static PresenceInfo evaluate(PresenceStamp? s, DateTime now) {
    if (s == null) return PresenceInfo.unknown;
    // Eine leicht vorausgehende Absenderuhr ergibt ein negatives Alter und zählt als aktuell.
    if (s.online && now.toUtc().difference(s.at) <= PresenceCodec.validity) {
      return const PresenceInfo(PresenceStatus.online);
    }
    return PresenceInfo(PresenceStatus.offline, s.at);
  }
}
