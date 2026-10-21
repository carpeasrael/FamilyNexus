import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/app_settings.dart';
import '../features/lock/lock_gate.dart';
import '../features/shell/app_root.dart';
import '../l10n/gen/app_localizations.dart';
import '../ui/theme/app_theme.dart';
import '../ui/widgets/glass.dart';
import 'app_services.dart';

class FamilyNexusApp extends StatefulWidget {
  const FamilyNexusApp({super.key, required this.services});
  final AppServices services;

  @override
  State<FamilyNexusApp> createState() => _FamilyNexusAppState();
}

class _FamilyNexusAppState extends State<FamilyNexusApp> {
  bool? _appliedSecure;

  @override
  void initState() {
    super.initState();
    widget.services.settings.addListener(_applyPlatformSettings);
    _applyPlatformSettings();
  }

  @override
  void dispose() {
    widget.services.settings.removeListener(_applyPlatformSettings);
    super.dispose();
  }

  void _applyPlatformSettings() {
    final secure = widget.services.settings.settings.secureScreen;
    if (secure != _appliedSecure) {
      _appliedSecure = secure;
      widget.services.screenProtection.setSecure(secure).ignore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: ListenableBuilder(
        listenable: widget.services.settings,
        builder: (context, _) {
          final s = widget.services.settings.settings;
          return MaterialApp(
            onGenerateTitle: (c) => AppLocalizations.of(c).appName,
            debugShowCheckedModeBanner: false,
            locale: s.languageCode == null ? null : Locale(s.languageCode!),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: buildTheme(Brightness.light, reduceEffects: s.reduceEffects, accent: s.accent),
            darkTheme: buildTheme(Brightness.dark, reduceEffects: s.reduceEffects, accent: s.accent),
            themeMode: switch (s.themeMode) {
              AppThemeMode.system => ThemeMode.system,
              AppThemeMode.dark => ThemeMode.dark,
              AppThemeMode.light => ThemeMode.light,
            },
            builder: (context, child) {
              // Systemleisten passend zum Design: helle Symbole auf dunklem, dunkle auf hellem Grund.
              final dark = Theme.of(context).brightness == Brightness.dark;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                  statusBarColor: Colors.transparent,
                  systemNavigationBarColor: Colors.transparent,
                ),
                child: AuroraBackground(child: LockGate(child: child ?? const SizedBox.shrink())),
              );
            },
            home: const AppRoot(),
          );
        },
      ),
    );
  }
}
