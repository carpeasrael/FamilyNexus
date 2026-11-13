import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;

import '../core/app_log.dart';
import '../core/platform_info.dart';
import '../data/db/app_database.dart';
import '../data/db/key_value_store.dart';
import '../data/db/sql_data_inventory.dart';
import '../data/db/sql_event_store.dart';
import '../data/db/sql_event_theme_store.dart';
import '../data/db/sql_shopping_store.dart';
import '../data/db/sql_task_store.dart';
import '../data/matrix/matrix_gateway.dart';
import '../data/matrix/sdk_matrix_gateway.dart';
import '../data/platform/activity_notifications.dart';
import '../data/platform/app_badge.dart';
import '../data/platform/device_auth.dart';
import '../data/platform/device_time_zone.dart';
import '../data/platform/file_access.dart';
import '../data/platform/in_app_auth.dart';
import '../data/platform/key_store.dart';
import '../data/platform/link_source.dart';
import '../data/platform/reminder_scheduler.dart';
import '../data/platform/screen_protection.dart';
import '../data/platform/vault_key_store.dart';
import '../data/sync/shopping_sync.dart';
import '../data/sync/task_sync.dart';
import '../domain/key_value_store.dart';
import '../domain/permissions.dart';
import '../domain/shopping.dart';
import '../domain/tasks.dart';
import '../features/lock/app_lock_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/shopping/shopping_controller.dart';
import '../features/tasks/tasks_controller.dart';
import '../l10n/gen/app_localizations.dart';
import 'app_services.dart';
import 'calendar_factory.dart';

/// Leitet alle unbehandelten Fehler in den redigierenden [AppLog] um, damit
/// Fehlertexte nicht ungefiltert in logcat landen.
void installErrorHandlers() {
  FlutterError.onError = (details) =>
      AppLog.e('flutter', 'Unbehandelter Framework-Fehler', details.exception);
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.e('platform', 'Unbehandelter Fehler', error);
    return true;
  };
}

bool _cryptoReady = false;

/// Initialisiert die Krypto-Bibliothek (vodozemac) genau einmal pro Prozess;
/// ein zweiter Aufruf (z. B. „Erneut versuchen“) würde sonst einen Fehler werfen.
Future<void> ensureCryptoInitialized() async {
  if (_cryptoReady) return;
  await vod.init();
  _cryptoReady = true;
}

/// Stellt die Sitzung wieder her und liefert, ob die lokalen Familiendaten trotz fehlender Sitzung bleiben sollen
/// (#134). Fehlt die Sitzung ohne Vermerk, ist das ein echtes Sitzungsende; der Vermerk steht nur dafür, dass das SDK
/// sie wegen eines eigenen Fehlers gelöscht haben kann. Lese- und Löschfehler des Vermerks führen in den Startfehler:
/// Ein stehender Vermerk hielte eine spätere Abmeldung vom Löschen ab.
Future<bool> restoreSession(MatrixGateway gateway, KeyValueStore kv) async {
  try {
    await gateway.restore();
  } on KeyLostException {
    rethrow;
  } on SessionRestoreException catch (e) {
    if (e.sessionLost) {
      try {
        await kv.write(AppServices.keepAccountDataKey, '1');
      } catch (e) {
        AppLog.e('startup', 'Vermerk zu den Familiendaten nicht gespeichert', e);
      }
    }
    rethrow;
  } catch (e) {
    // Offline/Serverfehler beim Start: Sitzung bleibt lokal bestehen, Sync holt auf.
    AppLog.w('startup', 'Sitzung nicht bestätigt, Start läuft lokal weiter (${e.runtimeType})');
  }
  if (!(await kv.readAll()).containsKey(AppServices.keepAccountDataKey)) return false;
  if (gateway.session != SessionState.ready) return true;
  await kv.delete(AppServices.keepAccountDataKey);
  return false;
}

Future<void> _closeAfterFailedStart(SdkMatrixGateway gateway, AppDatabase database) async {
  try {
    await gateway.close();
  } catch (e) {
    AppLog.e('startup', 'Matrix nicht geschlossen', e);
  }
  try {
    gateway.dispose();
  } catch (e) {
    AppLog.e('startup', 'Matrix nicht freigegeben', e);
  }
  try {
    await database.close();
  } catch (e) {
    AppLog.e('startup', 'Datenbank nicht geschlossen', e);
  }
}

