import 'dart:ui' show CheckedState, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schnappschuss dessen, was ein Screenreader unterhalb von [finder] liest und bedienen kann (Beschriftung, Wert,
/// Hinweis, Tooltip, Rolle, Zustand, Tippen). Für die Zerlegungen von AP-4: Der Text wurde vor dem Umbau am unveränderten
/// Code aufgenommen. Uhrzeiten (`hh:mm`) werden neutralisiert, weil sie von der Zeitzone des Rechners abhängen.
List<String> semanticsSnapshot(WidgetTester tester, Finder finder) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final d = n.getSemanticsData();
    final parts = <String>[
      if (d.label.isNotEmpty) 'L=${d.label.replaceAll('\n', ' | ')}',
      if (d.value.isNotEmpty) 'V=${d.value}',
      if (d.hint.isNotEmpty) 'H=${d.hint}',
      if (d.tooltip.isNotEmpty) 'T=${d.tooltip}',
      if (d.flagsCollection.isTextField) 'textfield',
      if (d.flagsCollection.isObscured) 'obscured',
      if (d.flagsCollection.isButton) 'button',
      if (d.flagsCollection.isLiveRegion) 'live',
      if (d.flagsCollection.isSelected == Tristate.isTrue) 'selected',
      if (d.flagsCollection.isEnabled == Tristate.isFalse) 'disabled',
      if (d.flagsCollection.isChecked == CheckedState.isTrue) 'checked',
      if (d.hasAction(SemanticsAction.tap)) 'tap',
    ];
    if (parts.isNotEmpty) out.add(parts.join(' ').replaceAll(RegExp(r'\b\d{1,2}:\d{2}\b'), 'hh:mm'));
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(tester.getSemantics(finder));
  return out;
}
