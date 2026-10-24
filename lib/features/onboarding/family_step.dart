import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/family.dart';
import '../../domain/invite_link.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../common/error_text.dart';
import '../common/invite_link_text.dart';
import '../family/invite_dialog.dart';

/// Was der Familienschritt zuerst zeigt: gründen (Weg „Neue Familie“), beitreten (Weg „Eingeladen“)
/// oder beides zur Auswahl (bestehendes Konto ohne Familie).
enum FamilyStepMode { create, join, choice }

/// Schritt „Familie“: gründen, per Einladungslink beitreten oder Einladungen annehmen.
class FamilyStep extends StatefulWidget {
  const FamilyStep({super.key, required this.onFamilyReady, this.mode = FamilyStepMode.choice});

  /// Wird aufgerufen, sobald eine Familie besteht (gegründet oder beigetreten).
  final Future<void> Function() onFamilyReady;
  final FamilyStepMode mode;

  @override
  State<FamilyStep> createState() => _FamilyStepState();
}

class _FamilyStepState extends State<FamilyStep> {
  late bool _join = widget.mode == FamilyStepMode.join;
  bool _busy = false;
  bool _completing = false;

  /// Gerade gegründet: Erfolgsansicht mit „Jetzt einladen“ statt sofortigem Abschluss.
  String? _createdName;

  /// Der Nutzer hat trotz Einladung „andere Familie gründen oder beitreten“ gewählt.
  bool _showChoice = false;
  final Set<String> _autoAccepted = <String>{};
  String? _error;

