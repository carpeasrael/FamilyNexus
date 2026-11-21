import 'package:flutter/material.dart';

import '../../../domain/anniversary_calc.dart';
import '../../../ui/theme/tokens.dart';

/// Kleine Symbole in einer Tageszelle des Monatsrasters (E-104): je Art höchstens eines, wie in der Kachel
/// (`Icons.cake` für Geburtstage, `Icons.local_florist` für Gedenktage), in fester Reihenfolge (Torte, dann Blume).
/// Die Beschriftung für Screenreader steht in der Semantics der Zelle (`calendarAnniversariesOnDay`).
class AnniversaryDayMarker extends StatelessWidget {
  const AnniversaryDayMarker({super.key, required this.kinds});

  final Set<AnniversaryKind> kinds;

  @override
  Widget build(BuildContext context) {
    if (kinds.isEmpty) return const SizedBox.shrink();
    final color = AuroraTokens.of(context).primary;
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      if (kinds.contains(AnniversaryKind.birth)) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Icon(Icons.cake, size: 9, color: color)),
      if (kinds.contains(AnniversaryKind.death)) Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Icon(Icons.local_florist, size: 9, color: color)),
    ]);
  }
}
