import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/app/app_services.dart';
import 'package:family_nexus/data/matrix/family_room_spec.dart';
import 'package:family_nexus/data/matrix/sdk_matrix_gateway.dart';
import 'package:family_nexus/domain/calendar_event.dart';
import 'package:family_nexus/domain/chat.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/domain/shopping.dart';
import 'package:family_nexus/domain/tasks.dart';
import 'package:family_nexus/features/common/prompt_dialog.dart';
import 'package:family_nexus/features/onboarding/family_step.dart';
import 'package:family_nexus/l10n/gen/app_localizations.dart';
import 'package:family_nexus/ui/theme/app_theme.dart';
import 'package:family_nexus/ui/widgets/length_limit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// #221: Jedes betroffene Feld begrenzt mit dem Maß der Prüfung; Flutters Begrenzung bleibt auf dem
/// Standard, damit Screenreader die Höchstlänge weiter erfahren.
void _expectMeasured(WidgetTester tester, Finder field, int max, LengthMeasure measure) {
  final f = tester.widget<TextField>(field);
  final formatter = f.inputFormatters!.whereType<MeasuredLengthFormatter>().single;
  expect((formatter.max, formatter.measure, f.maxLength, f.maxLengthEnforcement), (max, measure, max, null));
}

Finder _in(Type parent, Finder field) => find.descendant(of: find.byType(parent), matching: field);

Future<TestApp> _start(WidgetTester tester, {String? tab}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = await buildTestApp(clock: () => DateTime.utc(2026, 3, 20, 10));
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  if (tab != null) {
    await tester.tap(navTab(tab));
    await tester.pumpAndSettle();
  }
  return app;
}

