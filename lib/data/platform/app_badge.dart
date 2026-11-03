import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

import '../../core/app_log.dart';
import '../../core/platform_info.dart';
import '../sync/activity_notifier.dart';
import 'linux_launcher_badge.dart' if (dart.library.js_interop) 'web/linux_launcher_badge_stub.dart';

/// Zahl am App-Symbol (#254, E-88): dieselbe Zahl wie am Chat-Tab (`unreadCount`), entprellt.
///
/// * iOS: `setBadgeCount` (ab iOS 16, sonst `applicationIconBadgeNumber`); braucht die Freigabe „Kennzeichen“.
/// * macOS: Zahl am Dock-Symbol, ohne Berechtigung.
/// * Windows: Overlay-Symbol in der Taskleiste.
/// * Linux: Unity-LauncherEntry über D-Bus.
/// * Android: kein öffentliches API ohne Meldung; der Launcher zeigt Punkt/Zahl an der Chat-Meldung.
/// * Web: keins.
class PlatformAppBadge implements AppBadge {
  PlatformAppBadge({this.debounce = const Duration(milliseconds: 500), @visibleForTesting this.sink, this.supportedOverride});

  /// Test: ersetzt Kanal bzw. D-Bus.
  final Future<void> Function(int count)? sink;
  /// Test: Plattform unterstützt die Zahl (sonst nach Plattform).
  final bool? supportedOverride;

  static const MethodChannel _channel = MethodChannel('de.inneso.familynexus/window');

  final Duration debounce;
  Timer? _timer;
  int? _applied;
  LinuxLauncherBadge? _linux;

  bool get supported =>
      supportedOverride ?? (PlatformInfo.isIOS || PlatformInfo.isMacOS || PlatformInfo.isWindows || PlatformInfo.isLinux);

  @override
  void update(int count) {
    if (!supported) return;
    _timer?.cancel();
    _timer = Timer(debounce, () => _apply(count < 0 ? 0 : count).ignore());
  }

  /// Sofort auf 0 (Abmelden, lokale Löschung).
  Future<void> clear() async {
    _timer?.cancel();
    if (supported) await _apply(0);
  }

  Future<void> _apply(int count) async {
    if (count == _applied) return;
    try {
      final test = sink;
      if (test != null) {
        await test(count);
      } else if (PlatformInfo.isLinux) {
        await (_linux ??= LinuxLauncherBadge()).set(count);
      } else {
        await _channel.invokeMethod<void>('setBadge', count);
      }
      _applied = count;
    } catch (e) {
      AppLog.w('badge', 'Zahl am App-Symbol nicht gesetzt (${e.runtimeType})');
    }
  }
}
