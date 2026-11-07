import 'package:flutter/material.dart';

import '../core/app_log.dart';
import '../core/platform_info.dart';
import '../data/matrix/matrix_gateway.dart';
import '../data/platform/key_store.dart';
import '../data/platform/vault_key_store.dart';
import 'app.dart';
import 'app_services.dart';
import 'bootstrap.dart';
import 'startup_failure.dart';
import 'web_gate.dart';

/// Baut die Dienste auf und zeigt währenddessen, bei Fehlern oder nach dem Start die passende Oberfläche.
///
/// [bootstrapFn] ersetzt im Test `bootstrap`.
class Bootstrapper extends StatefulWidget {
  const Bootstrapper({super.key, this.bootstrapFn = bootstrap});

  final Future<AppServices> Function({KeyStore? keyStore}) bootstrapFn;

  @override
  State<Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<Bootstrapper> {
  /// Browser: Der Start wartet auf das Tresorpasswort (E-53); sonst gibt es keinen Tresor.
  final VaultBackend? _vault = PlatformInfo.isWeb ? createWebVaultBackend() : null;
  KeyStore? _webKeys;
  Future<AppServices>? _future;

  @override
  void initState() {
    super.initState();
    if (_vault == null) _future = widget.bootstrapFn();
  }

  /// [relock]: Browser nach dem Löschen aller Daten wieder zur Passwortabfrage.
  void _retry({bool relock = false}) => setState(() {
        if (_vault == null) {
          _future = widget.bootstrapFn();
          return;
        }
        if (relock) _webKeys = null;
        _future = _webKeys == null ? null : widget.bootstrapFn(keyStore: _webKeys);
      });

  /// Vollständige lokale Löschung (#272: [fullLocalReset]); danach neu starten, auch wenn das Löschen scheitert.
  Future<void> _fullReset(AppServices services) async {
    try {
      await fullLocalReset(services);
    } finally {
      if (mounted) _retry(relock: true);
    }
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
          _future = widget.bootstrapFn(keyStore: keys);
        }),
      );
    }
    return FutureBuilder<AppServices>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            AppLog.e('startup', 'Start fehlgeschlagen', snap.error);
            final error = snap.error;
            return StartupFailureApp(
              onRetry: _retry,
              onReset: _reset,
              sessionLost: error is SessionRestoreException && error.sessionLost,
            );
          }
          final services = snap.data;
          if (services == null) return const SizedBox.shrink();
          services.onFullReset ??= () => _fullReset(services);
          return FamilyNexusApp(services: services);
        },
      );
  }
}
