part of '../event_editor_screen.dart';

/// Reminder-Auswahl (Minuten vor Beginn).
const List<int> kReminderChoices = <int>[0, 5, 10, 15, 30, 60, 120, 1440, 2880];

/// Ob der Zeitwähler beim Fokus ins Stunden- oder Minutenfeld den Wert markiert (#263).
///
/// Nur auf dem Desktop: Dort setzt ein Klick den Cursor ohne Markierung, und das volle Feld
/// (zwei Ziffern) verwirft getippte Ziffern. Im Web markiert Flutter selbst; auf Mobilgeräten
/// ist Alles-Markieren beim Fokus nicht Plattform-Standard (bekannte Grenze, E-20).
bool selectAllOnTimeFieldFocus(TargetPlatform platform, {required bool isWeb}) {
  if (isWeb) return false;
  return switch (platform) {
    TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => false,
  };
}

/// Markiert den Inhalt eines Textfelds im eigenen Teilbaum, sobald es den Fokus bekommt (#263).
///
/// Hört auf den [FocusManager]; dessen Listener laufen nach den Listenern der Fokusknoten und
/// nach dem Setzen des Cursors durch den Klick, die Markierung bleibt also stehen. Nicht markiert
/// wird bei der Rückkehr ins Fenster (der Fokus kommt dann von `rootScope` zurück) und beim
/// erneuten Klick in ein Feld, das schon den Fokus hat (kein Fokuswechsel).
class _SelectAllOnFocus extends StatefulWidget {
  const _SelectAllOnFocus({required this.child});

  final Widget child;

  @override
  State<_SelectAllOnFocus> createState() => _SelectAllOnFocusState();
}

class _SelectAllOnFocusState extends State<_SelectAllOnFocus> {
  FocusNode? _previous;

  @override
  void initState() {
    super.initState();
    _previous = FocusManager.instance.primaryFocus;
    FocusManager.instance.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final previous = _previous;
    final focus = FocusManager.instance.primaryFocus;
    _previous = focus;
    if (focus == null || identical(focus, previous)) return;
    if (!selectAllOnTimeFieldFocus(defaultTargetPlatform, isWeb: kIsWeb)) return;
    // Rückkehr ins Fenster: Der Desktop-FocusManager parkt den Fokus beim inaktiven Fenster
    // auf rootScope und holt ihn danach zurück. Dann bleibt die Auswahl, wie sie war.
    if (previous == null || identical(previous, FocusManager.instance.rootScope)) return;
    final ctx = focus.context;
    if (ctx == null || !ctx.mounted) return;
    if (ctx.findAncestorStateOfType<_SelectAllOnFocusState>() != this) return;
    if (ctx.findAncestorWidgetOfExactType<EditableText>() == null) return;
    Actions.maybeInvoke(ctx, const SelectAllTextIntent(SelectionChangedCause.keyboard));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
