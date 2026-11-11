import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/widgets/glass.dart';

/// Zeigt die kurze Einführung (Kalender, Chat, Einkauf, #347) und merkt danach lokal, dass sie gesehen wurde.
/// Beenden, Überspringen und Zurück-Taste zählen gleich: Die Tour erscheint von selbst nur einmal und lässt sich in den
/// Einstellungen erneut öffnen.
Future<void> showIntroTour(BuildContext context) async {
  final settings = AppScope.read(context).settings;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const IntroTourDialog(),
  );
  if (!settings.settings.tourSeen) await settings.update((c) => c.copyWith(tourSeen: true));
}

class IntroTourDialog extends StatefulWidget {
  const IntroTourDialog({super.key});

  @override
  State<IntroTourDialog> createState() => _IntroTourDialogState();
}

class _IntroTourDialogState extends State<IntroTourDialog> {
  static const int _steps = 3;
  int _step = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, title, body) = switch (_step) {
      0 => (Icons.calendar_month_outlined, l.tourCalendarTitle, l.tourCalendarBody),
      1 => (Icons.chat_bubble_outline, l.tourChatTitle, l.tourChatBody),
      _ => (Icons.shopping_cart_outlined, l.tourShoppingTitle, l.tourShoppingBody),
    };
    final last = _step == _steps - 1;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: GlassCard(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              ExcludeSemantics(child: Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(height: 12),
              // Ansage bei jedem Schritt: Schritt, Titel und Text in einem Zug.
              Semantics(
                container: true,
                liveRegion: true,
                header: true,
                label: '${l.tourStepOf(_step + 1, _steps)}. $title. $body',
                child: ExcludeSemantics(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(l.tourStepOf(_step + 1, _steps), style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: 4),
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(body, style: Theme.of(context).textTheme.bodyLarge),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (!last) TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.tourSkip)),
                  if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: Text(l.tourBack)),
                  FilledButton(
                    autofocus: true,
                    onPressed: last ? () => Navigator.of(context).pop() : () => setState(() => _step++),
                    child: Text(last ? l.tourDone : l.tourNext),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
