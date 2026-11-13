part of '../chat_screen.dart';

/// Anzeige, solange ein angefordertes Gespräch noch nicht in der Liste steht (#31).
class _ChatOpening extends StatelessWidget {
  const _ChatOpening({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

/// Hinweis zur Verschlüsselung. Der Status des Gegenübers steht in der Kopfzeile (`_ThreadHeader`, #423).
class _EncryptionNote extends StatelessWidget {
  const _EncryptionNote({required this.current});
  final ChatThread? current;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final current = this.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Icon(Icons.lock_outline, size: 14),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            current != null && !current.isFamily ? l.chatDirectNote(current.title) : l.chatEncryptedNote,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ]),
    );
  }
}

/// Nachrichtenliste, neueste unten (umgekehrte Liste), mit Datumszeilen und Marke „Neue Nachrichten“.
class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.entries,
    required this.byId,
    required this.scroll,
    required this.markerKey,
    required this.collapseQuotes,
    required this.gateway,
    required this.services,
    required this.threadId,
    required this.onLongPress,
  });

  final List<ChatEntry> entries;
  final Map<String, ChatMessage> byId;
  final ScrollController scroll;
  final GlobalKey markerKey;
  final Listenable collapseQuotes;
  final MatrixGateway gateway;
  final AppServices services;
  final String threadId;
  final void Function(ChatMessage message) onLongPress;

  @override
  Widget build(BuildContext context) {
    final positionByKey = <String, int>{for (var i = 0; i < entries.length; i++) entries[i].key: i};
    return LayoutBuilder(
      // Spaltenbreite einmal je Build der Liste, nicht je Blase (#274): Im Zweispalter ist der Chat schmaler als das Fenster.
      builder: (context, box) {
        final bubbleWidth = bubbleMaxWidth(box.maxWidth);
        return ListView.builder(
          controller: scroll,
          reverse: true,
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          // Der State einer Blase (geladener Anhang) bleibt an seiner Nachricht, auch wenn neue
          // Nachrichten alle Indizes verschieben (#130). Datumszeilen und Marke haben eigene Schlüssel.
          findChildIndexCallback: (key) {
            final position = positionByKey[(key as ValueKey<String>).value];
            return position == null ? null : entries.length - 1 - position;
          },
          itemBuilder: (context, i) {
            final entry = entries[entries.length - 1 - i];
            final key = ValueKey<String>(entry.key);
            switch (entry) {
              case DayEntry(:final day):
                return KeyedSubtree(key: key, child: _DayLine(day: day));
              case UnreadMarkerEntry():
                return KeyedSubtree(key: key, child: _UnreadLine(key: markerKey));
              case MessageEntry(message: final m):
                if (m.beforeJoin) return KeyedSubtree(key: key, child: const _BeforeJoinNote());
                return _Bubble(
                  key: key,
                  message: m,
                  mine: m.senderId == gateway.userId,
                  replied: m.replyToId == null ? null : byId[m.replyToId],
                  myUserId: gateway.userId,
                  maxWidth: bubbleWidth,
                  collapseQuotes: collapseQuotes,
                  gateway: gateway,
                  services: services,
                  threadId: threadId,
                  onLongPress: () => onLongPress(m),
                );
            }
          },
        );
      },
    );
  }
}

/// Vorschau der Nachricht, auf die geantwortet wird, mit „Abbrechen“.
class _ReplyPreview extends StatelessWidget {
  const _ReplyPreview({required this.message, required this.onCancel});
  final ChatMessage message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: <Widget>[
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              Text(l.chatReplyingTo(message.senderLabel(l, inSentence: true)), maxLines: 1, overflow: TextOverflow.ellipsis),
              // Vorschau des Zitats, einzeilig (#254).
              Text(
                _quoteText(message),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ]),
          ),
          IconButton(
            tooltip: l.chatCancelReply,
            icon: const Icon(Icons.close),
            onPressed: onCancel,
          ),
        ]),
      ),
    );
  }
}

/// Eingabeleiste: Anhängen, Textfeld, Senden.
class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.sending, required this.onAttach, required this.onSend});
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      // Anhängen und Senden gehören zum Eingabefeld: die Tastatur bleibt dabei offen.
      child: TextFieldTapRegion(child: Row(children: <Widget>[
        IconButton(tooltip: l.chatAttach, icon: const Icon(Icons.attach_file), onPressed: onAttach),
        Expanded(
          // Desktop: Enter sendet, Umschalt+Enter macht einen Zeilenumbruch (#37).
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              if (PlatformInfo.enterSubmits) const SingleActivator(LogicalKeyboardKey.enter): onSend,
              if (PlatformInfo.enterSubmits) const SingleActivator(LogicalKeyboardKey.numpadEnter): onSend,
            },
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              // Zählt wie die Prüfung im Gateway in UTF-16-Einheiten, nicht nach Graphemen (#236, E-40).
              inputFormatters: <TextInputFormatter>[MeasuredLengthFormatter(ChatMessage.maxBody, LengthMeasure.utf16)],
              maxLength: ChatMessage.maxBody,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              enableIMEPersonalizedLearning: false,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: l.chatHint),
              onSubmitted: (_) => onSend(),
            ),
          ),
        ),
        IconButton.filled(
          tooltip: l.chatSend,
          icon: const Icon(Icons.send),
          onPressed: sending ? null : onSend,
        ),
      ])),
    );
  }
}
