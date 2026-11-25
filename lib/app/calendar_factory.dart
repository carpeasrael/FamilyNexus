import '../data/matrix/matrix_gateway.dart';
import '../data/platform/file_access.dart';
import '../data/sync/anniversary_sync.dart';
import '../data/sync/avatar_photo_sync.dart';
import '../data/sync/calendar_sync.dart';
import '../data/sync/cash_book_receipts.dart';
import '../data/sync/cash_book_sync.dart';
import '../data/sync/contact_sync.dart';
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
import '../domain/contact_service.dart';
import '../domain/contact_store.dart';
import '../domain/contacts.dart';
import '../domain/event_store.dart';
import '../domain/event_theme_service.dart';
import '../domain/event_theme_store.dart';
import '../domain/family.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/cashbook/cash_book_controller.dart';
import '../features/contacts/contact_controller.dart';
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
  ContactStore? contactStore,
  bool contactsEnabled = ContactFlags.enabled,
  BlockedListPort? blockedList,
  FileAccess? files,
  String cashBookCurrency = 'EUR',
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
  CashBookReceipts? cashBookReceipts;
  CashBookController? cashBookController;
  if (cashBookStore != null && familyRoom != null) {
    cashBooks = CashBookService(store: cashBookStore, myUserId: userId, clock: clock);
    cashBookReceipts = CashBookReceipts(
      gateway: gateway,
      service: cashBooks,
      store: cashBookStore,
      enabled: cashBooksEnabled,
      clock: clock,
    );
    cashBookSync = CashBookSync(
      gateway: gateway,
      receipts: cashBookReceipts,
      service: cashBooks,
      store: cashBookStore,
      familyRoom: familyRoom,
      enabled: cashBooksEnabled,
      clock: clock,
      retryInterval: retryInterval,
    );
    cashBookController = CashBookController(
      gateway: gateway,
      service: cashBooks,
      store: cashBookStore,
      sync: cashBookSync,
      receipts: cashBookReceipts,
      enabled: cashBooksEnabled,
      // Der Monat „laufend“ zählt nach dem lokalen Datum des Geräts, wie der Rest des Kalenders.
      today: () => controller.today,
      files: files,
      currencyFallback: cashBookCurrency,
    );
  }
  // Kontakte außerhalb der Familie (#119, E-114): gehören zum Konto, nicht zur Familie (auch ohne Familie); bis zur Freigabe
  // (`ContactFlags.enabled`) entstehen weder Dienst noch Synchronisation.
  ContactSync? contactSync;
  ContactController? contactController;
  if (contactStore != null && contactsEnabled) {
    contactSync = ContactSync(
      gateway: gateway,
      service: ContactService(store: contactStore, myUserId: userId, clock: clock),
      store: contactStore,
      blockedList: blockedList,
      clock: clock,
      retryInterval: retryInterval,
    );
    contactController = ContactController(gateway: gateway, sync: contactSync, clock: clock);
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
    cashBookReceipts: cashBookReceipts,
    cashBookController: cashBookController,
    contactSync: contactSync,
    contactController: contactController,
  );
  return controller;
}
