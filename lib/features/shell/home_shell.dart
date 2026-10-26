import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/app_version.dart';
import '../../domain/permissions.dart';
import '../../l10n/gen/app_localizations.dart';
import '../calendar/calendar_screen.dart';
import '../chat/chat_screen.dart';
import '../family/family_screen.dart';
import '../settings/privacy_screen.dart';
import '../settings/settings_screen.dart';
import '../shopping/shopping_screen.dart';
import '../tasks/tasks_screen.dart';
import '../today/today_screen.dart';

/// Hauptgerüst mit fünf Bereichen; Einstellungen liegen im Menü oben rechts.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const int _chatTab = 2;
  static const int _shoppingTab = 3;
  int _index = 0;
  late final Future<void> _opening;
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

  /// Ein Gespräch soll geöffnet werden (z. B. „Nachricht schreiben“): zum Chat wechseln.
  void _chatRequested() {
    if (_services.chatRequest.value != null && mounted) setState(() => _index = _chatTab);
  }

  @override
  void dispose() {
    _services.chatRequest.removeListener(_chatRequested);
    WidgetsBinding.instance.removeObserver(this);
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
        if (snap.connectionState != ConnectionState.done || services.calendar == null) {
          return Scaffold(body: Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator())));
        }
        final pages = <Widget>[
          TodayScreen(onOpenChat: () => setState(() => _index = _chatTab), onOpenShopping: () => setState(() => _index = _shoppingTab)),
          const CalendarScreen(),
          ChatScreen(active: _index == _chatTab),
          const ShoppingScreen(),
          const FamilyScreen(),
        ];
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_index]),
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
          endDrawer: _MenuDrawer(),
          body: SafeArea(child: IndexedStack(index: _index, children: pages)),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: <NavigationDestination>[
              NavigationDestination(icon: const Icon(Icons.today_outlined), label: l.tabToday),
              NavigationDestination(icon: const Icon(Icons.calendar_month_outlined), label: l.tabCalendar),
              NavigationDestination(
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
              NavigationDestination(icon: const Icon(Icons.shopping_cart_outlined), label: l.tabShopping),
              NavigationDestination(
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
            ],
          ),
        );
      },
    );
  }
}

/// Seitenmenü (Burger-Menü rechts oben).
class _MenuDrawer extends StatelessWidget {
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
        body: const SafeArea(child: SettingsScreen()),
      );
}
