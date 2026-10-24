/// Kontoanlage in der App (E-55): Ergebnis der Namensprüfung, Art der Registrierung beim Anbieter
/// und die Zusatzschritte, die ein Server bei der klassischen Registrierung (UIA) verlangen kann.
///
/// Alle Angaben stammen vom Server und sind nicht vertrauenswürdig: Adressen werden nur mit https
/// übernommen, Texte bereinigt.
library;

import 'text_sanitizer.dart';

/// Ergebnis der Prüfung „Ist der Benutzername frei?“. `unknown` blockiert nicht (z. B. offline).
enum UsernameCheck { available, taken, invalid, unknown }

/// Wie bei einem Anbieter ein Konto angelegt wird.
enum RegistrationMode {
  /// Klassisch über `/register` direkt in der App (Benutzername + Passwort, ggf. Zusatzschritte).
  inApp,

  /// Über die Anmeldeseite des Anbieters im Browser (OAuth, z. B. matrix.org).
  oauth,

  /// Keine Registrierung über die App möglich (abgeschaltet oder nur mit nicht unterstützten Schritten).
  disabled,
}

class RegistrationOptions {
  const RegistrationOptions({required this.mode, this.webPage});

  final RegistrationMode mode;

  /// Webseite des Anbieters für die Kontoanlage außerhalb der App (nur https), falls bekannt.
  final Uri? webPage;
}

/// Eine vom Server verlangte Bedingung (Nutzungsbedingungen, Datenschutz).
class TermsPolicy {
  const TermsPolicy({required this.name, required this.url});
  final String name;
  final Uri url;
}

/// Ein Zusatzschritt der klassischen Registrierung, den die Person selbst erledigen muss.
sealed class RegistrationStage {
  const RegistrationStage();
}

/// Bedingungen lesen und zustimmen.
class TermsStage extends RegistrationStage {
  const TermsStage(this.policies);
  final List<TermsPolicy> policies;
}

/// E-Mail-Adresse angeben und den Bestätigungslink öffnen. [sent]: Mail wurde verschickt.
class EmailStage extends RegistrationStage {
  const EmailStage({this.sent = false, this.notConfirmedYet = false});
  final bool sent;

  /// Die Person hat „bestätigt“ gemeldet, der Server sieht aber noch keine Bestätigung.
  final bool notConfirmedYet;
}

/// Einladungscode des Anbieters eingeben. [wrong]: der letzte Code passte nicht.
class TokenStage extends RegistrationStage {
  const TokenStage({this.wrong = false});
  final bool wrong;
}

/// „Ich bin kein Roboter“ im Browser bestätigen ([page] ist die Seite des Servers).
class CaptchaStage extends RegistrationStage {
  const CaptchaStage(this.page, {this.notDoneYet = false});
  final Uri page;
  final bool notDoneYet;
}

/// Antwort der Person auf einen [RegistrationStage].
sealed class RegistrationInput {
  const RegistrationInput();
}

class AcceptTerms extends RegistrationInput {
  const AcceptTerms();
}

class SubmitEmail extends RegistrationInput {
  const SubmitEmail(this.email);
  final String email;
}

class EmailConfirmed extends RegistrationInput {
  const EmailConfirmed();
}

class SubmitToken extends RegistrationInput {
  const SubmitToken(this.token);
  final String token;
}

class CaptchaDone extends RegistrationInput {
  const CaptchaDone();
}

/// Auswahl des Registrierungswegs aus den vom Server angebotenen Abläufen (UIA-„flows“).
class RegistrationFlows {
  const RegistrationFlows._();

  static const String dummy = 'm.login.dummy';
  static const String terms = 'm.login.terms';
  static const String email = 'm.login.email.identity';
  static const String token = 'm.login.registration_token';
  static const String recaptcha = 'm.login.recaptcha';

  /// Schritte, die die App beherrscht. Telefonnummer (msisdn) und SSO gehören bewusst nicht dazu.
  static const Set<String> supported = <String>{dummy, terms, email, token, recaptcha};

  /// Bevorzugt den kürzesten vollständig unterstützten Ablauf, der zu den bereits erledigten
  /// Schritten passt; `null`, wenn keiner passt.
  static List<String>? choose(List<List<String>> flows, Set<String> completed) {
    final usable = <List<String>>[
      for (final f in flows)
        if (f.isNotEmpty && f.every(supported.contains) && _startsWith(f, completed)) f,
    ]..sort((a, b) => _cost(a).compareTo(_cost(b)));
    return usable.isEmpty ? null : usable.first;
  }

  /// Nächster offener Schritt des gewählten Ablaufs oder `null`, wenn alle erledigt sind.
  static String? next(List<List<String>> flows, Set<String> completed) {
    final f = choose(flows, completed);
    if (f == null) return null;
    for (final s in f) {
      if (!completed.contains(s)) return s;
    }
    return null;
  }

  /// `true`, wenn mindestens ein Ablauf vollständig unterstützt wird.
  static bool anySupported(List<List<String>> flows) => choose(flows, const <String>{}) != null;

  static bool _startsWith(List<String> flow, Set<String> completed) => completed.every(flow.contains);

  /// Aufwand für die Person: Captcha und E-Mail wiegen schwerer als ein Häkchen.
  static int _cost(List<String> flow) => flow.fold<int>(0, (a, s) => a + switch (s) {
        dummy => 0,
        terms => 1,
        token => 2,
        recaptcha => 3,
        email => 4,
        _ => 10,
      });

  /// Liest die Bedingungen aus den Parametern der Stufe `m.login.terms`. Bevorzugt [language],
  /// dann Englisch, dann die erste Sprache. Nur https-Adressen werden übernommen.
  static List<TermsPolicy> termsFrom(Object? params, {String language = 'de'}) {
    if (params is! Map<String, Object?>) return const <TermsPolicy>[];
    final policies = params['policies'];
    if (policies is! Map<String, Object?>) return const <TermsPolicy>[];
    final out = <TermsPolicy>[];
    for (final p in policies.values.take(10)) {
      if (p is! Map<String, Object?>) continue;
      final langs = <String, Map<String, Object?>>{
        for (final e in p.entries)
          if (e.value is Map<String, Object?>) e.key: e.value! as Map<String, Object?>,
      };
      final entry = langs[language] ?? langs['en'] ?? (langs.isEmpty ? null : langs.values.first);
      if (entry == null) continue;
      final url = entry['url'];
      final name = entry['name'];
      final uri = url is String && url.length <= 500 ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) continue;
      final cleanName = TextSanitizer.clean(name is String ? name : '', max: 80);
      out.add(TermsPolicy(name: cleanName.isEmpty ? uri.host : cleanName, url: uri));
    }
    return out;
  }
}

/// Grobe Prüfung einer E-Mail-Adresse vor dem Versand (die eigentliche Prüfung macht der Server).
bool isPlausibleEmail(String s) {
  final t = s.trim();
  return t.length <= 254 && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t);
}
