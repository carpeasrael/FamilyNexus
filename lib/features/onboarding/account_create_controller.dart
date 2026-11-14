import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_log.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/registration.dart';
import '../../domain/server.dart';
import '../../domain/username_suggestion.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';
import 'provider_controller.dart';

/// Formularstelle, zu der ein Eingabegrund gehört; `provider` hat kein Feld.
enum AccountField { provider, name, user, pass, repeat }

/// Zustand und Aktionen von „Konto erstellen“ (AP-6a, E-55): Formularwerte, Prüfung des Benutzernamens, Registrierung in
/// der App mit Folgeschritten, Anlage auf der Seite des Anbieters (OAuth) und der Ausweg über Element. Abhängigkeiten
/// kommen über den Konstruktor; Fokusknoten, Texte und Ansichten bleiben in der Oberfläche. Fehler werden erst beim
/// Anzeigen in Text aufgelöst ([errorLine]), damit der Controller keinen `BuildContext` braucht.
class AccountCreateController extends ChangeNotifier {
  AccountCreateController({
    required this.gateway,
    required this.provider,
    required this.signInInBrowser,
    required this.cancelBrowserSignIn,
    required this.launchElement,
    this.requestFocus,
    this.checkDelay = const Duration(milliseconds: 600),
  }) {
    provider.addListener(_onProvider);
  }

  final MatrixGateway gateway;
  final ProviderController provider;

  /// Legt das Konto auf der Seite des Anbieters an und wartet auf den Rücksprung (OAuth).
  final Future<void> Function(ServerUrl server) signInInBrowser;

  /// Bricht eine laufende Browser-Anmeldung ab.
  final VoidCallback cancelBrowserSignIn;

  /// Startet Element; `false`, wenn es nicht installiert ist.
  final Future<bool> Function() launchElement;

  /// Setzt den Fokus auf das Feld [AccountField], zu dem ein Eingabegrund gehört.
  final void Function(AccountField field)? requestFocus;

  /// Pause nach der letzten Eingabe, bevor der Benutzername beim Server geprüft wird.
  final Duration checkDelay;

  final TextEditingController name = TextEditingController();
  final TextEditingController user = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController passwordRepeat = TextEditingController();

  bool _userEdited = false;
  bool _showPassword = false;
  bool _busy = false;
  bool _waitingForBrowser = false;
  bool _elementMissing = false;
  bool _disposed = false;
  ({String Function(AppLocalizations l) text, bool notice})? _error;

  /// Warum Enter nicht abgeschickt hat. Getrennt von [_error]: Eingaben löschen nur diesen Grund, Serverfehler bleiben
  /// bis zum nächsten Absenden stehen.
  String? _inputError;
  AccountField? _inputField;
  RegistrationStage? _stage;

  UsernameCheck? _check;
  String? _suggestion;
  Timer? _checkTimer;
  int _checkRun = 0;
  ServerUrl? _checkedServer;

  bool get busy => _busy;
  bool get showPassword => _showPassword;
  bool get waitingForBrowser => _waitingForBrowser;
  bool get elementMissing => _elementMissing;
  RegistrationStage? get stage => _stage;
  UsernameCheck? get check => _check;
  String? get suggestion => _suggestion;

  /// Der Text der Fehlerzeile: Grund der Verweigerung vor dem Serverfehler; `null` ohne beides.
  String? errorLine(AppLocalizations l) => _inputError ?? _error?.text(l);

  /// Die Fehlerzeile ist ein Hinweis (Vorgang beim Anbieter nicht abgeschlossen), kein Fehler (#430). Ein Eingabegrund hat
  /// Vorrang und ist nie ein Hinweis.
  bool get errorIsNotice => _inputError == null && (_error?.notice ?? false);

  /// Der Eingabegrund, wenn er zu [field] gehört.
  String? errorAt(AccountField field) => _inputField == field ? _inputError : null;

  bool get formOk =>
      provider.ready &&
      name.text.trim().isNotEmpty &&
      UsernameSuggestion.isValid(user.text.trim()) &&
      _check != UsernameCheck.taken &&
      _check != UsernameCheck.invalid &&
      password.text.length >= 8 &&
      password.text == passwordRepeat.text;

  void _update(void Function() change) {
    change();
    if (!_disposed) notifyListeners();
  }

  /// Anderer Anbieter: „frei/vergeben“ galt für den alten und wird neu geprüft.
  void _onProvider() {
    if (_disposed) return;
    if (provider.ready && provider.server != _checkedServer && user.text.trim().isNotEmpty) _scheduleCheck();
    if (provider.ready && _inputField == AccountField.provider) clearInputError();
  }

  /// Löscht den Eingabegrund (nicht den Serverfehler) und meldet die Änderung.
  void clearInputError() => _update(_dropInputError);

  void _dropInputError() {
    _inputError = null;
    _inputField = null;
  }

  void onName(String v) {
    _dropInputError();
    if (!_userEdited) {
      user.text = UsernameSuggestion.fromName(v);
      _scheduleCheck();
    }
    if (!_disposed) notifyListeners();
  }

  void onUser(String v) {
    _dropInputError();
    _userEdited = v.isNotEmpty;
    _scheduleCheck();
  }

  void toggleShowPassword() => _update(() => _showPassword = !_showPassword);

  void _scheduleCheck() {
    _checkTimer?.cancel();
    final run = ++_checkRun;
    _update(() {
      _check = null;
      _suggestion = null;
    });
    final candidate = user.text.trim();
    if (candidate.isEmpty) return;
    if (!UsernameSuggestion.isValid(candidate)) {
      _update(() => _check = UsernameCheck.invalid);
      return;
    }
    _checkTimer = Timer(checkDelay, () => _runCheck(candidate, run));
  }

