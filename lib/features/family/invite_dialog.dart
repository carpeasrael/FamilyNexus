import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/qr_view.dart';
import '../common/error_text.dart';
import '../common/invite_link_text.dart';

/// „Jemanden einladen“ (E-49, E-56): erzeugt einen einmaligen, zeitlich begrenzten Link und bietet
/// drei einfache Wege an – QR-Code zum Abscannen, E-Mail mit Anleitung, Link kopieren. Die Gültigkeit
/// ist wählbar (1, 3 oder 7 Tage, Issue #6); eine andere Wahl erzeugt einen neuen Link.
Future<void> showInviteDialog(BuildContext context, MatrixGateway gateway) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  // Erster Link vorab: scheitert schon das (z. B. offline), gibt es keinen Dialog, nur die Meldung.
  final String first;
  try {
    first = await gateway.createInviteLink();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => _InviteDialog(gateway: gateway, firstLink: first, messenger: messenger),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.gateway, required this.firstLink, required this.messenger});

  final MatrixGateway gateway;
  final String firstLink;
  final ScaffoldMessengerState messenger;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  Duration _validity = InviteLink.defaultValidity;
  late String _link = widget.firstLink;
  bool _busy = false;

  Future<void> _changeValidity(Duration d) async {
    if (d == _validity || _busy) return;
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final link = await widget.gateway.createInviteLink(validity: d);
      if (mounted) {
        setState(() {
          _validity = d;
          _link = link;
        });
      }
    } catch (e) {
      widget.messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _link));
    widget.messenger.showSnackBar(SnackBar(content: Text(l.familyInviteCopied)));
  }

  /// Öffnet einen Mailentwurf mit Anleitung und Link; ohne Mailprogramm wird der Link kopiert.
  Future<void> _mail() async {
    final l = AppLocalizations.of(context);
    final services = AppScope.read(context);
    final ok = await services.mail.compose(
      subject: l.inviteMailSubject,
      body: l.inviteMailBody(widget.gateway.family?.name ?? '', _link, inviteValiditySentence(l, _validity)),
    );
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: _link));
    widget.messenger.showSnackBar(SnackBar(content: Text(l.familyInviteMailFailed)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.familyInviteLinkTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text(l.familyInviteScanHint),
          const SizedBox(height: 12),
          Center(child: QrView(data: _link, size: 240, semanticLabel: l.familyInviteShowQr)),
          const SizedBox(height: 12),
          Text(l.familyInviteValidityLabel, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          SegmentedButton<Duration>(
            showSelectedIcon: false,
            segments: <ButtonSegment<Duration>>[
              for (final d in InviteLink.validityChoices)
                ButtonSegment<Duration>(value: d, label: Text(inviteValidityText(l, d))),
            ],
            selected: <Duration>{_validity},
            onSelectionChanged: _busy ? null : (s) => _changeValidity(s.first),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(icon: const Icon(Icons.mail_outline), onPressed: _busy ? null : _mail, label: Text(l.familyInviteMail)),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.copy), onPressed: _busy ? null : _copy, label: Text(l.familyInviteCopyLink)),
          const SizedBox(height: 12),
          Text(l.familyInviteLinkHint(inviteValiditySentence(l, _validity)), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
