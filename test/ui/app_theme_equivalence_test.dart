import 'package:family_nexus/domain/app_settings.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// AP-4f: `buildTheme` wird in Teil-Themes zerlegt. Der Wertvergleich stellt sicher, dass dabei jede Eigenschaft gleich
/// bleibt: Gegen eine Kopie der Funktion im Stand vor der Zerlegung, für beide Helligkeiten, beide Einstellungen für
/// reduzierte Effekte und alle Akzentfarben. Die Kopie ist die Referenz und wird nie angepasst.
/// Ausgabe aller Eigenschaften; die Objektnummern (`#1a2b3`) unterscheiden sich je Aufruf und werden entfernt.
String _dump(ThemeData t) => t.toDiagnosticsNode().toStringDeep(minLevel: DiagnosticLevel.debug).replaceAll(RegExp(r'#[0-9a-f]{5}'), '#');

/// Alle Felder der Design-Tokens (die Klasse hat keinen Gleichheitsoperator).
List<Object> _tokens(AuroraTokens t) => <Object>[
      t.bgBody, t.bgSurface, t.glassFill, t.glassBorder, t.textPrimary, t.textSecondary, t.textMuted, t.primary, t.onPrimary,
      t.magenta, t.violet, t.success, t.warning, t.danger, t.info, t.shadow, t.reduceEffects, t.gradientA, t.gradientB,
    ];

void main() {
  test('buildTheme liefert in jeder Kombination dasselbe Theme wie vor der Zerlegung', () {
    var n = 0;
    for (final brightness in Brightness.values) {
      for (final reduce in <bool>[false, true]) {
        for (final accent in AccentChoice.values) {
          final actual = buildTheme(brightness, reduceEffects: reduce, accent: accent);
          final expected = referenceBuildTheme(brightness, reduceEffects: reduce, accent: accent);
          expect(
            _dump(actual),
            _dump(expected),
            reason: '$brightness, reduceEffects=$reduce, $accent',
          );
          expect(_tokens(actual.extension<AuroraTokens>()!), _tokens(expected.extension<AuroraTokens>()!), reason: 'Tokens: $brightness, $reduce, $accent');
          expect(actual.colorScheme, expected.colorScheme, reason: '$brightness, $reduce, $accent');
          expect(actual.textTheme, expected.textTheme, reason: '$brightness, $reduce, $accent');
          n++;
        }
      }
    }
    expect(n, Brightness.values.length * 2 * AccentChoice.values.length);
  });

  test('Standardwerte von buildTheme: dunkel, ohne reduzierte Effekte, Akzent Türkis', () {
    expect(
      _dump(buildTheme(Brightness.dark)),
      _dump(referenceBuildTheme(Brightness.dark)),
    );
  });
}

// ---- Referenz: `buildTheme` im Stand vor AP-4f, unverändert kopiert (nur umbenannt) ----

ThemeData referenceBuildTheme(Brightness brightness, {bool reduceEffects = false, AccentChoice accent = AccentChoice.teal}) {
  final t = (brightness == Brightness.dark ? AuroraTokens.dark : AuroraTokens.light)
      .withReduceEffects(reduceEffects)
      .withAccent(accent);
  final scheme = ColorScheme(
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
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.bgSurface.withValues(alpha: 0.9),
      indicatorColor: t.primary.withValues(alpha: 0.22),
      selectedLabelTextStyle: body(12, FontWeight.w600).copyWith(color: t.textPrimary),
      unselectedLabelTextStyle: body(12, FontWeight.w500).copyWith(color: t.textPrimary),
      selectedIconTheme: IconThemeData(color: t.textPrimary),
      unselectedIconTheme: IconThemeData(color: t.textPrimary),
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
      // Ohne eigene Farbe nimmt SnackBarAction `inversePrimary` (= onPrimary): dunkel auf dunkler
      // Fläche, „Absender blockieren“ war kaum lesbar (Issue #62).
      actionTextColor: t.primary,
      disabledActionTextColor: t.textMuted,
      behavior: SnackBarBehavior.floating,
    ),
    focusColor: t.primary.withValues(alpha: 0.25),
  );
}
