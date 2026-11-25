part of '../chat_screen.dart';

/// Umschalter „Familie | Kontakte“ mit Abzeichen (#119, K3b-2a). Zahl und Text stehen im Label, nie nur Farbe.
class _ScopeSwitcher extends StatelessWidget {
  const _ScopeSwitcher({required this.scope, required this.familyUnread, required this.contactUnread, required this.onChanged});

  final ChatScope scope;
  final int familyUnread;
  final int contactUnread;
  final void Function(ChatScope scope) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget segment(String name, int unread) => Semantics(
          label: l.chatScopeLabel(name, unread),
          excludeSemantics: true,
          child: Text(unread > 0 ? '$name ($unread)' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: SegmentedButton<ChatScope>(
          showSelectedIcon: false,
          segments: <ButtonSegment<ChatScope>>[
            ButtonSegment<ChatScope>(value: ChatScope.family, label: segment(l.chatScopeFamily, familyUnread)),
            ButtonSegment<ChatScope>(value: ChatScope.contacts, label: segment(l.chatScopeContacts, contactUnread)),
          ],
          selected: <ChatScope>{scope},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

/// Dauerhafter Hinweis „Außerhalb der Familie“ (§8.6): Symbol, Rand **und** Text, auch bei knapper Höhe; trägt den Namen
/// und das Menü (Blockieren, Kontakte verwalten).
class _OutsideBanner extends StatelessWidget {
  const _OutsideBanner({required this.name, required this.userId, required this.collides, required this.onBlock, required this.onManage});

  final String name;
  final String userId;
  final bool collides;
  final VoidCallback onBlock;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final text = l.chatOutsideBanner(isolateText(name));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: t.warning), borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(children: <Widget>[
            Icon(Icons.public, size: 18, color: t.warning),
            const SizedBox(width: 6),
            Expanded(
              child: Semantics(
                container: true,
                label: collides ? '$text ${l.contactsNotYourFamily(isolateText(userId))}' : text,
                excludeSemantics: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                  if (collides) NotYourFamilyWarning(userId: userId),
                ]),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: l.chatContactsManage,
              onSelected: (v) => v == 0 ? onBlock() : onManage(),
              itemBuilder: (_) => <PopupMenuEntry<int>>[
                PopupMenuItem<int>(value: 0, child: Text(l.contactsBlock)),
                PopupMenuItem<int>(value: 1, child: Text(l.chatContactsManage)),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// Leere Kontakte-Liste mit den Wegen „Kontakte verwalten“ (dort: Hinzufügen).
class _ContactsEmpty extends StatelessWidget {
  const _ContactsEmpty({required this.onManage});
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(l.chatContactsEmpty, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onManage, child: Text(l.chatContactsManage)),
        ]),
      ),
    );
  }
}

/// Gespräch konnte nicht geöffnet werden, mit „Erneut versuchen“.
class _ContactOpenFailed extends StatelessWidget {
  const _ContactOpenFailed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(l.chatContactOpenFailed, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l.chatContactRetry)),
        ]),
      ),
    );
  }
}
