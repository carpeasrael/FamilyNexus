import 'package:flutter/material.dart';

import '../../domain/calendar_event.dart';
import '../../domain/occurrence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import 'calendar_controller.dart';
import 'formatting.dart';

/// Eintrag eines Vorkommens in Listen. Sichtbarkeit und Wiederholung werden
/// immer zusätzlich zur Farbe über Symbole und Text vermittelt.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.occurrence, required this.controller, required this.onTap});

  final Occurrence occurrence;
  final CalendarController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final fmt = Fmt(context, controller.zone);
    final e = occurrence.event;
    final color = AuroraTokens.personColors[controller.displayColorIndex(e) % AuroraTokens.personColors.length];
    final mine = e.ownerId == controller.me;
    final owner = mine ? '' : ', ${l.eventOwner(controller.displayNameOf(e.ownerId) ?? l.chatFormerMember)}';
    final repeat = e.recurrence.isRecurring ? ', ${l.eventRecurring}' : '';
    final privateLabel = e.isShared ? l.visibilityShared : l.visibilityPrivate;
    final range = fmt.range(occurrence, l);
    final semanticLabel = '${e.title}, $range, $privateLabel$owner$repeat';
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GlassCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          glow: color,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Container(width: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(e.title, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(range, style: monoStyle(context, size: 13, color: t.textSecondary)),
                  if (!mine)
                    Text(l.eventOwner(controller.displayNameOf(e.ownerId) ?? l.chatFormerMember), style: Theme.of(context).textTheme.bodySmall),
                  if (e.location.isNotEmpty)
                    Row(children: <Widget>[
                      Icon(Icons.place_outlined, size: 14, color: t.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(child: Text(e.location, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                ]),
              ),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                StatusBadge(
                  label: privateLabel,
                  color: e.isShared ? t.primary : t.violet,
                  icon: e.isShared ? Icons.groups_outlined : Icons.lock_outline,
                ),
                if (e.recurrence.isRecurring)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(Icons.repeat, size: 16, color: t.textSecondary, semanticLabel: l.eventRecurring),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Kleine Farbmarke einer Person (immer mit Namen daneben verwenden).
class PersonDot extends StatelessWidget {
  const PersonDot({super.key, required this.colorIndex});
  final int colorIndex;

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AuroraTokens.personColors[colorIndex % AuroraTokens.personColors.length],
          shape: BoxShape.circle,
        ),
      );
}

String visibilityLabel(AppLocalizations l, EventVisibility v) =>
    v == EventVisibility.shared ? l.visibilityShared : l.visibilityPrivate;
