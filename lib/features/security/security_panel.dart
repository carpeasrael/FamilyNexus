import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/security.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/theme/tokens.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../common/prompt_dialog.dart';
import '../common/syncing_view.dart';
import '../../data/platform/secret_clipboard.dart';

/// Leert die Zwischenablage nach [delay], falls sie noch [secret] enthält (E-57). Bewusst nicht an ein
/// Widget gebunden: Der Schlüssel darf nicht liegen bleiben, nur weil die Einrichtung weitergeht.
///
/// Im Hintergrund dürfen Apps die Zwischenablage oft nicht lesen (Android 10+) oder laufen gar nicht
/// (iOS); dann wird beim nächsten Zurückkehren in die App erneut geprüft.
void clearClipboardLater(String secret, {Duration delay = const Duration(seconds: 60)}) {
  AppLifecycleListener? listener;
  Timer? giveUp;
  var due = false;
  var done = false;

  Future<void> attempt() async {
    if (done || !due) return;
    try {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current == null) return; // nicht lesbar (Hintergrund): beim Zurückkehren erneut
      done = true;
      listener?.dispose();
      giveUp?.cancel();
      if (current.text == secret) await Clipboard.setData(const ClipboardData(text: ''));
    } catch (_) {
      // Ohne Zugriff auf die Zwischenablage bleibt nichts zu tun.
    }
  }

  listener = AppLifecycleListener(onResume: () => attempt().ignore());
  Timer(delay, () {
    due = true;
    attempt().ignore();
  });
  // Spätestens nach einer Stunde aufgeben (keine dauerhaft hängenden Beobachter).
  giveUp = Timer(const Duration(hours: 1), () {
    done = true;
    listener?.dispose();
  });
}

/// Einrichtung bzw. Wiederherstellung der Schlüsselsicherung („Notfall-Schlüssel“, E-57). Wird in der
/// Ersteinrichtung (nach der Anmeldung) gezeigt, bis dieses Gerät verifiziert ist. Es gibt kein
/// Überspringen: Ohne Verifizierung erhält ein Gerät keine Raumschlüssel (SA-1).
///
/// Mit [renew] ersetzt das Panel auf einem verifizierten Gerät den Schlüssel durch einen neuen (#11).
/// Datum der Schlüsseldatei in der Schreibweise der App-Sprache, z. B. `31.10.2026` bzw. `10/31/2026` (#162).
String keyFileDate(DateTime d, String locale) => DateFormat.yMd(locale).format(d);

class SecurityPanel extends StatefulWidget {
  const SecurityPanel({super.key, this.onReady, this.renew = false, this.onDone});

  /// Wird einmal aufgerufen, sobald dieses Gerät abgesichert ist und kein Schlüssel mehr angezeigt wird.
  final VoidCallback? onReady;

  /// Neuen Schlüssel erstellen statt Ersteinrichtung bzw. Wiederherstellung.
  final bool renew;

  /// Bei [renew]: aufgerufen, nachdem der neue Schlüssel bestätigt ist.
  final VoidCallback? onDone;

  @override
  State<SecurityPanel> createState() => _SecurityPanelState();
}

class _SecurityPanelState extends State<SecurityPanel> {
  bool _busy = false;
  // Einrichtung läuft: Der Zustand kann schon „bereit“ sein, bevor der Schlüssel zurückkommt (#10).
  bool _creatingKey = false;
  String? _error;
  String? _recoveryKey; // wird nur im Speicher gehalten, bis der Nutzer bestätigt
  bool _keySaved = false;
  bool _readyReported = false;
  final TextEditingController _restore = TextEditingController();

