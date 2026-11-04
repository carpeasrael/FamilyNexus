import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/app_log.dart';
import 'browser_launcher.dart';

/// Kennung einer Anmeldesitzung; vergibt allein [WebAuthSession.begin].
class WebAuthHandle {
  const WebAuthHandle(this.id);
  final int id;
}

/// Ergebnis von [WebAuthSession.start]: [started] = die Sitzung ist sichtbar; [result] schließt beim Ende
/// der Sitzung ab (Rücksprung oder `null` bei Abbruch, Fehler und nicht gestarteter Sitzung).
class WebAuthStart {
  const WebAuthStart({required this.started, required this.result});
  final bool started;
  final Future<Uri?> result;
}

/// Anbieterseite in einer Anmeldesitzung des Systems (iOS/macOS: ASWebAuthenticationSession; #268, E-91).
///
/// Ablauf: [begin] liefert sofort eine Kennung, [start] öffnet die Seite, [cancel] beendet die Sitzung –
/// jederzeit, auch bevor [start] gesendet bzw. beantwortet wurde.
abstract class WebAuthSession {
  WebAuthHandle begin();

  /// Öffnet [uri] (nur https). Mit [callbackScheme] endet die Sitzung beim Rücksprung auf dieses Schema;
  /// ohne (Kontoseiten, Captcha) endet sie über „Abbrechen“.
  Future<WebAuthStart> start(WebAuthHandle h, Uri uri, {String? callbackScheme});

  void cancel(WebAuthHandle h);
}

/// Sitzung über den MethodChannel `de.inneso.familynexus/webauth` (Swift: `AppDelegate.swift`,
/// `MainFlutterWindow.swift`). Genau eine Instanz je Start der App (`buildInAppAuth`); eine neue Instanz
/// übernimmt den Kanal.
class ChannelWebAuthSession implements WebAuthSession {
  ChannelWebAuthSession({this.channel = const MethodChannel(channelName)}) {
    channel.setMethodCallHandler(_handle);
  }

  static const String channelName = 'de.inneso.familynexus/webauth';

  /// Höchstlänge eines Rücksprungs (wie `MainActivity.linkFrom`).
  static const int maxLength = 2048;

  /// Statisch: über Instanzen hinweg eindeutig, weil `bootstrap()` mehrfach laufen kann („Erneut versuchen“).
  static int _nextId = 0;

  final MethodChannel channel;
  final Map<int, _Pending> _pending = <int, _Pending>{};
  final Set<int> _cancelled = <int>{};
  final Set<int> _sent = <int>{};

  @override
  WebAuthHandle begin() => WebAuthHandle(++_nextId);

  @override
  Future<WebAuthStart> start(WebAuthHandle h, Uri uri, {String? callbackScheme}) async {
    final notStarted = WebAuthStart(started: false, result: Future<Uri?>.value());
    if (!BrowserLauncher.isAllowed(uri) || _cancelled.contains(h.id) || _sent.contains(h.id)) return notStarted;
    // Vor dem Senden registrieren: Das Ende kann noch vor der Antwort auf `start` eintreffen.
    final pending = _pending[h.id] = _Pending(callbackScheme);
    _sent.add(h.id);
    var ok = false;
    try {
      ok = await channel.invokeMethod<bool>('start', <String, Object?>{
            'id': h.id,
            'url': uri.toString(),
            'scheme': callbackScheme,
          }) ??
          false;
    } on MissingPluginException {
      ok = false;
    } on PlatformException catch (e) {
      AppLog.e('webauth', 'Anmeldesitzung nicht gestartet', e);
      ok = false;
    }
    if (!ok) {
      _pending.remove(h.id);
      _sent.remove(h.id);
      pending.finish(null);
      return notStarted;
    }
    return WebAuthStart(started: true, result: pending.completer.future);
  }

  @override
  void cancel(WebAuthHandle h) {
    _cancelled.add(h.id);
    _pending.remove(h.id)?.finish(null);
    if (!_sent.remove(h.id)) return;
    channel.invokeMethod<void>('cancel', <String, Object?>{'id': h.id}).then<void>((_) {}, onError: (Object _) {});
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'ended') return null;
    final args = call.arguments;
    if (args is! Map) return null;
    final id = args['id'];
    if (id is! int) return null;
    // Unbekannt oder schon erledigt (z. B. verspätetes Ende einer ersetzten Sitzung): verwerfen.
    final pending = _pending.remove(id);
    _sent.remove(id);
    if (pending == null) return null;
    pending.finish(_accept(args['url'], pending.scheme));
    return null;
  }

  /// Nur ein lesbarer Rücksprung mit begrenzter Länge und – falls erwartet – dem richtigen Schema.
  static Uri? _accept(Object? raw, String? scheme) {
    if (raw is! String) return null;
    final u = raw.length > maxLength ? null : Uri.tryParse(raw);
    if (u == null || (scheme != null && u.scheme != scheme)) {
      AppLog.w('webauth', 'Rücksprung der Anmeldesitzung verworfen');
      return null;
    }
    return u;
  }
}

class _Pending {
  _Pending(this.scheme);
  final String? scheme;
  final Completer<Uri?> completer = Completer<Uri?>();

  void finish(Uri? u) {
    if (!completer.isCompleted) completer.complete(u);
  }
}
