import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Zugriff auf die IANA-Zeitzonendatenbank (im Paket gebündelt, kein Netz).
class TimeZones {
  const TimeZones._();

  static bool _ready = false;

  static void ensureInitialized() {
    if (_ready) return;
    tzdata.initializeTimeZones();
    _ready = true;
  }

  /// Liefert die Zeitzone oder `null`, wenn der Name unbekannt ist.
  static tz.Location? tryGet(String name) {
    ensureInitialized();
    if (name.isEmpty || name.length > 64) return null;
    // Rückfallname der Gerätezeitzone; fehlt als Eintrag in der Datenbank, ist aber eine gültige Zone.
    if (name == 'UTC') return tz.UTC;
    try {
      return tz.getLocation(name);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  static tz.Location get utc {
    ensureInitialized();
    return tz.UTC;
  }
}
