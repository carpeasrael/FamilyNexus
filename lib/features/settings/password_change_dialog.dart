import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_services.dart';
import '../../data/matrix/matrix_gateway.dart';
import '../../domain/password_change.dart';
import '../../l10n/gen/app_localizations.dart';
import '../common/error_text.dart';

/// Passwort ändern (#117, E-80): klassisch in der App, bei Anmeldung im Browser über die Kontoseite
/// des Anbieters. Geht beides nicht, sagt der Dialog das.
Future<void> changePassword(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final services = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final PasswordChange how;
  try {
    how = await services.gateway.passwordChange();
  } on GatewayException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(l, e))));
    return;
  }
  if (!context.mounted) return;
  await showDialog<void>(context: context, builder: (_) => PasswordChangeDialog(how: how));
}

/// Feld, zu dem ein Fehler gehört und das danach den Fokus bekommt.
enum _Field { current, next, repeat }

class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key, required this.how});
  final PasswordChange how;

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _repeat = TextEditingController();
  final FocusNode _currentFocus = FocusNode();
  final FocusNode _nextFocus = FocusNode();
  final FocusNode _repeatFocus = FocusNode();
  final FocusNode _closeFocus = FocusNode();
  final GlobalKey _errorKey = GlobalKey();
  bool _showPassword = false;
  bool _logoutOthers = false;
  bool _busy = false;

  /// Der Server hat die Änderung erst nach dem Absenden abgelehnt.
  bool _rejected = false;
  String? _error;
  _Field? _errorField;

  @override
  void dispose() {
    _clearPasswords();
    _current.dispose();
    _next.dispose();
    _repeat.dispose();
    _currentFocus.dispose();
    _nextFocus.dispose();
    _repeatFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  void _clearPasswords() {
    _current.clear();
    _next.clear();
    _repeat.clear();
  }

  void _onInput(String _) => setState(() {
        _error = null;
        _errorField = null;
      });

  (TextEditingController, FocusNode) _partsOf(_Field field) => switch (field) {
        _Field.current => (_current, _currentFocus),
        _Field.next => (_next, _nextFocus),
        _Field.repeat => (_repeat, _repeatFocus),
      };

  /// Warum sich das Formular nicht absenden lässt; `null`, wenn alles passt.
  (String, _Field)? _invalid(AppLocalizations l) {
    if (_current.text.isEmpty) return (l.passwordChangeCurrentMissing, _Field.current);
    if (_next.text.length < PasswordChange.minLength) return (l.regPasswordTooShort, _Field.next);
    if (_next.text.length > PasswordChange.maxLength) return (l.passwordChangeTooLong, _Field.next);
    if (_next.text == _current.text) return (l.passwordChangeSame, _Field.next);
    if (_repeat.text != _next.text) return (l.regPasswordMismatch, _Field.repeat);
    return null;
  }

  /// Der Grund steht in der Live-Zeile und am Feld: Das Vorlesen des fokussierten Feldes kann die
  /// Live-Region verdrängen, `errorText` wird mit dem Feld mitgelesen.
  void _showError(String text, _Field field, {bool select = false}) {
    final (controller, focus) = _partsOf(field);
    if (select) controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    setState(() {
      _error = text;
      _errorField = field;
    });
    focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final line = _errorKey.currentContext;
      if (line != null && line.mounted) Scrollable.ensureVisible(line);
    });
  }

  void _onFailure(AppLocalizations l, GatewayException e) {
    switch (e.error) {
      case GatewayError.passwordChangeUnavailable:
        _clearPasswords();
        setState(() {
          _rejected = true;
          _error = null;
          _errorField = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _closeFocus.requestFocus();
        });
      case GatewayError.invalidCredentials:
        _showError(l.passwordChangeWrongCurrent, _Field.current, select: true);
      case GatewayError.weakPassword:
        _showError(errorText(l, e), _Field.next, select: true);
      case GatewayError.serverUnreachable:
        // `.timeout` bricht den Aufruf nicht ab: Das neue Passwort kann schon gelten.
        _showError(l.passwordChangeUncertain, _Field.repeat);
      default:
        _showError(errorText(l, e), _Field.repeat);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l = AppLocalizations.of(context);
    final invalid = _invalid(l);
    if (invalid != null) {
      _showError(invalid.$1, invalid.$2);
      return;
    }
    final s = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });
    try {
      await s.gateway.changePassword(oldPassword: _current.text, newPassword: _next.text, logoutOtherDevices: _logoutOthers);
    } on GatewayException catch (e) {
      if (mounted) _onFailure(l, e);
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    // Vor dem Leeren: Ein Passwort-Manager speichert nur hier, mit den Feldinhalten.
    TextInput.finishAutofillContext();
    _clearPasswords();
    if (mounted) navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l.passwordChanged)));
  }

  Future<void> _openPage(Uri page) async {
    final l = AppLocalizations.of(context);
    final s = AppScope.read(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    final opened = await s.browser.open(page);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!opened) _error = l.accountDeleteNoBrowser;
    });
    if (opened) navigator.pop();
  }

  Widget _errorLine(ThemeData theme) => Padding(
        key: _errorKey,
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(liveRegion: true, child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
      );

  Widget _passwordField({
    required _Field field,
    required String label,
    required String autofillHint,
    required TextInputAction action,
    VoidCallback? onEditingComplete,
    required ValueChanged<String> onSubmitted,
    bool autofocus = false,
    String? helperText,
    String? mismatch,
    Widget? suffixIcon,
  }) {
    final (controller, focus) = _partsOf(field);
    return TextField(
      controller: controller,
      focusNode: focus,
      autofocus: autofocus,
      readOnly: _busy,
      obscureText: !_showPassword,
      autocorrect: false,
      enableSuggestions: false,
      enableIMEPersonalizedLearning: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      autofillHints: <String>[autofillHint],
      textInputAction: action,
      onChanged: _onInput,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 4,
        errorText: (_errorField == field ? _error : null) ?? mismatch,
        errorMaxLines: 3,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _form(AppLocalizations l, ThemeData theme) {
    final next = _next.text;
    final repeat = _repeat.text;
    return AutofillGroup(
      // Abbrechen darf nichts speichern; gespeichert wird nur nach Erfolg (siehe _submit).
      onDisposeAction: AutofillContextAction.cancel,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Text(l.passwordChangeHint),
        const SizedBox(height: 12),
        _passwordField(
          field: _Field.current,
          label: l.passwordChangeCurrent,
          autofillHint: AutofillHints.password,
          action: TextInputAction.next,
          autofocus: true,
          onSubmitted: (_) => _nextFocus.requestFocus(),
          suffixIcon: IconButton(
            tooltip: _showPassword ? l.passwordHide : l.passwordShow,
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: _busy ? null : () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        const SizedBox(height: 12),
        _passwordField(
          field: _Field.next,
          label: l.passwordChangeNew,
          autofillHint: AutofillHints.newPassword,
          action: TextInputAction.next,
          helperText: l.regPasswordHint,
          mismatch: next.isNotEmpty && next == _current.text ? l.passwordChangeSame : null,
          onSubmitted: (_) => _repeatFocus.requestFocus(),
        ),
        const SizedBox(height: 12),
        _passwordField(
          field: _Field.repeat,
          label: l.accountPasswordRepeat,
          autofillHint: AutofillHints.newPassword,
          action: TextInputAction.done,
          // Ein passender Anfang ist noch kein Fehler.
          mismatch: repeat.isNotEmpty && !next.startsWith(repeat) ? l.regPasswordMismatch : null,
          onEditingComplete: () {},
          onSubmitted: (_) => _submit(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.passwordChangeLogoutOthers),
          subtitle: Text(l.passwordChangeLogoutOthersHint),
          value: _logoutOthers,
          onChanged: _busy ? null : (v) => setState(() => _logoutOthers = v),
        ),
        if (_error != null) _errorLine(theme),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final how = widget.how;
    final unavailable = _rejected || how is PasswordChangeUnavailable;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l.passwordChangeTitle),
        content: SingleChildScrollView(
          child: _rejected
              ? Semantics(liveRegion: true, child: Text(l.passwordChangeUnavailable))
              : switch (how) {
                  PasswordChangeInApp() => _form(l, theme),
                  PasswordChangeInBrowser() => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                      Text(l.passwordChangeBrowserBody),
                      if (_error != null) _errorLine(theme),
                    ]),
                  PasswordChangeUnavailable() => Text(l.passwordChangeUnavailable),
                },
        ),
        actions: <Widget>[
          if (unavailable)
            TextButton(
              focusNode: _closeFocus,
              onPressed: () => Navigator.pop(context),
              // Außen um den Knopf erreicht der Hinweis dessen Semantik-Knoten nicht.
              child: _rejected ? Semantics(hint: l.passwordChangeUnavailable, child: Text(l.close)) : Text(l.close),
            )
          else
            // Während `_busy` aus: `Navigator.pop` umginge `PopScope`.
            TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: Text(l.cancel)),
          if (!unavailable)
            switch (how) {
              PasswordChangeInBrowser(:final page) => FilledButton(
                  onPressed: _busy ? null : () => _openPage(page),
                  child: Text(l.passwordChangeBrowserOpen),
                ),
              _ => FilledButton(
                  // Bleibt aktiv: Ein grauer Knopf sagt nicht, was fehlt. `_submit` nennt den Grund.
                  onPressed: _busy ? null : _submit,
                  child: _busy ? Semantics(liveRegion: true, child: Text(l.passwordChanging)) : Text(l.passwordChangeConfirm),
                ),
            },
        ],
      ),
    );
  }
}
