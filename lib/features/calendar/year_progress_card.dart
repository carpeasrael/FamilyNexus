import 'package:flutter/material.dart';

import '../../domain/year_progress.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';

/// Zeigt, wie weit das laufende Jahr ist: Tag x von y, verbleibende Tage, Prozent und ein Balken (#337).
/// Der Balken ist rein grafisch; Screenreader hören den Satz (Prozentwert), nicht zweimal.
class YearProgressCard extends StatelessWidget {
  const YearProgressCard({super.key, required this.today});

  /// Heutiger Kalendertag in der Zeitzone des Geräts.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final p = YearProgress.of(today);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GlassCard(
        child: Semantics(
          container: true,
          label: l.calendarYearSemantics(p.percent),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            ExcludeSemantics(child: Text('${p.year}', style: Theme.of(context).textTheme.titleSmall)),
            const SizedBox(height: 4),
            ExcludeSemantics(
              child: Text(l.calendarYearText(p.dayOfYear, p.daysInYear, p.daysLeft, p.percent), style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 8),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  key: const Key('yearProgressBar'),
                  value: p.fraction,
                  minHeight: 8,
                  color: t.primary,
                  backgroundColor: t.primary.withValues(alpha: 0.18),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
