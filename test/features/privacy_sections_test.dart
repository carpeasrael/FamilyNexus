import 'package:family_nexus/features/settings/privacy_screen.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #145: Im Browser (`kIsWeb` ist im Test konstant false, daher der Parameter) beschreibt die Datenschutzseite
/// keine Erinnerungen und Berechtigungen, die es dort nicht gibt.
void main() {
  for (final lang in ['de', 'en']) {
    final l = lookupAppLocalizations(Locale(lang));
    // Android-Berechtigungen, die es im Browser nicht gibt (die Web-Fassung darf sie nur verneinen).
    final androidOnly = RegExp(
      'genaue Alarme|Neustart-Meldung|exact alarms|boot notification',
      caseSensitive: false,
    );

    test(
      '$lang: Web ohne Erinnerungs-Abschnitt, Berechtigungen ohne Alarme und App-Sperre',
      () {
        final web = privacySections(l, web: true);
        expect(web.map((s) => s.$1), isNot(contains(l.privacy5Title)));
        expect(web.map((s) => s.$1), contains(l.privacy13Title));
        final perms = web.singleWhere((s) => s.$1 == l.privacy6Title).$2;
        expect(androidOnly.hasMatch(perms), isFalse, reason: perms);
        expect(
          perms,
          contains(lang == 'de' ? 'keine Berechtigung' : 'no permission'),
        );
        expect(perms, l.privacy6BodyWeb);
        expect(
          androidOnly.hasMatch(
            privacySections(
              l,
              web: false,
            ).singleWhere((s) => s.$1 == l.privacy6Title).$2,
          ),
          isTrue,
          reason: 'App-Fassung nennt sie weiterhin',
        );
      },
    );

    test('$lang: App (nicht Web) unverändert', () {
      final app = privacySections(l, web: false);
      expect(app.map((s) => s.$1), contains(l.privacy5Title));
      expect(app.map((s) => s.$1), isNot(contains(l.privacy13Title)));
      expect(
        app.singleWhere((s) => s.$1 == l.privacy6Title).$2,
        l.privacy6Body,
      );
    });

    test(
      '$lang: privacy13Body behauptet keine Erinnerungen „bei geschlossener Seite“',
      () {
        expect(
          l.privacy13Body,
          isNot(
            matches(
              RegExp(
                'geschlossener Seite|page is closed|closed page',
                caseSensitive: false,
              ),
            ),
          ),
        );
        expect(
          l.privacy13Body,
          contains(
            lang == 'de'
                ? 'auch nicht bei geöffneter Seite'
                : 'even while the page is open',
          ),
        );
      },
    );
  }
}
