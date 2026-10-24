import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../domain/security.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';
import '../security/security_panel.dart';
import 'account_create_step.dart';
import 'family_step.dart';
import 'invite_link_step.dart';
import 'login_step.dart';
import 'provider_controller.dart';
import 'welcome_step.dart';

enum _Step { welcome, inviteLink, account, login, security, family }

/// Ersteinrichtung (E-55, E-56): drei Wege ohne Fachbegriffe.
///
/// * Neue Familie gründen: Konto erstellen → Notfall-Schlüssel → Familie benennen.
/// * Ich wurde eingeladen: (Link einfügen →) Konto erstellen beim Anbieter des Einladenden →
///   Notfall-Schlüssel → Beitritt anfragen.
/// * Ich habe schon ein Konto: Anmelden → Gerät freischalten → Familie wird gefunden (oder gründen/beitreten).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step _step = _Step.welcome;
  OnboardingPath _path = OnboardingPath.create;

  /// Der Weg „eingeladen“ begann ohne Link (zusätzlicher Schritt „Link einfügen“).
  bool _withLinkStep = false;
  String? _loginUsername;
  bool _started = false;

  late final AppServices _s = AppScope.read(context);
  late final ProviderController _provider = ProviderController(gateway: _s.gateway, settings: _s.settings);

  @override
  void initState() {
    super.initState();
    _s.gateway.addListener(_onGateway);
    _s.pendingInvite.addListener(_onInvite);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _chooseInitialStep();
    if (_step == _Step.account || _step == _Step.login) _provider.start();
  }

  @override
  void dispose() {
    _s.gateway.removeListener(_onGateway);
    _s.pendingInvite.removeListener(_onInvite);
    _provider.dispose();
    super.dispose();
  }

  /// Beim ersten Aufbau an den passenden Schritt springen (z. B. nach Neustart oder Abmeldung).
  void _chooseInitialStep() {
    final loggedIn = _s.gateway.session == SessionState.ready;
    final invite = _s.pendingInvite.value;
    if (invite != null) _path = OnboardingPath.invited;
    if (loggedIn) {
      if (invite == null) _path = OnboardingPath.login;
      // Ohne verifiziertes Gerät zuerst der Notfall-Schlüssel bzw. die Freischaltung.
      _step = _s.gateway.securityState == SecurityState.ready ? _Step.family : _Step.security;
    } else if (invite != null) {
      _useInviteProvider(invite);
      _step = _Step.account;
    } else if (_s.settings.settings.onboardingDone) {
      _path = OnboardingPath.login;
      _step = _Step.login;
    }
  }

  void _useInviteProvider(InviteLink invite) {
    final url = ServerUrl.tryParse(invite.inviterServer);
    // Nicht lesbarer Servername: beim bisherigen Anbieter bleiben (sonst stünde „Verbinde …“ für immer).
    // Server im Heimnetz: erst nach Zustimmung verbinden (Review R2).
    url != null ? _provider.useStandard(url, askFirst: InviteLink.isLocalServer(invite.inviterServer)) : _provider.start();
  }

  /// Angemeldet (Konto erstellt oder Anmeldung): weiter zur Absicherung; abgemeldet: zurück.
  void _onGateway() {
    if (!mounted) return;
    final loggedIn = _s.gateway.session == SessionState.ready;
    // Angemeldet in einem Schritt vor der Absicherung (auch nach „Zurück“ während der Browser-Anmeldung).
    if (loggedIn && (_step == _Step.welcome || _step == _Step.inviteLink || _step == _Step.account || _step == _Step.login)) {
      setState(() => _step = _s.gateway.securityState == SecurityState.ready ? _Step.family : _Step.security);
    } else if (!loggedIn && (_step == _Step.security || _step == _Step.family)) {
      setState(() {
        _path = OnboardingPath.login;
        _step = _Step.login;
      });
      _provider.start();
    }
  }

  /// Einladung kam während der Einrichtung an (Deep Link/QR): Neulinge landen direkt bei „Konto erstellen“.
  void _onInvite() {
    final invite = _s.pendingInvite.value;
    if (!mounted || invite == null) return;
    if (_step == _Step.welcome || _step == _Step.inviteLink) {
      setState(() {
        _path = OnboardingPath.invited;
        _step = _Step.account;
      });
      _useInviteProvider(invite);
    }
  }

  void _choose(OnboardingPath path) {
    final invite = _s.pendingInvite.value;
    setState(() {
      _path = path;
      _withLinkStep = path == OnboardingPath.invited && invite == null;
      _step = switch (path) {
        OnboardingPath.create => _Step.account,
        OnboardingPath.invited => invite == null ? _Step.inviteLink : _Step.account,
        OnboardingPath.login => _Step.login,
      };
    });
    if (path == OnboardingPath.invited && invite != null) {
      _useInviteProvider(invite);
    } else {
      _provider.start();
    }
  }

  void _back() {
    // Laufende Anmeldung im Browser bzw. Registrierung beenden; sonst endete sie unbemerkt im Hintergrund.
    _s.oauthRedirect?.cancel();
    _s.gateway.cancelRegistration();
    setState(() {
      switch (_step) {
        case _Step.account when _path == OnboardingPath.invited && _withLinkStep:
          _step = _Step.inviteLink;
        case _Step.inviteLink || _Step.account || _Step.login:
          _step = _Step.welcome;
        default:
          break;
      }
    });
  }

  List<_Step> get _plan => switch (_path) {
        OnboardingPath.create => const <_Step>[_Step.account, _Step.security, _Step.family],
        OnboardingPath.invited => <_Step>[if (_withLinkStep) _Step.inviteLink, _Step.account, _Step.security, _Step.family],
        OnboardingPath.login => const <_Step>[_Step.login, _Step.security, _Step.family],
      };

  /// Position im Weg; „Konto erstellen“ und „Anmelden“ teilen sich denselben Platz.
  int get _index {
    final plan = _plan;
    final slot = (_step == _Step.account || _step == _Step.login)
        ? plan.firstWhere((x) => x == _Step.account || x == _Step.login)
        : _step;
    final i = plan.indexOf(slot);
    return i < 0 ? 0 : i;
  }

  String _title(AppLocalizations l) => switch (_step) {
        _Step.welcome => l.onbTitleLanguage,
        _Step.inviteLink => l.inviteStepTitle,
        _Step.account => l.regTitle,
        _Step.login => l.onbTitleAccount,
        _Step.security => _s.gateway.securityState == SecurityState.needsRestore ? l.keyRestoreTitle : l.keyTitle,
        _Step.family => _path == OnboardingPath.invited ? l.joinTitle : l.onbTitleFamily,
      };

  Future<void> _finish() async {
    _s.pendingInvite.value = null;
    await _s.settings.update((c) => c.copyWith(onboardingDone: true, pendingInvite: null));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canGoBack = _step == _Step.inviteLink || _step == _Step.account || _step == _Step.login;
    return ListenableBuilder(
      listenable: _s.gateway,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_title(l)),
          leading: canGoBack ? BackButton(onPressed: _back) : null,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (_step != _Step.welcome) ...<Widget>[
                Semantics(
                  liveRegion: true,
                  child: Text(l.onbStep(_index + 1, _plan.length), style: Theme.of(context).textTheme.labelMedium),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: (_index + 1) / _plan.length),
                const SizedBox(height: 16),
              ],
              GlassCard(child: _buildStep(l)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l) {
    switch (_step) {
      case _Step.welcome:
        return WelcomeStep(onChoose: _choose);
      case _Step.inviteLink:
        return const InviteLinkStep();
      case _Step.account:
        return AccountCreateStep(
          key: const ValueKey<String>('create'),
          provider: _provider,
          onLogin: (user) => setState(() {
            _loginUsername = user;
            _step = _Step.login;
          }),
        );
      case _Step.login:
        return LoginStep(
          key: const ValueKey<String>('login'),
          provider: _provider,
          initialUsername: _loginUsername,
          onCreate: () => setState(() => _step = _Step.account),
        );
      case _Step.security:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          SecurityPanel(onReady: () => setState(() => _step = _Step.family)),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () => _s.gateway.logout(), child: Text(l.onbChangeAccount)),
          ),
        ]);
      case _Step.family:
        return FamilyStep(
          mode: switch (_path) {
            OnboardingPath.create => FamilyStepMode.create,
            OnboardingPath.invited => FamilyStepMode.join,
            OnboardingPath.login => FamilyStepMode.choice,
          },
          onFamilyReady: _finish,
        );
    }
  }
}
