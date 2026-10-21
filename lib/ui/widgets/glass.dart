import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Hintergrund mit sanftem Farbverlauf; bei „Effekte reduzieren“ einfarbig.
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bgBody,
        gradient: t.reduceEffects
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.alphaBlend(t.gradientA.withValues(alpha: 0.35), t.bgBody),
                  t.bgBody,
                  Color.alphaBlend(t.gradientB.withValues(alpha: 0.4), t.bgBody),
                ],
              ),
      ),
      child: child,
    );
  }
}

/// Glasfläche: halbtransparent, Unschärfe, feine Kante. Mit
/// „Effekte reduzieren“ deckend ohne Unschärfe.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glow,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? glow;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    final radius = BorderRadius.circular(18);
    final fill = t.reduceEffects ? Color.alphaBlend(t.glassFill, t.bgSurface) : t.glassFill;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: t.glassBorder),
      ),
      // Eigene Material-Ebene, damit ListTile & Co. Tinte/Hintergrund zeigen.
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (!t.reduceEffects) {
      content = ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: content,
        ),
      );
    }
    content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(color: t.shadow, blurRadius: t.reduceEffects ? 4 : 24, offset: const Offset(0, 8)),
          if (glow != null && !t.reduceEffects)
            BoxShadow(color: glow!.withValues(alpha: 0.35), blurRadius: 18),
        ],
      ),
      child: content,
    );
    if (onTap != null) {
      content = Semantics(
        button: true,
        label: semanticLabel,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }
}

/// Statusbadge: Pille mit Text (nie nur Farbe).
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = AuroraTokens.of(context);
    final bg = Color.alphaBlend(color.withValues(alpha: 0.18), t.bgSurface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: 14, color: t.textPrimary), const SizedBox(width: 4)],
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ]),
    );
  }
}
