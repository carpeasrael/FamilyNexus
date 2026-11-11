part of '../account_create_step.dart';

/// Wartet auf die Rückkehr aus der Browser-Anmeldung (OAuth, E-55).
class _BrowserWaiting extends StatelessWidget {
  const _BrowserWaiting({required this.host, required this.onCancel});
  final String host;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Row(children: <Widget>[
        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Semantics(liveRegion: true, child: Text(l.oauthWaiting(host)))),
      ]),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: onCancel, child: Text(l.cancel)),
      ),
    ]);
  }
}

/// Konto auf der Seite des Anbieters anlegen (OAuth): Name und Schaltfläche.
class _OAuthCreate extends StatelessWidget {
  const _OAuthCreate({required this.host, required this.nameField, required this.busy, required this.onCreate});
  final String host;
  final Widget nameField;
  final bool busy;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.regOAuthIntro(host)),
      const SizedBox(height: 12),
      nameField,
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          icon: const Icon(Icons.open_in_new, size: 18),
          onPressed: busy ? null : onCreate,
          label: Text(l.regOAuthCreate(host)),
        ),
      ),
    ]);
  }
}

/// Anbieter ohne Kontoanlage in der App: Webseite öffnen, Element starten oder anmelden.
class _ExternalCreate extends StatelessWidget {
  const _ExternalCreate({
    required this.host,
    required this.elementMissing,
    required this.onOpenPage,
    required this.onOpenElement,
    required this.onLogin,
    required this.onDownload,
  });
  final String host;
  final bool elementMissing;

  /// `null`, wenn der Anbieter keine Webseite nennt.
  final VoidCallback? onOpenPage;
  final VoidCallback onOpenElement;
  final VoidCallback onLogin;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Text(l.regExternalBody(host)),
      const SizedBox(height: 12),
      Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: <Widget>[
        if (onOpenPage != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: onOpenPage,
            label: Text(l.regExternalOpen),
          ),
        OutlinedButton(onPressed: onOpenElement, child: Text(l.regElementOpen)),
        FilledButton(onPressed: onLogin, child: Text(l.regExternalLogin)),
      ]),
      if (elementMissing) ...<Widget>[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(l.regElementMissing(host))),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: onDownload, child: Text(l.regElementDownload)),
        ),
      ],
    ]);
  }
}

/// Benutzername mit Prüfergebnis und Vorschlag.
class _UsernameFields extends StatelessWidget {
  const _UsernameFields({
    required this.controller,
    required this.focusNode,
    required this.check,
    required this.suggestion,
    required this.inputError,
    required this.onChanged,
    required this.onUseSuggestion,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final UsernameCheck? check;
  final String? suggestion;
  final String? inputError;
  final ValueChanged<String> onChanged;
  final VoidCallback onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final suggestion = this.suggestion;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      TextField(
        controller: controller,
        focusNode: focusNode,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: l.regUsernameLabel,
          // Die Hinweise sind lang (Zeichenregeln, Vorschlag bei vergebenem Namen): mehrzeilig, sonst
          // bricht Flutter nach einer Zeile mit „…“ ab (Issue #44).
          helperMaxLines: 3,
          errorMaxLines: 3,
          helperText: switch (check) {
            UsernameCheck.available => l.regUsernameFree,
            null || UsernameCheck.unknown => l.regUsernameHint,
            _ => null,
          },
          errorText: inputError ?? switch (check) {
            UsernameCheck.taken => suggestion == null ? l.regUsernameTaken : l.regUsernameTakenSuggest(suggestion),
            UsernameCheck.invalid => l.regUsernameInvalid,
            _ => null,
          },
          suffixIcon: check == UsernameCheck.available
              ? Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary)
              : null,
        ),
      ),
      if (suggestion != null)
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(label: Text(l.regUseSuggestion(suggestion)), onPressed: onUseSuggestion),
        ),
    ]);
  }
}

/// Passwort und Wiederholung.
class _PasswordFields extends StatelessWidget {
  const _PasswordFields({
    required this.password,
    required this.passwordFocus,
    required this.repeat,
    required this.repeatFocus,
    required this.show,
    required this.passwordError,
    required this.repeatError,
    required this.onChanged,
    required this.onToggleShow,
    required this.onSubmit,
  });
  final TextEditingController password;
  final FocusNode passwordFocus;
  final TextEditingController repeat;
  final FocusNode repeatFocus;
  final bool show;
  final String? passwordError;
  final String? repeatError;
  final VoidCallback onChanged;
  final VoidCallback onToggleShow;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      TextField(
        controller: password,
        focusNode: passwordFocus,
        obscureText: !show,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        textInputAction: TextInputAction.next,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => repeatFocus.requestFocus(),
        decoration: InputDecoration(
          labelText: l.accountPassword,
          helperText: l.regPasswordHint,
          helperMaxLines: 3,
          errorText: passwordError,
          errorMaxLines: 3,
          suffixIcon: IconButton(
            tooltip: show ? l.passwordHide : l.passwordShow,
            icon: Icon(show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: onToggleShow,
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: repeat,
        focusNode: repeatFocus,
        obscureText: !show,
        autocorrect: false,
        enableSuggestions: false,
        enableIMEPersonalizedLearning: false,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        textInputAction: TextInputAction.done,
        onChanged: (_) => onChanged(),
        onEditingComplete: () {},
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          labelText: l.accountPasswordRepeat,
          errorMaxLines: 3,
          // Ein passender Anfang ist noch kein Fehler; den Grund nennt dann erst Enter.
          errorText: repeatError ??
              (repeat.text.isNotEmpty && !password.text.startsWith(repeat.text) ? l.regPasswordMismatch : null),
        ),
      ),
    ]);
  }
}

/// „Konto erstellen“.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.busy, required this.enabled, required this.onSubmit});
  final bool busy;
  final bool enabled;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        // `_submit`, nicht `_register`: Ein Tipp im selben Frame wie Enter sieht noch den alten Knopf.
        onPressed: busy || !enabled ? null : onSubmit,
        child: Text(busy ? l.regCreating : l.regCreate),
      ),
    );
  }
}

/// Fehlerzeile unter dem Formular (Screenreader liest sie vor).
class _CreateError extends StatelessWidget {
  const _CreateError({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Semantics(
        liveRegion: true,
        child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}

/// „Ich habe schon ein Konto“.
class _HaveAccountButton extends StatelessWidget {
  const _HaveAccountButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(onPressed: onPressed, child: Text(l.startHaveAccount)),
    );
  }
}