/// Führt [step] aus und loggt Schrittname und Dauer in Millisekunden (#316); sonst nichts (keine Daten, keine Fehlertexte).
Future<T> timedStep<T>(String name, Future<T> Function() step) async {
  final watch = Stopwatch()..start();
  try {
    return await step();
  } finally {
    AppLog.d('startup', 'schritt=$name ms=${watch.elapsedMilliseconds}');
  }
}

/// Öffnet Schlüsselspeicher und Datenbank und baut die Dienste auf.
///
/// Räumt zuerst temporäre Klartext-Dateien auf, die ein beendeter Prozess hinterlassen hat, damit das auch bei einem
/// Startfehler geschieht (#141). [openDatabase] ersetzt im Test `AppDatabase.open`, das sonst echte Pfade berührt.
Future<AppServices> bootstrap({
  KeyStore? keyStore,
  FileAccess? files,
  @visibleForTesting Future<AppDatabase> Function(KeyStore keys)? openDatabase,
}) async {
  final keys = keyStore ?? SecureKeyStore();
  final fileAccess = files ?? SystemFileAccess();
  await timedStep('clearTemporary', fileAccess.clearTemporary);
  final database = await timedStep('openDatabase', () async => await (openDatabase?.call(keys) ?? AppDatabase.open(keyStore: keys)));
  final kv = SqlKeyValueStore(database.db);
  final settings = await timedStep('loadSettings', () => SettingsController.load(kv));
  await timedStep('cryptoInit', ensureCryptoInitialized);
  final gateway = SdkMatrixGateway(keyStore: keys, accountStore: kv);
  final bool keepAccountData;
  try {
    keepAccountData = await timedStep('restoreSession', () => restoreSession(gateway, kv));
  } catch (_) {
    // Sonst liefe bei stehender Sitzung der Sync weiter, und „Erneut versuchen“ öffnete alles ein zweites Mal.
    await _closeAfterFailedStart(gateway, database);
    rethrow;
  }
  final links = PlatformLinkSource();
  // Anbieterseiten und Rücksprung der Anmeldung je Plattform (E-91): eine Sitzung für beide.
  final auth = buildInAppAuth(links: links);
  // Browser: keine Erinnerungen (E-53); ohne Scheduler gibt es auch keinen Koordinator.
  final LocalReminderScheduler? scheduler = PlatformInfo.isWeb ? null : LocalReminderScheduler();
  final lang = settings.settings.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l10n = lookupAppLocalizations(Locale(lang == 'de' ? 'de' : 'en'));
  await timedStep('schedulerInit', () async => await scheduler?.initialize(channelName: l10n.reminderChannelName, channelDescription: l10n.reminderChannelDescription));
  // Meldungen zu Chat und Einkauf (#254, E-88): dasselbe Plugin, Texte in der aktuellen App-Sprache.
  AppLocalizations activityL10n() {
    final code = settings.settings.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return lookupAppLocalizations(Locale(code == 'de' ? 'de' : 'en'));
  }

  final activity = scheduler == null
      ? null
      : LocalActivityNotifications(scheduler, () {
          final l = activityL10n();
          return (
            title: l.appName,
            chatBody: l.activityChatBody,
            shoppingBody: l.activityShoppingBody,
            channelName: l.activityChannelName,
            channelDescription: l.activityChannelDescription,
          );
        });
  return AppServices(
    keepAccountData: keepAccountData,
    scheduler: scheduler,
    activityPlatform: activity,
    badge: PlatformInfo.isWeb ? null : PlatformAppBadge(),
    familyDataClaim: (owner) => AppServices.claimFamilyData(database.db, owner, onWiped: scheduler?.cancelAll),
    calendarBuilder: (userId, familyRoom) async {
      final store = SqlEventStore(database.db);
      final zone = await SystemDeviceTimeZone().current();
      return buildCalendarController(
        store: store,
        gateway: gateway,
        userId: userId,
        zoneName: zone,
        themeStore: SqlEventThemeStore(database.db),
        isModerator: (id) => Permissions.isModeratorId(gateway.family, id),
      );
    },
    shoppingBuilder: (userId, familyRoom) async {
      final store = SqlShoppingStore(database.db);
      final service = ShoppingService(store: store, myUserId: userId);
      return ShoppingController(
        service: service,
        store: store,
        sync: ShoppingSync(gateway: gateway, service: service, store: store),
      );
    },
    tasksBuilder: (userId, familyRoom) async {
      final store = SqlTaskStore(database.db);
      final service = TaskService(
        store: store,
        myUserId: userId,
        isModerator: (id) => Permissions.isModeratorId(gateway.family, id),
      );
      return TasksController(
        service: service,
        store: store,
        sync: TaskSync(gateway: gateway, service: service, store: store),
        gateway: gateway,
        zoneName: await SystemDeviceTimeZone().current(),
      );
    },
    settings: settings,
    gateway: gateway,
    files: fileAccess,
    links: links,
    browser: auth.browser,
    oauthRedirect: auth.oauthRedirect,
    lock: AppLockController(settings: settings, auth: PlatformInfo.hasNoDeviceAuth ? const UnavailableDeviceAuth() : LocalDeviceAuth()),
    screenProtection: PlatformScreenProtection(),
    database: database,
    keyStore: keys,
    dataInventory: SqlDataInventory(
      db: database.db,
      keyStore: keys,
      appFileName: AppDatabase.fileName,
      matrixFileName: SdkMatrixGateway.matrixDbFileName,
      keyNames: const <String>[AppDatabase.keyName, SdkMatrixGateway.matrixDbKeyName],
    ),
  );
}

