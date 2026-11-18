import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/invite_link.dart';
import '../../domain/security.dart';
import '../../domain/server.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../../ui/widgets/glass.dart';
import '../security/security_panel.dart';
import 'account_create_step.dart';
import 'family_step.dart';
import 'invite_link_step.dart';
import 'login_step.dart';
import 'provider_controller.dart';
import 'server_step.dart';
import 'welcome_step.dart';

enum _Step { welcome, server, inviteLink, account, login, security, family }

/// Ersteinrichtung (E-55, E-56, E-108): drei Wege ohne Fachbegriffe, danach (ohne Einladung) die Wahl des Anbieters.
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

  /// Der Schritt „Anbieter wählen“ gehört zum Weg (E-108): nur Neu und Anmelden von der Startseite aus, ohne
  /// Einladung. Neustart, Abmeldung, angemeldeter Start und Einladung zählen weiter ohne ihn.
  bool _withServerStep = false;
  String? _loginUsername;
  bool _started = false;

  late final AppServices _s = AppScope.read(context);
  late final ProviderController _provider = ProviderController(gateway: _s.gateway, initial: _s.defaultProvider);

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

  /// Konto anlegen und Anmelden laufen beim Server aus der Einladung (E-63): `matrix.org` als Standard,
  /// sonst eingetragen unter „Anderer Anbieter“.
  void _useInviteProvider(InviteLink invite) {
    final url = ServerUrl.tryParse(invite.accountServer);
    // Nicht lesbarer Servername: beim bisherigen Anbieter bleiben (sonst stünde „Verbinde …“ für immer).
    // Server im Heimnetz: erst nach Zustimmung verbinden (Review R2).
    url != null ? _provider.useServer(url, askFirst: InviteLink.isLocalServer(invite.accountServer)) : _provider.start();
  }

  /// Angemeldet (Konto erstellt oder Anmeldung): weiter zur Absicherung; abgemeldet: zurück.
  void _onGateway() {
    if (!mounted) return;
    final loggedIn = _s.gateway.session == SessionState.ready;
    // Angemeldet in einem Schritt vor der Absicherung (auch nach „Zurück“ während der Browser-Anmeldung).
    if (loggedIn && (_step == _Step.welcome || _step == _Step.server || _step == _Step.inviteLink || _step == _Step.account || _step == _Step.login)) {
      setState(() => _step = _s.gateway.securityState == SecurityState.ready ? _Step.family : _Step.security);
    } else if (!loggedIn && (_step == _Step.security || _step == _Step.family)) {
      setState(() {
        _path = OnboardingPath.login;
        _withServerStep = false;
        _step = _Step.login;
      });
      _provider.start();
    }
  }

  /// Einladung kam während der Einrichtung an (Deep Link/QR): Neulinge landen direkt bei „Konto erstellen“.
  void _onInvite() {
    final invite = _s.pendingInvite.value;
    if (!mounted || invite == null) return;
    if (_step == _Step.server && _path == OnboardingPath.login) {
      // Wer sich anmelden will, meldet sich beim Server aus der Einladung an (wie im Schritt „Anmelden“).
      setState(() {
        _withServerStep = false;
        _step = _Step.login;
      });
      _useInviteProvider(invite);
    } else if (_step == _Step.welcome || _step == _Step.inviteLink || _step == _Step.server) {
      setState(() {
        _path = OnboardingPath.invited;
        _withServerStep = false;
        _step = _Step.account;
      });
      _useInviteProvider(invite);
    } else if (_step == _Step.login) {
      // Wer sich schon anmeldet, meldet sich beim Server aus der Einladung an; die Familie folgt am Ende.
      setState(() => _withServerStep = false);
      _useInviteProvider(invite);
    }
  }

  /// Vorgemerkten Einladungslink verwerfen: Wer zur Startseite zurückgeht oder „Neue Familie gründen“ wählt,
  /// will ihn nicht mehr; sonst überschreibt er nach einem Neustart den Anbieter und den Familienschritt (#103).
  void _discardInvite() {
    if (_s.pendingInvite.value == null && _s.settings.settings.pendingInvite == null) return;
    _s.pendingInvite.value = null;
    _s.settings.update((c) => c.copyWith(pendingInvite: null)).ignore();
  }

  void _choose(OnboardingPath path) {
    if (path == OnboardingPath.create) _discardInvite();
    final invite = _s.pendingInvite.value;
    // Mit dem Schritt „Anbieter wählen“ beginnen Neu und Anmelden, solange keine Einladung den Server vorgibt.
    final withServer = invite == null && path != OnboardingPath.invited;
    setState(() {
      _path = path;
      _withLinkStep = path == OnboardingPath.invited && invite == null;
      _withServerStep = withServer;
      _step = switch (path) {
        _ when withServer => _Step.server,
        OnboardingPath.create => _Step.account,
        OnboardingPath.invited => invite == null ? _Step.inviteLink : _Step.account,
        OnboardingPath.login => _Step.login,
      };
    });
    if (path != OnboardingPath.create && invite != null) {
      _useInviteProvider(invite);
    } else {
      // Kein Einladungs-Server: zurück auf den Standard, sonst bliebe der Server einer verworfenen Einladung oder
      // früheren Eingabe gewählt (ein Heimnetz-Server würde ohne Zustimmung geprüft, R2); danach genau eine Prüfung.
      _provider.resetToStandard();
      _provider.start();
    }
  }

  void _back() {
    // Laufende Anmeldung im Browser bzw. Registrierung beenden; sonst endete sie unbemerkt im Hintergrund.
    _s.oauthRedirect?.cancel();
    _s.gateway.cancelRegistration();
    setState(() {
      switch (_step) {
        case _Step.account || _Step.login when _withServerStep && _s.pendingInvite.value == null:
          _step = _Step.server;
        case _Step.account when _path == OnboardingPath.invited && _withLinkStep:
          _step = _Step.inviteLink;
        case _Step.server || _Step.inviteLink || _Step.account || _Step.login:
          _withServerStep = false;
          _step = _Step.welcome;
          _discardInvite();
        default:
          break;
      }
    });
  }

  List<_Step> get _plan => switch (_path) {
        OnboardingPath.create => <_Step>[if (_withServerStep) _Step.server, _Step.account, _Step.security, _Step.family],
        OnboardingPath.invited => <_Step>[if (_withLinkStep) _Step.inviteLink, _Step.account, _Step.security, _Step.family],
        OnboardingPath.login => <_Step>[if (_withServerStep) _Step.server, _Step.login, _Step.security, _Step.family],
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
        _Step.server => l.serverStepTitle,
        _Step.inviteLink => l.inviteStepTitle,
        _Step.account => l.regTitle,
        _Step.login => l.onbTitleAccount,
        _Step.security => _s.gateway.securityState == SecurityState.needsRestore ? l.keyRestoreTitle : l.keyTitle,
        _Step.family => _path == OnboardingPath.invited ? l.joinTitle : l.onbTitleFamily,
      };

  Future<void> _finish() async {
    _s.pendingInvite.value = null;
    final saved = await _s.settings.update((c) => c.copyWith(onboardingDone: true, pendingInvite: null));
    // Ohne gespeichertes Ende bliebe die Einrichtung stehen: Der Familienschritt zeigt den Fehler und bietet einen neuen
    // Versuch an (#411).
    if (!saved) throw const SetupSaveException();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final canGoBack = _step == _Step.server || _step == _Step.inviteLink || _step == _Step.account || _step == _Step.login;
    return ListenableBuilder(
      listenable: _s.gateway,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(_title(l)),
          leading: canGoBack ? BackButton(onPressed: _back) : null,
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: ContentWidth(child: ListView(
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
          )),
        ),
      ),
    );
  }

  Widget _buildStep(AppLocalizations l) {
    switch (_step) {
      case _Step.welcome:
        return WelcomeStep(onChoose: _choose);
      case _Step.server:
        return ServerStep(
          key: const ValueKey<String>('server'),
          provider: _provider,
          onContinue: () => setState(() => _step = _path == OnboardingPath.login ? _Step.login : _Step.account),
        );
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
