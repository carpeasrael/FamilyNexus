import 'dart:async';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:family_nexus/data/platform/element_launcher.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';

/// Merkt sich geöffnete Seiten; `available = false` simuliert ein Gerät ohne Browser.
class FakeBrowser implements BrowserLauncher {
  bool available = true;
  final List<Uri> opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    if (!available || !BrowserLauncher.isAllowed(uri)) return false;
    opened.add(uri);
    return true;
  }
}

/// Rücksprung der Browser-Anmeldung für Tests: [deliver] simuliert den Aufruf durch den Browser.
class FakeOAuthRedirect implements OAuthRedirect {
  static final Uri redirect = Uri.parse('io.github.carpeasrael.familynexus:/oauth');
  _FakeAttempt? _current;

  bool get waiting => _current != null && !_current!.closed;

  @override
  Future<OAuthAttempt> prepare() async {
    _current?.cancel();
    return _current = _FakeAttempt();
  }

  void deliver(Uri callback) => _current?.add(callback);

  @override
  void cancel() => _current?.cancel();
}

class _FakeAttempt implements OAuthAttempt {
  final List<Uri> _items = <Uri>[];
  Completer<void>? _signal;
  bool closed = false;

  @override
  Uri get redirectUri => FakeOAuthRedirect.redirect;

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
