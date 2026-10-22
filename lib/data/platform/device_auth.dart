import 'package:local_auth/local_auth.dart';

import '../../core/app_log.dart';

/// Authentifizierung mit den Geräteanmeldedaten des Betriebssystems (PIN, Muster,
/// Passwort oder Biometrie). Die App speichert selbst keine PIN (E-17).
abstract class DeviceAuth {
  /// `true`, wenn das Gerät eine gesicherte Sperre eingerichtet hat.
  Future<bool> isAvailable();

  /// Fragt die Geräteanmeldedaten ab. Liefert `false` bei Abbruch/Fehler.
  Future<bool> authenticate(String reason);
}

class LocalDeviceAuth implements DeviceAuth {
  LocalDeviceAuth([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      AppLog.e('lock', 'Geräteprüfung fehlgeschlagen', e);
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on LocalAuthException catch (e) {
      AppLog.w('lock', 'Authentifizierung nicht erfolgreich (${e.code.name})');
      return false;
    } catch (e) {
      AppLog.e('lock', 'Authentifizierung fehlgeschlagen', e);
      return false;
    }
  }
}

/// Plattform ohne Geräteanmeldung für Apps (Linux, SA-6): Die App-Sperre lässt sich nicht einschalten.
class UnavailableDeviceAuth implements DeviceAuth {
  const UnavailableDeviceAuth();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}
