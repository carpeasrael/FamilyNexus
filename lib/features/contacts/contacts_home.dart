part of 'contacts_screen.dart';

/// Schlüssel der Kontakte-Hülle ohne Familie, für Tests und Bedienhilfen (#119, K3c-3).
const Key contactsHomeKey = ValueKey<String>('contacts-home');

/// Die schlanke Hülle für ein Konto **ohne Familie** (#119, K3c-3, E-114, Entscheidung des Nutzers): Gespräche mit
/// Kontakten, Anfragen, „Kontakt hinzufügen“, Einstellungen und Karten für Familieneinladung und Beitrittsanfrage. Es gibt
/// weder Termine noch Einkauf noch Familienchat (keine `HomeShell` mit ausgeblendeten Tabs). `AppRoot` zeigt sie nur nach der
/// ausdrücklichen Wahl „Ohne Familie fortfahren (nur Kontakte)“ (`AppSettings.contactsOnly`) und nie, wenn es eine Familie gibt.
///
/// Familieneinladungen und Beitrittsanfragen werden hier **nie** angenommen oder beantwortet: Die Karten führen zurück in die
/// Einrichtung (Familienschritt), dort läuft Annahme wie bisher (E-49).
class ContactsHome extends StatelessWidget {
  const ContactsHome({super.key});

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final c = services.contacts?.controller;
    final g = services.gateway;
    return Scaffold(
      key: contactsHomeKey,
      appBar: AppBar(
        title: Text(l.contactsTitle),
        automaticallyImplyLeading: false,
        actions: <Widget>[
          if (c != null)
            ListenableBuilder(
              listenable: c,
              builder: (context, _) => c.loaded && c.enabled
                  ? IconButton(tooltip: l.contactsHomeAdd, icon: const Icon(Icons.person_add_alt), onPressed: () => _push(context, AddContactScreen(controller: c)))
                  : const SizedBox.shrink(),
            ),
          if (c != null) IconButton(tooltip: l.chatContactsManage, icon: const Icon(Icons.people_outline), onPressed: () => _push(context, ContactsScreen(controller: c))),
          IconButton(tooltip: l.contactsHomeSettings, icon: const Icon(Icons.settings_outlined), onPressed: () => _push(context, const _ContactsHomeSettings())),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListenableBuilder(
            listenable: Listenable.merge(<Listenable>[g, ?c]),
            builder: (context, _) {
              if (c == null) return const SizedBox.shrink();
              // Solange der erste Abgleich läuft, ist nicht bekannt, ob es doch eine Familie gibt: nichts zeigen.
              if (!g.initialSyncDone) return SyncingView(gateway: g);
              return LayoutBuilder(
                builder: (context, box) => Column(children: <Widget>[
                  // Karten scrollen und sind in der Höhe begrenzt: Bei großer Schrift verdrängen sie die Gespräche nicht.
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: box.maxHeight * 0.45),
                    child: SingleChildScrollView(child: _HomeCards(controller: c)),
                  ),
                  Expanded(
                    child: !c.loaded
                        ? Center(child: Semantics(label: l.contactsLoading, child: const CircularProgressIndicator()))
                        : !c.enabled
                            ? ContactsIntro(onTurnOn: () => c.setEnabled(true).ignore())
                            : const ChatScreen(contactsOnly: true),
                  ),
                ]),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Karten oberhalb der Gespräche: Hinweis „ohne Familie“ mit dem Weg zur Einrichtung, Familieneinladungen, Stand der
/// Beitrittsanfrage und offene Kontaktanfragen. **Keine** Annahme, Ablehnung oder Beantwortung hier.
class _HomeCards extends StatelessWidget {
  const _HomeCards({required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final g = services.gateway;
    final theme = Theme.of(context);
    final List<PendingInvitation> invitations = g.invitations;
    final requests = controller.enabled ? controller.requests.length + controller.requestsHidden : 0;
    final setup = FilledButton(onPressed: () => services.leaveContactsOnly().ignore(), child: Text(l.contactsHomeInviteAction));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Text(l.contactsHomeNoFamily),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(onPressed: () => services.leaveContactsOnly().ignore(), child: Text(l.contactsHomeSetupFamily)),
            ),
          ]),
        ),
        for (final inv in invitations)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Semantics(header: true, child: Text(l.contactsHomeInviteTitle, style: theme.textTheme.titleMedium)),
                const SizedBox(height: 4),
                Text(l.contactsHomeInviteBody(isolateText(inv.roomName), isolateText(inv.inviterLabel))),
                const SizedBox(height: 4),
                // Unerwartete Einladung: die vollständige ID, damit sich Namen nicht vortäuschen lassen (E-49).
                if (!inv.requested) Text(l.invitationUnexpectedWarning(isolateText(inv.inviterId)), style: theme.textTheme.bodySmall),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: setup),
              ]),
            ),
          ),
        if (g.joinRequestPending || g.joinRequestRejected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Semantics(liveRegion: true, child: Text(g.joinRequestRejected ? l.contactsHomeJoinRejected : l.contactsHomeJoinPending)),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: setup),
              ]),
            ),
          ),
        if (requests > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: GlassCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Semantics(header: true, child: Text(l.contactsHomeRequests(requests), style: theme.textTheme.titleMedium)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ContactsScreen(controller: controller))),
                    child: Text(l.contactsHomeRequestsAction),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Einstellungen als eigene Seite der Kontakte-Hülle (mit Zurück-Pfeil).
class _ContactsHomeSettings extends StatelessWidget {
  const _ContactsHomeSettings();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context).tabSettings)),
        body: const SafeArea(child: ContentWidth(child: SettingsScreen())),
      );
}
