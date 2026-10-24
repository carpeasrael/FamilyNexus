import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/qr_view.dart';
import '../common/error_text.dart';

/// „Jemanden einladen“ (E-49, E-56): erzeugt einen einmaligen, zeitlich begrenzten Link und bietet
/// drei einfache Wege an – QR-Code zum Abscannen, E-Mail mit Anleitung, Link kopieren.
Future<void> showInviteDialog(BuildContext context, MatrixGateway gateway) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final services = AppScope.read(context);
  final String link;
  try {
    link = await gateway.createInviteLink();
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return;
  }
  if (!context.mounted) return;

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(SnackBar(content: Text(l.familyInviteCopied)));
  }

  /// Öffnet einen Mailentwurf mit Anleitung und Link; ohne Mailprogramm wird der Link kopiert.
  Future<void> mail() async {
    final ok = await services.mail.compose(
      subject: l.inviteMailSubject,
      body: l.inviteMailBody(gateway.family?.name ?? '', link, '${InviteLink.defaultValidity.inHours}'),
    );
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: link));
    messenger.showSnackBar(SnackBar(content: Text(l.familyInviteMailFailed)));
  }

  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l.familyInviteLinkTitle),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          Text(l.familyInviteScanHint),
          const SizedBox(height: 12),
          Center(child: QrView(data: link, size: 240, semanticLabel: l.familyInviteShowQr)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(icon: const Icon(Icons.mail_outline), onPressed: mail, label: Text(l.familyInviteMail)),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.copy), onPressed: copy, label: Text(l.familyInviteCopyLink)),
          const SizedBox(height: 12),
          Text(l.familyInviteLinkHint, style: Theme.of(c).textTheme.bodySmall),
        ]),
      ),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.close)),
      ],
    ),
  );
}
