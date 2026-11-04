import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/app_version.dart';
import '../../domain/permissions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../ui/layout/adaptive.dart';
import '../calendar/calendar_screen.dart';
import '../chat/chat_screen.dart';
import '../family/family_screen.dart';
import '../settings/privacy_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/shopping_screen.dart';
import '../tasks/tasks_screen.dart';
import '../today/today_screen.dart';

/// Schlüssel der Hauptnavigation (untere Leiste oder seitliche Rail), für Tests und Bedienhilfen (#274).
const Key mainNavigationKey = ValueKey<String>('main-navigation');

/// Hauptgerüst mit fünf Bereichen; Einstellungen liegen im Menü oben rechts.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const int _chatTab = 2;
  static const int _shoppingTab = 3;
  static const int _calendarTab = 1;
  int _index = 0;

  /// „Alle Termine“ auf „Heute“: Kalender in der Agenda ab heute (#218).
  final ValueNotifier<CalendarMode?> _calendarMode = ValueNotifier<CalendarMode?>(null);

  void _openAgenda() {
    _calendarMode.value = CalendarMode.agenda;
    _calendarMode.value = null;
    setState(() => _index = _calendarTab);
  }
  late Future<void> _opening;
  late final AppServices _services;

  @override
  void initState() {
    super.initState();
    _services = AppScope.read(context);
    _opening = _services.openCalendar();
    _services.chatRequest.addListener(_chatRequested);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nach Rückkehr in die App: Planung auffrischen (Zeit, Zeitzone, Berechtigungen können sich geändert haben).
    if (state == AppLifecycleState.resumed) {
      _services.reminders?.reschedule().ignore();
      _services.presence?.setForeground(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      // „Inaktiv“ (z. B. Benachrichtigungsleiste) zählt noch als Vordergrund.
      _services.presence?.setForeground(false);
    }
  }

  /// Wechselt den Tab. Der Einkaufszettel räumt dabei seine Meldung ab (#254).
  void _go(int i) {
    setState(() => _index = i);
    if (i == _shoppingTab) _services.activity?.clearShopping();
  }

  /// Ein Gespräch soll geöffnet werden (z. B. „Nachricht schreiben“): zum Chat wechseln.
  void _chatRequested() {
    if (_services.chatRequest.value != null && mounted) setState(() => _index = _chatTab);
  }

  @override
  void dispose() {
    _services.chatRequest.removeListener(_chatRequested);
    WidgetsBinding.instance.removeObserver(this);
    _calendarMode.dispose();
    // Synchronisation und Erinnerungen laufen nur, solange die Oberfläche existiert.
    _services.closeCalendar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final titles = <String>[l.tabToday, l.tabCalendar, l.tabChat, l.tabShopping, l.tabFamily];
    return FutureBuilder<void>(
      future: _opening,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && snap.hasError) {
          // Die Familiendienste ließen sich nicht öffnen (z. B. Speicher voll): Menü und Neuversuch bleiben (#153).
          return Scaffold(
            appBar: AppBar(
              title: Text(l.appName),
              actions: <Widget>[
                Builder(
                  builder: (context) => IconButton(
                    tooltip: l.menuOpen,
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                  ),
                ),
              ],
            ),
            endDrawer: const _MenuDrawer(limited: true),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  Text(l.homeOpenFailed, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      final reopening = _services.openCalendar();
                      setState(() {
                        _opening = reopening;
                      });
                    },
                    child: Text(l.retry),
                  ),
                ]),
              ),
            ),
          );
        }
        if (snap.connectionState != ConnectionState.done || services.calendar == null) {
          return Scaffold(body: Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator())));
        }
        // Nutzbare Fläche = Fenster minus sichere Ränder, ohne Tastatur: einmal hier, oberhalb von Scaffold,
        // Leiste und AppBar. So hängt die Klasse nicht vom Tippen ab und kippt nicht zurück (E-92).
        final cls = windowClassIn(context);
        final compact = cls == WindowClass.compact;
        final twoPane = cls == WindowClass.expanded;
        // Chat sichtbar = gelesen (E-88, #254): im Zweispalter bei Tab Kalender und Chat, sonst nur bei Tab Chat.
        final chatVisible = _index == _chatTab || (twoPane && _index == _calendarTab);
        final pages = <Widget>[
          TodayScreen(
            onOpenChat: () => setState(() => _index = _chatTab),
            onOpenShopping: () => _go(_shoppingTab),
            onOpenAgenda: _openAgenda,
          ),
          CalendarScreen(modeRequest: _calendarMode),
          ChatScreen(active: chatVisible),
          const ShoppingScreen(),
          const FamilyScreen(),
        ];
        final destinations = _destinations(l, services);
        final listWidth = compact ? double.infinity : kContentMaxWidth;
        return Scaffold(
          appBar: AppBar(
            title: Text(twoPane && (_index == _calendarTab || _index == _chatTab) ? l.tabCalendarAndChat : titles[_index]),
            actions: <Widget>[
              // Burger-Menü rechts oben: Einstellungen und Datenschutz.
              Builder(
                builder: (context) => IconButton(
                  tooltip: l.menuOpen,
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          endDrawer: const _MenuDrawer(),
          // Ein Gerüst für alle Klassen. Der Elementbaum unter [Expanded] bleibt bei jedem Klassenwechsel gleich;
          // nur der Platz links (Leiste oder nichts) und die Rechtecke der Seiten ändern sich.
          body: SafeArea(
            child: Row(children: <Widget>[
              compact
                  ? const SizedBox.shrink()
                  : NavigationRail(
                      key: mainNavigationKey,
                      selectedIndex: _index,
                      onDestinationSelected: _go,
                      labelType: NavigationRailLabelType.all,
                      scrollable: true,
                      minWidth: kRailWidth,
                      destinations: <NavigationRailDestination>[
                        for (final d in destinations) NavigationRailDestination(icon: d.icon, label: Text(d.label)),
                      ],
                    ),
              Expanded(
                child: LayoutBuilder(builder: (context, box) {
                  final panes = paneWidths(box.maxWidth);
                  Rect rect(int i) {
                    if (twoPane && i == _calendarTab) return Rect.fromLTWH(0, 0, panes.calendar, box.maxHeight);
                    if (twoPane && i == _chatTab) {
                      return Rect.fromLTWH(panes.calendar + kPaneDivider, 0, panes.chat, box.maxHeight);
                    }
                    return Rect.fromLTWH(0, 0, box.maxWidth, box.maxHeight);
                  }

                  bool visible(int i) => i == _index || (twoPane && (_index == _calendarTab || _index == _chatTab) && (i == _calendarTab || i == _chatTab));
                  // Ein Stack, feste Reihenfolge, keine GlobalKeys: je Seite ändern sich nur Rechteck und Sichtbarkeit.
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
                      child: Offstage(offstage: !twoPane, child: const VerticalDivider(width: kPaneDivider, thickness: kPaneDivider)),
                    ),
                  ]);
                }),
              ),
            ]),
          ),
          bottomNavigationBar: compact
              ? NavigationBar(
                  key: mainNavigationKey,
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  destinations: <NavigationDestination>[
                    for (final d in destinations) NavigationDestination(icon: d.icon, label: d.label),
                  ],
                )
              : null,
        );
      },
    );
  }

  /// Die fünf Ziele; Leiste und Rail zeigen dieselben, mit denselben Meldungen (Badges).
  List<({Widget icon, String label})> _destinations(AppLocalizations l, AppServices services) => <({Widget icon, String label})>[
        (icon: const Icon(Icons.today_outlined), label: l.tabToday),
        (icon: const Icon(Icons.calendar_month_outlined), label: l.tabCalendar),
        (
          icon: ListenableBuilder(
            listenable: services.gateway,
            builder: (context, _) => Badge(
              isLabelVisible: services.gateway.unreadCount > 0,
              label: Text('${services.gateway.unreadCount}'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
          ),
          label: l.tabChat,
        ),
        (icon: const Icon(Icons.shopping_cart_outlined), label: l.tabShopping),
        (
          icon: ListenableBuilder(
            listenable: services.gateway,
            builder: (context, _) {
              // Offene Beitrittsanfragen: nur Moderatoren können sie entscheiden.
              final f = services.gateway.family;
              final open = f != null && Permissions.isModerator(f) ? f.requests.length : 0;
              return Badge(
                isLabelVisible: open > 0,
                label: Text('$open'),
                child: Semantics(label: open > 0 ? l.tabFamilyRequests(open) : null, child: const Icon(Icons.groups_outlined)),
              );
            },
          ),
          label: l.tabFamily,
        ),
      ];
}

/// Seitenmenü (Burger-Menü rechts oben).
class _MenuDrawer extends StatelessWidget {
  const _MenuDrawer({this.limited = false});

  /// Ohne Familiendienste (Fehleransicht): kein Eintrag, der sie braucht.
  final bool limited;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    void open(Widget page) {
      final nav = Navigator.of(context);
      nav.pop(); // Menü schließen
      nav.push(MaterialPageRoute<void>(builder: (_) => page));
    }

    return Drawer(
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Semantics(header: true, child: Text(l.menuTitle, style: Theme.of(context).textTheme.titleLarge)),
          ),
          if (!limited)
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: Text(l.tasksTitle),
              onTap: () => open(const TasksScreen()),
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(l.tabSettings),
            onTap: () => open(const _SettingsPage()),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.settingsPrivacyPolicy),
            onTap: () => open(const PrivacyScreen()),
          ),
          const Spacer(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l.menuVersion(appVersionWithBuild),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Einstellungen als eigene Seite (mit Zurück-Pfeil).
class _SettingsPage extends StatelessWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).tabSettings)),
        body: const SafeArea(child: ContentWidth(child: SettingsScreen())),
      );
}
