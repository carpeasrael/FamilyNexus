import 'package:flutter/widgets.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' show Database;

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../data/db/key_value_store.dart';
import '../data/db/sql_event_store.dart';
import '../data/db/sql_shopping_store.dart';
import '../data/db/sql_task_store.dart';
import '../data/matrix/matrix_gateway.dart';
import '../data/platform/browser_launcher.dart';
import '../data/platform/element_launcher.dart';
import '../domain/server.dart';
import '../data/platform/file_access.dart';
import '../data/platform/key_store.dart';
import '../data/platform/link_source.dart';
import '../data/platform/mail_launcher.dart';
import '../data/platform/oauth_redirect.dart';
import '../data/platform/reminder_scheduler.dart';
import '../data/platform/screen_protection.dart';
import '../data/sync/presence_sync.dart';
import '../domain/data_inventory.dart';
import '../domain/invite_link.dart';
import '../features/calendar/calendar_controller.dart';
import '../features/lock/app_lock_controller.dart';
import '../features/reminders/reminder_coordinator.dart';
import '../features/shopping/shopping_controller.dart';
import '../features/tasks/tasks_controller.dart';
import '../features/settings/settings_controller.dart';

/// Erzeugt den Kalender für den angemeldeten Nutzer (inkl. lokaler Ablage).
typedef CalendarBuilder = Future<CalendarController> Function(String userId);

/// Erzeugt den Einkaufszettel für den angemeldeten Nutzer (inkl. lokaler Ablage).
typedef ShoppingBuilder = Future<ShoppingController> Function(String userId);

/// Erzeugt die Aufgabenlisten für den angemeldeten Nutzer (inkl. lokaler Ablage).
typedef TasksBuilder = Future<TasksController> Function(String userId);

/// Gemeinsame Dienste der App; wird über [AppScope] bereitgestellt.
class AppServices {
  AppServices({
    required this.settings,
    required this.screenProtection,
    required this.gateway,
    required this.files,
    required this.links,
    required this.lock,
    this.database,
    this.keepAccountData = false,
    this.keyStore,
    this.dataInventory,
    this.calendarBuilder,
    this.shoppingBuilder,
    this.tasksBuilder,
    this.scheduler,
    this.mail = const SystemMailLauncher(),
    this.browser = const SystemBrowserLauncher(),
    this.element = const SystemElementLauncher(),
    this.oauthRedirect,
    this.defaultProvider,
  });

  final SettingsController settings;
  final ScreenProtection screenProtection;
  final MatrixGateway gateway;
  final FileAccess files;
  final LinkSource links;
  final AppLockController lock;

  /// Öffnet das Mailprogramm für Einladungslinks (E-49).
  final MailLauncher mail;

  /// Öffnet Seiten des Anbieters (Anmeldung, Bedingungen, Captcha; E-55).
  final BrowserLauncher browser;

  /// Startet Element, wenn der Server die Kontoanlage in der App nicht zulässt.
  final ElementLauncher element;

  /// Standard-Anbieter der Einrichtung; `null` = `matrix.org` (nur Tests setzen ihn).
  final ServerUrl? defaultProvider;

  /// Rücksprung der Anmeldung im Browser; `null` = auf dieser Plattform nicht verfügbar (Browser-App).
  final OAuthRedirect? oauthRedirect;

  /// Wird vom Start-Widget gesetzt: löscht alle lokalen Daten und startet neu.
  Future<void> Function()? onFullReset;

  /// Läuft eine Kontolöschung (#12)? Endet die Sitzung währenddessen, löscht die App alle lokalen Daten.
  bool accountDeletionPending = false;

  /// Gesprächskennung, die der Chat öffnen soll (z. B. „Nachricht schreiben“ in der Familie).
  /// Die Oberfläche wechselt zum Chat und setzt den Wert wieder auf `null`.
  final ValueNotifier<String?> chatRequest = ValueNotifier<String?>(null);

  /// Zuletzt geöffneter (geprüfter) Einladungslink, noch nicht bestätigt.
  final ValueNotifier<InviteLink?> pendingInvite = ValueNotifier<InviteLink?>(null);

  /// `null` in Widget-Tests ohne Datenbank.
  final AppDatabase? database;
  final KeyStore? keyStore;

  /// Speicherorte und lokaler Datenbestand für das Datenprotokoll; `null` in Widget-Tests ohne Datenbank.
  final LocalDataInventory? dataInventory;
  final CalendarBuilder? calendarBuilder;
  final ShoppingBuilder? shoppingBuilder;
  final TasksBuilder? tasksBuilder;
  final ReminderScheduler? scheduler;

  CalendarController? calendar;
  ShoppingController? shopping;
  TasksController? tasks;
  PresenceSync? presence;
  ReminderCoordinator? reminders;
  String? _calendarUser;

