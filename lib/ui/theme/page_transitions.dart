import 'package:flutter/material.dart';

import '../widgets/glass.dart';

/// #525: Die Seiten sind durchsichtig (der Scaffold ist transparent, der Verlauf liegt nur einmal über dem Navigator).
/// Beim Seitenwechsel, besonders bei der iOS-Wischgeste, schien so die Seite darunter durch. Dieser Builder legt jede
/// Seite auf einen eigenen deckenden Hintergrund ([AuroraBackground]) und reicht sonst alles an den Standard-Builder der
/// Plattform weiter (Übergang, Dauer, `delegatedTransition` für den Versatz der Seite darunter).
class OpaquePageTransitionsBuilder extends PageTransitionsBuilder {
  const OpaquePageTransitionsBuilder(this.inner);

  final PageTransitionsBuilder inner;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => inner.delegatedTransition;

  @override
  Duration get transitionDuration => inner.transitionDuration;

  @override
  Duration get reverseTransitionDuration => inner.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      inner.buildTransitions<T>(route, context, animation, secondaryAnimation, AuroraBackground(child: child));
}

/// Die Standard-Übergänge des Frameworks je Plattform, jeweils mit deckendem Hintergrund (alle Plattformen,
/// auch Fuchsia: ohne Eintrag gälte der Zoom-Übergang des Frameworks ohne Hintergrund).
PageTransitionsTheme opaquePageTransitionsTheme() {
  final defaults = const PageTransitionsTheme().builders;
  return PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      for (final p in TargetPlatform.values) p: OpaquePageTransitionsBuilder(defaults[p] ?? const ZoomPageTransitionsBuilder()),
    },
  );
}
