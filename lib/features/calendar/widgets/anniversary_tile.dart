import 'package:flutter/material.dart';

import '../../../domain/anniversaries.dart';
import '../../../domain/anniversary_calc.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../ui/theme/tokens.dart';
import '../../../ui/widgets/glass.dart';
import '../formatting.dart';

/// Text einer Zusatzzeile der Anzeigeregel (E-104); die Domäne liefert nur Art und Zahl.
String anniversaryLineText(AppLocalizations l, AnniversaryLine line) => switch (line.kind) {
      AnniversaryLineKind.willBe => l.anniversaryWillBe(line.number),
      AnniversaryLineKind.currentAge => l.anniversaryCurrentAge(line.number),
      AnniversaryLineKind.isAge => l.anniversaryIsAge(line.number),
      AnniversaryLineKind.wouldBe => l.anniversaryWouldBe(line.number),
      AnniversaryLineKind.nthDeathDay => l.anniversaryNthDeathDay(line.number),
      AnniversaryLineKind.yearsAgo => l.anniversaryYearsAgo(line.number),
    };

/// „heute“, „morgen“, „in {d} Tagen“; vergangene Tage im Kalender haben keine Angabe.
String? anniversaryWhenText(AppLocalizations l, int daysUntil) {
  if (daysUntil < 0) return null;
  if (daysUntil == 0) return l.anniversaryToday;
  if (daysUntil == 1) return l.anniversaryTomorrow;
  return l.anniversaryInDays(daysUntil);
}

/// Datum der Person in der Schreibweise der App-Sprache (E-20): mit Jahr voll, ohne Jahr Tag und Monat.
String anniversaryDateText(AnniversaryDate d, String locale) =>
    d.year == null ? formatDayMonthNumeric(DateTime.utc(2000, d.month, d.day), locale) : formatDateNumeric(DateTime.utc(d.year!, d.month, d.day), locale);

/// Kachel eines Geburts- oder Gedenktags: Symbol und Text (nie nur Farbe), Name, Zusatzzeilen, optional „wann“.
class AnniversaryTile extends StatelessWidget {
  const AnniversaryTile({super.key, required this.hit, this.showWhen = false, this.showDate = false, this.onTap});

  final AnniversaryHit hit;

  /// Tagesangabe („heute“, „morgen“, „in n Tagen“) anhängen (Heute-Karte, Liste).
  final bool showWhen;

  /// Datum der Person voranstellen (Liste).
  final bool showDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final birth = hit.kind == AnniversaryKind.birth;
    final name = hit.person.name;
    final title = birth ? l.anniversaryBirthdayOf(name) : l.anniversaryDeathdayOf(name);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final parts = <String>[
      if (showDate) anniversaryDateText(hit.date, locale),
      for (final line in anniversaryLines(hit, hit.person)) anniversaryLineText(l, line),
      if (showWhen) ?anniversaryWhenText(l, hit.daysUntil),
    ];
    final color = birth ? t.primary : t.textSecondary;
    return Semantics(
      label: <String>[title, ...parts].join(', '),
      button: onTap != null,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Icon(birth ? Icons.cake : Icons.local_florist, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (parts.isNotEmpty) Text(parts.join(' · '), style: Theme.of(context).textTheme.bodyMedium),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
