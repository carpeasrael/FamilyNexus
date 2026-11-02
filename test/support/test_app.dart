import 'dart:typed_data';

import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/app/calendar_factory.dart';
import 'package:family_nexus/data/sync/shopping_sync.dart';
import 'package:family_nexus/features/calendar/calendar_controller.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/features/shopping/shopping_controller.dart';
import 'package:family_nexus/data/sync/task_sync.dart';
import 'package:family_nexus/domain/permissions.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/features/tasks/tasks_controller.dart';
import 'package:family_nexus/data/platform/file_access.dart';
import 'package:family_nexus/features/lock/app_lock_controller.dart';
import 'package:family_nexus/data/platform/screen_protection.dart';
import 'package:family_nexus/domain/data_inventory.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/settings/settings_controller.dart';

import 'fake_browser.dart';
import 'fake_device_auth.dart';
import 'fake_links.dart';
import 'fake_mail.dart';
import 'fake_matrix.dart';
import 'fake_scheduler.dart';
import 'memory_event_store.dart';
import 'memory_shopping_store.dart';
import 'memory_task_store.dart';
import 'memory_stores.dart';

class TestApp {
  TestApp({
    required this.services,
    required this.protection,
    required this.server,
    required this.gateway,
    required this.store,
    required this.events,
    required this.shoppingStore,
    required this.taskStore,
    required this.scheduler,
    required this.links,
    required this.auth,
    required this.mail,
    required this.browser,
    required this.element,
    required this.oauth,
    required this.calendarRooms,
    required this.shoppingRooms,
    required this.taskRooms,
    required this.builtCalendars,
    required this.builtShopping,
    required this.builtTasks,
  });

  final AppServices services;
  final NoopScreenProtection protection;
  final FakeMatrixServer server;
  final FakeMatrixGateway gateway;
  final MemoryKeyValueStore store;
  final MemoryEventStore events;
  final MemoryShoppingStore shoppingStore;
  final MemoryTaskStore taskStore;
  final FakeReminderScheduler scheduler;
  final FakeLinkSource links;
  final FakeDeviceAuth auth;
  final FakeMailLauncher mail;
  final FakeBrowser browser;
  final FakeElement element;
  final FakeOAuthRedirect oauth;

  /// Räume, die `AppServices` den Buildern übergeben hat, je Aufruf (#140).
  final List<String?> calendarRooms;
  final List<String?> shoppingRooms;
  final List<String?> taskRooms;

  /// Gebaute Controller, auch die eines verworfenen Öffnungslaufs.
  final List<CalendarController> builtCalendars;
  final List<ShoppingController> builtShopping;
  final List<TasksController> builtTasks;
}

