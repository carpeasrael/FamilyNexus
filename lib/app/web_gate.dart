import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/platform/key_store.dart';
import '../data/platform/tab_lock.dart';
import '../data/platform/vault_key_store.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/glass.dart';

/// Mindestlänge des Browser-Passworts. Es schützt alle lokalen Daten dieses Browsers (E-53).
const int kMinVaultPasswordLength = 10;

/// Start der Web-Version: schützt den Browser-Speicher mit einem Passwort, bevor irgendetwas geöffnet wird.
/// Beim ersten Start wird ein Tresor angelegt, danach entsperrt. Sprache folgt dem Browser.
class WebUnlockApp extends StatefulWidget {
  const WebUnlockApp({super.key, required this.backend, required this.onUnlocked, required this.onWipe});

  final VaultBackend backend;
  final void Function(KeyStore keys) onUnlocked;

  /// Löscht Tresor und Datenbanken (bei vergessenem Passwort).
  final Future<void> Function() onWipe;

  @override
  State<WebUnlockApp> createState() => _WebUnlockAppState();
}

class _WebUnlockAppState extends State<WebUnlockApp> {
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  late Future<bool> _tab = acquireTabLock();
  late bool _create = !widget.backend.exists;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    final pw = _password.text;
    if (_create) {
      if (pw.length < kMinVaultPasswordLength) return setState(() => _error = l.webPasswordTooShort);
      if (pw != _repeat.text) return setState(() => _error = l.webPasswordMismatch);
    } else if (pw.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_create) {
        await widget.backend.create(pw);
      } else {
        await widget.backend.unlock(pw);
      }
      final keys = await VaultKeyStore.open(widget.backend);
      widget.onUnlocked(keys);
    } on WrongVaultPasswordException {
      if (mounted) setState(() => _error = l.webPasswordWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot(BuildContext context, AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.startupResetConfirmTitle),
        content: Text(l.startupResetConfirmBody),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await widget.onWipe();
    if (!mounted) return;
    _password.clear();
    _repeat.clear();
    setState(() {
      _create = true;
      _error = null;
    });
  }

  Widget _card(BuildContext context, List<Widget> children) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassCard(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.dark),
        builder: (context, child) => AuroraBackground(child: child ?? const SizedBox.shrink()),
        home: Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          final title = Theme.of(context).textTheme.headlineSmall;
          return Scaffold(
            body: SafeArea(
              child: FutureBuilder<bool>(
                future: _tab,
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  if (snap.data == false) {
                    return _card(context, <Widget>[
                      Semantics(header: true, child: Text(l.webTabBusyTitle, style: title)),
                      const SizedBox(height: 12),
                      Text(l.webTabBusyBody),
                      const SizedBox(height: 20),
                      FilledButton(onPressed: () => setState(() => _tab = acquireTabLock()), child: Text(l.startupRetry)),
                    ]);
                  }
                  return _card(context, <Widget>[
                    Semantics(header: true, child: Text(_create ? l.webUnlockTitleCreate : l.webUnlockTitle, style: title)),
                    const SizedBox(height: 12),
                    Text(_create ? l.webUnlockBodyCreate : l.webUnlockBody),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofocus: true,
                      enabled: !_busy,
                      decoration: InputDecoration(labelText: l.webPassword),
                      onSubmitted: _create ? null : (_) => _submit(l),
                    ),
                    if (_create) ...<Widget>[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _repeat,
                        obscureText: true,
                        enabled: !_busy,
                        decoration: InputDecoration(labelText: l.webPasswordRepeat),
                        onSubmitted: (_) => _submit(l),
                      ),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                    ],
                    const SizedBox(height: 20),
                    Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
                      FilledButton(
                        onPressed: _busy ? null : () => _submit(l),
                        child: Text(_busy ? l.webUnlockBusy : (_create ? l.webCreateAction : l.webUnlockAction)),
                      ),
                      if (!_create) TextButton(onPressed: _busy ? null : () => _forgot(context, l), child: Text(l.webForgotPassword)),
                    ]),
                  ]);
                },
              ),
            ),
          );
        }),
      );
}
