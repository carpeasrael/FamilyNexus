part of '../chat_screen.dart';

/// Leiste mit den Gesprächen: Familienchat und Einzelchats (mit Status und Ungelesenem).
class _ThreadBar extends StatelessWidget {
  const _ThreadBar({required this.threads, required this.selected, required this.onSelect});
  final List<ChatThread> threads;
  final String selected;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    return Semantics(
      container: true,
      label: l.chatThreads,
      child: SizedBox(
        height: 52,
        child: PresenceBuilder(
          builder: (context, now) => ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: threads.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final t = threads[i];
              final online = t.peerId != null && presenceOf(services, t.peerId!, now).status == PresenceStatus.online;
              final unread = t.unread;
              final label = t.isFamily ? l.chatThreadFamily(t.title) : l.chatThreadDirect(t.title);
              final status = t.peerId == null ? null : presenceLabel(l, presenceOf(services, t.peerId!, now), now);
              return Semantics(
                button: true,
                selected: t.id == selected,
                label: <String>[label, ?status, if (unread > 0) l.chatUnreadCount(unread)].join(', '),
                excludeSemantics: true,
                child: ChoiceChip(
                  selected: t.id == selected,
                  onSelected: (_) => onSelect(t.id),
                  avatar: t.isFamily ? const Icon(Icons.groups_outlined, size: 18) : PresenceDot(online: online),
                  label: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    // Ungelesenes zusätzlich fett, nicht nur über das Abzeichen (#254).
                    Text(t.title, style: unread > 0 ? const TextStyle(fontWeight: FontWeight.w700) : null),
                    if (unread > 0) ...<Widget>[const SizedBox(width: 6), Badge(label: Text('$unread'))],
                  ]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Datumszeile vor der ersten Nachricht eines Tages (#254).
class _DayLine extends StatelessWidget {
  const _DayLine({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final label = switch (chatDayOf(day, DateTime.now())) {
      ChatDay.today => l.chatToday,
      ChatDay.yesterday => l.chatYesterday,
      ChatDay.other => DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(day),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Semantics(
          header: true,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textSecondary)),
        ),
      ),
    );
  }
}

/// Marke über der ersten ungelesenen Nachricht: Linie **und** Text, nicht nur Farbe (#254).
class _UnreadLine extends StatelessWidget {
  const _UnreadLine({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: <Widget>[
        Expanded(child: Divider(color: t.primary, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            l.chatNewMessages,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.primary, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Divider(color: t.primary, thickness: 1)),
      ]),
    );
  }
}
