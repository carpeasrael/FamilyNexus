import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/family.dart';
import '../../domain/invite_link.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../common/syncing_view.dart';
import '../family/invite_dialog.dart';
import 'family_step_controller.dart';

export 'family_step_controller.dart' show FamilyStepMode, SetupSaveException;

part 'widgets/family_step_parts.dart';

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
  final TextEditingController _name = TextEditingController();
  final TextEditingController _link = TextEditingController();
  final TextEditingController _code = TextEditingController();
  late final AppServices _services;
  late final FamilyStepController _c;

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _c = FamilyStepController(
      gateway: _services.gateway,
      settings: _services.settings,
      pendingInvite: _services.pendingInvite,
      onFamilyReady: widget.onFamilyReady,
      mode: widget.mode,
    );
  }

  @override
  void dispose() {
    _c.dispose();
    _name.dispose();
    _link.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _inviteNow() async {
    await showInviteDialog(context, _services.gateway);
    if (!mounted) return;
    await _c.finish();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final g = _services.gateway;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[g, _services.pendingInvite, _c]),
      builder: (context, _) {
        if (!g.initialSyncDone) return SyncingView(gateway: g);
        final created = _c.createdName;
        if (created != null) return _createdView(l, created);
        // Das Konto gehört bereits zu einer Familie (z. B. Anmeldung an einem weiteren Gerät):
        // nichts gründen oder beitreten, die Einrichtung ist damit abgeschlossen.
        final existing = g.family;
        if (existing != null && !_c.creating) {
          // Das Speichern am Ende ist gescheitert (#411): Fehler zeigen und einen neuen Versuch anbieten, statt endlos zu drehen.
          if (_c.completionFailed) {
            return _CompletionFailed(familyName: existing.name, error: _c.errorMessage(l), busy: _c.busy, onRetry: _c.completeExisting);
          }
          if (!_c.completing) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _c.completeExisting();
            });
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
          if (inv.requested && _c.beginAutoAccept(inv.roomId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _c.accept(inv);
            });
          }
        }
        // Eingeladenes Konto: direkt die Einladung zeigen, ohne die Frage „Gründen oder Beitreten“ (E-49).
        if (invitations.isNotEmpty && !_c.showChoice) {
          return _InvitedView(
            invitations: invitations,
            busy: _c.busy,
            error: _c.errorMessage(l),
            onDecline: _c.decline,
            onAccept: _c.accept,
            onOther: _c.chooseOther,
          );
        }
        final pending = _services.pendingInvite.value;
        final List<Widget> body;
        if (g.joinRequestRejected) {
          body = _rejectedView(l, g);
        } else if (g.joinRequestPending) {
          body = _waitingView(l, g);
        } else if (pending != null) {
          body = _joinCard(l, pending);
        } else if (widget.mode == FamilyStepMode.choice || _c.showChoice) {
          body = <Widget>[
            Text(l.onbCreateOrJoin),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: <ButtonSegment<bool>>[
                ButtonSegment<bool>(value: false, label: Text(l.onbCreateTab)),
                ButtonSegment<bool>(value: true, label: Text(l.onbJoinTab)),
              ],
              selected: <bool>{_c.join},
              onSelectionChanged: (s) => _c.selectJoin(s.first),
            ),
            const SizedBox(height: 12),
            if (!_c.join) ..._createForm(l) else ..._joinForm(l),
          ];
        } else {
          body = <Widget>[
            if (widget.mode == FamilyStepMode.create) ..._createForm(l) else ..._joinForm(l),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _c.switchMode,
                child: Text(widget.mode == FamilyStepMode.create ? l.familySwitchToJoin : l.familySwitchToCreate),
              ),
            ),
          ];
        }
        final error = _c.errorMessage(l);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          if (invitations.isNotEmpty) _InvitationCards(invitations: invitations, busy: _c.busy, onDecline: _c.decline, onAccept: _c.accept),
          ...body,
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error))),
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
        TextButton(onPressed: _c.busy ? null : _c.finish, child: Text(l.later)),
        FilledButton.icon(
          icon: const Icon(Icons.person_add_alt_1_outlined),
          onPressed: _c.busy ? null : _inviteNow,
          label: Text(l.familyInviteNow),
        ),
      ]),
      if (_c.errorMessage(l) case final error?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Semantics(liveRegion: true, child: Text(error, style: TextStyle(color: theme.colorScheme.error))),
        ),
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
        TextButton(onPressed: _c.busy ? null : _c.discard, child: Text(l.joinDiscard)),
        if (!unreachable)
          FilledButton(onPressed: _c.busy ? null : () => _c.send(link), child: Text(_c.busy ? l.joinSending : l.joinSend)),
      ]),
    ];
  }

  /// Ein Moderator hat die Anfrage abgelehnt: erklären statt endlos „unterwegs“ zu zeigen.
  List<Widget> _rejectedView(AppLocalizations l, MatrixGateway g) => <Widget>[
        Row(children: <Widget>[
          Icon(Icons.block_outlined, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Semantics(liveRegion: true, child: Text(l.joinRejected))),
        ]),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 8, children: <Widget>[
            _joinDiagnosticButton(l, g),
            FilledButton(onPressed: _c.busy ? null : _c.cancelJoinRequest, child: Text(l.joinRejectedOk)),
          ]),
        ),
      ];

  /// Technische Details für Testberichte: Das Protokoll aus den Einstellungen ist ohne Familie nicht erreichbar.
  Widget _joinDiagnosticButton(AppLocalizations l, MatrixGateway g) => TextButton(
        onPressed: () {
          final text = g.joinRequestDiagnostic;
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.joinDiagnosticTitle),
              content: SingleChildScrollView(child: SelectableText(text)),
              actions: <Widget>[
                TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(l.joinDiagnosticCopied)));
                  },
                  child: Text(l.joinDiagnosticCopy),
                ),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(l.close)),
              ],
            ),
          );
        },
        child: Text(l.joinDiagnosticDetails),
      );

  List<Widget> _waitingView(AppLocalizations l, MatrixGateway g) {
    final who = _c.waitingFor;
    return <Widget>[
      Row(children: <Widget>[
        Icon(Icons.hourglass_top, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(child: Semantics(liveRegion: true, child: Text(who == null ? l.joinPending : l.joinWaiting(who)))),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(spacing: 8, children: <Widget>[
          _joinDiagnosticButton(l, g),
          OutlinedButton(onPressed: _c.busy ? null : _c.cancelJoinRequest, child: Text(l.joinCancel)),
        ]),
      ),
    ];
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
            onPressed: _c.busy || _name.text.trim().isEmpty ? null : () => _c.create(_name.text),
            child: Text(_c.busy ? l.familyCreating : l.familyCreate),
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
          child: FilledButton(onPressed: _c.busy ? null : () => _c.submitLink(_link.text, clearInput: _link.clear), child: Text(l.next)),
        ),
        // Ohne Link: Familien-Code, den ein Moderator in der Familienansicht nennt.
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(l.joinCodeTitle),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l.joinCodeHint),
            const SizedBox(height: 8),
            TextField(
              controller: _code,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(labelText: l.joinCodeLabel),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: _c.busy ? null : () => _c.sendCode(_code.text, clearInput: _code.clear), child: Text(_c.busy ? l.joinSending : l.joinSend)),
            ),
          ],
        ),
      ];
}
