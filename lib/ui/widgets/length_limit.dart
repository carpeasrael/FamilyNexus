import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wie die Prüfung der Domäne die Länge eines Textes zählt (#221).
///
/// Einkauf und Aufgaben zählen Unicode-Codepunkte, Termine UTF-16-Einheiten. Flutters `maxLength`
/// zählt dagegen sichtbare Zeichen (Grapheme); ein Familien-Emoji ist dort 1, in der Prüfung 7 bzw. 11.
enum LengthMeasure {
  codePoints,
  utf16;

  int of(String s) => switch (this) {
        LengthMeasure.codePoints => s.runes.length,
        LengthMeasure.utf16 => s.length,
      };
}

/// Begrenzt die Eingabe nach [measure] auf [max], gekürzt wird nur an Graphem-Grenzen (nie ein halbes
/// Emoji). Bildet Flutters [LengthLimitingTextInputFormatter] samt Plattform-Standard nach; steht in
/// `inputFormatters` und läuft damit vor Flutters eigener Begrenzung, die danach nie mehr greift
/// (Maß ≤ max ⇒ Grapheme ≤ max).
class MeasuredLengthFormatter extends TextInputFormatter {
  MeasuredLengthFormatter(this.max, this.measure) : assert(max > 0);

  final int max;
  final LengthMeasure measure;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (measure.of(newValue.text) <= max) return newValue;
    switch (LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement()) {
      case MaxLengthEnforcement.none:
        return newValue;
      case MaxLengthEnforcement.enforced:
        // Schon voll und ohne Auswahl: weiteres Tippen ändert nichts.
        if (measure.of(oldValue.text) == max && oldValue.selection.isCollapsed) return oldValue;
        return _truncate(newValue);
      case MaxLengthEnforcement.truncateAfterCompositionEnds:
        if (measure.of(oldValue.text) == max && !oldValue.composing.isValid) return oldValue;
        // Während der IME-Komposition bleibt der Text stehen, gekürzt wird nach ihrem Ende.
        if (newValue.composing.isValid) return newValue;
        return _truncate(newValue);
    }
  }

  TextEditingValue _truncate(TextEditingValue value) {
    var end = 0;
    var size = 0;
    for (final g in value.text.characters) {
      size += measure.of(g);
      if (size > max) break;
      end += g.length;
    }
    final truncated = value.text.substring(0, end);
    return TextEditingValue(
      text: truncated,
      selection: value.selection.copyWith(
        baseOffset: math.min(value.selection.start, truncated.length),
        extentOffset: math.min(value.selection.end, truncated.length),
      ),
      composing: !value.composing.isCollapsed && truncated.length > value.composing.start
          ? TextRange(start: value.composing.start, end: math.min(value.composing.end, truncated.length))
          : TextRange.empty,
    );
  }
}

/// Zähler „n/max“ nach [measure] statt nach sichtbaren Zeichen; Screenreader hören wie beim
/// Standardzähler die verbleibende Anzahl.
InputCounterWidgetBuilder measuredCounter(TextEditingController controller, int max, LengthMeasure measure) =>
    (context, {required currentLength, required isFocused, required maxLength}) {
      final n = measure.of(controller.text);
      final theme = Theme.of(context);
      return Text(
        '$n/$max',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        overflow: TextOverflow.ellipsis,
        semanticsLabel: MaterialLocalizations.of(context).remainingTextFieldCharacterCount((max - n).clamp(0, max)),
      );
    };
