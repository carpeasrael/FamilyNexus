import '../data/matrix/matrix_gateway.dart';
import '../data/sync/anniversary_sync.dart';
import '../data/sync/avatar_photo_sync.dart';
import '../data/sync/calendar_sync.dart';
import '../data/sync/cash_book_sync.dart';
import '../data/sync/event_theme_sync.dart';
import '../domain/anniversary_service.dart';
import '../domain/anniversary_store.dart';
import '../domain/avatar_photo.dart';
import '../domain/avatar_photo_service.dart';
import '../domain/avatar_photo_store.dart';
import '../domain/calendar_service.dart';
import '../domain/cash_book.dart';
import '../domain/cash_book_service.dart';
import '../domain/cash_book_store.dart';
import '../domain/event_store.dart';
import '../domain/event_theme_service.dart';
import '../domain/event_theme_store.dart';
import '../domain/family.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/family/avatar_photo_images.dart';

/// Baut Dienst, Synchronisation und Controller für einen Nutzer zusammen.
///
/// Mit [themeStore] entstehen zusätzlich Dienst und Synchronisation der Kalender-Themen (E-99). [isModerator]
/// liefert, ob eine Person aktuell Moderator der Familie ist; ohne Angabe ist niemand Moderator. Mit [anniversaryStore]
/// entstehen Dienst und Synchronisation der Geburts- und Gedenktage (E-104); „heute“ kommt aus dem Controller.
CalendarController buildCalendarController({
  required EventStore store,
  required MatrixGateway gateway,
  required String userId,
  required String zoneName,
  DateTime Function()? clock,
  Duration retryInterval = const Duration(seconds: 60),
  EventThemeStore? themeStore,
  AnniversaryStore? anniversaryStore,
  AvatarPhotoStore? avatarPhotoStore,
  String? familyRoom,
  bool Function(String userId)? isModerator,
  Role? Function(String userId)? roleOf,
  bool avatarPhotosEnabled = AvatarPhotoFlags.enabled,
  CashBookStore? cashBookStore,
  bool cashBooksEnabled = CashBookFlags.enabled,
}) {
  final service = CalendarService(store: store, myUserId: userId, clock: clock, roleOf: roleOf ?? ((_) => null));
  final sync = CalendarSync(
    gateway: gateway,
    service: service,
    store: store,
    clock: clock,
    retryInterval: retryInterval,
  );
  late final CalendarController controller;
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
  AnniversaryService? anniversaries;
  AnniversarySync? anniversarySync;
  if (anniversaryStore != null) {
    // Eine Quelle für „heute“: dieselbe Zonenauflösung und Uhr wie der Controller; die Closure wird erst nach
    // der Zuweisung von `controller` aufgerufen.
    anniversaries = AnniversaryService(
      store: anniversaryStore,
      myUserId: userId,
      today: () => controller.today,
      clock: clock,
    );
    anniversarySync = AnniversarySync(
      gateway: gateway,
      service: anniversaries,
      store: anniversaryStore,
      clock: clock,
      retryInterval: retryInterval,
    );
  }
  // Avatar-Fotos (#434, E-111): nur mit Ablage und bekannter Familie; die Sync-Klasse bleibt bis zur Freigabe inaktiv.
  AvatarPhotoService? avatarPhotos;
  AvatarPhotoSync? avatarPhotoSync;
  AvatarPhotoImages? avatarPhotoImages;
  if (avatarPhotoStore != null && familyRoom != null) {
    avatarPhotos = AvatarPhotoService(
      store: avatarPhotoStore,
      roomId: familyRoom,
      myUserId: userId,
      isModerator: isModerator ?? (_) => false,
      isMember: (id) => gateway.family?.member(id)?.status == MemberStatus.joined,
      clock: clock,
    );
    avatarPhotoImages = AvatarPhotoImages(avatarPhotos);
    avatarPhotoSync = AvatarPhotoSync(
      gateway: gateway,
      service: avatarPhotos,
      store: avatarPhotoStore,
      enabled: avatarPhotosEnabled,
      clock: clock,
      retryInterval: retryInterval,
    );
  }
  // Kassenbuch (#311, E-113): nur mit Ablage und bekannter Familie; die Sync-Klasse bleibt bis zur Freigabe inaktiv.
  CashBookService? cashBooks;
  CashBookSync? cashBookSync;
  if (cashBookStore != null && familyRoom != null) {
    cashBooks = CashBookService(store: cashBookStore, myUserId: userId, clock: clock);
    cashBookSync = CashBookSync(
      gateway: gateway,
      service: cashBooks,
      store: cashBookStore,
      familyRoom: familyRoom,
      enabled: cashBooksEnabled,
      clock: clock,
      retryInterval: retryInterval,
    );
  }
  controller = CalendarController(
    service: service,
    store: store,
    sync: sync,
    gateway: gateway,
    zoneName: zoneName,
    clock: clock,
    themes: themes,
    themeSync: themeSync,
    anniversaries: anniversaries,
    anniversarySync: anniversarySync,
    avatarPhotos: avatarPhotos,
    avatarPhotoSync: avatarPhotoSync,
    avatarPhotoImages: avatarPhotoImages,
    cashBooks: cashBooks,
    cashBookSync: cashBookSync,
  );
  return controller;
}