  Future<void> _runCheck(String candidate, int run) async {
    final server = provider.server;
    if (server == null) return;
    _checkedServer = server;
    final result = await gateway.checkUsername(server, candidate);
    String? alt;
    if (result == UsernameCheck.taken) {
      for (final alternative in UsernameSuggestion.alternatives(candidate)) {
        if (await gateway.checkUsername(server, alternative) == UsernameCheck.available) {
          alt = alternative;
          break;
        }
      }
    }
    if (_disposed || run != _checkRun) return;
    _update(() {
      _check = result;
      _suggestion = alt;
    });
  }

  void useSuggestion() {
    final s = _suggestion;
    if (s == null) return;
    _dropInputError();
    user.text = s;
    _userEdited = true;
    _scheduleCheck();
  }

  Future<void> _run(Future<void> Function() op) async {
    _update(() {
      _busy = true;
      _error = null;
      _dropInputError();
    });
    try {
      await op();
    } catch (e) {
      if (_disposed) return;
      _update(() => _error = (text: (l) => errorText(l, e), notice: isNotice(e)));
      if (e is GatewayException && e.error == GatewayError.usernameTaken) _scheduleCheck();
    } finally {
      if (!_disposed) _update(() => _busy = false);
    }
  }

  /// Legt das Konto in der App an. [language] ist die Sprache der Oberfläche (für Bedingungen des Anbieters).
  Future<void> register(String language) => _run(() async {
        final server = provider.server;
        if (server == null || !provider.ready) return;
        final stage = await gateway.register(
          server: server,
          username: user.text.trim(),
          password: password.text,
          displayName: name.text,
          language: language,
        );
        if (stage == null) _clearPasswords();
        if (!_disposed) _update(() => _stage = stage);
      });

  void _clearPasswords() {
    password.clear();
    passwordRepeat.clear();
  }

  Future<void> continueRegistration(RegistrationInput input) => _run(() async {
        try {
          final stage = await gateway.continueRegistration(input);
          if (stage == null) _clearPasswords();
          if (!_disposed) _update(() => _stage = stage);
        } on GatewayException catch (e) {
          // Vorübergehend (Netz, Überlastung, Eingabe): Schritt bleibt, erneut versuchen möglich – das
          // Gateway behält die Registrierung genau in diesen Fällen. Sonst endgültig: zurück zum Formular
          // und Registrierung samt Passwort verwerfen.
          const keep = <GatewayError>{
            GatewayError.invalidInput,
            GatewayError.rateLimited,
            GatewayError.emailInUse,
            GatewayError.serverUnreachable,
          };
          if (!keep.contains(e.error)) {
            gateway.cancelRegistration();
            if (!_disposed) _update(() => _stage = null);
          }
          rethrow;
        }
      });

  void cancelStage() {
    gateway.cancelRegistration();
    _update(() {
      _stage = null;
      _error = null;
    });
  }

  Future<void> createInBrowser() => _run(() async {
        final server = provider.server;
        if (server == null) return;
        _update(() => _waitingForBrowser = true);
        try {
          await signInInBrowser(server);
        } finally {
          if (!_disposed) _update(() => _waitingForBrowser = false);
        }
        final displayName = name.text.trim();
        if (displayName.isNotEmpty) {
          try {
            await gateway.setDisplayName(displayName);
          } catch (e) {
            // Der Name lässt sich später in den Einstellungen des Anbieters ändern; kein Abbruch.
            AppLog.w('onboarding', 'Anzeigename nicht gesetzt (${e.runtimeType})');
          }
        }
      });

  /// Ausweg ohne Kontoanlage in der App: Element starten; fehlt es, Hinweis mit Download.
  Future<void> openElement() async {
    final started = await launchElement();
    if (!_disposed) _update(() => _elementMissing = !started);
  }

  /// Enter im letzten Feld und Knopf: absenden oder den ersten Grund nennen, der dagegen spricht.
  void submit(AppLocalizations l, String language) {
    if (_busy) return;
    if (formOk) {
      register(language);
      return;
    }
    final candidate = user.text.trim();
    if (!provider.ready) {
      _refuse(l.regProviderNotReady, AccountField.provider);
    } else if (name.text.trim().isEmpty) {
      _refuse(l.regNameMissing, AccountField.name);
    } else if (!UsernameSuggestion.isValid(candidate) || _check == UsernameCheck.invalid) {
      _refuse(l.regUsernameInvalid, AccountField.user);
    } else if (_check == UsernameCheck.taken) {
      _refuse(l.regUsernameTaken, AccountField.user);
    } else if (password.text.length < 8) {
      _refuse(l.regPasswordTooShort, AccountField.pass);
    } else {
      _refuse(l.regPasswordMismatch, AccountField.repeat);
    }
  }

  /// Der Grund steht in der Fehlerzeile und am Feld: Das Vorlesen des fokussierten Feldes kann die Live-Region
  /// verdrängen, `errorText` wird mit dem Feld mitgelesen.
  void _refuse(String text, AccountField field) {
    _update(() {
      _inputError = text;
      _inputField = field;
    });
    if (field != AccountField.provider) requestFocus?.call(field);
  }

  @override
  void dispose() {
    _disposed = true;
    provider.removeListener(_onProvider);
    _checkTimer?.cancel();
    name.dispose();
    user.dispose();
    password.dispose();
    passwordRepeat.dispose();
    // Nichts darf weiterlaufen, wenn der Schritt verlassen wird: Registrierung (samt Passwort) und
    // Browser-Anmeldung beenden.
    gateway.cancelRegistration();
    if (_waitingForBrowser) cancelBrowserSignIn();
    super.dispose();
  }
}
