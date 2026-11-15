import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// Fake-Plattform für die eingebettete Seite (#441): merkt sich die Aufrufe des Controllers in FakeCtl.calls
// und gibt die Rückrufe der Navigation heraus. `addJavaScriptChannel`/`runJavaScript` werden nur gezählt, damit
// ein Test beweisen kann, dass die App sie nie aufruft.

// ignore: must_be_immutable
class FakePermissionRequest extends PlatformWebViewPermissionRequest {
  FakePermissionRequest() : super(types: <WebViewPermissionResourceType>{WebViewPermissionResourceType.camera});
  int denies = 0;
  int grants = 0;
  @override
  Future<void> deny() async => denies++;
  @override
  Future<void> grant() async => grants++;
}

class FakeNav extends PlatformNavigationDelegate {
  FakeNav(super.params) : super.implementation();
  NavigationRequestCallback? onNav;
  PageEventCallback? onStarted;
  UrlChangeCallback? onUrl;
  ProgressCallback? onProg;
  HttpResponseErrorCallback? onHttp;
  WebResourceErrorCallback? onResErr;
  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback c) async => onNav = c;
  @override
  Future<void> setOnPageStarted(PageEventCallback c) async => onStarted = c;
  @override
  Future<void> setOnPageFinished(PageEventCallback c) async {}
  @override
  Future<void> setOnProgress(ProgressCallback c) async => onProg = c;
  @override
  Future<void> setOnUrlChange(UrlChangeCallback c) async => onUrl = c;
  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback c) async => onHttp = c;
  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback c) async => onResErr = c;
}

class FakeCtl extends PlatformWebViewController {
  FakeCtl(super.params) : super.implementation();
  final List<String> calls = <String>[];
  FakeNav? nav;
  void Function(PlatformWebViewPermissionRequest)? perm;
  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate d) async => nav = d as FakeNav;
  @override
  Future<void> setJavaScriptMode(JavaScriptMode m) async => calls.add('js:${m.name}');
  @override
  Future<void> enableZoom(bool e) async => calls.add('zoom:$e');
  /// Hält `clearCache` zurück (Löschen hängt) bzw. lässt es scheitern.
  Completer<void>? clearGate;
  bool clearThrows = false;
  @override
  Future<void> clearCache() async {
    calls.add('clearCache');
    if (clearThrows) throw StateError('clearCache');
    await clearGate?.future;
  }
  @override
  Future<void> clearLocalStorage() async => calls.add('clearLocalStorage');
  @override
  Future<void> loadRequest(LoadRequestParams p) async => calls.add('load:${p.uri}');
  @override
  Future<void> setOnPlatformPermissionRequest(void Function(PlatformWebViewPermissionRequest) c) async => perm = c;
  @override
  Future<void> reload() async => calls.add('reload');
  bool back = false;
  @override
  Future<bool> canGoBack() async => back;
  @override
  Future<void> goBack() async => calls.add('goBack');
  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams p) async => calls.add('channel');
  @override
  Future<void> runJavaScript(String s) async => calls.add('runJS');
}

class FakeCookies extends PlatformWebViewCookieManager {
  FakeCookies(super.params) : super.implementation();
  @override
  Future<bool> clearCookies() async {
    FakePlatform.last!.calls.add('clearCookies');
    return true;
  }
}

class FakeWidget extends PlatformWebViewWidget {
  FakeWidget(super.params) : super.implementation();
  @override
  Widget build(BuildContext context) => const SizedBox(key: Key('webview'));
}

class FakePlatform extends WebViewPlatform {
  static FakeCtl? last;
  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) => last = FakeCtl(params);
  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) => FakeNav(params);
  @override
  PlatformWebViewCookieManager createPlatformCookieManager(PlatformWebViewCookieManagerCreationParams params) => FakeCookies(params);
  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) => FakeWidget(params);
}
