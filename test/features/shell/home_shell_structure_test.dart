import 'dart:ui' show Tristate;

import 'package:family_nexus/app/app.dart';
import 'package:family_nexus/features/shell/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/shell_finders.dart';
import '../../support/test_app.dart';

/// AP-4d: Die Zerlegung von `HomeShell.build` ändert weder Navigation und Menü (Semantik) noch die Seitenaufteilung
/// (Rechtecke, Sichtbarkeit, Fokusausschluss). Die Schnappschüsse wurden vor dem Umbau am unveränderten Code aufgenommen.
final DateTime _now = DateTime.utc(2026, 3, 20, 10);

Future<void> _start(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final app = await buildTestApp(clock: () => _now);
  await tester.pumpWidget(FamilyNexusApp(services: app.services));
  await tester.pumpAndSettle();
}

String _node(SemanticsNode n) {
  final d = n.getSemanticsData();
  return <String>[
    if (d.label.isNotEmpty) 'L=${d.label.replaceAll('\n', ' | ')}',
    if (d.hint.isNotEmpty) 'H=${d.hint}',
    if (d.tooltip.isNotEmpty) 'T=${d.tooltip}',
    if (d.flagsCollection.isButton) 'button',
    if (d.flagsCollection.isSelected == Tristate.isTrue) 'selected',
    if (d.hasAction(SemanticsAction.tap)) 'tap',
  ].join(' ');
}

List<String> _semantics(WidgetTester tester, Finder f) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final s = _node(n);
    if (s.isNotEmpty) out.add(s);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(f));
  return out;
}

/// Seitenaufteilung: je Seite Rechteck, Offstage und Fokusausschluss (nur der Stack unter der Rail).
List<String> _panes(WidgetTester tester) {
  final out = <String>[];
  final stack = find.descendant(of: find.byType(HomeShell), matching: find.byType(Stack)).evaluate().where((e) {
    final s = e.widget as Stack;
    return s.fit == StackFit.expand && s.children.length == 6;
  }).first;
  for (final c in (stack.widget as Stack).children) {
    if (c is! Positioned) continue;
    final child = c.child;
    final off = child is Offstage ? 'off=${child.offstage}' : child.runtimeType.toString();
    out.add('L=${c.left} T=${c.top} W=${c.width ?? '-'} H=${c.height ?? '-'} $off');
  }
  return out;
}

void main() {
  testWidgets('Shell schmal: untere Leiste, Seitenaufteilung, Menü', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester, const Size(400, 800));
    final snap = <String>[
      ..._semantics(tester, find.byType(AppBar)),
      '--',
      ..._semantics(tester, findNavigation()),
      '--',
      ..._panes(tester),
    ];
    expect(snap, _expectedCompact);
    handle.dispose();
  });

  testWidgets('Shell breit, Tab Kalender: Rail, Zweispalter, Trenner', (tester) async {
    final handle = tester.ensureSemantics();
    await _start(tester, const Size(1200, 800));
    await tester.tap(navTab('Kalender'));
    await tester.pumpAndSettle();
    final snap = <String>[
      ..._semantics(tester, find.byType(AppBar)),
      '--',
      ..._semantics(tester, findNavigation()),
      '--',
      ..._panes(tester),
    ];
    expect(snap, _expectedExpanded);
    handle.dispose();
  });
}

const List<String> _expectedCompact = <String>[
  'L=Heute',
  'T=Menü öffnen button tap',
  '--',
  'L=Nächste Termine | In den nächsten 30 Tagen stehen keine Termine an.',
  'L=Alle Termine button tap',
  'L=Erinnerungen | Keine Erinnerung geplant',
  'L=Übersicht button tap',
  'L=Wer ist online | Gerade ist sonst niemand online.',
  'L=Einkaufszettel | Einkaufszettel: 0 offen',
  'L=Einkauf button tap',
  'L=Aufgaben | Aufgaben für dich: 0 offen',
  'L=Aufgaben button tap',
  'L=Ungelesene Nachrichten | Keine ungelesenen Nachrichten',
  'L=Chat öffnen button tap',
  'T=Neuer Termin button tap',
  'button tap',
  'L=Heute',
  'T=Menü öffnen button tap',
  'L=Heute | Tab 1 von 5 button selected tap',
  'L=Kalender | Tab 2 von 5 button tap',
  'L=Chat | Tab 3 von 5 button tap',
  'L=Einkauf | Tab 4 von 5 button tap',
  'L=Familie | Tab 5 von 5 button tap',
  '--',
  'L=0.0 T=0.0 W=400.0 H=664.0 off=false',
  'L=0.0 T=0.0 W=400.0 H=664.0 off=true',
  'L=0.0 T=0.0 W=400.0 H=664.0 off=true',
  'L=0.0 T=0.0 W=400.0 H=664.0 off=true',
  'L=0.0 T=0.0 W=400.0 H=664.0 off=true',
  'L=0.0 T=0.0 W=1.0 H=- off=true',
];

const List<String> _expectedExpanded = <String>[
  'L=Kalender und Chat',
  'T=Menü öffnen button tap',
  '--',
  'L=Heute | Tab 1 von 5 tap',
  'L=Kalender | Tab 2 von 5 selected tap',
  'L=Chat | Tab 3 von 5 tap',
  'L=Einkauf | Tab 4 von 5 tap',
  'L=Familie | Tab 5 von 5 tap',
  '--',
  'L=0.0 T=0.0 W=1088.0 H=744.0 off=true',
  'L=0.0 T=0.0 W=647.0 H=744.0 off=false',
  'L=648.0 T=0.0 W=440.0 H=744.0 off=false',
  'L=0.0 T=0.0 W=1088.0 H=744.0 off=true',
  'L=0.0 T=0.0 W=1088.0 H=744.0 off=true',
  'L=647.0 T=0.0 W=1.0 H=- off=false',
];
