import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Zentrale Layoutgrenzen für Tablets und große Fenster (REQ-TABLET-01, #274, E-92).
///
/// Maßgeblich ist allein die nutzbare Fläche in logischen Pixeln: Fenstergröße abzüglich der vom System
/// gemeldeten sicheren Ränder, **ohne** Bildschirmtastatur. Gerätename, Zollgröße und Ausrichtung entscheiden
/// nicht. Alle Zahlen stehen nur hier.

/// Unterhalb dieser Breite: einspaltig mit unterer Leiste (Smartphone-Layout).
const double kCompactMax = 600;

/// Unterhalb dieser Höhe: einspaltig mit unterer Leiste, auch bei großer Breite (Smartphone quer).
/// Eine seitliche Leiste mit fünf Zielen und ein Chat samt Tastatur brauchen mehr Höhe.
const double kLowHeight = 480;

/// Breite der seitlichen Navigationsleiste (Untergrenze; sie wächst mit der Textskalierung).
const double kRailWidth = 80;

/// Mindestbreite je Spalte im Zweispalter (Kalender, Chat).
const double kPaneMinWidth = 440;

/// Anteil des Chats an der Inhaltsbreite im Zweispalter.
const double kChatPaneFraction = 0.4;

/// Obergrenze der Chatspalte und der Chat-Blasen.
const double kChatPaneMax = 560;

/// Ab dieser Breite Zweispalter: Leiste (80) + 2 × Mindestbreite (440) + Trenner (1) = 961, aufgerundet.
const double kExpandedMin = 1000;

/// Obergrenze der Inhaltsbreite für Listen und Formulare auf breiten Fenstern.
const double kContentMaxWidth = 720;

/// Breite des Trenners zwischen den Spalten.
const double kPaneDivider = 1;

/// Anteil der Spaltenbreite, den eine Chat-Blase höchstens belegt.
const double kBubbleFraction = 0.82;

enum WindowClass {
  /// Einspaltig, untere Leiste.
  compact,

  /// Einspaltig, seitliche Leiste.
  medium,

  /// Zwei Spalten (Kalender und Chat), seitliche Leiste.
  expanded,
}

/// Klasse der nutzbaren Fläche [usable] (Fenster minus sichere Ränder, ohne Tastatur).
WindowClass windowClassOf(Size usable) {
  if (usable.height < kLowHeight || usable.width < kCompactMax) return WindowClass.compact;
  if (usable.width < kExpandedMin) return WindowClass.medium;
  return WindowClass.expanded;
}

/// Nutzbare Fläche: Fenster minus sichere Ränder (`viewPadding`). Die Tastatur (`viewInsets`) zählt nicht mit,
/// sonst kippte das Layout beim Tippen (E-92).
Size usableSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final pad = MediaQuery.viewPaddingOf(context);
  return Size(math.max(0, size.width - pad.horizontal), math.max(0, size.height - pad.vertical));
}

/// Klasse des umgebenden Fensters.
WindowClass windowClassIn(BuildContext context) => windowClassOf(usableSize(context));

/// Spaltenbreiten im Zweispalter bei Inhaltsbreite [contentWidth] (ohne Leiste): Chat = 0,4 · Breite,
/// auf 440 bis 560 begrenzt; Kalender = Rest abzüglich Trenner.
({double calendar, double chat}) paneWidths(double contentWidth) {
  final chat = (contentWidth * kChatPaneFraction).clamp(kPaneMinWidth, kChatPaneMax).toDouble();
  return (calendar: math.max(0, contentWidth - chat - kPaneDivider), chat: chat);
}

/// Höchste Breite einer Chat-Blase in einer Spalte der Breite [paneWidth].
double bubbleMaxWidth(double paneWidth) => math.min(paneWidth * kBubbleFraction, kChatPaneMax);

/// Begrenzt den Inhalt auf [maxWidth] und zentriert ihn. Der Elementbaum bleibt bei jeder Breite gleich, nur
/// `maxWidth` wechselt; so geht beim Drehen kein Zustand verloren. Der Inhalt bekommt feste Maße (Breite
/// höchstens [maxWidth], Höhe wie angeboten), also dieselben engen Vorgaben wie ohne Wrapper.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, this.maxWidth = kContentMaxWidth, required this.child});

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => Center(
          child: SizedBox(
            width: constraints.hasBoundedWidth ? math.min(constraints.maxWidth, maxWidth) : null,
            height: constraints.hasBoundedHeight ? constraints.maxHeight : null,
            child: child,
          ),
        ),
      );
}
