part of '../chat_screen.dart';

/// Text eines Zitats: Nachricht oder Name des Anhangs.
String _quoteText(ChatMessage m) => m.body.isEmpty ? (m.attachment?.name ?? '') : m.body;

/// Datum und Uhrzeit in Ortszeit, ausgeschrieben (Tooltip, Screenreader; #254).
String _fullDateTime(BuildContext context, DateTime t) {
  final lt = t.toLocal();
  final locale = Localizations.localeOf(context).toLanguageTag();
  return '${DateFormat.yMMMMEEEEd(locale).format(lt)}, ${formatClock(context, lt.hour, lt.minute)}';
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.replied,
    required this.myUserId,
    required this.maxWidth,
    required this.collapseQuotes,
    required this.gateway,
    required this.services,
    required this.threadId,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final ChatMessage? replied;
  final String? myUserId;
  /// Höchste Breite der Blase (Spaltenbreite, nicht Fensterbreite).
  final double maxWidth;
  final Listenable collapseQuotes;
  final MatrixGateway gateway;
  final AppServices services;
  final String threadId;
  final VoidCallback onLongPress;

  static String _time(BuildContext context, DateTime t) {
    final lt = t.toLocal();
    return formatClock(context, lt.hour, lt.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final m = message;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Semantics(
            container: true,
            // Eigene Nachricht: „von dir“ (Dativ), nicht „von Du“ (#332).
            label: mine ? l.chatMessageFromYou : l.chatMessageFrom(m.senderLabel(l, inSentence: true)),
            child: GestureDetector(
              onLongPress: onLongPress,
              child: GlassCard(
                glow: mine ? t.primary : null,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  if (!mine)
                    Text(m.senderLabel(l), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.primary)),
                  if (m.replyToId != null) _Quote(replied: replied, myUserId: myUserId, collapse: collapseQuotes),
                  if (m.blockedAttachment)
                    Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      const Icon(Icons.block, size: 16),
                      const SizedBox(width: 6),
                      Flexible(child: Text(l.chatAttachmentBlocked)),
                    ]),
                  if (m.attachment != null) _AttachmentView(message: m, services: services, threadId: threadId),
                  if (m.sharedEventId != null) _EventCard(eventId: m.sharedEventId!, services: services),
                  if (m.undecryptable)
                    Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      const Icon(Icons.lock_clock_outlined, size: 16),
                      const SizedBox(width: 6),
                      Flexible(child: Text(l.chatUndecryptable)),
                    ]),
                  if (m.body.isNotEmpty && m.sharedEventId == null) Text(m.body),
                  if (m.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, children: <Widget>[
                        for (final e in m.reactions.entries)
                          StatusBadge(label: '${e.key} ${e.value.length}', color: t.violet),
                      ]),
                    ),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                    Tooltip(
                      message: _fullDateTime(context, m.time),
                      excludeFromSemantics: true,
                      child: Text(
                        _time(context, m.time),
                        semanticsLabel: _fullDateTime(context, m.time),
                        style: monoStyle(context, size: 11, color: t.textSecondary),
                      ),
                    ),
                    if (m.status == MessageStatus.sending) ...<Widget>[
                      const SizedBox(width: 6),
                      Icon(Icons.schedule, size: 12, semanticLabel: l.chatSending),
                    ],
                  ]),
                  if (m.status == MessageStatus.failed && !m.retryable)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                        Icon(Icons.error_outline, size: 16, color: t.danger),
                        const SizedBox(width: 4),
                        Flexible(child: Text(l.chatNotSent, style: TextStyle(color: t.danger))),
                      ]),
                    ),
                  if (m.status == MessageStatus.failed && m.retryable)
                    InkWell(
                      onTap: () => gateway.retryMessage(m.id, threadId: threadId).catchError((Object e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                          Icon(Icons.error_outline, size: 16, color: t.danger),
                          const SizedBox(width: 4),
                          Flexible(child: Text(l.chatRetry, style: TextStyle(color: t.danger))),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ein Hinweis statt vieler „nicht entschlüsselbar“-Einträge aus der Zeit vor dem Beitritt (#35).
class _BeforeJoinNote extends StatelessWidget {
  const _BeforeJoinNote();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        const Icon(Icons.lock_clock_outlined, size: 16),
        const SizedBox(width: 6),
        Flexible(child: Text(l.chatBeforeJoin, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall)),
      ]),
    );
  }
}

/// Anhänge werden nie automatisch geladen oder geöffnet.
class _AttachmentView extends StatefulWidget {
  const _AttachmentView({required this.message, required this.services, required this.threadId});
  final ChatMessage message;
  final AppServices services;
  final String threadId;

  @override
  State<_AttachmentView> createState() => _AttachmentViewState();
}

class _AttachmentViewState extends State<_AttachmentView> {
  Uint8List? _bytes;
  bool _loading = false;

