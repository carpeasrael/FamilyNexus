/// Kontolöschung aus der App heraus (#12, App Store Review Guideline 5.1.1(v)).
library;

/// Wie das eigene Konto beim Anbieter gelöscht wird.
sealed class AccountDeletion {
  const AccountDeletion();
}

/// Klassische Anmeldung mit Passwort: Löschung direkt in der App, bestätigt mit dem Passwort.
class AccountDeletionInApp extends AccountDeletion {
  const AccountDeletionInApp();
}

/// Anmeldung im Browser (OAuth, z. B. matrix.org): Die Löschung bestätigt die Person auf der
/// Kontoseite des Anbieters ([page], nur https). Clients dürfen das Konto hier nicht selbst löschen.
class AccountDeletionInBrowser extends AccountDeletion {
  const AccountDeletionInBrowser(this.page);
  final Uri page;
}
