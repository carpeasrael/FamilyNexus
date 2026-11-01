import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'package:flutter_vodozemac/flutter_vodozemac.dart' as vod;

import '../core/app_log.dart';
import '../core/platform_info.dart';
import '../data/db/app_database.dart';
import '../data/db/key_value_store.dart';
import '../data/db/sql_data_inventory.dart';
import '../data/db/sql_event_store.dart';
import '../data/db/sql_shopping_store.dart';
import '../data/db/sql_task_store.dart';
import '../data/sync/shopping_sync.dart';
import '../data/sync/task_sync.dart';
import '../domain/permissions.dart';
import '../domain/shopping.dart';
import '../domain/tasks.dart';
import '../features/shopping/shopping_controller.dart';
import '../features/tasks/tasks_controller.dart';
import '../data/matrix/matrix_gateway.dart';
import '../data/matrix/sdk_matrix_gateway.dart';
import '../domain/key_value_store.dart';
import '../data/platform/device_time_zone.dart';
import '../data/platform/device_auth.dart';
import '../data/platform/file_access.dart';
import '../data/platform/key_store.dart';
import '../data/platform/link_source.dart';
import '../data/platform/oauth_redirect.dart';
import '../data/platform/reminder_scheduler.dart';
import '../data/platform/screen_protection.dart';
import '../data/platform/vault_key_store.dart';
import '../features/lock/app_lock_controller.dart';
import '../features/settings/settings_controller.dart';
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
  } catch (_) {
    // Offline/Serverfehler beim Start: Sitzung bleibt lokal bestehen, Sync holt auf.
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
  await fileAccess.clearTemporary();
  final database = await (openDatabase?.call(keys) ?? AppDatabase.open(keyStore: keys));
  final kv = SqlKeyValueStore(database.db);
  final settings = await SettingsController.load(kv);
  await ensureCryptoInitialized();
  final gateway = SdkMatrixGateway(keyStore: keys);
  final bool keepAccountData;
  try {
    keepAccountData = await restoreSession(gateway, kv);
  } catch (_) {
    // Sonst liefe bei stehender Sitzung der Sync weiter, und „Erneut versuchen“ öffnete alles ein zweites Mal.
    await _closeAfterFailedStart(gateway, database);
    rethrow;
  }
  final links = PlatformLinkSource();
  // Browser: keine Erinnerungen (E-53); ohne Scheduler gibt es auch keinen Koordinator.
  final LocalReminderScheduler? scheduler = PlatformInfo.isWeb ? null : LocalReminderScheduler();
  final lang = settings.settings.languageCode ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l10n = lookupAppLocalizations(Locale(lang == 'de' ? 'de' : 'en'));
  await scheduler?.initialize(channelName: l10n.reminderChannelName, channelDescription: l10n.reminderChannelDescription);
  return AppServices(
    keepAccountData: keepAccountData,
    scheduler: scheduler,
    calendarBuilder: (userId) async {
      // Anderer Nutzer oder andere Familie als zuletzt: lokale Termine vollständig entfernen,
      // damit sich Daten verschiedener Familien nie vermischen (S7).
      final store = SqlEventStore(database.db);
      final owner = '$userId|${gateway.family?.roomId ?? ''}';
      final previous = (await kv.readAll())[AppServices.calendarOwnerKey];
      if (previous != null && previous != owner) {
        await store.wipe();
        await SqlShoppingStore(database.db).wipe();
        await SqlTaskStore(database.db).wipe();
        await scheduler?.cancelAll();
      }
      await kv.write(AppServices.calendarOwnerKey, owner);
      final zone = await SystemDeviceTimeZone().current();
      return buildCalendarController(store: store, gateway: gateway, userId: userId, zoneName: zone);
    },
    shoppingBuilder: (userId) async {
      final store = SqlShoppingStore(database.db);
      final service = ShoppingService(store: store, myUserId: userId);
      return ShoppingController(
        service: service,
        store: store,
        sync: ShoppingSync(gateway: gateway, service: service, store: store),
      );
    },
    tasksBuilder: (userId) async {
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
    oauthRedirect: OAuthRedirect.forPlatform(links),
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
