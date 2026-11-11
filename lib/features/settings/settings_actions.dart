import '../../data/matrix/matrix_gateway.dart';
import '../../domain/app_settings.dart';
import '../../domain/data_inventory.dart';
import '../../domain/security.dart';
import 'settings_controller.dart';

/// Aktionen der Einstellungen ohne Oberfläche (AP-6a). Der Zustand der Einstellungen liegt schon im
/// [SettingsController]; hier stehen die Abläufe, die über ihn hinausgehen: Standard-Erinnerungen, Meldungen zu Chat und
/// Einkauf (mit Berechtigung und neuer Planung), Gerätesicherheit und die Speicherorte. Abhängigkeiten kommen über den
/// Konstruktor; die Klasse hält keinen eigenen Zustand und ist deshalb kein `ChangeNotifier`.
class SettingsActions {
  SettingsActions({
    required this.settings,
    required this.gateway,
    this.inventory,
    this.requestNotifications,
    this.reschedule,
  });

  final SettingsController settings;
  final MatrixGateway gateway;

  /// Speicherorte; `null` im Browser.
  final LocalDataInventory? inventory;

  /// Fragt die Berechtigung für Benachrichtigungen an (ohne genaue Alarme); `null` ohne Plattform-Meldungen.
  final Future<void> Function()? requestNotifications;

  /// Plant alle Erinnerungen und Meldungen neu; `null`, solange es keinen Koordinator gibt.
  final Future<void> Function()? reschedule;

  /// Schaltet die Minute [minutes] der Standard-Erinnerungen ein oder aus; gespeichert wird absteigend sortiert.
  Future<void> setDefaultReminder(int minutes, {required bool on}) {
    final next = <int>{...settings.settings.defaultReminderMinutes};
    on ? next.add(minutes) : next.remove(minutes);
    return settings.update((s) => s.copyWith(defaultReminderMinutes: next.toList()..sort((a, b) => b.compareTo(a))));
  }

  Future<void> setNotifyChat({required bool on}) => _enable((c) => c.copyWith(notifyChat: on), on);

  Future<void> setNotifyShopping({required bool on}) => _enable((c) => c.copyWith(notifyShopping: on), on);

  /// Speichert die Einstellung; beim Einschalten wird danach die Berechtigung angefragt und neu geplant.
  Future<void> _enable(AppSettings Function(AppSettings) change, bool on) async {
    await settings.update(change);
    if (!on) return;
    await requestNotifications?.call();
    await reschedule?.call();
  }

  /// Die Speicherorte der lokalen Daten; `null` ohne Bestandsabfrage.
  Future<StorageLocations>? storageLocations() => inventory?.locations();

  /// Frischt die Geräteliste auf; Fehler bleiben unbeachtet (die Liste zeigt den letzten Stand).
  void refreshSecurity() => gateway.refreshSecurity().ignore();

  /// Startet die Verifizierung von [device]. Gibt den Fehler zurück, wenn sie scheitert; die Oberfläche macht daraus
  /// einen Text. `null` bei Erfolg.
  Future<Object?> verifyDevice(DeviceEntry device) async {
    try {
      await gateway.startVerification(userId: device.userId, deviceId: device.deviceId);
      return null;
    } catch (e) {
      return e;
    }
  }
}