  /// Name des Einladenden der zuletzt gesendeten Anfrage (für „… muss dich noch bestätigen“).
  String? _waitingFor;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _link = TextEditingController();
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _services.pendingInvite.addListener(_onPending);
  }

  @override
  void dispose() {
    _services.pendingInvite.removeListener(_onPending);
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  /// Ein per Deep Link/QR eingegangener Link wird als Karte gezeigt; gehandelt wird erst auf Tipp.
  void _onPending() {
    if (!mounted || _services.pendingInvite.value == null) return;
    setState(() {
      _join = true;
      _showChoice = true;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await op();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Während der Gründung meldet das Gateway die neue Familie schon; sie darf dann nicht als
  /// „bereits vorhanden“ gelten (sonst fehlte die Erfolgsansicht).
  bool _creating = false;

  Future<void> _create() => _run(() async {
        _creating = true;
        try {
          await _services.gateway.createFamily(_name.text);
          if (mounted) setState(() => _createdName = _name.text.trim());
        } finally {
          _creating = false;
        }
      });

  Future<void> _inviteNow() async {
    await showInviteDialog(context, _services.gateway);
    await widget.onFamilyReady();
  }

  /// Eingefügter Link: prüfen und als Karte zeigen (gleicher Weg wie ein geöffneter Link).
  Future<void> _submitLink() async {
    final l = AppLocalizations.of(context);
    final check = InviteLink.check(_link.text, now: DateTime.now(), ownHost: MatrixIds.serverName(_services.gateway.userId ?? ''));
    final problem = check.problem;
    if (problem != null) {
      setState(() => _error = inviteLinkProblemText(l, problem));
      return;
    }
    _link.clear();
    await _services.settings.update((c) => c.copyWith(pendingInvite: check.raw));
    _services.pendingInvite.value = check.link;
  }

  Future<void> _discard() async {
    _services.pendingInvite.value = null;
    await _services.settings.update((c) => c.copyWith(pendingInvite: null));
    if (mounted) setState(() => _error = null);
  }

  Future<void> _send(InviteLink link) async {
    final l = AppLocalizations.of(context);
    if (!link.isValidAt(DateTime.now())) {
      setState(() => _error = l.joinLinkExpired);
      return;
    }
    await _run(() async {
      await _services.gateway.requestToJoin(link);
      _waitingFor = link.inviterName ?? MatrixIds.localpart(link.inviter);
      await _discard();
    });
  }

  /// Nimmt die Einladung an. Die Karte nennt Familie und Einladenden und warnt bei unerwarteten
  /// Einladungen (S5); der Tipp auf „Beitreten“ ist die Bestätigung.
  Future<void> _accept(PendingInvitation inv) => _run(() async {
        await _services.gateway.acceptInvitation(inv.roomId);
        await widget.onFamilyReady();
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final g = _services.gateway;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[g, _services.pendingInvite]),
      builder: (context, _) {
        if (!g.initialSyncDone) {
          return Row(children: <Widget>[
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l.syncing),
          ]);
        }
        final created = _createdName;
        if (created != null) return _createdView(l, created);
        // Das Konto gehört bereits zu einer Familie (z. B. Anmeldung an einem weiteren Gerät):
        // nichts gründen oder beitreten, die Einrichtung ist damit abgeschlossen.
        final existing = g.family;
        if (existing != null && !_creating) {
          if (!_completing) {
            _completing = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFamilyReady());
          }
          return Semantics(
            liveRegion: true,
            child: Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.onbFamilyFound(existing.name))),
            ]),
          );
        }
        final invitations = g.invitations;
        // Bestätigte eigene Beitrittsanfrage: der Nutzer hat den Beitritt selbst angefordert, kein weiterer Tipp nötig.
        for (final inv in invitations) {
          if (inv.requested && _autoAccepted.add(inv.roomId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _accept(inv);
            });
          }
        }
        // Eingeladenes Konto: direkt die Einladung zeigen, ohne die Frage „Gründen oder Beitreten“ (E-49).
        if (invitations.isNotEmpty && !_showChoice) return _invitedView(l, g, invitations);
        final pending = _services.pendingInvite.value;
        final List<Widget> body;
        if (g.joinRequestPending) {
          body = _waitingView(l, g);
        } else if (pending != null) {
          body = _joinCard(l, pending);
        } else if (widget.mode == FamilyStepMode.choice || _showChoice) {
          body = <Widget>[
            Text(l.onbCreateOrJoin),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text(l.onbCreateTab)),
                ButtonSegment<bool>(value: true, label: Text(l.onbJoinTab)),
              ],
              selected: <bool>{_join},
              onSelectionChanged: (s) => setState(() {
                _join = s.first;
                _error = null;
              }),
            ),
            const SizedBox(height: 12),
            if (!_join) ..._createForm(l) else ..._joinForm(l),
          ];
        } else {
          body = <Widget>[
            if (widget.mode == FamilyStepMode.create) ..._createForm(l) else ..._joinForm(l),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _showChoice = true;
                  _join = widget.mode != FamilyStepMode.join;
                }),
                child: Text(widget.mode == FamilyStepMode.create ? l.familySwitchToJoin : l.familySwitchToCreate),
              ),
            ),
          ];
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          if (invitations.isNotEmpty) ..._invitationCards(l, g, invitations),
          ...body,
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
        ]);
      },
    );
  }

  Widget _createdView(AppLocalizations l, String name) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        Icon(Icons.celebration_outlined, color: theme.colorScheme.primary, size: 32),
        const SizedBox(width: 12),
        Expanded(child: Semantics(liveRegion: true, header: true, child: Text(l.familyCreatedTitle(name), style: theme.textTheme.titleMedium))),
      ]),
      const SizedBox(height: 12),
      Text(l.familyCreatedBody),
      const SizedBox(height: 16),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: <Widget>[
        TextButton(onPressed: widget.onFamilyReady, child: Text(l.later)),
        FilledButton.icon(icon: const Icon(Icons.person_add_alt_1_outlined), onPressed: _inviteNow, label: Text(l.familyInviteNow)),
      ]),
    ]);
  }

  /// Karte zur Einladung (E-56): Namen laut Einladung, technische Angaben nur unter „Details“.
  List<Widget> _joinCard(AppLocalizations l, InviteLink link) {
    final theme = Theme.of(context);
    final inviter = link.inviterName ?? MatrixIds.localpart(link.inviter);
    final family = link.familyName;
    // Familie im Heimnetz, eigenes Konto auf einem anderen Server: die Server erreichen sich nicht, ein
    // Beitritt ist unmöglich – klare Meldung statt einer Anfrage, die scheitert (Review R3).
    final own = MatrixIds.serverName(_services.gateway.userId ?? '');
    final unreachable = link.onLocalServer && own != null && own != link.via;
    // Überschrift „Familie beitreten“ steht in der Titelleiste der Einrichtung.
    return <Widget>[
      // Diese Karte ist für die beitretende Person die eigentliche Sicherheitsabfrage (E-37): Namen
      // stammen aus dem Link; der Anbieter der einladenden Person steht deshalb immer dabei.
      Text(family == null
          ? l.joinCardBodyNoName(inviter, link.inviterServer)
          : l.joinCardBody(family, inviter, link.inviterServer)),
      // Server im Heimnetz (IP, localhost, Name ohne Punkt): erlaubt, aber nur nach deutlicher Warnung (Issue #6).
      if (unreachable) ...<Widget>[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(l.joinCardLocalOtherAccount(link.via, own), style: TextStyle(color: theme.colorScheme.error)),
        ),
      ] else if (link.onLocalServer) ...<Widget>[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(l.joinCardLocalServer(link.via), style: TextStyle(color: theme.colorScheme.error)),
        ),
      ],
      if (link.inviterServer != link.via) ...<Widget>[
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(l.joinCardServerMismatch(link.via, link.inviterServer), style: TextStyle(color: theme.colorScheme.error)),
        ),
      ],
      const SizedBox(height: 8),
      Text(l.joinCardNote(inviter), style: theme.textTheme.bodySmall),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        title: Text(l.joinCardDetails),
        children: <Widget>[
          Text(l.joinCardDetailsInviter, style: theme.textTheme.bodySmall),
          SelectableText(link.inviter, style: monoStyle(context, size: 12)),
          const SizedBox(height: 4),
          Text(l.joinCardDetailsServer, style: theme.textTheme.bodySmall),
          SelectableText(link.via, style: monoStyle(context, size: 12)),
          const SizedBox(height: 8),
        ],
      ),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: <Widget>[
        TextButton(onPressed: _busy ? null : _discard, child: Text(l.joinDiscard)),
        if (!unreachable)
          FilledButton(onPressed: _busy ? null : () => _send(link), child: Text(_busy ? l.joinSending : l.joinSend)),
      ]),
    ];
  }

  List<Widget> _waitingView(AppLocalizations l, MatrixGateway g) {
    final who = _waitingFor;
    return <Widget>[
      Row(children: <Widget>[
        Icon(Icons.hourglass_top, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Semantics(liveRegion: true, child: Text(who == null ? l.joinPending : l.joinWaiting(who)))),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton(onPressed: _busy ? null : () => _run(g.cancelJoinRequest), child: Text(l.joinCancel)),
      ),
    ];
  }

  List<Widget> _invitationCards(AppLocalizations l, MatrixGateway g, List<PendingInvitation> invitations) => <Widget>[
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
                    onPressed: _busy ? null : () => _run(() => g.declineInvitation(inv.roomId)),
                    child: Text(l.decline),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _busy ? null : () => _accept(inv), child: Text(l.accept)),
                ]),
              ]),
            ),
          ),
        const Divider(),
      ];

  Widget _invitedView(AppLocalizations l, MatrixGateway g, List<PendingInvitation> invitations) {
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
                  onPressed: _busy ? null : () => _run(() => g.declineInvitation(inv.roomId)),
                  child: Text(l.decline),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _accept(inv),
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
          onPressed: _busy ? null : () => setState(() => _showChoice = true),
          child: Text(l.onbInvitedOther),
        ),
      ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
        ),
    ]);
  }

  List<Widget> _createForm(AppLocalizations l) => <Widget>[
        Text(l.familyCreateHint),
        const SizedBox(height: 8),
        Text(l.familyMinorsNote, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l.familyName, hintText: l.familyNameHint),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy || _name.text.trim().isEmpty ? null : _create,
            child: Text(_busy ? l.familyCreating : l.familyCreate),
          ),
        ),
      ];

  List<Widget> _joinForm(AppLocalizations l) => <Widget>[
        Text(l.joinHint),
        const SizedBox(height: 12),
        TextField(
          controller: _link,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(labelText: l.joinLinkLabel),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _busy ? null : _submitLink, child: Text(l.next)),
        ),
      ];
}
