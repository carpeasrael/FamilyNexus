import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'contact_controller.dart';
import 'contact_text.dart';

/// Kontakt hinzufügen (#119, K3b-1, §8.2): Eingabe, **Prüfen nur auf ausdrücklichen Tipp** (nie je Tastendruck: die Abfrage
/// zeigt dem eigenen und dem Fremd-Homeserver, wen man sucht), dann eine Karte mit Name **und** voller Kennung und der Taste
/// „Hinzufügen“, nur wenn die Person erreichbar ist.
class AddContactScreen extends StatefulWidget {
  const AddContactScreen({super.key, required this.controller});

  final ContactController controller;

  @override
  State<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<AddContactScreen> {
  final TextEditingController _input = TextEditingController();
  ContactCheck? _result;
  bool _busy = false;

  ContactController get c => widget.controller;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await c.check(_input.text);
      if (mounted) setState(() => _result = r);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final r = _result;
    if (r == null || r.outcome != ContactCheckOutcome.ready || _busy) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await c.add(r.userId);
      messenger.showSnackBar(SnackBar(content: Text(l.contactsAdded)));
      nav.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unblockLocal(String id) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await c.unblockLocal(id);
      await _check();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  String _text(AppLocalizations l, ContactCheckOutcome o) => switch (o) {
        ContactCheckOutcome.invalid => l.contactsCheckInvalid,
        ContactCheckOutcome.self => l.contactsCheckSelf,
        ContactCheckOutcome.duplicate => l.contactsCheckDuplicate,
        ContactCheckOutcome.blockedRecord => l.contactsCheckBlockedRecord,
        ContactCheckOutcome.blockedLocal => l.contactsCheckBlockedLocal,
        ContactCheckOutcome.familyMember => l.contactsCheckFamily,
        ContactCheckOutcome.notFound => l.contactsCheckNotFound,
        ContactCheckOutcome.notReachable => l.contactsCheckNotReachable,
        ContactCheckOutcome.identityChanged => l.contactsCheckIdentity,
        ContactCheckOutcome.unknown => l.contactsCheckUnknown,
        ContactCheckOutcome.rateLimited => l.contactsCheckRateLimited,
        ContactCheckOutcome.notReady => l.contactsCheckNotReady,
        ContactCheckOutcome.busy => '',
        ContactCheckOutcome.ready => '',
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.contactsAddTitle)),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          final until = c.checkBlockedUntil;
          final locked = until != null && DateTime.now().isBefore(until);
          return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
            GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                TextField(
                  controller: _input,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(labelText: l.contactsAddHint),
                  onChanged: (_) {
                    // Eine geänderte Eingabe macht das bisherige Ergebnis ungültig; es wird nichts abgefragt.
                    if (_result != null) setState(() => _result = null);
                  },
                  onSubmitted: (_) => _check(),
                ),
                const SizedBox(height: 8),
                Text(l.contactsCheckPrivacy, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy || locked ? null : _check,
                  child: Text(r != null && (r.outcome == ContactCheckOutcome.unknown) ? l.contactsCheckAgain : l.contactsCheck),
                ),
              ]),
            ),
            if (r != null && r.outcome != ContactCheckOutcome.busy)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    if (r.userId.isNotEmpty && r.outcome == ContactCheckOutcome.ready) ...<Widget>[
                      MergeSemantics(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          Semantics(header: true, child: Text(l.contactsFoundTitle, style: Theme.of(context).textTheme.titleMedium)),
                          if (r.displayName.isNotEmpty) Text(l.contactsFoundName(isolateText(r.displayName))),
                          Text(l.contactsFoundId(isolateText(r.userId))),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _busy ? null : _add, child: Text(l.contactsAddConfirm)),
                    ] else ...<Widget>[
                      Semantics(liveRegion: true, child: Text(_text(l, r.outcome))),
                      if (r.outcome == ContactCheckOutcome.blockedLocal)
                        TextButton(onPressed: () => _unblockLocal(r.userId), child: Text(l.contactsUnblockLocal)),
                    ],
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