  Future<Uint8List?> _load() async {
    if (_bytes != null) return _bytes;
    final l = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final b = await widget.services.gateway.loadAttachment(widget.message.id, threadId: widget.threadId);
      if (mounted) setState(() => _bytes = b);
      return b;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
      return null;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.attachmentSaveWarning),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.save)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final b = await _load();
    if (b == null) return;
    final a = widget.message.attachment!;
    try {
      await widget.services.files.saveFile(name: a.name, bytes: b, mimeType: a.mimeType);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final a = widget.message.attachment!;
    if (a.isImage && _bytes != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              _bytes!,
              height: 200,
              cacheHeight: 400, // begrenzt den Speicher (Bild-Bomben)
              fit: BoxFit.cover,
              semanticLabel: a.name,
              errorBuilder: (_, _, _) => const Icon(Icons.broken_image),
            ),
          ),
          // Bilder lassen sich wie andere Anhänge speichern (#40).
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.download_outlined), label: Text(l.chatSaveAttachment)),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Icon(a.isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined),
        const SizedBox(width: 6),
        Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 6),
        if (_loading)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
        else if (a.isImage) ...<Widget>[
          TextButton(onPressed: _load, child: Text(l.chatLoadAttachment)),
          TextButton(onPressed: _save, child: Text(l.chatSaveAttachment)),
        ] else
          TextButton(onPressed: _save, child: Text(l.chatSaveAttachment)),
      ]),
    );
  }
}

/// Termin als Karte im Verlauf, mit direkter Zu-/Absage.
class _EventCard extends StatelessWidget {
  const _EventCard({required this.eventId, required this.services});
  final String eventId;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = services.calendar;
    if (c == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final e = c.eventById(eventId);
        if (e == null || e.deleted || !e.isShared) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l.chatEventMissing));
        }
        final fmt = Fmt(context, c.zone);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Row(children: <Widget>[
              const Icon(Icons.event_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(e.title, style: Theme.of(context).textTheme.titleSmall)),
            ]),
            Text(fmt.eventSpan(e, l), style: monoStyle(context, size: 12)),
            const SizedBox(height: 6),
            RsvpButtons(controller: c, eventId: e.id),
          ]),
        );
      },
    );
  }
}

/// Zitat einer Antwort (#254): Absender und Text, ab 4 Zeilen eingeklappt. Tippen klappt auf und zu, ohne dem
/// Eingabefeld den Fokus zu nehmen; jedes Tippen außerhalb (auch ins Eingabefeld oder zum Scrollen), Fokusverlust,
/// Verlassen des Tabs und Hintergrund klappen zu. Der Zustand wird nicht gespeichert.
///
/// Ist das Ziel nicht sichtbar (nicht geladen, blockiert, gelöscht, nicht verschlüsselt angekommen), erscheint ein
/// neutraler Hinweis. Den Zitattext aus der Antwort selbst zeigen wir nie: Den setzt der Absender frei (E-30, #138).
class _Quote extends StatefulWidget {
  const _Quote({required this.replied, required this.myUserId, required this.collapse});
  final ChatMessage? replied;
  final String? myUserId;
  final Listenable collapse;

  /// Ab so vielen Zeilen wird eingeklappt.
  static const int maxLines = 4;

  @override
  State<_Quote> createState() => _QuoteState();
}

class _QuoteState extends State<_Quote> {
  bool _expanded = false;
  final FocusNode _focus = FocusNode(debugLabel: 'quote');

  @override
  void initState() {
    super.initState();
    widget.collapse.addListener(_collapseNow);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_Quote oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.collapse, widget.collapse)) {
      oldWidget.collapse.removeListener(_collapseNow);
      widget.collapse.addListener(_collapseNow);
    }
  }

  @override
  void dispose() {
    widget.collapse.removeListener(_collapseNow);
    _focus.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (!_focus.hasFocus) _collapseNow();
  }

  void _collapseNow() {
    if (mounted && _expanded) setState(() => _expanded = false);
  }

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final style = Theme.of(context).textTheme.bodySmall;
    final decoration = BoxDecoration(border: Border(left: BorderSide(color: t.magenta, width: 2)));
    const margin = EdgeInsets.only(bottom: 4);
    const padding = EdgeInsets.only(left: 8);
    final r = widget.replied;
    if (r == null) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: decoration,
        child: Text(l.chatReplyUnavailable, style: style?.copyWith(fontStyle: FontStyle.italic)),
      );
    }
    final text = _quoteText(r);
    final sender = r.senderId == widget.myUserId ? l.chatYou : r.senderLabel(l);
    return LayoutBuilder(builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        maxLines: _Quote.maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.localeOf(context),
      )..layout(maxWidth: (constraints.maxWidth - padding.horizontal - 2).clamp(0, double.infinity));
      final long = painter.didExceedMaxLines;
      painter.dispose();
      final collapsed = long && !_expanded;
      final box = Container(
        margin: margin,
        padding: padding,
        decoration: decoration,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(sender, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            text,
            maxLines: collapsed ? _Quote.maxLines : null,
            overflow: collapsed ? TextOverflow.ellipsis : null,
            style: style,
          ),
          if (long)
            Text(
              _expanded ? l.chatQuoteLess : l.chatQuoteMore,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.primary, fontWeight: FontWeight.w600),
            ),
        ]),
      );
      if (!long) return box;
      return TapRegion(
        onTapOutside: (_) => _collapseNow(),
        // Gehört zum Eingabefeld: Tippen aufs Zitat nimmt ihm den Fokus nicht (auch nicht mit der Maus).
        child: TextFieldTapRegion(
          child: Focus(
            focusNode: _focus,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
                _toggle();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Semantics(
              button: true,
              expanded: _expanded,
              onTap: _toggle,
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _toggle, child: box),
            ),
          ),
        ),
      );
    });
  }
}