  void _reportReady() {
    if (_readyReported || widget.onReady == null) return;
    _readyReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady!();
    });
  }

  Future<void> _copyKey(String key) async {
    final l = AppLocalizations.of(context);
    final m = ScaffoldMessenger.of(context);
    await copySecret(key);
    clearClipboardLater(key);
    m.showSnackBar(SnackBar(content: Text(l.keyCopied)));
  }

  Future<void> _saveKey(String key) async {
    final l = AppLocalizations.of(context);
    final s = AppScope.read(context);
    final m = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final date = keyFileDate(now, Localizations.localeOf(context).toLanguageTag());
    final text = l.keyFileBody(s.gateway.userId ?? '', s.gateway.server?.host ?? '', key, date);
    try {
      final saved = await s.files.saveFile(name: l.keyFileName, bytes: utf8.encode(text), mimeType: 'text/plain');
      if (saved) m.showSnackBar(SnackBar(content: Text(l.keySavedFile)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text(l.errUnknown)));
    }
  }

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
      _creatingKey = true;
      _error = null;
    });
    try {
      final key = widget.renew ? await _g.resetRecoveryKey() : await _g.setUpSecurity(password: password);
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
      if (mounted) {
        setState(() {
          _busy = false;
          _creatingKey = false;
        });
      }
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
      if (mounted) setState(() => _error = e.error == GatewayError.invalidInput ? l.keyRestoreFailed : errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = AppScope.of(context).gateway;
    final l = AppLocalizations.of(context);
    // Neuer Schlüssel: Der alte gilt schon nicht mehr – kein Zurück, bis der neue bestätigt ist.
    return PopScope(
      canPop: !widget.renew || (!_creatingKey && _recoveryKey == null),
      child: _content(g, l),
    );
  }

  Widget _content(MatrixGateway g, AppLocalizations l) {
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final state = g.securityState;
        // Schlüsselanzeige hat Vorrang, bis bestätigt – auch wenn der Zustand schon „bereit“ ist.
        if (_recoveryKey != null) return _keyView(l);
        // Während der Einrichtung nicht als „bereit“ melden, sonst geht die Einrichtung weiter und
        // der Schlüssel kommt nie zur Anzeige (#10).
        if (_creatingKey || widget.renew) return _setupView(l);
        switch (state) {
          case SecurityState.unknown:
            return SyncingView(gateway: g);
          case SecurityState.needsSetup:
            return _setupView(l);
          case SecurityState.needsRestore:
            return _restoreView(l, g);
          case SecurityState.ready:
            _reportReady();
            return Row(children: <Widget>[const Icon(Icons.verified_outlined), const SizedBox(width: 8), Text(l.securityStatusReady)]);
        }
      },
    );
  }

  Widget _setupView(AppLocalizations l) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        // Überschrift steht in der Titelleiste der Einrichtung.
        Text(widget.renew ? l.keyRenewIntro : l.keyIntro),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _busy ? null : _setUp,
            child: Text(_busy ? l.keyCreating : (widget.renew ? l.keyRenew : l.keyCreate)),
          ),
        ),
      ]);

  /// Schlüssel in Vierergruppen: leichter abzuschreiben und vorzulesen.
  static String _grouped(String key) {
    final compact = key.replaceAll(RegExp(r'\s+'), '');
    final parts = <String>[for (var i = 0; i < compact.length; i += 4) compact.substring(i, i + 4 > compact.length ? compact.length : i + 4)];
    return parts.join(' ');
  }

  Widget _keyView(AppLocalizations l) {
    final t = AuroraTokens.of(context);
    final key = _recoveryKey!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.keyShownIntro),
      const SizedBox(height: 12),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: t.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_grouped(key), style: monoStyle(context, size: 18)),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: <Widget>[
        OutlinedButton.icon(icon: const Icon(Icons.copy), onPressed: () => _copyKey(key), label: Text(l.keyCopy)),
        OutlinedButton.icon(icon: const Icon(Icons.save_alt), onPressed: () => _saveKey(key), label: Text(l.keySave)),
      ]),
      const SizedBox(height: 8),
      Text(l.keyPrintHint, style: Theme.of(context).textTheme.bodySmall),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _keySaved,
        onChanged: (v) => setState(() => _keySaved = v ?? false),
        title: Text(l.keySavedCheck),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _keySaved
              ? () {
                  _protectKey(false);
                  setState(() => _recoveryKey = null);
                  if (widget.renew) widget.onDone?.call();
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
      Text(l.keyRestoreIntro),
      const SizedBox(height: 12),
      if (others.isEmpty)
        Text(l.keyNoOtherDevice, style: Theme.of(context).textTheme.bodySmall)
      else
        for (final d in others)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.devices_other_outlined),
              label: Text(l.keyVerifyWithDevice(d.name)),
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
        decoration: InputDecoration(labelText: l.keyRestoreLabel),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: _busy ? null : _restoreWithKey, child: Text(_busy ? l.keyRestoring : l.keyRestoreButton)),
      ),
    ]);
  }
}

/// Eigene Seite aus den Einstellungen: neuen Notfall-Schlüssel erstellen (#11).
class RecoveryKeyRenewScreen extends StatelessWidget {
  const RecoveryKeyRenewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.keyRenewTitle)),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
          GlassCard(child: SecurityPanel(renew: true, onDone: () => Navigator.of(context).pop())),
        ]),
      ),
    );
  }
}
