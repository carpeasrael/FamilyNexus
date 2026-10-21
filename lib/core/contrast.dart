import 'dart:math' as math;
import 'dart:ui';

/// WCAG-2.x-Kontrastberechnung (relative Luminanz).
double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double relativeLuminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// Kontrastverhältnis zweier opaker Farben (1..21).
double contrastRatio(Color a, Color b) {
  final la = relativeLuminance(a);
  final lb = relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// Legt [fg] (ggf. mit Alpha) über [bg] und liefert die resultierende Farbe.
Color composite(Color fg, Color bg) => Color.alphaBlend(fg, bg);
