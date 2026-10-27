import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/account_deletion.dart';
import '../../domain/family.dart';
import '../../domain/permissions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Kontolöschung aus der App heraus (#12, Apple 5.1.1(v)): klassisch mit Passwort in der App, bei
/// Anmeldung im Browser über die Löschseite des Anbieters. Endet die Sitzung, löscht die App danach
/// alle lokalen Daten ([AppServices.accountDeletionPending]).
Future<void> deleteAccount(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final services = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final AccountDeletion how;
  try {
    how = await services.gateway.accountDeletion();
  } on GatewayException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => AccountDeletionDialog(how: how));
  // Abgebrochen oder Konto besteht noch: keine spätere Löschung der lokalen Daten.
  if (services.gateway.session == SessionState.ready) services.accountDeletionPending = false;
}

/// Ist man der einzige Moderator einer Familie mit weiteren Mitgliedern? Dann kann sie nach der
/// Löschung niemand mehr verwalten (Hinweis, nicht blockierend).
bool soleModerator(Family? f) {
  if (f == null || !Permissions.isModerator(f)) return false;
  final others = f.joined.where((m) => m.userId != f.myUserId);
  return others.isNotEmpty && others.every((m) => m.role != Role.moderator);
}

class AccountDeletionDialog extends StatefulWidget {
  const AccountDeletionDialog({super.key, required this.how});
  final AccountDeletion how;

  @override
  State<AccountDeletionDialog> createState() => _AccountDeletionDialogState();
}

class _AccountDeletionDialogState extends State<AccountDeletionDialog> {
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _browserOpened = false;
  String? _error;

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(AppServices s, AppLocalizations l) action) async {
    final l = AppLocalizations.of(context);
    final s = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(s, l);
    } on GatewayException catch (e) {
      // Hier wird nur das Passwort abgefragt: kein Hinweis auf den Benutzernamen (#36).
      final text = e.error == GatewayError.invalidCredentials ? l.errWrongPassword : errorText(l, e);
      if (mounted) setState(() => _error = text);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteInApp() => _run((s, l) async {
        s.accountDeletionPending = true;
        try {
          await s.gateway.deleteAccount(password: _password.text);
        } catch (_) {
          s.accountDeletionPending = false;
          rethrow;
        }
      });

  Future<void> _openPage(Uri page) => _run((s, l) async {
        s.accountDeletionPending = true;
        if (!await s.browser.open(page)) {
          s.accountDeletionPending = false;
          if (mounted) setState(() => _error = l.accountDeleteNoBrowser);
          return;
        }
        if (mounted) setState(() => _browserOpened = true);
      });

  Future<void> _check() => _run((s, l) async {
        if (!await s.gateway.checkAccountDeleted() && mounted) setState(() => _error = l.accountDeleteStillActive);
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final g = AppScope.of(context).gateway;
    final how = widget.how;
    final error = Theme.of(context).colorScheme.error;
    final destructive = FilledButton.styleFrom(backgroundColor: error, foregroundColor: Theme.of(context).colorScheme.onError);
    return AlertDialog(
      title: Text(l.accountDeleteTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Text(l.accountDeleteBody(g.userId ?? '–', g.server?.host ?? '–')),
          if (soleModerator(g.family)) ...<Widget>[
            const SizedBox(height: 12),
            Text(l.accountDeleteSoleModerator, style: TextStyle(color: error)),
          ],
          const SizedBox(height: 12),
          switch (how) {
            AccountDeletionInApp() => TextField(
                controller: _password,
                obscureText: true,
                enabled: !_busy,
                autofillHints: const <String>[AutofillHints.password],
                decoration: InputDecoration(labelText: l.accountDeletePassword),
                onChanged: (_) => setState(() {}),
              ),
            AccountDeletionInBrowser() => Text(_browserOpened ? l.accountDeleteBrowserWait : l.accountDeleteBrowserIntro),
          },
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: error)),
          ],
        ]),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
        switch (how) {
          AccountDeletionInApp() => FilledButton(
              style: destructive,
              onPressed: _busy || _password.text.isEmpty ? null : _deleteInApp,
              child: Text(l.accountDeleteConfirm),
            ),
          AccountDeletionInBrowser(:final page) when !_browserOpened => FilledButton(
              style: destructive,
              onPressed: _busy ? null : () => _openPage(page),
              child: Text(l.accountDeleteOpen),
            ),
          AccountDeletionInBrowser(:final page) => Wrap(spacing: 8, children: <Widget>[
              TextButton(onPressed: _busy ? null : () => _openPage(page), child: Text(l.accountDeleteOpenAgain)),
              FilledButton(onPressed: _busy ? null : _check, child: Text(l.accountDeleteCheck)),
            ]),
        },
      ],
    );
  }
}
