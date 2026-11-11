import 'package:flutter/material.dart';

import '../../domain/app_settings.dart';
import 'tokens.dart';

const String fontDisplay = 'SpaceGrotesk';
const String fontSans = 'IBMPlexSans';
const String fontMono = 'IBMPlexMono';

TextStyle monoStyle(BuildContext context, {double size = 14, Color? color}) =>
    TextStyle(
      fontFamily: fontMono,
      fontSize: size,
      color: color ?? AuroraTokens.of(context).textPrimary,
    );

ThemeData buildTheme(Brightness brightness, {bool reduceEffects = false, AccentChoice accent = AccentChoice.teal}) {
  final t = (brightness == Brightness.dark ? AuroraTokens.dark : AuroraTokens.light)
      .withReduceEffects(reduceEffects)
      .withAccent(accent);
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: t.textMuted),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: _colorScheme(brightness, t),
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: t.bgSurface,
    fontFamily: fontSans,
    textTheme: _textTheme(t),
    extensions: <ThemeExtension<dynamic>>[t],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: t.textPrimary,
      titleTextStyle: _display(t, 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: t.primary, width: 2),
      ),
      filled: true,
      fillColor: t.glassFill,
      labelStyle: _body(t, 14, FontWeight.w400, t.textSecondary),
    ),
    filledButtonTheme: _filledButtonTheme(t),
    outlinedButtonTheme: _outlinedButtonTheme(t),
    textButtonTheme: _textButtonTheme(t),
    navigationBarTheme: _navigationBarTheme(t),
    navigationRailTheme: _navigationRailTheme(t),
    dividerColor: t.glassBorder,
    switchTheme: _switchTheme(t),
    snackBarTheme: _snackBarTheme(t),
    focusColor: t.primary.withValues(alpha: 0.25),
  );
}

ColorScheme _colorScheme(Brightness brightness, AuroraTokens t) => ColorScheme(
      brightness: brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      secondary: t.magenta,
      // onSecondary und onError sind bewusst fest (dunkel auf Magenta bzw. Rot); Kontrast prüft test/core/contrast_test.dart.
      onSecondary: brightness == Brightness.dark ? const Color(0xFF2A0A1A) : Colors.white,
      tertiary: t.violet,
      error: t.danger,
      onError: brightness == Brightness.dark ? const Color(0xFF1F0505) : Colors.white,
      surface: t.bgSurface,
      onSurface: t.textPrimary,
    );

TextStyle _display(AuroraTokens t, double size, [FontWeight w = FontWeight.w600]) => TextStyle(
      fontFamily: fontDisplay,
      fontSize: size,
      fontWeight: w,
      letterSpacing: -0.01 * size,
      height: 1.2,
      color: t.textPrimary,
      fontVariations: <FontVariation>[FontVariation('wght', w.value.toDouble())],
    );

TextStyle _body(AuroraTokens t, double size, [FontWeight w = FontWeight.w400, Color? c]) => TextStyle(
      fontFamily: fontSans,
      fontSize: size,
      fontWeight: w,
      height: 1.5,
      color: c ?? t.textPrimary,
      fontVariations: <FontVariation>[FontVariation('wght', w.value.toDouble())],
    );

TextTheme _textTheme(AuroraTokens t) => TextTheme(
      displaySmall: _display(t, 30),
      headlineMedium: _display(t, 24),
      headlineSmall: _display(t, 20),
      titleLarge: _display(t, 20),
      titleMedium: _body(t, 16, FontWeight.w600),
      titleSmall: _body(t, 14, FontWeight.w600),
      bodyLarge: _body(t, 16),
      bodyMedium: _body(t, 14),
      bodySmall: _body(t, 12, FontWeight.w400, t.textSecondary),
      labelLarge: _body(t, 14, FontWeight.w600),
      labelMedium: _body(t, 12, FontWeight.w500),
      labelSmall: _body(t, 11, FontWeight.w500, t.textSecondary),
    );

FilledButtonThemeData _filledButtonTheme(AuroraTokens t) => FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        minimumSize: const Size(48, 48),
        textStyle: _body(t, 16, FontWeight.w600),
      ),
    );

OutlinedButtonThemeData _outlinedButtonTheme(AuroraTokens t) => OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: t.primary),
        foregroundColor: t.primary,
        minimumSize: const Size(48, 48),
        textStyle: _body(t, 16, FontWeight.w600),
      ),
    );

TextButtonThemeData _textButtonTheme(AuroraTokens t) => TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        foregroundColor: t.primary,
        minimumSize: const Size(48, 48),
      ),
    );

NavigationBarThemeData _navigationBarTheme(AuroraTokens t) => NavigationBarThemeData(
      backgroundColor: t.bgSurface.withValues(alpha: 0.9),
      indicatorColor: t.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(_body(t, 12, FontWeight.w500)),
      iconTheme: WidgetStatePropertyAll<IconThemeData>(IconThemeData(color: t.textPrimary)),
    );

NavigationRailThemeData _navigationRailTheme(AuroraTokens t) => NavigationRailThemeData(
      backgroundColor: t.bgSurface.withValues(alpha: 0.9),
      indicatorColor: t.primary.withValues(alpha: 0.22),
      selectedLabelTextStyle: _body(t, 12, FontWeight.w600).copyWith(color: t.textPrimary),
      unselectedLabelTextStyle: _body(t, 12, FontWeight.w500).copyWith(color: t.textPrimary),
      selectedIconTheme: IconThemeData(color: t.textPrimary),
      unselectedIconTheme: IconThemeData(color: t.textPrimary),
    );

SwitchThemeData _switchTheme(AuroraTokens t) => SwitchThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(t.textPrimary),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.primary.withValues(alpha: 0.7) : t.textMuted.withValues(alpha: 0.5),
      ),
    );

SnackBarThemeData _snackBarTheme(AuroraTokens t) => SnackBarThemeData(
      backgroundColor: t.bgSurface,
      contentTextStyle: _body(t, 14),
      // Ohne eigene Farbe nimmt SnackBarAction `inversePrimary` (= onPrimary): dunkel auf dunkler
      // Fläche, „Absender blockieren“ war kaum lesbar (Issue #62).
      actionTextColor: t.primary,
      disabledActionTextColor: t.textMuted,
      behavior: SnackBarBehavior.floating,
    );
