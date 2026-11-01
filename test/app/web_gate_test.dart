import 'dart:async';

import 'package:family_nexus/app/web_gate.dart';
import 'package:family_nexus/data/platform/key_store.dart';
import 'package:family_nexus/data/platform/vault_key_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tresor mit steuerbaren Fehlern.
class _Vault implements VaultBackend {
  _Vault({this.exists = false});

  @override
  bool exists;
  Object? createError;
  Object? unlockError;
  Object? loadError;
  final Map<String, String> data = <String, String>{};

  @override
  Future<void> create(String password) async {
    if (createError != null) throw createError!;
    exists = true;
  }

  @override
  Future<void> unlock(String password) async {
    if (unlockError != null) throw unlockError!;
  }

  @override
  Future<Map<String, String>> load() async {
    if (loadError != null) throw loadError!;
    return Map<String, String>.of(data);
  }

  @override
  Future<void> save(Map<String, String> entries) async {
    data
      ..clear()
      ..addAll(entries);
  }

  @override
  Future<void> destroy() async {}
}

/// Beobachtete Aufrufe der Rückrufe.
class _Calls {
  int unlocked = 0;
  int wiped = 0;
}

/// #154: Scheitert der Tresor aus einem anderen Grund als „falsches Passwort“, erscheint eine Meldung.
void main() {
  Future<_Calls> pump(WidgetTester tester, _Vault vault, String lang,
      {Object? wipeError, Future<void>? wipeGate, Object? unlockedError}) async {
    tester.platformDispatcher.localesTestValue = <Locale>[Locale(lang)];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final calls = _Calls();
    await tester.pumpWidget(WebUnlockApp(
      backend: vault,
      onUnlocked: (KeyStore keys) {
        calls.unlocked++;
        if (unlockedError != null) throw unlockedError;
      },
      onWipe: () async {
        calls.wiped++;
        await wipeGate;
        if (wipeError != null) throw wipeError;
      },
    ));
    await tester.pumpAndSettle();
    return calls;
  }

  Future<void> enter(WidgetTester tester, {bool repeat = false}) async {
    const pw = 'ein-langes-passwort';
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), pw);
    if (repeat) await tester.enterText(fields.at(1), pw);
  }

  for (final lang in ['de', 'en']) {
    final de = lang == 'de';
    final failed = de ? 'Der Tresor konnte nicht geöffnet werden' : 'The vault could not be opened';
    final wrong = de ? 'Falsches Passwort.' : 'Wrong password.';
    final wipeFailed = de ? 'Die Daten konnten nicht gelöscht werden' : 'The data could not be deleted';
    final forgot = de ? 'Passwort vergessen? Alle lokalen Daten löschen' : 'Forgot the password? Delete all local data';
    final delete = de ? 'Löschen' : 'Delete';
    final createAction = de ? 'Tresor anlegen' : 'Create vault';

    testWidgets('$lang: Anlegen scheitert – Meldung, Knopf wieder aktiv, nicht entsperrt', (tester) async {
      final calls = await pump(tester, _Vault()..createError = StateError('crypto.subtle fehlt'), lang);
      await enter(tester, repeat: true);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.textContaining(failed), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
      expect(calls.unlocked, 0);
      expect(calls.wiped, 0);
    });

    testWidgets('$lang: Entsperren scheitert (kein Passwortfehler) – Meldung', (tester) async {
      final calls = await pump(tester, _Vault(exists: true)..unlockError = StateError('Speicher gesperrt'), lang);
      await enter(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.textContaining(failed), findsOneWidget);
      expect(find.text(wrong), findsNothing);
      expect(tester.takeException(), isNull);
      expect(calls.unlocked, 0);
    });

    testWidgets('$lang: Laden der Schlüssel scheitert – Meldung', (tester) async {
      final vault = _Vault(exists: true)..loadError = StateError('Speicher gesperrt');
      final calls = await pump(tester, vault, lang);
      await enter(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.textContaining(failed), findsOneWidget);
      expect(calls.unlocked, 0);
    });

    testWidgets('$lang: falsches Passwort meldet weiterhin „falsch“', (tester) async {
      await pump(tester, _Vault(exists: true)..unlockError = WrongVaultPasswordException(), lang);
      await enter(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(find.text(wrong), findsOneWidget);
      expect(find.textContaining(failed), findsNothing);
    });

    testWidgets('$lang: Löschen scheitert – Meldung, Zustand bleibt „Entsperren“', (tester) async {
      final calls = await pump(tester, _Vault(exists: true), lang, wipeError: StateError('gesperrt'));
      await tester.tap(find.text(forgot));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, delete));
      await tester.pumpAndSettle();
      expect(calls.wiped, 1);
      expect(find.textContaining(wipeFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.text(createAction), findsNothing, reason: 'nicht auf „Anlegen“ umgeschaltet');
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('$lang: Löschen gelingt – wechselt zu „Anlegen“', (tester) async {
      final calls = await pump(tester, _Vault(exists: true), lang);
      await tester.tap(find.text(forgot));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, delete));
      await tester.pumpAndSettle();
      expect(calls.wiped, 1);
      expect(find.text(createAction), findsOneWidget);
      expect(find.textContaining(wipeFailed), findsNothing);
    });

    testWidgets('$lang: Erfolg entsperrt genau einmal', (tester) async {
      final calls = await pump(tester, _Vault(exists: true), lang);
      await enter(tester);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(calls.unlocked, 1);
      expect(find.textContaining(failed), findsNothing);
    });

    testWidgets('$lang: Während des Löschens sind Knöpfe und Felder gesperrt', (tester) async {
      final gate = Completer<void>();
      await pump(tester, _Vault(exists: true), lang, wipeGate: gate.future);
      await tester.tap(find.text(forgot));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, delete));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text(createAction), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
    });

    testWidgets('$lang: Fehler im Rückruf nach dem Entsperren erscheint nicht als Tresorfehler', (tester) async {
      await pump(tester, _Vault(exists: true), lang, unlockedError: StateError('Start'));
      await enter(tester);
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
      }, (e, st) => uncaught.add(e));
      expect(find.textContaining(failed), findsNothing);
      expect(uncaught.whereType<StateError>(), isNotEmpty, reason: 'der Fehler wird nicht als Tresorfehler verschluckt');
    });
  }
}