Future<void> _openTasks(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menü öffnen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, 'Aufgaben'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Einkauf: Eingabezeile und Bearbeiten-Dialog zählen Codepunkte', (tester) async {
    final app = await _start(tester, tab: 'Einkauf');
    _expectMeasured(tester, find.byType(TextField).at(0), ShoppingItem.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, find.byType(TextField).at(1), ShoppingItem.maxQuantity, LengthMeasure.codePoints);
    _expectMeasured(tester, find.byType(TextField).at(2), ShoppingItem.maxGroup, LengthMeasure.codePoints);
    expect(find.text('0/${ShoppingItem.maxGroup}'), findsNothing, reason: 'Eingabezeile bleibt ohne Zähler');

    await app.services.shopping!.add('Eier', quantity: '6', group: 'Aldi');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eier'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bearbeiten'));
    await tester.pumpAndSettle();
    final dialog = _in(AlertDialog, find.byType(TextField));
    _expectMeasured(tester, dialog.at(0), ShoppingItem.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, dialog.at(1), ShoppingItem.maxQuantity, LengthMeasure.codePoints);
    _expectMeasured(tester, dialog.at(2), ShoppingItem.maxGroup, LengthMeasure.codePoints);
    await tester.enterText(dialog.at(1), '6 😀');
    await tester.pump();
    expect(find.text('3/${ShoppingItem.maxQuantity}'), findsOneWidget, reason: 'Menge: 3 Codepunkte');
  });

  testWidgets('Aufgaben: Titel, Erklärung und Kommentar zählen Codepunkte, Punkte der Liste bleiben frei', (tester) async {
    final app = await _start(tester);
    await app.services.tasks!.create(
      title: 'Haushalt',
      assignee: app.gateway.userId!,
      rule: TaskRule.fromInterval(TaskInterval.daily),
      items: <String>['Müll raus'],
    );
    await _openTasks(tester);
    await tester.tap(find.text('Haushalt'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    final comment = find.widgetWithText(TextField, 'Kommentar (optional)');
    _expectMeasured(tester, comment, TaskLogEntry.maxComment, LengthMeasure.codePoints);
    await tester.enterText(comment, '👍🏽');
    await tester.pump();
    expect(find.text('2/${TaskLogEntry.maxComment}'), findsOneWidget, reason: 'Emoji mit Hautfarbe: 2 Codepunkte');
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Aufgabenliste bearbeiten'));
    await tester.pumpAndSettle();
    _expectMeasured(tester, find.widgetWithText(TextField, 'Titel'), TaskList.maxTitle, LengthMeasure.codePoints);
    _expectMeasured(tester, find.widgetWithText(TextField, 'Erklärung (optional)'), TaskList.maxDescription, LengthMeasure.codePoints);
    final items = tester.widget<TextField>(find.widgetWithText(TextField, 'Punkte (einer pro Zeile)'));
    expect(items.inputFormatters, isNull, reason: 'ein Formatter würde die ganze Liste begrenzen');
    expect(items.maxLength, isNull);
  });

  testWidgets('Termine: Titel, Ort und Notiz zählen UTF-16-Einheiten', (tester) async {
    await _start(tester, tab: 'Kalender');
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    Finder field(String label) => find.descendant(of: find.widgetWithText(TextFormField, label), matching: find.byType(TextField));
    _expectMeasured(tester, field('Titel'), CalendarEvent.maxTitle, LengthMeasure.utf16);
    _expectMeasured(tester, field('Ort'), CalendarEvent.maxLocation, LengthMeasure.utf16);
    _expectMeasured(tester, field('Notiz'), CalendarEvent.maxNote, LengthMeasure.utf16);
    await tester.enterText(field('Ort'), 'Zoo 😀');
    await tester.pump();
    expect(find.text('6/${CalendarEvent.maxLocation}'), findsOneWidget, reason: '😀 sind 2 UTF-16-Einheiten');
  });

  testWidgets('Zähler nennt Screenreadern die verbleibende Anzahl nach dem Maß der Prüfung', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester, tab: 'Kalender');
    await tester.tap(find.byTooltip('Neuer Termin'));
    await tester.pumpAndSettle();
    final ort = find.descendant(of: find.widgetWithText(TextFormField, 'Ort'), matching: find.byType(TextField));
    await tester.enterText(ort, '😀');
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('${CalendarEvent.maxLocation - 2}')), findsWidgets);
    handle.dispose();
  });
  testWidgets('Chat: Eingabe zählt UTF-16-Einheiten wie sendMessage (#236)', (tester) async {
    await _start(tester, tab: 'Chat');
    _expectMeasured(tester, find.widgetWithText(TextField, 'Nachricht schreiben'), ChatMessage.maxBody, LengthMeasure.utf16);
    expect(SdkMatrixGateway.maxMessageLength, ChatMessage.maxBody, reason: 'Feld und Prüfung nutzen dieselbe Grenze');
  });
  testWidgets('Familie gründen: Name zählt UTF-16-Einheiten wie createFamily (#461)', (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = await buildTestApp(loggedIn: false);
    await app.gateway.login(server: ServerUrl.tryParse(app.server.host)!, username: 'anna', password: 'geheim123');
    await app.gateway.setUpSecurity();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: buildTheme(Brightness.light),
      home: AppScope(
        services: app.services,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: FamilyStep(onFamilyReady: () async {}, mode: FamilyStepMode.create),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final name = find.byType(TextField).first;
    _expectMeasured(tester, name, FamilyRoomSpec.nameMax, LengthMeasure.utf16);
    expect(SdkMatrixGateway.maxFamilyNameLength, FamilyRoomSpec.nameMax, reason: 'Feld und Prüfung nutzen dieselbe Grenze');

    await tester.enterText(name, '${'a' * 59}😀');
    await tester.pump();
    expect(tester.widget<TextField>(name).controller!.text, 'a' * 59, reason: 'kein halbes Emoji, 😀 sind 2 Einheiten');
    expect(find.text('59/${FamilyRoomSpec.nameMax}'), findsOneWidget);

    const family = '👨‍👩‍👧‍👦';
    await tester.enterText(name, family * 6);
    await tester.pump();
    expect(tester.widget<TextField>(name).controller!.text, family * 5, reason: 'je Familien-Emoji 11 Einheiten');
    expect(find.text('55/${FamilyRoomSpec.nameMax}'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Familie gründen'));
    await tester.pumpAndSettle();
    expect(app.gateway.family?.name, family * 5);
    expect(find.text('Bitte Eingabe prüfen.'), findsNothing);
  });

  testWidgets('Familie umbenennen: Dialog zählt UTF-16-Einheiten wie renameFamily (#461)', (tester) async {
    final app = await _start(tester, tab: 'Familie');
    await tester.tap(find.byTooltip('Familienname ändern'));
    await tester.pumpAndSettle();
    final name = _in(AlertDialog, find.byType(TextField));
    _expectMeasured(tester, name, FamilyRoomSpec.nameMax, LengthMeasure.utf16);
    await tester.enterText(name, '${'a' * 59}😀');
    await tester.pump();
    expect(find.text('59/${FamilyRoomSpec.nameMax}'), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(app.gateway.family!.name, 'a' * 59);
    expect(find.text('Bitte Eingabe prüfen.'), findsNothing);
  });

  testWidgets('TextPromptDialog ohne lengthMeasure bleibt ohne Formatter (#461)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('de'),
      home: Scaffold(body: TextPromptDialog(title: 'T', label: 'L', confirmLabel: 'OK', obscure: true)),
    ));
    final f = tester.widget<TextField>(find.byType(TextField));
    expect(f.inputFormatters, isNull);
    expect(f.buildCounter, isNull);
  });
}
