import 'package:flutter/material.dart';

import '../../core/contrast.dart';
import '../../domain/app_settings.dart';

/// AURORA-Tokens (Teal-Basis) plus Neon-Akzente. Alle Farben der App kommen
/// von hier; Widgets lesen sie über [AuroraTokens.of].
@immutable
class AuroraTokens extends ThemeExtension<AuroraTokens> {
  const AuroraTokens({
    required this.bgBody,
    required this.bgSurface,
    required this.glassFill,
    required this.glassBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.magenta,
    required this.violet,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.shadow,
    required this.reduceEffects,
    required this.gradientA,
    required this.gradientB,
  });

  final Color bgBody;
  final Color bgSurface;
  final Color glassFill;
  final Color glassBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color onPrimary;
  final Color magenta;
  final Color violet;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color shadow;
  final bool reduceEffects;
  final Color gradientA;
  final Color gradientB;

  static const AuroraTokens dark = AuroraTokens(
    bgBody: Color(0xFF0B1120),
    bgSurface: Color(0xFF0F172A),
    glassFill: Color(0x33162033),
    glassBorder: Color(0x40FFFFFF),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF94A3B8),
    primary: Color(0xFF2DD4BF),
    onPrimary: Color(0xFF04201D),
    magenta: Color(0xFFF472B6),
    violet: Color(0xFFA78BFA),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    info: Color(0xFF38BDF8),
    shadow: Color(0x73000000),
    reduceEffects: false,
    gradientA: Color(0xFF0F766E),
    gradientB: Color(0xFF4C1D95),
  );

  static const AuroraTokens light = AuroraTokens(
    bgBody: Color(0xFFF6F7FB),
    bgSurface: Color(0xFFFFFFFF),
    glassFill: Color(0xB3FFFFFF),
    glassBorder: Color(0x33334155),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF526071),
    primary: Color(0xFF0F766E),
    onPrimary: Color(0xFFFFFFFF),
    magenta: Color(0xFFBE185D),
    violet: Color(0xFF6D28D9),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    info: Color(0xFF0369A1),
    shadow: Color(0x1F0F172A),
    reduceEffects: false,
    gradientA: Color(0xFFCCFBF1),
    gradientB: Color(0xFFEDE9FE),
  );

  /// Neonfarben für Personen (Termine).
  static const List<Color> personColors = <Color>[
    Color(0xFF2DD4BF),
    Color(0xFFF472B6),
    Color(0xFFA78BFA),
    Color(0xFF38BDF8),
    Color(0xFFFBBF24),
    Color(0xFF4ADE80),
    Color(0xFFFB923C),
    Color(0xFFF87171),
  ];

  static AuroraTokens of(BuildContext context) =>
      Theme.of(context).extension<AuroraTokens>()!;

  AuroraTokens withReduceEffects(bool value) => copyWith(reduceEffects: value);

  /// Setzt die gewählte Neon-Akzentfarbe: Primärfarbe, passende Schrift darauf und den Verlauf.
  /// Der dunkle Modus nutzt die leuchtende, der helle die abgedunkelte Variante (Kontrast ≥ 4,5).
  AuroraTokens withAccent(AccentChoice choice) {
    final a = AccentPalette.of(choice);
    final dark = bgBody.computeLuminance() < 0.5;
    final primary = dark ? a.neon : a.deep;
    const darkText = Color(0xFF0B1120);
    const lightText = Color(0xFFFFFFFF);
    final onPrimary = contrastRatio(darkText, primary) >= contrastRatio(lightText, primary) ? darkText : lightText;
    return copyWith(
      primary: primary,
      onPrimary: onPrimary,
      gradientA: dark ? a.deep : Color.lerp(a.neon, const Color(0xFFFFFFFF), 0.7),
    );
  }

  @override
  AuroraTokens copyWith({bool? reduceEffects, Color? primary, Color? onPrimary, Color? gradientA}) => AuroraTokens(
        bgBody: bgBody,
        bgSurface: bgSurface,
        glassFill: glassFill,
        glassBorder: glassBorder,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textMuted: textMuted,
        primary: primary ?? this.primary,
        onPrimary: onPrimary ?? this.onPrimary,
        magenta: magenta,
        violet: violet,
        success: success,
        warning: warning,
        danger: danger,
        info: info,
        shadow: shadow,
        reduceEffects: reduceEffects ?? this.reduceEffects,
        gradientA: gradientA ?? this.gradientA,
        gradientB: gradientB,
      );

  @override
  AuroraTokens lerp(ThemeExtension<AuroraTokens>? other, double t) =>
      t < 0.5 ? this : (other as AuroraTokens? ?? this);
}

/// Farben der wählbaren Neon-Akzente: [neon] leuchtet auf dunklem Grund, [deep] ist die abgedunkelte
/// Variante für hellen Grund (jeweils mit ausreichendem Kontrast für Text und Schaltflächen).
class AccentPalette {
  const AccentPalette(this.neon, this.deep);
  final Color neon;
  final Color deep;

  static const Map<AccentChoice, AccentPalette> all = <AccentChoice, AccentPalette>{
    AccentChoice.teal: AccentPalette(Color(0xFF2DD4BF), Color(0xFF0F766E)),
    AccentChoice.magenta: AccentPalette(Color(0xFFF472B6), Color(0xFFBE185D)),
    AccentChoice.violet: AccentPalette(Color(0xFFA78BFA), Color(0xFF6D28D9)),
    AccentChoice.sky: AccentPalette(Color(0xFF38BDF8), Color(0xFF0369A1)),
    AccentChoice.lime: AccentPalette(Color(0xFFA3E635), Color(0xFF3F6212)),
    AccentChoice.orange: AccentPalette(Color(0xFFFB923C), Color(0xFFC2410C)),
    AccentChoice.rose: AccentPalette(Color(0xFFFB7185), Color(0xFFBE123C)),
    AccentChoice.green: AccentPalette(Color(0xFF4ADE80), Color(0xFF15803D)),
  };

  static AccentPalette of(AccentChoice c) => all[c]!;
}
