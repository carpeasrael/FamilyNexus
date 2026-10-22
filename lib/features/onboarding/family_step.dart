import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/family.dart';
import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Schritt „Familie“: gründen, per Einladungslink beitreten oder Einladungen annehmen.
class FamilyStep extends StatefulWidget {
  const FamilyStep({super.key, required this.onFamilyReady});

  /// Wird aufgerufen, sobald eine Familie besteht (gegründet oder beigetreten).
  final Future<void> Function() onFamilyReady;

  @override
  State<FamilyStep> createState() => _FamilyStepState();
}

class _FamilyStepState extends State<FamilyStep> {
  bool _join = false;
  bool _busy = false;
  bool _completing = false;

  /// Der Nutzer hat trotz Einladung „andere Familie gründen oder beitreten“ gewählt.
  bool _showChoice = false;
  final Set<String> _autoAccepted = <String>{};
  String? _error;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _link = TextEditingController();
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _services.pendingInvite.addListener(_onPending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onPending());
  }

  @override
  void dispose() {
    _services.pendingInvite.removeListener(_onPending);
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  /// Ein per Deep Link/QR eingegangener Link wartet auf Bestätigung.
  void _onPending() {
    final link = _services.pendingInvite.value;
    if (link == null || !mounted) return;
    setState(() => _join = true);
    _services.pendingInvite.value = null;
    _confirmAndSend(link);
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

  Future<void> _create() => _run(() async {
        await _services.gateway.createFamily(_name.text);
        await widget.onFamilyReady();
      });

  Future<void> _submitLink() async {
    final l = AppLocalizations.of(context);
    final link = InviteLink.tryParse(_link.text, now: DateTime.now());
    if (link == null || !link.isValidAt(DateTime.now())) {
      setState(() => _error = l.joinLinkInvalid);
      return;
    }
    await _confirmAndSend(link);
  }

  Future<void> _confirmAndSend(InviteLink link) async {
    final l = AppLocalizations.of(context);
    if (!link.isValidAt(DateTime.now())) {
      setState(() => _error = l.joinLinkInvalid);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.joinConfirmTitle),
        content: Text(l.joinConfirmBody(link.via, link.inviter)),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.joinSend)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await _services.gateway.requestToJoin(link);
      _link.clear();
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
      listenable: g,
      builder: (context, _) {
        if (!g.initialSyncDone) {
          return Row(children: <Widget>[
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
            Text(l.syncing),
          ]);
        }
        // Das Konto gehört bereits zu einer Familie (z. B. Anmeldung an einem weiteren Gerät):
        // nichts gründen oder beitreten, die Einrichtung ist damit abgeschlossen.
        final existing = g.family;
        if (existing != null) {
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
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(l.onbCreateOrJoin),
          const SizedBox(height: 12),
          if (invitations.isNotEmpty) ...<Widget>[
            Semantics(header: true, child: Text(l.invitationsTitle, style: Theme.of(context).textTheme.titleSmall)),
            for (final inv in invitations)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(inv.roomName, style: Theme.of(context).textTheme.titleMedium),
                    Text(l.invitationFrom(inv.inviterId), style: Theme.of(context).textTheme.bodySmall),
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
          ],
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
          if (!_join) ..._createForm(l) else ..._joinForm(l, g),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ),
        ]);
      },
    );
  }

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
              Text(l.invitationFrom(inv.inviterId), style: theme.textTheme.bodySmall),
              if (!inv.requested) ...<Widget>[
                const SizedBox(height: 6),
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
        TextField(controller: _name, maxLength: 60, decoration: InputDecoration(labelText: l.familyName)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _busy ? null : _create, child: Text(_busy ? l.familyCreating : l.familyCreate)),
        ),
      ];

  List<Widget> _joinForm(AppLocalizations l, MatrixGateway g) {
    if (g.joinRequestPending) {
      return <Widget>[
        Semantics(liveRegion: true, child: Text(l.joinPending)),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(onPressed: _busy ? null : () => _run(g.cancelJoinRequest), child: Text(l.joinCancel)),
        ),
      ];
    }
    return <Widget>[
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
        child: FilledButton(onPressed: _busy ? null : _submitLink, child: Text(l.joinSend)),
      ),
    ];
  }
}
