import 'package:flutter/widgets.dart';

/// Tippen außerhalb eines Textfelds schließt die Bildschirmtastatur – auf allen Plattformen.
///
/// Flutter tut das von sich aus nur auf dem Desktop; auf iOS gibt es zudem keine Taste zum Ausblenden,
/// sodass die Tastatur sonst stehen bleibt und die Navigation verdeckt (Issue #2). Bereiche, die zum
/// Textfeld gehören (z. B. die Senden-Taste im Chat), markiert man mit [TextFieldTapRegion].
class DismissKeyboardOnTapOutside extends StatelessWidget {
  const DismissKeyboardOnTapOutside({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
        actions: <Type, Action<Intent>>{
          EditableTextTapOutsideIntent: CallbackAction<EditableTextTapOutsideIntent>(
            onInvoke: (intent) {
              intent.focusNode.unfocus();
              return null;
            },
          ),
        },
        child: child,
      );
}
