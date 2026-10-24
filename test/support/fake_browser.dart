import 'dart:async';

import 'package:family_nexus/data/platform/browser_launcher.dart';
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
  Completer<Uri?>? _done;

  bool get waiting => _done != null && !_done!.isCompleted;

  @override
  Future<Uri> prepare() async {
    cancel();
    _done = Completer<Uri?>();
    return redirect;
  }

  @override
  Future<Uri?> wait({Duration timeout = const Duration(minutes: 10)}) => _done?.future ?? Future<Uri?>.value();

  void deliver(Uri callback) {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(callback);
  }

  @override
  void cancel() {
    final d = _done;
    if (d != null && !d.isCompleted) d.complete(null);
  }
}
