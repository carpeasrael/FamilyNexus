import 'dart:async';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:family_nexus/data/platform/element_launcher.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:family_nexus/data/platform/web_auth_session.dart';

/// Merkt sich geöffnete Seiten und je Aufruf, ob sie in der App geöffnet werden sollten ([inApp]);
/// `available = false` simuliert ein Gerät, auf dem sich keine Seite öffnen lässt.
///
/// [openInApp] liefert wie Android standardmäßig `waited == false` (sofort). Mit [sessionWaits] verhält er
/// sich wie iOS/macOS: `waited` schließt erst mit [finishSession] (mit `true`) ab.
class FakeBrowser implements BrowserLauncher {
  bool available = true;
  bool sessionWaits = false;
  final List<Uri> opened = <Uri>[];
  final List<bool> inApp = <bool>[];
  Completer<bool>? _session;

  /// Ist eine Sitzung (mit [sessionWaits]) offen?
  bool get sessionOpen => _session != null && !_session!.isCompleted;

  @override
  Future<bool> open(Uri uri, {bool inApp = false}) async {
    if (!available || !BrowserLauncher.isAllowed(uri)) return false;
    opened.add(uri);
    this.inApp.add(inApp);
    return true;
  }

  @override
  Future<InAppOpening> openInApp(Uri uri) async {
    if (!available || !BrowserLauncher.isAllowed(uri)) return (opened: false, waited: Future<bool>.value(false));
    opened.add(uri);
    inApp.add(true);
    if (!sessionWaits) return (opened: true, waited: Future<bool>.value(false));
    final s = _session = Completer<bool>();
    return (opened: true, waited: s.future);
  }

  /// Beendet die offene Sitzung (wie „Abbrechen“ auf iPhone, iPad und Mac).
  void finishSession() {
    final s = _session;
    if (s != null && !s.isCompleted) s.complete(true);
  }
}

/// Rücksprung der Anmeldung beim Anbieter für Tests: [deliver] simuliert den Rücksprung. Öffnet die Seite wie
/// die App-Umsetzungen über den [FakeBrowser] (in der App).
class FakeOAuthRedirect implements OAuthRedirect {
  FakeOAuthRedirect(this.browser);

  static final Uri redirect = Uri.parse('io.github.carpeasrael.familynexus:/oauth');
  final FakeBrowser browser;
  _FakeAttempt? _current;

  bool get waiting => _current != null && !_current!.closed;

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    return _current = _FakeAttempt(browser);
  }

  void deliver(Uri callback) => _current?.add(callback);

  @override
  void cancel() => _current?.cancel();
}

class _FakeAttempt implements OAuthAttempt {
  _FakeAttempt(this.browser);

  final FakeBrowser browser;
  final List<Uri> _items = <Uri>[];
  Completer<void>? _signal;
  bool closed = false;

  @override
  Uri get redirectUri => FakeOAuthRedirect.redirect;

  @override
  Future<bool> open(Uri uri) async => !closed && await browser.open(uri, inApp: true);

  void add(Uri u) {
    if (closed) return;
    _items.add(u);
    _signal?.complete();
    _signal = null;
  }

  @override
  Future<Uri?> next({required DateTime deadline}) async {
    while (!closed) {
      if (_items.isNotEmpty) return _items.removeAt(0);
      await (_signal = Completer<void>()).future;
    }
    return null;
  }

  @override
  void cancel() {
    if (closed) return;
    closed = true;
    _signal?.complete();
    _signal = null;
  }
}

/// Anmeldesitzung für Tests (iOS/macOS, E-91): zählt [begin], merkt [starts] und [cancels]; das Ergebnis des
/// Starts steuern [startResult] bzw. [startGate], das Ende [finish].
class FakeWebAuthSession implements WebAuthSession {
  int begins = 0;
  int _next = 0;

  /// Antwort auf `start` (false = nicht gestartet).
  bool startResult = true;

  /// Hält die Antwort auf `start` zurück, bis der Completer abschließt (Abbruch während des Starts).
  Completer<void>? startGate;

  final List<({int id, Uri uri, String? scheme})> starts = <({int id, Uri uri, String? scheme})>[];
  final List<int> cancels = <int>[];
  final Map<int, Completer<Uri?>> _results = <int, Completer<Uri?>>{};

  @override
  WebAuthHandle begin() {
    begins++;
    return WebAuthHandle(++_next);
  }

  @override
  Future<WebAuthStart> start(WebAuthHandle h, Uri uri, {String? callbackScheme}) async {
    starts.add((id: h.id, uri: uri, scheme: callbackScheme));
    final c = _results[h.id] = Completer<Uri?>();
    final gate = startGate;
    if (gate != null) await gate.future;
    if (!startResult) {
      _results.remove(h.id);
      return WebAuthStart(started: false, result: Future<Uri?>.value());
    }
    return WebAuthStart(started: true, result: c.future);
  }

  @override
  void cancel(WebAuthHandle h) {
    cancels.add(h.id);
    final c = _results.remove(h.id);
    if (c != null && !c.isCompleted) c.complete(null);
  }

  /// Beendet die Sitzung [id] (Standard: die zuletzt gestartete) mit [callback] bzw. `null` (Abbruch).
  void finish(Uri? callback, {int? id}) {
    final c = _results.remove(id ?? starts.last.id);
    if (c != null && !c.isCompleted) c.complete(callback);
  }

  /// Ist die Sitzung [id] noch offen (weder beendet noch abgebrochen)?
  bool isOpen(int id) => _results.containsKey(id);
}

/// Simuliert Element; `installed = false` = nicht auf dem Gerät.
class FakeElement implements ElementLauncher {
  bool installed = true;
  int starts = 0;

  @override
  Future<bool> open() async {
    if (!installed) return false;
    starts++;
    return true;
  }
}
