import 'package:family_nexus/domain/registration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const d = RegistrationFlows.dummy;
  const t = RegistrationFlows.terms;
  const e = RegistrationFlows.email;
  const c = RegistrationFlows.recaptcha;
  const k = RegistrationFlows.token;

  test('wählt den einfachsten vollständig unterstützten Ablauf', () {
    expect(RegistrationFlows.choose(<List<String>>[<String>[c, t, e], <String>[c, t]], const <String>{}), <String>[c, t]);
    expect(RegistrationFlows.choose(<List<String>>[<String>[e], <String>[d]], const <String>{}), <String>[d]);
  });

  test('Abläufe mit nicht unterstützten Schritten (Telefon, SSO) fallen weg', () {
    expect(RegistrationFlows.choose(<List<String>>[<String>['m.login.msisdn'], <String>[t, e]], const <String>{}), <String>[t, e]);
    expect(RegistrationFlows.anySupported(<List<String>>[<String>['m.login.msisdn'], <String>['m.login.sso']]), isFalse);
    expect(RegistrationFlows.anySupported(const <List<String>>[]), isFalse);
  });


  test('Aufwand: Code (2) ist günstiger als Bedingungen + Captcha (4)', () {
    final flows = <List<String>>[<String>[t, c], <String>[k, d]];
    expect(RegistrationFlows.next(flows, const <String>{}), k);
    expect(RegistrationFlows.next(flows, const <String>{k}), d);
    expect(RegistrationFlows.next(flows, const <String>{t}), c, reason: 'begonnener Ablauf wird fortgesetzt');
    expect(RegistrationFlows.next(<List<String>>[<String>[t]], const <String>{t}), isNull);
  });

  test('TP-REG-05 Bedingungen: bevorzugte Sprache, nur https, Namen bereinigt', () {
    final params = <String, Object?>{
      'policies': <String, Object?>{
        'privacy': <String, Object?>{
          'version': '1',
          'en': <String, Object?>{'name': 'Privacy', 'url': 'https://hs.example/privacy-en'},
          'de': <String, Object?>{'name': 'Datenschutz\u202E', 'url': 'https://hs.example/privacy-de'},
        },
        'terms': <String, Object?>{
          'version': '2',
          'en': <String, Object?>{'name': 'Terms', 'url': 'http://hs.example/terms'},
        },
        'evil': <String, Object?>{
          'en': <String, Object?>{'name': 'X', 'url': 'javascript:alert(1)'},
        },
      },
    };
    final de = RegistrationFlows.termsFrom(params, language: 'de');
    expect(de, hasLength(1), reason: 'http und javascript verworfen');
    expect(de.single.name, 'Datenschutz');
    expect(de.single.url.toString(), 'https://hs.example/privacy-de');
    expect(RegistrationFlows.termsFrom(params, language: 'fr').single.name, 'Privacy');
    expect(RegistrationFlows.termsFrom('Müll'), isEmpty);
  });

  test('E-Mail-Plausibilität', () {
    expect(isPlausibleEmail('anna@beispiel.de'), isTrue);
    expect(isPlausibleEmail(' anna@beispiel.de '), isTrue);
    expect(isPlausibleEmail('anna@beispiel'), isFalse);
    expect(isPlausibleEmail('anna beispiel.de'), isFalse);
    expect(isPlausibleEmail('@beispiel.de'), isFalse);
  });
}
