import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/gen/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/glass.dart';

/// Ladebild, solange der Start (`bootstrap`) läuft (#316): Statt einer leeren Fläche zeigt die App sofort den
/// Aurora-Hintergrund mit Ladeanzeige. Sprache und Helligkeit folgen dem Gerät (Einstellungen sind noch nicht lesbar).
class StartupLoadingApp extends StatelessWidget {
  const StartupLoadingApp({super.key = const Key('startup-loading')});

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
        theme: buildTheme(WidgetsBinding.instance.platformDispatcher.platformBrightness),
        builder: (context, child) => AuroraBackground(child: child ?? const SizedBox.shrink()),
        home: Builder(builder: (context) {
          final l = AppLocalizations.of(context);
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                Semantics(label: l.loading, child: const CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(l.loading),
              ]),
            ),
          );
        }),
      );
}
