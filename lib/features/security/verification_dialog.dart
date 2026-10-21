import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Öffnet den Verifizierungsdialog automatisch, sobald eine Verifizierung läuft oder
/// angefragt wird (an beliebiger Stelle der App).
class VerificationListener extends StatefulWidget {
  const VerificationListener({super.key, required this.child});
  final Widget child;

  @override
  State<VerificationListener> createState() => _VerificationListenerState();
}

class _VerificationListenerState extends State<VerificationListener> {
  bool _open = false;
  late final MatrixGateway _gateway;

  @override
  void initState() {
    super.initState();
    _gateway = AppScope.read(context).gateway;
    _gateway.addListener(_check);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _gateway.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (!mounted || _open || _gateway.verification == null) return;
    _open = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => VerificationDialog(gateway: _gateway),
      );
      _open = false;
      // Falls inzwischen eine weitere Verifizierung begonnen hat.
      if (mounted) _check();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class VerificationDialog extends StatelessWidget {
  const VerificationDialog({super.key, required this.gateway});
  final MatrixGateway gateway;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: gateway,
      builder: (context, _) {
        final v = gateway.verification;
        if (v == null) {
          // Gegenseite oder Nutzer hat beendet.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const SizedBox.shrink();
        }
        Future<void> run(Future<void> Function() op) async {
          try {
            await op();
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(l, e))));
          }
        }

        final List<Widget> actions;
        final Widget body;
        switch (v.phase) {
          case VerificationPhase.incomingRequest:
            body = Text(l.verifyIncoming(v.peerDeviceId == null ? v.peerUserId : '${v.peerUserId} (${v.peerDeviceId})'));
            actions = <Widget>[
              TextButton(onPressed: () => run(gateway.cancelVerification), child: Text(l.decline)),
              FilledButton(onPressed: () => run(gateway.acceptVerification), child: Text(l.accept)),
            ];
          case VerificationPhase.waiting:
            body = Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.verifyWaiting)),
            ]);
            actions = <Widget>[TextButton(onPressed: () => run(gateway.cancelVerification), child: Text(l.cancel))];
          case VerificationPhase.comparing:
            body = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(l.verifyCompare),
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: <Widget>[
                for (final e in v.emojis)
                  Semantics(
                    label: e.name,
                    child: Text(e.emoji, style: const TextStyle(fontSize: 34)),
                  ),
              ]),
            ]);
            actions = <Widget>[
              TextButton(onPressed: () => run(() => gateway.confirmEmojiMatch(false)), child: Text(l.verifyNoMatch)),
              FilledButton(onPressed: () => run(() => gateway.confirmEmojiMatch(true)), child: Text(l.verifyMatch)),
            ];
          case VerificationPhase.waitingForPeerConfirmation:
            body = Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Expanded(child: Text(l.verifyWaitingConfirm)),
            ]);
            actions = <Widget>[TextButton(onPressed: () => run(gateway.cancelVerification), child: Text(l.cancel))];
          case VerificationPhase.done:
            body = Row(children: <Widget>[const Icon(Icons.verified_outlined), const SizedBox(width: 12), Text(l.verifyDone)]);
            actions = <Widget>[FilledButton(onPressed: () => run(gateway.cancelVerification), child: Text(l.close))];
          case VerificationPhase.cancelled:
            body = Text(l.verifyCancelled);
            actions = <Widget>[FilledButton(onPressed: () => run(gateway.cancelVerification), child: Text(l.close))];
        }
        return AlertDialog(
          title: Semantics(header: true, child: Text(l.verifyTitle)),
          content: SingleChildScrollView(child: body),
          actions: actions,
        );
      },
    );
  }
}
