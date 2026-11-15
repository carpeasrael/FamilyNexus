import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/app_scope.dart';
import '../../core/app_log.dart';
import '../../data/platform/browser_launcher.dart';
import '../../data/platform/embedded_auth.dart';
import '../../data/platform/website_data.dart';
import '../../l10n/gen/app_localizations.dart';
import '../lock/app_lock_controller.dart';

enum NavDecision { allow, block, redirect }

/// Reine Navigationsregel der eingebetteten Seite (#441, E-102): Hauptframe nur `https` ohne Zugangsdaten; der
/// Rücksprung (gleiches Schema und Pfad, keine Authority, höchstens 2048 Zeichen) wird nicht ausgeführt,
/// sondern geliefert; Unterframes: `https`, `about:blank`, `about:srcdoc`.
NavDecision decideNavigation(String url, {required bool isMainFrame, required Uri redirectUri}) {
  final u = Uri.tryParse(url);
  if (u == null) return NavDecision.block;
  if (!isMainFrame) {
    if (u.scheme == 'about') return (url == 'about:blank' || url == 'about:srcdoc') ? NavDecision.allow : NavDecision.block;
    return BrowserLauncher.isAllowed(u) ? NavDecision.allow : NavDecision.block;
  }
  if (u.scheme == redirectUri.scheme) {
    if (url.length <= 2048 && u.path == redirectUri.path && !u.hasAuthority) return NavDecision.redirect;
    return NavDecision.block;
  }
  return BrowserLauncher.isAllowed(u) ? NavDecision.allow : NavDecision.block;
}

/// Schleifenschutz: Es zählen nur erlaubte Hauptframe-Navigationen; Schlüssel ist die URL ohne Fragment;
/// gleitendes Fenster. Die [max]+1. Navigation derselben URL im Fenster wird blockiert (`false`); blockierte
/// zählen nicht mit. [reset] („Neu laden“) leert den Zähler.
class NavigationLoopGuard {
  NavigationLoopGuard({DateTime Function()? clock, this.max = 3, this.window = const Duration(seconds: 5)})
      : _clock = clock ?? DateTime.now;
  final DateTime Function() _clock;
  final int max;
  final Duration window;
  final Map<String, List<DateTime>> _seen = <String, List<DateTime>>{};

  static String key(String url) {
    final u = Uri.tryParse(url);
    return u == null ? url : u.removeFragment().toString();
  }

  /// `true` = erlaubt (und gezählt), `false` = Schleife (nicht gezählt).
  bool check(String url) {
    final now = _clock();
    final h = _seen.putIfAbsent(key(url), () => <DateTime>[]);
    h.removeWhere((t) => now.difference(t) > window);
    if (h.length >= max) return false;
    h.add(now);
    return true;
  }

  void reset() => _seen.clear();
}

/// Fehlercode der Plattform für „Vorgang abgebrochen“ (iOS/macOS `NSURLErrorCancelled`).
const int kErrorCancelled = -999;

/// Wie lange das Löschen von Cookies, Cache und Speicher beim Schließen höchstens abgewartet wird.
const Duration kClearTimeout = Duration(seconds: 3);

/// Eingebettete Anmelde- und Anbieterseite (#441, E-102). Zeigt `request.url` in einer WebView der App, mit
/// strengen Navigationsregeln ([decideNavigation]), verweigerten Berechtigungen und ohne JavaScript-Kanäle.
/// Jedes Schließen meldet genau ein Ergebnis über [onResult] und löscht vorher Cookies, Cache und Speicher.
class EmbeddedBrowserPage extends StatefulWidget {
  const EmbeddedBrowserPage({super.key, required this.request, required this.onResult, this.clock});
  final EmbeddedRequest request;
  final void Function(EmbeddedResult) onResult;
  final DateTime Function()? clock;

  @override
  State<EmbeddedBrowserPage> createState() => _EmbeddedBrowserPageState();
}

enum _Banner { none, problem, loop }

class _EmbeddedBrowserPageState extends State<EmbeddedBrowserPage> {
  late final WebViewController _c;
  final WebViewCookieManager _cookies = WebViewCookieManager();
  final ChannelWebsiteData _websiteData = const ChannelWebsiteData();
  late final NavigationLoopGuard _guard = NavigationLoopGuard(clock: widget.clock);

  /// Angezeigt wird nur die zuletzt **übernommene** Adresse (`onUrlChange`), nie eine blockierte oder noch
  /// ausstehende.
  String _shown = '';
  // Nur der Host der angezeigten Adresse (leer bei hostlosen Adressen wie about:blank), für den Fremd-Host-Hinweis (#485).
  String _shownHost = '';

