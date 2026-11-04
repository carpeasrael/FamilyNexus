import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;

import '../../core/app_log.dart';
import '../matrix/sdk_matrix_gateway.dart';
import 'browser_launcher.dart';
import 'link_source.dart';
import 'web_auth_session.dart';

/// Wie die Anmeldeseite des Anbieters öffnet und der Rücksprung zurückkommt (E-55, E-91).
enum OAuthFlow {
  /// Keine OAuth-Anmeldung (Web-App).
  none,

  /// Anmeldesitzung des Systems (iOS, macOS); der Rücksprung ist ihr Ergebnis.
  authSession,

  /// Custom Tab (Android, Rückfall extern); Rücksprung über das App-Schema.
  customTab,

  /// Externer Browser, Rücksprung über `127.0.0.1` (Linux, Windows).
  loopback,
}

/// Ablauf je Plattform (E-91).
OAuthFlow oauthFlowFor({required bool isWeb, required TargetPlatform platform}) {
  if (isWeb) return OAuthFlow.none;
  return switch (platform) {
    TargetPlatform.iOS || TargetPlatform.macOS => OAuthFlow.authSession,
    TargetPlatform.android => OAuthFlow.customTab,
    TargetPlatform.linux || TargetPlatform.windows || TargetPlatform.fuchsia => OAuthFlow.loopback,
  };
}

/// Empfängt den Rücksprung nach der Anmeldung beim Anbieter (OAuth, E-55, E-91). Drei Arten:
///
/// * [SessionOAuthRedirect] (iOS/macOS): Die Seite öffnet in einer Anmeldesitzung des Systems; deren
///   Ergebnis ist der Rücksprung (`io.github.carpeasrael.familynexus:/oauth`). Eine Sitzung liefert höchstens
///   eine Antwort: Ein Rücksprung mit fremdem `state` beendet den Versuch.
/// * [AppLinkOAuthRedirect] (Android): Die Seite öffnet im Custom Tab (Rückfall extern); der Rücksprung kommt
///   über das App-Schema und die [LinkSource]. Rücksprünge mit fremdem `state` werden verworfen, es wird
///   weiter gewartet.
/// * [LoopbackOAuthRedirect] (Linux/Windows): Die Seite öffnet im externen Browser; ein kurzlebiger
///   Empfänger auf `127.0.0.1` mit zufälligem Port (MSC2966, „Loopback“) nimmt bis zum Ende des Versuchs
///   Aufrufe von `/oauth` an. Fremder `state`: weiter warten.
///
/// Jeder Versuch ist ein eigenes [OAuthAttempt]: ein neuer Versuch beendet den alten, ein alter kann
/// den neuen nie beeinflussen. Rücksprünge sind nicht vertrauenswürdig; ob einer zum Versuch gehört
/// (`state`), prüft das Gateway.
abstract class OAuthRedirect {
  /// Beginnt einen neuen Versuch (ein laufender wird beendet).
  Future<OAuthAttempt> prepare();

  /// Beendet den laufenden Versuch (z. B. „Abbrechen“, „Zurück“).
  void cancel();
}

/// Ein Anmeldeversuch: Rücksprungadresse und eingehende Rücksprünge.
abstract class OAuthAttempt {
  Uri get redirectUri;

  /// Öffnet die Anmeldeseite [uri] passend zur Art des Versuchs; `false`, wenn keine Seite öffnete oder
  /// der Versuch schon beendet ist (dann wird nichts geöffnet).
  Future<bool> open(Uri uri);

  /// Nächster Rücksprung; `null` nach [cancel] oder wenn bis [deadline] keiner kam.
  Future<Uri?> next({required DateTime deadline});

  void cancel();
}

/// Gemeinsame Warteschlange der Versuche.
///
/// [close] heißt „keine weiteren Einträge“ (vorhandene werden noch ausgegeben), [cancel] beendet den Versuch
/// endgültig und verwirft vorhandene Einträge.
class _Queue implements OAuthAttempt {
  _Queue(this.redirectUri, {this.onClose, required this.opener});

  @override
  final Uri redirectUri;
  final void Function()? onClose;
  final Future<bool> Function(_Queue q, Uri uri) opener;
  final List<Uri> _items = <Uri>[];
  Completer<void>? _signal;
  bool _closed = false;
  bool _cancelled = false;

  bool get finished => _closed || _cancelled;

  void _wake() {
    final s = _signal;
    if (s != null && !s.isCompleted) s.complete();
  }

  void add(Uri u) {
    if (finished) return;
    _items.add(u);
    _wake();
  }

  /// Keine weiteren Einträge; ruft [onClose] nicht.
  void close() {
    if (finished) return;
    _closed = true;
    _wake();
  }

  @override
  Future<bool> open(Uri uri) async {
    if (finished) return false;
    return opener(this, uri);
  }

  @override
  Future<Uri?> next({required DateTime deadline}) async {
    while (true) {
      if (_cancelled) return null;
      if (_items.isNotEmpty) return _items.removeAt(0);
      if (_closed) return null;
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) return null;
      final s = _signal = Completer<void>();
      await s.future.timeout(left, onTimeout: () {});
    }
  }

  @override
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _items.clear();
    _wake();
    onClose?.call();
  }
}

/// Rücksprung über das App-Schema (Android); die Seite öffnet im Custom Tab, Rückfall extern.
class AppLinkOAuthRedirect implements OAuthRedirect {
  AppLinkOAuthRedirect(this._links, this._browser);

  final LinkSource _links;
  final BrowserLauncher _browser;
  _Queue? _current;

  static bool isCallback(String raw) => raw.startsWith('${SdkMatrixGateway.oauthScheme}:/oauth');

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    late final StreamSubscription<String> sub;
    final q = _current = _Queue(
      SdkMatrixGateway.oauthMobileRedirect,
      onClose: () => sub.cancel().ignore(),
      opener: (_, uri) => _browser.open(uri, inApp: true),
    );
    sub = _links.links.where(isCallback).listen((raw) {
      final u = Uri.tryParse(raw);
      if (u != null) q.add(u);
    });
    return q;
  }

  @override
  void cancel() => _current?.cancel();
}

/// Rücksprung über einen lokalen Empfänger (Linux, Windows); die Seite öffnet im externen Browser.
class LoopbackOAuthRedirect implements OAuthRedirect {
  LoopbackOAuthRedirect(this._browser);

  final BrowserLauncher _browser;
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
      opener: (_, uri) => _browser.open(uri),
    );
    server.listen((req) async {
      if (req.method != 'GET' || req.uri.path != '/oauth' || q.finished) {
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

/// Rücksprung als Ergebnis der Anmeldesitzung des Systems (iOS, macOS; E-91). Kein Rückfall auf den externen
/// Browser: Dessen Rücksprung könnte auf dem Mac niemand empfangen.
class SessionOAuthRedirect implements OAuthRedirect {
  SessionOAuthRedirect(this.session);

  final WebAuthSession session;
  _Queue? _current;

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    final h = session.begin();
    return _current = _Queue(
      SdkMatrixGateway.oauthMobileRedirect,
      onClose: () => session.cancel(h),
      opener: (q, uri) async {
        final start = await session.start(h, uri, callbackScheme: SdkMatrixGateway.oauthScheme);
        if (!start.started) {
          q.cancel();
          return false;
        }
        // Nicht auf das Ende warten: Eine Sitzung liefert höchstens eine Antwort.
        start.result.then((u) {
          if (u == null) {
            q.cancel();
          } else {
            q
              ..add(u)
              ..close();
          }
        }).ignore();
        return true;
      },
    );
  }

  @override
  void cancel() => _current?.cancel();
}
