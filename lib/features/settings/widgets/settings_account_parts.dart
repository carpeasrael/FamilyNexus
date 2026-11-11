part of '../settings_screen.dart';

class _AccountSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final gateway = AppScope.of(context).gateway;
    return ListenableBuilder(
      listenable: gateway,
      builder: (context, _) => _Section(title: l.settingsAccount, children: <Widget>[
        ListTile(title: Text(l.settingsServer), subtitle: Text(gateway.server?.host ?? '–')),
        ListTile(title: Text(l.accountUsername), subtitle: Text(gateway.userId ?? '–')),
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(l.passwordChangeTitle),
          onTap: () => changePassword(context),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l.logout),
          onTap: () async {
            final services = AppScope.read(context);
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(l.logout),
                content: Text(l.logoutBody),
                actions: <Widget>[
                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: Text(l.logout)),
                ],
              ),
            );
            if (ok == true) await services.logout();
          },
        ),
        // Apple 5.1.1(v): Wer in der App ein Konto anlegen kann, muss es hier auch löschen können (#12).
        ListTile(
          leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(l.accountDelete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          subtitle: Text(l.accountDeleteHint),
          onTap: () => deleteAccount(context),
        ),
      ]),
    );
  }
}

class _SecuritySection extends StatefulWidget {
  @override
  State<_SecuritySection> createState() => _SecuritySectionState();
}

class _SecuritySectionState extends State<_SecuritySection> {
  @override
  void initState() {
    super.initState();
    // Geräteliste beim Öffnen auffrischen.
    _actions(context).refreshSecurity();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final g = AppScope.of(context).gateway;
    return ListenableBuilder(
      listenable: g,
      builder: (context, _) {
        final ready = g.securityState == SecurityState.ready;
        return _Section(title: l.securityTitle, children: <Widget>[
          ListTile(
            leading: Icon(ready ? Icons.verified_outlined : Icons.warning_amber_outlined),
            title: Text(ready ? l.securityStatusReady : l.securityStatusNeeds),
          ),
          // Nur ein verifiziertes Gerät kann einen neuen Notfall-Schlüssel erstellen (#11).
          if (ready)
            ListTile(
              leading: const Icon(Icons.key_outlined),
              title: Text(l.keyRenew),
              subtitle: Text(l.securityKeyRenewHint),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RecoveryKeyRenewScreen())),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(l.securityDevices, style: Theme.of(context).textTheme.titleSmall),
          ),
          for (final d in g.devices)
            ListTile(
              dense: true,
              title: Text(d.isCurrent ? '${d.name} (${l.securityDeviceThis})' : d.name),
              subtitle: Text(d.verified ? l.securityDeviceVerified : l.securityDeviceUnverified),
              leading: Icon(d.verified ? Icons.check_circle_outline : Icons.help_outline),
              trailing: (!d.isCurrent && !d.verified)
                  ? TextButton(
                      onPressed: () async {
                        final m = ScaffoldMessenger.of(context);
                        final error = await _actions(context).verifyDevice(d);
                        if (error != null) m.showSnackBar(SnackBar(content: Text(errorText(l, error))));
                      },
                      child: Text(l.securityVerifyDevice),
                    )
                  : null,
            ),
        ]);
      },
    );
  }
}

class _LockTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final services = AppScope.of(context);
    final settings = services.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings.settings;
        return Column(children: <Widget>[
          SwitchListTile(
            title: Text(l.settingsLock),
            subtitle: Text(l.settingsLockHint),
            value: s.lockEnabled,
            onChanged: (v) async {
              final messenger = ScaffoldMessenger.of(context);
              final available = await services.lock.auth.isAvailable();
              if (v && !available) {
                messenger.showSnackBar(SnackBar(content: Text(l.settingsLockUnavailable)));
                return;
              }
              final ok = await services.lock.setEnabled(v, l.lockReason);
              if (!ok) messenger.showSnackBar(SnackBar(content: Text(l.settingsLockFailed)));
            },
          ),
          if (s.lockEnabled)
            _DropdownTile<int>(
              label: l.settingsLockTimeout,
              value: const <int>[0, 60, 300, 900].contains(s.lockTimeoutSeconds) ? s.lockTimeoutSeconds : 60,
              items: <int, String>{0: l.lockImmediately, 60: l.lock1min, 300: l.lock5min, 900: l.lock15min},
              onChanged: (v) => settings.update((c) => c.copyWith(lockTimeoutSeconds: v)),
            ),
        ]);
      },
    );
  }
}

/// Speicherorte der lokalen Daten (Pfade zum Markieren und Kopieren) und der Online-Anbieter.
class _StorageTiles extends StatefulWidget {
  @override
  State<_StorageTiles> createState() => _StorageTilesState();
}

class _StorageTilesState extends State<_StorageTiles> {
  Future<StorageLocations>? _locations;

  @override
  void initState() {
    super.initState();
    _locations = _actions(context).storageLocations();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final server = AppScope.of(context).gateway.server?.toString();
    return FutureBuilder<StorageLocations>(
      future: _locations,
      builder: (context, snap) {
        final loc = snap.data;
        Widget tile(String title, String value) => ListTile(
              dense: true,
              title: Text(title),
              subtitle: SelectableText(value),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(l.settingsStorageTitle, style: Theme.of(context).textTheme.titleSmall),
          ),
          if (loc != null) ...<Widget>[
            tile(l.settingsStorageDbDir, loc.inBrowser ? l.settingsStorageBrowser : loc.databaseDirectory),
            tile(l.settingsStorageAppDb, loc.appDatabase),
            tile(l.settingsStorageMatrixDb, loc.matrixDatabase),
            tile(l.settingsStorageKeys, DataReport.keyStoreText(l, loc.keyStore)),
          ],
          if (server != null) tile(l.settingsStorageOnline, server),
        ]);
      },
    );
  }
}
