part of '../chat_screen.dart';

/// Gesprächsliste, Startseite des Chat-Tabs bei mehreren Gesprächen (#423): Familienchat zuerst, danach die
/// Einzelchats mit Vorschau, Zeit, Ungelesen-Zähler und Online-Status. Wird nur in der Listenansicht aufgebaut (ein Durchlauf je Gespräch und Aufbau; `Offstage` baut den Tab auch, wenn er nicht sichtbar ist, die Kosten sind klein).
class _ThreadList extends StatelessWidget {
  const _ThreadList({required this.threads, required this.scroll, required this.onOpen});
  final List<ChatThread> threads;
  final ScrollController scroll;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final g = services.gateway;
    final blocked = services.settings.settings.blockedUsers.toSet();
    final rows = orderedThreadRows(threads, g.messagesIn, blocked, g.userId);
    return PresenceBuilder(
      builder: (context, now) => ListView.builder(
        controller: scroll,
        itemCount: rows.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Semantics(
                header: true,
                child: Text(l.chatThreads, style: Theme.of(context).textTheme.titleMedium),
              ),
            );
          }
          return _ThreadRowTile(row: rows[i - 1], now: now, onTap: onOpen);
        },
      ),
    );
  }
}

/// Eine Zeile der Gesprächsliste, mindestens 56 dp hoch, als Button.
class _ThreadRowTile extends StatelessWidget {
  const _ThreadRowTile({required this.row, required this.now, required this.onTap});
  final ThreadRow row;
  final DateTime now;
  final void Function(String id) onTap;

  /// Heute die Uhrzeit, gestern „Gestern“, sonst das Datum (Ortszeit).
  static String _timeText(BuildContext context, AppLocalizations l, DateTime time) {
    final t = time.toLocal();
    return switch (chatDayOf(t, DateTime.now())) {
      ChatDay.today => formatClock(context, t.hour, t.minute),
      ChatDay.yesterday => l.chatYesterday,
      ChatDay.other => DateFormat.yMd(Localizations.localeOf(context).toLanguageTag()).format(t),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final services = AppScope.of(context);
    final thread = row.thread;
    final last = row.last;
    final unread = thread.unread;
    final peer = thread.peerId;
    final presence = peer == null ? null : presenceOf(services, peer, now);
    final status = presence == null ? null : presenceLabel(l, presence, now);
    final preview = last == null ? '' : threadPreviewText(l, last, mine: last.senderId == services.gateway.userId);
    final hasPreview = preview.isNotEmpty;
    // Ohne Nachricht: Online-Status (Einzelchat) bzw. „Noch keine Nachrichten“ (Familienchat).
    final second = hasPreview ? preview : (status ?? l.emptyChat);
    final label = thread.isFamily ? l.chatThreadFamily(thread.title) : l.chatThreadDirect(thread.title);
    final timeText = last == null ? null : _timeText(context, l, last.time);
    final semantic = <String>[
      label,
      ?(hasPreview ? status : null),
      second,
      if (unread > 0) l.chatUnreadCount(unread),
    ].join(', ');
    return Semantics(
      button: true,
      label: semantic,
      onTap: () => onTap(thread.id),
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey<String>('thread-${thread.id}'),
        onTap: () => onTap(thread.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: <Widget>[
              // Einzelchat: Avatar mit Online-Punkt (#422); der Status steht zusätzlich als Text in der Zeile.
              SizedBox(
                width: 40,
                child: Center(
                  child: peer == null
                      ? const Icon(Icons.groups_outlined, size: 28)
                      : MemberAvatarView(
                          userId: peer,
                          size: 40,
                          colorIndex: personColorOf(services, peer),
                          online: presence?.status == PresenceStatus.online,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  // Ungelesenes zusätzlich fett, nicht nur über das Abzeichen (#254).
                  Text(
                    thread.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: unread > 0 ? FontWeight.w700 : null),
                  ),
                  Text(
                    second,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: <Widget>[
                if (timeText != null)
                  Text(timeText, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textSecondary)),
                if (unread > 0) ...<Widget>[const SizedBox(height: 4), Badge(label: Text('$unread'))],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Kopfzeile im Gespräch bei mehreren Gesprächen (#423): Zurück-Pfeil zur Liste, Titel und Online-Status.
/// [thread] ist `null`, solange ein angefordertes Gespräch noch nicht erschienen ist (nur der Pfeil).
class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({required this.thread, required this.onBack});
  final ChatThread? thread;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final thread = this.thread;
    final peer = thread?.peerId;
    return Row(children: <Widget>[
      IconButton(
        tooltip: l.chatBackToList,
        icon: const Icon(Icons.arrow_back),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onBack,
      ),
      if (thread != null)
        Expanded(
          child: Row(children: <Widget>[
            if (peer != null) ...<Widget>[
              MemberAvatarView(userId: peer, size: 28, colorIndex: personColorOf(AppScope.maybeOf(context), peer)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  thread.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            if (peer != null) ...<Widget>[
              const SizedBox(width: 12),
              Flexible(child: PresenceStatusText(userId: peer, compact: true)),
            ],
            const SizedBox(width: 12),
          ]),
        )
      else
        const Spacer(),
    ]);
  }
}
