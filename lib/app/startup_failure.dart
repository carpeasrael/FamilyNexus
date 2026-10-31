import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/gen/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/glass.dart';

/// Wird gezeigt, wenn Schlüssel/Datenbank nicht geöffnet werden können.
/// Sprache folgt dem Gerät (Einstellungen sind ja nicht lesbar).
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({super.key, required this.onRetry, required this.onReset, this.sessionLost = false});

  /// Die Anmeldung ging verloren, die Familiendaten sind unberührt (#134). Der allgemeine Text sagte „nichts verändert“.
  final bool sessionLost;
  final VoidCallback onRetry;
  final Future<void> Function() onReset;

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
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics(
                          header: true,
                          child: Text(
                            sessionLost ? l.startupSessionLostTitle : l.startupFailedTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(sessionLost ? l.startupSessionLostBody : l.startupFailedBody),
                        const SizedBox(height: 20),
                        Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
                          FilledButton(onPressed: onRetry, child: Text(l.startupRetry)),
                          OutlinedButton(
                            onPressed: () async {
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
                              if (ok == true) await onReset();
                            },
                            child: Text(l.startupReset),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      );
}
