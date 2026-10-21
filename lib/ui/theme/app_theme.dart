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
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.primary,
    onPrimary: t.onPrimary,
    secondary: t.magenta,
    onSecondary: brightness == Brightness.dark ? const Color(0xFF2A0A1A) : Colors.white,
    tertiary: t.violet,
    error: t.danger,
    onError: brightness == Brightness.dark ? const Color(0xFF1F0505) : Colors.white,
    surface: t.bgSurface,
    onSurface: t.textPrimary,
  );

  TextStyle display(double size, [FontWeight w = FontWeight.w600]) => TextStyle(
        fontFamily: fontDisplay,
        fontSize: size,
        fontWeight: w,
        letterSpacing: -0.01 * size,
        height: 1.2,
        color: t.textPrimary,
        fontVariations: <FontVariation>[FontVariation('wght', w.value.toDouble())],
      );
  TextStyle body(double size, [FontWeight w = FontWeight.w400, Color? c]) => TextStyle(
        fontFamily: fontSans,
        fontSize: size,
        fontWeight: w,
        height: 1.5,
        color: c ?? t.textPrimary,
        fontVariations: <FontVariation>[FontVariation('wght', w.value.toDouble())],
      );

  final text = TextTheme(
    displaySmall: display(30),
    headlineMedium: display(24),
    headlineSmall: display(20),
    titleLarge: display(20),
    titleMedium: body(16, FontWeight.w600),
    titleSmall: body(14, FontWeight.w600),
    bodyLarge: body(16),
    bodyMedium: body(14),
    bodySmall: body(12, FontWeight.w400, t.textSecondary),
    labelLarge: body(14, FontWeight.w600),
    labelMedium: body(12, FontWeight.w500),
    labelSmall: body(11, FontWeight.w500, t.textSecondary),
  );

  final focusBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: t.primary, width: 2),
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: t.textMuted),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: t.bgSurface,
    fontFamily: fontSans,
    textTheme: text,
    extensions: <ThemeExtension<dynamic>>[t],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: t.textPrimary,
      titleTextStyle: display(20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: focusBorder,
      filled: true,
      fillColor: t.glassFill,
      labelStyle: body(14, FontWeight.w400, t.textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        minimumSize: const Size(48, 48),
        textStyle: body(16, FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: t.primary),
        foregroundColor: t.primary,
        minimumSize: const Size(48, 48),
        textStyle: body(16, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: const StadiumBorder(),
        foregroundColor: t.primary,
        minimumSize: const Size(48, 48),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t.bgSurface.withValues(alpha: 0.9),
      indicatorColor: t.primary.withValues(alpha: 0.22),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(body(12, FontWeight.w500)),
      iconTheme: WidgetStatePropertyAll<IconThemeData>(IconThemeData(color: t.textPrimary)),
    ),
    dividerColor: t.glassBorder,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll<Color>(t.textPrimary),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? t.primary.withValues(alpha: 0.7) : t.textMuted.withValues(alpha: 0.5),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.bgSurface,
      contentTextStyle: body(14),
      behavior: SnackBarBehavior.floating,
    ),
    focusColor: t.primary.withValues(alpha: 0.25),
  );
}
