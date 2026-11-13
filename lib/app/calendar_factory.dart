import '../data/matrix/matrix_gateway.dart';
import '../data/sync/calendar_sync.dart';
import '../data/sync/event_theme_sync.dart';
import '../domain/calendar_service.dart';
import '../domain/event_store.dart';
import '../domain/event_theme_service.dart';
import '../domain/event_theme_store.dart';
import '../features/calendar/calendar_controller.dart';

/// Baut Dienst, Synchronisation und Controller für einen Nutzer zusammen.
///
/// Mit [themeStore] entstehen zusätzlich Dienst und Synchronisation der Kalender-Themen (E-99). [isModerator]
/// liefert, ob eine Person aktuell Moderator der Familie ist; ohne Angabe ist niemand Moderator.
CalendarController buildCalendarController({
  required EventStore store,
  required MatrixGateway gateway,
  required String userId,
  required String zoneName,
  DateTime Function()? clock,
  Duration retryInterval = const Duration(seconds: 60),
  EventThemeStore? themeStore,
  bool Function(String userId)? isModerator,
}) {
  final service = CalendarService(store: store, myUserId: userId, clock: clock);
  final sync = CalendarSync(
    gateway: gateway,
    service: service,
    store: store,
    clock: clock,
    retryInterval: retryInterval,
  );
  EventThemeService? themes;
  EventThemeSync? themeSync;
  if (themeStore != null) {
    themes = EventThemeService(
      store: themeStore,
      myUserId: userId,
      isModerator: isModerator ?? (_) => false,
      clock: clock,
    );
    themeSync = EventThemeSync(
      gateway: gateway,
      service: themes,
      store: themeStore,
      clock: clock,
      retryInterval: retryInterval,
    );
  }
  return CalendarController(
    service: service,
    store: store,
    sync: sync,
    gateway: gateway,
    zoneName: zoneName,
    clock: clock,
    themes: themes,
    themeSync: themeSync,
  );
}
