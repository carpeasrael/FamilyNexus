import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../common/error_text.dart';
import '../common/prompt_dialog.dart';

/// Einrichtung bzw. Wiederherstellung der Schlüsselsicherung. Wird in der Ersteinrichtung
/// (nach der Anmeldung) gezeigt, bis dieses Gerät verifiziert ist. Es gibt kein Überspringen:
/// Ohne Verifizierung erhält ein Gerät keine Raumschlüssel (SA-1).
class SecurityPanel extends StatefulWidget {
  const SecurityPanel({super.key});

  @override
  State<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<SecurityPanel> {
  bool _busy = false;
  String? _error;
  String? _recoveryKey; // wird nur im Speicher gehalten, bis der Nutzer bestätigt
  bool _keySaved = false;
  final TextEditingController _restore = TextEditingController();

  AppServices? _services;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _services = AppScope.of(context);
  }

  @override
  void dispose() {
    _restore.dispose();
    if (_recoveryKey != null) _protectKey(false);
    super.dispose();
  }

  /// Solange der Wiederherstellungsschlüssel zu sehen ist, ist der Bildschirmschutz erzwungen –
  /// unabhängig von der Einstellung (S6). Danach gilt wieder die Einstellung.
  void _protectKey(bool on) {
    final s = _services;
    if (s != null) s.screenProtection.setSecure(on || s.settings.settings.secureScreen).ignore();
  }

  MatrixGateway get _g => AppScope.read(context).gateway;

  Future<void> _setUp({String? password}) async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final key = await _g.setUpSecurity(password: password);
      if (mounted) {
        _protectKey(true);
        setState(() => _recoveryKey = key);
      }
    } on GatewayException catch (e) {
      if (e.error == GatewayError.reauthRequired && mounted) {
        final pw = await _askPassword();
        if (pw != null) return _setUp(password: pw);
      } else if (mounted) {
        setState(() => _error = errorText(l, e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askPassword() {
    final l = AppLocalizations.of(context);
    return TextPromptDialog.show(
      context,
      TextPromptDialog(
        title: l.securityPasswordTitle,
        hint: l.securityPasswordHint,
        label: l.accountPassword,
        confirmLabel: l.next,
        obscure: true,
      ),
    );
  }

  Future<void> _restoreWithKey() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _g.restoreSecurity(_restore.text);
      _restore.clear();
    } on GatewayException catch (e) {
      if (mounted) setState(() => _error = e.error == GatewayError.invalidInput ? l.securityRestoreFailed : errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).gateway;
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final state = g.securityState;
        // Schlüsselanzeige hat Vorrang, bis bestätigt – auch wenn der Zustand schon „bereit“ ist.
        if (_recoveryKey != null) return _keyView(l);
        switch (state) {
          case SecurityState.unknown:
            return Row(children: <Widget>[
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              Text(l.syncing),
            ]);
          case SecurityState.needsSetup:
            return _setupView(l);
          case SecurityState.needsRestore:
            return _restoreView(l, g);
          case SecurityState.ready:
            return Row(children: <Widget>[const Icon(Icons.verified_outlined), const SizedBox(width: 8), Text(l.securityStatusReady)]);
        }
      },
    );
  }

  Widget _setupView(AppLocalizations l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Semantics(header: true, child: Text(l.securityTitle, style: Theme.of(context).textTheme.titleLarge)),
        const SizedBox(height: 8),
        Text(l.securityIntro),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: _busy ? null : _setUp, child: Text(_busy ? l.securitySettingUp : l.securitySetupButton)),
        ),
      ]);

  Widget _keyView(AppLocalizations l) {
    final t = AuroraTokens.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Semantics(header: true, child: Text(l.securityKeyTitle, style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: t.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        // Bewusst nicht kopierbar: kein Eintrag in die Zwischenablage.
        child: Text(_recoveryKey!, style: monoStyle(context, size: 18)),
      ),
      const SizedBox(height: 8),
      Text(l.securityKeyHint, style: Theme.of(context).textTheme.bodySmall),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _keySaved,
        onChanged: (v) => setState(() => _keySaved = v ?? false),
        title: Text(l.securityKeySaved),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _keySaved
              ? () {
                  _protectKey(false);
                  setState(() => _recoveryKey = null);
                }
              : null,
          child: Text(l.next),
        ),
      ),
    ]);
  }

  Widget _restoreView(AppLocalizations l, MatrixGateway g) {
    final others = g.devices.where((d) => !d.isCurrent).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Semantics(header: true, child: Text(l.securityRestoreTitle, style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 8),
      Text(l.securityRestoreIntro),
      const SizedBox(height: 12),
      if (others.isEmpty)
        Text(l.securityNoOtherDevice, style: Theme.of(context).textTheme.bodySmall)
      else
        for (final d in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.devices_other_outlined),
              label: Text('${l.securityVerifyWithDevice}: ${d.name}'),
              onPressed: _busy ? null : () => g.startVerification(userId: d.userId, deviceId: d.deviceId).catchError((Object e) {
                    if (mounted) setState(() => _error = errorText(l, e));
                  }),
            ),
          ),
      TextButton(onPressed: () => g.refreshSecurity(), child: Text(l.retry)),
      const Divider(),
      TextField(
        controller: _restore,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        minLines: 1,
        maxLines: 3,
        decoration: InputDecoration(labelText: l.securityRestoreKeyLabel),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: _busy ? null : _restoreWithKey, child: Text(_busy ? l.securityRestoring : l.securityRestoreButton)),
      ),
    ]);
  }
}
