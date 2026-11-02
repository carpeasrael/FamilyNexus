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

/// Erzeugt den Kalender für den angemeldeten Nutzer (inkl. lokaler Ablage) und dessen Familie [familyRoom].
typedef CalendarBuilder = Future<CalendarController> Function(String userId, String? familyRoom);

/// Erzeugt den Einkaufszettel für den angemeldeten Nutzer (inkl. lokaler Ablage) und dessen Familie [familyRoom].
typedef ShoppingBuilder = Future<ShoppingController> Function(String userId, String? familyRoom);

/// Erzeugt die Aufgabenlisten für den angemeldeten Nutzer (inkl. lokaler Ablage) und dessen Familie [familyRoom].
typedef TasksBuilder = Future<TasksController> Function(String userId, String? familyRoom);

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
    this.familyDataClaim,
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

  /// Beansprucht die lokalen Familiendaten für `<Nutzer>|<Raum>`, vor dem Aufbau der Dienste (#140);
  /// siehe [claimFamilyData]. `null` in Widget-Tests ohne Datenbank.
  final Future<void> Function(String owner)? familyDataClaim;
  final ReminderScheduler? scheduler;

  CalendarController? calendar;
  ShoppingController? shopping;
  TasksController? tasks;
  PresenceSync? presence;
  ReminderCoordinator? reminders;
  String? _calendarUser;

  /// Familie, für die die Dienste offen sind oder gerade öffnen.
  String? _calendarRoom;

  /// Weicht dieser Raum von der aktuellen Familie ab, baut `AppRoot` die Dienste neu auf (#140).
  String? get openFamilyRoom => _calendarRoom;

  /// Wartet auf die Warteschlangen der geschlossenen Dienste: Danach schreibt keiner von ihnen mehr in die Ablage.
  Future<void> _closing = Future<void>.value();

  /// Kette der Ansprüche ([familyDataClaim]): Der nächste wartet auf den vorigen, ein Fehler bleibt beim Aufrufer.
  Future<void> _claimRun = Future<void>.value();

  /// Öffnet die Familiendienste des angemeldeten Nutzers (idempotent je Nutzer und Familie): Kalender samt
  /// Erinnerungen, Einkaufszettel und Online-Status.
  ///
  /// Der Raum wird vor dem ersten `await` gemerkt, Bindung und Ablage passen so zusammen, auch wenn die Familie
  /// währenddessen wechselt (#140): Die Sync-Klassen sperren dann, `AppRoot` baut neu auf. Nur Anspruch und Abschluss
  /// sind serialisiert: Ein hängender `build` hält keinen neuen Lauf auf (#153), denn Builder schreiben nicht in die
  /// Ablage, und ein veralteter Lauf gibt nach jedem `await` auf.
  Future<void> openCalendar() async {
    final uid = gateway.userId;
    final build = calendarBuilder;
    if (uid == null || build == null) return;
    final room = gateway.family?.roomId;
    if (calendar != null && _calendarUser == uid && _calendarRoom == room) return;
    closeCalendar();
    final attempt = _openAttempt;
    _calendarRoom = room;
    try {
      await _closing;
      if (attempt != _openAttempt) return;
      final claim = familyDataClaim;
      if (claim != null) {
        final owner = '$uid|${room ?? ''}';
        final run = _claimRun.then((_) => claim(owner));
        _claimRun = run.then<void>((_) {}, onError: (Object _) {});
        await run;
        if (attempt != _openAttempt) return;
      }
      final c = await build(uid, room);
      if (attempt != _openAttempt) {
        c.dispose();
        return;
      }
      calendar = c;
      _calendarUser = uid;
      c.start(familyRoom: room);
      final sb = shoppingBuilder;
      if (sb != null) {
        final s = await sb(uid, room);
        if (attempt != _openAttempt) {
          s.dispose();
          return;
        }
        (shopping = s).start(familyRoom: room);
      }
      final tb = tasksBuilder;
      if (tb != null) {
        final t = await tb(uid, room);
        if (attempt != _openAttempt) {
          t.dispose();
          return;
        }
        (tasks = t).start(familyRoom: room);
      }
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

  /// Zählt jedes Schließen: Ein Öffnungslauf, der das bemerkt, ist veraltet.
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

  /// Beansprucht die lokalen Familiendaten für [owner]: Gehörten sie jemand anderem (Nutzer oder Familie), werden sie
  /// vollständig entfernt, damit sich Daten verschiedener Familien nie vermischen (S7). [onWiped] entfernt das, was
  /// zu den gelöschten Daten geplant war. Der Besitzer wird zuletzt geschrieben: Nach einem Fehler löscht der nächste
  /// Aufruf erneut.
  static Future<void> claimFamilyData(Database db, String owner, {Future<void> Function()? onWiped}) async {
    final kv = SqlKeyValueStore(db);
    final previous = (await kv.readAll())[calendarOwnerKey];
    if (previous != null && previous != owner) {
      await SqlEventStore(db).wipe();
      await SqlShoppingStore(db).wipe();
      await SqlTaskStore(db).wipe();
      await onWiped?.call();
    }
    await kv.write(calendarOwnerKey, owner);
  }

  /// Einstellungsschlüssel: Konto und Familie, denen die lokalen Familiendaten gehören.
  static const String calendarOwnerKey = 'calendarOwner';

  /// Einstellungsschlüssel zu [keepAccountData].
  static const String keepAccountDataKey = 'keepAccountData';

  /// Beendet Synchronisation und Planung. [cancelReminders]: nur bei Abmeldung/Löschung –
  /// beim bloßen Schließen der Oberfläche müssen geplante Erinnerungen bestehen bleiben.
  ///
  /// Ein laufender Öffnungslauf ist danach veraltet. Die Warteschlangen der Dienste laufen noch aus; [openCalendar]
  /// wartet darauf. Weitere Aufrufe ohne offene Dienste ändern daran nichts: Ein Wechsel schließt bis zu dreimal.
  void closeCalendar({bool cancelReminders = false}) {
    _openAttempt++;
    if (cancelReminders) scheduler?.cancelAll().ignore();
    reminders?.dispose();
    reminders = null;
    final p = presence;
    if (p != null) {
      settings.removeListener(p.update);
      p.dispose();
      presence = null;
    }
    final idle = <Future<void>>[
      if (shopping case final s?) s.sync.idle(),
      if (tasks case final t?) t.sync.idle(),
      if (calendar case final c?) c.sync.idle(),
    ];
    if (idle.isNotEmpty) {
      _closing = Future.wait<void>(<Future<void>>[_closing, ...idle]).then<void>((_) {}, onError: (Object _) {});
    }
    shopping?.dispose();
    shopping = null;
    tasks?.dispose();
    tasks = null;
    calendar?.dispose();
    calendar = null;
    _calendarUser = null;
    _calendarRoom = null;
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