  /// Letzte bekannte Hauptseite: Start-URL, erlaubte Hauptframe-Navigationen und `onPageStarted`. [_mainKey] (ohne
  /// Fragment) dient dem Vergleich bei HTTP-Fehlern, [_mainLoad] ist das Ziel von „Neu laden“.
  late String _mainKey = NavigationLoopGuard.key(widget.request.url.toString());
  late String _mainLoad = widget.request.url.toString();
  int _progress = 0;
  _Banner _banner = _Banner.none;
  bool _openFailed = false;
  bool _suppressError = false;
  bool _done = false;
  bool _disposed = false;
  bool _external = false;
  AppLockController? _lock;
  ScaffoldMessengerState? _messenger;

  Uri get _redirect => widget.request.redirectUri ?? Uri.parse('x-none:/none');

  @override
  void initState() {
    super.initState();
    _c = WebViewController(onPermissionRequest: (r) => r.deny())
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: _onNavigationRequest,
        onPageStarted: (u) {
          _mainKey = NavigationLoopGuard.key(u);
          if (BrowserLauncher.isAllowed(Uri.parse(u))) _mainLoad = u;
          _suppressError = false;
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onUrlChange: (c) {
          final u = Uri.tryParse(c.url ?? '');
          if (u != null && mounted) {
            setState(() {
              _shown = '${u.host}${u.path}';
              _shownHost = u.host;
            });
          }
        },
        onWebResourceError: (e) {
          if (!(e.isForMainFrame ?? true)) return;
          if (e.errorCode == kErrorCancelled || _suppressError) return;
          _show(_Banner.problem);
        },
        onHttpError: (e) {
          final status = e.response?.statusCode ?? 0;
          if (status < 400) return;
          final req = e.request;
          // iOS/macOS melden `request` nie (Haupt- und Unterframe nicht unterscheidbar): Banner, die Seite
          // bleibt stehen. Android: nur die Hauptseite (Favicon u. a. Unterressourcen bleiben still).
          if (req == null || NavigationLoopGuard.key(req.uri.toString()) == _mainKey) _show(_Banner.problem);
        },
      ));
    unawaited(_start());
    unawaited(widget.request.cancel.future.then((_) => _finish(const EmbeddedCancelled())));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
    if (_lock == null) {
      final lock = AppScope.of(context).lock;
      _lock = lock;
      lock.addListener(_onLock);
      // Schon gesperrt beim Öffnen: Der Listener löste nie aus, also nach dem Aufbau sofort schließen.
      if (lock.locked) WidgetsBinding.instance.addPostFrameCallback((_) => _onLock());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _lock?.removeListener(_onLock);
    // Route zerstört, ohne dass die Seite schloss (Navigator ersetzt): Versuch endet.
    _finish(const EmbeddedCancelled());
    super.dispose();
  }

  NavigationDecision _onNavigationRequest(NavigationRequest r) {
    switch (decideNavigation(r.url, isMainFrame: r.isMainFrame, redirectUri: _redirect)) {
      case NavDecision.allow:
        if (r.isMainFrame) {
          if (!_guard.check(r.url)) {
            _show(_Banner.loop);
            return NavigationDecision.prevent;
          }
          _mainKey = NavigationLoopGuard.key(r.url);
          _mainLoad = r.url;
        }
        return NavigationDecision.navigate;
      case NavDecision.block:
        // Eigene Blockade: kein Fehler-Banner, die Seite bleibt stehen; höchstens ein kurzer Hinweis.
        if (r.isMainFrame) {
          _suppressError = true;
          _hintBlocked();
        }
        return NavigationDecision.prevent;
      case NavDecision.redirect:
        _finish(EmbeddedCallback(Uri.parse(r.url)));
        return NavigationDecision.prevent;
    }
  }

