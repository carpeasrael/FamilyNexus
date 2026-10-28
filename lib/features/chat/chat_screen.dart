import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../core/platform_info.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/file_access.dart';
import '../../domain/chat.dart';
import '../../domain/moderation.dart';
import '../../domain/presence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../calendar/event_detail_screen.dart' show RsvpButtons;
import '../calendar/formatting.dart';
import '../common/error_text.dart';
import '../moderation/moderation_actions.dart';
import '../presence/presence_view.dart';
import 'sender_name.dart';

const List<String> _quickReactions = <String>['👍', '❤️', '😂', '🎉', '😮', '🙏'];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.active = true});

  /// Der Chat ist gerade sichtbar: Nachrichten gelten dann als gelesen.
  final bool active;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ChatMessage? _replyTo;
  bool _sending = false;
  String _threadId = ChatThread.familyId;
  late final AppServices _services;

  /// Angefordertes Gespräch, das noch nicht in der Liste steht (z. B. gerade eröffneter
  /// Einzelchat). Bis es erscheint, wird gewartet statt auf den Familienchat zurückzufallen,
  /// sonst ginge eine private Nachricht an alle (#31).
  String? _waitingFor;
  Timer? _waitTimer;

  /// So lange wird höchstens auf ein angefordertes Gespräch gewartet.
  static const Duration openTimeout = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _services.chatRequest.addListener(_openRequested);
    // Die Anforderung kann gestellt worden sein, bevor dieser Bildschirm entstand.
    final pending = _services.chatRequest.value;
    if (pending != null) {
      _services.chatRequest.value = null;
      _select(pending);
    }
    _scroll.addListener(() {
      // Liste ist umgekehrt: Ende = älteste geladene Nachricht.
      if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
        AppScope.of(context).gateway.loadOlderMessages(threadId: _threadId).ignore();
      }
    });
  }

  /// Öffnet das angeforderte Gespräch (z. B. aus der Mitgliederliste).
  void _openRequested() {
    final id = _services.chatRequest.value;
    if (id == null) return;
    _services.chatRequest.value = null;
    if (mounted && id != _threadId) setState(() => _select(id));
  }

  void _select(String id) {
    _threadId = id;
    _replyTo = null;
    _waitTimer?.cancel();
    _waitingFor = null;
    if (id == ChatThread.familyId) return;
    _waitingFor = id;
    _waitTimer = Timer(openTimeout, () {
      if (!mounted || _waitingFor != id) return;
      setState(() {
        _waitingFor = null;
        _threadId = ChatThread.familyId;
      });
      _toast(AppLocalizations.of(context).chatOpenFailed);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _services.chatRequest.removeListener(_openRequested);
    _scroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _send(MatrixGateway g) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    final l = AppLocalizations.of(context);
    setState(() => _sending = true);
    try {
      await g.sendMessage(text, replyToId: _replyTo?.id, threadId: _threadId);
      _ctrl.clear();
      setState(() => _replyTo = null);
    } catch (e) {
      _toast(errorText(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach(AppServices s) async {
    final l = AppLocalizations.of(context);
    try {
      final file = await s.files.pickFile();
      if (file == null) return;
      await s.gateway.sendAttachment(fileName: file.name, bytes: file.bytes, replyToId: _replyTo?.id, threadId: _threadId);
      if (mounted) setState(() => _replyTo = null);
    } on FileTooLargeException {
      _toast(l.errAttachmentRejected);
    } catch (e) {
      _toast(errorText(l, e));
    }
  }

  Future<void> _actions(MatrixGateway g, ChatMessage m) async {
    final l = AppLocalizations.of(context);
    final foreign = m.senderId != g.userId;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text(l.chatReply),
            onTap: () {
              Navigator.pop(c);
              setState(() => _replyTo = m);
            },
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 8, children: <Widget>[
              for (final e in _quickReactions)
                Semantics(
                  label: '${l.chatReact} $e',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      Navigator.pop(c);
                      try {
                        await g.sendReaction(m.id, e, threadId: _threadId);
                      } catch (err) {
                        _toast(errorText(l, err));
                      }
                    },
                    child: Padding(padding: const EdgeInsets.all(10), child: Text(e, style: const TextStyle(fontSize: 24))),
                  ),
                ),
            ]),
          ),
          if (foreign) ...<Widget>[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l.chatReport),
              onTap: () {
                Navigator.pop(c);
                ModerationActions.report(context, _services, message: m, threadId: _threadId).ignore();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l.chatBlockSender(m.senderLabel(l))),
              onTap: () {
                Navigator.pop(c);
                ModerationActions.block(context, _services, userId: m.senderId, name: m.senderLabel(l)).ignore();
              },
            ),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final g = services.gateway;
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[g, services.settings]),
      builder: (context, _) {
        final blocked = services.settings.settings.blockedUsers;
        final threads = visibleThreads(g.threads, blocked);
        // Verschwindet ein Gespräch (z. B. Mitglied entfernt), geht es zurück zum Familienchat.
        // Ein angefordertes Gespräch, das noch nicht erschienen ist, wird dagegen abgewartet.
        final current = threads.where((t) => t.id == _threadId).firstOrNull;
        final waiting = current == null && _waitingFor == _threadId;
        if (current != null && _waitingFor == current.id) {
          _waitingFor = null;
          _waitTimer?.cancel();
        }
        if (current == null && !waiting && _threadId != ChatThread.familyId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _threadId = ChatThread.familyId);
          });
        }
        if (waiting) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l.chatOpening, textAlign: TextAlign.center),
              ]),
            ),
          );
        }
        final threadId = current?.id ?? ChatThread.familyId;
        final msgs = visibleMessages(g.messagesIn(threadId), blocked, myUserId: g.userId);
        if (widget.active && g.unreadIn(threadId) > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => g.markChatRead(threadId: threadId).ignore());
        }
        final byId = <String, ChatMessage>{for (final m in msgs) m.id: m};
        return Column(children: <Widget>[
          if (threads.length > 1)
            _ThreadBar(
              threads: threads,
              selected: threadId,
              onSelect: (id) => setState(() => _select(id)),
            ),
          Padding(
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
              if (current != null && !current.isFamily && current.peerId != null) ...<Widget>[
                const SizedBox(width: 12),
                Flexible(child: PresenceStatusText(userId: current.peerId!, compact: true)),
              ],
            ]),
          ),
          Expanded(
            child: msgs.isEmpty
                ? Center(child: Text(l.emptyChat))
                : ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) {
                      final m = msgs[msgs.length - 1 - i];
                      if (m.beforeJoin) return const _BeforeJoinNote();
                      return _Bubble(
                        message: m,
                        mine: m.senderId == g.userId,
                        replied: m.replyToId == null ? null : byId[m.replyToId],
                        gateway: g,
                        services: services,
                        threadId: threadId,
                        onLongPress: () => _actions(g, m),
                      );
                    },
                  ),
          ),
          if (_replyTo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: <Widget>[
                  Expanded(child: Text(l.chatReplyingTo(_replyTo!.senderLabel(l)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(
                    tooltip: l.chatCancelReply,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _replyTo = null),
                  ),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            // Anhängen und Senden gehören zum Eingabefeld: die Tastatur bleibt dabei offen.
            child: TextFieldTapRegion(child: Row(children: <Widget>[
              IconButton(tooltip: l.chatAttach, icon: const Icon(Icons.attach_file), onPressed: () => _attach(services)),
              Expanded(
                // Desktop: Enter sendet, Umschalt+Enter macht einen Zeilenumbruch (#37).
                child: CallbackShortcuts(
                  bindings: <ShortcutActivator, VoidCallback>{
                    if (PlatformInfo.enterSubmits) const SingleActivator(LogicalKeyboardKey.enter): () => _send(g),
                    if (PlatformInfo.enterSubmits) const SingleActivator(LogicalKeyboardKey.numpadEnter): () => _send(g),
                  },
                  child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 8000,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  enableIMEPersonalizedLearning: false,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(hintText: l.chatHint),
                  onSubmitted: (_) => _send(g),
                ),
                ),
              ),
              IconButton.filled(
                tooltip: l.chatSend,
                icon: const Icon(Icons.send),
                onPressed: _sending ? null : () => _send(g),
              ),
            ])),
          ),
        ]);
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.replied,
    required this.gateway,
    required this.services,
    required this.threadId,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final ChatMessage? replied;
  final MatrixGateway gateway;
  final AppServices services;
  final String threadId;
  final VoidCallback onLongPress;

  static String _time(DateTime t) {
    final lt = t.toLocal();
    return '${lt.hour.toString().padLeft(2, '0')}:${lt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = AuroraTokens.of(context);
    final m = message;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Semantics(
            container: true,
            label: l.chatMessageFrom(mine ? l.chatYou : m.senderLabel(l)),
            child: GestureDetector(
              onLongPress: onLongPress,
              child: GlassCard(
                glow: mine ? t.primary : null,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  if (!mine)
                    Text(m.senderLabel(l), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.primary)),
                  if (replied != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(border: Border(left: BorderSide(color: t.magenta, width: 2))),
                      child: Text(
                        replied!.body.isEmpty ? (replied!.attachment?.name ?? '') : replied!.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
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
                    Text(_time(m.time), style: monoStyle(context, size: 11, color: t.textSecondary)),
                    if (m.status == MessageStatus.sending) ...<Widget>[
                      const SizedBox(width: 6),
                      Icon(Icons.schedule, size: 12, semanticLabel: l.chatSending),
                    ],
                  ]),
                  if (m.status == MessageStatus.failed)
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
                    Text(t.title),
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
