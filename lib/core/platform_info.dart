import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Plattformabfragen, die im Browser nicht an `dart:io` scheitern (`Platform` wirft dort).
class PlatformInfo {
  const PlatformInfo._();

  static bool get isWeb => kIsWeb;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWindows => !kIsWeb && Platform.isWindows;

  /// Linux, Windows und Browser: SQLCipher/SQLite3MultipleCiphers über `sqflite_common_ffi(_web)`.
  static bool get usesFfiDatabase => kIsWeb || isLinux || isWindows;

  /// Kein Schutz vor Bildschirmaufnahmen (SA-6, SA-7).
  static bool get hasNoScreenProtection => kIsWeb || isLinux || isWindows;

  /// Keine Geräteanmeldung für die App-Sperre (Linux, Browser).
  static bool get hasNoDeviceAuth => kIsWeb || isLinux;

  /// Erinnerungen nur in der laufenden App (Linux, Windows); im Browser gar nicht.
  static bool get usesInAppReminders => isLinux || isWindows;
}
