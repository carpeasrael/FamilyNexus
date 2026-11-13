import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/app_services.dart';
import '../../core/platform_info.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../data/platform/file_access.dart';
import '../../domain/chat.dart';
import '../../domain/moderation.dart';
import '../../domain/presence.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../../ui/widgets/length_limit.dart';
import '../calendar/event_detail_screen.dart' show RsvpButtons;
import '../calendar/formatting.dart';
import '../common/error_text.dart';
import '../moderation/moderation_actions.dart';
import '../presence/presence_view.dart';
import 'chat_layout.dart';
import 'chat_view_model.dart';
import 'sender_name.dart';
import 'thread_preview.dart';

part 'widgets/attachment_view.dart';
part 'widgets/chat_parts.dart';
part 'widgets/message_bubble.dart';
part 'widgets/thread_and_lines.dart';
part 'widgets/thread_list.dart';

const List<String> _quickReactions = <String>['👍', '❤️', '😂', '🎉', '😮', '🙏'];

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.active = true});

  /// Der Chat ist gerade sichtbar: Nachrichten gelten dann als gelesen.
  final bool active;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  ChatMessage? _replyTo;
  bool _sending = false;

  /// Vom Nutzer gewähltes Gespräch (#423): `null` = keines geöffnet, dann zeigt der Tab die Gesprächsliste (bei
  /// mehreren Gesprächen). Nur der **Wunsch**: Was gezeigt wird, entscheidet [resolveChatView] in `build`.
  String? _open;

  /// Gezeigte Gesprächs-ID, in jedem Aufbau aus der Ansicht abgeleitet (`null` bei Liste und Warten). Verlauf,
  /// Nachladen, Lesen und Senden nutzen sie, nie [_open]; die Behandler lesen sie **vor jedem `await`**.
  String? _shown;

  /// Eigener Controller der Liste; [_scroll] gehört nur dem Verlauf.
  final ScrollController _listScroll = ScrollController();
  late final AppServices _services;

  /// Angefordertes Gespräch, das noch nicht in der Liste steht (z. B. gerade eröffneter
  /// Einzelchat). Bis es erscheint, wird gewartet statt auf den Familienchat zurückzufallen,
  /// sonst ginge eine private Nachricht an alle (#31).
  String? _waitingFor;
  Timer? _waitTimer;

  /// So lange wird höchstens auf ein angefordertes Gespräch gewartet.
  static const Duration openTimeout = Duration(seconds: 20);

  /// Marke „Neue Nachrichten“ (#254): Gespräch, für das sie beim Öffnen bestimmt wurde, und ihre Nachricht.
  /// Bestimmt wird einmal je Öffnen, vor dem Gelesen-Markieren; neue Nachrichten bei offenem Gespräch setzen
  /// keine neue Marke. Gesprächswechsel, Verlassen des Tabs und Hintergrund geben sie frei.
  String? _markerThread;
  String? _unreadFrom;
  bool _scrolledToMarker = false;
  final GlobalKey _markerKey = GlobalKey(debugLabel: 'unread-marker');

  /// Klappt aufgeklappte Zitate zu (Tab verlassen, Hintergrund; #254).
  final ValueNotifier<int> _collapseQuotes = ValueNotifier<int>(0);

  /// Vordergrund (`resumed`, `inactive`): Nur dann gilt das Gespräch als gelesen und als sichtbar (#254, E-88).
  bool _foreground = true;

  static bool _isForeground(AppLifecycleState? s) =>
      s == null || s == AppLifecycleState.resumed || s == AppLifecycleState.inactive;

  void _resetMarker() {
    _markerThread = null;
    _unreadFrom = null;
    _scrolledToMarker = false;
  }

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _services.chatRequest.addListener(_openRequested);
    WidgetsBinding.instance.addObserver(this);
    _foreground = _isForeground(WidgetsBinding.instance.lifecycleState);
    // Die Anforderung kann gestellt worden sein, bevor dieser Bildschirm entstand.
    final pending = _services.chatRequest.value;
    if (pending != null) {
      _services.chatRequest.value = null;
      _select(pending);
    }
    _scroll.addListener(() {
      // Liste ist umgekehrt: Ende = älteste geladene Nachricht.
      if (_scroll.hasClients && _scroll.position.extentAfter < 200) {
        final id = _shown;
        if (id != null) AppScope.of(context).gateway.loadOlderMessages(threadId: id).ignore();
      }
    });
  }

  /// Öffnet das angeforderte Gespräch (z. B. aus der Mitgliederliste).
  void _openRequested() {
    final id = _services.chatRequest.value;
    if (id == null) return;
    _services.chatRequest.value = null;
    // Immer öffnen, auch bei schon gewähltem Gespräch oder offener Liste (#423).
    if (mounted) setState(() => _select(id));
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _resetMarker();
      _collapseQuotes.value++;
      _services.visibleChatThread = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = _isForeground(state);
    if (foreground != _foreground && mounted) setState(() => _foreground = foreground);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // Rückkehr gilt wie Öffnen: Was im Hintergrund kam, bekommt eine neue Marke.
      _resetMarker();
      _collapseQuotes.value++;
    }
  }

  void _select(String id) {
    _open = id;
    _replyTo = null;
    _resetMarker();
    _waitTimer?.cancel();
    _waitingFor = null;
    if (id == ChatThread.familyId) return;
    _waitingFor = id;
    _waitTimer = Timer(openTimeout, () {
      if (!mounted || _waitingFor != id) return;
      setState(() {
        _waitingFor = null;
        _open = ChatThread.familyId;
      });
      _toast(AppLocalizations.of(context).chatOpenFailed);
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    _services.chatRequest.removeListener(_openRequested);
    WidgetsBinding.instance.removeObserver(this);
    _services.visibleChatThread = null;
    _collapseQuotes.dispose();
    _scroll.dispose();
    _listScroll.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Zurück zur Gesprächsliste (#423). Ein offener Endrawer schließt zuerst und nur er: `PopScope(canPop: false)`
  /// lässt auch dann nichts zu, wenn der Drawer offen ist.
  void _backToList() {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isEndDrawerOpen) {
      scaffold.closeEndDrawer();
      return;
    }
    setState(() {
      _open = null;
      _replyTo = null;
      _waitTimer?.cancel();
      _waitingFor = null;
      _resetMarker();
    });
    _services.visibleChatThread = null;
  }

  Future<void> _send(MatrixGateway g) async {
    final text = _ctrl.text.trim();
    final threadId = _shown;
    if (text.isEmpty || _sending || threadId == null) return;
    final l = AppLocalizations.of(context);
    // Stand beim Absenden (#410): `_ctrl` gehört allen Gesprächen und bleibt während des Sendens beschreibbar.
    final sentText = _ctrl.text;
    final sentReply = _replyTo;
    setState(() => _sending = true);
    try {
      await g.sendMessage(text, replyToId: sentReply?.id, threadId: threadId);
      if (!mounted) return;
      // Nur der unveränderte, schon gesendete Stand wird geleert; Neues (weitergetippt, nach einem Wechsel) bleibt.
      if (_ctrl.text == sentText) _ctrl.clear();
      if (identical(_replyTo, sentReply)) setState(() => _replyTo = null);
    } catch (e) {
      _toast(errorText(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _attach(AppServices s) async {
    final l = AppLocalizations.of(context);
    // Gespräch vor der Dateiauswahl festhalten: ein Wechsel währenddessen darf das Ziel nicht ändern (#423).
    final threadId = _shown;
    if (threadId == null) return;
    try {
      final file = await s.files.pickFile();
      if (file == null) return;
      await s.gateway.sendAttachment(fileName: file.name, bytes: file.bytes, replyToId: _replyTo?.id, threadId: threadId);
      if (mounted) setState(() => _replyTo = null);
    } on FileTooLargeException {
      _toast(l.errAttachmentRejected);
    } catch (e) {
      _toast(errorText(l, e));
    }
  }

  Future<void> _actions(MatrixGateway g, ChatMessage m) async {
    final l = AppLocalizations.of(context);
    final threadId = _shown;
    if (threadId == null) return;
    final foreign = m.senderId != g.userId;
    await showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          // Nicht Entschlüsseltes ist kein Antwortziel, das Gateway wiese es ab.
          if (!m.undecryptable)
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(l.chatReply),
              onTap: () {
                Navigator.pop(c);
                setState(() => _replyTo = m);
              },
            ),
          // Ungesendetes ist kein Reaktionsziel, das Gateway wiese es ab (E-86, #224).
          if (m.status == MessageStatus.sent)
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
                          await g.sendReaction(m.id, e, threadId: threadId);
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
                ModerationActions.report(context, _services, message: m, threadId: threadId).ignore();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text(l.chatBlockSender(m.senderLabel(l, inSentence: true))),
              onTap: () {
                Navigator.pop(c);
                ModerationActions.block(context, _services, userId: m.senderId, name: m.senderLabel(l, inSentence: true)).ignore();
              },
            ),
          ],
        ]),
      ),
    );
  }

  /// Das geöffnete Gespräch ist verschwunden (z. B. Mitglied entfernt, blockiert): zurück zum Familienchat, nicht
  /// zur Liste. Der Frame davor zeigt ihn schon (Rang 2 in [resolveChatView]); `_open` wird danach nachgezogen.
  void _followFamily(String vanished) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _open == vanished) setState(() => _open = ChatThread.familyId);
    });
  }

  /// Marke „Neue Nachrichten“, Sichtbarkeit und Gelesen-Markierung des Gesprächs [threadId] (#254, #294, E-88).
  void _trackVisibility(AppServices services, MatrixGateway g, String threadId, int unread) {
    // Gesperrt gilt nichts als gesehen (E-88, #294): Marke zurücksetzen, beim Entsperren entsteht sie neu (E-42).
    final locked = services.lock.locked;
    if (locked) _resetMarker();
    if (widget.active && !locked && _markerThread != threadId) {
      // Vor dem Gelesen-Markieren: danach gäbe es keine ungelesene Nachricht mehr.
      _markerThread = threadId;
      _unreadFrom = unread > 0 ? g.firstUnreadIdIn(threadId) : null;
      _scrolledToMarker = false;
    }
    // Sichtbar heißt wie bei den Meldungen: Chat-Tab, dieses Gespräch, Vordergrund (#254). Im Hintergrund wird
    // nichts gelesen markiert; die Rückkehr baut neu und markiert dann.
    if (widget.active) services.visibleChatThread = threadId;
    if (widget.active && _foreground && !locked && unread > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!services.lock.locked) g.markChatRead(threadId: threadId).ignore();
      });
    }
  }

  /// Springt einmal zur Marke, sobald sie gebaut ist.
  void _scrollToMarkerOnce(List<ChatEntry> entries) {
    if (_scrolledToMarker || !entries.any((e) => e is UnreadMarkerEntry)) return;
    _scrolledToMarker = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Nur wenn die Marke gebaut ist (Sichtbereich + Vorlauf); weiter oben liegende Marken bleiben, wo sie sind.
      final ctx = _markerKey.currentContext;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.5).ignore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final g = services.gateway;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[g, services.settings, services.lock]),
      builder: (context, _) {
        final threads = visibleThreads(g.threads, services.settings.settings.blockedUsers);
        final view = resolveChatView(
          threads: threads,
          open: _open,
          waitingFor: _waitingFor,
          active: widget.active,
          initialSyncDone: g.initialSyncDone,
        );
        _shown = view.shownId;
        if (view.followFamily) _followFamily(_open!);
        if (view.pin) _open = ChatThread.familyId;
        if (view.endWaiting) {
          _waitingFor = null;
          _waitTimer?.cancel();
        }
        // Zurück-Taste nur im offenen Gespräch des aktiven Tabs bei mehreren Gesprächen; sonst unverändert, auch
        // bei App-Sperre (die Sperre liegt über der App, ihr Zurück gehört nicht dem Chat).
        final canPop = !(widget.active && threads.length > 1 && _open != null && !services.lock.locked);
        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _backToList();
          },
          child: _body(context, services, view, threads),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppServices services, ChatView view, List<ChatThread> threads) {
    final l = AppLocalizations.of(context);
    switch (view.kind) {
      case ChatViewKind.opening:
        if (widget.active) services.visibleChatThread = null;
        return Column(children: <Widget>[
          if (view.showHeader) _ThreadHeader(thread: null, onBack: _backToList),
          Expanded(child: _ChatOpening(text: l.chatOpening)),
        ]);
      case ChatViewKind.list:
        // Jeder Aufbau der Liste: Marke frei, kein Gespräch sichtbar (nichts wird gelesen markiert).
        _resetMarker();
        services.visibleChatThread = null;
        return _ThreadList(threads: threads, scroll: _listScroll, onOpen: (id) => setState(() => _select(id)));
      case ChatViewKind.conversation:
        return _conversation(context, services, view);
    }
  }

  Widget _conversation(BuildContext context, AppServices services, ChatView view) {
    final l = AppLocalizations.of(context);
    final g = services.gateway;
    final blocked = services.settings.settings.blockedUsers;
    final threadId = view.shownId!;
    final all = g.messagesIn(threadId);
    final msgs = _uniqueById(visibleMessages(all, blocked, myUserId: g.userId));
    _trackVisibility(services, g, threadId, g.unreadIn(threadId));
    final entries = chatEntries(msgs, unreadFromId: _unreadFrom, allIds: <String>[for (final m in all) m.id]);
    _scrollToMarkerOnce(entries);
    return Column(children: <Widget>[
      if (view.showHeader) _ThreadHeader(thread: view.current, onBack: _backToList),
      _EncryptionNote(current: view.current),
      Expanded(
        child: msgs.isEmpty
            ? Center(child: Text(l.emptyChat))
            : _MessageList(
                entries: entries,
                byId: <String, ChatMessage>{for (final m in msgs) m.id: m},
                scroll: _scroll,
                markerKey: _markerKey,
                collapseQuotes: _collapseQuotes,
                gateway: g,
                services: services,
                threadId: threadId,
                onLongPress: (m) => _actions(g, m),
              ),
      ),
      if (_replyTo != null) _ReplyPreview(message: _replyTo!, onCancel: () => setState(() => _replyTo = null)),
      _Composer(controller: _ctrl, sending: _sending, onAttach: () => _attach(services), onSend: () => _send(g)),
    ]);
  }
}

/// Entfernt doppelte IDs, das erste Vorkommen bleibt: Die SDK-Zeitleiste kann an einer Seitengrenze ein Ereignis
/// doppelt liefern, und gleiche Keys sind in der Liste nicht zulässig (#130).
List<ChatMessage> _uniqueById(List<ChatMessage> messages) {
  final seen = <String>{};
  return <ChatMessage>[
    for (final m in messages)
      if (seen.add(m.id)) m,
  ];
}
