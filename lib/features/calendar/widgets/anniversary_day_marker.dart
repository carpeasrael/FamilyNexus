import 'package:flutter/material.dart';

import '../../../ui/theme/tokens.dart';

/// Kleines Symbol in einer Tageszelle des Monatsrasters: Es gibt einen Geburts- oder Gedenktag (E-104).
/// Die Beschriftung für Screenreader steht in der Semantics der Zelle (`calendarAnniversariesOnDay`).
class AnniversaryDayMarker extends StatelessWidget {
  const AnniversaryDayMarker({super.key});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Icon(Icons.cake, size: 9, color: AuroraTokens.of(context).primary));
}
