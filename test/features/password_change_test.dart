import 'dart:async';

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/data/matrix/matrix_gateway.dart';
import 'package:family_nexus/domain/password_change.dart';
import 'package:family_nexus/domain/registration.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';
import '../support/fake_matrix.dart';
import '../support/nav.dart';
import '../support/test_app.dart';

const _current = 'Aktuelles Passwort';
const _new = 'Neues Passwort';
const _repeat = 'Passwort wiederholen';
const _old = 'geheim123';
const _unavailable = 'Dein Anbieter erlaubt keine Änderung des Passworts in der App.';
const _uncertain = 'Keine Antwort vom Server. Wiederhole den Versuch. Meldet die App dann, das aktuelle Passwort stimme nicht, gilt dein neues Passwort bereits.';

Finder _field(String label) => find.widgetWithText(TextField, label);
TextField _widget(WidgetTester tester, String label) => tester.widget<TextField>(_field(label));
String _text(WidgetTester tester, String label) => _widget(tester, label).controller!.text;
bool _focused(WidgetTester tester, String label) => _widget(tester, label).focusNode!.hasFocus;
Finder get _confirm => find.widgetWithText(FilledButton, 'Passwort ändern');

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _openDialog(WidgetTester tester) async {
  await openSettings(tester);
  await tester.ensureVisible(find.widgetWithText(ListTile, 'Passwort ändern'));
  await tester.tap(find.widgetWithText(ListTile, 'Passwort ändern'));
  await tester.pumpAndSettle();
}

Future<TestApp> _app(WidgetTester tester, {void Function(FakeMatrixServer server)? setUp}) async {
  _tall(tester);
  final app = await buildTestApp(lang: 'de');
  setUp?.call(app.server);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await _openDialog(tester);
  return app;
}

/// Anna meldet sich im Browser an (OAuth).
Future<TestApp> _oauthApp(WidgetTester tester) async {
  _tall(tester);
  final fake = FakeMatrixServer()..registrationMode = RegistrationMode.oauth;
  fake.addAccount('anna', 'oauth-only', displayName: 'Anna');
  final app = await buildTestApp(server: fake, loggedIn: false);
  await app.gateway.startOAuth(server: ServerUrl.tryParse(fake.host)!, redirectUri: FakeOAuthRedirect.redirect, create: false);
  await app.gateway.completeOAuth(app.gateway.oauthCallback('anna'));
  await app.gateway.setUpSecurity();
  await app.gateway.createFamily('Familie Test');
  await app.services.settings.update((s) => s.copyWith(onboardingDone: true));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await _openDialog(tester);
  return app;
}

Future<void> _fill(WidgetTester tester, {String current = _old, String next = 'neu-und-lang', String? repeat}) async {
  await tester.enterText(_field(_current), current);
  await tester.enterText(_field(_new), next);
  await tester.enterText(_field(_repeat), repeat ?? next);
  await tester.pumpAndSettle();
}

Future<void> _pressEnter(WidgetTester tester) async {
  await tester.showKeyboard(_field(_repeat));
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _pressConfirm(WidgetTester tester) async {
  await tester.tap(_confirm);
  await tester.pumpAndSettle();
}

/// Grund in der Live-Zeile, am Feld, in dessen Semantik; Fokus auf dem Feld.
Future<void> _expectReason(WidgetTester tester, String text, {required String at}) async {
  final semantics = tester.ensureSemantics();
  await tester.pump();
  final live = find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false));
  expect(find.descendant(of: live, matching: find.text(text)), findsOneWidget, reason: 'Live-Zeile');
  expect(find.descendant(of: _field(at), matching: find.text(text)), findsOneWidget, reason: 'errorText am Feld');
  expect(tester.getSemantics(find.descendant(of: _field(at), matching: find.byType(EditableText))).hint, contains(text));
  expect(_focused(tester, at), isTrue, reason: 'Fokus auf „$at“');
  semantics.dispose();
}

