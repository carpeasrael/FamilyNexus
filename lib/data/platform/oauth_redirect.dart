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
///   „Loopback“). Er nimmt genau einen Aufruf von `/oauth` an und schließt sich danach.
///
/// Der Inhalt des Rücksprungs ist nicht vertrauenswürdig; die Prüfung von `state` und Code erfolgt im
/// Gateway.
abstract class OAuthRedirect {
  /// Bereitet einen Rücksprung vor und liefert die Rücksprungadresse.
  Future<Uri> prepare();

  /// Wartet auf den Rücksprung (höchstens [timeout]); `null` bei Abbruch oder Zeitüberschreitung.
  Future<Uri?> wait({Duration timeout = const Duration(minutes: 10)});

  /// Beendet das Warten (z. B. „Abbrechen“).
  void cancel();

  /// Passende Umsetzung für die Plattform; `null` im Browser (dort keine OAuth-Anmeldung, E-55).
  static OAuthRedirect? forPlatform(LinkSource links) {
    if (PlatformInfo.isWeb) return null;
    return PlatformInfo.isMobile ? AppLinkOAuthRedirect(links) : LoopbackOAuthRedirect();
  }
}

/// Rücksprung über das App-Schema (Mobilgeräte).
class AppLinkOAuthRedirect implements OAuthRedirect {
  AppLinkOAuthRedirect(this._links);

  final LinkSource _links;
  Completer<Uri?>? _done;
  StreamSubscription<String>? _sub;

  static bool isCallback(String raw) => raw.startsWith('${SdkMatrixGateway.oauthScheme}:/oauth');

  @override
  Future<Uri> prepare() async {
    cancel();
    final done = _done = Completer<Uri?>();
    _sub = _links.links.where(isCallback).listen((raw) {
      if (!done.isCompleted) done.complete(Uri.tryParse(raw));
    });
    return SdkMatrixGateway.oauthMobileRedirect;
  }

  @override
  Future<Uri?> wait({Duration timeout = const Duration(minutes: 10)}) async {
    final done = _done;
    if (done == null) return null;
    try {
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await _sub?.cancel();
      _sub = null;
    }
  }

  @override
  void cancel() {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(null);
    _sub?.cancel().ignore();
    _sub = null;
  }
}

/// Rücksprung über einen lokalen Empfänger (Desktop).
class LoopbackOAuthRedirect implements OAuthRedirect {
  HttpServer? _server;
  Completer<Uri?>? _done;

  /// Kurze Seite für den Browser nach dem Rücksprung (ohne Inhalte des Rücksprungs).
  static const String _page = '<!doctype html><meta charset="utf-8"><title>FamilyNexus</title>'
      '<body style="font-family:sans-serif;padding:2rem">'
      '<h1>Fertig</h1><p>Du kannst dieses Fenster schließen und zu FamilyNexus zurückkehren.</p>'
      '<p lang="en">Done – you can close this window and return to FamilyNexus.</p></body>';

  @override
  Future<Uri> prepare() async {
    cancel();
    final server = _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final done = _done = Completer<Uri?>();
    server.listen((req) {
      if (req.method != 'GET' || req.uri.path != '/oauth' || done.isCompleted) {
        req.response.statusCode = HttpStatus.notFound;
        req.response.close().ignore();
        return;
      }
      req.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..headers.set('cache-control', 'no-store')
        ..write(_page);
      req.response.close().ignore();
      done.complete(Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/oauth', query: req.uri.query));
    }, onError: (Object e) => AppLog.w('oauth', 'Rücksprung-Empfänger meldet einen Fehler'));
    return Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: '/oauth');
  }

  @override
  Future<Uri?> wait({Duration timeout = const Duration(minutes: 10)}) async {
    final done = _done;
    if (done == null) return null;
    try {
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      await _server?.close(force: true);
      _server = null;
    }
  }

  @override
  void cancel() {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(null);
    _server?.close(force: true).ignore();
    _server = null;
  }
}
