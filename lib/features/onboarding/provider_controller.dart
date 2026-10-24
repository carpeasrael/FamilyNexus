import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/matrix/matrix_gateway.dart';
import '../../domain/registration.dart';
import '../../domain/server.dart';
import '../settings/settings_controller.dart';

/// `empty`: eigener Anbieter gewählt, aber noch keine Adresse eingegeben.
enum ProviderStatus { empty, checking, ready, invalid, failed }

/// Gewählter Anbieter (Homeserver) in der Einrichtung (E-55). Die Prüfung läuft automatisch: für den
/// Standard bzw. den Anbieter aus der Einladung sofort, für eine eigene Eingabe nach kurzer Pause.
/// Ergebnis sind Erreichbarkeit, Betreiberangaben und der Weg zur Kontoanlage.
class ProviderController extends ChangeNotifier {
  ProviderController({
    required this.gateway,
    required this.settings,
    ServerUrl? initial,
    this.debounce = const Duration(milliseconds: 800),
  }) : _standard = initial ?? ServerUrl.tryParse(settings.settings.serverUrl)!;

  final MatrixGateway gateway;
  final SettingsController settings;
  final Duration debounce;

  ServerUrl _standard;
  bool _custom = false;
  String _customText = '';
  ProviderStatus _status = ProviderStatus.checking;
  ServerInfo? _info;
  RegistrationOptions? _options;
  GatewayError? _error;
  Timer? _timer;
  int _run = 0;
  bool _started = false;
  bool _disposed = false;

  /// Anbieter aus der Einladung oder den Einstellungen (ohne eigene Eingabe).
  ServerUrl get standard => _standard;
  bool get custom => _custom;
  String get customText => _customText;
  ProviderStatus get status => _status;
  ServerInfo? get info => _info;
  RegistrationOptions? get options => _options;
  GatewayError? get error => _error;

  /// Aktuell gewählter Anbieter (`null` bei ungültiger eigener Eingabe).
  ServerUrl? get server => _custom ? ServerUrl.tryParse(_customText) : _standard;

  bool get ready => _status == ProviderStatus.ready && _info != null;
  bool get usesOAuth => _info?.usesOAuth ?? false;
  RegistrationMode? get mode => _options?.mode;

  /// Erste Prüfung des Standard-Anbieters.
  void start() {
    _started = true;
    _check(immediate: true);
  }

  /// Wechselt auf einen fest vorgegebenen Anbieter (z. B. aus `@anna:beispiel.de` oder der Einladung).
  void useStandard(ServerUrl url) {
    if (_started && !_custom && url == _standard && _status != ProviderStatus.failed) return;
    _standard = url;
    _custom = false;
    start();
  }

  void setCustom(bool on) {
    if (on == _custom) return;
    _custom = on;
    _check(immediate: !on);
  }

  void setCustomText(String text) {
    _customText = text;
    _check(immediate: false);
  }

  /// Erneut prüfen (z. B. „Nochmal versuchen“ nach einem Netzfehler).
  void retry() => _check(immediate: true);

  void _check({required bool immediate}) {
    _timer?.cancel();
    final run = ++_run;
    _info = null;
    _options = null;
    _error = null;
    final url = server;
    if (url == null) {
      _status = _custom && _customText.trim().isEmpty ? ProviderStatus.empty : ProviderStatus.invalid;
      _notify();
      return;
    }
    _status = ProviderStatus.checking;
    _notify();
    if (immediate) {
      unawaited(_probe(url, run));
    } else {
      _timer = Timer(debounce, () => unawaited(_probe(url, run)));
    }
  }

  Future<void> _probe(ServerUrl url, int run) async {
    try {
      final info = await gateway.probeServer(url);
      // Vorübergehende Fehler (Netz, Überlastung) melden wie bei der Serverprüfung – mit „Erneut
      // versuchen“ statt eines falschen „kein Konto möglich“.
      final options = await gateway.registrationOptions(url);
      if (run != _run || _disposed) return;
      _info = info;
      _options = options;
      _status = ProviderStatus.ready;
      await settings.update((c) => c.copyWith(serverUrl: url.toString()));
    } on GatewayException catch (e) {
      if (run != _run || _disposed) return;
      _error = e.error;
      _status = ProviderStatus.failed;
    } catch (_) {
      if (run != _run || _disposed) return;
      _error = GatewayError.unknown;
      _status = ProviderStatus.failed;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