void main() {
  group('Passwort ändern (#117)', () {
    testWidgets('TP-PW-01 Einstellungen → Konto: Eintrag vor „Abmelden“, Felder verdeckt und ohne Tastatur-Lernen', (tester) async {
      await _app(tester);
      for (final label in <String>[_current, _new, _repeat]) {
        final f = _widget(tester, label);
        expect(f.obscureText, isTrue, reason: label);
        expect(f.autocorrect, isFalse, reason: label);
        expect(f.enableSuggestions, isFalse, reason: label);
        expect(f.enableIMEPersonalizedLearning, isFalse, reason: label);
        expect(f.smartDashesType, SmartDashesType.disabled, reason: label);
        expect(f.smartQuotesType, SmartQuotesType.disabled, reason: label);
      }
      expect(_widget(tester, _current).autofillHints, <String>[AutofillHints.password]);
      expect(_widget(tester, _new).autofillHints, <String>[AutofillHints.newPassword]);
      expect(_widget(tester, _repeat).autofillHints, <String>[AutofillHints.newPassword]);
      expect(_widget(tester, _current).autofocus, isTrue);
      expect(_focused(tester, _current), isTrue);
      expect(find.byTooltip('Passwort anzeigen'), findsOneWidget);
      await tester.tap(find.byTooltip('Passwort anzeigen'));
      await tester.pumpAndSettle();
      expect(_widget(tester, _current).obscureText, isFalse);
      expect(_widget(tester, _new).obscureText, isFalse);
      expect(_widget(tester, _repeat).obscureText, isFalse);
      final other = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Andere Geräte abmelden'));
      expect(other.value, isFalse, reason: 'Standard: andere Geräte bleiben angemeldet (E-80)');
      expect(tester.widget<FilledButton>(_confirm).onPressed, isNotNull, reason: 'nie ein grauer Knopf ohne Grund');
    });

    testWidgets('TP-PW-02 Enter springt von Feld zu Feld und sendet im letzten', (tester) async {
      final app = await _app(tester);
      await tester.enterText(_field(_current), _old);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_focused(tester, _new), isTrue);
      await tester.enterText(_field(_new), 'neu-und-lang');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_focused(tester, _repeat), isTrue);
      expect(app.server.passwordChangeCalls, 0);
      await tester.enterText(_field(_repeat), 'neu-und-lang');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(app.server.passwordOf('@anna:fake.test'), 'neu-und-lang');
    });

    for (final (name, press) in <(String, Future<void> Function(WidgetTester))>[('Knopf', _pressConfirm), ('Enter', _pressEnter)]) {
      group('TP-PW-03 Prüfung vor dem Absenden über $name', () {
        Future<void> check(WidgetTester tester, String reason, String at, {String current = _old, String next = 'neu-und-lang', String? repeat}) async {
          final app = await _app(tester);
          await _fill(tester, current: current, next: next, repeat: repeat);
          await press(tester);
          await _expectReason(tester, reason, at: at);
          expect(app.server.passwordChangeCalls, 0);
          await tester.enterText(_field(at), at == _current ? 'x' : 'neu');
          await tester.pumpAndSettle();
          final live = find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false));
          expect(find.descendant(of: live, matching: find.text(reason)), findsNothing, reason: 'verschwindet bei Eingabe');
        }

        testWidgets('aktuelles fehlt', (tester) => check(tester, 'Bitte gib dein aktuelles Passwort ein.', _current, current: ''));
        testWidgets('neu zu kurz', (tester) => check(tester, 'Das Passwort braucht mindestens 8 Zeichen.', _new, next: 'kurz'));
        testWidgets('neu zu lang', (tester) => check(tester, 'Das neue Passwort darf höchstens 512 Zeichen haben.', _new, next: 'a' * 513));
        testWidgets('neu gleich aktuell', (tester) => check(tester, 'Das neue Passwort muss sich vom aktuellen unterscheiden.', _new, next: _old));
        testWidgets('Wiederholung weicht ab', (tester) => check(tester, 'Die Passwörter stimmen nicht überein.', _repeat, repeat: 'neu-und-Lang'));
        testWidgets('Wiederholung leer', (tester) => check(tester, 'Die Passwörter stimmen nicht überein.', _repeat, repeat: ''));
      });
    }

    testWidgets('TP-PW-03b Abweichung erst, wenn sie nicht mehr passen kann; gleich aktuell sofort sichtbar', (tester) async {
      await _app(tester);
      await tester.enterText(_field(_new), 'neu-und-lang');
      await tester.enterText(_field(_repeat), 'neu-');
      await tester.pumpAndSettle();
      expect(find.text('Die Passwörter stimmen nicht überein.'), findsNothing);
      await tester.enterText(_field(_repeat), 'neu-x');
      await tester.pumpAndSettle();
      expect(find.text('Die Passwörter stimmen nicht überein.'), findsOneWidget);
      await tester.enterText(_field(_current), 'neu-und-lang');
      await tester.pumpAndSettle();
      expect(find.text('Das neue Passwort muss sich vom aktuellen unterscheiden.'), findsOneWidget);
    });

    testWidgets('TP-PW-04 Erfolg: Dialog schließt, Meldung, Felder leer, Autofill-Abschluss vor dem Leeren', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      final controllers = <TextEditingController>[for (final l in <String>[_current, _new, _repeat]) _widget(tester, l).controller!];
      var commits = 0;
      String? atCommit;
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
        calls.add(call);
        if (call.method == 'TextInput.finishAutofillContext' && call.arguments == true) {
          commits++;
          atCommit = controllers.first.text;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, null));
      await tester.tap(_confirm);
      await tester.pump();
      final texts = controllers.map((c) => c.text).toList();
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(atCommit, _old, reason: 'Passwort-Manager brauchen die Inhalte');
      expect(texts, everyElement(isEmpty));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Passwort geändert.'), findsOneWidget);
      expect(app.server.passwordOf('@anna:fake.test'), 'neu-und-lang');
      expect(app.server.lastLogoutOtherDevices, isFalse);
      expect(app.gateway.session, SessionState.ready);
    });

    testWidgets('TP-PW-05 „Andere Geräte abmelden“ wird übergeben', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Andere Geräte abmelden'));
      await tester.pumpAndSettle();
      await _pressConfirm(tester);
      expect(app.server.lastLogoutOtherDevices, isTrue);
    });

    testWidgets('TP-PW-06 falsches aktuelles Passwort: Grund, Fokus, Text markiert, Felder bleiben', (tester) async {
      final app = await _app(tester);
      await _fill(tester, current: 'nicht-richtig');
      await _pressConfirm(tester);
      await _expectReason(tester, 'Das aktuelle Passwort stimmt nicht.', at: _current);
      final selection = _widget(tester, _current).controller!.selection;
      expect((selection.start, selection.end), (0, 'nicht-richtig'.length));
      expect(_text(tester, _new), 'neu-und-lang');
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(app.server.passwordOf('@anna:fake.test'), _old);
    });

    testWidgets('TP-PW-06b Passwort vom Server abgelehnt: Grund am Feld „neu“', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      app.server.passwordChangeFailure = const GatewayException(GatewayError.weakPassword);
      await _pressConfirm(tester);
      await _expectReason(tester, 'Das Passwort ist zu schwach. Bitte nimm ein sichereres Passwort.', at: _new);
      final selection = _widget(tester, _new).controller!.selection;
      expect((selection.start, selection.end), (0, 'neu-und-lang'.length));
    });

    testWidgets('TP-PW-07 keine Antwort: eigener Text, Felder bleiben gefüllt, ein Feld hat den Fokus', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      app.server.passwordChangeFailure = const GatewayException(GatewayError.serverUnreachable);
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      await _expectReason(tester, _uncertain, at: _repeat);
      expect(_text(tester, _current), _old);
      expect(_text(tester, _new), 'neu-und-lang');
      expect(_text(tester, _repeat), 'neu-und-lang');
    });

    testWidgets('TP-PW-07b anderer Fehler: Fokus aufs letzte Feld, Grund nach derselben Regel', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      app.server.passwordChangeFailure = const GatewayException(GatewayError.rateLimited);
      await _pressConfirm(tester);
      await _expectReason(tester, 'Zu viele Anfragen. Bitte später erneut versuchen.', at: _repeat);
      expect(_text(tester, _repeat), 'neu-und-lang');
    });

    testWidgets('TP-PW-08 Esc schließt im Leerlauf, während des Absendens wirkungslos; alles aus, Knopftext sagt es', (tester) async {
      final gate = Completer<void>();
      final app = await _app(tester, setUp: (s) => s.passwordChangeGate = gate);
      await _fill(tester);
      await tester.tap(_confirm);
      await tester.pump();

      expect(find.text('Ändere Passwort …'), findsOneWidget);
      expect(_widget(tester, _current).readOnly, isTrue);
      expect(_widget(tester, _current).enabled, isNot(isFalse), reason: 'readOnly statt enabled: Fokus bleibt');
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Abbrechen')).onPressed, isNull);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Andere Geräte abmelden')).onChanged, isNull);
      expect(tester.widget<IconButton>(find.descendant(of: _field(_current), matching: find.byType(IconButton))).onPressed, isNull);
      final busyText = find.ancestor(of: find.text('Ändere Passwort …'), matching: find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false)));
      expect(busyText, findsOneWidget);
      expect(find.ancestor(of: busyText, matching: find.byType(FilledButton)), findsOneWidget, reason: 'um den Text, nicht um den Knopf');

      // Mit Wartezeit: Ein geschlossener Dialog stünde sonst während der Animation noch im Baum.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Esc');
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Barriere');
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsOneWidget, reason: 'Zurück');
      // `readOnly` schließt die Eingabeverbindung; die Sperre greift am Rückruf selbst.
      _widget(tester, _repeat).onSubmitted!('neu-und-lang');
      await tester.pump();
      expect(app.server.passwordChangeCalls, 1, reason: 'Enter sendet nicht doppelt');

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('TP-PW-08b Esc im Leerlauf schließt ohne Änderung', (tester) async {
      final app = await _app(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(app.server.passwordChangeCalls, 0);
    });

    testWidgets('TP-PW-09 Abbrechen bestätigt den Autofill-Kontext nicht', (tester) async {
      await _app(tester);
      await _fill(tester);
      final values = <Object?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, (call) async {
        if (call.method == 'TextInput.finishAutofillContext') values.add(call.arguments);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, null));
      await tester.tap(find.widgetWithText(TextButton, 'Abbrechen'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(values, isNot(contains(true)), reason: 'kein commit');
      expect(values, contains(false), reason: 'cancel');
    });

    testWidgets('TP-PW-10 Browser-Anmeldung: Kontoseite ohne Löschaktion, ohne Felder', (tester) async {
      final app = await _oauthApp(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Dein Passwort liegt bei deinem Anbieter. Du änderst es auf seiner Kontoseite im Browser.'), findsOneWidget);
      app.browser.available = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Kontoseite öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Der Browser konnte nicht geöffnet werden.'), findsOneWidget);
      app.browser.available = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Kontoseite öffnen'));
      await tester.pumpAndSettle();
      expect(app.browser.opened, <Uri>[app.server.accountManagementPage!]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('TP-PW-11 von vornherein nicht verfügbar: Text ohne Felder, Knopf „Schließen“', (tester) async {
      await _app(tester, setUp: (s) => s.passwordChangeMode = const PasswordChangeUnavailable());
      expect(find.byType(TextField), findsNothing);
      expect(find.text(_unavailable), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Abbrechen'), findsNothing);
      expect(_confirm, findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Schließen'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('TP-PW-11b erst nach dem Absenden abgelehnt: Felder geleert, Fokus und Hinweis auf „Schließen“', (tester) async {
      final app = await _app(tester);
      await _fill(tester);
      final controllers = <TextEditingController>[for (final l in <String>[_current, _new, _repeat]) _widget(tester, l).controller!];
      app.server.passwordChangeFailure = const GatewayException(GatewayError.passwordChangeUnavailable);
      await tester.tap(_confirm);
      await tester.pump();
      final texts = controllers.map((c) => c.text).toList();
      await tester.pumpAndSettle();
      expect(texts, everyElement(isEmpty));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      final live = find.byWidgetPredicate((w) => w is Semantics && (w.properties.liveRegion ?? false));
      expect(find.descendant(of: live, matching: find.text(_unavailable)), findsOneWidget);
      expect(_confirm, findsNothing);
      final close = find.widgetWithText(TextButton, 'Schließen');
      expect(tester.widget<TextButton>(close).focusNode!.hasFocus, isTrue);
      expect(tester.getSemantics(find.descendant(of: close, matching: find.text('Schließen'))).hint, contains(_unavailable));
      semantics.dispose();
    });

    testWidgets('TP-PW-12 Weg nicht ermittelbar: Meldung statt Dialog', (tester) async {
      _tall(tester);
      final app = await buildTestApp(lang: 'de');
      await tester.pumpWidget(FamilyNexusApp(services: app.services));
      await tester.pumpAndSettle();
      await openSettings(tester);
      app.server.reachable = false;
      await tester.ensureVisible(find.widgetWithText(ListTile, 'Passwort ändern'));
      await tester.tap(find.widgetWithText(ListTile, 'Passwort ändern'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('TP-PW-13 Hinweise erklären Geltung und Folgen', (tester) async {
      await _app(tester);
      expect(find.textContaining('Notfall-Schlüssel bleibt gleich'), findsOneWidget);
      expect(find.textContaining('dort noch nicht gesendete Änderungen gehen verloren'), findsOneWidget);
    });
  });
}
