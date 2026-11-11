import 'dart:ui' show Tristate;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/domain/server.dart';
import 'package:family_nexus/features/calendar/event_editor_screen.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/shell_finders.dart';
import '../support/test_app.dart';

/// AP-4c: Die Zerlegung von `EventEditorScreen.build` ändert nicht, was ein Screenreader liest und bedienen kann.
/// Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

Future<void> _openEditor(WidgetTester tester, TestApp app) async {
  tester.view.physicalSize = const Size(900, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
  await tester.tap(navTab('Kalender'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Neuer Termin'));
  await tester.pumpAndSettle();
}

List<String> _semantics(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    final parts = <String>[
      if (d.label.isNotEmpty) 'L=${d.label.replaceAll('\n', ' | ')}',
      if (d.value.isNotEmpty) 'V=${d.value}',
      if (d.hint.isNotEmpty) 'H=${d.hint}',
      if (d.tooltip.isNotEmpty) 'T=${d.tooltip}',
      if (d.flagsCollection.isTextField) 'textfield',
      if (d.flagsCollection.isButton) 'button',
      if (d.flagsCollection.isLiveRegion) 'live',
      if (d.flagsCollection.isSelected == Tristate.isTrue) 'selected',
      if (d.flagsCollection.isEnabled == Tristate.isFalse) 'disabled',
      if (d.hasAction(SemanticsAction.tap)) 'tap',
    ];
    // Uhrzeiten hängen von der Zeitzone des Rechners ab: neutralisieren.
    if (parts.isNotEmpty) out.add(parts.join(' ').replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), 'hh:mm'));
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(find.byType(EventEditorScreen)));
  return out;
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.ensureVisible(f.first);
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Termin-Editor: neu, privat, einmalig', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(clock: () => _now);
    await _openEditor(tester, app);
    expect(_semantics(tester), _expectedPrivate);
    handle.dispose();
  });

  testWidgets('Termin-Editor: geteilt mit Teilnehmern, wöchentlich nach Anzahl, Zeitfehler', (tester) async {
    final handle = tester.ensureSemantics();
    final app = await buildTestApp(clock: () => _now);
    final ben = app.server.newDevice();
    await ben.login(server: ServerUrl.tryParse(app.server.host)!, username: 'ben', password: 'geheim456');
    final room = app.gateway.familyRoom!;
    app.server.addMember(room, '@ben:fake.test');
    ben.attachFamilyRoom(room.id);
    await _openEditor(tester, app);
    await _tapText(tester, 'Geteilt');
    await _tapText(tester, 'Wöchentlich');
    await _tapText(tester, 'Nach Anzahl');
    await _tapText(tester, 'Ben');
    expect(_semantics(tester), _expectedShared);
    handle.dispose();
  });
}

const List<String> _expectedPrivate = <String>[
  'L=Titel | Beginn | Ende | Zeitzone: Europe/Berlin textfield tap',
  'L=Noch 200 Zeichen',
  'L=Ganztägig tap',
  'tap',
  'L=20. März 2026 button tap',
  'L=hh:mm button tap',
  'L=20. März 2026 button tap',
  'L=hh:mm button tap',
  'L=Sichtbarkeit | Nur für dich, verschlüsselt zwischen deinen eigenen Geräten. Wird nie an die Familie gesendet.',
  'L=Privat button selected tap',
  'L=Privat button tap',
  'L=Geteilt button tap',
  'L=Geteilt button tap',
  'L=Ort textfield tap',
  'L=Noch 200 Zeichen',
  'L=Notiz textfield tap',
  'L=Noch 5.000 Zeichen',
  'L=Wiederholung',
  'L=Keine button selected tap',
  'L=Täglich button tap',
  'L=Wöchentlich button tap',
  'L=Monatlich button tap',
  'L=Jährlich button tap',
  'L=Farbe',
  'L=Farbe 1 button tap',
  'L=Farbe 2 button tap',
  'L=Farbe 3 button selected tap',
  'L=Farbe 4 button tap',
  'L=Farbe 5 button tap',
  'L=Farbe 6 button tap',
  'L=Farbe 7 button tap',
  'L=Farbe 8 button tap',
  'L=Erinnerungen | Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.',
  'L=Zur Startzeit button tap',
  'L=5 Minuten vorher button tap',
  'L=10 Minuten vorher button selected tap',
  'L=15 Minuten vorher button tap',
  'L=30 Minuten vorher button tap',
  'L=1 Stunde vorher button tap',
  'L=2 Stunden vorher button tap',
  'L=1 Tag vorher button tap',
  'L=2 Tage vorher button tap',
  'L=Zurück T=Zurück button tap',
  'L=Neuer Termin',
  'L=Speichern button tap',
];

const List<String> _expectedShared = <String>[
  'L=Titel | Beginn | Ende | Zeitzone: Europe/Berlin textfield tap',
  'L=Noch 200 Zeichen',
  'L=Ganztägig tap',
  'tap',
  'L=20. März 2026 button tap',
  'L=hh:mm button tap',
  'L=20. März 2026 button tap',
  'L=hh:mm button tap',
  'L=Sichtbarkeit | Verschlüsselt an die Familie gesendet. Mitglieder sehen den Termin und können zu- oder absagen.',
  'L=Privat button tap',
  'L=Privat button tap',
  'L=Geteilt button selected tap',
  'L=Geteilt button tap',
  'L=Ort textfield tap',
  'L=Noch 200 Zeichen',
  'L=Notiz textfield tap',
  'L=Noch 5.000 Zeichen',
  'L=Wiederholung | Alle | Wochen | Endet',
  'L=Keine button tap',
  'L=Täglich button tap',
  'L=Wöchentlich button selected tap',
  'L=Monatlich button tap',
  'L=Jährlich button tap',
  'V=1 textfield tap',
  'L=Mo button tap',
  'L=Di button tap',
  'L=Mi button tap',
  'L=Do button tap',
  'L=Fr button tap',
  'L=Sa button tap',
  'L=So button tap',
  'L=Nie button tap',
  'L=Am Datum button tap',
  'L=Nach Anzahl button selected tap',
  'L=Anzahl V=10 textfield tap',
  'L=Teilnehmer',
  'L=Ben button selected tap',
  'L=Farbe',
  'L=Farbe 1 button tap',
  'L=Farbe 2 button tap',
  'L=Farbe 3 button selected tap',
  'L=Farbe 4 button tap',
  'L=Farbe 5 button tap',
  'L=Farbe 6 button tap',
  'L=Farbe 7 button tap',
  'L=Farbe 8 button tap',
  'L=Erinnerungen | Erinnerungen sind lokale Benachrichtigungen dieses Geräts. Sie zeigen nie Titel oder Ort.',
  'L=Zur Startzeit button tap',
  'L=5 Minuten vorher button tap',
  'L=10 Minuten vorher button selected tap',
  'L=15 Minuten vorher button tap',
  'L=30 Minuten vorher button tap',
  'L=1 Stunde vorher button tap',
  'L=2 Stunden vorher button tap',
  'L=1 Tag vorher button tap',
  'L=2 Tage vorher button tap',
  'L=Zurück T=Zurück button tap',
  'L=Neuer Termin',
  'L=Speichern button tap',
];
