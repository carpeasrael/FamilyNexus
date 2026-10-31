/// Passwort des eigenen Kontos ändern (#117, E-80).
library;

/// Wie das Passwort des angemeldeten Kontos geändert wird.
sealed class PasswordChange {
  const PasswordChange();

  /// Mindestlänge der App, auch bei der Kontoanlage.
  static const int minLength = 8;

  /// Längere Passwörter lehnt Synapse ab.
  static const int maxLength = 512;
}

/// Klassische Anmeldung mit Passwort: Änderung direkt in der App, bestätigt mit dem aktuellen Passwort.
class PasswordChangeInApp extends PasswordChange {
  const PasswordChangeInApp();
}

/// Anmeldung im Browser (OAuth, z. B. matrix.org): Das Passwort liegt beim Anbieter und wird auf
/// dessen Kontoseite ([page], nur https) geändert.
class PasswordChangeInBrowser extends PasswordChange {
  const PasswordChangeInBrowser(this.page);
  final Uri page;
}

/// Weder in der App noch auf einer bekannten Kontoseite möglich.
class PasswordChangeUnavailable extends PasswordChange {
  const PasswordChangeUnavailable();
}
