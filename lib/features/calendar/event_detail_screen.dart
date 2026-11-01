import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../domain/calendar_event.dart';
import '../../domain/calendar_service.dart';
import '../../domain/occurrence.dart';
import '../../domain/recurrence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../reminders/reminder_coordinator.dart';
import '../chat/sender_name.dart';
import 'calendar_controller.dart';
import 'event_editor_screen.dart';
import 'event_tile.dart';
import 'formatting.dart';

String rsvpLabel(AppLocalizations l, RsvpStatus s) => switch (s) {
      RsvpStatus.accepted => l.rsvpAccepted,
      RsvpStatus.declined => l.rsvpDeclined,
      RsvpStatus.maybe => l.rsvpMaybeStatus,
    };

String recurrenceSummary(AppLocalizations l, Recurrence r) => switch (r.frequency) {
      Frequency.none => '',
      Frequency.daily => l.repeatSummaryDaily(r.interval),
      Frequency.weekly => l.repeatSummaryWeekly(r.interval),
      Frequency.monthly => l.repeatSummaryMonthly(r.interval),
      Frequency.yearly => l.repeatSummaryYearly(r.interval),
    };

/// Zu-/Absage-Schaltflächen (auch in Chat-Karten genutzt).
class RsvpButtons extends StatelessWidget {
  const RsvpButtons({super.key, required this.controller, required this.eventId});
  final CalendarController controller;
  final String eventId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = controller.myRsvp(eventId);
    // Umbrechende Auswahlchips statt einer festen Segmentleiste: auch bei großer Schrift und
    // schmalen Karten bleiben die Beschriftungen vollständig lesbar.
    Widget chip(RsvpStatus status, IconData icon, String label) => ChoiceChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          selected: mine == status,
          showCheckmark: false,
          onSelected: (_) => controller.respond(eventId, status).ignore(),
        );
    return Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
      chip(RsvpStatus.accepted, Icons.check, l.rsvpAccept),
      chip(RsvpStatus.maybe, Icons.help_outline, l.rsvpMaybe),
      chip(RsvpStatus.declined, Icons.close, l.rsvpDecline),
    ]);
  }
}

