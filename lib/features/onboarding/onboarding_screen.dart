import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/app_settings.dart';
import '../../domain/security.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../common/error_text.dart';
import '../security/security_panel.dart';
import 'family_step.dart';

/// Ersteinrichtung in vier Schritten: Sprache, Server, Konto, Familie.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _steps = 4;
  int _step = 0;
  bool _stepChosen = false;

  // Server
  bool _customServer = false;
  final TextEditingController _serverCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  ServerInfo? _info;

  // Konto
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void dispose() {
    _serverCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Beim ersten Aufbau an den passenden Schritt springen (z. B. nach Abmeldung).
  void _chooseInitialStep(AppServices s) {
    if (_stepChosen) return;
    _stepChosen = true;
    final loggedIn = s.gateway.session == SessionState.ready;
    if (loggedIn) {
      // Ohne verifiziertes Gerät zuerst die Schlüsselsicherung (Konto-Schritt).
      _step = s.gateway.securityState == SecurityState.ready ? 3 : 2;
    } else if (s.settings.settings.onboardingDone) {
      _step = 2;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final l = AppLocalizations.of(context);
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  ServerUrl? _selectedServer(AppServices s) => ServerUrl.tryParse(
        _customServer ? _serverCtrl.text : AppSettings.defaultServerUrl,
      );

  Future<void> _checkServer(AppServices s) async {
    final l = AppLocalizations.of(context);
    final url = _selectedServer(s);
    if (url == null) {
      setState(() => _error = l.serverUrlInvalid);
      return;
    }
    await _run(() async {
      final info = await s.gateway.probeServer(url);
      if (!mounted) return;
      setState(() => _info = info);
      await s.settings.update((c) => c.copyWith(serverUrl: url.toString()));
    });
  }

  Future<void> _login(AppServices s) => _run(() async {
        final url = ServerUrl.tryParse(s.settings.settings.serverUrl);
        if (url == null) throw const GatewayException(GatewayError.invalidInput);
        await s.gateway.login(
          server: url,
          username: _userCtrl.text,
          password: _passCtrl.text,
        );
        _passCtrl.clear();
        // Es folgt die Schlüsselsicherung im selben Schritt (SecurityPanel).
        if (mounted) setState(() {});
      });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    _chooseInitialStep(s);
    final l = AppLocalizations.of(context);
    final titles = <String>[l.onbTitleLanguage, l.onbTitleServer, l.onbTitleAccount, l.onbTitleFamily];
    return Scaffold(
      appBar: AppBar(title: Text(titles[_step])),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Semantics(
              liveRegion: true,
              child: Text(l.onbStep(_step + 1, _steps), style: Theme.of(context).textTheme.labelMedium),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (_step + 1) / _steps),
            const SizedBox(height: 16),
            GlassCard(child: _buildStep(context, s, l)),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AppServices s, AppLocalizations l) {
    switch (_step) {
      case 0:
        return _languageStep(s, l);
      case 1:
        return _serverStep(s, l);
      case 2:
        return _accountStep(s, l);
      default:
        return _familyStep(s, l);
    }
  }

  Widget _languageStep(AppServices s, AppLocalizations l) {
    final lang = s.settings.settings.languageCode;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.onbIntro),
      const SizedBox(height: 12),
      for (final p in <String>[l.onbPoint1, l.onbPoint2, l.onbPoint3])
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(p)),
          ]),
        ),
      const SizedBox(height: 16),
      Text(l.settingsLanguage, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: <Widget>[
        for (final e in <String?, String>{null: l.languageSystem, 'de': l.languageGerman, 'en': l.languageEnglish}.entries)
          ChoiceChip(
            label: Text(e.value),
            selected: lang == e.key,
            onSelected: (_) => s.settings.update((c) => c.copyWith(languageCode: e.key)),
          ),
      ]),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(onPressed: () => setState(() => _step = 1), child: Text(l.next)),
      ),
    ]);
  }

  Widget _serverStep(AppServices s, AppLocalizations l) {
    final defaultHost = ServerUrl.tryParse(AppSettings.defaultServerUrl)!.host;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      RadioGroup<bool>(
        groupValue: _customServer,
        onChanged: (v) => setState(() {
          _customServer = v ?? false;
          _info = null;
          _error = null;
        }),
        child: Column(children: <Widget>[
          RadioListTile<bool>(value: false, title: Text(l.serverDefault(defaultHost))),
          RadioListTile<bool>(value: true, title: Text(l.serverCustom)),
        ]),
      ),
      if (_customServer)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: TextField(
            controller: _serverCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.serverUrlLabel),
            onChanged: (_) => setState(() => _info = null),
          ),
        ),
      const SizedBox(height: 8),
      Text(l.serverMetadataNote, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: _busy ? null : () => _checkServer(s),
        child: Text(_busy ? l.serverChecking : l.serverCheck),
      ),
      if (_info != null) ...<Widget>[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(l.serverOk(_info!.versions.last)),
            Text(l.serverOperator(_info!.url.host)),
            Text(_info!.contact == null ? l.serverContactUnknown : l.serverContact(_info!.contact!)),
            if (!_info!.supportsPasswordLogin)
              Text(l.serverNoPassword, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ],
      const SizedBox(height: 16),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
        TextButton(onPressed: () => setState(() => _step = 0), child: Text(l.back)),
        FilledButton(
          onPressed: (_info != null && _info!.supportsPasswordLogin) ? () => setState(() => _step = 2) : null,
          child: Text(l.next),
        ),
      ]),
    ]);
  }

  Widget _accountStep(AppServices s, AppLocalizations l) {
    if (s.gateway.session == SessionState.ready) {
      // Angemeldet: Schlüsselsicherung einrichten/wiederherstellen, dann weiter.
      return ListenableBuilder(
        listenable: s.gateway,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          const SecurityPanel(),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            TextButton(onPressed: () => s.gateway.logout(), child: Text(l.onbChangeAccount)),
            FilledButton(
              onPressed: s.gateway.securityState == SecurityState.ready ? () => setState(() => _step = 3) : null,
              child: Text(l.next),
            ),
          ]),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l.accountHint),
        const SizedBox(height: 12),
        TextField(
          controller: _userCtrl,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.accountUsername),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passCtrl,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(labelText: l.accountPassword),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
          TextButton(onPressed: () => setState(() => _step = 1), child: Text(l.back)),
          FilledButton(
            onPressed: _busy ? null : () => _login(s),
            child: Text(_busy ? l.accountLoggingIn : l.accountLogin),
          ),
        ]),
      ],
    );
  }

  Widget _familyStep(AppServices s, AppLocalizations l) => FamilyStep(
        onFamilyReady: () => s.settings.update((c) => c.copyWith(onboardingDone: true)),
      );
}
