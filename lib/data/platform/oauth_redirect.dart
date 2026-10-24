import 'dart:async';
import 'dart:io';

import '../../core/app_log.dart';
import '../../core/platform_info.dart';
import '../matrix/sdk_matrix_gateway.dart';
import 'link_source.dart';

/// Empfängt den Rücksprung nach der Anmeldung im Browser (OAuth, E-55).
///
/// * Android/iOS: eigenes App-Schema (`io.github.carpeasrael.familynexus:/oauth`), zugestellt über
///   die [LinkSource].
/// * Linux/Windows/macOS: kurzlebiger Empfänger auf `127.0.0.1` mit zufälligem Port (MSC2966,
///   „Loopback“), der bis zum Ende des Versuchs Aufrufe von `/oauth` annimmt.
///
/// Jeder Versuch ist ein eigenes [OAuthAttempt]: ein neuer Versuch beendet den alten, ein alter kann
/// den neuen nie beeinflussen. Rücksprünge sind nicht vertrauenswürdig; ob einer zum Versuch gehört
/// (`state`), prüft das Gateway – unpassende werden verworfen und es wird weiter gewartet.
abstract class OAuthRedirect {
  /// Beginnt einen neuen Versuch (ein laufender wird beendet).
  Future<OAuthAttempt> prepare();

  /// Beendet den laufenden Versuch (z. B. „Abbrechen“, „Zurück“).
  void cancel();

  /// Passende Umsetzung für die Plattform; `null` im Browser (dort keine OAuth-Anmeldung, E-55).
  static OAuthRedirect? forPlatform(LinkSource links) {
    if (PlatformInfo.isWeb) return null;
    return PlatformInfo.isMobile ? AppLinkOAuthRedirect(links) : LoopbackOAuthRedirect();
  }
}

/// Ein Anmeldeversuch: Rücksprungadresse und eingehende Rücksprünge.
abstract class OAuthAttempt {
  Uri get redirectUri;

  /// Nächster Rücksprung; `null` nach [cancel] oder wenn bis [deadline] keiner kam.
  Future<Uri?> next({required DateTime deadline});

  void cancel();
}

/// Gemeinsame Warteschlange der Versuche.
class _Queue implements OAuthAttempt {
  _Queue(this.redirectUri, {this.onClose});

  @override
  final Uri redirectUri;
  final void Function()? onClose;
  final List<Uri> _items = <Uri>[];
  Completer<void>? _signal;
  bool _closed = false;

  bool get closed => _closed;

  void add(Uri u) {
    if (_closed) return;
    _items.add(u);
    final s = _signal;
    if (s != null && !s.isCompleted) s.complete();
  }

  @override
  Future<Uri?> next({required DateTime deadline}) async {
    while (!_closed) {
      if (_items.isNotEmpty) return _items.removeAt(0);
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return null;
      final s = _signal = Completer<void>();
      await s.future.timeout(left, onTimeout: () {});
    }
    return null;
  }

  @override
  void cancel() {
    if (_closed) return;
    _closed = true;
    final s = _signal;
    if (s != null && !s.isCompleted) s.complete();
    onClose?.call();
  }
}

/// Rücksprung über das App-Schema (Mobilgeräte).
class AppLinkOAuthRedirect implements OAuthRedirect {
  AppLinkOAuthRedirect(this._links);

  final LinkSource _links;
  _Queue? _current;

  static bool isCallback(String raw) => raw.startsWith('${SdkMatrixGateway.oauthScheme}:/oauth');

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    late final StreamSubscription<String> sub;
    final q = _current = _Queue(SdkMatrixGateway.oauthMobileRedirect, onClose: () => sub.cancel().ignore());
    sub = _links.links.where(isCallback).listen((raw) {
      final u = Uri.tryParse(raw);
      if (u != null) q.add(u);
    });
    return q;
  }

  @override
  void cancel() => _current?.cancel();
}

/// Rücksprung über einen lokalen Empfänger (Desktop).
class LoopbackOAuthRedirect implements OAuthRedirect {
  _Queue? _current;

  /// Kurze Seite für den Browser nach dem Rücksprung (ohne Inhalte des Rücksprungs).
  static const String _page = '<!doctype html><meta charset="utf-8"><title>FamilyNexus</title>'
      '<body style="font-family:sans-serif;padding:2rem">'
      '<h1>Fertig</h1><p>Du kannst dieses Fenster schließen und zu FamilyNexus zurückkehren.</p>'
      '<p lang="en">Done – you can close this window and return to FamilyNexus.</p></body>';

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final q = _current = _Queue(
      Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/oauth'),
      onClose: () => server.close(force: true).ignore(),
    );
    server.listen((req) async {
      if (req.method != 'GET' || req.uri.path != '/oauth' || q.closed) {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close().catchError((Object _) {});
        return;
      }
      final callback = Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/oauth', query: req.uri.query);
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('cache-control', 'no-store')
        ..write(_page);
      // Erst die Seite vollständig ausliefern, dann melden (sonst schließt der Empfänger zu früh).
      await req.response.close().catchError((Object _) {});
      q.add(callback);
    }, onError: (Object e) => AppLog.w('oauth', 'Rücksprung-Empfänger meldet einen Fehler'));
    return q;
  }

  @override
  void cancel() => _current?.cancel();
}
