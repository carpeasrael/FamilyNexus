import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/matrix/matrix_gateway.dart' show GatewayException;
import '../../domain/chat.dart' show ContactRequest;
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import 'add_contact_screen.dart';
import 'contact_controller.dart';
import 'contact_text.dart';

/// Kontakte (#119, K3b-1, §8.1, §8.4): ausgeschaltet eine Erklärseite mit Einwilligung, eingeschaltet Anfragen, Liste,
/// „Kontakt hinzufügen“ und die eigene Kontakt-ID. Alles läuft über den [ContactController].
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key, required this.controller});

  final ContactController controller;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final Map<String, DateTime> _retryAt = <String, DateTime>{};

  ContactController get c => widget.controller;

  Future<void> _run(Future<void> Function() op) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
    } catch (e) {
      if (e is! GatewayException && e is! Exception) rethrow;
      messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    }
  }

  Future<bool> _confirm({required String title, required String body, required String action}) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(action)),
        ],
      ),
    );
    return ok == true && mounted;
  }

  Future<void> _turnOff() async {
    final l = AppLocalizations.of(context);
    if (await _confirm(title: l.contactsTurnOffTitle, body: l.contactsTurnOffBody, action: l.contactsTurnOff)) await _run(() => c.setEnabled(false));
  }

  Future<void> _accept(ContactRequest r) async {
    final l = AppLocalizations.of(context);
    if (await _confirm(title: l.contactsAcceptTitle, body: l.contactsAcceptBody(isolateText(r.fromName), isolateText(r.fromUserId)), action: l.contactsAccept)) {
      await _run(() => c.accept(r.roomId));
    }
  }

  Future<void> _blockRequest(ContactRequest r) async {
    final l = AppLocalizations.of(context);
    if (await _confirm(title: l.contactsBlockTitle, body: l.contactsBlockBody(isolateText(r.fromName), isolateText(r.fromUserId)), action: l.contactsBlock)) {
      await _run(() => c.blockRequest(r.roomId));
    }
  }

  Future<void> _remove(ContactEntry e) async {
    final l = AppLocalizations.of(context);
    if (await _confirm(title: l.contactsRemoveTitle, body: l.contactsRemoveBody(isolateText(e.title), isolateText(e.id)), action: l.contactsRemove)) {
      await _run(() => c.remove(e.id));
    }
  }

  Future<void> _block(ContactEntry e) async {
    final l = AppLocalizations.of(context);
    if (await _confirm(title: l.contactsBlockTitle, body: l.contactsBlockBody(isolateText(e.title), isolateText(e.id)), action: l.contactsBlock)) {
      await _run(() => c.block(e.id));
    }
  }

  Future<void> _retry(ContactEntry e) async {
    final l = AppLocalizations.of(context);
    final until = _retryAt[e.id];
    if (until != null && DateTime.now().isBefore(until)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.contactsRetryWait)));
      return;
    }
    _retryAt[e.id] = DateTime.now().add(ContactController.checkCooldown);
    await _run(() => c.retry(e.id));
  }

  Future<void> _copyId() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: c.myContactId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.contactsCopied)));
  }

  String _stateText(AppLocalizations l, ContactStateView s) => switch (s) {
        ContactStateView.waiting => l.contactsStateWaiting,
        ContactStateView.confirmed => l.contactsStateConfirmed,
        ContactStateView.notSent => l.contactsStateNotSent,
        ContactStateView.searching => l.contactsStateSearching,
        ContactStateView.blocked => l.contactsStateBlocked,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.contactsTitle)),
      body: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (!c.loaded) {
            return Center(child: Semantics(label: l.contactsLoading, child: const CircularProgressIndicator()));
          }
          if (!c.enabled) return _Intro(onTurnOn: () => _run(() => c.setEnabled(true)));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: <Widget>[
            if (c.requests.isNotEmpty || c.requestsHidden > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GlassCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Semantics(header: true, child: Text(l.contactsRequestsTitle, style: Theme.of(context).textTheme.titleLarge)),
                    for (final r in c.requests)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                          MergeSemantics(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                              Text(l.contactsRequestFrom(isolateText(r.fromName))),
                              Text(isolateText(r.fromUserId), style: Theme.of(context).textTheme.bodySmall),
                            ]),
                          ),
                          Wrap(spacing: 8, children: <Widget>[
                            TextButton(onPressed: () => _run(() => c.decline(r.roomId)), child: Text(l.contactsDecline)),
                            TextButton(onPressed: () => _blockRequest(r), child: Text(l.contactsBlock)),
                            FilledButton(onPressed: () => _accept(r), child: Text(l.contactsAccept)),
                          ]),
                        ]),
                      ),
                    if (c.requestsHidden > 0)
                      Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.contactsRequestsMore(c.requestsHidden), style: Theme.of(context).textTheme.bodySmall)),
                  ]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Semantics(header: true, child: Text(l.contactsListTitle, style: Theme.of(context).textTheme.titleLarge)),
                  const SizedBox(height: 8),
                  if (c.contacts.isEmpty) Text(l.contactsListEmpty),
                  for (final e in c.contacts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        MergeSemantics(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                            Text(isolateText(e.title), style: Theme.of(context).textTheme.titleMedium),
                            Text(isolateText(e.id), style: Theme.of(context).textTheme.bodySmall),
                            Text(_stateText(l, e.state), style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        Wrap(spacing: 8, children: <Widget>[
                          if (e.state == ContactStateView.notSent) TextButton(onPressed: () => _retry(e), child: Text(l.contactsRetry)),
                          if (e.state == ContactStateView.blocked)
                            TextButton(onPressed: () => _run(() => c.unblock(e.id)), child: Text(l.contactsUnblock))
                          else ...<Widget>[
                            TextButton(onPressed: () => _remove(e), child: Text(l.contactsRemove)),
                            TextButton(onPressed: () => _block(e), child: Text(l.contactsBlock)),
                          ],
                        ]),
                      ]),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                  Semantics(header: true, child: Text(l.contactsMyId, style: Theme.of(context).textTheme.titleMedium)),
                  const SizedBox(height: 4),
                  SelectableText(isolateText(c.myContactId)),
                  TextButton.icon(onPressed: _copyId, icon: const Icon(Icons.copy), label: Text(l.contactsCopy)),
                ]),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _turnOff, child: Text(l.contactsTurnOff)),
            ),
          ]);
        },
      ),
      floatingActionButton: ListenableBuilder(
        listenable: c,
        builder: (context, _) => c.loaded && c.enabled
            ? FloatingActionButton.extended(
                heroTag: 'fab-contacts',
                tooltip: l.contactsAdd,
                icon: const Icon(Icons.person_add_alt),
                label: Text(l.contactsAdd),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddContactScreen(controller: c))),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

/// Erklärseite (§8.1): Standard ist **aus**; erst die ausdrückliche Taste schaltet ein.
class _Intro extends StatelessWidget {
  const _Intro({required this.onTurnOn});

  final VoidCallback onTurnOn;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListView(padding: const EdgeInsets.all(16), children: <Widget>[
      GlassCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Semantics(header: true, child: Text(l.contactsIntroTitle, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: 12),
          Text(l.contactsIntroBody),
          const SizedBox(height: 16),
          FilledButton(onPressed: onTurnOn, child: Text(l.contactsTurnOn)),
        ]),
      ),
    ]);
  }
}
