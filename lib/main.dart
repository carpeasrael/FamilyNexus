import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_services.dart';
import 'app/bootstrap.dart';
import 'app/quiet_zone.dart';
import 'app/startup_failure.dart';
import 'core/app_log.dart';

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
  late Future<AppServices> _future = bootstrap();

  void _retry() => setState(() => _future = bootstrap());

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
    if (mounted) _retry();
  }

  Future<void> _reset() async {
    await resetLocalData();
    _retry();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
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
