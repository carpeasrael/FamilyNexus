import 'package:family_nexus/features/common/syncing_view.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// #24: „Synchronisiere …“ bleibt nicht endlos ohne Ausweg stehen.
void main() {
  testWidgets('nach längerer Wartezeit Hinweis und „Erneut versuchen“, das den Abgleich neu startet', (tester) async {
    final app = await buildTestApp();
    app.gateway.syncDone = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SyncingView(gateway: app.gateway)),
    ));
    expect(find.text('Synchronisiere …'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsNothing, reason: 'normales Warten ohne Hinweis');

    await tester.pump(SyncingView.slowAfter + const Duration(seconds: 1));
    expect(find.textContaining('Das dauert länger als üblich.'), findsOneWidget);
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pump();
    expect(app.gateway.syncRetries, 1);
    expect(find.text('Erneut versuchen'), findsNothing, reason: 'neuer Versuch, neue Wartezeit');

    await tester.pump(SyncingView.slowAfter + const Duration(seconds: 1));
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });
}
