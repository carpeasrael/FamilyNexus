part of '../home_shell.dart';

/// Burger-Menü rechts oben: öffnet das Seitenmenü des umgebenden Gerüsts.
class _MenuButton extends StatelessWidget {
  const _MenuButton();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Builder(
      builder: (context) => IconButton(
        tooltip: l.menuOpen,
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openEndDrawer(),
      ),
    );
  }
}

/// Die Familiendienste ließen sich nicht öffnen: Fehlertext, „Erneut versuchen“ und das eingeschränkte Menü (#153).
class _OpenFailed extends StatelessWidget {
  const _OpenFailed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.appName),
        actions: const <Widget>[_MenuButton()],
      ),
      endDrawer: const _MenuDrawer(limited: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(l.homeOpenFailed, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l.retry)),
          ]),
        ),
      ),
    );
  }
}

/// Platz links neben dem Inhalt: seitliche Rail (ab mittlerer Breite) oder nichts. Eigene Fokusgruppe.
class _SideRail extends StatelessWidget {
  const _SideRail({required this.compact, required this.selected, required this.onSelect, required this.destinations});
  final bool compact;
  final int selected;
  final ValueChanged<int> onSelect;
  final List<({Widget icon, String label})> destinations;

  @override
  Widget build(BuildContext context) {
    if (compact) return const SizedBox.shrink();
    return FocusTraversalGroup(
      child: NavigationRail(
        key: mainNavigationKey,
        selectedIndex: selected,
        onDestinationSelected: onSelect,
        labelType: NavigationRailLabelType.all,
        scrollable: true,
        minWidth: kRailWidth,
        destinations: <NavigationRailDestination>[
          for (final d in destinations) NavigationRailDestination(icon: d.icon, label: Text(d.label)),
        ],
      ),
    );
  }
}

/// Die fünf Seiten in einem Stack mit fester Reihenfolge und ohne GlobalKeys: je Seite ändern sich nur Rechteck und
/// Sichtbarkeit (E-92). Eigene Fokusgruppe: Tab geht erst durch den Inhalt, nicht quer über die Rail (Lesereihenfolge
/// nach Lage).
class _PaneStack extends StatelessWidget {
  const _PaneStack({required this.pages, required this.index, required this.split, required this.twoPane, required this.listWidth});
  final List<Widget> pages;
  final int index;

  /// Kalender und Chat stehen nebeneinander (Tab Kalender oder Chat im Zweispalter).
  final bool split;
  final bool twoPane;
  final double listWidth;

  static const int _calendarTab = _HomeShellState._calendarTab;
  static const int _chatTab = _HomeShellState._chatTab;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      child: LayoutBuilder(builder: (context, box) {
        final panes = paneWidths(box.maxWidth);
        Rect rect(int i) {
          if (twoPane && i == _calendarTab) return Rect.fromLTWH(0, 0, panes.calendar, box.maxHeight);
          if (twoPane && i == _chatTab) {
            return Rect.fromLTWH(panes.calendar + kPaneDivider, 0, panes.chat, box.maxHeight);
          }
          return Rect.fromLTWH(0, 0, box.maxWidth, box.maxHeight);
        }

        bool visible(int i) => i == index || (split && (i == _calendarTab || i == _chatTab));
        return Stack(fit: StackFit.expand, children: <Widget>[
          for (var i = 0; i < pages.length; i++)
            Positioned.fromRect(
              rect: rect(i),
              child: Offstage(
                offstage: !visible(i),
                child: ExcludeFocus(
                  excluding: !visible(i),
                  child: (i == _calendarTab || i == _chatTab) ? pages[i] : ContentWidth(maxWidth: listWidth, child: pages[i]),
                ),
              ),
            ),
          Positioned(
            left: panes.calendar,
            top: 0,
            bottom: 0,
            width: kPaneDivider,
            child: Offstage(offstage: !split, child: const VerticalDivider(width: kPaneDivider, thickness: kPaneDivider)),
          ),
        ]);
      }),
    );
  }
}
