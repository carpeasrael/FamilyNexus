import 'package:flutter/foundation.dart';

import '../../data/platform/device_auth.dart';
import '../settings/settings_controller.dart';

/// Optionale App-Sperre (E-17): Beim Start und nach Inaktivität im Hintergrund wird die
/// Oberfläche verdeckt, bis das Gerät die Anmeldedaten (PIN/Muster/Passwort/Biometrie) bestätigt.
class AppLockController extends ChangeNotifier {
  AppLockController({
    required this.settings,
    required this.auth,
    DateTime Function()? clock,
    Duration Function()? monotonic,
  })  : _clock = clock ?? DateTime.now,
        _monotonic = monotonic ?? _stopwatchElapsed,
        _locked = settings.settings.lockEnabled;

  final SettingsController settings;
  final DeviceAuth auth;
  final DateTime Function() _clock;

  /// Monotone Uhr: lässt sich nicht verstellen, steht aber je nach System still, solange das Gerät schläft.
  final Duration Function() _monotonic;
  static final Stopwatch _stopwatch = Stopwatch()..start();
  static Duration _stopwatchElapsed() => _stopwatch.elapsed;

  bool _locked;
  bool _authenticating = false;
  DateTime? _backgroundedAt;
  Duration? _backgroundedMono;

  bool get locked => _locked;
  bool get authenticating => _authenticating;

  /// Die App geht in den Hintergrund.
  void onPaused() {
    // Der System-Dialog selbst löst Zustandswechsel aus; sie zählen nicht als Inaktivität.
    if (_authenticating) return;
    _backgroundedAt = _clock();
    _backgroundedMono = _monotonic();
  }

  /// Die App kommt zurück: sperren, wenn die Auszeit überschritten ist.
  void onResumed() {
    if (_authenticating) return;
    final s = settings.settings;
    final since = _backgroundedAt;
    final sinceMono = _backgroundedMono;
    _backgroundedAt = null;
    _backgroundedMono = null;
    if (!s.lockEnabled || _locked || since == null || sinceMono == null) return;
    // Beide Uhren zählen (Pen-Test I-05): Die Wanduhr erfasst den Geräteschlaf, die monotone Uhr ein Zurückstellen
    // der Uhrzeit. Läuft die Wanduhr rückwärts, wird ebenfalls gesperrt.
    final timeout = Duration(seconds: s.lockTimeoutSeconds);
    final wall = _clock().difference(since);
    if (wall >= timeout || wall.isNegative || _monotonic() - sinceMono >= timeout) {
      _locked = true;
      notifyListeners();
    }
  }

  /// Sperrt sofort (z. B. nach Aktivierung durch den Nutzer nicht nötig; für Tests/künftige Nutzung).
  void lockNow() {
    if (!settings.settings.lockEnabled || _locked) return;
    _locked = true;
    notifyListeners();
  }

  /// Fragt die Geräteanmeldedaten ab; bei Erfolg wird entsperrt.
  Future<bool> unlock(String reason) async {
    if (!_locked || _authenticating) return !_locked;
    _authenticating = true;
    notifyListeners();
    try {
      final ok = await auth.authenticate(reason);
      if (ok) _locked = false;
      return ok;
    } finally {
      _authenticating = false;
      notifyListeners();
    }
  }

  /// Aktiviert die Sperre erst nach erfolgreicher Bestätigung (kein Aussperren durch Fehlbedienung);
  /// deaktivieren verlangt ebenfalls die Geräteanmeldedaten.
  Future<bool> setEnabled(bool enable, String reason) async {
    if (enable && !await auth.isAvailable()) return false;
    _authenticating = true;
    try {
      if (!await auth.authenticate(reason)) return false;
    } finally {
      _authenticating = false;
    }
    final ok = await settings.update((s) => s.copyWith(lockEnabled: enable));
    if (ok && !enable) {
      _locked = false;
      notifyListeners();
    }
    return ok;
  }
}
