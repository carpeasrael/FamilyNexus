import 'dart:async';

import '../../core/app_log.dart';
import 'browser_launcher.dart';

/// Art der eingebetteten Seite: Anmeldung (Beschriftung „Abbrechen“) oder Kontoseite/Captcha („Fertig“).
enum EmbeddedKind { signIn, page }

sealed class EmbeddedResult {
  const EmbeddedResult();
}

/// Rücksprung der Anmeldung (wurde in der Seite abgefangen, nicht ausgeführt).
class EmbeddedCallback extends EmbeddedResult {
  const EmbeddedCallback(this.uri);
  final Uri uri;
}

/// Abbrechen, Zurück, Sperre, Zeitablauf, Seite entsorgt: beendet den Versuch.
class EmbeddedCancelled extends EmbeddedResult {
  const EmbeddedCancelled();
}

/// „Im Browser fortsetzen“: beendet nur die Seite, nicht den Versuch.
class EmbeddedContinueExternally extends EmbeddedResult {
  const EmbeddedContinueExternally();
}

class EmbeddedRequest {
  EmbeddedRequest({
    required this.url,
    required this.kind,
    required this.cancel,
    required this.continueExternally,
    this.redirectUri,
  });
  final Uri url;
  final Uri? redirectUri;
  final EmbeddedKind kind;

  /// Schließt der Aufrufer ab, schließt die Seite mit [EmbeddedCancelled].
  final Completer<void> cancel;

  /// Ausweg: `true`, wenn der alte Weg die Seite öffnete (dann schließt die Seite), sonst bleibt sie offen.
  final Future<bool> Function() continueExternally;
}

/// Ergebnis des Öffnens: [result] endet, wenn die Seite schließt.
class EmbeddedHandle {
  const EmbeddedHandle(this.result);
  final Future<EmbeddedResult> result;
}

/// Zeigt die Seite und kehrt **nach dem Einblenden** der Route zurück (nicht beim Schließen); `null` =
/// nicht verfügbar (kein Navigator, keine WebView-Plattform): dann gilt der alte Weg.
typedef EmbeddedOpener = Future<EmbeddedHandle?> Function(EmbeddedRequest request);

/// Öffnet Kontoseiten und Captcha in der eingebetteten Ansicht; `open(inApp: false)` bleibt extern.
class EmbeddedBrowserLauncher implements BrowserLauncher {
  EmbeddedBrowserLauncher(this._opener, this._fallback);
  final EmbeddedOpener _opener;
  final BrowserLauncher _fallback;

  @override
  Future<bool> open(Uri uri, {bool inApp = false}) async {
    if (!inApp) return _fallback.open(uri);
    return (await openInApp(uri)).opened;
  }

  @override
  Future<InAppOpening> openInApp(Uri uri) async {
    if (!BrowserLauncher.isAllowed(uri)) return (opened: false, waited: Future<bool>.value(false));
    final waited = Completer<bool>();
    var external = false;
    final request = EmbeddedRequest(
      url: uri,
      kind: EmbeddedKind.page,
      cancel: Completer<void>(),
      continueExternally: () async {
        final r = await _fallback.openInApp(uri);
        if (!r.opened) return false;
        // Die Seite endete schon („Fertig“ während der Rückfall öffnete): `waited` ist abgeschlossen. Der Ausweg
        // zählt nicht (#484); das externe Fenster ist offen, wird aber nicht mehr überwacht.
        if (waited.isCompleted) {
          AppLog.w('browser', 'Seite war schon beendet, Ausweg nicht mehr gewertet');
          return false;
        }
        external = true;
        waited.complete(r.waited);
        return true;
      },
    );
    EmbeddedHandle? handle;
    try {
      handle = await _opener(request);
    } catch (e) {
      AppLog.w('browser', 'Eingebettete Ansicht nicht verfügbar, öffne mit dem alten Weg');
      handle = null;
    }
    if (handle == null) return _fallback.openInApp(uri);
    unawaited(handle.result.then((_) {
      if (!external && !waited.isCompleted) waited.complete(true);
    }));
    return (opened: true, waited: waited.future);
  }
}