  /// Öffnet die Familiendienste des angemeldeten Nutzers (idempotent): Kalender samt
  /// Erinnerungen, Einkaufszettel und Online-Status.
  Future<void> openCalendar() async {
    final uid = gateway.userId;
    final build = calendarBuilder;
    if (uid == null || build == null) return;
    if (calendar != null && _calendarUser == uid) return;
    closeCalendar();
    final attempt = ++_openAttempt;
    try {
      final c = await build(uid);
      calendar = c;
      _calendarUser = uid;
      c.start();
      final sb = shoppingBuilder;
      if (sb != null) (shopping = await sb(uid)).start();
      final tb = tasksBuilder;
      if (tb != null) (tasks = await tb(uid)).start();
      final p = PresenceSync(gateway: gateway, enabled: () => settings.settings.shareOnlineStatus);
      presence = p;
      settings.addListener(p.update);
      p.start(foreground: WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused);
      final s = scheduler;
      if (s != null) reminders = ReminderCoordinator(calendar: c, scheduler: s, settings: settings, clock: () => c.now)..start();
    } catch (e) {
      AppLog.e('app', 'Familiendienste konnten nicht geöffnet werden', e);
      // Kein Teilzustand: Fehler heißt „nicht geöffnet“, ein Neuversuch baut alles neu auf (#153). Ein
      // veralteter Aufruf baut einen neueren, erfolgreichen nicht ab.
      if (attempt == _openAttempt) closeCalendar();
      rethrow;
    }
  }

  int _openAttempt = 0;

  /// Meldet den Status als „offline“ und meldet dann ab.
  Future<void> logout() async {
    await presence?.goOffline();
    await gateway.logout();
  }

  /// Entfernt die Familiendaten des abgemeldeten Kontos (Termine samt privater, Einkaufszettel, Aufgaben) von
  /// diesem Gerät; App-Einstellungen bleiben. Ohne vorherige Anmeldung (`calendarOwner` fehlt) geschieht nichts.
  /// Abmelden hieß bisher nur „Sitzung beenden“; die Daten blieben bis zur Anmeldung eines anderen Kontos liegen
  /// (Pen-Test F-02).
  Future<void> wipeAccountData() async {
    // Zuerst lesen: Der Vermerk (#134) darf nicht hinter die Rundreise des Aufräumens rücken.
    final keep = keepAccountData;
    final wipe = debugWipeAccountData;
    final db = database?.db;
    await files.clearTemporary(); // auch bei `keep`: Temp-Dateien sind keine Familiendaten (#141)
    if (keep) return;
    if (wipe != null) return wipe();
    if (db != null) await wipeAccountDataIn(db);
  }

  /// `true`: Das SDK kann die Sitzung beim Start wegen eines eigenen Fehlers gelöscht haben. Das ist kein gewolltes
  /// Sitzungsende, Familiendaten und Erinnerungen bleiben bis zur nächsten Anmeldung (#134, E-82).
  bool keepAccountData;

  /// Ersetzt im Test das Löschen; `buildTestApp` hat keine Datenbank.
  @visibleForTesting
  Future<void> Function()? debugWipeAccountData;

  bool _confirmingSession = false;

  /// Eine Sitzung steht: Der Vermerk [keepAccountData] entfällt, ein späteres Abmelden löscht wieder.
  Future<void> sessionConfirmed() async {
    if (!keepAccountData || _confirmingSession) return;
    _confirmingSession = true;
    try {
      final db = database?.db;
      if (db != null) await SqlKeyValueStore(db).delete(keepAccountDataKey);
      keepAccountData = false;
    } catch (e) {
      // Die Datenbank kann bereits geschlossen sein (`_fullReset`); sonst folgt der nächste Versuch beim nächsten Aufbau.
      AppLog.e('app', 'Vermerk zu den Familiendaten nicht entfernt', e);
    } finally {
      _confirmingSession = false;
    }
  }

  /// [wipeAccountData] für die App-Datenbank [db].
  static Future<void> wipeAccountDataIn(Database db) async {
    final kv = SqlKeyValueStore(db);
    if ((await kv.readAll())[calendarOwnerKey] == null) return;
    await SqlEventStore(db).wipe();
    await SqlShoppingStore(db).wipe();
    await SqlTaskStore(db).wipe();
    await kv.delete(calendarOwnerKey);
  }

  /// Einstellungsschlüssel: Konto und Familie, denen die lokalen Familiendaten gehören.
  static const String calendarOwnerKey = 'calendarOwner';

  /// Einstellungsschlüssel zu [keepAccountData].
  static const String keepAccountDataKey = 'keepAccountData';

  /// Beendet Synchronisation und Planung. [cancelReminders]: nur bei Abmeldung/Löschung –
  /// beim bloßen Schließen der Oberfläche müssen geplante Erinnerungen bestehen bleiben.
  void closeCalendar({bool cancelReminders = false}) {
    if (cancelReminders) scheduler?.cancelAll().ignore();
    reminders?.dispose();
    reminders = null;
    final p = presence;
    if (p != null) {
      settings.removeListener(p.update);
      p.dispose();
      presence = null;
    }
    shopping?.dispose();
    shopping = null;
    tasks?.dispose();
    tasks = null;
    calendar?.dispose();
    calendar = null;
    _calendarUser = null;
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.services;
  }

  /// Wie [of], aber ohne Abhängigkeit zu registrieren (z. B. in `initState`).
  static AppServices read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => services != oldWidget.services;
}
