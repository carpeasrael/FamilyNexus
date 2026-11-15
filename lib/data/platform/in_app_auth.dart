import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'browser_launcher.dart';
import 'embedded_auth.dart';
import 'link_source.dart';
import 'oauth_redirect.dart';
import 'web_auth_session.dart';

/// Öffner für Anbieterseiten und Rücksprung der Anmeldung, passend zueinander gebaut (E-91, E-102).
typedef InAppAuth = ({BrowserLauncher browser, OAuthRedirect? oauthRedirect});

/// Einzige Bauweise für [BrowserLauncher] und [OAuthRedirect] der App (`bootstrap()`), nach [oauthFlowFor].
///
/// iOS, macOS und Android (`OAuthFlow.embedded`, #441): Die Seite des Anbieters erscheint in einer eingebetteten
/// Ansicht der App, die [embeddedOpener] zeigt. Der alte Weg der Plattform bleibt als Rückfall zur Aufrufzeit
/// (Opener meldet „nicht verfügbar“) und als Ziel von „Im Browser fortsetzen“: iOS/macOS genau eine
/// [WebAuthSession] (Standard: [ChannelWebAuthSession]), die Launcher und Rücksprung teilen; Android Custom Tab
/// (Rückfall extern) mit Rücksprung über das App-Schema. Ohne [embeddedOpener] (Tests, Web) liefert die Methode
/// nur diesen alten Weg. Linux/Windows: extern mit Loopback. Web: extern, keine OAuth-Anmeldung. Die übrigen
/// Parameter sind für Tests austauschbar.
InAppAuth buildInAppAuth({
  required LinkSource links,
  TargetPlatform? platform,
  bool? isWeb,
  WebAuthSession Function()? newSession,
  CustomTabLauncher? customTab,
  Future<bool> Function(Uri uri)? launch,
  EmbeddedOpener? embeddedOpener,
}) {
  final p = platform ?? defaultTargetPlatform;
  final web = isWeb ?? kIsWeb;
  final flow = oauthFlowFor(isWeb: web, platform: p);
  final embedded = flow == OAuthFlow.embedded ? embeddedOpener : null;
  // Der alte Weg der Plattform: Rückfall und Ausweg der eingebetteten Ansicht (E-91).
  final legacy = flow == OAuthFlow.embedded ? (p == TargetPlatform.android ? OAuthFlow.customTab : OAuthFlow.authSession) : flow;
  switch (legacy) {
    case OAuthFlow.authSession:
      final session = newSession?.call() ?? ChannelWebAuthSession();
      final browser = SystemBrowserLauncher(webAuth: session, platform: p, isWeb: web, launch: launch);
      return _withEmbedded(embedded, browser, SessionOAuthRedirect(session));
    case OAuthFlow.customTab:
      final browser = SystemBrowserLauncher(
        customTab: customTab ?? const ChannelCustomTabLauncher(),
        platform: p,
        isWeb: web,
        launch: launch,
      );
      return _withEmbedded(embedded, browser, AppLinkOAuthRedirect(links, browser));
    case OAuthFlow.loopback:
      final browser = SystemBrowserLauncher(platform: p, isWeb: web, launch: launch);
      return (browser: browser, oauthRedirect: LoopbackOAuthRedirect(browser));
    case OAuthFlow.none || OAuthFlow.embedded:
      return (browser: SystemBrowserLauncher(platform: p, isWeb: web, launch: launch), oauthRedirect: null);
  }
}

InAppAuth _withEmbedded(EmbeddedOpener? opener, SystemBrowserLauncher browser, OAuthRedirect redirect) {
  if (opener == null) return (browser: browser, oauthRedirect: redirect);
  return (browser: EmbeddedBrowserLauncher(opener, browser), oauthRedirect: EmbeddedOAuthRedirect(opener, redirect));
}
