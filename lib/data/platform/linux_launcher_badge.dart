import 'package:dbus/dbus.dart';

/// Zahl am Starter-Symbol unter Linux über das Signal `com.canonical.Unity.LauncherEntry.Update` (#254, E-88).
/// Wirkt in KDE Plasma, im Ubuntu-Dock und in Dash-to-Dock; GNOME ohne Erweiterung zeigt nichts. Fehlt der
/// Sitzungsbus oder lässt die Flatpak-Sandbox das Signal nicht durch, geschieht stumm nichts.
class LinuxLauncherBadge {
  LinuxLauncherBadge({this.desktopId = 'de.inneso.familynexus.desktop', this.client});

  final String desktopId;

  /// Sitzungsbus; wird beim ersten Setzen geöffnet (Test: eigener Bus).
  DBusClient? client;

  static final DBusObjectPath _path = DBusObjectPath('/de/inneso/familynexus/launcher');

  Future<void> set(int count) async {
    final c = client ??= DBusClient.session();
    await c.emitSignal(
      path: _path,
      interface: 'com.canonical.Unity.LauncherEntry',
      name: 'Update',
      values: <DBusValue>[
        DBusString('application://$desktopId'),
        DBusDict.stringVariant(<String, DBusValue>{
          'count': DBusInt64(count),
          'count-visible': DBusBoolean(count > 0),
        }),
      ],
    );
  }

  Future<void> close() async {
    final c = client;
    client = null;
    await c?.close();
  }
}
