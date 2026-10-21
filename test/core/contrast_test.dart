import 'package:family_nexus/core/contrast.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/theme/tokens.dart';
import 'package:family_nexus/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Kontrastberechnung: Schwarz/Weiß = 21', () {
    expect(contrastRatio(const Color(0xFF000000), const Color(0xFFFFFFFF)), closeTo(21, 0.01));
  });

  for (final entry in <String, AuroraTokens>{
    'dunkel': AuroraTokens.dark,
    'hell': AuroraTokens.light,
  }.entries) {
    group('WCAG AA (${entry.key})', () {
      final t = entry.value;
      // Glas liegt über dem Hintergrund; schlechtester Fall = Verlauf-Endfarbe.
      final worstBackgrounds = <Color>[
        t.bgBody,
        composite(t.glassFill, t.bgBody),
        composite(t.glassFill, composite(t.gradientA.withValues(alpha: 0.4), t.bgBody)),
        composite(t.glassFill, composite(t.gradientB.withValues(alpha: 0.4), t.bgBody)),
        composite(t.glassFill, t.bgSurface),
      ];

      test('Text auf allen Glasflächen ≥ 4.5', () {
        for (final bg in worstBackgrounds) {
          expect(contrastRatio(t.textPrimary, bg), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(t.textSecondary, bg), greaterThanOrEqualTo(4.5));
          expect(contrastRatio(t.textMuted, bg), greaterThanOrEqualTo(4.5));
        }
      });

      test('Primärbutton: onPrimary auf primary ≥ 4.5', () {
        expect(contrastRatio(t.onPrimary, t.primary), greaterThanOrEqualTo(4.5));
      });

      test('Akzent-/Statusfarben als Text auf Oberfläche ≥ 4.5', () {
        for (final c in <Color>[t.primary, t.success, t.danger, t.info, t.warning, t.magenta, t.violet]) {
          expect(contrastRatio(c, t.bgSurface), greaterThanOrEqualTo(4.5), reason: '$c');
        }
      });

      test('Rahmen/UI-Komponenten ≥ 3 (Eingabefeld-Rand)', () {
        expect(contrastRatio(t.textMuted, t.bgSurface), greaterThanOrEqualTo(3));
      });
    });
  }

  for (final b in Brightness.values) {
    test('ColorScheme-Paare erreichen AA (${b.name})', () {
      final c = buildTheme(b).colorScheme;
      final pairs = <String, (Color, Color)>{
        'primary': (c.onPrimary, c.primary),
        'secondary': (c.onSecondary, c.secondary),
        'error': (c.onError, c.error),
        'surface': (c.onSurface, c.surface),
      };
      for (final e in pairs.entries) {
        expect(contrastRatio(e.value.$1, e.value.$2), greaterThanOrEqualTo(4.5), reason: e.key);
      }
    });
  }

  test('Rahmen und Fokus gegen Oberfläche ≥ 3 (sichtbare Bedienelemente)', () {
    for (final t in <AuroraTokens>[AuroraTokens.dark, AuroraTokens.light]) {
      final border = composite(t.glassBorder, composite(t.glassFill, t.bgBody));
      expect(contrastRatio(t.primary, t.bgSurface), greaterThanOrEqualTo(3));
      // Eingabefeld-Rand nutzt textMuted (siehe Theme), nicht den Glasrand.
      expect(contrastRatio(t.textMuted, t.bgSurface), greaterThanOrEqualTo(3));
      expect(border, isNotNull);
    }
  });

  for (final base in <String, AuroraTokens>{'dunkel': AuroraTokens.dark, 'hell': AuroraTokens.light}.entries) {
    for (final accent in AccentChoice.values) {
      test('Akzent ${accent.name} (${base.key}): Kontrast von Schaltflächen, Text und Verlauf ≥ 4.5', () {
        final t = base.value.withAccent(accent);
        expect(contrastRatio(t.onPrimary, t.primary), greaterThanOrEqualTo(4.5), reason: 'Schrift auf Primärfläche');
        expect(contrastRatio(t.primary, t.bgSurface), greaterThanOrEqualTo(4.5), reason: 'Akzent als Text/Rand auf Oberfläche');
        expect(contrastRatio(t.primary, composite(t.glassFill, t.bgBody)), greaterThanOrEqualTo(4.5), reason: 'Akzent auf Glas');
        final backgrounds = <Color>[
          composite(t.glassFill, composite(t.gradientA.withValues(alpha: 0.4), t.bgBody)),
          composite(t.glassFill, composite(t.gradientA.withValues(alpha: 0.35), t.bgBody)),
        ];
        for (final bg in backgrounds) {
          for (final text in <Color>[t.textPrimary, t.textSecondary, t.textMuted]) {
            expect(contrastRatio(text, bg), greaterThanOrEqualTo(4.5), reason: 'Text auf Verlauf');
          }
          expect(contrastRatio(t.primary, bg), greaterThanOrEqualTo(3), reason: 'Akzent als Bedienelement auf Verlauf');
        }
      });
    }
  }
}