/// Löscht alle lokalen Daten und Schlüssel (nur nach ausdrücklicher Bestätigung).
///
/// Temporäre Klartext-Dateien zuerst, damit ein Fehler beim Löschen sie nicht stehen lässt (#141). [destroyAll]
/// ersetzt im Test alle übrigen Schritte, die sonst den echten Datenbankpfad des Rechners träfen.
Future<void> resetLocalData({
  KeyStore? keyStore,
  FileAccess? files,
  @visibleForTesting Future<void> Function()? destroyAll,
}) async {
  await (files ?? SystemFileAccess()).clearTemporary();
  if (destroyAll != null) return destroyAll();
  await AppReminderCleanup.cancelAll();
  await AppDatabase.destroy();
  await AppDatabase.destroy(name: SdkMatrixGateway.matrixDbFileName);
  await (keyStore ?? SecureKeyStore()).deleteAll();
}

/// Vollständige lokale Löschung aus der laufenden App: abmelden, Datenbanken schließen und löschen,
/// Schlüssel entfernen. Setzt zuerst [AppServices.resetting], damit die Oberfläche bis zum Neustart
/// einen neutralen Ladezustand zeigt statt der Anmeldung (#272). [wipe] ersetzt im Test [resetLocalData].
Future<void> fullLocalReset(AppServices s, {@visibleForTesting Future<void> Function()? wipe}) async {
  s.resetting.value = true;
  try {
    await s.presence?.goOffline();
  } catch (e) {
    // best effort
    AppLog.w('reset', 'Offline-Meldung vor dem Löschen nicht gesendet (${e.runtimeType})');
  }
  s.closeCalendar(cancelReminders: true);
  try {
    await s.gateway.logout();
  } catch (e) {
    // Server nicht erreichbar: lokal wird trotzdem vollständig gelöscht.
    AppLog.w('reset', 'Abmeldung vor dem Löschen nicht möglich (${e.runtimeType})');
  }
  await s.gateway.close();
  await s.database?.close();
  if (wipe != null) return wipe();
  await resetLocalData(keyStore: s.keyStore, files: s.files);
}

/// Browser: löscht Tresor und beide Datenbanken, ohne sie entsperrt zu haben (Passwort vergessen).
Future<void> wipeWebData(VaultBackend vault) async {
  await AppDatabase.destroy();
  await AppDatabase.destroy(name: SdkMatrixGateway.matrixDbFileName);
  await vault.destroy();
}

/// Entfernt geplante Erinnerungen, ohne die App vollständig initialisiert zu haben.
class AppReminderCleanup {
  const AppReminderCleanup._();
  static Future<void> cancelAll() => PlatformInfo.isWeb ? Future<void>.value() : LocalReminderScheduler().cancelAll();
}
