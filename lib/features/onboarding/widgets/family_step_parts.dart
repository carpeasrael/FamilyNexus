part of '../family_step.dart';

/// Karten zu offenen Einladungen über dem Formular (bei „Andere Familie gründen oder beitreten“ und bei Anfragen).
class _InvitationCards extends StatelessWidget {
  const _InvitationCards({required this.invitations, required this.busy, required this.onDecline, required this.onAccept});
  final List<PendingInvitation> invitations;
  final bool busy;
  final void Function(PendingInvitation invitation) onDecline;
  final void Function(PendingInvitation invitation) onAccept;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Semantics(header: true, child: Text(l.invitationsTitle, style: Theme.of(context).textTheme.titleSmall)),
      for (final inv in invitations)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(inv.roomName, style: Theme.of(context).textTheme.titleMedium),
              Text(l.invitationFrom(inv.inviterLabel), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                TextButton(
                  onPressed: busy ? null : () => onDecline(inv),
                  child: Text(l.decline),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: busy ? null : () => onAccept(inv), child: Text(l.accept)),
              ]),
            ]),
          ),
        ),
      const Divider(),
    ]);
  }
}

/// Eingeladenes Konto (E-49): direkt die Einladung zeigen, ohne die Frage „Gründen oder Beitreten“.
class _InvitedView extends StatelessWidget {
  const _InvitedView({
    required this.invitations,
    required this.busy,
    required this.error,
    required this.onDecline,
    required this.onAccept,
    required this.onOther,
  });
  final List<PendingInvitation> invitations;
  final bool busy;

  /// Fehlertext der letzten Aktion; `null` ohne Fehler.
  final String? error;
  final void Function(PendingInvitation invitation) onDecline;
  final void Function(PendingInvitation invitation) onAccept;
  final VoidCallback onOther;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Semantics(header: true, child: Text(l.onbInvitedTitle, style: theme.textTheme.titleMedium)),
      const SizedBox(height: 8),
      for (final inv in invitations)
        Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(inv.roomName, style: theme.textTheme.titleMedium),
              Text(l.invitationFrom(inv.inviterLabel), style: theme.textTheme.bodySmall),
              if (!inv.requested) ...<Widget>[
                const SizedBox(height: 6),
                // Unerwartete Einladung: hier bewusst die vollständige ID, damit sich Namen nicht vortäuschen lassen.
                Text(l.invitationUnexpectedWarning(inv.inviterId), style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: <Widget>[
                TextButton(
                  onPressed: busy ? null : () => onDecline(inv),
                  child: Text(l.decline),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FilledButton(
                    onPressed: busy ? null : () => onAccept(inv),
                    child: Text(l.onbInvitedJoin(inv.roomName), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ]),
            ]),
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: busy ? null : onOther,
          child: Text(l.onbInvitedOther),
        ),
      ),
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(liveRegion: true, child: Text(error!, style: TextStyle(color: theme.colorScheme.error))),
        ),
    ]);
  }
}