/// Baut die App-Dienste mit Fake-Matrix. `loggedIn: true` legt zusätzlich
/// Anmeldung und Familie an und markiert die Einrichtung als abgeschlossen.
Future<TestApp> buildTestApp({
  String? lang = 'de',
  bool loggedIn = true,
  FakeMatrixServer? server,
  DateTime Function()? clock,
  ScreenProtection? screenProtection,
  bool secureScreen = true,
  bool lockEnabled = false,
  String? defaultProvider,
  bool matrixOrgDefault = false,
  // false: wie im Browser (E-53) – AppServices ohne Scheduler, `services.reminders` ist null. `TestApp.scheduler` bleibt befüllt.
  bool withReminders = true,
  // Test: Familiendienste schlagen beim Öffnen fehl (#153).
  Future<void> Function(String uid)? beforeCalendarBuild,
  Future<void> Function(String uid)? beforeShoppingBuild,
  Future<void> Function(String uid)? beforeTasksBuild,
  // Test: Besitzer der lokalen Daten (#140). Ohne Angabe wie ohne Datenbank: kein Anspruch.
  Future<void> Function(String owner)? familyDataClaim,
  // Test: Ablagen mit Haken (#140).
  MemoryEventStore? eventStore,
  MemoryShoppingStore? shoppingItems,
  MemoryTaskStore? taskItems,
}) async {
  final store = MemoryKeyValueStore();
  if (lang != null) store.data['language'] = lang;
  final fake = server ?? FakeMatrixServer();
  if (server == null) {
    fake.addAccount('anna', 'geheim123', displayName: 'Anna');
    fake.addAccount('ben', 'geheim456', displayName: 'Ben');
  }
  final gateway = fake.newDevice();
  if (loggedIn) {
    await gateway.login(server: ServerUrl.tryParse(fake.host)!, username: 'anna', password: 'geheim123');
    await gateway.setUpSecurity();
    await gateway.createFamily('Familie Test');
    store.data['onboardingDone'] = 'true';
  }
  final protection = NoopScreenProtection();
  if (!secureScreen) store.data['secureScreen'] = 'false';
  if (lockEnabled) store.data['lockEnabled'] = 'true';
  final events = eventStore ?? MemoryEventStore();
  final shoppingStore = shoppingItems ?? MemoryShoppingStore();
  final taskStore = taskItems ?? MemoryTaskStore();
  final scheduler = FakeReminderScheduler();
  final links = FakeLinkSource();
  final auth = FakeDeviceAuth();
  final mail = FakeMailLauncher();
  final browser = FakeBrowser();
  final element = FakeElement();
  final oauth = FakeOAuthRedirect();
  final settingsController = await SettingsController.load(store);
  final calendarRooms = <String?>[];
  final shoppingRooms = <String?>[];
  final taskRooms = <String?>[];
  final builtCalendars = <CalendarController>[];
  final builtShopping = <ShoppingController>[];
  final builtTasks = <TasksController>[];
  final services = AppServices(
    settings: settingsController,
    screenProtection: screenProtection ?? protection,
    gateway: gateway,
    files: FakeFileAccess(),
    dataInventory: FakeLocalDataInventory(),
    links: links,
    lock: AppLockController(settings: settingsController, auth: auth),
    scheduler: withReminders ? scheduler : null,
    mail: mail,
    browser: browser,
    element: element,
    oauthRedirect: oauth,
    // Standard-Anbieter ist im Test der Fake-Server (statt matrix.org), außer ein Test will den echten Standard.
    defaultProvider: matrixOrgDefault ? null : ServerUrl.tryParse(defaultProvider ?? fake.host),
    familyDataClaim: familyDataClaim,
    shoppingBuilder: (uid, room) async {
      shoppingRooms.add(room);
      await beforeShoppingBuild?.call(uid);
      final service = ShoppingService(store: shoppingStore, myUserId: uid, clock: clock);
      final controller = ShoppingController(
        service: service,
        store: shoppingStore,
        sync: ShoppingSync(gateway: gateway, service: service, store: shoppingStore, retryInterval: const Duration(hours: 1)),
      );
      builtShopping.add(controller);
      return controller;
    },
    tasksBuilder: (uid, room) async {
      taskRooms.add(room);
      await beforeTasksBuild?.call(uid);
      final service = TaskService(
        store: taskStore,
        myUserId: uid,
        isModerator: (id) => Permissions.isModeratorId(gateway.family, id),
        clock: clock,
      );
      final controller = TasksController(
        service: service,
        store: taskStore,
        sync: TaskSync(gateway: gateway, service: service, store: taskStore, retryInterval: const Duration(hours: 1)),
        gateway: gateway,
        zoneName: 'Europe/Berlin',
        periodCheck: const Duration(hours: 1),
      );
      builtTasks.add(controller);
      return controller;
    },
    calendarBuilder: (uid, room) async {
      calendarRooms.add(room);
      await beforeCalendarBuild?.call(uid);
      final controller = buildCalendarController(
        store: events,
        gateway: gateway,
        userId: uid,
        zoneName: 'Europe/Berlin',
        clock: clock,
        retryInterval: const Duration(hours: 1),
      );
      builtCalendars.add(controller);
      return controller;
    },
  );
  return TestApp(
    services: services,
    protection: protection,
    server: fake,
    gateway: gateway,
    store: store,
    events: events,
    shoppingStore: shoppingStore,
    taskStore: taskStore,
    scheduler: scheduler,
    links: links,
    auth: auth,
    mail: mail,
    browser: browser,
    element: element,
    oauth: oauth,
    calendarRooms: calendarRooms,
    shoppingRooms: shoppingRooms,
    taskRooms: taskRooms,
    builtCalendars: builtCalendars,
    builtShopping: builtShopping,
    builtTasks: builtTasks,
  );
}

/// Fake für die Dateiauswahl.
class FakeFileAccess implements FileAccess {
  PickedFile? next;
  final List<String> saved = <String>[];
  final Map<String, Uint8List> contents = <String, Uint8List>{};

  /// `true`: Der Systemdialog wird abgebrochen, nichts wird gespeichert.
  bool cancelSave = false;

  /// Aufrufe von [clearTemporary].
  int cleared = 0;

  /// Läuft während [clearTemporary], vor dessen Ende.
  Future<void> Function()? onClear;

  @override
  Future<void> clearTemporary() async {
    cleared++;
    await onClear?.call();
  }

  @override
  Future<PickedFile?> pickFile() async => next;

  @override
  Future<bool> saveFile({required String name, required Uint8List bytes, required String mimeType}) async {
    if (cancelSave) return false;
    saved.add(name);
    contents[name] = bytes;
    return true;
  }
}

/// Fake der lokalen Bestandsaufnahme (Linux-Pfade, eine Einstellung, Schlüssel nur als vorhanden).
class FakeLocalDataInventory implements LocalDataInventory {
  static const StorageLocations fixed = StorageLocations(
    databaseDirectory: '/home/test/.local/share/de.inneso.familynexus/databases',
    appDatabase: '/home/test/.local/share/de.inneso.familynexus/databases/familynexus_app.db',
    matrixDatabase: '/home/test/.local/share/de.inneso.familynexus/databases/familynexus_matrix.db',
    keyStore: KeyStoreKind.linuxSecretService,
  );

  @override
  Future<StorageLocations> locations() async => fixed;

  @override
  Future<LocalInventory> read() async => const LocalInventory(
        locations: fixed,
        keys: <LocalKey>[LocalKey('db.app', present: true), LocalKey('db.matrix', present: true)],
        tables: <LocalTable>[
          LocalTable('settings', <Map<String, Object?>>[
            <String, Object?>{'key': 'language', 'value': 'de'},
          ]),
          LocalTable('events', <Map<String, Object?>>[]),
        ],
        appDatabaseBytes: 4096,
      );
}
