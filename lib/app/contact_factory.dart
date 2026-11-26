import '../data/matrix/matrix_gateway.dart';
import '../data/sync/contact_sync.dart';
import '../domain/contact_service.dart';
import '../domain/contact_store.dart';
import '../domain/contacts.dart';
import '../features/contacts/contact_controller.dart';

/// Die Kontakt-Dienste eines Kontos (#119, E-114, K3c-2): Synchronisation und Oberfläche. Sie gehören zum Konto, nicht zur
/// Familie und nicht zum Kalender; `AppServices.openContacts`/`closeContacts` steuern ihren Lebenszyklus.
class ContactServices {
  ContactServices({required this.sync, required this.controller});

  final ContactSync sync;
  final ContactController controller;

  /// Startet erst die Synchronisation (sie liefert Richtlinie und Änderungen), dann den Controller.
  void start() {
    sync.start();
    controller.start();
  }

  /// Beendet zuerst den Controller: Danach darf kein Aufruf mehr an Gateway oder Dienst gehen.
  void dispose() {
    controller.dispose();
    sync.dispose();
  }

  /// Wartet, bis die bereits eingegangenen Signale verarbeitet sind (Schließen, #140/#153).
  Future<void> idle() => sync.idle();
}

/// Baut die Kontakt-Dienste für [userId]. Ohne [contactStore] oder bei gesperrter Freigabe ([contactsEnabled],
/// Standard `ContactFlags.enabled`) entsteht nichts: `null`, weder Dienst noch Synchronisation.
ContactServices? buildContactServices({
  required MatrixGateway gateway,
  required String userId,
  ContactStore? contactStore,
  bool contactsEnabled = ContactFlags.enabled,
  BlockedListPort? blockedList,
  DateTime Function()? clock,
  Duration retryInterval = const Duration(seconds: 60),
}) {
  if (contactStore == null || !contactsEnabled) return null;
  final sync = ContactSync(
    gateway: gateway,
    service: ContactService(store: contactStore, myUserId: userId, clock: clock),
    store: contactStore,
    blockedList: blockedList,
    clock: clock,
    retryInterval: retryInterval,
  );
  return ContactServices(sync: sync, controller: ContactController(gateway: gateway, sync: sync, clock: clock));
}
