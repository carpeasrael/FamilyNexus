import 'dart:async';

import 'package:family_nexus/data/platform/browser_launcher.dart';
import 'package:family_nexus/data/platform/embedded_auth.dart';
import 'package:family_nexus/data/platform/oauth_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_browser.dart';

void main() {
  final page = Uri.parse('https://anbieter.test/authorize');
  final cb = Uri.parse('io.github.carpeasrael.familynexus:/oauth?code=1&state=s');
  DateTime soon([int s = 1]) => DateTime.now().add(Duration(seconds: s));

  late List<EmbeddedRequest> requests;
  late List<Completer<EmbeddedResult>> results;
  Future<EmbeddedHandle?> opener(EmbeddedRequest r) async {
    requests.add(r);
    final c = Completer<EmbeddedResult>();
    results.add(c);
    return EmbeddedHandle(c.future);
  }

  setUp(() {
    requests = <EmbeddedRequest>[];
    results = <Completer<EmbeddedResult>>[];
  });

  test('Rücksprung wird geliefert, Versuch endet danach, alter Weg unberührt', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    expect(await a.open(page), isTrue);
    expect(requests.single.kind, EmbeddedKind.signIn);
    expect(requests.single.redirectUri, a.redirectUri);
    results.single.complete(EmbeddedCallback(cb));
    expect(await a.next(deadline: soon()), cb);
    expect(await a.next(deadline: soon()), isNull);
    expect(session.begins, 0);
  });

  test('cancelled beendet Versuch; cancel() schliesst Seite; neuer Versuch beendet alten', () async {
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(FakeWebAuthSession()));
    final a = await r.prepare();
    await a.open(page);
    final a2 = await r.prepare();
    expect(requests.single.cancel.isCompleted, isTrue, reason: 'prepare() beendet den alten Versuch und seine Seite');
    expect(await a.next(deadline: soon()), isNull);
    await a2.open(page);
    results.last.complete(const EmbeddedCancelled());
    expect(await a2.next(deadline: soon()), isNull);
    final a3 = await r.prepare();
    await a3.open(page);
    a3.cancel();
    expect(requests.last.cancel.isCompleted, isTrue);
  });

  test('Ausweg: gleiche Original-URL, Pumpe liefert Rücksprung der Systemsitzung, Seitenende beendet nichts', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    expect(await requests.single.continueExternally(), isTrue);
    expect(session.starts.single.uri, page);
    expect(session.starts.single.scheme, 'io.github.carpeasrael.familynexus');
    results.single.complete(const EmbeddedContinueExternally());
    await Future<void>.delayed(Duration.zero);
    final next = a.next(deadline: soon(2));
    session.finish(cb);
    expect(await next, cb);
    expect(await a.next(deadline: soon()), isNull, reason: 'close() am Ende der Pumpe');
  });

  test('Ausweg + Abbruch in der Systemsitzung = Versuch endet (oauthAborted)', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    await requests.single.continueExternally();
    final next = a.next(deadline: soon(2));
    session.finish(null);
    expect(await next, isNull);
  });

  test('Ausweg-Wiederholung: erster scheitert (alte Instanz abgebrochen), zweiter ruft neu prepare() und gelingt', () async {
    final session = FakeWebAuthSession()..startResult = false;
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    expect(await requests.single.continueExternally(), isFalse);
    expect(session.begins, 1);
    session.startResult = true;
    expect(await requests.single.continueExternally(), isTrue, reason: 'Wiederholung muss klappen');
    expect(session.begins, 2, reason: 'jeder Ausweg ruft neu prepare()');
    expect(session.starts.last.uri, page);
    // Eingebetteter Versuch blieb während des Fehlschlags offen und liefert weiter.
    final next = a.next(deadline: soon(2));
    session.finish(cb);
    expect(await next, cb);
  });

  test('zwei erfolgreiche Ausweg-Aufrufe: der Versuch des ersten wird vom Brückencode selbst abgebrochen', () async {
    // Ein Rückfall, dessen `prepare()` den alten Versuch NICHT selbst beendet (anders als SessionOAuthRedirect):
    // Nur so ist beobachtbar, dass die Brücke einen alten Versuch vor dem neuen abbricht.
    final fallback = _CountingRedirect();
    final r = EmbeddedOAuthRedirect(opener, fallback);
    final a = await r.prepare();
    await a.open(page);
    expect(await requests.single.continueExternally(), isTrue);
    expect(fallback.attempts, hasLength(1));
    expect(fallback.attempts.single.cancelled, isFalse, reason: 'der erste Ausweg läuft');
    expect(await requests.single.continueExternally(), isTrue);
    expect(fallback.attempts, hasLength(2), reason: 'jeder Ausweg ruft neu prepare()');
    expect(fallback.attempts.first.cancelled, isTrue, reason: 'der alte Versuch wird vor dem neuen abgebrochen');
    expect(fallback.attempts.last.cancelled, isFalse);
    expect(fallback.attempts.last.opened, <Uri>[page]);
    a.cancel();
    expect(fallback.attempts.last.cancelled, isTrue, reason: 'cancel() des eingebetteten Versuchs bricht auch den Ausweg ab');
  });

  test('Ausweg scheitert: Versuch bleibt offen, Seite kann noch Rücksprung liefern', () async {
    final session = FakeWebAuthSession()..startResult = false;
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    expect(await requests.single.continueExternally(), isFalse);
    results.single.complete(EmbeddedCallback(cb));
    expect(await a.next(deadline: soon()), cb);
  });

  test('cancel() des eingebetteten Versuchs bricht auch die Systemsitzung ab', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    await requests.single.continueExternally();
    a.cancel();
    expect(session.cancels, isNotEmpty);
    expect(session.isOpen(session.starts.single.id), isFalse);
  });

  test('Pumpe: Frist endet den Versuch (close), auch ohne Abbruch', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session), pumpTimeout: const Duration(milliseconds: 50));
    final a = await r.prepare();
    await a.open(page);
    await requests.single.continueExternally();
    final sw = Stopwatch()..start();
    expect(await a.next(deadline: soon(30)), isNull);
    expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
  });

  test('Pumpe: Rücksprung vor close() geht nicht verloren', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(session));
    final a = await r.prepare();
    await a.open(page);
    await requests.single.continueExternally();
    session.finish(cb);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(await a.next(deadline: soon()), cb);
  });

  test('Rückfall zur Aufrufzeit: Opener null oder wirft -> alter Weg, gleiche URL', () async {
    final session = FakeWebAuthSession();
    final r = EmbeddedOAuthRedirect((_) async => null, SessionOAuthRedirect(session));
    final a = await r.prepare();
    expect(await a.open(page), isTrue);
    expect(session.starts.single.uri, page);
    final next = a.next(deadline: soon(2));
    session.finish(cb);
    expect(await next, cb);

    final session2 = FakeWebAuthSession();
    final r2 = EmbeddedOAuthRedirect((_) => throw StateError('x'), SessionOAuthRedirect(session2));
    final a2 = await r2.prepare();
    expect(await a2.open(page), isTrue);
    expect(session2.starts.single.uri, page);
  });

  test('open() nach beendetem Versuch: false, Seite wird geschlossen', () async {
    final r = EmbeddedOAuthRedirect(opener, SessionOAuthRedirect(FakeWebAuthSession()));
    final a = await r.prepare();
    a.cancel();
    expect(await a.open(page), isFalse);
    expect(requests, isEmpty);
  });

  group('Launcher', () {
    test('open(inApp:false) bleibt extern; inApp -> Seite (kind page); opened vor Seitenende, waited danach', () async {
      final fb = FakeBrowser();
      final l = EmbeddedBrowserLauncher(opener, fb);
      expect(await l.open(Uri.parse('https://element.io/download')), isTrue);
      expect(requests, isEmpty);
      expect(fb.opened.single.host, 'element.io');
      final o = await l.openInApp(page);
      expect(o.opened, isTrue, reason: 'opened nach dem Push, nicht beim Schließen');
      expect(requests.single.kind, EmbeddedKind.page);
      var waited = false;
      unawaited(o.waited.then((v) => waited = v));
      await Future<void>.delayed(Duration.zero);
      expect(waited, isFalse);
      results.single.complete(const EmbeddedCancelled());
      await Future<void>.delayed(Duration.zero);
      expect(waited, isTrue);
    });

    test('Rückfall bei null/Ausnahme', () async {
      final fb = FakeBrowser();
      final o2 = await EmbeddedBrowserLauncher((_) async => null, fb).openInApp(page);
      expect(o2.opened, isTrue);
      expect(fb.opened.last, page);
      final o3 = await EmbeddedBrowserLauncher((_) => throw StateError('x'), fb).openInApp(page);
      expect(o3.opened, isTrue);
    });

    test('Ausweg hängt waited auf den alten Weg um; Ausweg-Wiederholung nach Fehlschlag', () async {
      final fb = FakeBrowser()
        ..sessionWaits = true
        ..available = false;
      final l = EmbeddedBrowserLauncher(opener, fb);
      final o = await l.openInApp(page);
      expect(o.opened, isTrue);
      expect(await requests.single.continueExternally(), isFalse);
      fb.available = true;
      expect(await requests.single.continueExternally(), isTrue);
      results.single.complete(const EmbeddedContinueExternally());
      var waited = false;
      unawaited(o.waited.then((v) => waited = v));
      await Future<void>.delayed(Duration.zero);
      expect(waited, isFalse, reason: 'Seite zu, Systemsitzung offen');
      fb.finishSession();
      await Future<void>.delayed(Duration.zero);
      expect(waited, isTrue);
    });

    test('nicht-https wird abgelehnt', () async {
      final l = EmbeddedBrowserLauncher(opener, FakeBrowser());
      expect((await l.openInApp(Uri.parse('http://x.test/'))).opened, isFalse);
      expect(requests, isEmpty);
      expect(BrowserLauncher.isAllowed(page), isTrue);
    });
  });
}

/// Rückfall-Stub: zählt Versuche und beendet einen früheren Versuch in `prepare()` nicht selbst.
class _CountingRedirect implements OAuthRedirect {
  final List<_CountingAttempt> attempts = <_CountingAttempt>[];

  @override
  Future<OAuthAttempt> prepare() async {
    final a = _CountingAttempt();
    attempts.add(a);
    return a;
  }

  @override
  void cancel() {
    for (final a in attempts) {
      a.cancel();
    }
  }
}

class _CountingAttempt implements OAuthAttempt {
  final Completer<void> _end = Completer<void>();
  final List<Uri> opened = <Uri>[];
  bool cancelled = false;

  @override
  Uri get redirectUri => Uri.parse('io.github.carpeasrael.familynexus:/oauth');

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<Uri?> next({required DateTime deadline}) async {
    await _end.future.timeout(deadline.difference(DateTime.now()), onTimeout: () {});
    return null;
  }

  @override
  void cancel() {
    cancelled = true;
    if (!_end.isCompleted) _end.complete();
  }
}
