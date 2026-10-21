import '../data/matrix/matrix_gateway.dart';
import '../data/sync/calendar_sync.dart';
import '../domain/calendar_service.dart';
import '../domain/event_store.dart';
import '../features/calendar/calendar_controller.dart';

/// Baut Dienst, Synchronisation und Controller für einen Nutzer zusammen.
CalendarController buildCalendarController({
  required EventStore store,
  required MatrixGateway gateway,
  required String userId,
  required String zoneName,
  DateTime Function()? clock,
  Duration retryInterval = const Duration(seconds: 60),
}) {
  final service = CalendarService(store: store, myUserId: userId, clock: clock);
  final sync = CalendarSync(
    gateway: gateway,
    service: service,
    store: store,
    clock: clock,
    retryInterval: retryInterval,
  );
  return CalendarController(
    service: service,
    store: store,
    sync: sync,
    gateway: gateway,
    zoneName: zoneName,
    clock: clock,
  );
}
