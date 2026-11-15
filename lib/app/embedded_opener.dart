import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewPlatform;

import '../core/app_log.dart';
import '../data/platform/embedded_auth.dart';
import '../features/onboarding/embedded_browser_page.dart';

/// Opener der eingebetteten Ansicht (#441): schiebt die Seite auf den Navigator von [key] und kehrt **nach dem
/// Push** zurück. `null` heißt „nicht verfügbar“ (der Aufrufer nimmt den alten Weg): kein Navigator (z. B. der
/// Schlüssel einer ersetzten Oberfläche) oder keine WebView-Plattform. Die Route wird gezielt entfernt, nie
/// blind per `pop()`. [platformAvailable] ersetzt im Test die Prüfung von `WebViewPlatform.instance`.
EmbeddedOpener embeddedOpenerFor(GlobalKey<NavigatorState> key, {@visibleForTesting bool Function()? platformAvailable}) {
  return (request) async {
    if (!(platformAvailable?.call() ?? WebViewPlatform.instance != null)) {
      AppLog.w('embedded', 'Keine WebView-Plattform');
      return null;
    }
    final nav = key.currentState;
    if (nav == null) {
      AppLog.w('embedded', 'Kein Navigator');
      return null;
    }
    final result = Completer<EmbeddedResult>();
    late final Route<void> route;
    route = MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EmbeddedBrowserPage(
        request: request,
        onResult: (r) {
          if (!result.isCompleted) result.complete(r);
          if (route.isActive && nav.mounted) nav.removeRoute(route);
        },
      ),
    );
    unawaited(nav.push<void>(route));
    return EmbeddedHandle(result.future);
  };
}
