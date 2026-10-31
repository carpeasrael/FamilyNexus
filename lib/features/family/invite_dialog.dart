import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/qr_view.dart';
import '../common/error_text.dart';
import '../common/invite_link_text.dart';

/// „Jemanden einladen“ (E-49, E-56): erzeugt einen einmaligen, zeitlich begrenzten Link und bietet
/// drei einfache Wege an – QR-Code zum Abscannen, E-Mail mit Anleitung, Link kopieren. Die Gültigkeit
/// ist wählbar (1, 3 oder 7 Tage, Issue #6); eine andere Wahl erzeugt einen neuen Link. Jede Anfrage
/// bestätigt ein Moderator (E-78).
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
    builder: (c) => _InviteDialog(gateway: gateway, firstLink: first),
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.gateway, required this.firstLink});

  final MatrixGateway gateway;
  final String firstLink;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  Duration _validity = InviteLink.defaultValidity;
  late String _link = widget.firstLink;
  bool _busy = false;

  /// Server für Konto und Anmeldung der Eingeladenen (Feld `srv`, E-63); `null` = Server des Einladenden.
  String? _accountServer;
  final TextEditingController _server = TextEditingController();
  String? _serverError;

  /// Rückmeldung im Dialog („Link kopiert.“ usw.). Ein SnackBar läge auf dem Handy hinter dem Dialog (#66).
  String? _notice;
  bool _copied = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  /// Neuer Link mit geänderter Gültigkeit und/oder anderem Konto-Server; der alte bleibt gültig, wird aber nicht mehr gezeigt.
  Future<void> _regenerate({Duration? validity, String? accountServer, bool keepServer = true}) async {
    final l = AppLocalizations.of(context);
    final v = validity ?? _validity;
    final srv = keepServer ? _accountServer : accountServer;
    setState(() => _busy = true);
    try {
      final link = await widget.gateway.createInviteLink(validity: v, accountServer: srv);
      if (mounted) {
        setState(() {
          _validity = v;
          _accountServer = srv;
          _link = link;
          _serverError = null;
          _notice = null;
          _copied = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (srv != _accountServer) _serverError = errorText(l, e);
          _notice = errorText(l, e);
          _copied = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeValidity(Duration d) async {
    if (d == _validity || _busy) return;
    await _regenerate(validity: d);
  }

  /// Übernimmt den eingetragenen Server (leer = Standard). Eingabe wird wie überall als Server-Adresse geprüft.
  Future<void> _applyServer() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final raw = _server.text.trim();
    String? host;
    if (raw.isNotEmpty) {
      final url = ServerUrl.tryParse(raw);
      if (url == null) {
        setState(() => _serverError = l.familyInviteServerInvalid);
        return;
      }
      host = url.uri.hasPort ? '${url.host}:${url.uri.port}' : url.host;
    }
    if (host == _accountServer) return;
    await _regenerate(accountServer: host, keepServer: false);
  }

  /// Zum Weitergeben: der anklickbare https-Link der Landingpage (E-68); die App liest ihn ebenso.
  String get _shareLink => InviteLink.toWebLink(_link) ?? _link;

  Future<void> _copy() async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: _shareLink));
    if (mounted) {
      setState(() {
        _notice = l.familyInviteCopied;
        _copied = true;
      });
    }
  }

  /// Öffnet einen Mailentwurf mit Anleitung und Link; ohne Mailprogramm wird der Link kopiert.
  Future<void> _mail() async {
    final l = AppLocalizations.of(context);
    final services = AppScope.read(context);
    final ok = await services.mail.compose(
      subject: l.inviteMailSubject,
      body: l.inviteMailBody(_shareLink, inviteValiditySentence(l, _validity)),
    );
    if (ok) return;
    await Clipboard.setData(ClipboardData(text: _shareLink));
    if (mounted) {
      setState(() {
        _notice = l.familyInviteMailFailed;
        _copied = true;
      });
    }
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
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(l.advTitle),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(l.familyInviteServerHint, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              TextField(
                controller: _server,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _applyServer(),
                decoration: InputDecoration(
                  labelText: l.familyInviteServerLabel,
                  hintText: MatrixIds.serverName(widget.gateway.userId ?? ''),
                  errorText: _serverError,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _busy ? null : _applyServer, child: Text(l.familyInviteServerApply)),
              ),
            ],
          ),
          FilledButton.tonalIcon(icon: const Icon(Icons.mail_outline), onPressed: _busy ? null : _mail, label: Text(l.familyInviteMail)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: Icon(_copied ? Icons.check : Icons.copy),
            onPressed: _busy ? null : _copy,
            label: Text(l.familyInviteCopyLink),
          ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Semantics(liveRegion: true, child: Text(_notice!, textAlign: TextAlign.center)),
            ),
          const SizedBox(height: 12),
          Text(
            l.familyInviteLinkHint(inviteValiditySentence(l, _validity)),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]),
      ),
      actions: <Widget>[
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
      ],
    );
  }
}
