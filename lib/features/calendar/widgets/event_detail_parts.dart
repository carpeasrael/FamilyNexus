part of '../event_detail_screen.dart';

/// Titel, Zeit, Sichtbarkeit, Ort, Notiz und Besitzer des Termins.
class _EventSummaryCard extends StatelessWidget {
  const _EventSummaryCard({
    required this.event,
    required this.glow,
    required this.range,
    required this.dateLong,
    required this.owner,
    required this.mine,
  });
  final CalendarEvent event;
  final Color glow;
  final String range;
  final String dateLong;

  /// „Von dir“ oder „Von {Name}“.
  final String owner;

  /// Der Termin gehört der angemeldeten Person (bearbeitbar).
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final e = event;
    return GlassCard(
      glow: glow,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Semantics(header: true, child: Text(e.title, style: Theme.of(context).textTheme.headlineSmall)),
        const SizedBox(height: 6),
        Text(range, style: monoStyle(context, size: 15)),
        Text(dateLong, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
          StatusBadge(
            label: visibilityLabel(l, e.visibility),
            color: e.isShared ? t.primary : t.violet,
            icon: e.isShared ? Icons.groups_outlined : Icons.lock_outline,
          ),
          if (e.recurrence.isRecurring) StatusBadge(label: recurrenceSummary(l, e.recurrence), color: t.info, icon: Icons.repeat),
        ]),
        if (e.location.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Row(children: <Widget>[const Icon(Icons.place_outlined, size: 18), const SizedBox(width: 6), Expanded(child: Text(e.location))]),
        ],
        if (e.note.isNotEmpty) ...<Widget>[const SizedBox(height: 10), Text(e.note)],
        const SizedBox(height: 10),
        Text(owner, style: Theme.of(context).textTheme.bodySmall),
        if (!mine) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.eventReadOnly, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

/// Zu- und Absagen mit der Liste der Antworten und den Eingeladenen.
class _RsvpCard extends StatelessWidget {
  const _RsvpCard({required this.controller, required this.event, required this.rsvps, required this.nameOf});
  final CalendarController controller;
  final CalendarEvent event;
  final Map<String, RsvpStatus> rsvps;
  final String Function(String userId) nameOf;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = event;
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventRsvp, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        RsvpButtons(controller: controller, eventId: e.id),
        const SizedBox(height: 8),
        for (final entry in rsvps.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: <Widget>[
              PersonDot(colorIndex: controller.colorIndexFor(entry.key)),
              const SizedBox(width: 8),
              Expanded(child: Text(nameOf(entry.key))),
              Text(rsvpLabel(l, entry.value)),
            ]),
          ),
        if (rsvps.isEmpty) Text(l.rsvpNone, style: Theme.of(context).textTheme.bodySmall),
        if (e.attendees.isNotEmpty) ...<Widget>[
          const Divider(),
          Text(l.eventAttendees, style: Theme.of(context).textTheme.labelMedium),
          Wrap(spacing: 6, children: <Widget>[for (final a in e.attendees) Chip(label: Text(nameOf(a)))]),
        ],
      ]),
    );
  }
}

/// „Im Chat teilen“ (nur für den Besitzer eines geteilten Termins).
class _ShareInChatButton extends StatelessWidget {
  const _ShareInChatButton({required this.controller, required this.event});
  final CalendarController controller;
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.forum_outlined),
        label: Text(l.eventShareInChat),
        onPressed: () async {
          final m = ScaffoldMessenger.of(context);
          try {
            await controller.shareInChat(event);
            m.showSnackBar(SnackBar(content: Text(l.eventShared)));
          } catch (err) {
            m.showSnackBar(SnackBar(content: Text(errorText(l, err))));
          }
        },
      ),
    );
  }
}

/// Eigene Erinnerungen an diesen Termin (Minuten vor Beginn), mit „Zurücksetzen“.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.controller, required this.event, required this.selected});
  final CalendarController controller;
  final CalendarEvent event;
  final Set<int> selected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.eventYourReminders, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
          for (final m in kReminderChoices)
            FilterChip(
              label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
              selected: selected.contains(m),
              onSelected: (v) {
                final next = <int>{...selected};
                v ? next.add(m) : next.remove(m);
                controller.setReminders(event.id, (next.toList()..sort((a, b) => b.compareTo(a)))).ignore();
              },
            ),
        ]),
        if (controller.hasCustomReminders(event.id))
          TextButton(onPressed: () => controller.setReminders(event.id, null), child: Text(l.eventResetReminders)),
      ]),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.controller, required this.event});
  final CalendarController controller;
  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<CalendarEvent>>(
      future: controller.history(event.id),
      builder: (context, snap) {
        final list = snap.data ?? const <CalendarEvent>[];
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: GlassCard(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              title: Text('${l.eventHistory} (${list.length})'),
              children: <Widget>[
                for (final h in list)
                  ListTile(
                    dense: true,
                    title: Text(h.deleted ? l.eventCancelled : h.title),
                    subtitle: Text(l.eventVersion(h.version), style: monoStyle(context, size: 12)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
