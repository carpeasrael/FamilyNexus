part of '../chat_screen.dart';

/// Statussymbol hinter dem Zeitstempel einer eigenen Nachricht (#526, E-106): Sendet, Gesendet, Gelesen.
///
/// Im Einzelchat steht nur das Symbol (mit Beschriftung für Screenreader), im Familienchat bei „Gelesen“ zusätzlich
/// „Gelesen von n“ als Text; Tippen öffnet die Namen. Blockierte Nutzer zählen nicht (wie ihre Nachrichten).
class _DeliveryStatus extends StatelessWidget {
  const _DeliveryStatus({required this.message, required this.myUserId, required this.isFamily, required this.services});

  final ChatMessage message;
  final String? myUserId;
  final bool isFamily;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final blocked = services.settings.settings.blockedUsers.toSet();
    final line = deliveryLine(message, myUserId: myUserId, blocked: blocked);
    if (line == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    switch (line.stage) {
      case DeliveryStage.sending:
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(Icons.schedule, size: 12, semanticLabel: l.chatSending),
        );
      case DeliveryStage.sent:
        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Icon(Icons.done, size: 14, color: t.textSecondary, semanticLabel: l.chatStatusSent),
        );
      case DeliveryStage.read:
        final label = isFamily ? l.chatStatusReadBy(line.readCount) : l.chatStatusRead;
        final icon = Icon(Icons.done_all, size: 14, color: t.primary, semanticLabel: label);
        if (!isFamily) return Padding(padding: const EdgeInsets.only(left: 6), child: icon);
        return Flexible(
          child: InkWell(
            onTap: () => _showReaders(context, readersOf(message, blocked)),
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                icon,
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, size: 11, color: t.primary),
                  ),
                ),
              ]),
            ),
          ),
        );
    }
  }

  /// Blatt „Gelesen von“ mit den Namen aus der Familie; Unbekannte erscheinen als „Ehemaliges Mitglied“, nie als ID.
  Future<void> _showReaders(BuildContext context, Set<String> readers) {
    final l = AppLocalizations.of(context);
    final family = services.gateway.family;
    final names = <String>[
      for (final id in readers) memberLabel(l, family, id, me: myUserId ?? ''),
    ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.chatReadByTitle, style: Theme.of(c).textTheme.titleMedium),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: <Widget>[
              for (final n in names) ListTile(leading: const Icon(Icons.done_all), title: Text(n)),
            ]),
          ),
        ]),
      ),
    );
  }
}