/// Details eines Termins bzw. eines Vorkommens.
class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({super.key, required this.controller, required this.occurrence});
  final CalendarController controller;
  final Occurrence occurrence;

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  CalendarController get c => widget.controller;

  /// ID des angezeigten Termins. Sie wechselt, wenn der Termin von „Geteilt“ auf „Privat“
  /// gestellt wird (dabei entsteht eine Kopie mit neuer ID, der alte Termin gilt als gelöscht).
  late String _eventId = widget.occurrence.event.id;

  /// Vorkommen des aktuellen Stands von [e]. Das beim Öffnen übergebene Vorkommen veraltet, sobald der
  /// Termin bearbeitet wird (Uhrzeit, Datum, ganztägig; #63): bei Serien gilt derselbe Tag, sonst das
  /// erste Vorkommen ab dem neuen Beginn.
  Occurrence _occurrenceOf(CalendarEvent e) {
    final o = widget.occurrence;
    if (identical(e, o.event)) return o;
    const day = Duration(days: 1);
    for (final x in OccurrenceExpander.expand(e, from: o.start.subtract(day), to: o.end.add(day), viewer: c.zone)) {
      if (x.dateKey == o.dateKey) return x;
    }
    final first = OccurrenceExpander.expand(e, from: e.start.subtract(day), to: e.end.add(day * 2), viewer: c.zone);
    return first.isEmpty ? o : first.first;
  }

  Future<void> _edit(CalendarEvent e) async {
    final saved = await Navigator.of(context).push<CalendarEvent>(MaterialPageRoute<CalendarEvent>(
      builder: (_) => EventEditorScreen(controller: c, existing: e),
    ));
    if (saved != null && mounted && saved.id != _eventId) setState(() => _eventId = saved.id);
  }

  Future<void> _delete(CalendarEvent e) async {
    final l = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    final series = e.recurrence.isRecurring;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.eventDelete),
        content: Text(series ? l.eventDeleteSeriesConfirm : l.eventDeleteConfirm),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          if (series) TextButton(onPressed: () => Navigator.pop(ctx, 'one'), child: Text(l.eventDeleteThis)),
          TextButton(onPressed: () => Navigator.pop(ctx, 'all'), child: Text(series ? l.eventDeleteAll : l.delete)),
        ],
      ),
    );
    if (choice == null) return;
    try {
      if (choice == 'one') {
        await c.excludeOccurrence(e, _occurrenceOf(e).dateKey);
      } else {
        await c.delete(e.id);
      }
      nav.pop();
    } catch (err) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err is CalendarException ? l.eventSaveError : errorText(l, err))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final e = c.eventById(_eventId);
        if (e == null || e.deleted) {
          return Scaffold(appBar: AppBar(), body: Center(child: Text(l.eventCancelled)));
        }
        final fmt = Fmt(context, c.zone);
        final occurrence = _occurrenceOf(e);
        final mine = c.service.canEdit(e);
        final family = services.gateway.family;
        String nameOf(String id) => memberLabel(l, family, id, me: c.me);
        final rsvps = c.rsvpsOf(e.id);
        final defaults = services.settings.settings.defaultReminderMinutes;
        final reminderSet = c.remindersOf(e, defaults).toSet();
        return Scaffold(
          appBar: AppBar(
            title: Text(l.chatEventCard),
            actions: <Widget>[
              if (mine)
                IconButton(
                  tooltip: l.eventEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(e),
                ),
              if (mine)
                IconButton(tooltip: l.eventDelete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(e)),
            ],
          ),
          body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
              GlassCard(
                glow: AuroraTokens.personColors[c.displayColorIndex(e) % AuroraTokens.personColors.length],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Semantics(header: true, child: Text(e.title, style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 6),
                  Text(fmt.range(occurrence, l), style: monoStyle(context, size: 15)),
                  Text(fmt.dateLong(DateTime.parse(occurrence.dateKey)), style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
                    StatusBadge(
                      label: visibilityLabel(l, e.visibility),
                      color: e.isShared ? t.primary : t.violet,
                      icon: e.isShared ? Icons.groups_outlined : Icons.lock_outline,
                    ),
                    if (e.recurrence.isRecurring)
                      StatusBadge(label: recurrenceSummary(l, e.recurrence), color: t.info, icon: Icons.repeat),
                  ]),
                  if (e.location.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 10),
                    Row(children: <Widget>[const Icon(Icons.place_outlined, size: 18), const SizedBox(width: 6), Expanded(child: Text(e.location))]),
                  ],
                  if (e.note.isNotEmpty) ...<Widget>[const SizedBox(height: 10), Text(e.note)],
                  const SizedBox(height: 10),
                  Text(e.ownerId == c.me ? l.eventOwnerYou : l.eventOwner(nameOf(e.ownerId)), style: Theme.of(context).textTheme.bodySmall),
                  if (!mine) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.eventReadOnly, style: Theme.of(context).textTheme.bodySmall)),
                ]),
              ),
              if (e.isShared) ...<Widget>[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(l.eventRsvp, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    RsvpButtons(controller: c, eventId: e.id),
                    const SizedBox(height: 8),
                    for (final entry in rsvps.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(children: <Widget>[
                          PersonDot(colorIndex: c.colorIndexFor(entry.key)),
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
                ),
                if (mine)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.forum_outlined),
                      label: Text(l.eventShareInChat),
                      onPressed: () async {
                        final m = ScaffoldMessenger.of(context);
                        try {
                          await c.shareInChat(e);
                          m.showSnackBar(SnackBar(content: Text(l.eventShared)));
                        } catch (err) {
                          m.showSnackBar(SnackBar(content: Text(errorText(l, err))));
                        }
                      },
                    ),
                  ),
              ],
              // Im Browser gibt es keine Erinnerungen (E-53, #145): keine Karte; gespeicherte Werte bleiben unberührt.
              if (services.reminders != null) ...<Widget>[
                const SizedBox(height: 12),
                GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(l.eventYourReminders, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: <Widget>[
                      for (final m in kReminderChoices)
                        FilterChip(
                          label: Text(m == 0 ? l.reminderAtStart : l.reminderBefore(ReminderCoordinator.durationText(l, m))),
                          selected: reminderSet.contains(m),
                          onSelected: (v) {
                            final next = <int>{...reminderSet};
                            v ? next.add(m) : next.remove(m);
                            c.setReminders(e.id, (next.toList()..sort((a, b) => b.compareTo(a)))).ignore();
                          },
                        ),
                    ]),
                    if (c.hasCustomReminders(e.id))
                      TextButton(onPressed: () => c.setReminders(e.id, null), child: Text(l.eventResetReminders)),
                  ]),
                ),
              ],
              _History(controller: c, event: e),
            ]),
          ),
        );
      },
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