  void _hintBlocked() {
    final m = _messenger;
    if (!mounted || m == null) return;
    m
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).embeddedBlocked)));
  }

  void _onLock() {
    if (_lock?.locked ?? false) _finish(const EmbeddedCancelled());
  }

  void _show(_Banner b) {
    if (mounted) setState(() => _banner = b);
  }

  Future<void> _safe(String what, Future<Object?> Function() step) async {
    try {
      await step();
    } catch (e) {
      AppLog.w('embedded', '$what nicht gelöscht (${e.runtimeType})');
    }
  }

  /// Löscht Cookies, Cache und lokalen Speicher. Alle Aufrufe starten sofort (solange der Controller lebt). Auf
  /// iOS und macOS löscht ein vierter Aufruf zusätzlich den gesamten Website-Datenspeicher (IndexedDB, Service
  /// Worker u. a., soweit WebKit es zulässt, #486); sonst bleiben diese Reste (E-102).
  Future<void> _clear() async {
    await Future.wait(<Future<void>>[
      _safe('Cookies', _cookies.clearCookies),
      _safe('Cache', _c.clearCache),
      _safe('Speicher', _c.clearLocalStorage),
      _safe('Datenspeicher', _websiteData.clear),
    ]);
  }

  Future<void> _start() async {
    try {
      await _c.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _c.enableZoom(false);
      await _clear();
      if (_done || (_lock?.locked ?? false)) return;
      await _c.loadRequest(widget.request.url);
    } catch (e) {
      AppLog.e('embedded', 'Seite nicht gestartet', e);
      _show(_Banner.problem);
    }
  }

  /// Schließt mit [r]: erst löschen (solange der Controller lebt), dann das Ergebnis melden, das die Route
  /// entfernt. Beim Entsorgen der Seite wird sofort gemeldet.
  void _finish(EmbeddedResult r) {
    if (_done) return;
    _done = true;
    final cleared = _clear();
    if (_disposed) {
      widget.onResult(r);
      return;
    }
    _messenger?.clearSnackBars();
    unawaited(cleared.timeout(kClearTimeout, onTimeout: () => AppLog.w('embedded', 'Löschen dauert zu lange')).whenComplete(() => widget.onResult(r)));
  }

  Future<void> _reload() async {
    _guard.reset();
    _suppressError = false;
    _show(_Banner.none);
    // Immer die zuletzt bekannte Hauptseite laden (auch wenn der Schleifenschutz die aktuelle Navigation blockierte).
    try {
      await _c.loadRequest(Uri.parse(_mainLoad));
    } catch (e) {
      AppLog.e('embedded', 'Neu laden fehlgeschlagen', e);
      _show(_Banner.problem);
    }
  }

  Future<void> _continue() async {
    if (_external) return;
    _external = true;
    var ok = false;
    try {
      ok = await widget.request.continueExternally();
    } catch (e) {
      AppLog.e('embedded', 'Ausweg fehlgeschlagen', e);
    } finally {
      _external = false;
    }
    if (ok) {
      _finish(const EmbeddedContinueExternally());
    } else if (mounted && !_done) {
      // Nach „Fertig“ (`_done`) kein Fehlerbanner mehr: Die Seite schließt gerade (#484).
      setState(() => _openFailed = true);
    }
  }

  /// Zurück (Android-Zurück, iOS-Wischen, Schließen-Knopf): erst eine Seite zurück, sonst Abbruch.
  Future<void> _back() async {
    bool canGoBack = false;
    try {
      canGoBack = await _c.canGoBack();
    } catch (e) {
      AppLog.w('embedded', 'Zurück nicht prüfbar (${e.runtimeType})');
    }
    if (canGoBack) {
      await _c.goBack();
    } else {
      _finish(const EmbeddedCancelled());
    }
  }

  Widget _bannerBar(AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Text(_banner == _Banner.loop ? l.embeddedLoopBlocked : l.embeddedProblem)),
            IconButton(
              key: const Key('banner-dismiss'),
              tooltip: l.embeddedDismiss,
              icon: const Icon(Icons.close),
              onPressed: () => _show(_Banner.none),
            ),
          ]),
          if (_openFailed) Text(l.embeddedOpenFailed, key: const Key('open-failed')),
          Wrap(spacing: 8, children: <Widget>[
            TextButton(key: const Key('reload'), onPressed: _reload, child: Text(l.embeddedReload)),
            TextButton(key: const Key('external'), onPressed: _continue, child: Text(l.embeddedContinueExternally)),
            TextButton(key: const Key('banner-cancel'), onPressed: () => _finish(const EmbeddedCancelled()), child: Text(l.embeddedCancel)),
          ]),
        ]),
      ),
    );
  }

  Widget _hostLine(AppLocalizations l, bool foreign) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Row(children: <Widget>[
            Icon(Icons.lock_outline, size: 16, semanticLabel: l.embeddedSecure),
            const SizedBox(width: 6),
            // Immer der vollständige Host (mehrzeilig, nie abgeschnitten).
            Expanded(child: Text(_shown, key: const Key('host'))),
          ]),
          if (foreign) Text(l.embeddedForeignHost(_shownHost.isEmpty ? _shown.split('/').first : _shownHost), key: const Key('foreign')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Exakter Vergleich der Hosts (kein Präfix): `anbieter.test.example.net` ist nicht `anbieter.test` (#485).
    final foreign = _shown.isNotEmpty && _shownHost.toLowerCase() != widget.request.url.host.toLowerCase();
    final signIn = widget.request.kind == EmbeddedKind.signIn;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(signIn ? l.embeddedTitleSignIn : l.embeddedTitlePage),
          actions: <Widget>[
            TextButton(
              key: const Key('cancel'),
              onPressed: () => _finish(const EmbeddedCancelled()),
              child: Text(signIn ? l.embeddedCancel : l.embeddedDone),
            ),
          ],
        ),
        body: Column(children: <Widget>[
          if (_shown.isNotEmpty) _hostLine(l, foreign),
          if (_progress > 0 && _progress < 100) LinearProgressIndicator(value: _progress / 100, semanticsLabel: l.embeddedLoading),
          if (_banner != _Banner.none) _bannerBar(l),
          Expanded(child: WebViewWidget(controller: _c)),
        ]),
      ),
    );
  }
}
