import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/bootstrap.dart';
import 'app/quiet_zone.dart';
import 'app/startup_failure.dart';
import 'app/web_gate.dart';
import 'core/app_log.dart';
import 'core/platform_info.dart';
import 'data/platform/key_store.dart';
import 'data/platform/vault_key_store.dart';

void main() => runInQuietZone(() {
      WidgetsFlutterBinding.ensureInitialized();
      installErrorHandlers();
      runApp(const _Bootstrapper());
    });

class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper();

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  /// Browser: Der Start wartet auf das Tresorpasswort (E-53); sonst gibt es keinen Tresor.
  final VaultBackend? _vault = PlatformInfo.isWeb ? createWebVaultBackend() : null;
  KeyStore? _webKeys;
  Future<AppServices>? _future;

  @override
  void initState() {
    super.initState();
    if (_vault == null) _future = bootstrap();
  }

  /// [relock]: Browser nach dem Löschen aller Daten wieder zur Passwortabfrage.
  void _retry({bool relock = false}) => setState(() {
        if (_vault == null) {
          _future = bootstrap();
          return;
        }
        if (relock) _webKeys = null;
        _future = _webKeys == null ? null : bootstrap(keyStore: _webKeys);
      });

  /// Vollständige lokale Löschung: abmelden, Datenbanken schließen und löschen, Schlüssel entfernen.
  Future<void> _fullReset(AppServices services) async {
    try {
      await services.presence?.goOffline();
    } catch (_) {
      // best effort
    }
    services.closeCalendar(cancelReminders: true);
    try {
      await services.gateway.logout();
    } catch (_) {
      // Server nicht erreichbar: lokal wird trotzdem vollständig gelöscht.
    }
    await services.gateway.close();
    await services.database?.close();
    await resetLocalData(keyStore: services.keyStore);
    if (mounted) _retry(relock: true);
  }

  Future<void> _reset() async {
    await resetLocalData(keyStore: _webKeys);
    _retry(relock: true);
  }

  @override
  Widget build(BuildContext context) {
    final vault = _vault;
    if (vault != null && _webKeys == null) {
      return WebUnlockApp(
        backend: vault,
        onWipe: () => wipeWebData(vault),
        onUnlocked: (keys) => setState(() {
          _webKeys = keys;
          _future = bootstrap(keyStore: keys);
        }),
      );
    }
    return FutureBuilder<AppServices>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            AppLog.e('startup', 'Start fehlgeschlagen', snap.error);
            return StartupFailureApp(onRetry: _retry, onReset: _reset);
          }
          final services = snap.data;
          if (services == null) return const SizedBox.shrink();
          services.onFullReset ??= () => _fullReset(services);
          return FamilyNexusApp(services: services);
        },
      );
  }
}
