import 'dart:async';

import 'package:family_nexus/data/platform/web_auth_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kanal-Schicht der Anmeldesitzung (iOS/macOS, #268, E-91) gegen einen nachgebildeten nativen Handler.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ChannelWebAuthSession.channelName);
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final page = Uri.parse('https://anbieter.test/authorize?x=1');
  const scheme = 'io.github.carpeasrael.familynexus';

  late List<MethodCall> calls;

  /// Native Seite: [onStart] beantwortet `start` (Standard: true).
  void native({FutureOr<Object?> Function(MethodCall call)? onStart}) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'start') return onStart == null ? true : await onStart(call);
      return null;
    });
  }

  /// Sendet `ended(id, url)` von der nativen Seite an Dart.
  Future<void> ended(int id, String? url) async {
    final data = const StandardMethodCodec().encodeMethodCall(MethodCall('ended', <String, Object?>{'id': id, 'url': url}));
    await messenger.handlePlatformMessage(ChannelWebAuthSession.channelName, data, (_) {});
  }

  int idOf(MethodCall call) => (call.arguments as Map<Object?, Object?>)['id']! as int;

  setUp(() {
    calls = <MethodCall>[];
    native();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('start sendet id, url und Schema; Ende mit passender URI wird zugestellt', () async {
    final s = ChannelWebAuthSession();
    final h = s.begin();
    final r = await s.start(h, page, callbackScheme: scheme);
    expect(r.started, isTrue);
    final args = calls.single.arguments as Map<Object?, Object?>;
    expect(calls.single.method, 'start');
    expect(args['id'], h.id);
    expect(args['url'], page.toString());
    expect(args['scheme'], scheme);
    await ended(h.id, '$scheme:/oauth?code=1&state=2');
    expect((await r.result)!.queryParameters['code'], '1');
  });

  test('Completer ist vor start registriert: ended noch im start-Handler wird zugestellt', () async {
    final s = ChannelWebAuthSession();
    native(onStart: (call) async {
      await ended(idOf(call), '$scheme:/oauth?code=früh&state=2');
      return true;
    });
    final r = await s.start(s.begin(), page, callbackScheme: scheme);
    expect(r.started, isTrue);
    expect((await r.result)!.queryParameters['code'], 'früh');
  });

  test('fremde und alte IDs werden verworfen', () async {
    final s = ChannelWebAuthSession();
    final h = s.begin();
    final r = await s.start(h, page, callbackScheme: scheme);
    await ended(h.id + 1000, '$scheme:/oauth?code=fremd&state=2');
    await ended(h.id - 1, null);
    var done = false;
    unawaited(r.result.then((_) => done = true));
    await pumpEventQueue();
    expect(done, isFalse, reason: 'fremde IDs beenden die Sitzung nicht');
    await ended(h.id, '$scheme:/oauth?code=eigen&state=2');
    expect((await r.result)!.queryParameters['code'], 'eigen');
    // Ein zweites, verspätetes Ende derselben ID ist wirkungslos (kein Fehler).
    await ended(h.id, null);
  });

  test('falsches Schema, zu lang oder unlesbar → null', () async {
    final s = ChannelWebAuthSession();
    for (final raw in <String>[
      'https://evil.test/oauth?code=1',
      '$scheme:/oauth?code=${'x' * 2048}',
      '$scheme://[::1', // unlesbar
    ]) {
      final h = s.begin();
      final r = await s.start(h, page, callbackScheme: scheme);
      await ended(h.id, raw);
      expect(await r.result, isNull, reason: raw.length > 60 ? 'zu lang' : raw);
    }
  });

  test('PlatformException, MissingPluginException und false → nicht gestartet', () async {
    final s = ChannelWebAuthSession();
    native(onStart: (_) => throw PlatformException(code: 'x'));
    expect((await s.start(s.begin(), page, callbackScheme: scheme)).started, isFalse);
    native(onStart: (_) => false);
    final r = await s.start(s.begin(), page, callbackScheme: scheme);
    expect(r.started, isFalse);
    expect(await r.result, isNull);
    messenger.setMockMethodCallHandler(channel, null); // kein Plugin: MissingPluginException
    expect((await s.start(s.begin(), page, callbackScheme: scheme)).started, isFalse);
  });

  test('nur https', () async {
    final s = ChannelWebAuthSession();
    expect((await s.start(s.begin(), Uri.parse('http://anbieter.test/'), callbackScheme: scheme)).started, isFalse);
    expect(calls, isEmpty);
  });

  test('cancel(h) sendet cancel mit genau dieser ID und schließt result sofort mit null', () async {
    final s = ChannelWebAuthSession();
    final h = s.begin();
    final r = await s.start(h, page, callbackScheme: scheme);
    s.cancel(h);
    expect(await r.result.timeout(const Duration(seconds: 1)), isNull);
    await pumpEventQueue();
    expect(calls.map((c) => c.method), <String>['start', 'cancel']);
    expect(idOf(calls.last), h.id);
  });

  test('cancel vor start → kein start gesendet, kein cancel gesendet', () async {
    final s = ChannelWebAuthSession();
    final h = s.begin();
    s.cancel(h);
    final r = await s.start(h, page, callbackScheme: scheme);
    expect(r.started, isFalse);
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  test('cancel während die Startantwort aussteht → cancel mit dieser ID, result null', () async {
    final s = ChannelWebAuthSession();
    final gate = Completer<void>();
    native(onStart: (_) async {
      await gate.future;
      return true;
    });
    final h = s.begin();
    final starting = s.start(h, page, callbackScheme: scheme);
    await pumpEventQueue();
    s.cancel(h);
    gate.complete();
    final r = await starting;
    expect(await r.result, isNull);
    await pumpEventQueue();
    expect(calls.map((c) => c.method), <String>['start', 'cancel']);
    expect(idOf(calls.last), h.id);
  });

  test('zwei Nutzer derselben Instanz: steigende IDs, der Abbruch des einen verwirft den anderen nicht', () async {
    final s = ChannelWebAuthSession();
    final a = s.begin();
    final b = s.begin();
    expect(b.id, greaterThan(a.id));
    // Abbruch von a vor dessen Start.
    s.cancel(a);
    final rb = await s.start(b, page);
    expect(rb.started, isTrue);
    expect((await s.start(a, page)).started, isFalse);
    // Abbruch eines dritten nach dessen Start.
    final c = s.begin();
    final rc = await s.start(c, page, callbackScheme: scheme);
    s.cancel(c);
    expect(await rc.result, isNull);
    await ended(b.id, '$scheme:/oauth');
    expect(await rb.result, isNotNull, reason: 'b läuft weiter');
  });

  test('zwei Instanzen nacheinander (wie „Erneut versuchen“) vergeben keine doppelte ID', () {
    final first = ChannelWebAuthSession();
    final ids = <int>{first.begin().id, first.begin().id};
    final second = ChannelWebAuthSession();
    ids
      ..add(second.begin().id)
      ..add(second.begin().id);
    expect(ids, hasLength(4));
  });
}
