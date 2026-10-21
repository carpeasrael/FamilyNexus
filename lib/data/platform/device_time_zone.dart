import 'package:flutter_timezone/flutter_timezone.dart';

import '../../core/app_log.dart';
import '../../domain/time_zones.dart';

/// Zeitzone des Geräts (IANA-Name). Android-Brücke hinter Schnittstelle.
abstract class DeviceTimeZone {
  Future<String> current();
}

class SystemDeviceTimeZone implements DeviceTimeZone {
  @override
  Future<String> current() async {
    try {
      final id = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (TimeZones.tryGet(id) != null) return id;
    } catch (e) {
      AppLog.e('tz', 'Gerätezeitzone nicht ermittelbar', e);
    }
    return 'UTC';
  }
}
