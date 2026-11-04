import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'browser_launcher.dart';
import 'link_source.dart';
import 'oauth_redirect.dart';
import 'web_auth_session.dart';

/// Öffner für Anbieterseiten und Rücksprung der Anmeldung, passend zueinander gebaut (E-91).
typedef InAppAuth = ({BrowserLauncher browser, OAuthRedirect? oauthRedirect});

/// Einzige Bauweise für [BrowserLauncher] und [OAuthRedirect] der App (`bootstrap()`), nach [oauthFlowFor].
///
/// iOS/macOS: genau eine [WebAuthSession] (Standard: [ChannelWebAuthSession]), die Launcher und Rücksprung
/// teilen. Android: Custom Tab (Rückfall extern) mit Rücksprung über das App-Schema. Linux/Windows: extern
/// mit Loopback. Web: extern, keine OAuth-Anmeldung. Die übrigen Parameter sind für Tests austauschbar.
InAppAuth buildInAppAuth({
  required LinkSource links,
  TargetPlatform? platform,
  bool? isWeb,
  WebAuthSession Function()? newSession,
  CustomTabLauncher? customTab,
  Future<bool> Function(Uri uri)? launch,
}) {
  final p = platform ?? defaultTargetPlatform;
  final web = isWeb ?? kIsWeb;
  switch (oauthFlowFor(isWeb: web, platform: p)) {
    case OAuthFlow.authSession:
      final session = newSession?.call() ?? ChannelWebAuthSession();
      return (
        browser: SystemBrowserLauncher(webAuth: session, platform: p, isWeb: web, launch: launch),
        oauthRedirect: SessionOAuthRedirect(session),
      );
    case OAuthFlow.customTab:
      final browser = SystemBrowserLauncher(
        customTab: customTab ?? const ChannelCustomTabLauncher(),
        platform: p,
        isWeb: web,
        launch: launch,
      );
      return (browser: browser, oauthRedirect: AppLinkOAuthRedirect(links, browser));
    case OAuthFlow.loopback:
      final browser = SystemBrowserLauncher(platform: p, isWeb: web, launch: launch);
      return (browser: browser, oauthRedirect: LoopbackOAuthRedirect(browser));
    case OAuthFlow.none:
      return (browser: SystemBrowserLauncher(platform: p, isWeb: web, launch: launch), oauthRedirect: null);
  }
}
